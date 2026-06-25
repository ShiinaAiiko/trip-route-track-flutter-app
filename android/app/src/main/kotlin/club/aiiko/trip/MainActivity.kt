package club.aiiko.trip

import android.content.Intent
import android.content.pm.PackageManager
import android.content.ComponentName
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInAccount
import com.google.android.gms.auth.api.signin.GoogleSignInClient
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.tasks.Task

class MainActivity : FlutterActivity() {
    private val CHANNEL = "flutter_background"
    private val BYD_CHANNEL = "byd_vehicle"
    private val LANGUAGE_CHANNEL = "app_language"
    private val NOTIFICATION_CLICK_CHANNEL = "notification_click"
    private val FLUTTER_BRIDGE_CHANNEL = "flutter_bridge"
    private val LOG_CHANNEL = "log_service"
    private val WEBVIEW_CHANNEL = "nyanya/webview"
    private val DEEP_LINK_CHANNEL = "deep_link"
    private val QQ_CHANNEL = "qq_login"
    private val APP_INFO_CHANNEL = "app_info"
    
    private var deepLinkChannel: MethodChannel? = null
    private var initialDeepLink: String? = null

    private val REQUEST_CODE_BYDAUTO_PERMISSIONS = 1001
    private val INSTALL_PERMISSION_REQUEST_CODE = 1002
    private val REQUEST_CODE_GOOGLE_SIGN_IN = 1003

    private var bydVehicleService: BYDAutoVehicleService? = null
    private var bydMethodChannel: MethodChannel? = null
    private var logMethodChannel: MethodChannel? = null
    private var isBydServiceAvailable = false
    private var pendingStartCarData = false
    private var pendingApkPath: String? = null
    
    // 测试服务
    private var testBYDAutoVehicleService: TestBYDAutoVehicleService? = null
    
    // Google Sign-In
    private lateinit var googleSignInClient: GoogleSignInClient
    private var pendingThirdPartyLoginResult: ((Map<String, Any>) -> Unit)? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sendLog("app", "configureFlutterEngine 被调用")
        
        // 初始化Google Sign-In
        initGoogleSignIn()

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
                    sendLog("app", "未实现的方法调用: ${call.method}")
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
                    sendLog("app", "未实现的方法调用: ${call.method}")
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
                "installApk" -> {
                    val path = call.argument<String>("path")
                    installApk(path)
                    result.success(null)
                }
                else -> {
                    sendLog("app", "未实现的方法调用: ${call.method}")
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FLUTTER_BRIDGE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val path = call.argument<String>("path")
                    installApk(path)
                    result.success(null)
                }
                "restartApp" -> {
                    restartApp()
                    result.success(null)
                }
                "quitApp" -> {
                    quitApp()
                    result.success(null)
                }
                "closeLocalServer" -> {
                    sendLog("app", "closeLocalServer 被调用")
                    result.success(null)
                }
                "thirdPartyLogin" -> {
                    val type = call.argument<String>("type")
                    handleThirdPartyLogin(type, result)
                }
                else -> {
                    sendLog("app", "未实现的方法调用 (flutter_bridge): ${call.method}")
                    result.notImplemented()
                }
            }
        }

        // QQ 登录权限授权
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, QQ_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setPermissionGranted" -> {
                    try {
                        // 使用反射调用 QQ SDK 的 setIsPermissionGranted 方法
                        val tencentClass = Class.forName("com.tencent.tauth.Tencent")
                        val method = tencentClass.getMethod("setIsPermissionGranted", Boolean::class.javaPrimitiveType, String::class.java)
                        method.invoke(null, true, Build.MODEL)
                        sendLog("app", "QQ权限已授权: ${Build.MODEL}")
                        result.success(true)
                    } catch (e: Exception) {
                        sendLog("app", "QQ权限授权失败: ${e.message}")
                        result.success(false)
                    }
                }
                else -> {
                    sendLog("app", "未实现的QQ方法调用: ${call.method}")
                    result.notImplemented()
                }
            }
        }

        bydMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BYD_CHANNEL)
        
        // 初始化测试服务
        testBYDAutoVehicleService = TestBYDAutoVehicleService(bydMethodChannel)
        testBYDAutoVehicleService?.setLogCallback { log -> sendCarLog(log) }
        
        bydMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startCarDataUpdates" -> {
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
                        val hasAllPerms = bydVehicleService?.hasRequiredPermissions() == true
                        if (hasAllPerms) {
                            sendCarLog("权限检查通过 (全部权限)，启动车机数据监听")
                            bydVehicleService?.start()
                        } else {
                            // 部分权限被拒绝，但仍尝试启动服务（有反射降级逻辑）
                            val hasAnyPerms = bydVehicleService?.hasAnyPermission() == true
                            if (hasAnyPerms) {
                                sendCarLog("权限检查: 部分权限通过，尝试启动车机数据监听")
                                bydVehicleService?.start()
                            } else {
                                sendCarLog("权限检查失败 (无任何权限)，准备申请权限")
                                pendingStartCarData = true
                                requestBydAutoPermissions()
                            }
                        }
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
                        sendCarLog("BYD服务不可用，发送空数据")
                        sendEmptyCarData()
                    }
                    result.success(null)
                }
                "hasBydPermissions" -> {
                    val hasPerms = bydVehicleService?.hasRequiredPermissions() ?: false
                    sendCarLog("hasBydPermissions 返回: $hasPerms")
                    result.success(hasPerms)
                }
                "requestBydPermissions" -> {
                    requestBydAutoPermissions()
                    result.success(null)
                }
                "checkBydPermissions" -> {
                    val permissionTypes = call.arguments as? List<String> ?: emptyList()
                    val results = mutableMapOf<String, Boolean>()
                    val allBydPermissions = bydVehicleService?.getRequiredPermissions() ?: emptyArray()
                    
                    for (type in permissionTypes) {
                        val fullPermissionName = mapToBydPermissionString(type)
                        val hasPermission = allBydPermissions.contains(fullPermissionName) && 
                            checkSelfPermission(fullPermissionName) == PackageManager.PERMISSION_GRANTED
                        results[type] = hasPermission
                    }
                    
                    sendCarLog("checkBydPermissions 结果: $results")
                    result.success(results)
                }
                // ==================== 车速类接口 ====================
                "getSpeedData" -> {
                    val data = bydVehicleService?.getSpeedData(true) ?: emptyMap<String, Any?>()
                    result.success(data)
                }
                "enableSpeedListener" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    bydVehicleService?.enableSpeedListener(enabled)
                    result.success(null)
                }
                // ==================== 空调类接口 ====================
                "getAcData" -> {
                    val data = bydVehicleService?.getAcData(true) ?: emptyMap<String, Any?>()
                    result.success(data)
                }
                "enableAcListener" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    bydVehicleService?.enableAcListener(enabled)
                    result.success(null)
                }
                "setAcData" -> {
                    val field = call.argument<String>("field") ?: ""
                    val value = call.argument<Any>("value")
                    if (value != null) {
                        val success = bydVehicleService?.setAcData(field, value) ?: false
                        result.success(mapOf("success" to success))
                    } else {
                        result.success(mapOf("success" to false))
                    }
                }
                // ==================== 行驶数据类型接口 ====================
                "getStatisticData" -> {
                    val data = bydVehicleService?.getStatisticData(true) ?: emptyMap<String, Any?>()
                    result.success(data)
                }
                "enableStatisticListener" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    bydVehicleService?.enableStatisticListener(enabled)
                    result.success(null)
                }
                "setStatisticData" -> {
                    val field = call.argument<String>("field") ?: ""
                    val value = call.argument<Any>("value")
                    if (value != null) {
                        val success = bydVehicleService?.setStatisticData(field, value) ?: false
                        result.success(mapOf("success" to success))
                    } else {
                        result.success(mapOf("success" to false))
                    }
                }
                // ==================== 仪表类接口 ====================
                "getInstrumentData" -> {
                    val data = bydVehicleService?.getInstrumentData(true) ?: emptyMap<String, Any?>()
                    result.success(data)
                }
                "enableInstrumentListener" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    bydVehicleService?.enableInstrumentListener(enabled)
                    result.success(null)
                }
                "setInstrumentData" -> {
                    val field = call.argument<String>("field") ?: ""
                    val value = call.argument<Any>("value")
                    if (value != null) {
                        val success = bydVehicleService?.setInstrumentData(field, value) ?: false
                        result.success(mapOf("success" to success))
                    } else {
                        result.success(mapOf("success" to false))
                    }
                }
                "setInstrumentUnit" -> {
                    val unitName = call.argument<Int>("unitName") ?: 0
                    val unitValue = call.argument<Int>("unitValue") ?: 0
                    val success = bydVehicleService?.setInstrumentUnit(unitName, unitValue) ?: false
                    result.success(mapOf("success" to success))
                }
                "setMaintenanceInfo" -> {
                    val typeName = call.argument<Int>("typeName") ?: 0
                    val infoValue = call.argument<Int>("infoValue") ?: 0
                    val success = bydVehicleService?.setMaintenanceInfo(typeName, infoValue) ?: false
                    result.success(mapOf("success" to success))
                }
                // ==================== 门锁类接口 ====================
                "getDoorData" -> {
                    val data = bydVehicleService?.getDoorData(true) ?: emptyMap<String, Any?>()
                    result.success(data)
                }
                "enableDoorListener" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    bydVehicleService?.enableDoorListener(enabled)
                    result.success(null)
                }
                "setDoorData" -> {
                    val field = call.argument<String>("field") ?: ""
                    val value = call.argument<Any>("value")
                    if (value != null) {
                        val success = bydVehicleService?.setDoorData(field, value) ?: false
                        result.success(mapOf("success" to success))
                    } else {
                        result.success(mapOf("success" to false))
                    }
                }
                // ==================== 车辆设置类接口 ====================
                "getVehicleSettingData" -> {
                    val data = bydVehicleService?.getVehicleSettingData(true) ?: emptyMap<String, Any?>()
                    result.success(data)
                }
                "enableVehicleSettingListener" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    bydVehicleService?.enableVehicleSettingListener(enabled)
                    result.success(null)
                }
                "setVehicleSettingData" -> {
                    val field = call.argument<String>("field") ?: ""
                    val value = call.argument<Any>("value")
                    if (value != null) {
                        val success = bydVehicleService?.setVehicleSettingData(field, value) ?: false
                        result.success(mapOf("success" to success))
                    } else {
                        result.success(mapOf("success" to false))
                    }
                }
                "vehicleSettingHasFeature" -> {
                    val feature = call.argument<String>("feature") ?: ""
                    val hasFeature = bydVehicleService?.vehicleSettingHasFeature(feature) ?: false
                    result.success(mapOf("hasFeature" to hasFeature))
                }
                // ==================== 发动机类接口 ====================
                "getEngineData" -> {
                    val data = bydVehicleService?.getEngineData(true) ?: emptyMap<String, Any?>()
                    result.success(data)
                }
                "enableEngineListener" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    bydVehicleService?.enableEngineListener(enabled)
                    result.success(null)
                }
                "setEngineData" -> {
                    val field = call.argument<String>("field") ?: ""
                    val value = call.argument<Any>("value")
                    if (value != null) {
                        val success = bydVehicleService?.setEngineData(field, value) ?: false
                        result.success(mapOf("success" to success))
                    } else {
                        result.success(mapOf("success" to false))
                    }
                }
                // ==================== 车辆数据分类字段获取接口 ====================
                "getCarGetField" -> {
                    val category = call.argument<String>("category") ?: ""
                    val field = call.argument<String>("field")
                    sendCarLog("getCarGetField category: $category, field: $field")
                    when (category) {
                        "engine" -> {
                            val data = bydVehicleService?.getEngineData(true, field)
                            result.success(data)
                        }
                        else -> {
                            result.success(null)
                        }
                    }
                }
                // ==================== 全景摄像头类接口 ====================
                "getPanoramaData" -> {
                    val data = bydVehicleService?.getPanoramaData(true) ?: emptyMap<String, Any?>()
                    result.success(data)
                }
                "enablePanoramaListener" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    bydVehicleService?.enablePanoramaListener(enabled)
                    result.success(null)
                }
                "setPanoramaData" -> {
                    val field = call.argument<String>("field") ?: ""
                    val value = call.argument<Any>("value")
                    if (value != null) {
                        val success = bydVehicleService?.setPanoramaData(field, value) ?: false
                        result.success(mapOf("success" to success))
                    } else {
                        result.success(mapOf("success" to false))
                    }
                }
                // ==================== 传感器类接口 ====================
                "getSensorData" -> {
                    val data = bydVehicleService?.getSensorData(true) ?: emptyMap<String, Any?>()
                    result.success(data)
                }
                "enableSensorListener" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    bydVehicleService?.enableSensorListener(enabled)
                    result.success(null)
                }
                "setSensorData" -> {
                    val field = call.argument<String>("field") ?: ""
                    val value = call.argument<Any>("value")
                    if (value != null) {
                        val success = bydVehicleService?.setSensorData(field, value) ?: false
                        result.success(mapOf("success" to success))
                    } else {
                        result.success(mapOf("success" to false))
                    }
                }
                // ==================== 时间类接口 ====================
                "getTimeData" -> {
                    val data = bydVehicleService?.getTimeData(true) ?: emptyMap<String, Any?>()
                    result.success(data)
                }
                "enableTimeListener" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    bydVehicleService?.enableTimeListener(enabled)
                    result.success(null)
                }
                "setTimeData" -> {
                    val field = call.argument<String>("field") ?: ""
                    val value = call.argument<Any>("value")
                    if (value != null) {
                        val success = bydVehicleService?.setTimeData(field, value) ?: false
                        result.success(mapOf("success" to success))
                    } else {
                        result.success(mapOf("success" to false))
                    }
                }
                // ==================== 能量模式类接口 ====================
                "getEnergyModeData" -> {
                    val data = bydVehicleService?.getEnergyModeData(true) ?: emptyMap<String, Any?>()
                    result.success(data)
                }
                "enableEnergyModeListener" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    bydVehicleService?.enableEnergyModeListener(enabled)
                    result.success(null)
                }
                "setEnergyModeData" -> {
                    val field = call.argument<String>("field") ?: ""
                    val value = call.argument<Any>("value")
                    if (value != null) {
                        val success = bydVehicleService?.setEnergyModeData(field, value) ?: false
                        result.success(mapOf("success" to success))
                    } else {
                        result.success(mapOf("success" to false))
                    }
                }
                // ==================== 雷达类接口 ====================
                "getRadarData" -> {
                    val data = bydVehicleService?.getRadarData(true) ?: emptyMap<String, Any?>()
                    result.success(data)
                }
                "enableRadarListener" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    bydVehicleService?.enableRadarListener(enabled)
                    result.success(null)
                }
                "setRadarData" -> {
                    val field = call.argument<String>("field") ?: ""
                    val value = call.argument<Any>("value")
                    if (value != null) {
                        val success = bydVehicleService?.setRadarData(field, value) ?: false
                        result.success(mapOf("success" to success))
                    } else {
                        result.success(mapOf("success" to false))
                    }
                }
                // ==================== 轮胎类接口 ====================
                "getTyreData" -> {
                    val data = bydVehicleService?.getTyreData(true) ?: emptyMap<String, Any?>()
                    result.success(data)
                }
                "enableTyreListener" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    bydVehicleService?.enableTyreListener(enabled)
                    result.success(null)
                }
                "setTyreData" -> {
                    val field = call.argument<String>("field") ?: ""
                    val value = call.argument<Any>("value")
                    if (value != null) {
                        val success = bydVehicleService?.setTyreData(field, value) ?: false
                        result.success(mapOf("success" to success))
                    } else {
                        result.success(mapOf("success" to false))
                    }
                }
                // ==================== 空气质量类接口 ====================
                "getAirQualityData" -> {
                    val data = bydVehicleService?.getAirQualityData(true) ?: emptyMap<String, Any?>()
                    result.success(data)
                }
                "enableAirQualityListener" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    bydVehicleService?.enableAirQualityListener(enabled)
                    result.success(null)
                }
                "setAirQualityData" -> {
                    val field = call.argument<String>("field") ?: ""
                    val value = call.argument<Any>("value")
                    if (value != null) {
                        val success = bydVehicleService?.setAirQualityData(field, value) ?: false
                        result.success(mapOf("success" to success))
                    } else {
                        result.success(mapOf("success" to false))
                    }
                }
                // ==================== 充电类接口 ====================
                "getChargeData" -> {
                    val data = bydVehicleService?.getChargeData(true) ?: emptyMap<String, Any?>()
                    result.success(data)
                }
                "enableChargeListener" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    bydVehicleService?.enableChargeListener(enabled)
                    result.success(null)
                }
                "setChargeData" -> {
                    val field = call.argument<String>("field") ?: ""
                    val value = call.argument<Any>("value")
                    if (value != null) {
                        val success = bydVehicleService?.setChargeData(field, value) ?: false
                        result.success(mapOf("success" to success))
                    } else {
                        result.success(mapOf("success" to false))
                    }
                }
                // ==================== 媒体中心类接口 ====================
                "getMediaData" -> {
                    val data = bydVehicleService?.getMediaData(true) ?: emptyMap<String, Any?>()
                    result.success(data)
                }
                "enableMediaListener" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    bydVehicleService?.enableMediaListener(enabled)
                    result.success(null)
                }
                "setMediaData" -> {
                    val field = call.argument<String>("field") ?: ""
                    val value = call.argument<Any>("value")
                    if (value != null) {
                        val success = bydVehicleService?.setMediaData(field, value) ?: false
                        result.success(mapOf("success" to success))
                    } else {
                        result.success(mapOf("success" to false))
                    }
                }
                // ==================== 车身状态类接口 ====================
                "getBodyStatusData" -> {
                    val data = bydVehicleService?.getBodyStatusData(true) ?: emptyMap<String, Any?>()
                    result.success(data)
                }
                "enableBodyStatusListener" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    bydVehicleService?.enableBodyStatusListener(enabled)
                    result.success(null)
                }
                "setBodyStatusData" -> {
                    val field = call.argument<String>("field") ?: ""
                    val value = call.argument<Any>("value")
                    if (value != null) {
                        val success = bydVehicleService?.setBodyStatusData(field, value) ?: false
                        result.success(mapOf("success" to success))
                    } else {
                        result.success(mapOf("success" to false))
                    }
                }
                // ==================== 车灯类接口 ====================
                "getLightData" -> {
                    val data = bydVehicleService?.getLightData(true) ?: emptyMap<String, Any?>()
                    result.success(data)
                }
                "enableLightListener" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    bydVehicleService?.enableLightListener(enabled)
                    result.success(null)
                }
                "setLightData" -> {
                    val field = call.argument<String>("field") ?: ""
                    val value = call.argument<Any>("value")
                    if (value != null) {
                        val success = bydVehicleService?.setLightData(field, value) ?: false
                        result.success(mapOf("success" to success))
                    } else {
                        result.success(mapOf("success" to false))
                    }
                }
                "enableCarDataListener" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    bydVehicleService?.enableCarDataListener(enabled)
                    result.success(null)
                }
                "testCarData" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    testBYDAutoVehicleService?.testCarData(enabled)
                    result.success(true)
                }
                "setCarDataListenerDebounceDelay" -> {
                    val delayMs = call.argument<Int>("delayMs") ?: 0
                    bydVehicleService?.setCarDataListenerDebounceDelay(delayMs)
                    testBYDAutoVehicleService?.setCarDataListenerDebounceDelay(delayMs)
                    result.success(true)
                }
                "checkCarSDKAvailable" -> {
                    val available = bydVehicleService?.checkCarSDKAvailable() ?: false
                    result.success(available)
                }
                else -> {
                    sendCarLog("未实现的方法调用: ${call.method}")
                    result.notImplemented()
                }
            }
        }

        logMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOG_CHANNEL)
        logMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WEBVIEW_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSystemWebViewVersion" -> {
                    val version = getSystemWebViewVersion()
                    result.success(version)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // App Info Channel - 提供应用版本类型等信息
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_INFO_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getVersionType" -> {
                    result.success(BuildConfig.VERSION_TYPE)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Deep Link Channel
        deepLinkChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEEP_LINK_CHANNEL)
        deepLinkChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialLink" -> {
                    // 不要在这里清除 initialDeepLink，让它可以重复获取
                    result.success(initialDeepLink)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // 如果有初始 deep link，发送给 Flutter
        initialDeepLink?.let {
            deepLinkChannel?.invokeMethod("onDeepLink", it)
            // 不要清除 initialDeepLink，允许重复发送
        }
    }

    private fun getSystemWebViewVersion(): String {
        // 尝试获取不同设备上的WebView版本
        val webViewPackages = listOf(
            "com.google.android.webview",      // Google WebView
            "com.android.webview",             // AOSP WebView
            "com.huawei.webview",              // 华为 WebView
            "com.sec.android.app.sbrowser",    // 三星浏览器/WebView
            "com.miui.webview"                 // 小米 WebView
        )
        
        for (packageName in webViewPackages) {
            try {
                val packageInfo = packageManager.getPackageInfo(packageName, 0)
                val version = packageInfo.versionName
                if (version != null && version.isNotEmpty()) {
                    return version
                }
            } catch (e: Exception) {
                // 继续尝试下一个包名
            }
        }
        
        // 如果都获取不到，尝试使用WebView类的版本信息
        return try {
            val webViewClass = Class.forName("android.webkit.WebView")
            val versionField = webViewClass.getDeclaredField("WEB_VIEW_VERSION")
            versionField.isAccessible = true
            versionField.get(null) as String
        } catch (e: Exception) {
            "0"
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
            
            if (pendingStartCarData) {
                // 即使部分权限被拒绝，也尝试启动服务
                // BYDAutoVehicleService 有反射降级逻辑，可以处理部分权限缺失的情况
                val grantedCount = grantResults.count { it == PackageManager.PERMISSION_GRANTED }
                val totalCount = grantResults.size
                if (allGranted) {
                    sendCarLog("权限授予成功，启动车机数据监听 (全部 $totalCount 个权限)")
                } else {
                    sendCarLog("部分权限被拒绝 ($grantedCount/$totalCount)，但仍尝试启动车机数据监听")
                }
                bydVehicleService?.start()
                pendingStartCarData = false
            }
        }
    }

    private fun openApp() {
        sendLog("app", "openApp 被调用")
        val intent = Intent(this, MainActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        startActivity(intent)
    }

    private fun installApk(path: String?) {
        if (path.isNullOrEmpty()) {
            sendLog("app", "installApk: path is empty")
            return
        }

        pendingApkPath = path
        sendLog("app", "installApk: preparing to install from: $path")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (!packageManager.canRequestPackageInstalls()) {
                sendLog("app", "installApk: requesting install permission")
                // 跳转到设置页面请求权限
                val intent = Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName")
                ).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivityForResult(intent, INSTALL_PERMISSION_REQUEST_CODE)
                return
            }
        }

        // 有权限，直接安装
        performInstall(path)
    }

    private fun performInstall(path: String) {
        try {
            val file = java.io.File(path)
            if (!file.exists()) {
                sendLog("app", "installApk: file not found: $path")
                return
            }
            sendLog("app", "installApk: file exists, starting install")

            val intent = Intent(Intent.ACTION_VIEW).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                val uri = androidx.core.content.FileProvider.getUriForFile(
                    this@MainActivity,
                    "${packageName}.fileprovider",
                    file
                )
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(intent)
            sendLog("app", "installApk: install intent sent")
        } catch (e: Exception) {
            sendLog("app", "installApk failed: ${e.message}")
            e.printStackTrace()
        }
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
        sendLog("background", "startBackgroundService 被调用")
        val intent = Intent(this, BackgroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopBackgroundService() {
        sendLog("background", "stopBackgroundService 被调用")
        val intent = Intent(this, BackgroundService::class.java)
        stopService(intent)
    }

    private fun updateNotification(title: String?, desc: String?) {
        sendLog("background", "updateNotification 被调用, title: $title, desc: $desc")
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
        sendLog("background", "updateAppTitle 被调用, title: $title")
        try {
            if (title.isNullOrEmpty()) return

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1) {
                val shortcutManager = getSystemService(ShortcutManager::class.java)
                if (shortcutManager != null && shortcutManager.isRequestPinShortcutSupported) {
                    val shortcutInfo = ShortcutInfo.Builder(this, "dynamic_app_launcher")
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
            sendLog("app", "updateAppTitle 失败: ${e.message}")
            sendLog("app", "异常堆栈: ${e.stackTraceToString()}")
        }
    }

    private fun mapToBydPermissionString(type: String): String {
        return when (type) {
            "bydAcCommon" -> "android.permission.BYDAUTO_AC_COMMON"
            "bydBodyworkCommon" -> "android.permission.BYDAUTO_BODYWORK_COMMON"
            "bydEngineCommon" -> "android.permission.BYDAUTO_ENGINE_COMMON"
            "bydTyreCommon" -> "android.permission.BYDAUTO_TYRE_COMMON"
            "bydInstrumentCommon" -> "android.permission.BYDAUTO_INSTRUMENT_COMMON"
            "bydDoorlockCommon" -> "android.permission.BYDAUTO_DOORLOCK_COMMON"
            "bydPanoramaCommon" -> "android.permission.BYDAUTO_PANORAMA_COMMON"
            "bydVehiclesetCommon" -> "android.permission.BYDAUTO_VEHICLESET_COMMON"
            "bydSpeedGet" -> "android.permission.BYDAUTO_SPEED_GET"
            "bydStatisticGet" -> "android.permission.BYDAUTO_STATISTIC_GET"
            "bydTyreGet" -> "android.permission.BYDAUTO_TYRE_GET"
            "bydEngineGet" -> "android.permission.BYDAUTO_ENGINE_GET"
            "bydEnergyGet" -> "android.permission.BYDAUTO_ENERGY_GET"
            "bydChargeGet" -> "android.permission.BYDAUTO_CHARGE_GET"
            else -> type
        }
    }

    private fun sendCarLog(log: String) {
        try {
            FileLogHelper.log("BYD", log)

            val logData = mapOf(
                "type" to "carLog",
                "message" to log
            )
            val jsonString = JSONObject(logData).toString()
            logMethodChannel?.invokeMethod("onBydLog", jsonString)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun sendLog(type: String, message: String) {
        try {
            FileLogHelper.log(type.uppercase(), message)

            val logData = mapOf(
                "type" to type,
                "message" to message
            )
            val jsonString = JSONObject(logData).toString()
            logMethodChannel?.invokeMethod("onLog", jsonString)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        FileLogHelper.init(this)
        FileLogHelper.log("MainActivity", "onCreate: App 正在启动")

        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            FileLogHelper.logException("UncaughtException", "未捕获的异常发生在线程 ${thread.name}", throwable as? Exception)
            FileLogHelper.log("UncaughtException", "退出应用...")
            System.exit(1)
        }

        window.setSoftInputMode(android.view.WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE or android.view.WindowManager.LayoutParams.SOFT_INPUT_STATE_HIDDEN)
        
        // 处理 deep link
        handleDeepLink(intent)
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleDeepLink(intent)
    }
    
    private fun handleDeepLink(intent: Intent?) {
        intent?.data?.let { uri ->
            val url = uri.toString()
            sendLog("app", "Deep link received: $url")
            
            // 无论 deepLinkChannel 是否存在，都保存并尝试发送
            initialDeepLink = url
            
            if (deepLinkChannel != null) {
                deepLinkChannel?.invokeMethod("onDeepLink", url)
                sendLog("app", "Deep link sent to Flutter: $url")
            } else {
                sendLog("app", "Deep link saved for later: $url")
            }
        }
    }

    override fun onResume() {
        super.onResume()
        // 隐藏输入法，防止 App 启动或从后台返回时无故唤起输入法
        val imm = getSystemService(android.content.Context.INPUT_METHOD_SERVICE) as? android.view.inputmethod.InputMethodManager
        imm?.hideSoftInputFromWindow(window.decorView.windowToken, 0)
        
        // 检查是否有待处理的 deep link
        // 当 App 从后台恢复时，onNewIntent 可能不被调用，所以在这里检查
        if (intent?.data != null) {
            handleDeepLink(intent)
        } else if (initialDeepLink != null && deepLinkChannel != null) {
            // 如果有待处理的 deep link 且 channel 已初始化，发送它
            deepLinkChannel?.invokeMethod("onDeepLink", initialDeepLink)
            sendLog("app", "Resume: sent pending deep link: $initialDeepLink")
        }
    }

    private fun restartApp() {
        sendLog("app", "restartApp 被调用")
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        if (intent == null) {
            sendLog("app", "restartApp 失败: intent 为空")
            return
        }
        intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP or android.content.Intent.FLAG_ACTIVITY_CLEAR_TASK or android.content.Intent.FLAG_ACTIVITY_NO_ANIMATION)
        startActivity(intent)
        overridePendingTransition(0, 0)
        sendLog("app", "restartApp 已启动新 Activity，准备退出")
        System.exit(0)
    }

    private fun quitApp() {
        sendLog("app", "quitApp 被调用")
        android.os.Process.killProcess(android.os.Process.myPid())
    }

    // ==================== Google Sign-In ====================
    
    private fun initGoogleSignIn() {
        val clientId = BuildConfig.GOOGLE_CLIENT_ID
        val webClientId = BuildConfig.GOOGLE_WEB_CLIENT_ID
        val gso = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
             .requestEmail()
             .requestProfile()
             .build()
        
        googleSignInClient = GoogleSignIn.getClient(this, gso)
        sendLog("app", "Google Sign-In 初始化完成, clientId=$clientId, webClientId=$webClientId")
    }
    
    private fun handleThirdPartyLogin(type: String?, result: MethodChannel.Result) {
        sendLog("app", "handleThirdPartyLogin: $type")
        
        when (type) {
            "google" -> {
                signInWithGoogle(result)
            }
            "qq" -> {
                // QQ登录预留
                sendLog("app", "QQ登录功能尚未实现")
                result.success(mapOf("success" to false, "error" to "QQ登录功能尚未实现"))
            }
            "github" -> {
                // GitHub登录预留
                sendLog("app", "GitHub登录功能尚未实现")
                result.success(mapOf("success" to false, "error" to "GitHub登录功能尚未实现"))
            }
            else -> {
                result.success(mapOf("success" to false, "error" to "不支持的登录类型: $type"))
            }
        }
    }
    
    private fun signInWithGoogle(result: MethodChannel.Result) {
        sendLog("app", "signInWithGoogle 被调用")
        
        pendingThirdPartyLoginResult = { loginResult ->
            result.success(loginResult)
        }
        
        val signInIntent = googleSignInClient.signInIntent
        startActivityForResult(signInIntent, REQUEST_CODE_GOOGLE_SIGN_IN)
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == INSTALL_PERMISSION_REQUEST_CODE) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && packageManager.canRequestPackageInstalls()) {
                sendLog("app", "installApk: permission granted")
                pendingApkPath?.let {
                    performInstall(it)
                }
            } else {
                sendLog("app", "installApk: permission denied")
            }
        } else if (requestCode == REQUEST_CODE_GOOGLE_SIGN_IN) {
            val task = GoogleSignIn.getSignedInAccountFromIntent(data)
            handleSignInResult(task)
        }
    }
    
    private fun handleSignInResult(completedTask: Task<GoogleSignInAccount>) {
        try {
            val account = completedTask.getResult(ApiException::class.java)
            
            // 获取用户信息
            val userId = account.id ?: ""
            val userName = account.displayName ?: ""
            val userEmail = account.email ?: ""
            val userAvatar = account.photoUrl?.toString() ?: ""
            val idToken = account.idToken ?: ""
            
            sendLog("app", "Google登录成功: $userEmail")
            
            val resultMap = mapOf(
                "success" to true,
                "userId" to userId,
                "userName" to userName,
                "userEmail" to userEmail,
                "userAvatar" to userAvatar,
                "idToken" to idToken,
                "accessToken" to "" // Google Sign-In主要使用idToken
            )
            
            pendingThirdPartyLoginResult?.invoke(resultMap)
            pendingThirdPartyLoginResult = null
            
        } catch (e: ApiException) {
            sendLog("app", "Google登录失败: ${e.message}")
            
            val errorMessage = e.message ?: "登录失败"
            val resultMap: Map<String, Any> = mapOf(
                "success" to false,
                "error" to errorMessage
            )
            
            pendingThirdPartyLoginResult?.invoke(resultMap)
            pendingThirdPartyLoginResult = null
        }
    }
}
