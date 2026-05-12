
package club.aiiko.trip

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "flutter_background"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "geckoView",
            GeckoViewFactory(flutterEngine.dartExecutor.binaryMessenger)
        )

        // 注册 flutter_background MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startBackgroundService" -> {
                    startBackgroundService()
                    result.success(null)
                }
                "stopBackgroundService" -> {
                    stopBackgroundService()
                    result.success(null)
                }
                "updateNotification" -> {
                    val title = call.argument<String>("taskTitle")
                    val desc = call.argument<String>("taskDesc")
                    updateNotification(title, desc)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun startBackgroundService() {
        val intent = Intent(this, BackgroundService::class.java)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopBackgroundService() {
        val intent = Intent(this, BackgroundService::class.java)
        stopService(intent)
    }

    private fun updateNotification(title: String?, desc: String?) {
        if (BackgroundService.isRunning) {
            // 通过 Intent 发送更新通知的请求给 BackgroundService
            val intent = Intent(this, BackgroundService::class.java)
            intent.putExtra("action", "update")
            intent.putExtra("title", title)
            intent.putExtra("desc", desc)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 确保窗口软输入模式正确设置
        window.setSoftInputMode(android.view.WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
    }
}
