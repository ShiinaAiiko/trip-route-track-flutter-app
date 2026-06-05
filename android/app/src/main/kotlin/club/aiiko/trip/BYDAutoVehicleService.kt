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
import android.hardware.bydauto.pm2p5.BYDAutoPM2p5Device
import android.hardware.bydauto.pm2p5.AbsBYDAutoPM2p5Listener
import android.hardware.bydauto.speed.BYDAutoSpeedDevice
import android.hardware.bydauto.speed.AbsBYDAutoSpeedListener
import android.hardware.bydauto.statistic.BYDAutoStatisticDevice
import android.hardware.bydauto.statistic.AbsBYDAutoStatisticListener
import android.hardware.bydauto.tyre.BYDAutoTyreDevice
import android.hardware.bydauto.tyre.AbsBYDAutoTyreListener
import android.hardware.bydauto.sensor.BYDAutoSensorDevice
import android.hardware.bydauto.sensor.AbsBYDAutoSensorListener
import android.hardware.bydauto.time.BYDAutoTimeDevice
import android.hardware.bydauto.time.AbsBYDAutoTimeListener
import android.hardware.bydauto.energy.BYDAutoEnergyDevice
import android.hardware.bydauto.energy.AbsBYDAutoEnergyListener
import android.hardware.bydauto.radar.BYDAutoRadarDevice
import android.hardware.bydauto.radar.AbsBYDAutoRadarListener
import android.hardware.bydauto.charging.BYDAutoChargingDevice
import android.hardware.bydauto.charging.AbsBYDAutoChargingListener
import android.hardware.bydauto.bodywork.BYDAutoBodyworkDevice
import android.hardware.bydauto.bodywork.AbsBYDAutoBodyworkListener
import android.hardware.bydauto.light.BYDAutoLightDevice
import android.hardware.bydauto.light.AbsBYDAutoLightListener
import android.hardware.bydauto.multimedia.BYDAutoMultimediaDevice
import android.hardware.bydauto.multimedia.AbsBYDAutoMultimediaListener
import android.hardware.bydauto.multimedia.MediaInfo
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
    private var pm2p5Device: BYDAutoPM2p5Device? = null
    private var sensorDevice: BYDAutoSensorDevice? = null
    private var timeDevice: BYDAutoTimeDevice? = null
    private var energyDevice: BYDAutoEnergyDevice? = null
    private var radarDevice: BYDAutoRadarDevice? = null
    private var chargeDevice: BYDAutoChargingDevice? = null
    private var bodyStatusDevice: BYDAutoBodyworkDevice? = null
    private var lightDevice: BYDAutoLightDevice? = null
    private var mediaDevice: BYDAutoMultimediaDevice? = null

    private var methodChannel: MethodChannel? = null
    private var isStarted = false
    private var enableCarDataListener = false
    private var lastSendTime = 0L
    private var debounceDelayMs = 0


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
    // 数据缓存 - 统计类
    private var lastDrivingTime: Double = 0.0
    private var lastElecDrivingRange: Int = 0
    private var lastFuelDrivingRange: Int = 0
    private var lastLastElecConPHM: Double = 0.0
    private var lastLastFuelConPHM: Double = 0.0
    private var lastTotalElecConPHM: Double = 0.0
    private var lastTotalFuelCon: Double = 0.0
    private var lastTotalElecCon: Double = 0.0
    private var lastTotalFuelConPHM: Double = 0.0
    private var lastKeyBatteryLevel: Int = 0

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

    // 数据缓存 - 胎压类
    private var lastTyreAirLeakState: Int = 0
    private var lastTyreBatteryState: Int = 0
    private var lastTyrePressureStateLf: Int = 0
    private var lastTyrePressureStateRf: Int = 0
    private var lastTyrePressureStateLr: Int = 0
    private var lastTyrePressureStateRr: Int = 0
    private var lastTyreSignalStateLf: Int = 0
    private var lastTyreSignalStateRf: Int = 0
    private var lastTyreSignalStateLr: Int = 0
    private var lastTyreSignalStateRr: Int = 0
    private var lastTyreSystemState: Int = 0
    private var lastTyreTemperatureState: Int = 0

    // 数据缓存 - 仪表类
    private var lastMalfunctionInfo: Int = 0
    private var lastMaintenanceInfo: Int = 0
    private var lastTemperatureUnit: Int = 0  // 温度单位
    private var lastPressureUnit: Int = 0     // 气压单位
    private var lastFuelConsumptionUnit: Int = 0  // 油耗距离单位
    private var lastPowerUnit: Int = 0        // 功率单位
    private var lastAlarmBuzzleState: Int = 0 // 蜂鸣器状态

    // 数据缓存 - 媒体类
    private var lastPlayMediaInfo: String = ""

    // 数据缓存 - 空调类
    private var lastAcWindModeShownState: Int = 0

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
        val requiredPermissions = getRequiredPermissions().toList()

        sendCarLog("权限检查结果:")
        var allGranted = true
        requiredPermissions.forEach { permission ->
            val granted = context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
            sendCarLog("  $permission: $granted")
            if (!granted) allGranted = false
        }

        return allGranted
    }

    /**
     * 检查是否有至少一个权限通过
     * 用于判断是否应该尝试启动服务（有反射降级逻辑）
     */
    fun hasAnyPermission(): Boolean {
        val requiredPermissions = getRequiredPermissions()
        
        return requiredPermissions.any { permission ->
            context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
        }
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

        // 初始化门锁设备
        try {
            sendCarLog("初始化门锁设备 BYDAutoDoorLockDevice...")
            doorLockDevice = BYDAutoDoorLockDevice.getInstance(context)
            sendCarLog("BYDAutoDoorLockDevice.getInstance() 完成")
            if (doorLockDevice != null) {
                try {
                    doorLockDevice?.registerListener(doorLockListener)
                    sendCarLog("门锁监听器注册成功")
                } catch (e: Exception) {
                    sendCarLog("门锁监听器注册失败: ${e.message}")
                }
            }
        } catch (e: Exception) {
            sendCarLog("门锁设备初始化异常: ${e.message}")
        }

        // 初始化车辆设置设备
        try {
            sendCarLog("初始化车辆设置设备 BYDAutoSettingDevice...")
            settingDevice = BYDAutoSettingDevice.getInstance(context)
            sendCarLog("BYDAutoSettingDevice.getInstance() 完成")
            if (settingDevice != null) {
                try {
                    settingDevice?.registerListener(settingListener)
                    sendCarLog("车辆设置监听器注册成功")
                } catch (e: Exception) {
                    sendCarLog("车辆设置监听器注册失败: ${e.message}")
                }
            }
        } catch (e: Exception) {
            sendCarLog("车辆设置设备初始化异常: ${e.message}")
        }

        // 初始化发动机设备
        try {
            sendCarLog("初始化发动机设备 BYDAutoEngineDevice...")
            engineDevice = BYDAutoEngineDevice.getInstance(context)
            sendCarLog("BYDAutoEngineDevice.getInstance() 完成")
            if (engineDevice != null) {
                try {
                    engineDevice?.registerListener(engineListener)
                    sendCarLog("发动机监听器注册成功")
                } catch (e: Exception) {
                    sendCarLog("发动机监听器注册失败: ${e.message}")
                }
            }
        } catch (e: Exception) {
            sendCarLog("发动机设备初始化异常: ${e.message}")
        }

        // 初始化全景摄像头设备
        try {
            sendCarLog("初始化全景摄像头设备 BYDAutoPanoramaDevice...")
            panoramaDevice = BYDAutoPanoramaDevice.getInstance(context)
            sendCarLog("BYDAutoPanoramaDevice.getInstance() 完成")
            if (panoramaDevice != null) {
                try {
                    panoramaDevice?.registerListener(panoramaListener)
                    sendCarLog("全景摄像头监听器注册成功")
                } catch (e: Exception) {
                    sendCarLog("全景摄像头监听器注册失败: ${e.message}")
                }
            }
        } catch (e: Exception) {
            sendCarLog("全景摄像头设备初始化异常: ${e.message}")
        }

        // 初始化传感器设备
        try {
            sendCarLog("初始化传感器设备 BYDAutoSensorDevice...")
            sensorDevice = BYDAutoSensorDevice.getInstance(context)
            sendCarLog("BYDAutoSensorDevice.getInstance() 完成")
            if (sensorDevice != null) {
                try {
                    sensorDevice?.registerListener(sensorListener)
                    sendCarLog("传感器监听器注册成功")
                } catch (e: Exception) {
                    sendCarLog("传感器监听器注册失败: ${e.message}")
                }
            }
        } catch (e: Exception) {
            sendCarLog("传感器设备初始化异常: ${e.message}")
        }

        // 初始化时间设备
        try {
            sendCarLog("初始化时间设备 BYDAutoTimeDevice...")
            timeDevice = BYDAutoTimeDevice.getInstance(context)
            sendCarLog("BYDAutoTimeDevice.getInstance() 完成")
            if (timeDevice != null) {
                try {
                    timeDevice?.registerListener(timeListener)
                    sendCarLog("时间监听器注册成功")
                } catch (e: Exception) {
                    sendCarLog("时间监听器注册失败: ${e.message}")
                }
            }
        } catch (e: Exception) {
            sendCarLog("时间设备初始化异常: ${e.message}")
        }

        // 初始化能量模式设备
        try {
            sendCarLog("初始化能量模式设备 BYDAutoEnergyDevice...")
            energyDevice = BYDAutoEnergyDevice.getInstance(context)
            sendCarLog("BYDAutoEnergyDevice.getInstance() 完成")
            if (energyDevice != null) {
                try {
                    energyDevice?.registerListener(energyListener)
                    sendCarLog("能量模式监听器注册成功")
                } catch (e: Exception) {
                    sendCarLog("能量模式监听器注册失败: ${e.message}")
                }
            }
        } catch (e: Exception) {
            sendCarLog("能量模式设备初始化异常: ${e.message}")
        }

        // 初始化雷达设备
        try {
            sendCarLog("初始化雷达设备 BYDAutoRadarDevice...")
            radarDevice = BYDAutoRadarDevice.getInstance(context)
            sendCarLog("BYDAutoRadarDevice.getInstance() 完成")
            if (radarDevice != null) {
                try {
                    radarDevice?.registerListener(radarListener)
                    sendCarLog("雷达监听器注册成功")
                } catch (e: Exception) {
                    sendCarLog("雷达监听器注册失败: ${e.message}")
                }
            }
        } catch (e: Exception) {
            sendCarLog("雷达设备初始化异常: ${e.message}")
        }

        // 初始化 PM2.5 设备
        try {
            sendCarLog("初始化 PM2.5 设备 BYDAutoPM2p5Device...")
            pm2p5Device = BYDAutoPM2p5Device.getInstance(context)
            sendCarLog("BYDAutoPM2p5Device.getInstance() 完成")
            if (pm2p5Device != null) {
                try {
                    pm2p5Device?.registerListener(pm2p5Listener)
                    sendCarLog("PM2.5 监听器注册成功")
                } catch (e: Exception) {
                    sendCarLog("PM2.5 监听器注册失败: ${e.message}")
                }
            }
        } catch (e: Exception) {
            sendCarLog("PM2.5 设备初始化异常: ${e.message}")
        }

        // 初始化充电设备
        try {
            sendCarLog("初始化充电设备 BYDAutoChargingDevice...")
            chargeDevice = BYDAutoChargingDevice.getInstance(context)
            sendCarLog("BYDAutoChargingDevice.getInstance() 完成")
            if (chargeDevice != null) {
                try {
                    chargeDevice?.registerListener(chargeListener)
                    sendCarLog("充电监听器注册成功")
                } catch (e: Exception) {
                    sendCarLog("充电监听器注册失败: ${e.message}")
                }
            }
        } catch (e: Exception) {
            sendCarLog("充电设备初始化异常: ${e.message}")
        }

        // 初始化媒体设备
        try {
            sendCarLog("初始化媒体设备 BYDAutoMultimediaDevice...")
            mediaDevice = BYDAutoMultimediaDevice.getInstance(context)
            sendCarLog("BYDAutoMultimediaDevice.getInstance() 完成")
            if (mediaDevice != null) {
                try {
                    mediaDevice?.registerListener(mediaListener)
                    sendCarLog("媒体监听器注册成功")
                } catch (e: Exception) {
                    sendCarLog("媒体监听器注册失败: ${e.message}")
                }
            }
        } catch (e: Exception) {
            sendCarLog("媒体设备初始化异常: ${e.message}")
        }

        // 初始化车身状态设备
        try {
            sendCarLog("初始化车身状态设备 BYDAutoBodyworkDevice...")
            bodyStatusDevice = BYDAutoBodyworkDevice.getInstance(context)
            sendCarLog("BYDAutoBodyworkDevice.getInstance() 完成")
            if (bodyStatusDevice != null) {
                try {
                    bodyStatusDevice?.registerListener(bodyStatusListener)
                    sendCarLog("车身状态监听器注册成功")
                } catch (e: Exception) {
                    sendCarLog("车身状态监听器注册失败: ${e.message}")
                }
            }
        } catch (e: Exception) {
            sendCarLog("车身状态设备初始化异常: ${e.message}")
        }

        // 初始化车灯设备
        try {
            sendCarLog("初始化车灯设备 BYDAutoLightDevice...")
            lightDevice = BYDAutoLightDevice.getInstance(context)
            sendCarLog("BYDAutoLightDevice.getInstance() 完成")
            if (lightDevice != null) {
                try {
                    lightDevice?.registerListener(lightListener)
                    sendCarLog("车灯监听器注册成功")
                } catch (e: Exception) {
                    sendCarLog("车灯监听器注册失败: ${e.message}")
                }
            }
        } catch (e: Exception) {
            sendCarLog("车灯设备初始化异常: ${e.message}")
        }

        // 初始化空调设备
        try {
            sendCarLog("初始化空调设备 BYDAutoAcDevice...")
            acDevice = BYDAutoAcDevice.getInstance(context)
            sendCarLog("BYDAutoAcDevice.getInstance() 完成")
            if (acDevice != null) {
                try {
                    acDevice?.registerListener(acListener)
                    sendCarLog("空调监听器注册成功")
                } catch (e: Exception) {
                    sendCarLog("空调监听器注册失败: ${e.message}")
                }
            }
        } catch (e: Exception) {
            sendCarLog("空调设备初始化异常: ${e.message}")
        }

        // 参考车况助手项目：手动读取初始数据
        sendCarLog("开始手动读取初始数据...")
        manualReadInitialData()

        sendCarLog("BYDAutoVehicleService 启动完成")
        // 调用 requestCarData() 获取所有真实数据并更新缓存，然后发送完整数据
        requestCarData()
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
                val elecPercent = statisticDevice?.getElecPercentageValue() ?: 0.0
                val fuelPercent = statisticDevice?.getFuelPercentageValue() ?: 0
                val totalMileage = statisticDevice?.getTotalMileageValue() ?: 0
                val evMileage = statisticDevice?.getEVMileageValue() ?: 0

                sendCarLog("手动读取统计 - 电量: $elecPercent%, 油量: $fuelPercent%, 总里程: $totalMileage, 纯电里程: $evMileage")
            }
        } catch (e: Exception) {
            sendCarLog("手动读取统计失败: ${e.message}")
        }

        // 读取仪表设备数据
        try {
            if (instrumentDevice != null) {
                val externalChargingPower = instrumentDevice?.getExternalChargingPower() ?: 0.0
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
            sendCarLog("changed-speed-currentSpeed:$value")
            if (value != lastSpeed) {
                lastSpeed = value
                sendCarData()
                if (speedListenerEnabled) sendSpeedData()
            }
        }

        override fun onAccelerateDeepnessChanged(value: Int) {
            sendCarLog("changed-speed-accelerateDeepness:$value")
            if (value != lastAccelerateDepth) {
                lastAccelerateDepth = value
                sendCarData()
                if (speedListenerEnabled) sendSpeedData()
            }
        }

        override fun onBrakeDeepnessChanged(value: Int) {
            sendCarLog("changed-speed-brakeDeepness:$value")
            if (value != lastBrakeDepth) {
                lastBrakeDepth = value
                sendCarData()
                if (speedListenerEnabled) sendSpeedData()
            }
        }
    }

    private val statisticListener = object : AbsBYDAutoStatisticListener() {
        override fun onDrivingTimeChanged(value: Double) {
            sendCarLog("changed-statistic-drivingTime:$value")
            lastDrivingTime = value
            sendCarData()
            if (statisticListenerEnabled) sendStatisticData()
        }

        override fun onElecDrivingRangeChanged(value: Int) {
            sendCarLog("changed-statistic-elecDrivingRange:$value")
            lastElecDrivingRange = value
            sendCarData()
            if (statisticListenerEnabled) sendStatisticData()
        }

        override fun onElecPercentageChanged(value: Double) {
            sendCarLog("changed-statistic-elecPercentage:$value")
            lastElecPercentage = value
            sendCarData()
            if (statisticListenerEnabled) sendStatisticData()
        }

        override fun onFuelDrivingRangeChanged(value: Int) {
            sendCarLog("changed-statistic-fuelDrivingRange:$value")
            lastFuelDrivingRange = value
            sendCarData()
            if (statisticListenerEnabled) sendStatisticData()
        }

        override fun onFuelPercentageChanged(value: Int) {
            sendCarLog("changed-statistic-fuelPercentage:$value")
            lastFuelPercentage = value
            sendCarData()
            if (statisticListenerEnabled) sendStatisticData()
        }

        override fun onLastElecConPHMChanged(value: Double) {
            sendCarLog("changed-statistic-lastElecConPHM:$value")
            lastLastElecConPHM = value
            sendCarData()
            if (statisticListenerEnabled) sendStatisticData()
        }

        override fun onLastFuelConPHMChanged(value: Double) {
            sendCarLog("changed-statistic-lastFuelConPHM:$value")
            lastLastFuelConPHM = value
            sendCarData()
            if (statisticListenerEnabled) sendStatisticData()
        }

        override fun onTotalElecConPHMChanged(value: Double) {
            sendCarLog("changed-statistic-totalElecConPHM:$value")
            lastTotalElecConPHM = value
            sendCarData()
            if (statisticListenerEnabled) sendStatisticData()
        }

        override fun onTotalFuelConChanged(value: Double) {
            sendCarLog("changed-statistic-totalFuelCon:$value")
            lastTotalFuelCon = value
            sendCarData()
            if (statisticListenerEnabled) sendStatisticData()
        }

        override fun onTotalElecConChanged(value: Double) {
            sendCarLog("changed-statistic-totalElecCon:$value")
            lastTotalElecCon = value
            sendCarData()
            if (statisticListenerEnabled) sendStatisticData()
        }

        override fun onTotalFuelConPHMChanged(value: Double) {
            sendCarLog("changed-statistic-totalFuelConPHM:$value")
            lastTotalFuelConPHM = value
            sendCarData()
            if (statisticListenerEnabled) sendStatisticData()
        }

        override fun onTotalMileageValueChanged(value: Int) {
            sendCarLog("changed-statistic-totalMileage:$value")
            lastTotalMileage = value
            sendCarData()
            if (statisticListenerEnabled) sendStatisticData()
        }

        override fun onKeyBatteryLevelChanged(value: Int) {
            sendCarLog("changed-statistic-keyBatteryLevel:$value")
            lastKeyBatteryLevel = value
            sendCarData()
            if (statisticListenerEnabled) sendStatisticData()
        }

        override fun onEVMileageValueChanged(value: Int) {
            sendCarLog("changed-statistic-evMileage:$value")
            lastEvMileage = value
            sendCarData()
            if (statisticListenerEnabled) sendStatisticData()
        }
    }

    private val tyreListener = object : AbsBYDAutoTyreListener() {
        override fun onTyreAirLeakStateChanged(area: Int, state: Int) {
            val areaName = when (area) {
                BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_FRONT -> "Lf"
                BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_FRONT -> "Rf"
                BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_REAR -> "Lr"
                BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_REAR -> "Rr"
                else -> "Unknown"
            }
            sendCarLog("changed-tyre-tyreAirLeakState-$areaName:$state")
            lastTyreAirLeakState = state
            sendCarData()
            if (tyreDataListenerEnabled) sendTyreData()
        }

        override fun onTyreBatteryStateChanged(state: Int) {
            sendCarLog("changed-tyre-tyreBatteryState:$state")
            lastTyreBatteryState = state
            sendCarData()
            if (tyreDataListenerEnabled) sendTyreData()
        }

        override fun onTyrePressureStateChanged(area: Int, state: Int) {
            val areaName = when (area) {
                BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_FRONT -> "Lf"
                BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_FRONT -> "Rf"
                BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_REAR -> "Lr"
                BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_REAR -> "Rr"
                else -> "Unknown"
            }
            sendCarLog("changed-tyre-tyrePressureState-$areaName:$state")
            when (area) {
                BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_FRONT -> lastTyrePressureStateLf = state
                BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_FRONT -> lastTyrePressureStateRf = state
                BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_REAR -> lastTyrePressureStateLr = state
                BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_REAR -> lastTyrePressureStateRr = state
            }
            sendCarData()
            if (tyreDataListenerEnabled) sendTyreData()
        }

        override fun onTyrePressureValueChanged(area: Int, value: Int) {
            val areaName = when (area) {
                BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_FRONT -> "Lf"
                BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_FRONT -> "Rf"
                BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_REAR -> "Lr"
                BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_REAR -> "Rr"
                else -> "Unknown"
            }
            sendCarLog("changed-tyre-tyrePressure-$areaName:$value")
            when (area) {
                BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_FRONT -> lastTyrePressureLf = value
                BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_FRONT -> lastTyrePressureRf = value
                BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_REAR -> lastTyrePressureLr = value
                BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_REAR -> lastTyrePressureRr = value
            }
            sendCarData()
            if (tyreDataListenerEnabled) sendTyreData()
        }

        override fun onTyreSignalStateChanged(area: Int, state: Int) {
            val areaName = when (area) {
                BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_FRONT -> "Lf"
                BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_FRONT -> "Rf"
                BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_REAR -> "Lr"
                BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_REAR -> "Rr"
                else -> "Unknown"
            }
            sendCarLog("changed-tyre-tyreSignalState-$areaName:$state")
            when (area) {
                BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_FRONT -> lastTyreSignalStateLf = state
                BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_FRONT -> lastTyreSignalStateRf = state
                BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_REAR -> lastTyreSignalStateLr = state
                BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_REAR -> lastTyreSignalStateRr = state
            }
            sendCarData()
            if (tyreDataListenerEnabled) sendTyreData()
        }

        override fun onTyreSystemStateChanged(state: Int) {
            sendCarLog("changed-tyre-tyreSystemState:$state")
            lastTyreSystemState = state
            sendCarData()
            if (tyreDataListenerEnabled) sendTyreData()
        }

        override fun onTyreTemperatureStateChanged(state: Int) {
            sendCarLog("changed-tyre-tyreTemperatureState:$state")
            lastTyreTemperatureState = state
            sendCarData()
            if (tyreDataListenerEnabled) sendTyreData()
        }
    }

    private val instrumentListener = object : AbsBYDAutoInstrumentListener() {
        override fun onMalfunctionInfoChanged(typeName: Int, hasMalfunction: Int) {
            sendCarLog("changed-instrument-malfunctionInfo:$hasMalfunction")
            lastMalfunctionInfo = hasMalfunction
            sendCarData()
            if (instrumentListenerEnabled) sendInstrumentData()
        }

        override fun onAlarmBuzzleStateChange(state: Int) {
            // 蜂鸣器状态变化频繁抖动，暂时忽略以避免性能问题
            // 状态值在 0(停止) 和 1(鸣响) 之间高频切换会导致大量消息发送
            // 如需启用，请添加防抖逻辑
            // sendCarLog("changed-instrument-alarmBuzzleState:$state")
            // sendCarData()
            // if (instrumentListenerEnabled) sendInstrumentData()
        }

        override fun onMaintenanceInfoChanged(typeName: Int, infoValue: Int) {
            sendCarLog("changed-instrument-maintenanceInfo:$infoValue")
            lastMaintenanceInfo = infoValue
            sendCarData()
            if (instrumentListenerEnabled) sendInstrumentData()
        }

        override fun onExternalChargingPowerChanged(value: Double) {
            sendCarLog("changed-instrument-externalChargingPower:$value")
            lastExternalChargingPower = value
            sendCarData()
            if (instrumentListenerEnabled) sendInstrumentData()
        }
    }

    private val doorLockListener = object : AbsBYDAutoDoorLockListener() {
        override fun onDoorLockStatusChanged(area: Int, state: Int) {
            val areaName = when (area) {
                BYDAutoDoorLockDevice.DOOR_LOCK_AREA_LEFT_FRONT -> "Lf"
                BYDAutoDoorLockDevice.DOOR_LOCK_AREA_LEFT_REAR -> "Lr"
                BYDAutoDoorLockDevice.DOOR_LOCK_AREA_RIGHT_FRONT -> "Rf"
                BYDAutoDoorLockDevice.DOOR_LOCK_AREA_RIGHT_REAR -> "Rr"
                BYDAutoDoorLockDevice.DOOR_LOCK_AREA_BACK -> "Back"
                BYDAutoDoorLockDevice.DOOR_LOCK_AREA_CHILDLOCK_LEFT -> "ChildlockL"
                BYDAutoDoorLockDevice.DOOR_LOCK_AREA_CHILDLOCK_RIGHT -> "ChildlockR"
                else -> "Unknown"
            }
            sendCarLog("changed-doorLock-doorLockStatus-$areaName:$state")
            when (area) {
                BYDAutoDoorLockDevice.DOOR_LOCK_AREA_LEFT_FRONT -> lastDoorLockLeftFront = state
                BYDAutoDoorLockDevice.DOOR_LOCK_AREA_LEFT_REAR -> lastDoorLockLeftRear = state
                BYDAutoDoorLockDevice.DOOR_LOCK_AREA_RIGHT_FRONT -> lastDoorLockRightFront = state
                BYDAutoDoorLockDevice.DOOR_LOCK_AREA_RIGHT_REAR -> lastDoorLockRightRear = state
                BYDAutoDoorLockDevice.DOOR_LOCK_AREA_BACK -> lastDoorLockBack = state
                BYDAutoDoorLockDevice.DOOR_LOCK_AREA_CHILDLOCK_LEFT -> lastDoorLockChildlockLeft = state
                BYDAutoDoorLockDevice.DOOR_LOCK_AREA_CHILDLOCK_RIGHT -> lastDoorLockChildlockRight = state
            }
            sendCarData()
            if (doorLockListenerEnabled) sendDoorData()
        }
    }

    private val settingListener = object : AbsBYDAutoSettingListener() {
        override fun onACBTWindSwitchChanged(state: Int) {
            sendCarLog("changed-setting-acBTWind:$state")
            lastAcBTWind = state
            sendCarData()
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onACTunnelCycleSwitchChanged(state: Int) {
            sendCarLog("changed-setting-acTunnelCycle:$state")
            lastAcTunnelCycle = state
            sendCarData()
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onACPauseCycleSwitchChanged(state: Int) {
            sendCarLog("changed-setting-acPauseCycle:$state")
            lastAcPauseCycle = state
            sendCarData()
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onACAutoAirModeChanged(state: Int) {
            sendCarLog("changed-setting-acAutoAir:$state")
            lastAcAutoAir = state
            sendCarData()
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onPM25PowerSwitchChanged(state: Int) {
            sendCarLog("changed-setting-pm25Power:$state")
            lastPm25Power = state
            sendCarData()
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onPM25SwitchCheckChanged(state: Int) {
            sendCarLog("changed-setting-pm25SwitchCheck:$state")
            lastPm25SwitchCheck = state
            sendCarData()
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onPM25TimeCheckChanged(state: Int) {
            sendCarLog("changed-setting-pm25TimeCheck:$state")
            lastPm25TimeCheck = state
            sendCarData()
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onEnergyFeedbackStrengthChanged(level: Int) {
            sendCarLog("changed-setting-energyFeedback:$level")
            lastEnergyFeedback = level
            sendCarData()
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onSOCTargetRangeChanged(state: Int) {
            sendCarLog("changed-setting-socTarget:$state")
            lastSocTarget = state
            sendCarData()
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onChargingPortSwitchChanged(state: Int) {
            sendCarLog("changed-setting-chargingPort:$state")
            lastChargingPort = state
            sendCarData()
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onAutoExternalRearMirrorFollowUpSwitchChanged(state: Int) {
            sendCarLog("changed-setting-autoExternalRearMirrorFollowUp:$state")
            lastAutoExternalRearMirrorFollowUp = state
            sendCarData()
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onLockOffDoorChanged(state: Int) {
            sendCarLog("changed-setting-lockOff:$state")
            lastLockOff = state
            sendCarData()
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onLanguageChanged(value: Int) {
            sendCarLog("changed-setting-language:$value")
            lastLanguage = value
            sendCarData()
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onOverspeedLockStateChanged(state: Int) {
            sendCarLog("changed-setting-overspeedLock:$state")
            lastOverspeedLock = state
            sendCarData()
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onSafeWarnStateChanged(state: Int) {
            sendCarLog("changed-setting-safeWarnState:$state")
            lastSafeWarnState = state
            sendCarData()
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onMaintainRemindStateChanged(state: Int) {
            sendCarLog("changed-setting-maintainRemindState:$state")
            lastMaintainRemindState = state
            sendCarData()
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onSteerAssisModeChanged(state: Int) {
            sendCarLog("changed-setting-steerAssis:$state")
            lastSteerAssis = state
            sendCarData()
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onRearViewMirrorFlipSwitchChanged(state: Int) {
            sendCarLog("changed-setting-rearViewMirrorFlip:$state")
            lastRearViewMirrorFlip = state
            sendCarData()
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onDriverSeatAutoReturnSwitchChanged(state: Int) {
            sendCarLog("changed-setting-driverSeatAutoReturn:$state")
            lastDriverSeatAutoReturn = state
            sendCarData()
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onSteerPositionAutoReturnSwitchChanged(state: Int) {
            sendCarLog("changed-setting-steerPositionAutoReturn:$state")
            lastSteerPositionAutoReturn = state
            sendCarData()
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onRemoteControlUpwindowStateChanged(state: Int) {
            sendCarLog("changed-setting-remoteControlUpwindowState:$state")
            lastRemoteControlUpwindowState = state
            sendCarData()
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onControlWindowSwitchChanged(state: Int) {
            sendCarLog("changed-setting-remoteControlDownwindowState:$state")
            lastRemoteControlDownwindowState = state
            sendCarData()
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onLockCarRiseWindowChanged(state: Int) {
            sendCarLog("changed-setting-lockCarRiseWindow:$state")
            lastLockCarRiseWindow = state
            sendCarData()
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onMicroSwitchLockWindowStateChanged(state: Int) {
            sendCarLog("changed-setting-microSwitchLockWindowState:$state")
            lastMicroSwitchLockWindowState = state
            sendCarData()
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onMicroSwitchUnlockWindowStateChanged(state: Int) {
            sendCarLog("changed-setting-microSwitchUnlockWindowState:$state")
            lastMicroSwitchUnlockWindowState = state
            sendCarData()
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onBackHomeLightDelayValueChanged(value: Int) {
            sendCarLog("changed-setting-backHomeLightDelayValue:$value")
            lastBackHomeLightDelayValue = value
            sendCarData()
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onLeftHomeLightDelayValueChanged(value: Int) {
            sendCarLog("changed-setting-leftHomeLightDelayValue:$value")
            lastLeftHomeLightDelayValue = value
            sendCarData()
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onBackDoorElectricModeChanged(mode: Int) {
            sendCarLog("changed-setting-backDoorElectricMode:$mode")
            lastBackDoorElectricMode = mode
            sendCarData()
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }
    }

    private val engineListener = object : AbsBYDAutoEngineListener() {
        override fun onEngineSpeedChanged(value: Int) {
            sendCarLog("changed-engine-engineSpeed:$value")
            lastEngineSpeed = value
            sendCarData()
            if (engineListenerEnabled) sendEngineData()
        }

        override fun onEngineCoolantLevelChanged(state: Int) {
            sendCarLog("changed-engine-engineCoolantLevel:$state")
            lastEngineCoolantLevel = state
            sendCarData()
            if (engineListenerEnabled) sendEngineData()
        }

        override fun onOilLevelChanged(value: Int) {
            sendCarLog("changed-engine-oilLevel:$value")
            lastOilLevel = value
            sendCarData()
            if (engineListenerEnabled) sendEngineData()
        }
    }

    private val panoramaListener = object : AbsBYDAutoPanoramaListener() {
        override fun onPanOutputStateChanged(mode: Int) {
            sendCarLog("changed-panorama-panoOutputState:$mode")
            lastPanoOutputState = mode
            sendCarData()
            if (panoramaListenerEnabled) sendPanoramaData()
        }

        override fun onPanoWorkStateChanged(mode: Int) {
            sendCarLog("changed-panorama-panoWorkState:$mode")
            lastPanoWorkState = mode
            sendCarData()
            if (panoramaListenerEnabled) sendPanoramaData()
        }

        override fun onBackLineConfigChanged(mode: Int) {
            sendCarLog("changed-panorama-backLineConfig:$mode")
            lastBackLineConfig = mode
            sendCarData()
            if (panoramaListenerEnabled) sendPanoramaData()
        }

        override fun onPanoRotationChanged(value: Int) {
            sendCarLog("changed-panorama-panoRotation:$value")
            lastPanoRotation = value
            sendCarData()
            if (panoramaListenerEnabled) sendPanoramaData()
        }

        override fun onDisplayModeChanged(mode: Int) {
            sendCarLog("changed-panorama-displayMode:$mode")
            lastDisplayMode = mode
            sendCarData()
        }
    }

    private val sensorListener = object : AbsBYDAutoSensorListener() {
        override fun onLightIntensityChanged(value: Int) {
            sendCarLog("changed-sensor-lightIntensity:$value")
            lastLightIntensity = value
            sendCarData()
            if (sensorListenerEnabled) sendSensorData()
        }
    }

    private val timeListener = object : AbsBYDAutoTimeListener() {
        override fun onTimeChanged(time: IntArray) {
            sendCarLog("changed-time-time:${time.joinToString(",")}")
            if (time.size >= 6) {
                lastYear = time[0]
                lastMonth = time[1]
                lastDay = time[2]
                lastHour = time[3]
                lastMinute = time[4]
                lastSecond = time[5]
            }
            sendCarData()
            if (timeListenerEnabled) sendTimeData()
        }

        override fun onTimeFormatChanged(value: Int) {
            sendCarLog("changed-time-timeFormat:$value")
            lastTimeFormat = value
            sendCarData()
            if (timeListenerEnabled) sendTimeData()
        }
    }

    private val energyListener = object : AbsBYDAutoEnergyListener() {
        override fun onEnergyModeChanged(mode: Int) {
            sendCarLog("changed-energyMode-energyMode:$mode")
            lastEnergyMode = mode
            sendCarData()
            if (energyModeListenerEnabled) sendEnergyModeData()
        }

        override fun onOperationModeChanged(mode: Int) {
            sendCarLog("changed-energyMode-operationMode:$mode")
            lastOperationMode = mode
            sendCarData()
            if (energyModeListenerEnabled) sendEnergyModeData()
        }

        override fun onPowerGenerationStateChanged(mode: Int) {
            sendCarLog("changed-energyMode-powerGenerationState:$mode")
            lastPowerGenerationState = mode
            sendCarData()
            if (energyModeListenerEnabled) sendEnergyModeData()
        }

        override fun onPowerGenerationValueChanged(value: Int) {
            sendCarLog("changed-energyMode-powerGenerationValue:$value")
            lastPowerGenerationValue = value
            sendCarData()
            if (energyModeListenerEnabled) sendEnergyModeData()
        }

        override fun onRoadSurfaceChanged(type: Int) {
            sendCarLog("changed-energyMode-roadSurfaceMode:$type")
            lastRoadSurfaceMode = type
            sendCarData()
            if (energyModeListenerEnabled) sendEnergyModeData()
        }
    }

    private val radarListener = object : AbsBYDAutoRadarListener() {
        override fun onRadarProbeStateChanged(area: Int, state: Int) {
            val areaName = when (area) {
                BYDAutoRadarDevice.RADAR_AREA_LEFT_FRONT -> "Lf"
                BYDAutoRadarDevice.RADAR_AREA_RIGHT_FRONT -> "Rf"
                BYDAutoRadarDevice.RADAR_AREA_LEFT_REAR -> "Lr"
                BYDAutoRadarDevice.RADAR_AREA_RIGHT_REAR -> "Rr"
                BYDAutoRadarDevice.RADAR_AREA_LEFT -> "L"
                BYDAutoRadarDevice.RADAR_AREA_RIGHT -> "R"
                BYDAutoRadarDevice.RADAR_AREA_FRONT_LEFT_MID -> "Flm"
                BYDAutoRadarDevice.RADAR_AREA_FRONT_RIGHT_MID -> "Frm"
                else -> "Unknown"
            }
            sendCarLog("changed-radar-radarProbeState-$areaName:$state")
            when (area) {
                BYDAutoRadarDevice.RADAR_AREA_LEFT_FRONT -> lastRadarLeftFront = state
                BYDAutoRadarDevice.RADAR_AREA_RIGHT_FRONT -> lastRadarRightFront = state
                BYDAutoRadarDevice.RADAR_AREA_LEFT_REAR -> lastRadarLeftRear = state
                BYDAutoRadarDevice.RADAR_AREA_RIGHT_REAR -> lastRadarRightRear = state
                BYDAutoRadarDevice.RADAR_AREA_LEFT -> lastRadarLeft = state
                BYDAutoRadarDevice.RADAR_AREA_RIGHT -> lastRadarRight = state
                BYDAutoRadarDevice.RADAR_AREA_FRONT_LEFT_MID -> lastRadarFrontLeftMid = state
                BYDAutoRadarDevice.RADAR_AREA_FRONT_RIGHT_MID -> lastRadarFrontRightMid = state
            }
            sendCarData()
            if (radarListenerEnabled) sendRadarData()
        }

        override fun onReverseRadarSwitchStateChanged(state: Int) {
            sendCarLog("changed-radar-reverseRadarSwitch:$state")
            lastReverseRadarSwitch = state
            sendCarData()
            if (radarListenerEnabled) sendRadarData()
        }
    }

    private val pm2p5Listener = object : AbsBYDAutoPM2p5Listener() {
        override fun onPM2p5CheckStateChanged(state_in: Int, state_out: Int) {
            sendCarLog("changed-pm2p5-pm25CheckStateIn:$state_in")
            sendCarLog("changed-pm2p5-pm25CheckStateOut:$state_out")
            lastPm25CheckStateIn = state_in
            lastPm25CheckStateOut = state_out
            if (pm2p5ListenerEnabled) sendPm2p5Data()
            sendCarData()
        }

        override fun onPM2p5LevelChanged(level_in: Int, level_out: Int) {
            sendCarLog("changed-pm2p5-pm25LevelIn:$level_in")
            sendCarLog("changed-pm2p5-pm25LevelOut:$level_out")
            lastPm25LevelIn = level_in
            lastPm25LevelOut = level_out
            if (pm2p5ListenerEnabled) sendPm2p5Data()
            sendCarData()
        }

        override fun onPM2p5ValueChanged(value_in: Int, value_out: Int) {
            sendCarLog("changed-pm2p5-pm25ValueIn:$value_in")
            sendCarLog("changed-pm2p5-pm25ValueOut:$value_out")
            lastPm25ValueIn = value_in
            lastPm25ValueOut = value_out
            if (pm2p5ListenerEnabled) sendPm2p5Data()
            sendCarData()
        }
    }

    private val chargeListener = object : AbsBYDAutoChargingListener() {
        override fun onChargerFaultStateChanged(value: Int) {
            sendCarLog("changed-charge-chargerFaultState:$value")
            lastChargerFaultState = value
            sendCarData()
            if (chargeListenerEnabled) sendChargeData()
        }

        override fun onChargerWorkStateChanged(value: Int) {
            sendCarLog("changed-charge-chargerWorkState:$value")
            lastChargerWorkState = value
            sendCarData()
            if (chargeListenerEnabled) sendChargeData()
        }

        override fun onChargingCapacityChanged(value: Double) {
            sendCarLog("changed-charge-chargingCapacity:$value")
            lastChargingCapacity = value
            sendCarData()
            if (chargeListenerEnabled) sendChargeData()
        }

        override fun onChargingTypeChanged(value: Int) {
            sendCarLog("changed-charge-chargingType:$value")
            lastChargingType = value
            sendCarData()
            if (chargeListenerEnabled) sendChargeData()
        }

        override fun onChargingRestTimeChanged(hour: Int, minute: Int) {
            sendCarLog("changed-charge-chargingRestTimeHour:$hour")
            sendCarLog("changed-charge-chargingRestTimeMinute:$minute")
            lastChargingRestTimeHour = hour
            lastChargingRestTimeMinute = minute
            sendCarData()
            if (chargeListenerEnabled) sendChargeData()
        }

        override fun onChargingCapStateChanged(type: Int, state: Int) {
            val typeName = if (type == BYDAutoChargingDevice.CHARGING_CAP_AC) "Ac" else "Dc"
            sendCarLog("changed-charge-chargingCapState-$typeName:$state")
            if (type == BYDAutoChargingDevice.CHARGING_CAP_AC) {
                lastChargingCapStateAc = state
            } else if (type == BYDAutoChargingDevice.CHARGING_CAP_DC) {
                lastChargingCapStateDc = state
            }
            sendCarData()
            if (chargeListenerEnabled) sendChargeData()
        }

        override fun onChargingPortLockRebackStateChanged(value: Int) {
            sendCarLog("changed-charge-chargingPortLockRebackState:$value")
            lastChargingPortLockRebackState = value
            sendCarData()
            if (chargeListenerEnabled) sendChargeData()
        }

        override fun onDischargeRequestStateChanged(value: Int) {
            sendCarLog("changed-charge-dischargeRequestState:$value")
            lastDischargeRequestState = value
            sendCarData()
            if (chargeListenerEnabled) sendChargeData()
        }

        override fun onChargerStateChanged(value: Int) {
            sendCarLog("changed-charge-chargerState:$value")
            lastChargerState = value
            sendCarData()
            if (chargeListenerEnabled) sendChargeData()
        }

        override fun onChargingGunStateChanged(value: Int) {
            sendCarLog("changed-charge-chargingGunState:$value")
            lastChargingGunState = value
            sendCarData()
            if (chargeListenerEnabled) sendChargeData()
        }

        override fun onChargingPowerChanged(value: Double) {
            sendCarLog("changed-charge-chargingPower:$value")
            lastChargingPower = value
            sendCarData()
            if (chargeListenerEnabled) sendChargeData()
        }

        override fun onBatteryManagementDeviceStateChanged(value: Int) {
            sendCarLog("changed-charge-batteryManagementDeviceState:$value")
            lastBatteryManagementDeviceState = value
            sendCarData()
            if (chargeListenerEnabled) sendChargeData()
        }

        override fun onChargingScheduleEnableStateChanged(value: Int) {
            sendCarLog("changed-charge-chargingScheduleEnableState:$value")
            lastChargingScheduleEnableState = value
            sendCarData()
            if (chargeListenerEnabled) sendChargeData()
        }

        override fun onChargingScheduleStateChanged(value: Int) {
            sendCarLog("changed-charge-chargingScheduleState:$value")
            lastChargingScheduleState = value
            sendCarData()
            if (chargeListenerEnabled) sendChargeData()
        }

        override fun onChargingGunNotInsertedStateChanged(value: Int) {
            sendCarLog("changed-charge-chargingGunNotInsertedState:$value")
            lastChargingGunNotInsertedState = value
            sendCarData()
            if (chargeListenerEnabled) sendChargeData()
        }

        override fun onChargingScheduleTimeChanged(hour: Int, minute: Int) {
            sendCarLog("changed-charge-chargingScheduleTimeHour:$hour")
            sendCarLog("changed-charge-chargingScheduleTimeMinute:$minute")
            lastChargingScheduleTimeHour = hour
            lastChargingScheduleTimeMinute = minute
            sendCarData()
            if (chargeListenerEnabled) sendChargeData()
        }
    }

    private val mediaListener = object : AbsBYDAutoMultimediaListener() {
        override fun onMediaTypeChanged(type: Int) {
            sendCarLog("changed-media-mediaType:$type")
            lastMediaType = type
            sendCarData()
            if (mediaListenerEnabled) sendMediaData()
        }

        override fun onPlayModeChanged(mode: Int) {
            sendCarLog("changed-media-playMode:$mode")
            lastPlayMode = mode
            sendCarData()
            if (mediaListenerEnabled) sendMediaData()
        }

        override fun onPlayStateChanged(state: Int) {
            sendCarLog("changed-media-playState:$state")
            lastPlayState = state
            sendCarData()
            if (mediaListenerEnabled) sendMediaData()
        }

        override fun onPlayMediaInfoChanged(mediaInfo: MediaInfo?) {
            sendCarLog("changed-media-playMediaInfo:${mediaInfo?.toString() ?: ""}")
            lastPlayMediaInfo = mediaInfo?.toString() ?: ""
            sendCarData()
            if (mediaListenerEnabled) sendMediaData()
        }
    }

    private val bodyStatusListener = object : AbsBYDAutoBodyworkListener() {
        override fun onAutoSystemStateChanged(state: Int) {
            sendCarLog("changed-bodyStatus-autoSystemState:$state")
            lastAutoSystemState = state
            sendCarData()
            if (bodyStatusListenerEnabled) sendBodyStatusData()
        }

        override fun onBatteryVoltageLevelChanged(level: Int) {
            sendCarLog("changed-bodyStatus-batteryVoltageLevel:$level")
            lastBatteryVoltageLevel = level
            sendCarData()
            if (bodyStatusListenerEnabled) sendBodyStatusData()
        }

        override fun onDoorStateChanged(area: Int, state: Int) {
            val areaName = when (area) {
                BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_LEFT_FRONT -> "Lf"
                BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_RIGHT_FRONT -> "Rf"
                BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_LEFT_REAR -> "Lr"
                BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_RIGHT_REAR -> "Rr"
                BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_HOOD -> "Hood"
                BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_LUGGAGE_DOOR -> "Luggage"
                else -> "Unknown"
            }
            sendCarLog("changed-bodyStatus-doorState-$areaName:$state")
            when (area) {
                BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_LEFT_FRONT -> lastDoorStateLf = state
                BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_RIGHT_FRONT -> lastDoorStateRf = state
                BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_LEFT_REAR -> lastDoorStateLr = state
                BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_RIGHT_REAR -> lastDoorStateRr = state
                BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_HOOD -> lastDoorStateHood = state
                BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_LUGGAGE_DOOR -> lastDoorStateLuggage = state
            }
            sendCarData()
            if (bodyStatusListenerEnabled) sendBodyStatusData()
        }

        override fun onWindowStateChanged(area: Int, state: Int) {
            val areaName = when (area) {
                BYDAutoBodyworkDevice.BODYWORK_CMD_WINDOW_LEFT_FRONT -> "Lf"
                BYDAutoBodyworkDevice.BODYWORK_CMD_WINDOW_RIGHT_FRONT -> "Rf"
                BYDAutoBodyworkDevice.BODYWORK_CMD_WINDOW_LEFT_REAR -> "Lr"
                BYDAutoBodyworkDevice.BODYWORK_CMD_WINDOW_RIGHT_REAR -> "Rr"
                else -> "Unknown"
            }
            sendCarLog("changed-bodyStatus-windowState-$areaName:$state")
            when (area) {
                BYDAutoBodyworkDevice.BODYWORK_CMD_WINDOW_LEFT_FRONT -> lastWindowStateLf = state
                BYDAutoBodyworkDevice.BODYWORK_CMD_WINDOW_RIGHT_FRONT -> lastWindowStateRf = state
                BYDAutoBodyworkDevice.BODYWORK_CMD_WINDOW_LEFT_REAR -> lastWindowStateLr = state
                BYDAutoBodyworkDevice.BODYWORK_CMD_WINDOW_RIGHT_REAR -> lastWindowStateRr = state
            }
            sendCarData()
            if (bodyStatusListenerEnabled) sendBodyStatusData()
        }

        override fun onWindowOpenPercentChanged(area: Int, value: Int) {
            val areaName = when (area) {
                BYDAutoBodyworkDevice.BODYWORK_CMD_MOON_ROOF -> "MoonRoof"
                BYDAutoBodyworkDevice.BODYWORK_CMD_SUNSHADE_PANEL -> "Sunshade"
                else -> "Unknown"
            }
            sendCarLog("changed-bodyStatus-windowOpenPercent-$areaName:$value")
            when (area) {
                BYDAutoBodyworkDevice.BODYWORK_CMD_MOON_ROOF -> lastMoonRoofPercent = value
                BYDAutoBodyworkDevice.BODYWORK_CMD_SUNSHADE_PANEL -> lastSunshadePercent = value
            }
            sendCarData()
            if (bodyStatusListenerEnabled) sendBodyStatusData()
        }

        override fun onPowerLevelChanged(level: Int) {
            sendCarLog("changed-bodyStatus-powerLevel:$level")
            lastPowerLevel = level
            sendCarData()
            if (bodyStatusListenerEnabled) sendBodyStatusData()
        }

        override fun onSteeringWheelValueChanged(type: Int, value: Double) {
            val typeName = when (type) {
                BYDAutoBodyworkDevice.BODYWORK_CMD_STEERING_WHEEL_ANGEL -> "Angle"
                BYDAutoBodyworkDevice.BODYWORK_CMD_STEERING_WHEEL_SPEED -> "Speed"
                else -> "Unknown"
            }
            sendCarLog("changed-bodyStatus-steeringWheel-$typeName:$value")
            when (type) {
                BYDAutoBodyworkDevice.BODYWORK_CMD_STEERING_WHEEL_ANGEL -> lastSteeringWheelAngle = value
                BYDAutoBodyworkDevice.BODYWORK_CMD_STEERING_WHEEL_SPEED -> lastSteeringWheelSpeed = value
            }
            sendCarData()
            if (bodyStatusListenerEnabled) sendBodyStatusData()
        }

        override fun onFuelElecLowPowerChanged(state: Int) {
            sendCarLog("changed-bodyStatus-fuelElecLowPower:$state")
            lastFuelElecLowPower = state
            sendCarData()
            if (bodyStatusListenerEnabled) sendBodyStatusData()
        }

        override fun onAlarmStateChanged(state: Int) {
            sendCarLog("changed-bodyStatus-alarmState:$state")
            lastAlarmState = state
            sendCarData()
            if (bodyStatusListenerEnabled) sendBodyStatusData()
        }
    }

    private val lightListener = object : AbsBYDAutoLightListener() {
        override fun onLightAutoSwitchOff() {
            sendCarLog("changed-light-lightAutoStatus:0")
            lastLightAutoStatus = BYDAutoLightDevice.LIGHT_OFF
            sendCarData()
            if (lightListenerEnabled) sendLightData()
        }

        override fun onLightAutoSwitchOn() {
            sendCarLog("changed-light-lightAutoStatus:1")
            lastLightAutoStatus = BYDAutoLightDevice.LIGHT_ON
            sendCarData()
            if (lightListenerEnabled) sendLightData()
        }

        override fun onLightOff(type: Int) {
            val typeName = when (type) {
                BYDAutoLightDevice.LIGHT_SIDE -> "Side"
                BYDAutoLightDevice.LIGHT_LOW_BEAM -> "LowBeam"
                BYDAutoLightDevice.LIGHT_HIGH_BEAM -> "HighBeam"
                BYDAutoLightDevice.LIGHT_LEFT_TURN_SIGNAL -> "LeftTurnSignal"
                BYDAutoLightDevice.LIGHT_RIGHT_TURN_SIGNAL -> "RightTurnSignal"
                BYDAutoLightDevice.LIGHT_FRONT_FOG -> "FrontFog"
                BYDAutoLightDevice.LIGHT_REAR_FOG -> "RearFog"
                BYDAutoLightDevice.LIGHT_FOOT -> "Foot"
                else -> "Unknown"
            }
            sendCarLog("changed-light-light-$typeName:0")
            when (type) {
                BYDAutoLightDevice.LIGHT_SIDE -> lastLightSide = BYDAutoLightDevice.LIGHT_OFF
                BYDAutoLightDevice.LIGHT_LOW_BEAM -> lastLightLowBeam = BYDAutoLightDevice.LIGHT_OFF
                BYDAutoLightDevice.LIGHT_HIGH_BEAM -> lastLightHighBeam = BYDAutoLightDevice.LIGHT_OFF
                BYDAutoLightDevice.LIGHT_LEFT_TURN_SIGNAL -> lastLightLeftTurnSignal = BYDAutoLightDevice.LIGHT_OFF
                BYDAutoLightDevice.LIGHT_RIGHT_TURN_SIGNAL -> lastLightRightTurnSignal = BYDAutoLightDevice.LIGHT_OFF
                BYDAutoLightDevice.LIGHT_FRONT_FOG -> lastLightFrontFog = BYDAutoLightDevice.LIGHT_OFF
                BYDAutoLightDevice.LIGHT_REAR_FOG -> lastLightRearFog = BYDAutoLightDevice.LIGHT_OFF
                BYDAutoLightDevice.LIGHT_FOOT -> lastLightFoot = BYDAutoLightDevice.LIGHT_OFF
            }
            sendCarData()
            if (lightListenerEnabled) sendLightData()
        }

        override fun onLightOn(type: Int) {
            val typeName = when (type) {
                BYDAutoLightDevice.LIGHT_SIDE -> "Side"
                BYDAutoLightDevice.LIGHT_LOW_BEAM -> "LowBeam"
                BYDAutoLightDevice.LIGHT_HIGH_BEAM -> "HighBeam"
                BYDAutoLightDevice.LIGHT_LEFT_TURN_SIGNAL -> "LeftTurnSignal"
                BYDAutoLightDevice.LIGHT_RIGHT_TURN_SIGNAL -> "RightTurnSignal"
                BYDAutoLightDevice.LIGHT_FRONT_FOG -> "FrontFog"
                BYDAutoLightDevice.LIGHT_REAR_FOG -> "RearFog"
                BYDAutoLightDevice.LIGHT_FOOT -> "Foot"
                else -> "Unknown"
            }
            sendCarLog("changed-light-light-$typeName:1")
            when (type) {
                BYDAutoLightDevice.LIGHT_SIDE -> lastLightSide = BYDAutoLightDevice.LIGHT_ON
                BYDAutoLightDevice.LIGHT_LOW_BEAM -> lastLightLowBeam = BYDAutoLightDevice.LIGHT_ON
                BYDAutoLightDevice.LIGHT_HIGH_BEAM -> lastLightHighBeam = BYDAutoLightDevice.LIGHT_ON
                BYDAutoLightDevice.LIGHT_LEFT_TURN_SIGNAL -> lastLightLeftTurnSignal = BYDAutoLightDevice.LIGHT_ON
                BYDAutoLightDevice.LIGHT_RIGHT_TURN_SIGNAL -> lastLightRightTurnSignal = BYDAutoLightDevice.LIGHT_ON
                BYDAutoLightDevice.LIGHT_FRONT_FOG -> lastLightFrontFog = BYDAutoLightDevice.LIGHT_ON
                BYDAutoLightDevice.LIGHT_REAR_FOG -> lastLightRearFog = BYDAutoLightDevice.LIGHT_ON
                BYDAutoLightDevice.LIGHT_FOOT -> lastLightFoot = BYDAutoLightDevice.LIGHT_ON
            }
            sendCarData()
            if (lightListenerEnabled) sendLightData()
        }

        override fun onAFSSwitchStateChange(state: Int) {
            sendCarLog("changed-light-afsSwitch:$state")
            lastAfsSwitch = state
            sendCarData()
            if (lightListenerEnabled) sendLightData()
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
                elecPercent = statisticDevice?.getElecPercentageValue() ?: 0.0
                fuelPercent = statisticDevice?.getFuelPercentageValue() ?: 0
                totalMileage = statisticDevice?.getTotalMileageValue() ?: 0
                evMileage = statisticDevice?.getEVMileageValue() ?: 0
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

    private fun updateInstrumentData() {
        try {
            sendCarLog("updateInstrumentData() - instrumentDevice: ${instrumentDevice != null}")
            if (instrumentDevice == null) return
            
            // 获取单位信息
            lastTemperatureUnit = instrumentDevice?.getUnit(BYDAutoInstrumentDevice.TEMPERATURE_UNIT) ?: lastTemperatureUnit
            lastPressureUnit = instrumentDevice?.getUnit(BYDAutoInstrumentDevice.PRESSURE_UNIT) ?: lastPressureUnit
            lastFuelConsumptionUnit = instrumentDevice?.getUnit(BYDAutoInstrumentDevice.FUEL_CONSUMPTION_AND_DISTANCE_UNIT) ?: lastFuelConsumptionUnit
            lastPowerUnit = instrumentDevice?.getUnit(BYDAutoInstrumentDevice.POWER_UNIT) ?: lastPowerUnit
            
            // 获取故障信息
            lastMalfunctionInfo = instrumentDevice?.getMalfunctionInfo(0) ?: lastMalfunctionInfo
            
            // 获取保养信息
            lastMaintenanceInfo = instrumentDevice?.getMaintenanceInfo(BYDAutoInstrumentDevice.MAINTENANCE_TIME) ?: lastMaintenanceInfo
            
            // 获取外接充电量
            lastExternalChargingPower = instrumentDevice?.getExternalChargingPower() ?: lastExternalChargingPower
            
            sendCarLog("updateInstrumentData() - 单位: 温度=$lastTemperatureUnit, 气压=$lastPressureUnit, 油耗=$lastFuelConsumptionUnit, 功率=$lastPowerUnit")
        } catch (e: Exception) {
            sendCarLog("updateInstrumentData() 异常: ${e.message}")
        }
    }

    private fun updateDoorLockData() {
        try {
            sendCarLog("updateDoorLockData() - doorLockDevice: ${doorLockDevice != null}")
            if (doorLockDevice == null) return
            
            lastDoorLockLeftFront = doorLockDevice?.getDoorLockStatus(BYDAutoDoorLockDevice.DOOR_LOCK_AREA_LEFT_FRONT) ?: lastDoorLockLeftFront
            lastDoorLockRightFront = doorLockDevice?.getDoorLockStatus(BYDAutoDoorLockDevice.DOOR_LOCK_AREA_RIGHT_FRONT) ?: lastDoorLockRightFront
            lastDoorLockLeftRear = doorLockDevice?.getDoorLockStatus(BYDAutoDoorLockDevice.DOOR_LOCK_AREA_LEFT_REAR) ?: lastDoorLockLeftRear
            lastDoorLockRightRear = doorLockDevice?.getDoorLockStatus(BYDAutoDoorLockDevice.DOOR_LOCK_AREA_RIGHT_REAR) ?: lastDoorLockRightRear
            lastDoorLockBack = doorLockDevice?.getDoorLockStatus(BYDAutoDoorLockDevice.DOOR_LOCK_AREA_BACK) ?: lastDoorLockBack
            
            sendCarLog("updateDoorLockData() - 门锁状态: 左前=$lastDoorLockLeftFront, 右前=$lastDoorLockRightFront, 左后=$lastDoorLockLeftRear, 右后=$lastDoorLockRightRear")
        } catch (e: Exception) {
            sendCarLog("updateDoorLockData() 异常: ${e.message}")
        }
    }

    private fun updateSettingData() {
        try {
            sendCarLog("updateSettingData() - settingDevice: ${settingDevice != null}")
            if (settingDevice == null) return
            
            lastAcBTWind = settingDevice?.getACBTWind() ?: lastAcBTWind
            lastAcTunnelCycle = settingDevice?.getACTunnelCycle() ?: lastAcTunnelCycle
            lastAcPauseCycle = settingDevice?.getACPauseCycle() ?: lastAcPauseCycle
            lastAcAutoAir = settingDevice?.getACAutoAir() ?: lastAcAutoAir
            lastPm25Power = settingDevice?.getPM25Power() ?: lastPm25Power
            lastPm25SwitchCheck = settingDevice?.getPM25SwitchCheck() ?: lastPm25SwitchCheck
            lastEnergyFeedback = settingDevice?.getEnergyFeedback() ?: lastEnergyFeedback
            lastSocTarget = settingDevice?.getSOCTarget() ?: lastSocTarget
            lastChargingPort = settingDevice?.getChargingPort() ?: lastChargingPort
            lastLockOff = settingDevice?.getLockOff() ?: lastLockOff
            lastLanguage = settingDevice?.getLanguage() ?: lastLanguage
            lastOverspeedLock = settingDevice?.getOverspeedLock() ?: lastOverspeedLock
            
            sendCarLog("updateSettingData() - 更新完成")
        } catch (e: Exception) {
            sendCarLog("updateSettingData() 异常: ${e.message}")
        }
    }

    private fun updateEngineData() {
        try {
            sendCarLog("updateEngineData() - engineDevice: ${engineDevice != null}")
            if (engineDevice == null) return
            
            lastEngineDisplacement = engineDevice?.getEngineDisplacement() ?: lastEngineDisplacement
            lastEngineCode = engineDevice?.getEngineCode() ?: lastEngineCode
            lastEnginePower = engineDevice?.getEnginePower() ?: lastEnginePower
            lastEngineSpeed = engineDevice?.getEngineSpeed() ?: lastEngineSpeed
            lastEngineCoolantLevel = engineDevice?.getEngineCoolantLevel() ?: lastEngineCoolantLevel
            lastOilLevel = engineDevice?.getOilLevel() ?: lastOilLevel
            
            sendCarLog("updateEngineData() - 发动机排量=$lastEngineDisplacement, 功率=$lastEnginePower, 转速=$lastEngineSpeed")
        } catch (e: Exception) {
            sendCarLog("updateEngineData() 异常: ${e.message}")
        }
    }

    private fun updatePanoramaData() {
        try {
            sendCarLog("updatePanoramaData() - panoramaDevice: ${panoramaDevice != null}")
            if (panoramaDevice == null) return
            
            lastPanoOutputSignal = panoramaDevice?.getPanoOutputSignal() ?: lastPanoOutputSignal
            lastPanoWorkState = panoramaDevice?.getPanoWorkState() ?: lastPanoWorkState
            lastBackLineConfig = panoramaDevice?.getBackLineConfig() ?: lastBackLineConfig
            lastPanoOutputState = panoramaDevice?.getPanoOutputState() ?: lastPanoOutputState
            lastPanoRotation = panoramaDevice?.getPanoRotation() ?: lastPanoRotation
            lastDisplayMode = panoramaDevice?.getDisplayMode() ?: lastDisplayMode
            lastPanoramaOnlineState = panoramaDevice?.getPanoramaOnlineState() ?: lastPanoramaOnlineState
            
            sendCarLog("updatePanoramaData() - 工作状态=$lastPanoWorkState, 在线状态=$lastPanoramaOnlineState")
        } catch (e: Exception) {
            sendCarLog("updatePanoramaData() 异常: ${e.message}")
        }
    }

    private fun updateAcData() {
        try {
            sendCarLog("updateAcData() - acDevice: ${acDevice != null}")
            if (acDevice == null) return
            
            lastAcCompressorMode = acDevice?.getAcCompressorMode() ?: lastAcCompressorMode
            lastAcStartState = acDevice?.getAcStartState() ?: lastAcStartState
            lastAcControlMode = acDevice?.getAcControlMode() ?: lastAcControlMode
            lastAcCycleMode = acDevice?.getAcCycleMode() ?: lastAcCycleMode
            lastAcWindMode = acDevice?.getAcWindMode() ?: lastAcWindMode
            lastAcWindLevel = acDevice?.getAcWindLevel() ?: lastAcWindLevel
            lastAcTemperatureMain = acDevice?.getTemprature(BYDAutoAcDevice.AC_TEMPERATURE_MAIN) ?: lastAcTemperatureMain
            lastAcTemperatureDeputy = acDevice?.getTemprature(BYDAutoAcDevice.AC_TEMPERATURE_DEPUTY) ?: lastAcTemperatureDeputy
            lastTemperatureUnit = acDevice?.getTemperatureUnit() ?: lastTemperatureUnit
            
            sendCarLog("updateAcData() - 压缩机状态=$lastAcCompressorMode, 主温度=$lastAcTemperatureMain, 风速=$lastAcWindLevel")
        } catch (e: Exception) {
            sendCarLog("updateAcData() 异常: ${e.message}")
        }
    }

    private fun updateSensorData() {
        try {
            sendCarLog("updateSensorData() - sensorDevice: ${sensorDevice != null}")
            if (sensorDevice == null) return
            
            lastLightIntensity = sensorDevice?.getLightIntensity() ?: lastLightIntensity
            
            sendCarLog("updateSensorData() - 光照强度=$lastLightIntensity")
        } catch (e: Exception) {
            sendCarLog("updateSensorData() 异常: ${e.message}")
        }
    }

    private fun updateTimeData() {
        try {
            sendCarLog("updateTimeData() - timeDevice: ${timeDevice != null}")
            if (timeDevice == null) return
            
            val timeArray = timeDevice?.getTime() ?: intArrayOf()
            lastYear = timeArray.getOrNull(0) ?: lastYear
            lastMonth = timeArray.getOrNull(1) ?: lastMonth
            lastDay = timeArray.getOrNull(2) ?: lastDay
            lastHour = timeArray.getOrNull(3) ?: lastHour
            lastMinute = timeArray.getOrNull(4) ?: lastMinute
            lastSecond = timeArray.getOrNull(5) ?: lastSecond
            lastTimeFormat = timeDevice?.getTimeFormat() ?: lastTimeFormat
            
            sendCarLog("updateTimeData() - 时间: ${lastYear}-${lastMonth}-${lastDay} ${lastHour}:${lastMinute}:${lastSecond}")
        } catch (e: Exception) {
            sendCarLog("updateTimeData() 异常: ${e.message}")
        }
    }

    private fun updateEnergyModeData() {
        try {
            sendCarLog("updateEnergyModeData() - energyDevice: ${energyDevice != null}")
            if (energyDevice == null) return
            
            lastEnergyMode = energyDevice?.getEnergyMode() ?: lastEnergyMode
            lastOperationMode = energyDevice?.getOperationMode() ?: lastOperationMode
            lastPowerGenerationState = energyDevice?.getPowerGenerationState() ?: lastPowerGenerationState
            lastPowerGenerationValue = energyDevice?.getPowerGenerationValue() ?: lastPowerGenerationValue
            lastRoadSurfaceMode = energyDevice?.getRoadSurfaceMode() ?: lastRoadSurfaceMode
            
            sendCarLog("updateEnergyModeData() - 能量模式=$lastEnergyMode, 运行模式=$lastOperationMode")
        } catch (e: Exception) {
            sendCarLog("updateEnergyModeData() 异常: ${e.message}")
        }
    }

    private fun updateRadarData() {
        try {
            sendCarLog("updateRadarData() - radarDevice: ${radarDevice != null}")
            if (radarDevice == null) return
            
            lastRadarLeftFront = radarDevice?.getRadarProbeState(BYDAutoRadarDevice.RADAR_AREA_LEFT_FRONT) ?: lastRadarLeftFront
            lastRadarRightFront = radarDevice?.getRadarProbeState(BYDAutoRadarDevice.RADAR_AREA_RIGHT_FRONT) ?: lastRadarRightFront
            lastRadarLeftRear = radarDevice?.getRadarProbeState(BYDAutoRadarDevice.RADAR_AREA_LEFT_REAR) ?: lastRadarLeftRear
            lastRadarRightRear = radarDevice?.getRadarProbeState(BYDAutoRadarDevice.RADAR_AREA_RIGHT_REAR) ?: lastRadarRightRear
            lastRadarLeft = radarDevice?.getRadarProbeState(BYDAutoRadarDevice.RADAR_AREA_LEFT) ?: lastRadarLeft
            lastRadarRight = radarDevice?.getRadarProbeState(BYDAutoRadarDevice.RADAR_AREA_RIGHT) ?: lastRadarRight
            lastReverseRadarSwitch = radarDevice?.getReverseRadarSwitchState() ?: lastReverseRadarSwitch
            
            sendCarLog("updateRadarData() - 雷达值: 左前=$lastRadarLeftFront, 右前=$lastRadarRightFront")
        } catch (e: Exception) {
            sendCarLog("updateRadarData() 异常: ${e.message}")
        }
    }

    private fun updateAirQualityData() {
        try {
            sendCarLog("updateAirQualityData() - pm2p5Device: ${pm2p5Device != null}")
            if (pm2p5Device == null) return
            
            lastPm25OnlineState = pm2p5Device?.getPM2p5OnlineState() ?: lastPm25OnlineState
            
            val pm2p5CheckStates = pm2p5Device?.getPM2p5CheckState() ?: intArrayOf()
            lastPm25CheckStateIn = pm2p5CheckStates.getOrNull(0) ?: lastPm25CheckStateIn
            lastPm25CheckStateOut = pm2p5CheckStates.getOrNull(1) ?: lastPm25CheckStateOut
            
            val pm2p5Levels = pm2p5Device?.getPM2p5Level() ?: intArrayOf()
            lastPm25LevelIn = pm2p5Levels.getOrNull(0) ?: lastPm25LevelIn
            lastPm25LevelOut = pm2p5Levels.getOrNull(1) ?: lastPm25LevelOut
            
            val pm2p5Values = pm2p5Device?.getPM2p5Value() ?: intArrayOf()
            lastPm25ValueIn = pm2p5Values.getOrNull(0) ?: lastPm25ValueIn
            lastPm25ValueOut = pm2p5Values.getOrNull(1) ?: lastPm25ValueOut
            
            sendCarLog("updateAirQualityData() - PM2.5: 车内=$lastPm25ValueIn, 车外=$lastPm25ValueOut")
        } catch (e: Exception) {
            sendCarLog("updateAirQualityData() 异常: ${e.message}")
        }
    }

    private fun updateChargeData() {
        try {
            sendCarLog("updateChargeData() - chargeDevice: ${chargeDevice != null}")
            if (chargeDevice == null) return
            
            lastChargerFaultState = chargeDevice?.getChargerFaultState() ?: lastChargerFaultState
            lastChargerWorkState = chargeDevice?.getChargerWorkState() ?: lastChargerWorkState
            lastChargingCapacity = chargeDevice?.getChargingCapacity() ?: lastChargingCapacity
            lastChargingType = chargeDevice?.getChargingType() ?: lastChargingType
            lastChargingPower = chargeDevice?.getChargingPower() ?: lastChargingPower
            lastChargerState = chargeDevice?.getChargerState() ?: lastChargerState
            lastChargingGunState = chargeDevice?.getChargingGunState() ?: lastChargingGunState
            
            sendCarLog("updateChargeData() - 充电状态=$lastChargerState, 充电功率=$lastChargingPower")
        } catch (e: Exception) {
            sendCarLog("updateChargeData() 异常: ${e.message}")
        }
    }

    private fun updateMediaData() {
        try {
            sendCarLog("updateMediaData() - mediaDevice: ${mediaDevice != null}")
            if (mediaDevice == null) return
            
            lastMediaType = mediaDevice?.getMediaType() ?: lastMediaType
            lastPlayMode = mediaDevice?.getPlayMode() ?: lastPlayMode
            lastPlayState = mediaDevice?.getPlayState() ?: lastPlayState
            lastPlayMediaInfo = mediaDevice?.getPlayMediaInfo()?.toString() ?: lastPlayMediaInfo
            
            sendCarLog("updateMediaData() - 媒体类型=$lastMediaType, 播放状态=$lastPlayState")
        } catch (e: Exception) {
            sendCarLog("updateMediaData() 异常: ${e.message}")
        }
    }

    private fun updateBodyStatusData() {
        try {
            sendCarLog("updateBodyStatusData() - bodyStatusDevice: ${bodyStatusDevice != null}")
            if (bodyStatusDevice == null) return
            
            lastAutoVIN = bodyStatusDevice?.getAutoVIN() ?: lastAutoVIN
            lastAutoModelName = bodyStatusDevice?.getAutoModelName() ?: lastAutoModelName
            lastAutoSystemState = bodyStatusDevice?.getAutoSystemState() ?: lastAutoSystemState
            lastDoorStateLf = bodyStatusDevice?.getDoorState(BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_LEFT_FRONT) ?: lastDoorStateLf
            lastDoorStateRf = bodyStatusDevice?.getDoorState(BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_RIGHT_FRONT) ?: lastDoorStateRf
            lastDoorStateLr = bodyStatusDevice?.getDoorState(BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_LEFT_REAR) ?: lastDoorStateLr
            lastDoorStateRr = bodyStatusDevice?.getDoorState(BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_RIGHT_REAR) ?: lastDoorStateRr
            lastPowerLevel = bodyStatusDevice?.getPowerLevel() ?: lastPowerLevel
            
            sendCarLog("updateBodyStatusData() - VIN=$lastAutoVIN, 系统状态=$lastAutoSystemState")
        } catch (e: Exception) {
            sendCarLog("updateBodyStatusData() 异常: ${e.message}")
        }
    }

    private fun updateLightData() {
        try {
            sendCarLog("updateLightData() - lightDevice: ${lightDevice != null}")
            if (lightDevice == null) return
            
            lastLightAutoStatus = lightDevice?.getLightAutoStatus() ?: lastLightAutoStatus
            lastLightSide = lightDevice?.getLightStatus(BYDAutoLightDevice.LIGHT_SIDE) ?: lastLightSide
            lastLightLowBeam = lightDevice?.getLightStatus(BYDAutoLightDevice.LIGHT_LOW_BEAM) ?: lastLightLowBeam
            lastLightHighBeam = lightDevice?.getLightStatus(BYDAutoLightDevice.LIGHT_HIGH_BEAM) ?: lastLightHighBeam
            lastLightFrontFog = lightDevice?.getLightStatus(BYDAutoLightDevice.LIGHT_FRONT_FOG) ?: lastLightFrontFog
            lastLightRearFog = lightDevice?.getLightStatus(BYDAutoLightDevice.LIGHT_REAR_FOG) ?: lastLightRearFog
            lastAfsSwitch = lightDevice?.getAFSSwitch() ?: lastAfsSwitch
            
            sendCarLog("updateLightData() - 自动灯=$lastLightAutoStatus, 近光=$lastLightLowBeam, 远光=$lastLightHighBeam")
        } catch (e: Exception) {
            sendCarLog("updateLightData() 异常: ${e.message}")
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

        try {
            doorLockDevice?.unregisterListener(doorLockListener)
            sendCarLog("门锁监听器已注销")
        } catch (e: Exception) {
            sendCarLog("注销门锁监听器失败: ${e.message}")
        }

        try {
            settingDevice?.unregisterListener(settingListener)
            sendCarLog("车辆设置监听器已注销")
        } catch (e: Exception) {
            sendCarLog("注销车辆设置监听器失败: ${e.message}")
        }

        try {
            engineDevice?.unregisterListener(engineListener)
            sendCarLog("发动机监听器已注销")
        } catch (e: Exception) {
            sendCarLog("注销发动机监听器失败: ${e.message}")
        }

        try {
            panoramaDevice?.unregisterListener(panoramaListener)
            sendCarLog("全景摄像头监听器已注销")
        } catch (e: Exception) {
            sendCarLog("注销全景摄像头监听器失败: ${e.message}")
        }

        try {
            sensorDevice?.unregisterListener(sensorListener)
            sendCarLog("传感器监听器已注销")
        } catch (e: Exception) {
            sendCarLog("注销传感器监听器失败: ${e.message}")
        }

        try {
            timeDevice?.unregisterListener(timeListener)
            sendCarLog("时间监听器已注销")
        } catch (e: Exception) {
            sendCarLog("注销时间监听器失败: ${e.message}")
        }

        try {
            energyDevice?.unregisterListener(energyListener)
            sendCarLog("能量模式监听器已注销")
        } catch (e: Exception) {
            sendCarLog("注销能量模式监听器失败: ${e.message}")
        }

        try {
            radarDevice?.unregisterListener(radarListener)
            sendCarLog("雷达监听器已注销")
        } catch (e: Exception) {
            sendCarLog("注销雷达监听器失败: ${e.message}")
        }

        try {
            pm2p5Device?.unregisterListener(pm2p5Listener)
            sendCarLog("空气质量监听器已注销")
        } catch (e: Exception) {
            sendCarLog("注销空气质量监听器失败: ${e.message}")
        }

        try {
            chargeDevice?.unregisterListener(chargeListener)
            sendCarLog("充电监听器已注销")
        } catch (e: Exception) {
            sendCarLog("注销充电监听器失败: ${e.message}")
        }

        try {
            mediaDevice?.unregisterListener(mediaListener)
            sendCarLog("媒体监听器已注销")
        } catch (e: Exception) {
            sendCarLog("注销媒体监听器失败: ${e.message}")
        }

        try {
            bodyStatusDevice?.unregisterListener(bodyStatusListener)
            sendCarLog("车身状态监听器已注销")
        } catch (e: Exception) {
            sendCarLog("注销车身状态监听器失败: ${e.message}")
        }

        try {
            lightDevice?.unregisterListener(lightListener)
            sendCarLog("车灯监听器已注销")
        } catch (e: Exception) {
            sendCarLog("注销车灯监听器失败: ${e.message}")
        }

        try {
            acDevice?.unregisterListener(acListener)
            sendCarLog("空调监听器已注销")
        } catch (e: Exception) {
            sendCarLog("注销空调监听器失败: ${e.message}")
        }

        sendCarLog("BYDAutoVehicleService 停止完成")
    }

    private fun buildCarData(): Map<String, Any?> {
        return mapOf<String, Any?>(
            "speed" to mapOf<String, Any?>(
                "currentSpeed" to lastSpeed,
                "accelerateDeepness" to lastAccelerateDepth,
                "brakeDeepness" to lastBrakeDepth
            ),
            "statistic" to mapOf<String, Any?>(
                "drivingTime" to lastDrivingTime,
                "elecDrivingRange" to lastElecDrivingRange,
                "elecPercentage" to lastElecPercentage,
                "fuelDrivingRange" to lastFuelDrivingRange,
                "fuelPercentage" to lastFuelPercentage,
                "lastElecConPHM" to lastLastElecConPHM,
                "lastFuelConPHM" to lastLastFuelConPHM,
                "totalElecConPHM" to lastTotalElecConPHM,
                "totalFuelConPHM" to lastTotalFuelConPHM,
                "totalFuelCon" to lastTotalFuelCon,
                "totalElecCon" to lastTotalElecCon,
                "totalMileage" to lastTotalMileage,
                "keyBatteryLevel" to lastKeyBatteryLevel,
                "evMileage" to lastEvMileage
            ),
            "instrument" to mapOf<String, Any?>(
                "malfunctionInfo" to lastMalfunctionInfo,
                "alarmBuzzleState" to lastAlarmBuzzleState,
                "unit" to mapOf<String, Any?>(
                    "temperature" to lastTemperatureUnit,
                    "pressure" to lastPressureUnit,
                    "fuelConsumption" to lastFuelConsumptionUnit,
                    "power" to lastPowerUnit
                ),
                "maintenanceInfo" to lastMaintenanceInfo,
                "externalChargingPower" to lastExternalChargingPower
            ),
            "door" to mapOf<String, Any?>(
                "leftFront" to lastDoorLockLeftFront,
                "leftRear" to lastDoorLockLeftRear,
                "rightFront" to lastDoorLockRightFront,
                "rightRear" to lastDoorLockRightRear,
                "back" to lastDoorLockBack,
                "childlockLeft" to lastDoorLockChildlockLeft,
                "childlockRight" to lastDoorLockChildlockRight
            ),
            "vehicleSetting" to mapOf<String, Any?>(
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
            ),
            "engine" to mapOf<String, Any?>(
                "engineDisplacement" to lastEngineDisplacement,
                "engineCode" to lastEngineCode,
                "enginePower" to lastEnginePower,
                "engineSpeed" to lastEngineSpeed,
                "engineCoolantLevel" to lastEngineCoolantLevel,
                "oilLevel" to lastOilLevel
            ),
            "panorama" to mapOf<String, Any?>(
                "panoOutputSignal" to lastPanoOutputSignal,
                "panoWorkState" to lastPanoWorkState,
                "backLineConfig" to lastBackLineConfig,
                "panoOutputState" to lastPanoOutputState,
                "panoRotation" to lastPanoRotation,
                "displayMode" to lastDisplayMode,
                "panoramaOnlineState" to lastPanoramaOnlineState
            ),
            "ac" to mapOf<String, Any?>(
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
            ),
            "sensor" to mapOf<String, Any?>(
                "lightIntensity" to lastLightIntensity
            ),
            "time" to mapOf<String, Any?>(
                "year" to lastYear,
                "month" to lastMonth,
                "day" to lastDay,
                "hour" to lastHour,
                "minute" to lastMinute,
                "second" to lastSecond,
                "timeFormat" to lastTimeFormat
            ),
            "energyMode" to mapOf<String, Any?>(
                "energyMode" to lastEnergyMode,
                "operationMode" to lastOperationMode,
                "powerGenerationState" to lastPowerGenerationState,
                "powerGenerationValue" to lastPowerGenerationValue,
                "roadSurfaceMode" to lastRoadSurfaceMode
            ),
            "radar" to mapOf<String, Any?>(
                "leftFront" to lastRadarLeftFront,
                "rightFront" to lastRadarRightFront,
                "leftRear" to lastRadarLeftRear,
                "rightRear" to lastRadarRightRear,
                "left" to lastRadarLeft,
                "right" to lastRadarRight,
                "frontLeftMid" to lastRadarFrontLeftMid,
                "frontRightMid" to lastRadarFrontRightMid,
                "reverseRadarSwitch" to lastReverseRadarSwitch
            ),
            "tyre" to mapOf<String, Any?>(
                "tyrePressureLf" to lastTyrePressureLf,
                "tyrePressureRf" to lastTyrePressureRf,
                "tyrePressureLr" to lastTyrePressureLr,
                "tyrePressureRr" to lastTyrePressureRr,
                "tyreAirLeakStateLf" to lastTyreAirLeakState,
                "tyreAirLeakStateRf" to lastTyreAirLeakState,
                "tyreAirLeakStateLr" to lastTyreAirLeakState,
                "tyreAirLeakStateRr" to lastTyreAirLeakState,
                "tyreBatteryState" to lastTyreBatteryState,
                "tyreSystemState" to lastTyreSystemState,
                "tyreTemperatureState" to lastTyreTemperatureState,
                "tyreSignalStateLf" to lastTyreSignalStateLf,
                "tyreSignalStateRf" to lastTyreSignalStateRf,
                "tyreSignalStateLr" to lastTyreSignalStateLr,
                "tyreSignalStateRr" to lastTyreSignalStateRr
            ),
            "airQuality" to mapOf<String, Any?>(
                "pm25OnlineState" to lastPm25OnlineState,
                "pm25CheckStateIn" to lastPm25CheckStateIn,
                "pm25CheckStateOut" to lastPm25CheckStateOut,
                "pm25LevelIn" to lastPm25LevelIn,
                "pm25LevelOut" to lastPm25LevelOut,
                "pm25ValueIn" to lastPm25ValueIn,
                "pm25ValueOut" to lastPm25ValueOut
            ),
            "charge" to mapOf<String, Any?>(
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
            ),
            "media" to mapOf<String, Any?>(
                "mediaType" to lastMediaType,
                "playMode" to lastPlayMode,
                "playState" to lastPlayState,
                "fileName" to lastFileName,
                "artistName" to lastArtistName,
                "albumName" to lastAlbumName
            ),
            "bodyStatus" to mapOf<String, Any?>(
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
            ),
            "light" to mapOf<String, Any?>(
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
            ),
            "timestamp" to System.currentTimeMillis()
        )
    }

    // ==================== 车速类接口 ====================
    private var speedListenerEnabled = false

    fun getSpeedData(refreshCache: Boolean = false): Map<String, Any?> {
        if (refreshCache) {
            updateSpeedData()
        }
        return mapOf<String, Any?>(
            "currentSpeed" to lastSpeed,
            "accelerateDeepness" to lastAccelerateDepth,
            "brakeDeepness" to lastBrakeDepth
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
            val data = getSpeedData(false)
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
            sendCarLog("changed-ac-acStartState:1")
            lastAcStartState = 1
            if (acListenerEnabled) sendAcData()
            sendCarData()
        }

        override fun onAcStoped() {
            sendCarLog("changed-ac-acStartState:0")
            lastAcStartState = 0
            if (acListenerEnabled) sendAcData()
            sendCarData()
        }

        override fun onAcRearStarted() {
            sendCarLog("changed-ac-rearAcStartState:1")
            lastRearAcStartState = 1
            if (acListenerEnabled) sendAcData()
            sendCarData()
        }

        override fun onAcRearStoped() {
            sendCarLog("changed-ac-rearAcStartState:0")
            lastRearAcStartState = 0
            if (acListenerEnabled) sendAcData()
            sendCarData()
        }

        override fun onAcCtrlModeChanged(mode: Int) {
            sendCarLog("changed-ac-acControlMode:$mode")
            lastAcControlMode = mode
            if (acListenerEnabled) sendAcData()
            sendCarData()
        }

        override fun onAcCycleModeChanged(mode: Int) {
            sendCarLog("changed-ac-acCycleMode:$mode")
            lastAcCycleMode = mode
            if (acListenerEnabled) sendAcData()
            sendCarData()
        }

        override fun onAcWindModeChanged(mode: Int) {
            sendCarLog("changed-ac-acWindMode:$mode")
            lastAcWindMode = mode
            if (acListenerEnabled) sendAcData()
            sendCarData()
        }

        override fun onAcDefrostStateChanged(area: Int, state: Int) {
            val areaName = if (area == BYDAutoAcDevice.AC_DEFROST_AREA_FRONT) "Front" else "Rear"
            sendCarLog("changed-ac-acDefrostState-$areaName:$state")
            when (area) {
                BYDAutoAcDevice.AC_DEFROST_AREA_FRONT -> lastAcDefrostStateFront = state
                BYDAutoAcDevice.AC_DEFROST_AREA_REAR -> lastAcDefrostStateRear = state
            }
            if (acListenerEnabled) sendAcData()
            sendCarData()
        }

        override fun onAcWindLevelChanged(level: Int) {
            sendCarLog("changed-ac-acWindLevel:$level")
            lastAcWindLevel = level
            if (acListenerEnabled) sendAcData()
            sendCarData()
        }

        override fun onTemperatureChanged(area: Int, value: Int) {
            val areaName = when (area) {
                BYDAutoAcDevice.AC_TEMPERATURE_MAIN -> "Main"
                BYDAutoAcDevice.AC_TEMPERATURE_DEPUTY -> "Deputy"
                BYDAutoAcDevice.AC_TEMPERATURE_REAR -> "Rear"
                BYDAutoAcDevice.AC_TEMPERATURE_OUT -> "Out"
                else -> "Unknown"
            }
            sendCarLog("changed-ac-acTemperature-$areaName:$value")
            when (area) {
                BYDAutoAcDevice.AC_TEMPERATURE_MAIN -> lastAcTemperatureMain = value
                BYDAutoAcDevice.AC_TEMPERATURE_DEPUTY -> lastAcTemperatureDeputy = value
                BYDAutoAcDevice.AC_TEMPERATURE_REAR -> lastAcTemperatureRear = value
                BYDAutoAcDevice.AC_TEMPERATURE_OUT -> lastAcTemperatureOut = value
            }
            if (acListenerEnabled) sendAcData()
            sendCarData()
        }

        override fun onTemperatureUnitChanged(unit: Int) {
            sendCarLog("changed-ac-temperatureUnit:$unit")
            lastTemperatureUnit = unit
            if (acListenerEnabled) sendAcData()
            sendCarData()
        }

        override fun onAcCompressorModeChanged(mode: Int) {
            sendCarLog("changed-ac-acCompressorMode:$mode")
            lastAcCompressorMode = mode
            if (acListenerEnabled) sendAcData()
            sendCarData()
        }

        override fun onAcVentilationStateChanged(state: Int) {
            sendCarLog("changed-ac-acVentilationState:$state")
            lastAcVentilationState = state
            if (acListenerEnabled) sendAcData()
            sendCarData()
        }

        override fun onAcCompressorManualSignChanged(sign: Int) {
            sendCarLog("changed-ac-acCompressorManualSign:$sign")
            lastAcCompressorManualSign = sign
            if (acListenerEnabled) sendAcData()
            sendCarData()
        }

        override fun onAcWindLevelManualSignChanged(sign: Int) {
            sendCarLog("changed-ac-acWindLevelManualSign:$sign")
            lastAcWindLevelManualSign = sign
            if (acListenerEnabled) sendAcData()
            sendCarData()
        }

        override fun onAcWindModeManualSignChanged(sign: Int) {
            sendCarLog("changed-ac-acWindModeManualSign:$sign")
            lastAcWindModeManualSign = sign
            if (acListenerEnabled) sendAcData()
            sendCarData()
        }

        override fun onAcWindModeShownStateChanged(state: Int) {
            sendCarLog("changed-ac-acWindModeShownState:$state")
            lastAcWindModeShownState = state
            if (acListenerEnabled) sendAcData()
            sendCarData()
        }
    }

    fun getAcData(refreshCache: Boolean = false): Map<String, Any?> {
        if (refreshCache) {
            updateAcData()
        }
        return mapOf<String, Any?>(
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
            sendAcData()
        }
    }

    private fun sendAcData() {
        try {
            val data = getAcData(false)
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
            val success = result == 0
            if (success) {
                sendCarData()
            }
            success
        } catch (e: Exception) {
            sendCarLog("设置空调数据失败: ${e.message}")
            false
        }
    }

    private fun sendCarData() {
        sendCarLog("sendCarData: 方法被调用，enableCarDataListener=$enableCarDataListener, debounceDelayMs=$debounceDelayMs")
        if (!enableCarDataListener) {
            sendCarLog("sendCarData: enableCarDataListener 为 false，直接返回")
            return
        }
        if (debounceDelayMs > 0) {
            val currentTime = System.currentTimeMillis()
            if (currentTime - lastSendTime < debounceDelayMs) {
                sendCarLog("sendCarData: 防抖机制，距离上次发送不足${debounceDelayMs}ms，跳过")
                return
            }
            lastSendTime = currentTime
        }
        try {
            val jsonString = JSONObject(buildCarData()).toString()
            sendCarLog("sendCarData: 准备发送数据，长度=${jsonString.length}")
            methodChannel?.invokeMethod("onCarDataChanged", jsonString)
            sendCarLog("sendCarData: 数据发送成功")
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

    fun enableCarDataListener(enabled: Boolean) {
        enableCarDataListener = enabled
        sendCarLog("全局车机数据监听状态: $enabled")
        if (enabled) {
            sendCarData()
        }
    }

    fun setCarDataListenerDebounceDelay(delayMs: Int) {
        debounceDelayMs = delayMs
        sendCarLog("车机数据防抖延迟设置为: ${delayMs}ms")
    }

    private fun sendCarLog(log: String) {
        sendBydLogToFlutter(log)
        Log.d("BYDAutoVehicleService", log)
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

        // 强制更新所有数据 - 获取真实数据并更新缓存
        sendCarLog("requestCarData() - 开始更新所有数据")
        
        // 更新车速数据
        updateSpeedData()
        
        // 更新统计数据
        updateStatisticData()
        
        // 更新胎压数据
        updateTyreData()
        
        // 更新仪表数据
        updateInstrumentData()
        
        // 更新门锁数据
        updateDoorLockData()
        
        // 更新车辆设置数据
        updateSettingData()
        
        // 更新发动机数据
        updateEngineData()
        
        // 更新全景摄像头数据
        updatePanoramaData()
        
        // 更新空调数据
        updateAcData()
        
        // 更新传感器数据
        updateSensorData()
        
        // 更新时间数据
        updateTimeData()
        
        // 更新能量模式数据
        updateEnergyModeData()
        
        // 更新雷达数据
        updateRadarData()
        
        // 更新空气质量数据
        updateAirQualityData()
        
        // 更新充电数据
        updateChargeData()
        
        // 更新媒体数据
        updateMediaData()
        
        // 更新车身状态数据
        updateBodyStatusData()
        
        // 更新灯光数据
        updateLightData()

        sendCarLog("requestCarData() - 发送数据")
        sendCarData()
        sendCarLog("=== requestCarData() 结束 ===")
    }

    // ==================== 行驶数据类型接口 ====================
    private var statisticListenerEnabled = false

    fun getStatisticData(refreshCache: Boolean = false): Map<String, Any?> {
        if (refreshCache) {
            updateStatisticData()
        }
        return mapOf<String, Any?>(
            "drivingTime" to lastDrivingTime,
            "elecDrivingRange" to lastElecDrivingRange,
            "elecPercentage" to lastElecPercentage,
            "fuelDrivingRange" to lastFuelDrivingRange,
            "fuelPercentage" to lastFuelPercentage,
            "lastElecConPHM" to lastLastElecConPHM,
            "lastFuelConPHM" to lastLastFuelConPHM,
            "totalElecConPHM" to lastTotalElecConPHM,
            "totalFuelConPHM" to lastTotalFuelConPHM,
            "totalFuelCon" to lastTotalFuelCon,
            "totalElecCon" to lastTotalElecCon,
            "totalMileage" to lastTotalMileage,
            "keyBatteryLevel" to lastKeyBatteryLevel,
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
            val data = getStatisticData(false)
            val jsonString = JSONObject(data).toString()
            methodChannel?.invokeMethod("onStatisticDataChanged", jsonString)
        } catch (e: Exception) {
            sendCarLog("发送行驶数据失败: ${e.message}")
        }
    }

    // ==================== 仪表类接口 ====================
    private var instrumentListenerEnabled = false

    fun getInstrumentData(refreshCache: Boolean = false): Map<String, Any?> {
        if (refreshCache) {
            updateInstrumentData()
        }
        return mapOf<String, Any?>(
            "malfunctionInfo" to lastMalfunctionInfo,
            "alarmBuzzleState" to lastAlarmBuzzleState,
            "unit" to mapOf<String, Any?>(
                "temperature" to lastTemperatureUnit,
                "pressure" to lastPressureUnit,
                "fuelConsumption" to lastFuelConsumptionUnit,
                "power" to lastPowerUnit
            ),
            "maintenanceInfo" to lastMaintenanceInfo,
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
        return try {
            val result = when (field) {
                "setUnit" -> {
                    val v = value as Map<*, *>
                    val frontEndUnitName = (v["unitName"] as? Int) ?: 0
                    val unitValue = (v["unitValue"] as? Int) ?: 0
                    
                    val sdkUnitName = when (frontEndUnitName) {
                        1 -> BYDAutoInstrumentDevice.PRESSURE_UNIT           // 压力单位
                        2 -> BYDAutoInstrumentDevice.TEMPERATURE_UNIT         // 温度单位
                        3 -> BYDAutoInstrumentDevice.POWER_UNIT                // 能量单位 -> 功率
                        4 -> BYDAutoInstrumentDevice.FUEL_CONSUMPTION_AND_DISTANCE_UNIT  // 长度单位 -> 油耗距离
                        else -> {
                            sendCarLog("不支持的单位类型: $frontEndUnitName")
                            -1
                        }
                    }
                    
                    if (sdkUnitName == -1) null
                    else instrumentDevice?.setUnit(sdkUnitName, unitValue)
                }
                "setMaintenanceInfo" -> {
                    val v = value as Map<*, *>
                    val frontEndTypeName = (v["typeName"] as? Int) ?: 0
                    val infoValue = (v["infoValue"] as? Int) ?: 0
                    
                    val sdkTypeName = when (frontEndTypeName) {
                        0 -> BYDAutoInstrumentDevice.MAINTENANCE_TIME      // 轮胎换位 -> 保养时间
                        1 -> BYDAutoInstrumentDevice.MAINTENANCE_MILEAGE   // 保养检查 -> 保养里程
                        else -> {
                            sendCarLog("不支持的保养类型: $frontEndTypeName")
                            -1
                        }
                    }
                    
                    if (sdkTypeName == -1) null
                    else instrumentDevice?.setMaintenanceInfo(sdkTypeName, infoValue)
                }
                else -> null
            }
            val success = result == BYDAutoInstrumentDevice.INSTRUMENT_COMMAND_SUCCESS
            sendCarLog("设置仪表数据: $field = $value, 结果: $success")
            if (success) {
                sendCarData()
            }
            success
        } catch (e: Exception) {
            sendCarLog("设置仪表数据失败: ${e.message}")
            false
        }
    }

    fun setInstrumentUnit(unitName: Int, unitValue: Int): Boolean {
        return try {
            val sdkUnitName = when (unitName) {
                1 -> BYDAutoInstrumentDevice.PRESSURE_UNIT           // 压力单位
                2 -> BYDAutoInstrumentDevice.TEMPERATURE_UNIT         // 温度单位
                3 -> BYDAutoInstrumentDevice.POWER_UNIT                // 能量单位 -> 功率
                4 -> BYDAutoInstrumentDevice.FUEL_CONSUMPTION_AND_DISTANCE_UNIT  // 长度单位 -> 油耗距离
                else -> {
                    sendCarLog("不支持的单位类型: $unitName")
                    -1
                }
            }
            
            if (sdkUnitName == -1) {
                false
            } else {
                val result = instrumentDevice?.setUnit(sdkUnitName, unitValue)
                val success = result == BYDAutoInstrumentDevice.INSTRUMENT_COMMAND_SUCCESS
                sendCarLog("设置仪表单位: $unitName -> $sdkUnitName = $unitValue, 结果: $success")
                if (success) {
                    sendCarData()
                }
                success
            }
        } catch (e: Exception) {
            sendCarLog("设置仪表单位失败: ${e.message}")
            false
        }
    }

    fun setMaintenanceInfo(typeName: Int, infoValue: Int): Boolean {
        return try {
            val sdkTypeName = when (typeName) {
                0 -> BYDAutoInstrumentDevice.MAINTENANCE_TIME      // 轮胎换位 -> 保养时间
                1 -> BYDAutoInstrumentDevice.MAINTENANCE_MILEAGE   // 保养检查 -> 保养里程
                else -> {
                    sendCarLog("不支持的保养类型: $typeName")
                    -1
                }
            }
            
            if (sdkTypeName == -1) {
                false
            } else {
                val result = instrumentDevice?.setMaintenanceInfo(sdkTypeName, infoValue)
                val success = result == BYDAutoInstrumentDevice.INSTRUMENT_COMMAND_SUCCESS
                sendCarLog("设置保养信息: $typeName -> $sdkTypeName = $infoValue, 结果: $success")
                if (success) {
                    sendCarData()
                }
                success
            }
        } catch (e: Exception) {
            sendCarLog("设置保养信息失败: ${e.message}")
            false
        }
    }

    private fun sendInstrumentData() {
        try {
            val data = getInstrumentData(false)
            val jsonString = JSONObject(data).toString()
            methodChannel?.invokeMethod("onInstrumentDataChanged", jsonString)
        } catch (e: Exception) {
            sendCarLog("发送仪表数据失败: ${e.message}")
        }
    }

    // ==================== 门锁类接口 ====================
    private var doorLockListenerEnabled = false

    fun getDoorData(refreshCache: Boolean = false): Map<String, Any?> {
        if (refreshCache) {
            updateDoorLockData()
        }
        return mapOf<String, Any?>(
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
            val data = getDoorData(false)
            val jsonString = JSONObject(data).toString()
            methodChannel?.invokeMethod("onDoorDataChanged", jsonString)
        } catch (e: Exception) {
            sendCarLog("发送门锁数据失败: ${e.message}")
        }
    }

    // ==================== 车辆设置类接口 ====================
    private var vehicleSettingListenerEnabled = false

    fun getVehicleSettingData(refreshCache: Boolean = false): Map<String, Any?> {
        if (refreshCache) {
            updateSettingData()
        }
        return mapOf<String, Any?>(
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
        return try {
            val result = when (field) {
                "acBTWind" -> settingDevice?.setACBTWind(value as Int) ?: -1
                "acTunnelCycle" -> settingDevice?.setACTunnelCycle(value as Int) ?: -1
                "acPauseCycle" -> settingDevice?.setACPauseCycle(value as Int) ?: -1
                "acAutoAir" -> settingDevice?.setACAutoAir(value as Int) ?: -1
                "pm25Power" -> settingDevice?.setPM25Power(value as Int) ?: -1
                "pm25SwitchCheck" -> settingDevice?.setPM25SwitchCheck(value as Int) ?: -1
                "pm25TimeCheck" -> settingDevice?.setPM25TimeCheck(value as Int) ?: -1
                "energyFeedback" -> settingDevice?.setEnergyFeedback(value as Int) ?: -1
                "socTarget" -> settingDevice?.setSOCTarget(value as Int) ?: -1
                "chargingPort" -> settingDevice?.setChargingPort(value as Int) ?: -1
                "autoExternalRearMirrorFollowUp" -> settingDevice?.setAutoExternalRearMirrorFollowUpSwitch(value as Int) ?: -1
                "lockOff" -> settingDevice?.setLockOff(value as Int) ?: -1
                "language" -> settingDevice?.setLanguage(value as Int) ?: -1
                "overspeedLock" -> settingDevice?.setOverspeedLock(value as Int) ?: -1
                "steerAssis" -> settingDevice?.setSteerAssis(value as Int) ?: -1
                "rearViewMirrorFlip" -> settingDevice?.setRearViewMirrorFlip(value as Int) ?: -1
                "driverSeatAutoReturn" -> settingDevice?.setDriverSeatAutoReturn(value as Int) ?: -1
                "steerPositionAutoReturn" -> settingDevice?.setSteerPositionAutoReturn(value as Int) ?: -1
                "remoteControlUpwindowState" -> settingDevice?.setRemoteControlUpwindowState(value as Int) ?: -1
                "remoteControlDownwindowState" -> settingDevice?.setRemoteControlDownwindowState(value as Int) ?: -1
                "lockCarRiseWindow" -> settingDevice?.setLockCarRiseWindow(value as Int) ?: -1
                "microSwitchLockWindowState" -> settingDevice?.setMicroSwitchLockWindowState(value as Int) ?: -1
                "microSwitchUnlockWindowState" -> settingDevice?.setMicroSwitchUnlockWindowState(value as Int) ?: -1
                "backHomeLightDelayValue" -> settingDevice?.setBackHomeLightDelayValue(value as Int) ?: -1
                "leftHomeLightDelayValue" -> settingDevice?.setLeftHomeLightDelayValue(value as Int) ?: -1
                "backDoorElectricMode" -> settingDevice?.setBackDoorElectricMode(value as Int) ?: -1
                else -> -1
            }
            sendCarLog("设置车辆设置数据: $field = $value, 结果: $result")
            val success = result == 0
            if (success) {
                sendCarData()
            }
            success
        } catch (e: Exception) {
            sendCarLog("设置车辆设置数据失败: ${e.message}")
            false
        }
    }

    fun vehicleSettingHasFeature(feature: String): Boolean {
        sendCarLog("检查车辆设置功能: $feature")
        return false
    }

    private fun sendVehicleSettingData() {
        try {
            val data = getVehicleSettingData(false)
            val jsonString = JSONObject(data).toString()
            methodChannel?.invokeMethod("onVehicleSettingDataChanged", jsonString)
        } catch (e: Exception) {
            sendCarLog("发送车辆设置数据失败: ${e.message}")
        }
    }

    // ==================== 发动机类接口 ====================
    private var engineListenerEnabled = false

    fun getEngineData(refreshCache: Boolean = false): Map<String, Any?> {
        if (refreshCache) {
            updateEngineData()
        }
        return mapOf<String, Any?>(
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
            val data = getEngineData(false)
            val jsonString = JSONObject(data).toString()
            methodChannel?.invokeMethod("onEngineDataChanged", jsonString)
        } catch (e: Exception) {
            sendCarLog("发送发动机数据失败: ${e.message}")
        }
    }

    // ==================== 全景摄像头类接口 ====================
    private var panoramaListenerEnabled = false

    fun getPanoramaData(refreshCache: Boolean = false): Map<String, Any?> {
        if (refreshCache) {
            updatePanoramaData()
        }
        return mapOf<String, Any?>(
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
            val data = getPanoramaData(false)
            val jsonString = JSONObject(data).toString()
            methodChannel?.invokeMethod("onPanoramaDataChanged", jsonString)
        } catch (e: Exception) {
            sendCarLog("发送全景摄像头数据失败: ${e.message}")
        }
    }

    // ==================== 传感器类接口 ====================
    private var sensorListenerEnabled = false
    private var lastLightIntensity: Int = 0

    fun getSensorData(refreshCache: Boolean = false): Map<String, Any?> {
        if (refreshCache) {
            updateSensorData()
        }
        return mapOf<String, Any?>("lightIntensity" to lastLightIntensity)
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
            val data = getSensorData(false)
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

    fun getTimeData(refreshCache: Boolean = false): Map<String, Any?> {
        if (refreshCache) {
            updateTimeData()
        }
        return mapOf<String, Any?>(
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
            val data = getTimeData(false)
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

    fun getEnergyModeData(refreshCache: Boolean = false): Map<String, Any?> {
        if (refreshCache) {
            updateEnergyModeData()
        }
        return mapOf<String, Any?>(
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
            val data = getEnergyModeData(false)
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
    private var lastRadarFrontLeftMid: Int = 0
    private var lastRadarFrontRightMid: Int = 0
    private var lastReverseRadarSwitch: Int = 0

    fun getRadarData(refreshCache: Boolean = false): Map<String, Any?> {
        if (refreshCache) {
            updateRadarData()
        }
        return mapOf<String, Any?>(
            "leftFront" to lastRadarLeftFront,
            "rightFront" to lastRadarRightFront,
            "leftRear" to lastRadarLeftRear,
            "rightRear" to lastRadarRightRear,
            "left" to lastRadarLeft,
            "right" to lastRadarRight,
            "frontLeftMid" to lastRadarFrontLeftMid,
            "frontRightMid" to lastRadarFrontRightMid,
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
            val data = getRadarData(false)
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

    fun getTyreData(refreshCache: Boolean = false): Map<String, Any?> {
        if (refreshCache) {
            updateTyreData()
        }
        return mapOf<String, Any?>(
            "tyrePressureLf" to lastTyrePressureLf,
            "tyrePressureRf" to lastTyrePressureRf,
            "tyrePressureLr" to lastTyrePressureLr,
            "tyrePressureRr" to lastTyrePressureRr,
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
            val data = getTyreData(false)
            val jsonString = JSONObject(data).toString()
            methodChannel?.invokeMethod("onTyreDataChanged", jsonString)
        } catch (e: Exception) {
            sendCarLog("发送轮胎数据失败: ${e.message}")
        }
    }

    // ==================== 空气质量类接口 ====================
    private var pm2p5ListenerEnabled = false
    private var lastPm25OnlineState: Int = 0
    private var lastPm25CheckStateIn: Int = 0
    private var lastPm25CheckStateOut: Int = 0
    private var lastPm25LevelIn: Int = 0
    private var lastPm25LevelOut: Int = 0
    private var lastPm25ValueIn: Int = 0
    private var lastPm25ValueOut: Int = 0

    private fun sendPm2p5Data() {
        try {
            val data = getAirQualityData(false)
            val jsonString = JSONObject(data).toString()
            methodChannel?.invokeMethod("onAirQualityDataChanged", jsonString)
        } catch (e: Exception) {
            sendCarLog("发送空气质量数据失败: ${e.message}")
        }
    }

    fun getAirQualityData(refreshCache: Boolean = false): Map<String, Any?> {
        if (refreshCache) {
            updateAirQualityData()
        }
        return mapOf<String, Any?>(
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
        pm2p5ListenerEnabled = enabled
        sendCarLog("PM2.5 监听器状态: $enabled")
        if (enabled) sendPm2p5Data()
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

    fun getChargeData(refreshCache: Boolean = false): Map<String, Any?> {
        if (refreshCache) {
            updateChargeData()
        }
        return mapOf<String, Any?>(
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
            val data = getChargeData(false)
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

    fun getMediaData(refreshCache: Boolean = false): Map<String, Any?> {
        if (refreshCache) {
            updateMediaData()
        }
        return mapOf<String, Any?>(
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
        return try {
            val result = when (field) {
                "controlMedia" -> {
                    val action = value as Int
                    // 根据开发文档，控制媒体需要指定模式和动作
                    // action: 0-暂停播放、1-播放、2-上一曲、3-下一曲、4-停止播放、5-继续播放、6-静音、7-取消静音
                    val mode = when (action) {
                        0, 1, 2, 3, 4, 5 -> BYDAutoMultimediaDevice.MODE_MUSIC
                        else -> BYDAutoMultimediaDevice.MODE_MUSIC
                    }
                    val mediaAction = when (action) {
                        0 -> BYDAutoMultimediaDevice.ACTION_PAUSE
                        1 -> BYDAutoMultimediaDevice.ACTION_PLAY
                        2 -> BYDAutoMultimediaDevice.ACTION_PLAY_PRE
                        3 -> BYDAutoMultimediaDevice.ACTION_PLAY_NEXT
                        4 -> BYDAutoMultimediaDevice.ACTION_PAUSE
                        5 -> BYDAutoMultimediaDevice.ACTION_PLAY
                        else -> -1
                    }
                    if (mediaAction == -1) -1
                    else mediaDevice?.controlMedia(mode, mediaAction, null) ?: -1
                }
                else -> -1
            }
            sendCarLog("设置媒体中心数据: $field = $value, 结果: $result")
            val success = result == BYDAutoMultimediaDevice.MULTIMEDIA_COMMAND_SUCCESS
            if (success) {
                sendCarData()
            }
            success
        } catch (e: Exception) {
            sendCarLog("设置媒体中心数据失败: ${e.message}")
            false
        }
    }

    private fun sendMediaData() {
        try {
            val data = getMediaData(false)
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
    private var lastSteeringWheelAngle: Double = 0.0
    private var lastSteeringWheelSpeed: Double = 0.0
    private var lastFuelElecLowPower: Int = 0
    private var lastAlarmState: Int = 0
    private var lastMoonRoofConfig: Int = 0

    fun getBodyStatusData(refreshCache: Boolean = false): Map<String, Any?> {
        if (refreshCache) {
            updateBodyStatusData()
        }
        return mapOf<String, Any?>(
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
            val data = getBodyStatusData(false)
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

    fun getLightData(refreshCache: Boolean = false): Map<String, Any?> {
        if (refreshCache) {
            updateLightData()
        }
        return mapOf<String, Any?>(
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
            val data = getLightData(false)
            val jsonString = JSONObject(data).toString()
            methodChannel?.invokeMethod("onLightDataChanged", jsonString)
        } catch (e: Exception) {
            sendCarLog("发送车灯数据失败: ${e.message}")
        }
    }
}