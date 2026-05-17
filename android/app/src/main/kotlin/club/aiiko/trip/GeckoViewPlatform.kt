package club.aiiko.trip

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
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

data class TabSession(
    val session: GeckoSession,
    val url: String,
    val title: String = "",
    val id: Long = System.currentTimeMillis(),
    var canGoBack: Boolean = false,
    var canGoForward: Boolean = false
)

class TabManager(
    private val context: Context,
    private val methodChannel: MethodChannel,
    private val geckoView: GeckoView
) {
    companion object {
        private const val TAG = "TabManager"
    }

    val tabStack = mutableListOf<TabSession>()
    var currentTabIndex = -1
    var currentTabCanGoBack: Boolean = false
    var currentTabCanGoForward: Boolean = false

    val currentSession: GeckoSession?
        get() = if (currentTabIndex >= 0 && currentTabIndex < tabStack.size) {
            tabStack[currentTabIndex].session
        } else null

    val tabCount: Int
        get() = tabStack.size

    val canGoBack: Boolean
        get() = tabStack.size > 1

    val currentTab: TabSession?
        get() = if (currentTabIndex >= 0 && currentTabIndex < tabStack.size) {
            tabStack[currentTabIndex]
        } else null

    fun createNewTab(url: String): TabSession {
        Log.d(TAG, "Creating new tab for URL: $url")
        val session = GeckoSession()
        session.open(GeckoViewPlatform.getRuntime(context))

        val tabSession = TabSession(session, url, "")
        tabStack.add(tabSession)
        currentTabIndex = tabStack.size - 1
        session.loadUri(url)
        notifyTabStackChanged()

        return tabSession
    }

    fun addTab(session: GeckoSession, url: String): TabSession {
        Log.d(TAG, "Adding existing session as new tab: $url")
        val tabSession = TabSession(session, url, "")
        tabStack.add(tabSession)
        currentTabIndex = tabStack.size - 1
        // 切换到新 session
        geckoView.setSession(session)
        notifyTabStackChanged()
        return tabSession
    }

    fun closeCurrentTab(): Boolean {
        if (tabStack.size <= 1) {
            Log.d(TAG, "Cannot close last tab")
            return false
        }
        val tab = currentTab
        if (tab != null) {
            Log.d(TAG, "Closing tab: ${tab.title}")
            tab.session.close()
            tabStack.removeAt(currentTabIndex)
            currentTabIndex = tabStack.size - 1
            val prevSession = currentSession
            if (prevSession != null) {
                geckoView.setSession(prevSession)
            }
            notifyTabStackChanged()
            return true
        }
        return false
    }

    fun closeTab(tabId: Long): Boolean {
        val index = tabStack.indexOfFirst { it.id == tabId }
        if (index >= 0) {
            if (index == currentTabIndex && tabStack.size <= 1) {
                return false
            }
            Log.d(TAG, "Closing tab by id: $tabId")
            tabStack[index].session.close()
            tabStack.removeAt(index)
            if (index <= currentTabIndex) {
                currentTabIndex = (currentTabIndex - 1).coerceAtLeast(0)
            }
            val currentSession = currentSession
            if (currentSession != null) {
                geckoView.setSession(currentSession)
            }
            notifyTabStackChanged()
            return true
        }
        return false
    }

    fun goBackToPreviousTab(): Boolean {
        if (canGoBack) {
            Log.d(TAG, "Going back to previous tab")
            closeCurrentTab()
            return true
        }
        return false
    }

    fun getTabsInfo(): List<Map<String, Any>> {
        return tabStack.mapIndexed { index, tab ->
            mapOf(
                "id" to tab.id,
                "url" to tab.url,
                "title" to tab.title,
                "isCurrent" to (index == currentTabIndex)
            )
        }
    }

    private fun updateTab(session: GeckoSession, url: String? = null, title: String? = null) {
        val index = tabStack.indexOfFirst { it.session == session }
        Log.d(TAG, "updateTab called: session=$session, url=$url, title=$title, found index=$index, tabStack size=${tabStack.size}")
        if (index >= 0) {
            val oldTab = tabStack[index]
            tabStack[index] = oldTab.copy(
                url = url ?: oldTab.url,
                title = title ?: oldTab.title
            )
            Log.d(TAG, "Tab updated: new url=${tabStack[index].url}, new title=${tabStack[index].title}")
        } else {
            Log.w(TAG, "Tab not found in tabStack for session: $session")
        }
    }

    fun notifyTabChanged() {
        try {
            val tab = currentTab
            if (tab != null) {
                methodChannel.invokeMethod(
                    "onTabChanged",
                    mapOf(
                        "id" to tab.id,
                        "url" to tab.url,
                        "title" to tab.title
                    )
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error notifying tab changed: ${e.message}")
        }
    }

    fun notifyTabStackChanged() {
        try {
            val tabsInfo = tabStack.mapIndexed { index, tab ->
                mapOf(
                    "id" to tab.id,
                    "url" to tab.url,
                    "title" to tab.title,
                    "isCurrent" to (index == currentTabIndex),
                    "canGoBack" to tab.canGoBack,
                    "canGoForward" to tab.canGoForward
                )
            }
            Log.d(TAG, "notifyTabStackChanged: canGoBack=$currentTabCanGoBack, canGoForward=$currentTabCanGoForward, tabs=${tabsInfo.size}")
            methodChannel.invokeMethod(
                "onTabStackChanged",
                mapOf(
                    "tabs" to tabsInfo,
                    "canGoBack" to currentTabCanGoBack,
                    "canGoForward" to currentTabCanGoForward
                )
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error notifying tab stack changed: ${e.message}")
        }
    }

    fun requestExitApp(): Boolean {
        try {
            methodChannel.invokeMethod("onRequestExitApp", null)
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error invoking onRequestExitApp: ${e.message}")
            return false
        }
    }

    fun setupSession(session: GeckoSession, serverPort: Int) {
        session.progressDelegate = object : GeckoSession.ProgressDelegate {
            override fun onPageStart(s: GeckoSession, url: String) {
                Log.d(TAG, "onPageStart for tab: $url")
                try {
                    methodChannel.invokeMethod("onPageStart", mapOf("url" to url))
                } catch (e: Exception) {
                    Log.e(TAG, "Error invoking onPageStart: ${e.message}")
                }
            }

            override fun onPageStop(s: GeckoSession, success: Boolean) {
                Log.d(TAG, "onPageStop for tab: $success")
                try {
                    methodChannel.invokeMethod("onPageStop", mapOf("success" to success))
                } catch (e: Exception) {
                    Log.e(TAG, "Error invoking onPageStop: ${e.message}")
                }
                if (success) {
                    val handler = Handler(Looper.getMainLooper())
                    handler.postDelayed({
                        injectGeolocationMock(s)
                        injectJSBridge(s, serverPort)
                        geckoView.requestFocus()
                    }, 300)
                }
            }
        }

        session.contentDelegate = object : GeckoSession.ContentDelegate {
            override fun onTitleChange(s: GeckoSession, title: String?) {
                Log.d(TAG, "Title changed for tab: $title")
                updateTab(s, title = title ?: "")
                try {
                    methodChannel.invokeMethod(
                        "onTitleChange",
                        mapOf("title" to (title ?: ""))
                    )
                } catch (e: Exception) {
                    Log.e(TAG, "Error invoking onTitleChange: ${e.message}")
                }
            }
        }

        session.permissionDelegate = object : GeckoSession.PermissionDelegate {
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

        Log.d(TAG, "setupSession called for session: $session")
        session.navigationDelegate = object : GeckoSession.NavigationDelegate {
            override fun onNewSession(s: GeckoSession, uri: String): GeckoResult<GeckoSession>? {
                Log.d(TAG, "onNewSession called: $uri")
                val newSession = GeckoSession()
                setupSession(newSession, serverPort)
                addTab(newSession, uri)
                return GeckoResult.fromValue(newSession)
            }

            override fun onCanGoBack(session: GeckoSession, canGoBack: Boolean) {
                Log.d(TAG, "onCanGoBack changed: $canGoBack for session")
                currentTabCanGoBack = canGoBack
                val index = tabStack.indexOfFirst { it.session == session }
                if (index >= 0) {
                    val oldTab = tabStack[index]
                    tabStack[index] = oldTab.copy(canGoBack = canGoBack)
                }
                Log.d(TAG, "currentTabCanGoBack updated to: $currentTabCanGoBack")
                notifyTabStackChanged()
            }

            override fun onCanGoForward(session: GeckoSession, canGoForward: Boolean) {
                Log.d(TAG, "onCanGoForward changed: $canGoForward for session")
                currentTabCanGoForward = canGoForward
                val index = tabStack.indexOfFirst { it.session == session }
                if (index >= 0) {
                    val oldTab = tabStack[index]
                    tabStack[index] = oldTab.copy(canGoForward = canGoForward)
                }
                notifyTabStackChanged()
            }
        }
        Log.d(TAG, "NavigationDelegate set for session: $session")
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

    private fun injectGeolocationMock(session: GeckoSession) {
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
        session.loadUri("javascript:$mockScript")
    }

    private fun injectJSBridge(session: GeckoSession, serverPort: Int) {
        val bridgeScript = """
            window.isFlutterApp = true;
            if (!window.ReactNativeWebView) {
                window.ReactNativeWebView = {
                    postMessage: function(message) {
                        var xhr = new XMLHttpRequest();
                        xhr.open('GET', 'http://localhost:$serverPort/__flutter_bridge__?message=' + encodeURIComponent(message), true);
                        xhr.send();
                    }
                };
            }
            (function() {
                var lastUrl = window.location.href;
                var lastTitle = document.title;
                function notifyChange() {
                    var currentUrl = window.location.href;
                    var currentTitle = document.title;
                    if (currentUrl !== lastUrl || currentTitle !== lastTitle) {
                        lastUrl = currentUrl;
                        lastTitle = currentTitle;
                        try {
                            window.ReactNativeWebView.postMessage(JSON.stringify({type: 'url_change', url: currentUrl, title: currentTitle}));
                        } catch(e) {}
                    }
                }
                setInterval(notifyChange, 100);
            })();
        """.trimIndent()
        session.loadUri("javascript:$bridgeScript")
    }
}

class GeckoViewPlatform(
    private val context: Context,
    messenger: BinaryMessenger,
    id: Int,
    creationParams: Map<String, Any>?
) : PlatformView, MethodChannel.MethodCallHandler {

    private val TAG = "GeckoViewPlatform"
    private val geckoView: GeckoView
    private val methodChannel: MethodChannel
    private val handler = Handler(Looper.getMainLooper())
    private val serverPort: Int
    private lateinit var tabManager: TabManager

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

        val isDarkMode = creationParams?.get("isDarkMode") as? Boolean ?: true
        val bgColor = if (isDarkMode) {
            android.graphics.Color.BLACK
        } else {
            android.graphics.Color.WHITE
        }

        serverPort = creationParams?.get("serverPort") as? Int ?: 8080

        // 使用自定义的 GeckoViewWrapper 来增强焦点和输入法支持
        geckoView = GeckoViewWrapper(context).apply {
            setBackgroundColor(bgColor)

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

        // 初始化 tab manager（必须在使用 tabManager 之前）
        tabManager = TabManager(context, methodChannel, geckoView)

        // 创建初始会话并设置到 tab manager
        val initialUrl = creationParams?.get("initialUrl") as? String ?: "http://localhost:8080/"
        val session = GeckoSession()
        session.open(getRuntime(context))
        tabManager.setupSession(session, serverPort)
        val tabSession = TabSession(session, initialUrl, "")
        tabManager.tabStack.add(tabSession)
        tabManager.currentTabIndex = 0
        geckoView.setSession(session)
        session.loadUri(initialUrl)
        tabManager.notifyTabStackChanged()
        
        // 设置返回键监听（必须在 tabManager 初始化之后）
        geckoView.setOnKeyListener { v, keyCode, event ->
            if (keyCode == android.view.KeyEvent.KEYCODE_BACK && event.action == android.view.KeyEvent.ACTION_UP) {
                Log.d("GeckoViewPlatform", "Back button pressed")
                val currentTab = tabManager.currentTab
                val currentSession = tabManager.currentSession
                val canGoBack = tabManager.currentTabCanGoBack
                
                if (currentTab != null && currentSession != null) {
                    if (canGoBack) {
                        // 有历史记录，返回页面内历史
                        Log.d("GeckoViewPlatform", "Going back in page history")
                        currentSession.goBack()
                    } else if (tabManager.tabCount > 1) {
                        // 没有历史记录但有多个标签，关闭当前标签
                        Log.d("GeckoViewPlatform", "No history, closing current tab")
                        tabManager.closeCurrentTab()
                    } else {
                        // 只有一个标签且没有历史，请求退出App
                        Log.d("GeckoViewPlatform", "No history and only one tab, requesting exit")
                        tabManager.requestExitApp()
                    }
                }
                true
            } else {
                false
            }
        }
    }

    override fun getView(): View {
        return geckoView
    }

    override fun dispose() {
        val currentSession = tabManager.currentSession
        if (currentSession != null) {
            currentSession.close()
        }
        methodChannel.setMethodCallHandler(null)
    }

    private var lastGeolocationCallback: String? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "loadUrl" -> {
                val url = call.argument<String>("url")
                if (url != null) {
                    val currentSession = tabManager.currentSession
                    if (currentSession != null) {
                        currentSession.loadUri(url)
                    }
                    result.success(null)
                } else {
                    result.error("INVALID_URL", "URL is null", null)
                }
            }
            "evaluateJavascript" -> {
                val script = call.argument<String>("script")
                if (script != null) {
                    val currentSession = tabManager.currentSession
                    if (currentSession != null) {
                        currentSession.loadUri("javascript:$script")
                    }
                    result.success(null)
                } else {
                    result.error("INVALID_SCRIPT", "Script is null", null)
                }
            }
            "postMessage" -> {
                val message = call.argument<String>("message")
                if (message != null) {
                    val currentSession = tabManager.currentSession
                    if (currentSession != null) {
                        currentSession.loadUri("javascript:if (window.onFlutterMessage) { window.onFlutterMessage($message); }")
                    }
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
                    val currentSession = tabManager.currentSession
                    if (currentSession != null) {
                        currentSession.loadUri("javascript:$js")
                    }
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
                val currentSession = tabManager.currentSession
                if (currentSession != null) {
                    currentSession.loadUri("javascript:$js")
                }
                result.success(null)
            }
            "closeCurrentTab" -> {
                val resultValue = tabManager.closeCurrentTab()
                result.success(resultValue)
            }
            "closeTab" -> {
                val tabId = call.argument<Long>("tabId")
                if (tabId != null) {
                    val resultValue = tabManager.closeTab(tabId)
                    result.success(resultValue)
                } else {
                    result.error("INVALID_TAB_ID", "Tab id is null", null)
                }
            }
            "goBackToPreviousTab" -> {
                val resultValue = tabManager.goBackToPreviousTab()
                result.success(resultValue)
            }
            "getTabsInfo" -> {
                result.success(tabManager.getTabsInfo())
            }
            "goBack" -> {
                Log.d(TAG, "goBack called, currentSession: ${tabManager.currentSession}")
                val currentSession = tabManager.currentSession
                currentSession?.goBack()
                result.success(null)
            }
            "goForward" -> {
                Log.d(TAG, "goForward called, currentSession: ${tabManager.currentSession}")
                val currentSession = tabManager.currentSession
                currentSession?.goForward()
                result.success(null)
            }
            "reload" -> {
                Log.d(TAG, "reload called, currentSession: ${tabManager.currentSession}")
                val currentSession = tabManager.currentSession
                currentSession?.reload()
                result.success(null)
            }
            "openInBrowser" -> {
                val url = call.argument<String>("url")
                if (url != null) {
                    Log.d(TAG, "openInBrowser called with url: $url, context: ${context}")
                    try {
                        val uri = android.net.Uri.parse(url)
                        Log.d(TAG, "Parsed URI: $uri")
                        val intent = android.content.Intent(android.content.Intent.ACTION_VIEW, uri)
                        intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                        Log.d(TAG, "Starting activity with intent: $intent")
                        context.startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error opening in browser: ${e.message}", e)
                        result.error("OPEN_BROWSER_ERROR", e.message, null)
                    }
                } else {
                    Log.e(TAG, "openInBrowser called with null url")
                    result.error("INVALID_URL", "URL is null", null)
                }
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

    init {
        Log.d(TAG, "GeckoViewWrapper initialized")
        // 确保可以获取焦点
        isFocusable = true
        isFocusableInTouchMode = true
        isClickable = true
        isFocusedByDefault = true
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
