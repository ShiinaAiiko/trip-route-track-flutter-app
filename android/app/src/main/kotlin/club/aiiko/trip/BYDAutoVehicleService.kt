package club.aiiko.trip

import android.content.Context
import android.content.pm.PackageManager
import android.hardware.bydauto.BYDAutoConstants
import android.hardware.bydauto.ac.BYDAutoAcDevice
import android.hardware.bydauto.ac.AbsBYDAutoAcListener
import android.hardware.bydauto.doorlock.BYDAutoDoorLockDevice
import android.hardware.bydauto.doorlock.AbsBYDAutoDoorLockListener
import android.hardware.bydauto.engine.BYDAutoEngineDevice
import android.hardware.bydauto.engine.AbsBYDAutoEngineListener
import android.hardware.bydauto.instrument.BYDAutoInstrumentDevice
import android.hardware.bydauto.instrument.AbsBYDAutoInstrumentListener
import android.hardware.bydauto.panorama.BYDAutoPanoramaDevice
import android.hardware.bydauto.panorama.AbsBYDAutoPanoramaListener
import android.hardware.bydauto.setting.BYDAutoSettingDevice
import android.hardware.bydauto.setting.AbsBYDAutoSettingListener
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
    private var acDevice: BYDAutoAcDevice? = null
    private var doorLockDevice: BYDAutoDoorLockDevice? = null
    private var engineDevice: BYDAutoEngineDevice? = null
    private var panoramaDevice: BYDAutoPanoramaDevice? = null
    private var settingDevice: BYDAutoSettingDevice? = null

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

    // 数据缓存 - 空调类
    private var lastAcCompressorMode: Int = 0
    private var lastAcCompressorManualSign: Int = 0
    private var lastAcWindLevelManualSign: Int = 0
    private var lastAcWindModeManualSign: Int = 0
    private var lastAcStartState: Int = 0
    private var lastAcControlMode: Int = 0
    private var lastAcCycleMode: Int = 0
    private var lastAcWindMode: Int = 0
    private var lastAcDefrostStateFront: Int = 0
    private var lastAcDefrostStateRear: Int = 0
    private var lastAcWindLevel: Int = 0
    private var lastAcTemperatureMain: Int = 0
    private var lastAcTemperatureDeputy: Int = 0
    private var lastAcTemperatureRear: Int = 0
    private var lastAcTemperatureOut: Int = 0
    private var lastTemperatureUnit: Int = 0
    private var lastAcTemperatureControlMode: Int = 0
    private var lastAcVentilationState: Int = 0
    private var lastRearAcStartState: Int = 0

    // 数据缓存 - 门锁类
    private var lastDoorLockLeftFront: Int = 0
    private var lastDoorLockLeftRear: Int = 0
    private var lastDoorLockRightFront: Int = 0
    private var lastDoorLockRightRear: Int = 0
    private var lastDoorLockBack: Int = 0
    private var lastDoorLockChildlockLeft: Int = 0
    private var lastDoorLockChildlockRight: Int = 0

    // 数据缓存 - 车辆设置类
    private var lastAcBTWind: Int = 0
    private var lastAcTunnelCycle: Int = 0
    private var lastAcPauseCycle: Int = 0
    private var lastAcAutoAir: Int = 0
    private var lastPm25Power: Int = 0
    private var lastPm25SwitchCheck: Int = 0
    private var lastPm25TimeCheck: Int = 0
    private var lastEnergyFeedback: Int = 0
    private var lastSocTarget: Int = 0
    private var lastChargingPort: Int = 0
    private var lastAutoExternalRearMirrorFollowUp: Int = 0
    private var lastLockOff: Int = 0
    private var lastLanguage: Int = 0
    private var lastOverspeedLock: Int = 0
    private var lastSafeWarnState: Int = 0
    private var lastMaintainRemindState: Int = 0
    private var lastSteerAssis: Int = 0
    private var lastRearViewMirrorFlip: Int = 0
    private var lastDriverSeatAutoReturn: Int = 0
    private var lastSteerPositionAutoReturn: Int = 0
    private var lastRemoteControlUpwindowState: Int = 0
    private var lastRemoteControlDownwindowState: Int = 0
    private var lastLockCarRiseWindow: Int = 0
    private var lastMicroSwitchLockWindowState: Int = 0
    private var lastMicroSwitchUnlockWindowState: Int = 0
    private var lastBackHomeLightDelayValue: Int = 0
    private var lastLeftHomeLightDelayValue: Int = 0
    private var lastBackDoorElectricMode: Int = 0

    // 数据缓存 - 发动机类
    private var lastEngineDisplacement: Double = 0.0
    private var lastEngineCode: String = ""
    private var lastEnginePower: Int = 0
    private var lastEngineSpeed: Int = 0
    private var lastEngineCoolantLevel: Int = 0
    private var lastOilLevel: Int = 0

    // 数据缓存 - 全景摄像头类
    private var lastPanoOutputSignal: Int = 0
    private var lastPanoWorkState: Int = 0
    private var lastBackLineConfig: Int = 0
    private var lastPanoOutputState: Int = 0
    private var lastPanoRotation: Int = 0
    private var lastDisplayMode: Int = 0
    private var lastPanoramaOnlineState: Int = 0

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

    // ==================== 车速类接口 ====================
    private var speedListenerEnabled = false

    fun getSpeedData(): Map<String, Any?> {
        return mapOf(
            "currentSpeed" to lastSpeed,
            "accelerateDepth" to lastAccelerateDepth,
            "brakeDepth" to lastBrakeDepth
        )
    }

    fun enableSpeedListener(enabled: Boolean) {
        speedListenerEnabled = enabled
        sendCarLog("车速监听器状态: $enabled")
        if (enabled) {
            sendSpeedData()
        }
    }

    private fun sendSpeedData() {
        try {
            val data = getSpeedData()
            val jsonString = JSONObject(data).toString()
            methodChannel?.invokeMethod("onSpeedDataChanged", jsonString)
        } catch (e: Exception) {
            sendCarLog("发送车速数据失败: ${e.message}")
        }
    }

    // ==================== 空调类接口 ====================
    private var acListenerEnabled = false

    private val acListener = object : AbsBYDAutoAcListener() {
        override fun onAcStarted() {
            sendCarLog("空调监听器回调 - 空调开启")
            lastAcStartState = 1
            if (acListenerEnabled) sendAcData()
            sendCarData(buildCarData())
        }

        override fun onAcStoped() {
            sendCarLog("空调监听器回调 - 空调关闭")
            lastAcStartState = 0
            if (acListenerEnabled) sendAcData()
            sendCarData(buildCarData())
        }

        override fun onAcRearStarted() {
            sendCarLog("空调监听器回调 - 后空调开启")
            lastRearAcStartState = 1
            if (acListenerEnabled) sendAcData()
            sendCarData(buildCarData())
        }

        override fun onAcRearStoped() {
            sendCarLog("空调监听器回调 - 后空调关闭")
            lastRearAcStartState = 0
            if (acListenerEnabled) sendAcData()
            sendCarData(buildCarData())
        }

        override fun onAcCtrlModeChanged(mode: Int) {
            sendCarLog("空调监听器回调 - 控制方式变化: $mode")
            lastAcControlMode = mode
            if (acListenerEnabled) sendAcData()
            sendCarData(buildCarData())
        }

        override fun onAcCycleModeChanged(mode: Int) {
            sendCarLog("空调监听器回调 - 循环方式变化: $mode")
            lastAcCycleMode = mode
            if (acListenerEnabled) sendAcData()
            sendCarData(buildCarData())
        }

        override fun onAcWindModeChanged(mode: Int) {
            sendCarLog("空调监听器回调 - 出风模式变化: $mode")
            lastAcWindMode = mode
            if (acListenerEnabled) sendAcData()
            sendCarData(buildCarData())
        }

        override fun onAcDefrostStateChanged(area: Int, state: Int) {
            sendCarLog("空调监听器回调 - 除霜状态变化 area=$area, state=$state")
            when (area) {
                BYDAutoAcDevice.AC_DEFROST_AREA_FRONT -> lastAcDefrostStateFront = state
                BYDAutoAcDevice.AC_DEFROST_AREA_REAR -> lastAcDefrostStateRear = state
            }
            if (acListenerEnabled) sendAcData()
            sendCarData(buildCarData())
        }

        override fun onAcWindLevelChanged(level: Int) {
            sendCarLog("空调监听器回调 - 风量档位变化: $level")
            lastAcWindLevel = level
            if (acListenerEnabled) sendAcData()
            sendCarData(buildCarData())
        }

        override fun onTemperatureChanged(area: Int, value: Int) {
            sendCarLog("空调监听器回调 - 温度变化 area=$area, value=$value")
            when (area) {
                BYDAutoAcDevice.AC_TEMPERATURE_MAIN -> lastAcTemperatureMain = value
                BYDAutoAcDevice.AC_TEMPERATURE_DEPUTY -> lastAcTemperatureDeputy = value
                BYDAutoAcDevice.AC_TEMPERATURE_REAR -> lastAcTemperatureRear = value
                BYDAutoAcDevice.AC_TEMPERATURE_OUT -> lastAcTemperatureOut = value
            }
            if (acListenerEnabled) sendAcData()
            sendCarData(buildCarData())
        }

        override fun onTemperatureUnitChanged(unit: Int) {
            sendCarLog("空调监听器回调 - 温度单位变化: $unit")
            lastTemperatureUnit = unit
            if (acListenerEnabled) sendAcData()
            sendCarData(buildCarData())
        }

        override fun onAcCompressorModeChanged(mode: Int) {
            sendCarLog("空调监听器回调 - 压缩机状态变化: $mode")
            lastAcCompressorMode = mode
            if (acListenerEnabled) sendAcData()
            sendCarData(buildCarData())
        }

        override fun onAcVentilationStateChanged(state: Int) {
            sendCarLog("空调监听器回调 - 通风状态变化: $state")
            lastAcVentilationState = state
            if (acListenerEnabled) sendAcData()
            sendCarData(buildCarData())
        }

        override fun onAcCompressorManualSignChanged(sign: Int) {
            sendCarLog("空调监听器回调 - 压缩机手动标志变化: $sign")
            lastAcCompressorManualSign = sign
            if (acListenerEnabled) sendAcData()
            sendCarData(buildCarData())
        }

        override fun onAcWindLevelManualSignChanged(sign: Int) {
            sendCarLog("空调监听器回调 - 风量手动标志变化: $sign")
            lastAcWindLevelManualSign = sign
            if (acListenerEnabled) sendAcData()
            sendCarData(buildCarData())
        }

        override fun onAcWindModeManualSignChanged(sign: Int) {
            sendCarLog("空调监听器回调 - 出风模式手动标志变化: $sign")
            lastAcWindModeManualSign = sign
            if (acListenerEnabled) sendAcData()
            sendCarData(buildCarData())
        }
    }

    fun getAcData(): Map<String, Any?> {
        return mapOf(
            "acCompressorMode" to lastAcCompressorMode,
            "acCompressorManualSign" to lastAcCompressorManualSign,
            "acWindLevelManualSign" to lastAcWindLevelManualSign,
            "acWindModeManualSign" to lastAcWindModeManualSign,
            "acStartState" to lastAcStartState,
            "acControlMode" to lastAcControlMode,
            "acCycleMode" to lastAcCycleMode,
            "acWindMode" to lastAcWindMode,
            "acDefrostStateFront" to lastAcDefrostStateFront,
            "acDefrostStateRear" to lastAcDefrostStateRear,
            "acWindLevel" to lastAcWindLevel,
            "acTemperatureMain" to lastAcTemperatureMain,
            "acTemperatureDeputy" to lastAcTemperatureDeputy,
            "acTemperatureRear" to lastAcTemperatureRear,
            "acTemperatureOut" to lastAcTemperatureOut,
            "temperatureUnit" to lastTemperatureUnit,
            "acTemperatureControlMode" to lastAcTemperatureControlMode,
            "acVentilationState" to lastAcVentilationState,
            "rearAcStartState" to lastRearAcStartState
        )
    }

    fun enableAcListener(enabled: Boolean) {
        acListenerEnabled = enabled
        sendCarLog("空调监听器状态: $enabled")
        if (enabled) {
            try {
                acDevice?.registerListener(acListener)
            } catch (e: Exception) {
                sendCarLog("注册空调监听器失败: ${e.message}")
            }
            sendAcData()
        } else {
            try {
                acDevice?.unregisterListener(acListener)
            } catch (e: Exception) {
                sendCarLog("取消注册空调监听器失败: ${e.message}")
            }
        }
    }

    private fun sendAcData() {
        try {
            val data = getAcData()
            val jsonString = JSONObject(data).toString()
            methodChannel?.invokeMethod("onAcDataChanged", jsonString)
        } catch (e: Exception) {
            sendCarLog("发送空调数据失败: ${e.message}")
        }
    }

    fun setAcData(field: String, value: Any): Boolean {
        return try {
            val result = when (field) {
                "start" -> acDevice?.start(
                    if (value is Map<*, *>) (value["setSource"] as? Int) ?: 1 else 1
                ) ?: -1
                "stop" -> acDevice?.stop(
                    if (value is Map<*, *>) (value["setSource"] as? Int) ?: 1 else 1
                ) ?: -1
                "startRearAc" -> acDevice?.startRearAc(
                    if (value is Map<*, *>) (value["setSource"] as? Int) ?: 1 else 1
                ) ?: -1
                "stopRearAc" -> acDevice?.stopRearAc(
                    if (value is Map<*, *>) (value["setSource"] as? Int) ?: 1 else 1
                ) ?: -1
                "acControlMode" -> {
                    val v = value as Map<*, *>
                    acDevice?.setAcControlMode(
                        (v["setSource"] as? Int) ?: 1,
                        (v["value"] as? Int) ?: 0
                    ) ?: -1
                }
                "acCycleMode" -> {
                    val v = value as Map<*, *>
                    acDevice?.setAcCycleMode(
                        (v["setSource"] as? Int) ?: 1,
                        (v["value"] as? Int) ?: 0
                    ) ?: -1
                }
                "acWindMode" -> {
                    val v = value as Map<*, *>
                    acDevice?.setAcWindMode(
                        (v["setSource"] as? Int) ?: 1,
                        (v["value"] as? Int) ?: 0
                    ) ?: -1
                }
                "acDefrostState" -> {
                    val v = value as Map<*, *>
                    acDevice?.setAcDefrostState(
                        (v["setSource"] as? Int) ?: 1,
                        (v["area"] as? Int) ?: BYDAutoAcDevice.AC_DEFROST_AREA_FRONT,
                        (v["value"] as? Int) ?: 0
                    ) ?: -1
                }
                "acWindLevel" -> {
                    val v = value as Map<*, *>
                    acDevice?.setAcWindLevel(
                        (v["setSource"] as? Int) ?: 1,
                        (v["level"] as? Int) ?: 0
                    ) ?: -1
                }
                "acTemperature" -> {
                    val v = value as Map<*, *>
                    val area = when (v["area"]) {
                        "main" -> BYDAutoAcDevice.AC_TEMPERATURE_MAIN
                        "deputy" -> BYDAutoAcDevice.AC_TEMPERATURE_DEPUTY
                        "rear" -> BYDAutoAcDevice.AC_TEMPERATURE_REAR
                        else -> BYDAutoAcDevice.AC_TEMPERATURE_MAIN
                    }
                    acDevice?.setAcTemperature(
                        area,
                        (v["value"] as? Int) ?: 25,
                        (v["setSource"] as? Int) ?: 1,
                        (v["unit"] as? Int) ?: 0
                    ) ?: -1
                }
                "acTemperatureControlMode" -> {
                    val v = value as Map<*, *>
                    acDevice?.setAcTemperatureControlMode(
                        (v["setSource"] as? Int) ?: 1,
                        (v["value"] as? Int) ?: 0
                    ) ?: -1
                }
                "acVentilationState" -> {
                    val v = value as Map<*, *>
                    acDevice?.setAcVentilationState(
                        (v["setSource"] as? Int) ?: 1,
                        (v["value"] as? Int) ?: 0
                    ) ?: -1
                }
                else -> -1
            }
            result == 0
        } catch (e: Exception) {
            sendCarLog("设置空调数据失败: ${e.message}")
            false
        }
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

    // ==================== 行驶数据类型接口 ====================
    private var statisticListenerEnabled = false

    fun getStatisticData(): Map<String, Any?> {
        return mapOf(
            "drivingTime" to lastSpeed,
            "elecDrivingRange" to lastAccelerateDepth,
            "elecPercentage" to lastElecPercentage,
            "fuelDrivingRange" to lastBrakeDepth,
            "fuelPercentage" to lastFuelPercentage,
            "lastElecConPHM" to 0.0,
            "lastFuelConPHM" to 0.0,
            "totalElecConPHM" to 0.0,
            "totalFuelConPHM" to 0.0,
            "totalFuelCon" to 0.0,
            "totalElecCon" to 0.0,
            "totalMileage" to lastTotalMileage,
            "keyBatteryLevel" to 0,
            "evMileage" to lastEvMileage
        )
    }

    fun enableStatisticListener(enabled: Boolean) {
        statisticListenerEnabled = enabled
        sendCarLog("行驶数据监听器状态: $enabled")
        if (enabled) {
            sendStatisticData()
        }
    }

    fun setStatisticData(field: String, value: Any): Boolean {
        sendCarLog("设置行驶数据: $field = $value")
        return false
    }

    private fun sendStatisticData() {
        try {
            val data = getStatisticData()
            val jsonString = JSONObject(data).toString()
            methodChannel?.invokeMethod("onStatisticDataChanged", jsonString)
        } catch (e: Exception) {
            sendCarLog("发送行驶数据失败: ${e.message}")
        }
    }

    // ==================== 仪表类接口 ====================
    private var instrumentListenerEnabled = false

    fun getInstrumentData(): Map<String, Any?> {
        return mapOf(
            "malfunctionInfo" to emptyMap<Int, Int>(),
            "alarmBuzzleState" to 0,
            "unit" to emptyMap<Int, Int>(),
            "maintenanceInfo" to emptyMap<Int, Int>(),
            "externalChargingPower" to lastExternalChargingPower
        )
    }

    fun enableInstrumentListener(enabled: Boolean) {
        instrumentListenerEnabled = enabled
        sendCarLog("仪表监听器状态: $enabled")
        if (enabled) {
            sendInstrumentData()
        }
    }

    fun setInstrumentData(field: String, value: Any): Boolean {
        sendCarLog("设置仪表数据: $field = $value")
        return false
    }

    fun setInstrumentUnit(unitName: Int, unitValue: Int): Boolean {
        sendCarLog("设置仪表单位: $unitName = $unitValue")
        return false
    }

    fun setMaintenanceInfo(typeName: Int, infoValue: Int): Boolean {
        sendCarLog("设置保养信息: $typeName = $infoValue")
        return false
    }

    private fun sendInstrumentData() {
        try {
            val data = getInstrumentData()
            val jsonString = JSONObject(data).toString()
            methodChannel?.invokeMethod("onInstrumentDataChanged", jsonString)
        } catch (e: Exception) {
            sendCarLog("发送仪表数据失败: ${e.message}")
        }
    }

    // ==================== 门锁类接口 ====================
    private var doorLockListenerEnabled = false

    fun getDoorData(): Map<String, Any?> {
        return mapOf(
            "leftFront" to lastDoorLockLeftFront,
            "leftRear" to lastDoorLockLeftRear,
            "rightFront" to lastDoorLockRightFront,
            "rightRear" to lastDoorLockRightRear,
            "back" to lastDoorLockBack,
            "childlockLeft" to lastDoorLockChildlockLeft,
            "childlockRight" to lastDoorLockChildlockRight
        )
    }

    fun enableDoorListener(enabled: Boolean) {
        doorLockListenerEnabled = enabled
        sendCarLog("门锁监听器状态: $enabled")
        if (enabled) {
            sendDoorData()
        }
    }

    fun setDoorData(field: String, value: Any): Boolean {
        sendCarLog("设置门锁数据: $field = $value")
        return false
    }

    private fun sendDoorData() {
        try {
            val data = getDoorData()
            val jsonString = JSONObject(data).toString()
            methodChannel?.invokeMethod("onDoorDataChanged", jsonString)
        } catch (e: Exception) {
            sendCarLog("发送门锁数据失败: ${e.message}")
        }
    }

    // ==================== 车辆设置类接口 ====================
    private var vehicleSettingListenerEnabled = false

    fun getVehicleSettingData(): Map<String, Any?> {
        return mapOf(
            "acBTWind" to lastAcBTWind,
            "acTunnelCycle" to lastAcTunnelCycle,
            "acPauseCycle" to lastAcPauseCycle,
            "acAutoAir" to lastAcAutoAir,
            "pm25Power" to lastPm25Power,
            "pm25SwitchCheck" to lastPm25SwitchCheck,
            "pm25TimeCheck" to lastPm25TimeCheck,
            "energyFeedback" to lastEnergyFeedback,
            "socTarget" to lastSocTarget,
            "chargingPort" to lastChargingPort,
            "autoExternalRearMirrorFollowUp" to lastAutoExternalRearMirrorFollowUp,
            "lockOff" to lastLockOff,
            "language" to lastLanguage,
            "overspeedLock" to lastOverspeedLock,
            "safeWarnState" to lastSafeWarnState,
            "maintainRemindState" to lastMaintainRemindState,
            "steerAssis" to lastSteerAssis,
            "rearViewMirrorFlip" to lastRearViewMirrorFlip,
            "driverSeatAutoReturn" to lastDriverSeatAutoReturn,
            "steerPositionAutoReturn" to lastSteerPositionAutoReturn,
            "remoteControlUpwindowState" to lastRemoteControlUpwindowState,
            "remoteControlDownwindowState" to lastRemoteControlDownwindowState,
            "lockCarRiseWindow" to lastLockCarRiseWindow,
            "microSwitchLockWindowState" to lastMicroSwitchLockWindowState,
            "microSwitchUnlockWindowState" to lastMicroSwitchUnlockWindowState,
            "backHomeLightDelayValue" to lastBackHomeLightDelayValue,
            "leftHomeLightDelayValue" to lastLeftHomeLightDelayValue,
            "backDoorElectricMode" to lastBackDoorElectricMode
        )
    }

    fun enableVehicleSettingListener(enabled: Boolean) {
        vehicleSettingListenerEnabled = enabled
        sendCarLog("车辆设置监听器状态: $enabled")
        if (enabled) {
            sendVehicleSettingData()
        }
    }

    fun setVehicleSettingData(field: String, value: Any): Boolean {
        sendCarLog("设置车辆设置数据: $field = $value")
        return false
    }

    fun vehicleSettingHasFeature(feature: String): Boolean {
        sendCarLog("检查车辆设置功能: $feature")
        return false
    }

    private fun sendVehicleSettingData() {
        try {
            val data = getVehicleSettingData()
            val jsonString = JSONObject(data).toString()
            methodChannel?.invokeMethod("onVehicleSettingDataChanged", jsonString)
        } catch (e: Exception) {
            sendCarLog("发送车辆设置数据失败: ${e.message}")
        }
    }

    // ==================== 发动机类接口 ====================
    private var engineListenerEnabled = false

    fun getEngineData(): Map<String, Any?> {
        return mapOf(
            "engineDisplacement" to lastEngineDisplacement,
            "engineCode" to lastEngineCode,
            "enginePower" to lastEnginePower,
            "engineSpeed" to lastEngineSpeed,
            "engineCoolantLevel" to lastEngineCoolantLevel,
            "oilLevel" to lastOilLevel
        )
    }

    fun enableEngineListener(enabled: Boolean) {
        engineListenerEnabled = enabled
        sendCarLog("发动机监听器状态: $enabled")
        if (enabled) {
            sendEngineData()
        }
    }

    fun setEngineData(field: String, value: Any): Boolean {
        sendCarLog("设置发动机数据: $field = $value")
        return false
    }

    private fun sendEngineData() {
        try {
            val data = getEngineData()
            val jsonString = JSONObject(data).toString()
            methodChannel?.invokeMethod("onEngineDataChanged", jsonString)
        } catch (e: Exception) {
            sendCarLog("发送发动机数据失败: ${e.message}")
        }
    }

    // ==================== 全景摄像头类接口 ====================
    private var panoramaListenerEnabled = false

    fun getPanoramaData(): Map<String, Any?> {
        return mapOf(
            "panoOutputSignal" to lastPanoOutputSignal,
            "panoWorkState" to lastPanoWorkState,
            "backLineConfig" to lastBackLineConfig,
            "panoOutputState" to lastPanoOutputState,
            "panoRotation" to lastPanoRotation,
            "displayMode" to lastDisplayMode,
            "panoramaOnlineState" to lastPanoramaOnlineState
        )
    }

    fun enablePanoramaListener(enabled: Boolean) {
        panoramaListenerEnabled = enabled
        sendCarLog("全景摄像头监听器状态: $enabled")
        if (enabled) {
            sendPanoramaData()
        }
    }

    fun setPanoramaData(field: String, value: Any): Boolean {
        sendCarLog("设置全景摄像头数据: $field = $value")
        return false
    }

    private fun sendPanoramaData() {
        try {
            val data = getPanoramaData()
            val jsonString = JSONObject(data).toString()
            methodChannel?.invokeMethod("onPanoramaDataChanged", jsonString)
        } catch (e: Exception) {
            sendCarLog("发送全景摄像头数据失败: ${e.message}")
        }
    }

    // ==================== 传感器类接口 ====================
    private var sensorListenerEnabled = false
    private var lastLightIntensity: Int = 0

    fun getSensorData(): Map<String, Any?> {
        return mapOf("lightIntensity" to lastLightIntensity)
    }

    fun enableSensorListener(enabled: Boolean) {
        sensorListenerEnabled = enabled
        sendCarLog("传感器监听器状态: $enabled")
        if (enabled) sendSensorData()
    }

    fun setSensorData(field: String, value: Any): Boolean {
        sendCarLog("设置传感器数据: $field = $value")
        return false
    }

    private fun sendSensorData() {
        try {
            val data = getSensorData()
            val jsonString = JSONObject(data).toString()
            methodChannel?.invokeMethod("onSensorDataChanged", jsonString)
        } catch (e: Exception) {
            sendCarLog("发送传感器数据失败: ${e.message}")
        }
    }

    // ==================== 时间类接口 ====================
    private var timeListenerEnabled = false
    private var lastYear: Int = 0
    private var lastMonth: Int = 0
    private var lastDay: Int = 0
    private var lastHour: Int = 0
    private var lastMinute: Int = 0
    private var lastSecond: Int = 0
    private var lastTimeFormat: Int = 0

    fun getTimeData(): Map<String, Any?> {
        return mapOf(
            "year" to lastYear,
            "month" to lastMonth,
            "day" to lastDay,
            "hour" to lastHour,
            "minute" to lastMinute,
            "second" to lastSecond,
            "timeFormat" to lastTimeFormat
        )
    }

    fun enableTimeListener(enabled: Boolean) {
        timeListenerEnabled = enabled
        sendCarLog("时间监听器状态: $enabled")
        if (enabled) sendTimeData()
    }

    fun setTimeData(field: String, value: Any): Boolean {
        sendCarLog("设置时间数据: $field = $value")
        return false
    }

    private fun sendTimeData() {
        try {
            val data = getTimeData()
            val jsonString = JSONObject(data).toString()
            methodChannel?.invokeMethod("onTimeDataChanged", jsonString)
        } catch (e: Exception) {
            sendCarLog("发送时间数据失败: ${e.message}")
        }
    }

    // ==================== 能量模式类接口 ====================
    private var energyModeListenerEnabled = false
    private var lastEnergyMode: Int = 0
    private var lastOperationMode: Int = 0
    private var lastPowerGenerationState: Int = 0
    private var lastPowerGenerationValue: Int = 0
    private var lastRoadSurfaceMode: Int = 0

    fun getEnergyModeData(): Map<String, Any?> {
        return mapOf(
            "energyMode" to lastEnergyMode,
            "operationMode" to lastOperationMode,
            "powerGenerationState" to lastPowerGenerationState,
            "powerGenerationValue" to lastPowerGenerationValue,
            "roadSurfaceMode" to lastRoadSurfaceMode
        )
    }

    fun enableEnergyModeListener(enabled: Boolean) {
        energyModeListenerEnabled = enabled
        sendCarLog("能量模式监听器状态: $enabled")
        if (enabled) sendEnergyModeData()
    }

    fun setEnergyModeData(field: String, value: Any): Boolean {
        sendCarLog("设置能量模式数据: $field = $value")
        return false
    }

    private fun sendEnergyModeData() {
        try {
            val data = getEnergyModeData()
            val jsonString = JSONObject(data).toString()
            methodChannel?.invokeMethod("onEnergyModeDataChanged", jsonString)
        } catch (e: Exception) {
            sendCarLog("发送能量模式数据失败: ${e.message}")
        }
    }

    // ==================== 雷达类接口 ====================
    private var radarListenerEnabled = false
    private var lastRadarLeftFront: Int = 0
    private var lastRadarRightFront: Int = 0
    private var lastRadarLeftRear: Int = 0
    private var lastRadarRightRear: Int = 0
    private var lastRadarLeft: Int = 0
    private var lastRadarRight: Int = 0
    private var lastFrontLeftMid: Int = 0
    private var lastFrontRightMid: Int = 0
    private var lastReverseRadarSwitch: Int = 0

    fun getRadarData(): Map<String, Any?> {
        return mapOf(
            "leftFront" to lastRadarLeftFront,
            "rightFront" to lastRadarRightFront,
            "leftRear" to lastRadarLeftRear,
            "rightRear" to lastRadarRightRear,
            "left" to lastRadarLeft,
            "right" to lastRadarRight,
            "frontLeftMid" to lastFrontLeftMid,
            "frontRightMid" to lastFrontRightMid,
            "reverseRadarSwitch" to lastReverseRadarSwitch
        )
    }

    fun enableRadarListener(enabled: Boolean) {
        radarListenerEnabled = enabled
        sendCarLog("雷达监听器状态: $enabled")
        if (enabled) sendRadarData()
    }

    fun setRadarData(field: String, value: Any): Boolean {
        sendCarLog("设置雷达数据: $field = $value")
        return false
    }

    private fun sendRadarData() {
        try {
            val data = getRadarData()
            val jsonString = JSONObject(data).toString()
            methodChannel?.invokeMethod("onRadarDataChanged", jsonString)
        } catch (e: Exception) {
            sendCarLog("发送雷达数据失败: ${e.message}")
        }
    }

    // ==================== 轮胎类接口 (新版完整数据) ====================
    private var tyreDataListenerEnabled = false
    private var lastTyrePressureLfNew: Int = 0
    private var lastTyrePressureRfNew: Int = 0
    private var lastTyrePressureLrNew: Int = 0
    private var lastTyrePressureRrNew: Int = 0
    private var lastTyreAirLeakStateLf: Int = 0
    private var lastTyreAirLeakStateRf: Int = 0
    private var lastTyreAirLeakStateLr: Int = 0
    private var lastTyreAirLeakStateRr: Int = 0
    private var lastTyreBatteryState: Int = 0
    private var lastTyreSystemState: Int = 0
    private var lastTyreTemperatureState: Int = 0
    private var lastTyreSignalStateLf: Int = 0
    private var lastTyreSignalStateRf: Int = 0
    private var lastTyreSignalStateLr: Int = 0
    private var lastTyreSignalStateRr: Int = 0

    fun getTyreData(): Map<String, Any?> {
        return mapOf(
            "tyrePressureLf" to lastTyrePressureLfNew,
            "tyrePressureRf" to lastTyrePressureRfNew,
            "tyrePressureLr" to lastTyrePressureLrNew,
            "tyrePressureRr" to lastTyrePressureRrNew,
            "tyreAirLeakStateLf" to lastTyreAirLeakStateLf,
            "tyreAirLeakStateRf" to lastTyreAirLeakStateRf,
            "tyreAirLeakStateLr" to lastTyreAirLeakStateLr,
            "tyreAirLeakStateRr" to lastTyreAirLeakStateRr,
            "tyreBatteryState" to lastTyreBatteryState,
            "tyreSystemState" to lastTyreSystemState,
            "tyreTemperatureState" to lastTyreTemperatureState,
            "tyreSignalStateLf" to lastTyreSignalStateLf,
            "tyreSignalStateRf" to lastTyreSignalStateRf,
            "tyreSignalStateLr" to lastTyreSignalStateLr,
            "tyreSignalStateRr" to lastTyreSignalStateRr
        )
    }

    fun enableTyreListener(enabled: Boolean) {
        tyreDataListenerEnabled = enabled
        sendCarLog("轮胎数据监听器状态: $enabled")
        if (enabled) sendTyreData()
    }

    fun setTyreData(field: String, value: Any): Boolean {
        sendCarLog("设置轮胎数据: $field = $value")
        return false
    }

    private fun sendTyreData() {
        try {
            val data = getTyreData()
            val jsonString = JSONObject(data).toString()
            methodChannel?.invokeMethod("onTyreDataChanged", jsonString)
        } catch (e: Exception) {
            sendCarLog("发送轮胎数据失败: ${e.message}")
        }
    }

    // ==================== 空气质量类接口 ====================
    private var airQualityListenerEnabled = false
    private var lastPm25OnlineState: Int = 0
    private var lastPm25CheckStateIn: Int = 0
    private var lastPm25CheckStateOut: Int = 0
    private var lastPm25LevelIn: Int = 0
    private var lastPm25LevelOut: Int = 0
    private var lastPm25ValueIn: Int = 0
    private var lastPm25ValueOut: Int = 0

    fun getAirQualityData(): Map<String, Any?> {
        return mapOf(
            "pm25OnlineState" to lastPm25OnlineState,
            "pm25CheckStateIn" to lastPm25CheckStateIn,
            "pm25CheckStateOut" to lastPm25CheckStateOut,
            "pm25LevelIn" to lastPm25LevelIn,
            "pm25LevelOut" to lastPm25LevelOut,
            "pm25ValueIn" to lastPm25ValueIn,
            "pm25ValueOut" to lastPm25ValueOut
        )
    }

    fun enableAirQualityListener(enabled: Boolean) {
        airQualityListenerEnabled = enabled
        sendCarLog("空气质量监听器状态: $enabled")
        if (enabled) sendAirQualityData()
    }

    fun setAirQualityData(field: String, value: Any): Boolean {
        sendCarLog("设置空气质量数据: $field = $value")
        return false
    }

    private fun sendAirQualityData() {
        try {
            val data = getAirQualityData()
            val jsonString = JSONObject(data).toString()
            methodChannel?.invokeMethod("onAirQualityDataChanged", jsonString)
        } catch (e: Exception) {
            sendCarLog("发送空气质量数据失败: ${e.message}")
        }
    }

    // ==================== 充电类接口 ====================
    private var chargeListenerEnabled = false
    private var lastChargerFaultState: Int = 0
    private var lastChargerWorkState: Int = 0
    private var lastChargingCapacity: Double = 0.0
    private var lastChargingType: Int = 0
    private var lastChargingRestTimeHour: Int = 0
    private var lastChargingRestTimeMinute: Int = 0
    private var lastChargingCapStateAc: Int = 0
    private var lastChargingCapStateDc: Int = 0
    private var lastChargingPortLockRebackState: Int = 0
    private var lastDischargeRequestState: Int = 0
    private var lastChargerState: Int = 0
    private var lastChargingGunState: Int = 0
    private var lastChargingPower: Double = 0.0
    private var lastBatteryManagementDeviceState: Int = 0
    private var lastChargingScheduleEnableState: Int = 0
    private var lastChargingScheduleState: Int = 0
    private var lastChargingGunNotInsertedState: Int = 0
    private var lastChargingScheduleTimeHour: Int = 0
    private var lastChargingScheduleTimeMinute: Int = 0

    fun getChargeData(): Map<String, Any?> {
        return mapOf(
            "chargerFaultState" to lastChargerFaultState,
            "chargerWorkState" to lastChargerWorkState,
            "chargingCapacity" to lastChargingCapacity,
            "chargingType" to lastChargingType,
            "chargingRestTimeHour" to lastChargingRestTimeHour,
            "chargingRestTimeMinute" to lastChargingRestTimeMinute,
            "chargingCapStateAc" to lastChargingCapStateAc,
            "chargingCapStateDc" to lastChargingCapStateDc,
            "chargingPortLockRebackState" to lastChargingPortLockRebackState,
            "dischargeRequestState" to lastDischargeRequestState,
            "chargerState" to lastChargerState,
            "chargingGunState" to lastChargingGunState,
            "chargingPower" to lastChargingPower,
            "batteryManagementDeviceState" to lastBatteryManagementDeviceState,
            "chargingScheduleEnableState" to lastChargingScheduleEnableState,
            "chargingScheduleState" to lastChargingScheduleState,
            "chargingGunNotInsertedState" to lastChargingGunNotInsertedState,
            "chargingScheduleTimeHour" to lastChargingScheduleTimeHour,
            "chargingScheduleTimeMinute" to lastChargingScheduleTimeMinute
        )
    }

    fun enableChargeListener(enabled: Boolean) {
        chargeListenerEnabled = enabled
        sendCarLog("充电监听器状态: $enabled")
        if (enabled) sendChargeData()
    }

    fun setChargeData(field: String, value: Any): Boolean {
        sendCarLog("设置充电数据: $field = $value")
        return false
    }

    private fun sendChargeData() {
        try {
            val data = getChargeData()
            val jsonString = JSONObject(data).toString()
            methodChannel?.invokeMethod("onChargeDataChanged", jsonString)
        } catch (e: Exception) {
            sendCarLog("发送充电数据失败: ${e.message}")
        }
    }

    // ==================== 媒体中心类接口 ====================
    private var mediaListenerEnabled = false
    private var lastMediaType: Int = 0
    private var lastPlayMode: Int = 0
    private var lastPlayState: Int = 0
    private var lastFileName: String = ""
    private var lastArtistName: String = ""
    private var lastAlbumName: String = ""

    fun getMediaData(): Map<String, Any?> {
        return mapOf(
            "mediaType" to lastMediaType,
            "playMode" to lastPlayMode,
            "playState" to lastPlayState,
            "fileName" to lastFileName,
            "artistName" to lastArtistName,
            "albumName" to lastAlbumName
        )
    }

    fun enableMediaListener(enabled: Boolean) {
        mediaListenerEnabled = enabled
        sendCarLog("媒体中心监听器状态: $enabled")
        if (enabled) sendMediaData()
    }

    fun setMediaData(field: String, value: Any): Boolean {
        sendCarLog("设置媒体中心数据: $field = $value")
        return false
    }

    private fun sendMediaData() {
        try {
            val data = getMediaData()
            val jsonString = JSONObject(data).toString()
            methodChannel?.invokeMethod("onMediaDataChanged", jsonString)
        } catch (e: Exception) {
            sendCarLog("发送媒体中心数据失败: ${e.message}")
        }
    }

    // ==================== 车身状态类接口 ====================
    private var bodyStatusListenerEnabled = false
    private var lastAutoVIN: String = ""
    private var lastAutoModelName: Int = 0
    private var lastAutoSystemState: Int = 0
    private var lastDoorStateLf: Int = 0
    private var lastDoorStateRf: Int = 0
    private var lastDoorStateLr: Int = 0
    private var lastDoorStateRr: Int = 0
    private var lastDoorStateHood: Int = 0
    private var lastDoorStateLuggage: Int = 0
    private var lastWindowStateLf: Int = 0
    private var lastWindowStateRf: Int = 0
    private var lastWindowStateLr: Int = 0
    private var lastWindowStateRr: Int = 0
    private var lastMoonRoofPercent: Int = 0
    private var lastSunshadePercent: Int = 0
    private var lastBatteryVoltageLevel: Int = 0
    private var lastPowerLevel: Int = 0
    private var lastSteeringWheelAngle: Int = 0
    private var lastSteeringWheelSpeed: Int = 0
    private var lastFuelElecLowPower: Int = 0
    private var lastAlarmState: Int = 0
    private var lastMoonRoofConfig: Int = 0

    fun getBodyStatusData(): Map<String, Any?> {
        return mapOf(
            "autoVIN" to lastAutoVIN,
            "autoModelName" to lastAutoModelName,
            "autoSystemState" to lastAutoSystemState,
            "doorStateLf" to lastDoorStateLf,
            "doorStateRf" to lastDoorStateRf,
            "doorStateLr" to lastDoorStateLr,
            "doorStateRr" to lastDoorStateRr,
            "doorStateHood" to lastDoorStateHood,
            "doorStateLuggage" to lastDoorStateLuggage,
            "windowStateLf" to lastWindowStateLf,
            "windowStateRf" to lastWindowStateRf,
            "windowStateLr" to lastWindowStateLr,
            "windowStateRr" to lastWindowStateRr,
            "moonRoofPercent" to lastMoonRoofPercent,
            "sunshadePercent" to lastSunshadePercent,
            "batteryVoltageLevel" to lastBatteryVoltageLevel,
            "powerLevel" to lastPowerLevel,
            "steeringWheelAngle" to lastSteeringWheelAngle,
            "steeringWheelSpeed" to lastSteeringWheelSpeed,
            "fuelElecLowPower" to lastFuelElecLowPower,
            "alarmState" to lastAlarmState,
            "moonRoofConfig" to lastMoonRoofConfig
        )
    }

    fun enableBodyStatusListener(enabled: Boolean) {
        bodyStatusListenerEnabled = enabled
        sendCarLog("车身状态监听器状态: $enabled")
        if (enabled) sendBodyStatusData()
    }

    fun setBodyStatusData(field: String, value: Any): Boolean {
        sendCarLog("设置车身状态数据: $field = $value")
        return false
    }

    private fun sendBodyStatusData() {
        try {
            val data = getBodyStatusData()
            val jsonString = JSONObject(data).toString()
            methodChannel?.invokeMethod("onBodyStatusDataChanged", jsonString)
        } catch (e: Exception) {
            sendCarLog("发送车身状态数据失败: ${e.message}")
        }
    }

    // ==================== 车灯类接口 ====================
    private var lightListenerEnabled = false
    private var lastLightAutoStatus: Int = 0
    private var lastLightSide: Int = 0
    private var lastLightLowBeam: Int = 0
    private var lastLightHighBeam: Int = 0
    private var lastLightLeftTurnSignal: Int = 0
    private var lastLightRightTurnSignal: Int = 0
    private var lastLightFrontFog: Int = 0
    private var lastLightRearFog: Int = 0
    private var lastLightFoot: Int = 0
    private var lastAfsSwitch: Int = 0

    fun getLightData(): Map<String, Any?> {
        return mapOf(
            "lightAutoStatus" to lastLightAutoStatus,
            "lightSide" to lastLightSide,
            "lightLowBeam" to lastLightLowBeam,
            "lightHighBeam" to lastLightHighBeam,
            "lightLeftTurnSignal" to lastLightLeftTurnSignal,
            "lightRightTurnSignal" to lastLightRightTurnSignal,
            "lightFrontFog" to lastLightFrontFog,
            "lightRearFog" to lastLightRearFog,
            "lightFoot" to lastLightFoot,
            "afsSwitch" to lastAfsSwitch
        )
    }

    fun enableLightListener(enabled: Boolean) {
        lightListenerEnabled = enabled
        sendCarLog("车灯监听器状态: $enabled")
        if (enabled) sendLightData()
    }

    fun setLightData(field: String, value: Any): Boolean {
        sendCarLog("设置车灯数据: $field = $value")
        return false
    }

    private fun sendLightData() {
        try {
            val data = getLightData()
            val jsonString = JSONObject(data).toString()
            methodChannel?.invokeMethod("onLightDataChanged", jsonString)
        } catch (e: Exception) {
            sendCarLog("发送车灯数据失败: ${e.message}")
        }
    }
}