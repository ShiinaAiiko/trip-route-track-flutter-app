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
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val CHANNEL = "flutter_background"
    private val BYD_CHANNEL = "byd_vehicle"
    private val LANGUAGE_CHANNEL = "app_language"
    private val NOTIFICATION_CLICK_CHANNEL = "notification_click"

    private val REQUEST_CODE_BYDAUTO_PERMISSIONS = 1001

    private var bydVehicleService: BYDAutoVehicleService? = null
    private var bydMethodChannel: MethodChannel? = null
    private var isBydServiceAvailable = false
    private var pendingStartCarData = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sendCarLog("configureFlutterEngine 被调用")
        
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "geckoView",
            GeckoViewFactory(flutterEngine.dartExecutor.binaryMessenger)
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startBackgroundService" -> {
                    sendCarLog("收到 startBackgroundService 调用")
                    startBackgroundService()
                    result.success(null)
                }
                "stopBackgroundService" -> {
                    sendCarLog("收到 stopBackgroundService 调用")
                    stopBackgroundService()
                    result.success(null)
                }
                "updateNotification" -> {
                    val title = call.argument<String>("taskTitle")
                    val desc = call.argument<String>("taskDesc")
                    sendCarLog("收到 updateNotification 调用, title: $title, desc: $desc")
                    updateNotification(title, desc)
                    result.success(null)
                }
                else -> {
                    sendCarLog("未实现的方法调用: ${call.method}")
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LANGUAGE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateAppTitle" -> {
                    val title = call.argument<String>("title")
                    sendCarLog("收到 updateAppTitle 调用, title: $title")
                    updateAppTitle(title)
                    result.success(null)
                }
                else -> {
                    sendCarLog("未实现的方法调用: ${call.method}")
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CLICK_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openApp" -> {
                    sendCarLog("收到 openApp 调用")
                    openApp()
                    result.success(null)
                }
                else -> {
                    sendCarLog("未实现的方法调用: ${call.method}")
                    result.notImplemented()
                }
            }
        }

        bydMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BYD_CHANNEL)
        bydMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startCarDataUpdates" -> {
                    sendCarLog("收到 startCarDataUpdates 调用")
                    if (bydVehicleService == null) {
                        try {
                            sendCarLog("开始初始化 BYDAutoVehicleService")
                            bydVehicleService = BYDAutoVehicleService(applicationContext)
                            bydVehicleService?.setMethodChannel(bydMethodChannel!!)
                            isBydServiceAvailable = true
                            sendCarLog("BYDAutoVehicleService 初始化成功")
                        } catch (e: Exception) {
                            sendCarLog("BYDAutoVehicleService 初始化失败: ${e.message}")
                            sendCarLog("异常堆栈: ${e.stackTraceToString()}")
                            isBydServiceAvailable = false
                        }
                    }
                    if (isBydServiceAvailable && bydVehicleService != null) {
                        if (bydVehicleService?.hasRequiredPermissions() == true) {
                            sendCarLog("权限检查通过，启动车机数据监听")
                            bydVehicleService?.start()
                        } else {
                            sendCarLog("权限检查失败，准备申请权限")
                            pendingStartCarData = true
                            requestBydAutoPermissions()
                        }
                    }
                    result.success(null)
                }
                "stopCarDataUpdates" -> {
                    sendCarLog("收到 stopCarDataUpdates 调用")
                    if (isBydServiceAvailable) {
                        bydVehicleService?.stop()
                    }
                    result.success(null)
                }
                "requestCarData" -> {
                    sendCarLog("收到 requestCarData 调用")
                    if (isBydServiceAvailable && bydVehicleService != null) {
                        bydVehicleService?.requestCarData()
                    } else {
                        sendCarLog("BYD服务不可用，发送空数据")
                        sendEmptyCarData()
                    }
                    result.success(null)
                }
                "hasBydPermissions" -> {
                    sendCarLog("收到 hasBydPermissions 调用")
                    val hasPerms = bydVehicleService?.hasRequiredPermissions() ?: false
                    sendCarLog("hasBydPermissions 返回: $hasPerms")
                    result.success(hasPerms)
                }
                "requestBydPermissions" -> {
                    sendCarLog("收到 requestBydPermissions 调用")
                    requestBydAutoPermissions()
                    result.success(null)
                }
                else -> {
                    sendCarLog("未实现的方法调用: ${call.method}")
                    result.notImplemented()
                }
            }
        }
    }

    private fun requestBydAutoPermissions() {
        sendCarLog("requestBydAutoPermissions 被调用")
        bydVehicleService?.getRequiredPermissions()?.let { permissions ->
            sendCarLog("请求权限: ${permissions.joinToString()}")
            requestPermissions(permissions, REQUEST_CODE_BYDAUTO_PERMISSIONS)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        sendCarLog("onRequestPermissionsResult 被调用")
        sendCarLog("requestCode: $requestCode")
        sendCarLog("permissions: ${permissions.joinToString()}")
        sendCarLog("grantResults: ${grantResults.joinToString()}")
        
        if (requestCode == REQUEST_CODE_BYDAUTO_PERMISSIONS) {
            val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            sendCarLog("权限是否全部授予: $allGranted")
            
            if (allGranted && pendingStartCarData) {
                sendCarLog("权限授予成功，启动车机数据监听")
                bydVehicleService?.start()
                pendingStartCarData = false
            } else if (!allGranted) {
                sendCarLog("部分权限被拒绝")
            }
        }
    }

    private fun openApp() {
        sendCarLog("openApp 被调用")
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
            val jsonString = JSONObject(emptyData).toString()
            bydMethodChannel?.invokeMethod("onCarDataChanged", jsonString)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun startBackgroundService() {
        sendCarLog("startBackgroundService 被调用")
        val intent = Intent(this, BackgroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopBackgroundService() {
        sendCarLog("stopBackgroundService 被调用")
        val intent = Intent(this, BackgroundService::class.java)
        stopService(intent)
    }

    private fun updateNotification(title: String?, desc: String?) {
        sendCarLog("updateNotification 被调用, title: $title, desc: $desc")
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
        sendCarLog("updateAppTitle 被调用, title: $title")
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
            sendCarLog("updateAppTitle 失败: ${e.message}")
            sendCarLog("异常堆栈: ${e.stackTraceToString()}")
        }
    }

    private fun sendCarLog(log: String) {
        try {
            val logData = mapOf(
                "type" to "carlog",
                "message" to log
            )
            val jsonString = JSONObject(logData).toString()
            bydMethodChannel?.invokeMethod("onCarDataChanged", jsonString)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setSoftInputMode(android.view.WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
    }
}
