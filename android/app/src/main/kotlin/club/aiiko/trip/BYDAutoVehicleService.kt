package club.aiiko.trip

import android.content.Context
import android.content.pm.PackageManager
import android.hardware.bydauto.BYDAutoConstants
import android.hardware.bydauto.speed.BYDAutoSpeedDevice
import android.hardware.bydauto.speed.AbsBYDAutoSpeedListener
import android.hardware.bydauto.statistic.BYDAutoStatisticDevice
import android.hardware.bydauto.statistic.AbsBYDAutoStatisticListener
import android.hardware.bydauto.tyre.BYDAutoTyreDevice
import android.hardware.bydauto.tyre.AbsBYDAutoTyreListener
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class BYDAutoVehicleService(private val context: Context) {
    private var speedDevice: BYDAutoSpeedDevice? = null
    private var statisticDevice: BYDAutoStatisticDevice? = null
    private var tyreDevice: BYDAutoTyreDevice? = null

    private var methodChannel: MethodChannel? = null
    private var isStarted = false

    // 数据缓存
    private var lastSpeed: Double = 0.0
    private var lastAccelerateDepth: Int = 0
    private var lastBrakeDepth: Int = 0
    private var lastTyrePressureLf: Int = 0
    private var lastTyrePressureRf: Int = 0
    private var lastTyrePressureLr: Int = 0
    private var lastTyrePressureRr: Int = 0
    private var lastElecPercentage: Double = 0.0
    private var lastFuelPercentage: Int = 0
    private var lastTotalMileage: Int = 0
    private var lastEvMileage: Int = 0
    private var lastChargeStatus: Int = 0
    private var lastChargePower: Int = 0

    private var speedListener: AbsBYDAutoSpeedListener? = null
    private var tyreListener: AbsBYDAutoTyreListener? = null
    private var statisticListener: AbsBYDAutoStatisticListener? = null

    // 无效数据常量
    private val INVALID_DATA = 65535
    private val INVALID_DATA_1 = -10011

    init {
        sendCarLog("BYDAutoVehicleService 初始化")
    }

    fun setMethodChannel(channel: MethodChannel) {
        this.methodChannel = channel
        sendCarLog("MethodChannel 已设置")
    }

    fun hasRequiredPermissions(): Boolean {
        val permissions = listOf(
            "android.permission.BYDAUTO_AC_COMMON",
            "android.permission.BYDAUTO_BODYWORK_COMMON",
            "android.permission.BYDAUTO_ENGINE_COMMON",
            "android.permission.BYDAUTO_TYRE_COMMON",
            "android.permission.BYDAUTO_INSTRUMENT_COMMON",
            "android.permission.BYDAUTO_DOORLOCK_COMMON",
            "android.permission.BYDAUTO_PANORAMA_COMMON",
            "android.permission.BYDAUTO_VEHICLESET_COMMON",
            "android.permission.BYDAUTO_SPEED_GET",
            "android.permission.BYDAUTO_STATISTIC_GET",
            "android.permission.BYDAUTO_TYRE_GET",
            "android.permission.BYDAUTO_ENGINE_GET",
            "android.permission.BYDAUTO_ENERGY_GET",
            "android.permission.BYDAUTO_CHARGE_GET"
        )
        
        sendCarLog("权限检查结果:")
        val allGranted = permissions.all { permission ->
            val granted = context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
            sendCarLog("  $permission: $granted")
            granted
        }
        
        return allGranted
    }

    fun getRequiredPermissions(): Array<String> {
        sendCarLog("获取需要申请的所有比亚迪车机权限列表")
        return arrayOf(
            "android.permission.BYDAUTO_AC_COMMON",
            "android.permission.BYDAUTO_BODYWORK_COMMON",
            "android.permission.BYDAUTO_ENGINE_COMMON",
            "android.permission.BYDAUTO_TYRE_COMMON",
            "android.permission.BYDAUTO_INSTRUMENT_COMMON",
            "android.permission.BYDAUTO_DOORLOCK_COMMON",
            "android.permission.BYDAUTO_PANORAMA_COMMON",
            "android.permission.BYDAUTO_VEHICLESET_COMMON",
            "android.permission.BYDAUTO_SPEED_GET",
            "android.permission.BYDAUTO_STATISTIC_GET",
            "android.permission.BYDAUTO_TYRE_GET",
            "android.permission.BYDAUTO_ENGINE_GET",
            "android.permission.BYDAUTO_ENERGY_GET",
            "android.permission.BYDAUTO_CHARGE_GET"
        )
    }

    fun start() {
        if (isStarted) {
            sendCarLog("服务已启动，无需重复启动")
            return
        }
        
        sendCarLog("开始启动 BYDAutoVehicleService")
        
        if (!hasRequiredPermissions()) {
            sendCarLog("缺少比亚迪车机权限，无法启动服务")
            sendError("缺少比亚迪车机权限，请先申请权限")
            sendEmptyCarData()
            return
        }
        
        sendCarLog("权限检查通过，开始初始化设备")
        isStarted = true

        var devicesInitialized = 0

        // 初始化车速设备
        try {
            sendCarLog("初始化车速设备 BYDAutoSpeedDevice...")
            speedDevice = BYDAutoSpeedDevice.getInstance(context)
            
            if (speedDevice == null) {
                sendCarLog("车速设备初始化失败: getInstance 返回 null")
            } else {
                speedListener = createSpeedListener()
                speedDevice?.registerListener(speedListener)
                sendCarLog("车速设备初始化成功，监听器已注册")
                devicesInitialized++
                
                // 立即读取当前值
                updateSpeedData()
            }
        } catch (e: Exception) {
            handleInitException("车速设备", e)
        }

        // 初始化统计设备
        try {
            sendCarLog("初始化统计设备 BYDAutoStatisticDevice...")
            statisticDevice = BYDAutoStatisticDevice.getInstance(context)
            
            if (statisticDevice == null) {
                sendCarLog("统计设备初始化失败: getInstance 返回 null")
            } else {
                statisticListener = createStatisticListener()
                statisticDevice?.registerListener(statisticListener)
                sendCarLog("统计设备初始化成功，监听器已注册")
                devicesInitialized++
                
                // 立即读取当前值
                updateStatisticData()
            }
        } catch (e: Exception) {
            handleInitException("统计设备", e)
        }

        // 初始化胎压设备
        try {
            sendCarLog("初始化胎压设备 BYDAutoTyreDevice...")
            tyreDevice = BYDAutoTyreDevice.getInstance(context)
            
            if (tyreDevice == null) {
                sendCarLog("胎压设备初始化失败: getInstance 返回 null")
            } else {
                tyreListener = createTyreListener()
                tyreDevice?.registerListener(tyreListener)
                sendCarLog("胎压设备初始化成功，监听器已注册")
                devicesInitialized++
                
                // 立即读取当前值
                updateTyreData()
            }
        } catch (e: Exception) {
            handleInitException("胎压设备", e)
        }

        // 检查是否所有设备都初始化失败
        if (devicesInitialized == 0) {
            sendCarLog("所有设备初始化失败，可能运行在非比亚迪车机环境")
            sendEmptyCarData()
        } else {
            sendCarLog("BYDAutoVehicleService 启动完成，成功初始化 $devicesInitialized 个设备")
            // 发送一次完整数据
            sendCarData(buildCarData())
        }
    }

    private fun handleInitException(deviceName: String, e: Exception) {
        sendCarLog("初始化 ${deviceName} 失败: ${e.message}")
        if (e.message?.contains("Stub") == true) {
            sendCarLog("检测到 Stub 异常，设备可能不可用")
        }
    }

    private fun createSpeedListener(): AbsBYDAutoSpeedListener {
        return object : AbsBYDAutoSpeedListener() {
            override fun onSpeedChanged(value: Double) {
                sendCarLog("车速监听器回调 - 速度变化: $value")
                if (value != lastSpeed && value >= 0 && value <= 282) {
                    lastSpeed = value
                    sendCarData(buildCarData())
                }
            }

            override fun onAccelerateDeepnessChanged(value: Int) {
                sendCarLog("车速监听器回调 - 油门深度变化: $value")
                if (value != lastAccelerateDepth && value >= 0 && value <= 100) {
                    lastAccelerateDepth = value
                    sendCarData(buildCarData())
                }
            }

            override fun onBrakeDeepnessChanged(value: Int) {
                sendCarLog("车速监听器回调 - 刹车深度变化: $value")
                if (value != lastBrakeDepth && value >= 0 && value <= 100) {
                    lastBrakeDepth = value
                    sendCarData(buildCarData())
                }
            }
        }
    }

    private fun createStatisticListener(): AbsBYDAutoStatisticListener {
        return object : AbsBYDAutoStatisticListener() {
            // 统计数据通过轮询获取，监听器保留但不依赖回调
        }
    }

    private fun createTyreListener(): AbsBYDAutoTyreListener {
        return object : AbsBYDAutoTyreListener() {
            override fun onTyrePressureValueChanged(area: Int, value: Int) {
                sendCarLog("胎压监听器回调 - 区域: $area, 压力: $value")
                val changed = when (area) {
                    BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_FRONT -> {
                        if (value != lastTyrePressureLf && value in 0..4094) {
                            lastTyrePressureLf = value
                            true
                        } else false
                    }
                    BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_FRONT -> {
                        if (value != lastTyrePressureRf && value in 0..4094) {
                            lastTyrePressureRf = value
                            true
                        } else false
                    }
                    BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_REAR -> {
                        if (value != lastTyrePressureLr && value in 0..4094) {
                            lastTyrePressureLr = value
                            true
                        } else false
                    }
                    BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_REAR -> {
                        if (value != lastTyrePressureRr && value in 0..4094) {
                            lastTyrePressureRr = value
                            true
                        } else false
                    }
                    else -> false
                }
                if (changed) {
                    sendCarData(buildCarData())
                }
            }
        }
    }

    private fun updateSpeedData() {
        try {
            val speed = speedDevice?.currentSpeed ?: 0.0
            val accelerate = speedDevice?.accelerateDeepness ?: 0
            val brake = speedDevice?.brakeDeepness ?: 0
            
            if (speed >= 0 && speed <= 282) lastSpeed = speed
            if (accelerate >= 0 && accelerate <= 100) lastAccelerateDepth = accelerate
            if (brake >= 0 && brake <= 100) lastBrakeDepth = brake
            
            sendCarLog("初始化读取速度数据 - 速度: $speed, 油门: $accelerate, 刹车: $brake")
        } catch (e: Exception) {
            sendCarLog("读取速度数据失败: ${e.message}")
        }
    }

    private fun updateStatisticData() {
        try {
            // 直接调用API获取电量和油量
            val elecPercent = statisticDevice?.elecPercentageValue ?: 0.0
            val fuelPercent = statisticDevice?.fuelPercentageValue ?: 0
            val totalMileage = statisticDevice?.totalMileageValue ?: 0
            val evMileage = statisticDevice?.evMileageValue ?: 0
            
            if (elecPercent >= 0 && elecPercent <= 100) lastElecPercentage = elecPercent
            if (fuelPercent >= 0 && fuelPercent <= 100) lastFuelPercentage = fuelPercent
            if (totalMileage >= 0) lastTotalMileage = totalMileage
            if (evMileage >= 0) lastEvMileage = evMileage
            
            sendCarLog("初始化读取统计数据 - 电量: $elecPercent%, 油量: $fuelPercent%, 总里程: $totalMileage, 纯电里程: $evMileage")
        } catch (e: Exception) {
            sendCarLog("读取统计数据失败: ${e.message}")
        }
    }

    private fun updateTyreData() {
        try {
            val lf = tyreDevice?.getTyrePressureValue(BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_FRONT) ?: 0
            val rf = tyreDevice?.getTyrePressureValue(BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_FRONT) ?: 0
            val lr = tyreDevice?.getTyrePressureValue(BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_REAR) ?: 0
            val rr = tyreDevice?.getTyrePressureValue(BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_REAR) ?: 0
            
            if (lf in 0..4094) lastTyrePressureLf = lf
            if (rf in 0..4094) lastTyrePressureRf = rf
            if (lr in 0..4094) lastTyrePressureLr = lr
            if (rr in 0..4094) lastTyrePressureRr = rr
            
            sendCarLog("初始化读取胎压数据 - 左前: $lf, 右前: $rf, 左后: $lr, 右后: $rr")
        } catch (e: Exception) {
            sendCarLog("读取胎压数据失败: ${e.message}")
        }
    }

    fun stop() {
        if (!isStarted) {
            sendCarLog("服务未启动，无需停止")
            return
        }
        sendCarLog("停止 BYDAutoVehicleService")
        isStarted = false

        try {
            speedListener?.let { speedDevice?.unregisterListener(it) }
            sendCarLog("车速监听器已注销")
        } catch (e: Exception) {
            sendCarLog("注销车速监听器失败: ${e.message}")
        }

        try {
            statisticListener?.let { statisticDevice?.unregisterListener(it) }
            sendCarLog("统计监听器已注销")
        } catch (e: Exception) {
            sendCarLog("注销统计监听器失败: ${e.message}")
        }

        try {
            tyreListener?.let { tyreDevice?.unregisterListener(it) }
            sendCarLog("胎压监听器已注销")
        } catch (e: Exception) {
            sendCarLog("注销胎压监听器失败: ${e.message}")
        }
        
        sendCarLog("BYDAutoVehicleService 停止完成")
    }

    private fun buildCarData(): Map<String, Any?> {
        return mapOf(
            "speed" to lastSpeed,
            "elecPercentage" to lastElecPercentage,
            "fuelPercentage" to lastFuelPercentage,
            "accelerateDepth" to lastAccelerateDepth,
            "brakeDepth" to lastBrakeDepth,
            "totalMileage" to lastTotalMileage,
            "evMileage" to lastEvMileage,
            "tyrePressure" to mapOf(
                "leftFront" to lastTyrePressureLf,
                "rightFront" to lastTyrePressureRf,
                "leftRear" to lastTyrePressureLr,
                "rightRear" to lastTyrePressureRr
            ),
            "chargeStatus" to lastChargeStatus,
            "chargePower" to lastChargePower,
            "timestamp" to System.currentTimeMillis()
        )
    }

    private fun sendCarData(data: Map<String, Any?>) {
        try {
            val jsonString = JSONObject(data).toString()
            methodChannel?.invokeMethod("onCarDataChanged", jsonString)
        } catch (e: Exception) {
            sendCarLog("发送车机数据失败: ${e.message}")
        }
    }

    private fun sendError(message: String) {
        try {
            val errorData = mapOf(
                "type" to "error",
                "message" to message
            )
            val jsonString = JSONObject(errorData).toString()
            methodChannel?.invokeMethod("onCarDataChanged", jsonString)
        } catch (e: Exception) {
            sendCarLog("发送错误消息失败: ${e.message}")
        }
    }

    private fun sendCarLog(log: String) {
        sendBydLogToFlutter(log)
        try {
            val logData = mapOf(
                "type" to "carLog",
                "message" to log
            )
            val jsonString = JSONObject(logData).toString()
            methodChannel?.invokeMethod("onCarDataChanged", jsonString)
            Log.d("BYDAutoVehicleService", log)
        } catch (e: Exception) {
            Log.e("BYDAutoVehicleService", "发送日志失败: ${e.message}")
        }
    }

    private fun sendBydLogToFlutter(log: String) {
        try {
            methodChannel?.invokeMethod("onBydLog", log)
            Log.d("BYDAutoVehicleService", "[BYD-LOG] $log")
        } catch (e: Exception) {
            Log.e("BYDAutoVehicleService", "发送BYD日志到Flutter失败: ${e.message}")
        }
    }

    fun sendEmptyCarData() {
        sendCarLog("发送空车机数据")
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
                "chargeStatus" to 0,
                "chargePower" to 0,
                "timestamp" to System.currentTimeMillis()
            )
            val jsonString = JSONObject(emptyData).toString()
            methodChannel?.invokeMethod("onCarDataChanged", jsonString)
        } catch (e: Exception) {
            sendCarLog("发送空车机数据失败: ${e.message}")
        }
    }

    fun requestCarData() {
        sendCarLog("请求车机数据")
        
        if (!isStarted) {
            sendCarLog("服务未启动，返回空车机数据")
            sendEmptyCarData()
            return
        }
        
        // 强制更新所有数据
        updateSpeedData()
        updateStatisticData()
        updateTyreData()
        
        sendCarData(buildCarData())
    }
}
