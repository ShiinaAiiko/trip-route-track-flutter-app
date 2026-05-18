package club.aiiko.trip

import android.content.Context
import android.content.pm.PackageManager
import android.hardware.bydauto.BYDAutoConstants
import android.hardware.bydauto.instrument.BYDAutoInstrumentDevice
import android.hardware.bydauto.instrument.AbsBYDAutoInstrumentListener
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
    private var instrumentDevice: BYDAutoInstrumentDevice? = null

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
    private var lastExternalChargingPower: Double = 0.0

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
        val requiredPermissions = listOf(
            "android.permission.BYDAUTO_AC_COMMON",
            "android.permission.BYDAUTO_BODYWORK_COMMON",
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
        var allGranted = true
        requiredPermissions.forEach { permission ->
            val granted = context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
            sendCarLog("  $permission: $granted")
            if (!granted) allGranted = false
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

        val hasAllPermissions = hasRequiredPermissions()
        if (!hasAllPermissions) {
            sendCarLog("⚠️ 部分权限缺失，尝试使用反射调用获取数据")
        } else {
            sendCarLog("权限检查通过，开始初始化设备")
        }

        isStarted = true

        // 初始化车速设备
        try {
            sendCarLog("初始化车速设备 BYDAutoSpeedDevice...")
            speedDevice = BYDAutoSpeedDevice.getInstance(context)
            sendCarLog("BYDAutoSpeedDevice.getInstance() 完成")

            if (speedDevice == null) {
                sendCarLog("❌ BYDAutoSpeedDevice.getInstance() 返回 null，可能是权限不足")
            } else {
                sendCarLog("speedDevice 实例类型: ${speedDevice?.javaClass?.name}")
                if (speedDevice?.javaClass?.simpleName?.contains("Stub") == true) {
                    sendCarLog("⚠️ BYDAutoSpeedDevice 是 Stub 实现")
                }
                try {
                    speedDevice?.registerListener(speedListener)
                    sendCarLog("车速监听器注册成功")
                } catch (e: Exception) {
                    sendCarLog("车速监听器注册失败: ${e.message}")
                }
            }
        } catch (e: Exception) {
            sendCarLog("车速设备初始化异常: ${e.message}")
            sendCarLog("异常堆栈: ${e.stackTraceToString()}")
        }

        // 初始化统计设备
        try {
            sendCarLog("初始化统计设备 BYDAutoStatisticDevice...")
            statisticDevice = BYDAutoStatisticDevice.getInstance(context)
            sendCarLog("BYDAutoStatisticDevice.getInstance() 完成")

            if (statisticDevice == null) {
                sendCarLog("❌ BYDAutoStatisticDevice.getInstance() 返回 null")
            } else {
                sendCarLog("statisticDevice 实例类型: ${statisticDevice?.javaClass?.name}")
                if (statisticDevice?.javaClass?.simpleName?.contains("Stub") == true) {
                    sendCarLog("⚠️ BYDAutoStatisticDevice 是 Stub 实现")
                }
                try {
                    statisticDevice?.registerListener(statisticListener)
                    sendCarLog("统计监听器注册成功")
                } catch (e: Exception) {
                    sendCarLog("统计监听器注册失败: ${e.message}")
                }
            }
        } catch (e: Exception) {
            sendCarLog("统计设备初始化异常: ${e.message}")
            sendCarLog("异常堆栈: ${e.stackTraceToString()}")
        }

        // 初始化胎压设备
        try {
            sendCarLog("初始化胎压设备 BYDAutoTyreDevice...")
            tyreDevice = BYDAutoTyreDevice.getInstance(context)
            sendCarLog("BYDAutoTyreDevice.getInstance() 完成")

            if (tyreDevice == null) {
                sendCarLog("❌ BYDAutoTyreDevice.getInstance() 返回 null")
            } else {
                sendCarLog("tyreDevice 实例类型: ${tyreDevice?.javaClass?.name}")
                if (tyreDevice?.javaClass?.simpleName?.contains("Stub") == true) {
                    sendCarLog("⚠️ BYDAutoTyreDevice 是 Stub 实现")
                }
                try {
                    tyreDevice?.registerListener(tyreListener)
                    sendCarLog("胎压监听器注册成功")
                } catch (e: Exception) {
                    sendCarLog("胎压监听器注册失败: ${e.message}")
                }
            }
        } catch (e: Exception) {
            sendCarLog("胎压设备初始化异常: ${e.message}")
            sendCarLog("异常堆栈: ${e.stackTraceToString()}")
        }

        // 初始化仪表设备
        try {
            sendCarLog("初始化仪表设备 BYDAutoInstrumentDevice...")
            instrumentDevice = BYDAutoInstrumentDevice.getInstance(context)
            sendCarLog("BYDAutoInstrumentDevice.getInstance() 完成")

            if (instrumentDevice == null) {
                sendCarLog("❌ BYDAutoInstrumentDevice.getInstance() 返回 null")
            } else {
                sendCarLog("instrumentDevice 实例类型: ${instrumentDevice?.javaClass?.name}")
                if (instrumentDevice?.javaClass?.simpleName?.contains("Stub") == true) {
                    sendCarLog("⚠️ BYDAutoInstrumentDevice 是 Stub 实现")
                }
                try {
                    instrumentDevice?.registerListener(instrumentListener)
                    sendCarLog("仪表监听器注册成功")
                } catch (e: Exception) {
                    sendCarLog("仪表监听器注册失败: ${e.message}")
                }
            }
        } catch (e: Exception) {
            sendCarLog("仪表设备初始化异常: ${e.message}")
            sendCarLog("异常堆栈: ${e.stackTraceToString()}")
        }

        // 参考车况助手项目：手动读取初始数据
        sendCarLog("开始手动读取初始数据...")
        manualReadInitialData()

        sendCarLog("BYDAutoVehicleService 启动完成")
        sendCarData(buildCarData())
    }

    // 参考车况助手项目：手动读取初始数据
    private fun manualReadInitialData() {
        // 手动读取胎压数据（参考车况助手项目的做法）
        try {
            if (tyreDevice != null) {
                val pressureLf = tyreDevice?.getTyrePressureValue(BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_FRONT) ?: 0
                val pressureRf = tyreDevice?.getTyrePressureValue(BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_FRONT) ?: 0
                val pressureLr = tyreDevice?.getTyrePressureValue(BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_REAR) ?: 0
                val pressureRr = tyreDevice?.getTyrePressureValue(BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_REAR) ?: 0

                sendCarLog("手动读取胎压 - 左前: $pressureLf, 右前: $pressureRf, 左后: $pressureLr, 右后: $pressureRr")

                // 手动触发监听器回调
                tyreListener?.onTyrePressureValueChanged(BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_FRONT, pressureLf)
                tyreListener?.onTyrePressureValueChanged(BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_FRONT, pressureRf)
                tyreListener?.onTyrePressureValueChanged(BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_REAR, pressureLr)
                tyreListener?.onTyrePressureValueChanged(BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_REAR, pressureRr)
            }
        } catch (e: Exception) {
            sendCarLog("手动读取胎压失败: ${e.message}")
        }

        // 读取车速数据
        try {
            if (speedDevice != null) {
                val speed = speedDevice?.currentSpeed ?: 0.0
                sendCarLog("手动读取车速: $speed")
            }
        } catch (e: Exception) {
            sendCarLog("手动读取车速失败: ${e.message}")
        }

        // 读取统计设备数据
        try {
            if (statisticDevice != null) {
                val elecPercent = statisticDevice?.elecPercentageValue ?: 0.0
                val fuelPercent = statisticDevice?.fuelPercentageValue ?: 0
                val totalMileage = statisticDevice?.totalMileageValue ?: 0
                val evMileage = statisticDevice?.evMileageValue ?: 0

                sendCarLog("手动读取统计 - 电量: $elecPercent%, 油量: $fuelPercent%, 总里程: $totalMileage, 纯电里程: $evMileage")
            }
        } catch (e: Exception) {
            sendCarLog("手动读取统计失败: ${e.message}")
        }

        // 读取仪表设备数据
        try {
            if (instrumentDevice != null) {
                val externalChargingPower = instrumentDevice?.externalChargingPower ?: 0.0
                sendCarLog("手动读取仪表 - 外接充电量: $externalChargingPower kW.h")
                if (externalChargingPower >= 0.0 && externalChargingPower <= 10000.0) {
                    lastExternalChargingPower = externalChargingPower
                }
            }
        } catch (e: Exception) {
            sendCarLog("手动读取仪表失败: ${e.message}")
        }
    }

    private fun handleInitException(deviceName: String, e: Exception) {
        sendCarLog("初始化 ${deviceName} 失败: ${e.message}")
        if (e.message?.contains("Stub") == true) {
            sendCarLog("检测到 Stub 异常，设备可能不可用")
        }
    }

    // 参考车况助手项目：监听器作为类成员变量
    private val speedListener = object : AbsBYDAutoSpeedListener() {
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

    private val statisticListener = object : AbsBYDAutoStatisticListener() {
        override fun onElecPercentageChanged(value: Double) {
            sendCarLog("统计监听器回调 - 电量变化: $value")
            if (value >= 0 && value <= 100) {
                lastElecPercentage = value
                sendCarData(buildCarData())
            }
        }

        override fun onFuelPercentageChanged(value: Int) {
            sendCarLog("统计监听器回调 - 油量变化: $value")
            if (value >= 0 && value <= 100) {
                lastFuelPercentage = value
                sendCarData(buildCarData())
            }
        }

        // override fun onTotalMileageChanged(value: Int) {
        //     sendCarLog("统计监听器回调 - 总里程变化: $value")
        //     if (value >= 0) {
        //         lastTotalMileage = value
        //         sendCarData(buildCarData())
        //     }
        // }
    }

    private val tyreListener = object : AbsBYDAutoTyreListener() {
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

    private val instrumentListener = object : AbsBYDAutoInstrumentListener() {
        override fun onExternalChargingPowerChanged(value: Double) {
            sendCarLog("仪表监听器回调 - 外接充电量变化: $value")
            if (value >= 0.0 && value <= 10000.0) {
                lastExternalChargingPower = value
                sendCarData(buildCarData())
            }
        }
    }

    private fun updateSpeedData() {
        try {
            sendCarLog("updateSpeedData() - speedDevice: ${speedDevice != null}")

            if (speedDevice == null) {
                sendCarLog("updateSpeedData() - speedDevice 为 null，尝试重新初始化")
                try {
                    speedDevice = BYDAutoSpeedDevice.getInstance(context)
                    if (speedDevice != null) {
                        speedDevice?.registerListener(speedListener)
                        sendCarLog("speedDevice 重新初始化成功")
                    } else {
                        sendCarLog("speedDevice 重新初始化失败，权限不足")
                    }
                } catch (e: Exception) {
                    sendCarLog("重新初始化 speedDevice 异常: ${e.message}")
                }
                return
            }

            var speed = 0.0
            var accelerate = 0
            var brake = 0

            try {
                // 先尝试直接调用
                speed = speedDevice?.currentSpeed ?: 0.0
                accelerate = speedDevice?.accelerateDeepness ?: 0
                brake = speedDevice?.brakeDeepness ?: 0
            } catch (securityEx: SecurityException) {
                sendCarLog("直接调用失败(SecurityException)，尝试反射调用: ${securityEx.message}")
                // 使用反射调用（使用数值常量，避免SDK版本差异）
                speed = BydApiReflectHelper.getDouble(speedDevice, 1, 1033220112) // SPEED_ACCELERATE_VALUE
                accelerate = BydApiReflectHelper.get(speedDevice, 1, 1033220112) // SPEED_ACCELERATE_VALUE
                brake = BydApiReflectHelper.get(speedDevice, 1, 874512400) // SPEED_BRAKE_S
            } catch (e: Exception) {
                sendCarLog("直接调用失败，尝试反射调用: ${e.message}")
                speed = BydApiReflectHelper.getDouble(speedDevice, 1, 1033220112) // SPEED_ACCELERATE_VALUE
                accelerate = BydApiReflectHelper.get(speedDevice, 1, 1033220112) // SPEED_ACCELERATE_VALUE
                brake = BydApiReflectHelper.get(speedDevice, 1, 874512400) // SPEED_BRAKE_S
            }

            sendCarLog("updateSpeedData() - 原始数据: speed=$speed, accelerate=$accelerate, brake=$brake")

            if (speed >= 0 && speed <= 282) lastSpeed = speed
            if (accelerate >= 0 && accelerate <= 100) lastAccelerateDepth = accelerate
            if (brake >= 0 && brake <= 100) lastBrakeDepth = brake

            sendCarLog("updateSpeedData() - 更新后数据: speed=$lastSpeed, accelerate=$lastAccelerateDepth, brake=$lastBrakeDepth")
        } catch (e: Exception) {
            sendCarLog("updateSpeedData() 异常: ${e.message}")
            sendCarLog("异常堆栈: ${e.stackTraceToString()}")
        }
    }

    private fun updateStatisticData() {
        try {
            sendCarLog("updateStatisticData() - statisticDevice: ${statisticDevice != null}")

            if (statisticDevice == null) {
                sendCarLog("updateStatisticData() - statisticDevice 为 null")
                return
            }

            var elecPercent = 0.0
            var fuelPercent = 0
            var totalMileage = 0
            var evMileage = 0

            try {
                // 先尝试直接调用
                elecPercent = statisticDevice?.elecPercentageValue ?: 0.0
                fuelPercent = statisticDevice?.fuelPercentageValue ?: 0
                totalMileage = statisticDevice?.totalMileageValue ?: 0
                evMileage = statisticDevice?.evMileageValue ?: 0
            } catch (securityEx: SecurityException) {
                sendCarLog("直接调用失败(SecurityException)，尝试反射调用: ${securityEx.message}")
                // 使用反射调用（使用数值常量，避免SDK版本差异）
                elecPercent = BydApiReflectHelper.getDouble(statisticDevice, 2, 1246777400) / 100.0 // STATISTIC_ELEC_PERCENTAGE
                fuelPercent = BydApiReflectHelper.get(statisticDevice, 2, 1246777401) // STATISTIC_FUEL_PERCENTAGE
                totalMileage = BydApiReflectHelper.get(statisticDevice, 2, 1246777402) // STATISTIC_TOTAL_MILEAGE
                evMileage = BydApiReflectHelper.get(statisticDevice, 2, 1246777403) // STATISTIC_EV_MILEAGE
            } catch (e: Exception) {
                sendCarLog("直接调用失败，尝试反射调用: ${e.message}")
                elecPercent = BydApiReflectHelper.getDouble(statisticDevice, 2, 1246777400) / 100.0 // STATISTIC_ELEC_PERCENTAGE
                fuelPercent = BydApiReflectHelper.get(statisticDevice, 2, 1246777401) // STATISTIC_FUEL_PERCENTAGE
                totalMileage = BydApiReflectHelper.get(statisticDevice, 2, 1246777402) // STATISTIC_TOTAL_MILEAGE
                evMileage = BydApiReflectHelper.get(statisticDevice, 2, 1246777403) // STATISTIC_EV_MILEAGE
            }

            sendCarLog("updateStatisticData() - 原始数据: elecPercent=$elecPercent%, fuelPercent=$fuelPercent%, totalMileage=$totalMileage, evMileage=$evMileage")

            if (elecPercent >= 0 && elecPercent <= 100) lastElecPercentage = elecPercent
            if (fuelPercent >= 0 && fuelPercent <= 100) lastFuelPercentage = fuelPercent
            if (totalMileage >= 0) lastTotalMileage = totalMileage
            if (evMileage >= 0) lastEvMileage = evMileage

            sendCarLog("updateStatisticData() - 更新后数据: elecPercentage=$lastElecPercentage%, fuelPercentage=$lastFuelPercentage%, totalMileage=$lastTotalMileage, evMileage=$lastEvMileage")
        } catch (e: Exception) {
            sendCarLog("updateStatisticData() 异常: ${e.message}")
            sendCarLog("异常堆栈: ${e.stackTraceToString()}")
        }
    }

    private fun updateTyreData() {
        try {
            sendCarLog("updateTyreData() - tyreDevice: ${tyreDevice != null}")

            if (tyreDevice == null) {
                sendCarLog("updateTyreData() - tyreDevice 为 null")
                return
            }

            var lf = 0
            var rf = 0
            var lr = 0
            var rr = 0

            try {
                // 先尝试直接调用
                lf = tyreDevice?.getTyrePressureValue(BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_FRONT) ?: 0
                rf = tyreDevice?.getTyrePressureValue(BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_FRONT) ?: 0
                lr = tyreDevice?.getTyrePressureValue(BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_REAR) ?: 0
                rr = tyreDevice?.getTyrePressureValue(BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_REAR) ?: 0
            } catch (securityEx: SecurityException) {
                sendCarLog("直接调用失败(SecurityException)，尝试反射调用: ${securityEx.message}")
                // 使用反射调用（使用数值常量，避免SDK版本差异）
                lf = BydApiReflectHelper.get(tyreDevice, 3, -1728052956) // TYRE_PRESSURE_VALUE_LEFT_FRONT
                rf = BydApiReflectHelper.get(tyreDevice, 3, -1728052952) // TYRE_PRESSURE_VALUE_RIGHT_FRONT
                lr = BydApiReflectHelper.get(tyreDevice, 3, -1728052948) // TYRE_PRESSURE_VALUE_LEFT_REAR
                rr = BydApiReflectHelper.get(tyreDevice, 3, -1728052944) // TYRE_PRESSURE_VALUE_RIGHT_REAR
            } catch (e: Exception) {
                sendCarLog("直接调用失败，尝试反射调用: ${e.message}")
                lf = BydApiReflectHelper.get(tyreDevice, 3, -1728052956) // TYRE_PRESSURE_VALUE_LEFT_FRONT
                rf = BydApiReflectHelper.get(tyreDevice, 3, -1728052952) // TYRE_PRESSURE_VALUE_RIGHT_FRONT
                lr = BydApiReflectHelper.get(tyreDevice, 3, -1728052948) // TYRE_PRESSURE_VALUE_LEFT_REAR
                rr = BydApiReflectHelper.get(tyreDevice, 3, -1728052944) // TYRE_PRESSURE_VALUE_RIGHT_REAR
            }

            sendCarLog("updateTyreData() - 原始数据: 左前=$lf, 右前=$rf, 左后=$lr, 右后=$rr")

            if (lf in 0..4094) lastTyrePressureLf = lf
            if (rf in 0..4094) lastTyrePressureRf = rf
            if (lr in 0..4094) lastTyrePressureLr = lr
            if (rr in 0..4094) lastTyrePressureRr = rr

            sendCarLog("updateTyreData() - 更新后数据: 左前=$lastTyrePressureLf, 右前=$lastTyrePressureRf, 左后=$lastTyrePressureLr, 右后=$lastTyrePressureRr")
        } catch (e: Exception) {
            sendCarLog("updateTyreData() 异常: ${e.message}")
            sendCarLog("异常堆栈: ${e.stackTraceToString()}")
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
            speedDevice?.unregisterListener(speedListener)
            sendCarLog("车速监听器已注销")
        } catch (e: Exception) {
            sendCarLog("注销车速监听器失败: ${e.message}")
        }

        try {
            statisticDevice?.unregisterListener(statisticListener)
            sendCarLog("统计监听器已注销")
        } catch (e: Exception) {
            sendCarLog("注销统计监听器失败: ${e.message}")
        }

        try {
            tyreDevice?.unregisterListener(tyreListener)
            sendCarLog("胎压监听器已注销")
        } catch (e: Exception) {
            sendCarLog("注销胎压监听器失败: ${e.message}")
        }

        try {
            instrumentDevice?.unregisterListener(instrumentListener)
            sendCarLog("仪表监听器已注销")
        } catch (e: Exception) {
            sendCarLog("注销仪表监听器失败: ${e.message}")
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
            "externalChargingPower" to lastExternalChargingPower,
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
        sendCarLog("=== requestCarData() 开始 ===")
        sendCarLog("requestCarData() - isStarted: $isStarted")

        if (!isStarted) {
            sendCarLog("requestCarData() - 服务未启动，尝试启动服务")
            start()
            sendCarLog("requestCarData() - 启动后 isStarted: $isStarted")

            if (!isStarted) {
                sendCarLog("requestCarData() - 服务启动失败，返回空数据")
                sendEmptyCarData()
                sendCarLog("=== requestCarData() 结束 ===")
                return
            }
        }

        // 强制更新所有数据
        sendCarLog("requestCarData() - 开始更新数据")
        updateSpeedData()
        updateStatisticData()
        updateTyreData()

        sendCarLog("requestCarData() - 发送数据")
        sendCarData(buildCarData())
        sendCarLog("=== requestCarData() 结束 ===")
    }
}