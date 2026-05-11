package club.aiiko.trip

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.view.View
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

    companion object {
        private var geckoRuntime: GeckoRuntime? = null
        
        fun getRuntime(context: Context): GeckoRuntime {
            if (geckoRuntime == null) {
                val settings = GeckoRuntimeSettings.Builder()
                    .javaScriptEnabled(true)
                    .remoteDebuggingEnabled(true)
                    .build()
                geckoRuntime = GeckoRuntime.create(context, settings)
            }
            return geckoRuntime!!
        }
    }

    init {
        methodChannel = MethodChannel(messenger, "gecko_view_$id")
        methodChannel.setMethodCallHandler(this)

        geckoView = GeckoView(context).apply {
            setBackgroundColor(android.graphics.Color.BLACK)
        }
        geckoSession = GeckoSession()

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

        // 设置进度监听
        geckoSession.progressDelegate = object : GeckoSession.ProgressDelegate {
            override fun onPageStart(session: GeckoSession, url: String) {
                isLoading = true
                methodChannel.invokeMethod("onPageStart", mapOf("url" to url))
            }

            override fun onPageStop(session: GeckoSession, success: Boolean) {
                isLoading = false
                methodChannel.invokeMethod("onPageStop", mapOf("success" to success))
                if (success) {
                    injectGeolocationMock()
                }
            }
        }

        // 打开 session
        geckoSession.open(getRuntime(context))
        geckoView.setSession(geckoSession)

        // 加载初始 URL
        val initialUrl = creationParams?.get("initialUrl") as? String ?: "https://trip.aiiko.club/zh-CN"
        geckoSession.loadUri(initialUrl)
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

    override fun getView(): View {
        return geckoView
    }

    override fun dispose() {
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

    private var lastGeolocationCallback: String? = null

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
                    geckoSession.loadUri("javascript:if (window.postMessage) { window.postMessage($message, '*'); }")
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
            else -> result.notImplemented()
        }
    }
}
