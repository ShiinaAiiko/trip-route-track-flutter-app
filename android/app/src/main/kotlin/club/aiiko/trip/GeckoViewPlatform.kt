package club.aiiko.trip

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Rect
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.ViewTreeObserver
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputConnection
import androidx.core.app.ActivityCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import org.mozilla.geckoview.GeckoResult
import org.mozilla.geckoview.GeckoRuntime
import org.mozilla.geckoview.GeckoRuntimeSettings
import org.mozilla.geckoview.GeckoSession
import org.mozilla.geckoview.GeckoView

class GeckoViewPlatform(
    private val context: Context,
    messenger: BinaryMessenger,
    id: Int,
    creationParams: Map<String, Any>?
) : PlatformView, MethodChannel.MethodCallHandler {

    private val geckoView: GeckoView
    private val geckoSession: GeckoSession
    private val methodChannel: MethodChannel
    private var isLoading = true
    private val handler = Handler(Looper.getMainLooper())
    private val serverPort: Int
    // 导航历史记录，用于判断是否可以返回
    private val navigationHistory = mutableListOf<String>()
    // 定期检查并重新注入 bridge 的任务
    private var bridgeCheckRunnable: Runnable? = null

    companion object {
        private var geckoRuntime: GeckoRuntime? = null
        
        fun getRuntime(context: Context): GeckoRuntime {
            if (geckoRuntime == null) {
                synchronized(this) {
                    if (geckoRuntime == null) {
                        try {
                            val settings = GeckoRuntimeSettings.Builder()
                                .javaScriptEnabled(true)
                                .remoteDebuggingEnabled(true)
                                .build()
                            geckoRuntime = GeckoRuntime.create(context.applicationContext, settings)
                            Log.d("GeckoViewPlatform", "GeckoRuntime created successfully")
                        } catch (e: Exception) {
                            Log.e("GeckoViewPlatform", "Failed to create GeckoRuntime: ${e.message}")
                            throw e
                        }
                    }
                }
            }
            return geckoRuntime!!
        }
    }

    init {
        Log.d("GeckoViewPlatform", "Creating MethodChannel with id: $id")
        methodChannel = MethodChannel(messenger, "gecko_view_$id")
        methodChannel.setMethodCallHandler(this)
        Log.d("GeckoViewPlatform", "MethodChannel created: gecko_view_$id")

        serverPort = creationParams?.get("serverPort") as? Int ?: 8080
        Log.d("GeckoViewPlatform", "Server port: $serverPort")

        val isDarkMode = creationParams?.get("isDarkMode") as? Boolean ?: true
        val bgColor = if (isDarkMode) {
            android.graphics.Color.BLACK
        } else {
            android.graphics.Color.WHITE
        }

        geckoSession = GeckoSession()
        
        // 使用自定义的 GeckoViewWrapper 来增强焦点和输入法支持
        geckoView = GeckoViewWrapper(context).apply {
            // 设置透明背景，让状态栏设置完全控制显示效果
            setBackgroundColor(android.graphics.Color.TRANSPARENT)
            
            // 设置触摸事件监听 - 只请求焦点，不强制唤起输入法
            // 输入法唤起由 GeckoView 内部根据输入框点击自动处理
            setOnTouchListener { v, event ->
                if (event.action == android.view.MotionEvent.ACTION_UP) {
                    v.postDelayed({
                        if (!v.hasFocus()) {
                            v.requestFocus()
                        }
                    }, 100) // 给系统 100ms 的缓冲时间来切换 View 状态
                }
                false
            }
        }

        // 设置权限委托，处理网页的位置权限请求
        geckoSession.permissionDelegate = object : GeckoSession.PermissionDelegate {
            override fun onContentPermissionRequest(
                session: GeckoSession,
                permission: GeckoSession.PermissionDelegate.ContentPermission
            ): GeckoResult<Int> {
                if (permission.permission == GeckoSession.PermissionDelegate.PERMISSION_GEOLOCATION) {
                    if (hasLocationPermission()) {
                        return GeckoResult.fromValue(
                            GeckoSession.PermissionDelegate.ContentPermission.VALUE_ALLOW
                        )
                    } else {
                        return GeckoResult.fromValue(
                            GeckoSession.PermissionDelegate.ContentPermission.VALUE_DENY
                        )
                    }
                }
                return GeckoResult.fromValue(
                    GeckoSession.PermissionDelegate.ContentPermission.VALUE_ALLOW
                )
            }

            override fun onAndroidPermissionsRequest(
                session: GeckoSession,
                permissions: Array<out String>?,
                callback: GeckoSession.PermissionDelegate.Callback
            ) {
                val hasAllPermissions = permissions?.all { perm ->
                    ActivityCompat.checkSelfPermission(context, perm) == PackageManager.PERMISSION_GRANTED
                } ?: true
                
                if (hasAllPermissions) {
                    callback.grant()
                } else {
                    callback.reject()
                }
            }
        }

        // 打开 session
        geckoSession.open(getRuntime(context))
        geckoView.setSession(geckoSession)

        // 加载初始 URL - 使用本地服务器
        val defaultUrl = "http://localhost:$serverPort/"
        val initialUrl = creationParams?.get("initialUrl") as? String ?: defaultUrl
        
        // 设置页面加载完成后的回调
        geckoSession.progressDelegate = object : GeckoSession.ProgressDelegate {
            override fun onPageStart(session: GeckoSession, url: String) {
                Log.d("GeckoViewPlatform", "onPageStart called: $url")
                isLoading = true
                // 记录导航历史（只在页面开始加载时添加，避免重复）
                if (navigationHistory.isEmpty() || navigationHistory.last() != url) {
                    navigationHistory.add(url)
                    Log.d("GeckoViewPlatform", "Navigation history: $navigationHistory")
                }
                try {
                    methodChannel.invokeMethod("onPageStart", mapOf("url" to url))
                    Log.d("GeckoViewPlatform", "invokeMethod onPageStart succeeded")
                } catch (e: Exception) {
                    Log.e("GeckoViewPlatform", "invokeMethod onPageStart failed: ${e.message}")
                }
            }

            override fun onPageStop(session: GeckoSession, success: Boolean) {
                Log.d("GeckoViewPlatform", "onPageStop called: success=$success")
                isLoading = false
                // 先发送 onPageStop 消息，确保 Flutter 端能及时关闭 loading
                methodChannel.invokeMethod("onPageStop", mapOf("success" to success))
                if (success) {
                    // 延迟注入 JavaScript，避免干扰页面加载状态
                    handler.postDelayed({
                        injectGeolocationMock()
                        injectJSBridge()
                        geckoView.requestFocus()
                    }, 300)
                }
            }
        }
        
        // 加载本地服务器
        geckoSession.loadUri(initialUrl)
        
        // 启动定期检查和重新注入 bridge 的任务
        startBridgeChecker()
    }

    private fun hasLocationPermission(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val hasFine = ActivityCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
            val hasCoarse = ActivityCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_COARSE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
            return hasFine || hasCoarse
        }
        return true
    }
    
    /**
     * 启动定期检查和重新注入 bridge 的任务
     * 确保即使路由变化后 bridge 也不会丢失
     */
    private fun startBridgeChecker() {
        // 先停止旧的任务（如果存在）
        stopBridgeChecker()
        
        // 创建新的检查任务
        bridgeCheckRunnable = object : Runnable {
            override fun run() {
                try {
                    // 检查 bridge 是否还存在（使用英文注释避免 URL 编码问题）
                    val checkScript = """
                        (function() {
                            // check if bridge exists
                            var hasBridge = !!(window.isFlutterApp && window.ReactNativeWebView && window.ReactNativeWebView.postMessage);
                            return hasBridge ? '1' : '0';
                        })();
                    """.trimIndent()
                    
                    // Inject check script
                    geckoSession.loadUri("javascript:$checkScript")
                    
                    // 不管检查结果如何，都尝试重新注入（这样更安全）
                    // 稍微延迟一下，避免和上面的检查脚本冲突
                    handler.postDelayed({
                        try {
                            injectJSBridge()
                        } catch (e: Exception) {
                            Log.e("GeckoViewPlatform", "Error re-injecting bridge: ${e.message}")
                        }
                    }, 100)
                } catch (e: Exception) {
                    Log.e("GeckoViewPlatform", "Error in bridge checker: ${e.message}")
                }
                
                // 安排下一次检查（500ms 后）
                handler.postDelayed(this, 500)
            }
        }
        
        // 延迟启动，让页面先加载完
        handler.postDelayed(bridgeCheckRunnable!!, 1000)
    }
    
    /**
     * 停止定期检查任务
     */
    private fun stopBridgeChecker() {
        bridgeCheckRunnable?.let { 
            handler.removeCallbacks(it) 
            bridgeCheckRunnable = null
        }
    }

    override fun getView(): View {
        return geckoView
    }

    override fun dispose() {
        // 停止 bridge 检查任务
        stopBridgeChecker()
        geckoSession.close()
        methodChannel.setMethodCallHandler(null)
    }

    private fun injectGeolocationMock() {
        val mockScript = """
            (function() {
                window._geolocationWatchId = null;
                window._geolocationSuccessCallback = null;
                window._geolocationErrorCallback = null;

                var Geolocation = function() {};

                Geolocation.prototype.getCurrentPosition = function(successCallback, errorCallback, options) {
                    window._geolocationSuccessCallback = successCallback;
                    window._geolocationErrorCallback = errorCallback;
                    if (window._geolocationSuccessCallback) {
                        window.postMessage({type: 'GEOLOCATION_REQUEST', action: 'getCurrentPosition'}, '*');
                    }
                };

                Geolocation.prototype.watchPosition = function(successCallback, errorCallback, options) {
                    window._geolocationSuccessCallback = successCallback;
                    window._geolocationErrorCallback = errorCallback;
                    window._geolocationWatchId = window._geolocationWatchId || 1;
                    window.postMessage({type: 'GEOLOCATION_REQUEST', action: 'watchPosition'}, '*');
                    return window._geolocationWatchId;
                };

                Geolocation.prototype.clearWatch = function(watchId) {
                    if (watchId === window._geolocationWatchId) {
                        window._geolocationWatchId = null;
                    }
                };

                if (!window.navigator.geolocation) {
                    Object.defineProperty(window.navigator, 'geolocation', {
                        value: new Geolocation(),
                        writable: false,
                        configurable: true
                    });
                }
            })();
        """.trimIndent()
        geckoSession.loadUri("javascript:$mockScript")
    }

    private fun injectJSBridge() {
        val bridgeScript = """
            window.isFlutterApp = true;
            
            // 先尝试删除旧的定义，避免冲突
            try { delete window.ReactNativeWebView; } catch (e) {}
            
            // 直接定义 ReactNativeWebView
            window.ReactNativeWebView = {
                postMessage: function(message) {
                    var xhr = new XMLHttpRequest();
                    xhr.open('GET', 'http://localhost:$serverPort/__flutter_bridge__?message=' + encodeURIComponent(message), true);
                    xhr.send();
                }
            };
        """.trimIndent()
        geckoSession.loadUri("javascript:$bridgeScript")
    }

    private var lastGeolocationCallback: String? = null

    /**
     * 判断是否可以返回上一页
     * 导航历史记录大于1条时表示可以返回
     */
    private fun canGoBack(): Boolean {
        return navigationHistory.size > 1
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "loadUrl" -> {
                val url = call.argument<String>("url")
                if (url != null) {
                    geckoSession.loadUri(url)
                    result.success(null)
                } else {
                    result.error("INVALID_URL", "URL is null", null)
                }
            }
            "evaluateJavascript" -> {
                val script = call.argument<String>("script")
                if (script != null) {
                    geckoSession.loadUri("javascript:$script")
                    result.success(null)
                } else {
                    result.error("INVALID_SCRIPT", "Script is null", null)
                }
            }
            "postMessage" -> {
                val message = call.argument<String>("message")
                if (message != null) {
                    geckoSession.loadUri("javascript:if (window.onFlutterMessage) { window.onFlutterMessage($message); }")
                    result.success(null)
                } else {
                    result.error("INVALID_MESSAGE", "Message is null", null)
                }
            }
            "setGeolocation" -> {
                val latitude = call.argument<Double>("latitude")
                val longitude = call.argument<Double>("longitude")
                val accuracy = call.argument<Double>("accuracy") ?: 10.0
                val altitude = call.argument<Double>("altitude")
                val heading = call.argument<Double>("heading")
                val speed = call.argument<Double>("speed")
                val timestamp = call.argument<Double>("timestamp") ?: (System.currentTimeMillis().toDouble())

                if (latitude != null && longitude != null) {
                    val positionJson = buildString {
                        append("{coords:{")
                        append("latitude:$latitude,")
                        append("longitude:$longitude,")
                        append("accuracy:$accuracy,")
                        if (altitude != null) append("altitude:$altitude,")
                        if (heading != null) append("heading:$heading,")
                        if (speed != null) append("speed:$speed,")
                        append("altitudeAccuracy:${accuracy}")
                        append("}},")
                        append("timestamp:$timestamp")
                        append("}")
                    }

                    val js = """
                        (function() {
                            if (window._geolocationSuccessCallback) {
                                window._geolocationSuccessCallback($positionJson);
                            }
                            if (window.navigator && window.navigator.geolocation && window._geolocationWatchId !== null) {
                                var mockPosition = $positionJson;
                                window.navigator.geolocation._successHandler(mockPosition);
                            }
                        })();
                    """.trimIndent()
                    geckoSession.loadUri("javascript:$js")
                    result.success(null)
                } else {
                    result.error("INVALID_COORDS", "latitude or longitude is null", null)
                }
            }
            "setGeolocationError" -> {
                val code = call.argument<String>("code") ?: "POSITION_UNAVAILABLE"
                val message = call.argument<String>("message") ?: "Position unavailable"

                val js = """
                    (function() {
                        if (window._geolocationErrorCallback) {
                            window._geolocationErrorCallback({code: '$code', message: '$message'});
                        }
                        if (window.navigator && window.navigator.geolocation && window._geolocationWatchId !== null) {
                            window.navigator.geolocation._errorHandler({code: 2, message: '$message'});
                        }
                    })();
                """.trimIndent()
                geckoSession.loadUri("javascript:$js")
                result.success(null)
            }
            "goBack" -> {
                if (canGoBack()) {
                    geckoSession.goBack()
                    // 移除最后一条历史记录（当前页面）
                    if (navigationHistory.size > 0) {
                        navigationHistory.removeLast()
                    }
                    result.success(true)
                } else {
                    result.success(false)
                }
            }
            "canGoBack" -> {
                result.success(canGoBack())
            }
            else -> result.notImplemented()
        }
    }
}

/**
 * 自定义 GeckoView 包装类
 * 解决 Flutter PlatformView 中焦点传递问题
 * 实现 GeckoView 官方补丁思路：先清空焦点再重新请求
 */
class GeckoViewWrapper(context: Context) : GeckoView(context) {

    private val TAG = "GeckoViewWrapper"
    
    // 用于检测输入法变化的监听器
    private var layoutListener: ViewTreeObserver.OnGlobalLayoutListener? = null
    private var lastVisibleHeight = 0
    private var isKeyboardVisible = false

    init {
        Log.d(TAG, "GeckoViewWrapper initialized")
        // 确保可以获取焦点
        isFocusable = true
        isFocusableInTouchMode = true
        isClickable = true
        isFocusedByDefault = true
        
        // 设置输入法变化监听器
        setupKeyboardChangeListener()
    }

    /**
     * 设置键盘变化监听器
     * 当输入法收起时，强制刷新布局以修复底部黑色区域问题
     */
    private fun setupKeyboardChangeListener() {
        layoutListener = ViewTreeObserver.OnGlobalLayoutListener {
            if (rootView == null) return@OnGlobalLayoutListener
            
            val r = Rect()
            rootView.getWindowVisibleDisplayFrame(r)
            val screenHeight = rootView.rootView.height
            val visibleHeight = r.height()
            
            // 检测输入法状态变化
            val keyboardHeight = screenHeight - visibleHeight
            val currentKeyboardVisible = keyboardHeight > screenHeight * 0.15
            
            // 当输入法从显示变为隐藏时
            if (isKeyboardVisible && !currentKeyboardVisible) {
                Log.w(TAG, "========== Keyboard closed, triggering layout fix ==========")
                // 强制刷新布局，修复底部黑色区域
                postDelayed({
                    requestLayout()
                    invalidate()
                    // 额外的强制重绘
                    parent?.requestLayout()
                    Log.w(TAG, "Layout refreshed after keyboard close")
                }, 100)
            }
            
            isKeyboardVisible = currentKeyboardVisible
            lastVisibleHeight = visibleHeight
        }
        
        viewTreeObserver.addOnGlobalLayoutListener(layoutListener)
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        // 移除监听器，避免内存泄漏
        layoutListener?.let {
            viewTreeObserver.removeOnGlobalLayoutListener(it)
        }
    }

    override fun onCheckIsTextEditor(): Boolean {
        // 返回 true，表示这是一个文本编辑器，可以接受输入
        Log.d(TAG, "onCheckIsTextEditor called, returning true")
        return true
    }

    override fun onCreateInputConnection(outAttrs: EditorInfo): InputConnection? {
        // 调用父类的实现，让 GeckoView 自己处理输入连接
        Log.d(TAG, "onCreateInputConnection called, delegating to super class")
        return super.onCreateInputConnection(outAttrs)
    }

    override fun checkInputConnectionProxy(view: View?): Boolean {
        // 告诉系统：即使输入连接看起来不是直接来自这个 View，也请信任并处理它
        Log.d(TAG, "checkInputConnectionProxy called")
        return true
    }

    /**
     * 实现官方补丁的思路：先清空焦点再重新请求，以触发系统重新评估输入法服务
     */
    fun showSoftInput() {
        Log.w(TAG, "========== showSoftInput() called ==========")
        val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as? android.view.inputmethod.InputMethodManager
        if (imm != null) {
            val isActive = imm.isActive(this)
            Log.w(TAG, "hasFocus=${hasFocus()}, isFocused=${isFocused()}, isActive=$isActive")
            
            if (isActive) {
                Log.w(TAG, "SUCCESS: View IS active, showing soft input directly")
                imm.showSoftInput(this, 0)
            } else {
                Log.w(TAG, "PROBLEM: View has focus but NOT active (VirtualDisplay issue)")
                // 尝试反射方案：绕过 isActive 检查
                try {
                    Log.w(TAG, "Attempting reflection workaround")
                    val method = imm.javaClass.getMethod(
                        "showSoftInput",
                        android.view.View::class.java,
                        Int::class.javaPrimitiveType,
                        android.os.ResultReceiver::class.java
                    )
                    method.invoke(imm, this, 0, null)
                    Log.w(TAG, "Reflection call succeeded")
                } catch (e: Exception) {
                    Log.w(TAG, "Reflection failed: ${e.message}")
                    // 回退到传统方法
                    if (hasFocus()) {
                        Log.w(TAG, "Attempting fix: clearFocus() then requestFocus()")
                        clearFocus()
                        requestFocus()
                    }
                    post {
                        val newIsActive = imm.isActive(this)
                        Log.w(TAG, "After post: hasFocus=${hasFocus()}, isActive=$newIsActive")
                        if (hasFocus()) {
                            Log.w(TAG, "Calling showSoftInput after post")
                            imm.showSoftInput(this@GeckoViewWrapper, 0)
                        }
                    }
                }
            }
        } else {
            Log.w(TAG, "ERROR: InputMethodManager is null!")
        }
    }
}
