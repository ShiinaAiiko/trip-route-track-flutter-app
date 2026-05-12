
package club.aiiko.trip

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "flutter_background"
    private lateinit var backgroundService: BackgroundService
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "geckoView",
            GeckoViewFactory(flutterEngine.dartExecutor.binaryMessenger)
        )
        
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
                    val taskTitle = call.argument<String>("taskTitle")
                    val taskDesc = call.argument<String>("taskDesc")
                    updateNotification(taskTitle, taskDesc)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setSoftInputMode(android.view.WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
    }
    
    private fun startBackgroundService() {
        if (!::backgroundService.isInitialized || !BackgroundService.isRunning) {
            val intent = Intent(this, BackgroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        }
    }
    
    private fun stopBackgroundService() {
        if (::backgroundService.isInitialized && BackgroundService.isRunning) {
            val intent = Intent(this, BackgroundService::class.java)
            stopService(intent)
        }
    }
    
    private fun updateNotification(title: String?, desc: String?) {
        if (::backgroundService.isInitialized && BackgroundService.isRunning) {
            backgroundService.updateNotification(title, desc)
        }
    }
}
