package club.aiiko.trip

import android.content.Intent
import android.content.pm.PackageManager
import android.content.ComponentName
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "flutter_background"
    private val BYD_CHANNEL = "byd_vehicle"
    private val LANGUAGE_CHANNEL = "app_language"
    private val NOTIFICATION_CLICK_CHANNEL = "notification_click"

    private var bydVehicleService: BYDAutoVehicleService? = null
    private var bydMethodChannel: MethodChannel? = null
    private var isBydServiceAvailable = false

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LANGUAGE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateAppTitle" -> {
                    val title = call.argument<String>("title")
                    updateAppTitle(title)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CLICK_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openApp" -> {
                    openApp()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        bydMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BYD_CHANNEL)
        bydMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startCarDataUpdates" -> {
                    if (bydVehicleService == null) {
                        try {
                            bydVehicleService = BYDAutoVehicleService(applicationContext)
                            bydVehicleService?.setMethodChannel(bydMethodChannel!!)
                            isBydServiceAvailable = true
                        } catch (e: Exception) {
                            e.printStackTrace()
                            isBydServiceAvailable = false
                        }
                    }
                    if (isBydServiceAvailable) {
                        bydVehicleService?.start()
                    }
                    result.success(null)
                }
                "stopCarDataUpdates" -> {
                    if (isBydServiceAvailable) {
                        bydVehicleService?.stop()
                    }
                    result.success(null)
                }
                "requestCarData" -> {
                    if (isBydServiceAvailable && bydVehicleService != null) {
                        bydVehicleService?.requestCarData()
                    } else {
                        sendEmptyCarData()
                    }
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun openApp() {
        val intent = Intent(this, MainActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        startActivity(intent)
    }

    private fun sendEmptyCarData() {
        try {
            val emptyData = mapOf(
                "speed" to 0.0,
                "elecPercentage" to 0.0,
                "fuelPercentage" to 0,
                "accelerateDepth" to 0,
                "brakeDepth" to 0,
                "totalMileage" to 0,
                "evMileage" to 0,
                "tyrePressure" to mapOf(
                    "leftFront" to 0,
                    "rightFront" to 0,
                    "leftRear" to 0,
                    "rightRear" to 0
                ),
                "timestamp" to System.currentTimeMillis()
            )
            val jsonString = org.json.JSONObject(emptyData).toString()
            bydMethodChannel?.invokeMethod("onCarDataChanged", jsonString)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun startBackgroundService() {
        val intent = Intent(this, BackgroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
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
            val intent = Intent(this, BackgroundService::class.java)
            intent.putExtra("action", "update")
            intent.putExtra("title", title)
            intent.putExtra("desc", desc)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        }
    }

    private fun updateAppTitle(title: String?) {
        try {
            if (title.isNullOrEmpty()) return
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1) {
                val shortcutManager = getSystemService(ShortcutManager::class.java)
                if (shortcutManager != null) {
                    val shortcutInfo = ShortcutInfo.Builder(this, "app_launcher")
                        .setShortLabel(title)
                        .setLongLabel(title)
                        .setIntent(Intent(Intent.ACTION_MAIN).apply {
                            setClass(this@MainActivity, MainActivity::class.java)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        })
                        .build()
                    shortcutManager.updateShortcuts(listOf(shortcutInfo))
                }
            }
            
            val componentName = ComponentName(this, MainActivity::class.java)
            packageManager.setComponentEnabledSetting(
                componentName,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
            packageManager.setComponentEnabledSetting(
                componentName,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
            
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setSoftInputMode(android.view.WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
    }
}
