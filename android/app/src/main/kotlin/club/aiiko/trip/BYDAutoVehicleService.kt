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
            sendCarLog("车速监听器回调 - 速度变化: $value")
            if (value != lastSpeed && value >= 0 && value <= 282) {
                lastSpeed = value
                sendCarData(buildCarData())
                if (speedListenerEnabled) sendSpeedData()
            }
        }

        override fun onAccelerateDeepnessChanged(value: Int) {
            sendCarLog("车速监听器回调 - 油门深度变化: $value")
            if (value != lastAccelerateDepth && value >= 0 && value <= 100) {
                lastAccelerateDepth = value
                sendCarData(buildCarData())
                if (speedListenerEnabled) sendSpeedData()
            }
        }

        override fun onBrakeDeepnessChanged(value: Int) {
            sendCarLog("车速监听器回调 - 刹车深度变化: $value")
            if (value != lastBrakeDepth && value >= 0 && value <= 100) {
                lastBrakeDepth = value
                sendCarData(buildCarData())
                if (speedListenerEnabled) sendSpeedData()
            }
        }
    }

    private val statisticListener = object : AbsBYDAutoStatisticListener() {
        override fun onDrivingTimeChanged(value: Double) {
            sendCarLog("统计监听器回调 - 行驶时间变化: $value")
            if (value >= 0 && value <= 9999.9) {
                sendCarData(buildCarData())
                if (statisticListenerEnabled) sendStatisticData()
            }
        }

        override fun onElecDrivingRangeChanged(value: Int) {
            sendCarLog("统计监听器回调 - 电续驶里程变化: $value")
            if (value >= 0 && value <= 511) {
                sendCarData(buildCarData())
                if (statisticListenerEnabled) sendStatisticData()
            }
        }

        override fun onElecPercentageChanged(value: Double) {
            sendCarLog("统计监听器回调 - 电量变化: $value")
            if (value >= 0 && value <= 100) {
                lastElecPercentage = value
                sendCarData(buildCarData())
                if (statisticListenerEnabled) sendStatisticData()
            }
        }

        override fun onFuelDrivingRangeChanged(value: Int) {
            sendCarLog("统计监听器回调 - 燃油续驶里程变化: $value")
            if (value >= 0 && value <= 4095) {
                sendCarData(buildCarData())
                if (statisticListenerEnabled) sendStatisticData()
            }
        }

        override fun onFuelPercentageChanged(value: Int) {
            sendCarLog("统计监听器回调 - 油量变化: $value")
            if (value >= 0 && value <= 100) {
                lastFuelPercentage = value
                sendCarData(buildCarData())
                if (statisticListenerEnabled) sendStatisticData()
            }
        }

        override fun onLastElecConPHMChanged(value: Double) {
            sendCarLog("统计监听器回调 - 最近百公里电耗变化: $value")
            sendCarData(buildCarData())
            if (statisticListenerEnabled) sendStatisticData()
        }

        override fun onLastFuelConPHMChanged(value: Double) {
            sendCarLog("统计监听器回调 - 最近百公里油耗变化: $value")
            if (value >= 0 && value <= 51.1) {
                sendCarData(buildCarData())
                if (statisticListenerEnabled) sendStatisticData()
            }
        }

        override fun onTotalElecConPHMChanged(value: Double) {
            sendCarLog("统计监听器回调 - 累计平均电耗变化: $value")
            sendCarData(buildCarData())
            if (statisticListenerEnabled) sendStatisticData()
        }

        override fun onTotalFuelConChanged(value: Double) {
            sendCarLog("统计监听器回调 - 燃油消耗总量变化: $value")
            if (value >= 0) {
                sendCarData(buildCarData())
                if (statisticListenerEnabled) sendStatisticData()
            }
        }

        override fun onTotalElecConChanged(value: Double) {
            sendCarLog("统计监听器回调 - 电消耗总量变化: $value")
            sendCarData(buildCarData())
            if (statisticListenerEnabled) sendStatisticData()
        }

        override fun onTotalFuelConPHMChanged(value: Double) {
            sendCarLog("统计监听器回调 - 累计平均油耗变化: $value")
            if (value >= 0 && value <= 51.1) {
                sendCarData(buildCarData())
                if (statisticListenerEnabled) sendStatisticData()
            }
        }

        override fun onTotalMileageValueChanged(value: Int) {
            sendCarLog("统计监听器回调 - 总里程变化: $value")
            if (value >= 0 && value <= 999999) {
                lastTotalMileage = value
                sendCarData(buildCarData())
                if (statisticListenerEnabled) sendStatisticData()
            }
        }

        override fun onKeyBatteryLevelChanged(value: Int) {
            sendCarLog("统计监听器回调 - 钥匙电量变化: $value")
            sendCarData(buildCarData())
            if (statisticListenerEnabled) sendStatisticData()
        }

        override fun onEVMileageValueChanged(value: Int) {
            sendCarLog("统计监听器回调 - EV里程变化: $value")
            if (value >= 0 && value <= 999999) {
                lastEvMileage = value
                sendCarData(buildCarData())
                if (statisticListenerEnabled) sendStatisticData()
            }
        }
    }

    private val tyreListener = object : AbsBYDAutoTyreListener() {
        override fun onTyreAirLeakStateChanged(area: Int, state: Int) {
            sendCarLog("胎压监听器回调 - 漏气状态变化: 区域=$area, 状态=$state")
            sendCarData(buildCarData())
            if (tyreDataListenerEnabled) sendTyreData()
        }

        override fun onTyreBatteryStateChanged(state: Int) {
            sendCarLog("胎压监听器回调 - 电池状态变化: $state")
            sendCarData(buildCarData())
            if (tyreDataListenerEnabled) sendTyreData()
        }

        override fun onTyrePressureStateChanged(area: Int, state: Int) {
            sendCarLog("胎压监听器回调 - 压力状态变化: 区域=$area, 状态=$state")
            sendCarData(buildCarData())
            if (tyreDataListenerEnabled) sendTyreData()
        }

        override fun onTyrePressureValueChanged(area: Int, value: Int) {
            sendCarLog("胎压监听器回调 - 压力值变化: 区域=$area, 值=$value")
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
                if (tyreDataListenerEnabled) sendTyreData()
            }
        }

        override fun onTyreSignalStateChanged(area: Int, state: Int) {
            sendCarLog("胎压监听器回调 - 信号状态变化: 区域=$area, 状态=$state")
            sendCarData(buildCarData())
            if (tyreDataListenerEnabled) sendTyreData()
        }

        override fun onTyreSystemStateChanged(state: Int) {
            sendCarLog("胎压监听器回调 - 系统状态变化: $state")
            sendCarData(buildCarData())
            if (tyreDataListenerEnabled) sendTyreData()
        }

        override fun onTyreTemperatureStateChanged(state: Int) {
            sendCarLog("胎压监听器回调 - 温度状态变化: $state")
            sendCarData(buildCarData())
            if (tyreDataListenerEnabled) sendTyreData()
        }
    }

    private val instrumentListener = object : AbsBYDAutoInstrumentListener() {
        override fun onMalfunctionInfoChanged(typeName: Int, hasMalfunction: Int) {
            sendCarLog("仪表监听器回调 - 故障提示信息变化: 类型=$typeName, 状态=$hasMalfunction")
            sendCarData(buildCarData())
            if (instrumentListenerEnabled) sendInstrumentData()
        }

        override fun onAlarmBuzzleStateChange(state: Int) {
            sendCarLog("仪表监听器回调 - 蜂鸣器状态变化: $state")
            sendCarData(buildCarData())
            if (instrumentListenerEnabled) sendInstrumentData()
        }

        override fun onMaintenanceInfoChanged(typeName: Int, infoValue: Int) {
            sendCarLog("仪表监听器回调 - 保养信息变化: 类型=$typeName, 值=$infoValue")
            sendCarData(buildCarData())
            if (instrumentListenerEnabled) sendInstrumentData()
        }

        override fun onExternalChargingPowerChanged(value: Double) {
            sendCarLog("仪表监听器回调 - 外接充电量变化: $value")
            if (value >= 0.0 && value <= 10000.0) {
                lastExternalChargingPower = value
                sendCarData(buildCarData())
                if (instrumentListenerEnabled) sendInstrumentData()
            }
        }
    }

    private val doorLockListener = object : AbsBYDAutoDoorLockListener() {
        override fun onDoorLockStatusChanged(area: Int, state: Int) {
            sendCarLog("门锁监听器回调 - 区域: $area, 状态: $state")
            when (area) {
                BYDAutoDoorLockDevice.DOOR_LOCK_AREA_LEFT_FRONT -> lastDoorLockLeftFront = state
                BYDAutoDoorLockDevice.DOOR_LOCK_AREA_LEFT_REAR -> lastDoorLockLeftRear = state
                BYDAutoDoorLockDevice.DOOR_LOCK_AREA_RIGHT_FRONT -> lastDoorLockRightFront = state
                BYDAutoDoorLockDevice.DOOR_LOCK_AREA_RIGHT_REAR -> lastDoorLockRightRear = state
                BYDAutoDoorLockDevice.DOOR_LOCK_AREA_BACK -> lastDoorLockBack = state
                BYDAutoDoorLockDevice.DOOR_LOCK_AREA_CHILDLOCK_LEFT -> lastDoorLockChildlockLeft = state
                BYDAutoDoorLockDevice.DOOR_LOCK_AREA_CHILDLOCK_RIGHT -> lastDoorLockChildlockRight = state
            }
            sendCarData(buildCarData())
            if (doorLockListenerEnabled) sendDoorData()
        }
    }

    private val settingListener = object : AbsBYDAutoSettingListener() {
        override fun onACBTWindSwitchChanged(state: Int) {
            sendCarLog("车辆设置监听器回调 - 蓝牙通话自动降风速: $state")
            lastAcBTWind = state
            sendCarData(buildCarData())
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onACTunnelCycleSwitchChanged(state: Int) {
            sendCarLog("车辆设置监听器回调 - 进隧道自动内循环: $state")
            lastAcTunnelCycle = state
            sendCarData(buildCarData())
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onACPauseCycleSwitchChanged(state: Int) {
            sendCarLog("车辆设置监听器回调 - 驻车自动内循环: $state")
            lastAcPauseCycle = state
            sendCarData(buildCarData())
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onACAutoAirModeChanged(state: Int) {
            sendCarLog("车辆设置监听器回调 - 空调自动模式: $state")
            lastAcAutoAir = state
            sendCarData(buildCarData())
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onPM25PowerSwitchChanged(state: Int) {
            sendCarLog("车辆设置监听器回调 - PM2.5上电检测: $state")
            lastPm25Power = state
            sendCarData(buildCarData())
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onPM25SwitchCheckChanged(state: Int) {
            sendCarLog("车辆设置监听器回调 - PM2.5开关门检测: $state")
            lastPm25SwitchCheck = state
            sendCarData(buildCarData())
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onPM25TimeCheckChanged(state: Int) {
            sendCarLog("车辆设置监听器回调 - PM2.5定时检测: $state")
            lastPm25TimeCheck = state
            sendCarData(buildCarData())
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onEnergyFeedbackStrengthChanged(level: Int) {
            sendCarLog("车辆设置监听器回调 - 能量回馈强度: $level")
            lastEnergyFeedback = level
            sendCarData(buildCarData())
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onSOCTargetRangeChanged(state: Int) {
            sendCarLog("车辆设置监听器回调 - SOC目标点: $state")
            lastSocTarget = state
            sendCarData(buildCarData())
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onChargingPortSwitchChanged(state: Int) {
            sendCarLog("车辆设置监听器回调 - 充电枪电锁模式: $state")
            lastChargingPort = state
            sendCarData(buildCarData())
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onAutoExternalRearMirrorFollowUpSwitchChanged(state: Int) {
            sendCarLog("车辆设置监听器回调 - 外后视镜随动: $state")
            lastAutoExternalRearMirrorFollowUp = state
            sendCarData(buildCarData())
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onLockOffDoorChanged(state: Int) {
            sendCarLog("车辆设置监听器回调 - 开锁方式: $state")
            lastLockOff = state
            sendCarData(buildCarData())
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onLanguageChanged(value: Int) {
            sendCarLog("车辆设置监听器回调 - 语言: $value")
            lastLanguage = value
            sendCarData(buildCarData())
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onOverspeedLockStateChanged(state: Int) {
            sendCarLog("车辆设置监听器回调 - 超速闭锁: $state")
            lastOverspeedLock = state
            sendCarData(buildCarData())
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onSafeWarnStateChanged(state: Int) {
            sendCarLog("车辆设置监听器回调 - 安全警告: $state")
            lastSafeWarnState = state
            sendCarData(buildCarData())
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onMaintainRemindStateChanged(state: Int) {
            sendCarLog("车辆设置监听器回调 - 保养提醒: $state")
            lastMaintainRemindState = state
            sendCarData(buildCarData())
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onSteerAssisModeChanged(state: Int) {
            sendCarLog("车辆设置监听器回调 - 转向助力模式: $state")
            lastSteerAssis = state
            sendCarData(buildCarData())
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onRearViewMirrorFlipSwitchChanged(state: Int) {
            sendCarLog("车辆设置监听器回调 - 后视镜翻转: $state")
            lastRearViewMirrorFlip = state
            sendCarData(buildCarData())
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onDriverSeatAutoReturnSwitchChanged(state: Int) {
            sendCarLog("车辆设置监听器回调 - 驾驶座自动回退: $state")
            lastDriverSeatAutoReturn = state
            sendCarData(buildCarData())
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onSteerPositionAutoReturnSwitchChanged(state: Int) {
            sendCarLog("车辆设置监听器回调 - 方向盘自动回退: $state")
            lastSteerPositionAutoReturn = state
            sendCarData(buildCarData())
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onRemoteControlUpwindowStateChanged(state: Int) {
            sendCarLog("车辆设置监听器回调 - 遥控升窗: $state")
            lastRemoteControlUpwindowState = state
            sendCarData(buildCarData())
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onControlWindowSwitchChanged(state: Int) {
            sendCarLog("车辆设置监听器回调 - 遥控降窗: $state")
            lastRemoteControlDownwindowState = state
            sendCarData(buildCarData())
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onLockCarRiseWindowChanged(state: Int) {
            sendCarLog("车辆设置监听器回调 - 锁车升窗: $state")
            lastLockCarRiseWindow = state
            sendCarData(buildCarData())
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onMicroSwitchLockWindowStateChanged(state: Int) {
            sendCarLog("车辆设置监听器回调 - 微动开关锁窗: $state")
            lastMicroSwitchLockWindowState = state
            sendCarData(buildCarData())
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onMicroSwitchUnlockWindowStateChanged(state: Int) {
            sendCarLog("车辆设置监听器回调 - 微动开关解锁窗: $state")
            lastMicroSwitchUnlockWindowState = state
            sendCarData(buildCarData())
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onBackHomeLightDelayValueChanged(value: Int) {
            sendCarLog("车辆设置监听器回调 - 回家灯延时: $value")
            lastBackHomeLightDelayValue = value
            sendCarData(buildCarData())
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onLeftHomeLightDelayValueChanged(value: Int) {
            sendCarLog("车辆设置监听器回调 - 离家灯延时: $value")
            lastLeftHomeLightDelayValue = value
            sendCarData(buildCarData())
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }

        override fun onBackDoorElectricModeChanged(mode: Int) {
            sendCarLog("车辆设置监听器回调 - 尾门电动模式: $mode")
            lastBackDoorElectricMode = mode
            sendCarData(buildCarData())
            if (vehicleSettingListenerEnabled) sendVehicleSettingData()
        }
    }

    private val engineListener = object : AbsBYDAutoEngineListener() {
        override fun onEngineSpeedChanged(value: Int) {
            sendCarLog("发动机监听器回调 - 转速: $value")
            lastEngineSpeed = value
            sendCarData(buildCarData())
            if (engineListenerEnabled) sendEngineData()
        }

        override fun onEngineCoolantLevelChanged(state: Int) {
            sendCarLog("发动机监听器回调 - 冷却液液位: $state")
            lastEngineCoolantLevel = state
            sendCarData(buildCarData())
            if (engineListenerEnabled) sendEngineData()
        }

        override fun onOilLevelChanged(value: Int) {
            sendCarLog("发动机监听器回调 - 机油液位: $value")
            lastOilLevel = value
            sendCarData(buildCarData())
            if (engineListenerEnabled) sendEngineData()
        }
    }

    private val panoramaListener = object : AbsBYDAutoPanoramaListener() {
        override fun onPanOutputStateChanged(mode: Int) {
            sendCarLog("全景摄像头监听器回调 - 输出状态: $mode")
            lastPanoOutputState = mode
            sendCarData(buildCarData())
            if (panoramaListenerEnabled) sendPanoramaData()
        }

        override fun onPanoWorkStateChanged(mode: Int) {
            sendCarLog("全景摄像头监听器回调 - 工作状态: $mode")
            lastPanoWorkState = mode
            sendCarData(buildCarData())
            if (panoramaListenerEnabled) sendPanoramaData()
        }

        override fun onBackLineConfigChanged(mode: Int) {
            sendCarLog("全景摄像头监听器回调 - 倒车线配置: $mode")
            lastBackLineConfig = mode
            sendCarData(buildCarData())
            if (panoramaListenerEnabled) sendPanoramaData()
        }

        override fun onPanoRotationChanged(value: Int) {
            sendCarLog("全景摄像头监听器回调 - 旋转: $value")
            lastPanoRotation = value
            sendCarData(buildCarData())
            if (panoramaListenerEnabled) sendPanoramaData()
        }

        override fun onDisplayModeChanged(mode: Int) {
            sendCarLog("全景摄像头监听器回调 - 显示模式: $mode")
            lastDisplayMode = mode
            sendCarData(buildCarData())
        }
    }

    private val sensorListener = object : AbsBYDAutoSensorListener() {
        override fun onLightIntensityChanged(value: Int) {
            sendCarLog("传感器监听器回调 - 光照强度: $value")
            lastLightIntensity = value
            sendCarData(buildCarData())
            if (sensorListenerEnabled) sendSensorData()
        }
    }

    private val timeListener = object : AbsBYDAutoTimeListener() {
        override fun onTimeChanged(time: IntArray) {
            sendCarLog("时间监听器回调 - 时间变化: ${time.joinToString(",")}")
            if (time.size >= 6) {
                lastYear = time[0]
                lastMonth = time[1]
                lastDay = time[2]
                lastHour = time[3]
                lastMinute = time[4]
                lastSecond = time[5]
            }
            sendCarData(buildCarData())
            if (timeListenerEnabled) sendTimeData()
        }

        override fun onTimeFormatChanged(value: Int) {
            sendCarLog("时间监听器回调 - 格式: $value")
            lastTimeFormat = value
            sendCarData(buildCarData())
            if (timeListenerEnabled) sendTimeData()
        }
    }

    private val energyListener = object : AbsBYDAutoEnergyListener() {
        override fun onEnergyModeChanged(mode: Int) {
            sendCarLog("能量模式监听器回调 - 能量模式: $mode")
            lastEnergyMode = mode
            sendCarData(buildCarData())
            if (energyModeListenerEnabled) sendEnergyModeData()
        }

        override fun onOperationModeChanged(mode: Int) {
            sendCarLog("能量模式监听器回调 - 运行模式: $mode")
            lastOperationMode = mode
            sendCarData(buildCarData())
            if (energyModeListenerEnabled) sendEnergyModeData()
        }

        override fun onPowerGenerationStateChanged(mode: Int) {
            sendCarLog("能量模式监听器回调 - 发电状态: $mode")
            lastPowerGenerationState = mode
            sendCarData(buildCarData())
            if (energyModeListenerEnabled) sendEnergyModeData()
        }

        override fun onPowerGenerationValueChanged(value: Int) {
            sendCarLog("能量模式监听器回调 - 发电量: $value")
            lastPowerGenerationValue = value
            sendCarData(buildCarData())
            if (energyModeListenerEnabled) sendEnergyModeData()
        }

        override fun onRoadSurfaceChanged(type: Int) {
            sendCarLog("能量模式监听器回调 - 路面模式: $type")
            lastRoadSurfaceMode = type
            sendCarData(buildCarData())
            if (energyModeListenerEnabled) sendEnergyModeData()
        }
    }

    private val radarListener = object : AbsBYDAutoRadarListener() {
        override fun onRadarProbeStateChanged(area: Int, state: Int) {
            sendCarLog("雷达监听器回调 - 区域: $area, 状态: $state")
            when (area) {
                BYDAutoRadarDevice.RADAR_AREA_LEFT_FRONT -> lastRadarLeftFront = state
                BYDAutoRadarDevice.RADAR_AREA_RIGHT_FRONT -> lastRadarRightFront = state
                BYDAutoRadarDevice.RADAR_AREA_LEFT_REAR -> lastRadarLeftRear = state
                BYDAutoRadarDevice.RADAR_AREA_RIGHT_REAR -> lastRadarRightRear = state
                BYDAutoRadarDevice.RADAR_AREA_LEFT -> lastRadarLeft = state
                BYDAutoRadarDevice.RADAR_AREA_RIGHT -> lastRadarRight = state
                BYDAutoRadarDevice.RADAR_AREA_FRONT_LEFT_MID -> lastFrontLeftMid = state
                BYDAutoRadarDevice.RADAR_AREA_FRONT_RIGHT_MID -> lastFrontRightMid = state
            }
            sendCarData(buildCarData())
            if (radarListenerEnabled) sendRadarData()
        }

        override fun onReverseRadarSwitchStateChanged(state: Int) {
            sendCarLog("雷达监听器回调 - 倒车雷达开关: $state")
            lastReverseRadarSwitch = state
            sendCarData(buildCarData())
            if (radarListenerEnabled) sendRadarData()
        }
    }

    private val pm2p5Listener = object : AbsBYDAutoPM2p5Listener() {
        override fun onPM2p5CheckStateChanged(state_in: Int, state_out: Int) {
            sendCarLog("PM2.5 监听器回调 - 检测状态变化: 车内=$state_in, 车外=$state_out")
            lastPm25CheckStateIn = state_in
            lastPm25CheckStateOut = state_out
            if (pm2p5ListenerEnabled) sendPm2p5Data()
            sendCarData(buildCarData())
        }

        override fun onPM2p5LevelChanged(level_in: Int, level_out: Int) {
            sendCarLog("PM2.5 监听器回调 - 等级变化: 车内=$level_in, 车外=$level_out")
            lastPm25LevelIn = level_in
            lastPm25LevelOut = level_out
            if (pm2p5ListenerEnabled) sendPm2p5Data()
            sendCarData(buildCarData())
        }

        override fun onPM2p5ValueChanged(value_in: Int, value_out: Int) {
            sendCarLog("PM2.5 监听器回调 - 数值变化: 车内=$value_in, 车外=$value_out")
            lastPm25ValueIn = value_in
            lastPm25ValueOut = value_out
            if (pm2p5ListenerEnabled) sendPm2p5Data()
            sendCarData(buildCarData())
        }
    }

    private val chargeListener = object : AbsBYDAutoChargingListener() {
        override fun onChargerFaultStateChanged(value: Int) {
            sendCarLog("充电监听器回调 - 故障状态: $value")
            lastChargerFaultState = value
            sendCarData(buildCarData())
            if (chargeListenerEnabled) sendChargeData()
        }

        override fun onChargerWorkStateChanged(value: Int) {
            sendCarLog("充电监听器回调 - 工作状态: $value")
            lastChargerWorkState = value
            sendCarData(buildCarData())
            if (chargeListenerEnabled) sendChargeData()
        }

        override fun onChargingCapacityChanged(value: Double) {
            sendCarLog("充电监听器回调 - 充电量: $value")
            lastChargingCapacity = value
            sendCarData(buildCarData())
            if (chargeListenerEnabled) sendChargeData()
        }

        override fun onChargingTypeChanged(value: Int) {
            sendCarLog("充电监听器回调 - 充电类型: $value")
            lastChargingType = value
            sendCarData(buildCarData())
            if (chargeListenerEnabled) sendChargeData()
        }

        override fun onChargingRestTimeChanged(hour: Int, minute: Int) {
            sendCarLog("充电监听器回调 - 剩余时间: $hour 小时 $minute 分钟")
            lastChargingRestTimeHour = hour
            lastChargingRestTimeMinute = minute
            sendCarData(buildCarData())
            if (chargeListenerEnabled) sendChargeData()
        }

        override fun onChargingCapStateChanged(type: Int, state: Int) {
            sendCarLog("充电监听器回调 - 充电口状态: type=$type, state=$state")
            if (type == BYDAutoChargingDevice.CHARGING_CAP_AC) {
                lastChargingCapStateAc = state
            } else if (type == BYDAutoChargingDevice.CHARGING_CAP_DC) {
                lastChargingCapStateDc = state
            }
            sendCarData(buildCarData())
            if (chargeListenerEnabled) sendChargeData()
        }

        override fun onChargingPortLockRebackStateChanged(value: Int) {
            sendCarLog("充电监听器回调 - 充电口锁回退: $value")
            lastChargingPortLockRebackState = value
            sendCarData(buildCarData())
            if (chargeListenerEnabled) sendChargeData()
        }

        override fun onDischargeRequestStateChanged(value: Int) {
            sendCarLog("充电监听器回调 - 放电请求: $value")
            lastDischargeRequestState = value
            sendCarData(buildCarData())
            if (chargeListenerEnabled) sendChargeData()
        }

        override fun onChargerStateChanged(value: Int) {
            sendCarLog("充电监听器回调 - 充电器状态: $value")
            lastChargerState = value
            sendCarData(buildCarData())
            if (chargeListenerEnabled) sendChargeData()
        }

        override fun onChargingGunStateChanged(value: Int) {
            sendCarLog("充电监听器回调 - 充电枪状态: $value")
            lastChargingGunState = value
            sendCarData(buildCarData())
            if (chargeListenerEnabled) sendChargeData()
        }

        override fun onChargingPowerChanged(value: Double) {
            sendCarLog("充电监听器回调 - 充电功率: $value")
            lastChargingPower = value
            sendCarData(buildCarData())
            if (chargeListenerEnabled) sendChargeData()
        }

        override fun onBatteryManagementDeviceStateChanged(value: Int) {
            sendCarLog("充电监听器回调 - BMS状态: $value")
            lastBatteryManagementDeviceState = value
            sendCarData(buildCarData())
            if (chargeListenerEnabled) sendChargeData()
        }

        override fun onChargingScheduleEnableStateChanged(value: Int) {
            sendCarLog("充电监听器回调 - 定时充电使能: $value")
            lastChargingScheduleEnableState = value
            sendCarData(buildCarData())
            if (chargeListenerEnabled) sendChargeData()
        }

        override fun onChargingScheduleStateChanged(value: Int) {
            sendCarLog("充电监听器回调 - 定时充电状态: $value")
            lastChargingScheduleState = value
            sendCarData(buildCarData())
            if (chargeListenerEnabled) sendChargeData()
        }

        override fun onChargingGunNotInsertedStateChanged(value: Int) {
            sendCarLog("充电监听器回调 - 充电枪未插入: $value")
            lastChargingGunNotInsertedState = value
            sendCarData(buildCarData())
            if (chargeListenerEnabled) sendChargeData()
        }

        override fun onChargingScheduleTimeChanged(hour: Int, minute: Int) {
            sendCarLog("充电监听器回调 - 定时时间: $hour 小时 $minute 分钟")
            lastChargingScheduleTimeHour = hour
            lastChargingScheduleTimeMinute = minute
            sendCarData(buildCarData())
            if (chargeListenerEnabled) sendChargeData()
        }
    }

    private val mediaListener = object : AbsBYDAutoMultimediaListener() {
        override fun onMediaTypeChanged(type: Int) {
            sendCarLog("媒体监听器回调 - 媒体类型: $type")
            lastMediaType = type
            sendCarData(buildCarData())
            if (mediaListenerEnabled) sendMediaData()
        }

        override fun onPlayModeChanged(mode: Int) {
            sendCarLog("媒体监听器回调 - 播放模式: $mode")
            lastPlayMode = mode
            sendCarData(buildCarData())
            if (mediaListenerEnabled) sendMediaData()
        }

        override fun onPlayStateChanged(state: Int) {
            sendCarLog("媒体监听器回调 - 播放状态: $state")
            lastPlayState = state
            sendCarData(buildCarData())
            if (mediaListenerEnabled) sendMediaData()
        }

        override fun onPlayMediaInfoChanged(mediaInfo: MediaInfo?) {
            sendCarLog("媒体监听器回调 - 媒体信息变化")
            sendCarData(buildCarData())
            if (mediaListenerEnabled) sendMediaData()
        }
    }

    private val bodyStatusListener = object : AbsBYDAutoBodyworkListener() {
        override fun onAutoSystemStateChanged(state: Int) {
            sendCarLog("车身状态监听器回调 - 系统状态: $state")
            lastAutoSystemState = state
            sendCarData(buildCarData())
            if (bodyStatusListenerEnabled) sendBodyStatusData()
        }

        override fun onBatteryVoltageLevelChanged(level: Int) {
            sendCarLog("车身状态监听器回调 - 电瓶电压: $level")
            lastBatteryVoltageLevel = level
            sendCarData(buildCarData())
            if (bodyStatusListenerEnabled) sendBodyStatusData()
        }

        override fun onDoorStateChanged(area: Int, state: Int) {
            sendCarLog("车身状态监听器回调 - 车门区域: $area, 状态: $state")
            when (area) {
                BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_LEFT_FRONT -> lastDoorStateLf = state
                BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_RIGHT_FRONT -> lastDoorStateRf = state
                BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_LEFT_REAR -> lastDoorStateLr = state
                BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_RIGHT_REAR -> lastDoorStateRr = state
                BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_HOOD -> lastDoorStateHood = state
                BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_LUGGAGE_DOOR -> lastDoorStateLuggage = state
            }
            sendCarData(buildCarData())
            if (bodyStatusListenerEnabled) sendBodyStatusData()
        }

        override fun onWindowStateChanged(area: Int, state: Int) {
            sendCarLog("车身状态监听器回调 - 车窗区域: $area, 状态: $state")
            when (area) {
                BYDAutoBodyworkDevice.BODYWORK_CMD_WINDOW_LEFT_FRONT -> lastWindowStateLf = state
                BYDAutoBodyworkDevice.BODYWORK_CMD_WINDOW_RIGHT_FRONT -> lastWindowStateRf = state
                BYDAutoBodyworkDevice.BODYWORK_CMD_WINDOW_LEFT_REAR -> lastWindowStateLr = state
                BYDAutoBodyworkDevice.BODYWORK_CMD_WINDOW_RIGHT_REAR -> lastWindowStateRr = state
            }
            sendCarData(buildCarData())
            if (bodyStatusListenerEnabled) sendBodyStatusData()
        }

        override fun onWindowOpenPercentChanged(area: Int, value: Int) {
            sendCarLog("车身状态监听器回调 - 天窗/遮阳帘区域: $area, 开度: $value")
            when (area) {
                BYDAutoBodyworkDevice.BODYWORK_CMD_MOON_ROOF -> lastMoonRoofPercent = value
                BYDAutoBodyworkDevice.BODYWORK_CMD_SUNSHADE_PANEL -> lastSunshadePercent = value
            }
            sendCarData(buildCarData())
            if (bodyStatusListenerEnabled) sendBodyStatusData()
        }

        override fun onPowerLevelChanged(level: Int) {
            sendCarLog("车身状态监听器回调 - 电源等级: $level")
            lastPowerLevel = level
            sendCarData(buildCarData())
            if (bodyStatusListenerEnabled) sendBodyStatusData()
        }

        override fun onSteeringWheelValueChanged(type: Int, value: Double) {
            sendCarLog("车身状态监听器回调 - 方向盘类型: $type, 值: $value")
            when (type) {
                BYDAutoBodyworkDevice.BODYWORK_CMD_STEERING_WHEEL_ANGEL -> lastSteeringWheelAngle = value
                BYDAutoBodyworkDevice.BODYWORK_CMD_STEERING_WHEEL_SPEED -> lastSteeringWheelSpeed = value
            }
            sendCarData(buildCarData())
            if (bodyStatusListenerEnabled) sendBodyStatusData()
        }

        override fun onFuelElecLowPowerChanged(state: Int) {
            sendCarLog("车身状态监听器回调 - 油电低电量: $state")
            lastFuelElecLowPower = state
            sendCarData(buildCarData())
            if (bodyStatusListenerEnabled) sendBodyStatusData()
        }

        override fun onAlarmStateChanged(state: Int) {
            sendCarLog("车身状态监听器回调 - 报警状态: $state")
            lastAlarmState = state
            sendCarData(buildCarData())
            if (bodyStatusListenerEnabled) sendBodyStatusData()
        }
    }

    private val lightListener = object : AbsBYDAutoLightListener() {
        override fun onLightAutoSwitchOff() {
            sendCarLog("车灯监听器回调 - 灯光AUTO档关闭")
            lastLightAutoStatus = BYDAutoLightDevice.LIGHT_OFF
            sendCarData(buildCarData())
            if (lightListenerEnabled) sendLightData()
        }

        override fun onLightAutoSwitchOn() {
            sendCarLog("车灯监听器回调 - 灯光AUTO档打开")
            lastLightAutoStatus = BYDAutoLightDevice.LIGHT_ON
            sendCarData(buildCarData())
            if (lightListenerEnabled) sendLightData()
        }

        override fun onLightOff(type: Int) {
            sendCarLog("车灯监听器回调 - 车灯关闭: 类型=$type")
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
            sendCarData(buildCarData())
            if (lightListenerEnabled) sendLightData()
        }

        override fun onLightOn(type: Int) {
            sendCarLog("车灯监听器回调 - 车灯打开: 类型=$type")
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
            sendCarData(buildCarData())
            if (lightListenerEnabled) sendLightData()
        }

        override fun onAFSSwitchStateChange(state: Int) {
            sendCarLog("车灯监听器回调 - AFS开关状态变化: $state")
            lastAfsSwitch = state
            sendCarData(buildCarData())
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
                "currentSpeed" to (speedDevice?.getCurrentSpeed() ?: lastSpeed),
                "accelerateDeepness" to (speedDevice?.getAccelerateDeepness() ?: lastAccelerateDepth),
                "brakeDeepness" to (speedDevice?.getBrakeDeepness() ?: lastBrakeDepth)
            ),
            "statistic" to mapOf<String, Any?>(
                "drivingTime" to (statisticDevice?.getDrivingTimeValue() ?: 0.0),
                "elecDrivingRange" to (statisticDevice?.getElecDrivingRangeValue() ?: 0),
                "elecPercentage" to (statisticDevice?.getElecPercentageValue() ?: lastElecPercentage),
                "fuelDrivingRange" to (statisticDevice?.getFuelDrivingRangeValue() ?: 0),
                "fuelPercentage" to (statisticDevice?.getFuelPercentageValue() ?: lastFuelPercentage),
                "lastElecConPHM" to (statisticDevice?.getLastElecConPHMValue() ?: 0.0),
                "lastFuelConPHM" to (statisticDevice?.getLastFuelConPHMValue() ?: 0.0),
                "totalElecConPHM" to (statisticDevice?.getTotalElecConPHMValue() ?: 0.0),
                "totalFuelConPHM" to (statisticDevice?.getTotalFuelConPHMValue() ?: 0.0),
                "totalFuelCon" to (statisticDevice?.getTotalFuelConValue() ?: 0.0),
                "totalElecCon" to (statisticDevice?.getTotalElecConValue() ?: 0.0),
                "totalMileage" to (statisticDevice?.getTotalMileageValue() ?: lastTotalMileage),
                "keyBatteryLevel" to (statisticDevice?.getKeyBatteryLevel() ?: 0),
                "evMileage" to (statisticDevice?.getEVMileageValue() ?: lastEvMileage)
            ),
            "instrument" to mapOf<String, Any?>(
                "malfunctionInfo" to emptyMap<Int, Int>(),
                "alarmBuzzleState" to (instrumentDevice?.getAlarmBuzzleState() ?: 0),
                "unit" to emptyMap<Int, Int>(),
                "maintenanceInfo" to emptyMap<Int, Int>(),
                "externalChargingPower" to (instrumentDevice?.getExternalChargingPower() ?: lastExternalChargingPower)
            ),
            "door" to mapOf<String, Any?>(
                "leftFront" to (doorLockDevice?.getDoorLockStatus(BYDAutoDoorLockDevice.DOOR_LOCK_AREA_LEFT_FRONT) ?: lastDoorLockLeftFront),
                "leftRear" to (doorLockDevice?.getDoorLockStatus(BYDAutoDoorLockDevice.DOOR_LOCK_AREA_LEFT_REAR) ?: lastDoorLockLeftRear),
                "rightFront" to (doorLockDevice?.getDoorLockStatus(BYDAutoDoorLockDevice.DOOR_LOCK_AREA_RIGHT_FRONT) ?: lastDoorLockRightFront),
                "rightRear" to (doorLockDevice?.getDoorLockStatus(BYDAutoDoorLockDevice.DOOR_LOCK_AREA_RIGHT_REAR) ?: lastDoorLockRightRear),
                "back" to (doorLockDevice?.getDoorLockStatus(BYDAutoDoorLockDevice.DOOR_LOCK_AREA_BACK) ?: lastDoorLockBack),
                "childlockLeft" to (doorLockDevice?.getDoorLockStatus(BYDAutoDoorLockDevice.DOOR_LOCK_AREA_CHILDLOCK_LEFT) ?: lastDoorLockChildlockLeft),
                "childlockRight" to (doorLockDevice?.getDoorLockStatus(BYDAutoDoorLockDevice.DOOR_LOCK_AREA_CHILDLOCK_RIGHT) ?: lastDoorLockChildlockRight)
            ),
            "vehicleSetting" to mapOf<String, Any?>(
                "acBTWind" to (settingDevice?.getACBTWind() ?: lastAcBTWind),
                "acTunnelCycle" to (settingDevice?.getACTunnelCycle() ?: lastAcTunnelCycle),
                "acPauseCycle" to (settingDevice?.getACPauseCycle() ?: lastAcPauseCycle),
                "acAutoAir" to (settingDevice?.getACAutoAir() ?: lastAcAutoAir),
                "pm25Power" to (settingDevice?.getPM25Power() ?: lastPm25Power),
                "pm25SwitchCheck" to (settingDevice?.getPM25SwitchCheck() ?: lastPm25SwitchCheck),
                "pm25TimeCheck" to (settingDevice?.getPM25TimeCheck() ?: lastPm25TimeCheck),
                "energyFeedback" to (settingDevice?.getEnergyFeedback() ?: lastEnergyFeedback),
                "socTarget" to (settingDevice?.getSOCTarget() ?: lastSocTarget),
                "chargingPort" to (settingDevice?.getChargingPort() ?: lastChargingPort),
                "autoExternalRearMirrorFollowUp" to (settingDevice?.getAutoExternalRearMirrorFollowUpSwitch() ?: lastAutoExternalRearMirrorFollowUp),
                "lockOff" to (settingDevice?.getLockOff() ?: lastLockOff),
                "language" to (settingDevice?.getLanguage() ?: lastLanguage),
                "overspeedLock" to (settingDevice?.getOverspeedLock() ?: lastOverspeedLock),
                "safeWarnState" to (settingDevice?.getSafeWarnState() ?: lastSafeWarnState),
                "maintainRemindState" to (settingDevice?.getMaintainRemindState() ?: lastMaintainRemindState),
                "steerAssis" to (settingDevice?.getSteerAssis() ?: lastSteerAssis),
                "rearViewMirrorFlip" to (settingDevice?.getRearViewMirrorFlip() ?: lastRearViewMirrorFlip),
                "driverSeatAutoReturn" to lastDriverSeatAutoReturn,
                "steerPositionAutoReturn" to lastSteerPositionAutoReturn,
                "remoteControlUpwindowState" to (settingDevice?.getRemoteControlUpwindowState() ?: lastRemoteControlUpwindowState),
                "remoteControlDownwindowState" to (settingDevice?.getRemoteControlDownwindowState() ?: lastRemoteControlDownwindowState),
                "lockCarRiseWindow" to (settingDevice?.getLockCarRiseWindow() ?: lastLockCarRiseWindow),
                "microSwitchLockWindowState" to (settingDevice?.getMicroSwitchLockWindowState() ?: lastMicroSwitchLockWindowState),
                "microSwitchUnlockWindowState" to (settingDevice?.getMicroSwitchUnlockWindowState() ?: lastMicroSwitchUnlockWindowState),
                "backHomeLightDelayValue" to (settingDevice?.getBackHomeLightDelayValue() ?: lastBackHomeLightDelayValue),
                "leftHomeLightDelayValue" to (settingDevice?.getLeftHomeLightDelayValue() ?: lastLeftHomeLightDelayValue),
                "backDoorElectricMode" to (settingDevice?.getBackDoorElectricMode() ?: lastBackDoorElectricMode)
            ),
            "engine" to mapOf<String, Any?>(
                "engineDisplacement" to (engineDevice?.getEngineDisplacement() ?: lastEngineDisplacement),
                "engineCode" to (engineDevice?.getEngineCode() ?: lastEngineCode),
                "enginePower" to (engineDevice?.getEnginePower() ?: lastEnginePower),
                "engineSpeed" to (engineDevice?.getEngineSpeed() ?: lastEngineSpeed),
                "engineCoolantLevel" to (engineDevice?.getEngineCoolantLevel() ?: lastEngineCoolantLevel),
                "oilLevel" to (engineDevice?.getOilLevel() ?: lastOilLevel)
            ),
            "panorama" to mapOf<String, Any?>(
                "panoOutputSignal" to (panoramaDevice?.getPanoOutputSignal() ?: lastPanoOutputSignal),
                "panoWorkState" to (panoramaDevice?.getPanoWorkState() ?: lastPanoWorkState),
                "backLineConfig" to (panoramaDevice?.getBackLineConfig() ?: lastBackLineConfig),
                "panoOutputState" to (panoramaDevice?.getPanoOutputState() ?: lastPanoOutputState),
                "panoRotation" to (panoramaDevice?.getPanoRotation() ?: lastPanoRotation),
                "displayMode" to (panoramaDevice?.getDisplayMode() ?: lastDisplayMode),
                "panoramaOnlineState" to (panoramaDevice?.getPanoramaOnlineState() ?: lastPanoramaOnlineState)
            ),
            "ac" to mapOf<String, Any?>(
                "acCompressorMode" to (acDevice?.getAcCompressorMode() ?: lastAcCompressorMode),
                "acCompressorManualSign" to (acDevice?.getAcCompressorManualSign() ?: lastAcCompressorManualSign),
                "acWindLevelManualSign" to (acDevice?.getAcWindLevelManualSign() ?: lastAcWindLevelManualSign),
                "acWindModeManualSign" to (acDevice?.getAcWindModeManualSign() ?: lastAcWindModeManualSign),
                "acStartState" to (acDevice?.getAcStartState() ?: lastAcStartState),
                "acControlMode" to (acDevice?.getAcControlMode() ?: lastAcControlMode),
                "acCycleMode" to (acDevice?.getAcCycleMode() ?: lastAcCycleMode),
                "acWindMode" to (acDevice?.getAcWindMode() ?: lastAcWindMode),
                "acDefrostStateFront" to (acDevice?.getAcDefrostState(BYDAutoAcDevice.AC_DEFROST_AREA_FRONT) ?: lastAcDefrostStateFront),
                "acDefrostStateRear" to (acDevice?.getAcDefrostState(BYDAutoAcDevice.AC_DEFROST_AREA_REAR) ?: lastAcDefrostStateRear),
                "acWindLevel" to (acDevice?.getAcWindLevel() ?: lastAcWindLevel),
                "acTemperatureMain" to (acDevice?.getTemprature(BYDAutoAcDevice.AC_TEMPERATURE_MAIN) ?: lastAcTemperatureMain),
                "acTemperatureDeputy" to (acDevice?.getTemprature(BYDAutoAcDevice.AC_TEMPERATURE_DEPUTY) ?: lastAcTemperatureDeputy),
                "acTemperatureRear" to (acDevice?.getTemprature(BYDAutoAcDevice.AC_TEMPERATURE_REAR) ?: lastAcTemperatureRear),
                "acTemperatureOut" to (acDevice?.getTemprature(BYDAutoAcDevice.AC_TEMPERATURE_OUT) ?: lastAcTemperatureOut),
                "temperatureUnit" to (acDevice?.getTemperatureUnit() ?: lastTemperatureUnit),
                "acTemperatureControlMode" to (acDevice?.getAcTemperatureControlMode() ?: lastAcTemperatureControlMode),
                "acVentilationState" to (acDevice?.getAcVentilationState() ?: lastAcVentilationState),
                "rearAcStartState" to (acDevice?.getRearAcStartState() ?: lastRearAcStartState)
            ),
            "sensor" to mapOf<String, Any?>(
                "lightIntensity" to (sensorDevice?.getLightIntensity() ?: lastLightIntensity)
            ),
            "time" to run {
                val timeArray = timeDevice?.getTime()
                mapOf<String, Any?>(
                    "year" to (timeArray?.getOrNull(0) ?: lastYear),
                    "month" to (timeArray?.getOrNull(1) ?: lastMonth),
                    "day" to (timeArray?.getOrNull(2) ?: lastDay),
                    "hour" to (timeArray?.getOrNull(3) ?: lastHour),
                    "minute" to (timeArray?.getOrNull(4) ?: lastMinute),
                    "second" to (timeArray?.getOrNull(5) ?: lastSecond),
                    "timeFormat" to (timeDevice?.getTimeFormat() ?: lastTimeFormat)
                )
            },
            "energyMode" to mapOf<String, Any?>(
                "energyMode" to (energyDevice?.getEnergyMode() ?: lastEnergyMode),
                "operationMode" to (energyDevice?.getOperationMode() ?: lastOperationMode),
                "powerGenerationState" to (energyDevice?.getPowerGenerationState() ?: lastPowerGenerationState),
                "powerGenerationValue" to (energyDevice?.getPowerGenerationValue() ?: lastPowerGenerationValue),
                "roadSurfaceMode" to (energyDevice?.getRoadSurfaceMode() ?: lastRoadSurfaceMode)
            ),
            "radar" to mapOf<String, Any?>(
                "leftFront" to (radarDevice?.getRadarProbeState(BYDAutoRadarDevice.RADAR_AREA_LEFT_FRONT) ?: 0),
                "rightFront" to (radarDevice?.getRadarProbeState(BYDAutoRadarDevice.RADAR_AREA_RIGHT_FRONT) ?: 0),
                "leftRear" to (radarDevice?.getRadarProbeState(BYDAutoRadarDevice.RADAR_AREA_LEFT_REAR) ?: 0),
                "rightRear" to (radarDevice?.getRadarProbeState(BYDAutoRadarDevice.RADAR_AREA_RIGHT_REAR) ?: 0),
                "left" to (radarDevice?.getRadarProbeState(BYDAutoRadarDevice.RADAR_AREA_LEFT) ?: 0),
                "right" to (radarDevice?.getRadarProbeState(BYDAutoRadarDevice.RADAR_AREA_RIGHT) ?: 0),
                "frontLeftMid" to (radarDevice?.getRadarProbeState(BYDAutoRadarDevice.RADAR_AREA_FRONT_LEFT_MID) ?: 0),
                "frontRightMid" to (radarDevice?.getRadarProbeState(BYDAutoRadarDevice.RADAR_AREA_FRONT_RIGHT_MID) ?: 0),
                "reverseRadarSwitch" to (radarDevice?.getReverseRadarSwitchState() ?: 0)
            ),
            "tyre" to mapOf<String, Any?>(
                "tyrePressureLf" to (tyreDevice?.getTyrePressureValue(BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_FRONT) ?: lastTyrePressureLf),
                "tyrePressureRf" to (tyreDevice?.getTyrePressureValue(BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_FRONT) ?: lastTyrePressureRf),
                "tyrePressureLr" to (tyreDevice?.getTyrePressureValue(BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_REAR) ?: lastTyrePressureLr),
                "tyrePressureRr" to (tyreDevice?.getTyrePressureValue(BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_REAR) ?: lastTyrePressureRr),
                "tyreAirLeakStateLf" to (tyreDevice?.getTyreAirLeakState(BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_FRONT) ?: lastTyreAirLeakStateLf),
                "tyreAirLeakStateRf" to (tyreDevice?.getTyreAirLeakState(BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_FRONT) ?: lastTyreAirLeakStateRf),
                "tyreAirLeakStateLr" to (tyreDevice?.getTyreAirLeakState(BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_REAR) ?: lastTyreAirLeakStateLr),
                "tyreAirLeakStateRr" to (tyreDevice?.getTyreAirLeakState(BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_REAR) ?: lastTyreAirLeakStateRr),
                "tyreBatteryState" to (tyreDevice?.getTyreBatteryState() ?: lastTyreBatteryState),
                "tyreSystemState" to (tyreDevice?.getTyreSystemState() ?: lastTyreSystemState),
                "tyreTemperatureState" to (tyreDevice?.getTyreTemperatureState() ?: lastTyreTemperatureState),
                "tyreSignalStateLf" to (tyreDevice?.getTyreSignalState(BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_FRONT) ?: lastTyreSignalStateLf),
                "tyreSignalStateRf" to (tyreDevice?.getTyreSignalState(BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_FRONT) ?: lastTyreSignalStateRf),
                "tyreSignalStateLr" to (tyreDevice?.getTyreSignalState(BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_REAR) ?: lastTyreSignalStateLr),
                "tyreSignalStateRr" to (tyreDevice?.getTyreSignalState(BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_REAR) ?: lastTyreSignalStateRr)
            ),
            "airQuality" to mapOf<String, Any?>(
                "pm25OnlineState" to (pm2p5Device?.getPM2p5OnlineState() ?: lastPm25OnlineState),
                "pm25CheckStateIn" to (pm2p5Device?.getPM2p5CheckState()?.getOrNull(0) ?: lastPm25CheckStateIn),
                "pm25CheckStateOut" to (pm2p5Device?.getPM2p5CheckState()?.getOrNull(1) ?: lastPm25CheckStateOut),
                "pm25LevelIn" to (pm2p5Device?.getPM2p5Level()?.getOrNull(0) ?: lastPm25LevelIn),
                "pm25LevelOut" to (pm2p5Device?.getPM2p5Level()?.getOrNull(1) ?: lastPm25LevelOut),
                "pm25ValueIn" to (pm2p5Device?.getPM2p5Value()?.getOrNull(0) ?: lastPm25ValueIn),
                "pm25ValueOut" to (pm2p5Device?.getPM2p5Value()?.getOrNull(1) ?: lastPm25ValueOut)
            ),
            "charge" to mapOf<String, Any?>(
                "chargerFaultState" to (chargeDevice?.getChargerFaultState() ?: lastChargerFaultState),
                "chargerWorkState" to (chargeDevice?.getChargerWorkState() ?: lastChargerWorkState),
                "chargingCapacity" to (chargeDevice?.getChargingCapacity() ?: lastChargingCapacity),
                "chargingType" to (chargeDevice?.getChargingType() ?: lastChargingType),
                "chargingRestTimeHour" to (chargeDevice?.getChargingRestTime()?.getOrNull(0) ?: lastChargingRestTimeHour),
                "chargingRestTimeMinute" to (chargeDevice?.getChargingRestTime()?.getOrNull(1) ?: lastChargingRestTimeMinute),
                "chargingCapStateAc" to (chargeDevice?.getChargingCapState(BYDAutoChargingDevice.CHARGING_CAP_AC) ?: lastChargingCapStateAc),
                "chargingCapStateDc" to (chargeDevice?.getChargingCapState(BYDAutoChargingDevice.CHARGING_CAP_DC) ?: lastChargingCapStateDc),
                "chargingPortLockRebackState" to (chargeDevice?.getChargingPortLockRebackState() ?: lastChargingPortLockRebackState),
                "dischargeRequestState" to (chargeDevice?.getDischargeRequestState() ?: lastDischargeRequestState),
                "chargerState" to (chargeDevice?.getChargerState() ?: lastChargerState),
                "chargingGunState" to (chargeDevice?.getChargingGunState() ?: lastChargingGunState),
                "chargingPower" to (chargeDevice?.getChargingPower() ?: lastChargingPower),
                "batteryManagementDeviceState" to (chargeDevice?.getBatteryManagementDeviceState() ?: lastBatteryManagementDeviceState),
                "chargingScheduleEnableState" to (chargeDevice?.getChargingScheduleEnableState() ?: lastChargingScheduleEnableState),
                "chargingScheduleState" to (chargeDevice?.getChargingScheduleState() ?: lastChargingScheduleState),
                "chargingGunNotInsertedState" to (chargeDevice?.getChargingGunNotInsertedState() ?: lastChargingGunNotInsertedState),
                "chargingScheduleTimeHour" to (chargeDevice?.getChargingScheduleTime()?.getOrNull(0) ?: lastChargingScheduleTimeHour),
                "chargingScheduleTimeMinute" to (chargeDevice?.getChargingScheduleTime()?.getOrNull(1) ?: lastChargingScheduleTimeMinute)
            ),
            "media" to mapOf<String, Any?>(
                "mediaType" to (mediaDevice?.getMediaType() ?: lastMediaType),
                "playMode" to (mediaDevice?.getPlayMode() ?: lastPlayMode),
                "playState" to (mediaDevice?.getPlayState() ?: lastPlayState),
                "fileName" to (mediaDevice?.getPlayMediaInfo()?.fileName ?: lastFileName),
                "artistName" to (mediaDevice?.getPlayMediaInfo()?.artistName ?: lastArtistName),
                "albumName" to (mediaDevice?.getPlayMediaInfo()?.albumName ?: lastAlbumName)
            ),
            "bodyStatus" to mapOf<String, Any?>(
                "autoVIN" to (bodyStatusDevice?.getAutoVIN() ?: lastAutoVIN),
                "autoModelName" to (bodyStatusDevice?.getAutoModelName() ?: lastAutoModelName),
                "autoSystemState" to (bodyStatusDevice?.getAutoSystemState() ?: lastAutoSystemState),
                "doorStateLf" to (bodyStatusDevice?.getDoorState(BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_LEFT_FRONT) ?: lastDoorStateLf),
                "doorStateRf" to (bodyStatusDevice?.getDoorState(BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_RIGHT_FRONT) ?: lastDoorStateRf),
                "doorStateLr" to (bodyStatusDevice?.getDoorState(BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_LEFT_REAR) ?: lastDoorStateLr),
                "doorStateRr" to (bodyStatusDevice?.getDoorState(BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_RIGHT_REAR) ?: lastDoorStateRr),
                "doorStateHood" to (bodyStatusDevice?.getDoorState(BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_HOOD) ?: lastDoorStateHood),
                "doorStateLuggage" to (bodyStatusDevice?.getDoorState(BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_LUGGAGE_DOOR) ?: lastDoorStateLuggage),
                "windowStateLf" to (bodyStatusDevice?.getWindowState(BYDAutoBodyworkDevice.BODYWORK_CMD_WINDOW_LEFT_FRONT) ?: lastWindowStateLf),
                "windowStateRf" to (bodyStatusDevice?.getWindowState(BYDAutoBodyworkDevice.BODYWORK_CMD_WINDOW_RIGHT_FRONT) ?: lastWindowStateRf),
                "windowStateLr" to (bodyStatusDevice?.getWindowState(BYDAutoBodyworkDevice.BODYWORK_CMD_WINDOW_LEFT_REAR) ?: lastWindowStateLr),
                "windowStateRr" to (bodyStatusDevice?.getWindowState(BYDAutoBodyworkDevice.BODYWORK_CMD_WINDOW_RIGHT_REAR) ?: lastWindowStateRr),
                "moonRoofPercent" to (bodyStatusDevice?.getWindowOpenPercent(BYDAutoBodyworkDevice.BODYWORK_CMD_MOON_ROOF) ?: lastMoonRoofPercent),
                "sunshadePercent" to (bodyStatusDevice?.getWindowOpenPercent(BYDAutoBodyworkDevice.BODYWORK_CMD_SUNSHADE_PANEL) ?: lastSunshadePercent),
                "batteryVoltageLevel" to (bodyStatusDevice?.getBatteryVoltageLevel() ?: lastBatteryVoltageLevel),
                "powerLevel" to (bodyStatusDevice?.getPowerLevel() ?: lastPowerLevel),
                "steeringWheelAngle" to (bodyStatusDevice?.getSteeringWheelValue(BYDAutoBodyworkDevice.BODYWORK_CMD_STEERING_WHEEL_ANGEL) ?: lastSteeringWheelAngle),
                "steeringWheelSpeed" to (bodyStatusDevice?.getSteeringWheelValue(BYDAutoBodyworkDevice.BODYWORK_CMD_STEERING_WHEEL_SPEED) ?: lastSteeringWheelSpeed),
                "fuelElecLowPower" to (bodyStatusDevice?.getFuelElecLowPower() ?: lastFuelElecLowPower),
                "alarmState" to (bodyStatusDevice?.getAlarmState() ?: lastAlarmState),
                "moonRoofConfig" to (bodyStatusDevice?.getMoonRoofConfig() ?: lastMoonRoofConfig)
            ),
            "light" to mapOf<String, Any?>(
                "lightAutoStatus" to (lightDevice?.getLightAutoStatus() ?: lastLightAutoStatus),
                "lightSide" to (lightDevice?.getLightStatus(BYDAutoLightDevice.LIGHT_SIDE) ?: lastLightSide),
                "lightLowBeam" to (lightDevice?.getLightStatus(BYDAutoLightDevice.LIGHT_LOW_BEAM) ?: lastLightLowBeam),
                "lightHighBeam" to (lightDevice?.getLightStatus(BYDAutoLightDevice.LIGHT_HIGH_BEAM) ?: lastLightHighBeam),
                "lightLeftTurnSignal" to (lightDevice?.getLightStatus(BYDAutoLightDevice.LIGHT_LEFT_TURN_SIGNAL) ?: lastLightLeftTurnSignal),
                "lightRightTurnSignal" to (lightDevice?.getLightStatus(BYDAutoLightDevice.LIGHT_RIGHT_TURN_SIGNAL) ?: lastLightRightTurnSignal),
                "lightFrontFog" to (lightDevice?.getLightStatus(BYDAutoLightDevice.LIGHT_FRONT_FOG) ?: lastLightFrontFog),
                "lightRearFog" to (lightDevice?.getLightStatus(BYDAutoLightDevice.LIGHT_REAR_FOG) ?: lastLightRearFog),
                "lightFoot" to (lightDevice?.getLightStatus(BYDAutoLightDevice.LIGHT_FOOT) ?: lastLightFoot),
                "afsSwitch" to (lightDevice?.getAFSSwitch() ?: lastAfsSwitch)
            ),
            "timestamp" to System.currentTimeMillis()
        )
    }

    // ==================== 车速类接口 ====================
    private var speedListenerEnabled = false

    fun getSpeedData(): Map<String, Any?> {
        return mapOf<String, Any?>(
            "currentSpeed" to (speedDevice?.getCurrentSpeed() ?: lastSpeed),
            "accelerateDeepness" to (speedDevice?.getAccelerateDeepness() ?: lastAccelerateDepth),
            "brakeDeepness" to (speedDevice?.getBrakeDeepness() ?: lastBrakeDepth)
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

        override fun onAcWindModeShownStateChanged(state: Int) {
            sendCarLog("空调监听器回调 - 出风模式显示状态变化: $state")
            if (acListenerEnabled) sendAcData()
            sendCarData(buildCarData())
        }
    }

    fun getAcData(): Map<String, Any?> {
        return mapOf<String, Any?>(
            "acCompressorMode" to (acDevice?.getAcCompressorMode() ?: lastAcCompressorMode),
            "acCompressorManualSign" to (acDevice?.getAcCompressorManualSign() ?: lastAcCompressorManualSign),
            "acWindLevelManualSign" to (acDevice?.getAcWindLevelManualSign() ?: lastAcWindLevelManualSign),
            "acWindModeManualSign" to (acDevice?.getAcWindModeManualSign() ?: lastAcWindModeManualSign),
            "acStartState" to (acDevice?.getAcStartState() ?: lastAcStartState),
            "acControlMode" to (acDevice?.getAcControlMode() ?: lastAcControlMode),
            "acCycleMode" to (acDevice?.getAcCycleMode() ?: lastAcCycleMode),
            "acWindMode" to (acDevice?.getAcWindMode() ?: lastAcWindMode),
            "acDefrostStateFront" to (acDevice?.getAcDefrostState(BYDAutoAcDevice.AC_DEFROST_AREA_FRONT) ?: lastAcDefrostStateFront),
            "acDefrostStateRear" to (acDevice?.getAcDefrostState(BYDAutoAcDevice.AC_DEFROST_AREA_REAR) ?: lastAcDefrostStateRear),
            "acWindLevel" to (acDevice?.getAcWindLevel() ?: lastAcWindLevel),
            "acTemperatureMain" to (acDevice?.getTemprature(BYDAutoAcDevice.AC_TEMPERATURE_MAIN) ?: lastAcTemperatureMain),
            "acTemperatureDeputy" to (acDevice?.getTemprature(BYDAutoAcDevice.AC_TEMPERATURE_DEPUTY) ?: lastAcTemperatureDeputy),
            "acTemperatureRear" to (acDevice?.getTemprature(BYDAutoAcDevice.AC_TEMPERATURE_REAR) ?: lastAcTemperatureRear),
            "acTemperatureOut" to (acDevice?.getTemprature(BYDAutoAcDevice.AC_TEMPERATURE_OUT) ?: lastAcTemperatureOut),
            "temperatureUnit" to (acDevice?.getTemperatureUnit() ?: lastTemperatureUnit),
            "acTemperatureControlMode" to (acDevice?.getAcTemperatureControlMode() ?: lastAcTemperatureControlMode),
            "acVentilationState" to (acDevice?.getAcVentilationState() ?: lastAcVentilationState),
            "rearAcStartState" to (acDevice?.getRearAcStartState() ?: lastRearAcStartState)
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
            val success = result == 0
            if (success) {
                sendCarData(buildCarData())
            }
            success
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
        return mapOf<String, Any?>(
            "drivingTime" to (statisticDevice?.getDrivingTimeValue() ?: 0.0),
            "elecDrivingRange" to (statisticDevice?.getElecDrivingRangeValue() ?: 0),
            "elecPercentage" to (statisticDevice?.getElecPercentageValue() ?: lastElecPercentage),
            "fuelDrivingRange" to (statisticDevice?.getFuelDrivingRangeValue() ?: 0),
            "fuelPercentage" to (statisticDevice?.getFuelPercentageValue() ?: lastFuelPercentage),
            "lastElecConPHM" to (statisticDevice?.getLastElecConPHMValue() ?: 0.0),
            "lastFuelConPHM" to (statisticDevice?.getLastFuelConPHMValue() ?: 0.0),
            "totalElecConPHM" to (statisticDevice?.getTotalElecConPHMValue() ?: 0.0),
            "totalFuelConPHM" to (statisticDevice?.getTotalFuelConPHMValue() ?: 0.0),
            "totalFuelCon" to (statisticDevice?.getTotalFuelConValue() ?: 0.0),
            "totalElecCon" to (statisticDevice?.getTotalElecConValue() ?: 0.0),
            "totalMileage" to (statisticDevice?.getTotalMileageValue() ?: lastTotalMileage),
            "keyBatteryLevel" to (statisticDevice?.getKeyBatteryLevel() ?: 0),
            "evMileage" to (statisticDevice?.getEVMileageValue() ?: lastEvMileage)
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
        return mapOf<String, Any?>(
            "malfunctionInfo" to emptyMap<Int, Int>(),
            "alarmBuzzleState" to (instrumentDevice?.getAlarmBuzzleState() ?: 0),
            "unit" to emptyMap<Int, Int>(),
            "maintenanceInfo" to emptyMap<Int, Int>(),
            "externalChargingPower" to (instrumentDevice?.getExternalChargingPower() ?: lastExternalChargingPower)
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
        return mapOf<String, Any?>(
            "leftFront" to (doorLockDevice?.getDoorLockStatus(BYDAutoDoorLockDevice.DOOR_LOCK_AREA_LEFT_FRONT) ?: lastDoorLockLeftFront),
            "leftRear" to (doorLockDevice?.getDoorLockStatus(BYDAutoDoorLockDevice.DOOR_LOCK_AREA_LEFT_REAR) ?: lastDoorLockLeftRear),
            "rightFront" to (doorLockDevice?.getDoorLockStatus(BYDAutoDoorLockDevice.DOOR_LOCK_AREA_RIGHT_FRONT) ?: lastDoorLockRightFront),
            "rightRear" to (doorLockDevice?.getDoorLockStatus(BYDAutoDoorLockDevice.DOOR_LOCK_AREA_RIGHT_REAR) ?: lastDoorLockRightRear),
            "back" to (doorLockDevice?.getDoorLockStatus(BYDAutoDoorLockDevice.DOOR_LOCK_AREA_BACK) ?: lastDoorLockBack),
            "childlockLeft" to (doorLockDevice?.getDoorLockStatus(BYDAutoDoorLockDevice.DOOR_LOCK_AREA_CHILDLOCK_LEFT) ?: lastDoorLockChildlockLeft),
            "childlockRight" to (doorLockDevice?.getDoorLockStatus(BYDAutoDoorLockDevice.DOOR_LOCK_AREA_CHILDLOCK_RIGHT) ?: lastDoorLockChildlockRight)
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
        return mapOf<String, Any?>(
            "acBTWind" to (settingDevice?.getACBTWind() ?: lastAcBTWind),
            "acTunnelCycle" to (settingDevice?.getACTunnelCycle() ?: lastAcTunnelCycle),
            "acPauseCycle" to (settingDevice?.getACPauseCycle() ?: lastAcPauseCycle),
            "acAutoAir" to (settingDevice?.getACAutoAir() ?: lastAcAutoAir),
            "pm25Power" to (settingDevice?.getPM25Power() ?: lastPm25Power),
            "pm25SwitchCheck" to (settingDevice?.getPM25SwitchCheck() ?: lastPm25SwitchCheck),
            "pm25TimeCheck" to (settingDevice?.getPM25TimeCheck() ?: lastPm25TimeCheck),
            "energyFeedback" to (settingDevice?.getEnergyFeedback() ?: lastEnergyFeedback),
            "socTarget" to (settingDevice?.getSOCTarget() ?: lastSocTarget),
            "chargingPort" to (settingDevice?.getChargingPort() ?: lastChargingPort),
            "autoExternalRearMirrorFollowUp" to (settingDevice?.getAutoExternalRearMirrorFollowUpSwitch() ?: lastAutoExternalRearMirrorFollowUp),
            "lockOff" to (settingDevice?.getLockOff() ?: lastLockOff),
            "language" to (settingDevice?.getLanguage() ?: lastLanguage),
            "overspeedLock" to (settingDevice?.getOverspeedLock() ?: lastOverspeedLock),
            "safeWarnState" to (settingDevice?.getSafeWarnState() ?: lastSafeWarnState),
            "maintainRemindState" to (settingDevice?.getMaintainRemindState() ?: lastMaintainRemindState),
            "steerAssis" to (settingDevice?.getSteerAssis() ?: lastSteerAssis),
            "rearViewMirrorFlip" to (settingDevice?.getRearViewMirrorFlip() ?: lastRearViewMirrorFlip),
            "driverSeatAutoReturn" to lastDriverSeatAutoReturn,
            "steerPositionAutoReturn" to lastSteerPositionAutoReturn,
            "remoteControlUpwindowState" to (settingDevice?.getRemoteControlUpwindowState() ?: lastRemoteControlUpwindowState),
            "remoteControlDownwindowState" to (settingDevice?.getRemoteControlDownwindowState() ?: lastRemoteControlDownwindowState),
            "lockCarRiseWindow" to (settingDevice?.getLockCarRiseWindow() ?: lastLockCarRiseWindow),
            "microSwitchLockWindowState" to (settingDevice?.getMicroSwitchLockWindowState() ?: lastMicroSwitchLockWindowState),
            "microSwitchUnlockWindowState" to (settingDevice?.getMicroSwitchUnlockWindowState() ?: lastMicroSwitchUnlockWindowState),
            "backHomeLightDelayValue" to (settingDevice?.getBackHomeLightDelayValue() ?: lastBackHomeLightDelayValue),
            "leftHomeLightDelayValue" to (settingDevice?.getLeftHomeLightDelayValue() ?: lastLeftHomeLightDelayValue),
            "backDoorElectricMode" to (settingDevice?.getBackDoorElectricMode() ?: lastBackDoorElectricMode)
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
                sendCarData(buildCarData())
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
        return mapOf<String, Any?>(
            "engineDisplacement" to (engineDevice?.getEngineDisplacement() ?: lastEngineDisplacement),
            "engineCode" to (engineDevice?.getEngineCode() ?: lastEngineCode),
            "enginePower" to (engineDevice?.getEnginePower() ?: lastEnginePower),
            "engineSpeed" to (engineDevice?.getEngineSpeed() ?: lastEngineSpeed),
            "engineCoolantLevel" to (engineDevice?.getEngineCoolantLevel() ?: lastEngineCoolantLevel),
            "oilLevel" to (engineDevice?.getOilLevel() ?: lastOilLevel)
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
        return mapOf<String, Any?>(
            "panoOutputSignal" to (panoramaDevice?.panoOutputSignal ?: lastPanoOutputSignal),
            "panoWorkState" to (panoramaDevice?.panoWorkState ?: lastPanoWorkState),
            "backLineConfig" to (panoramaDevice?.backLineConfig ?: lastBackLineConfig),
            "panoOutputState" to (panoramaDevice?.panoOutputState ?: lastPanoOutputState),
            "panoRotation" to (panoramaDevice?.panoRotation ?: lastPanoRotation),
            "displayMode" to (panoramaDevice?.displayMode ?: lastDisplayMode),
            "panoramaOnlineState" to (panoramaDevice?.panoramaOnlineState ?: lastPanoramaOnlineState)
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
        return mapOf<String, Any?>("lightIntensity" to (sensorDevice?.getLightIntensity() ?: lastLightIntensity))
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
        val timeArray = timeDevice?.getTime()
        return mapOf<String, Any?>(
            "year" to (timeArray?.getOrNull(0) ?: lastYear),
            "month" to (timeArray?.getOrNull(1) ?: lastMonth),
            "day" to (timeArray?.getOrNull(2) ?: lastDay),
            "hour" to (timeArray?.getOrNull(3) ?: lastHour),
            "minute" to (timeArray?.getOrNull(4) ?: lastMinute),
            "second" to (timeArray?.getOrNull(5) ?: lastSecond),
            "timeFormat" to (timeDevice?.getTimeFormat() ?: lastTimeFormat)
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
        return mapOf<String, Any?>(
            "energyMode" to (energyDevice?.getEnergyMode() ?: lastEnergyMode),
            "operationMode" to (energyDevice?.getOperationMode() ?: lastOperationMode),
            "powerGenerationState" to (energyDevice?.getPowerGenerationState() ?: lastPowerGenerationState),
            "powerGenerationValue" to (energyDevice?.getPowerGenerationValue() ?: lastPowerGenerationValue),
            "roadSurfaceMode" to (energyDevice?.getRoadSurfaceMode() ?: lastRoadSurfaceMode)
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
        return mapOf<String, Any?>(
            "leftFront" to (radarDevice?.getRadarProbeState(BYDAutoRadarDevice.RADAR_AREA_LEFT_FRONT) ?: lastRadarLeftFront),
            "rightFront" to (radarDevice?.getRadarProbeState(BYDAutoRadarDevice.RADAR_AREA_RIGHT_FRONT) ?: lastRadarRightFront),
            "leftRear" to (radarDevice?.getRadarProbeState(BYDAutoRadarDevice.RADAR_AREA_LEFT_REAR) ?: lastRadarLeftRear),
            "rightRear" to (radarDevice?.getRadarProbeState(BYDAutoRadarDevice.RADAR_AREA_RIGHT_REAR) ?: lastRadarRightRear),
            "left" to (radarDevice?.getRadarProbeState(BYDAutoRadarDevice.RADAR_AREA_LEFT) ?: lastRadarLeft),
            "right" to (radarDevice?.getRadarProbeState(BYDAutoRadarDevice.RADAR_AREA_RIGHT) ?: lastRadarRight),
            "frontLeftMid" to (radarDevice?.getRadarProbeState(BYDAutoRadarDevice.RADAR_AREA_FRONT_LEFT_MID) ?: lastFrontLeftMid),
            "frontRightMid" to (radarDevice?.getRadarProbeState(BYDAutoRadarDevice.RADAR_AREA_FRONT_RIGHT_MID) ?: lastFrontRightMid),
            "reverseRadarSwitch" to (radarDevice?.getReverseRadarSwitchState() ?: lastReverseRadarSwitch)
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
        return mapOf<String, Any?>(
            "tyrePressureLf" to (tyreDevice?.getTyrePressureValue(BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_FRONT) ?: lastTyrePressureLf),
            "tyrePressureRf" to (tyreDevice?.getTyrePressureValue(BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_FRONT) ?: lastTyrePressureRf),
            "tyrePressureLr" to (tyreDevice?.getTyrePressureValue(BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_REAR) ?: lastTyrePressureLr),
            "tyrePressureRr" to (tyreDevice?.getTyrePressureValue(BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_REAR) ?: lastTyrePressureRr),
            "tyreAirLeakStateLf" to (tyreDevice?.getTyreAirLeakState(BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_FRONT) ?: lastTyreAirLeakStateLf),
            "tyreAirLeakStateRf" to (tyreDevice?.getTyreAirLeakState(BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_FRONT) ?: lastTyreAirLeakStateRf),
            "tyreAirLeakStateLr" to (tyreDevice?.getTyreAirLeakState(BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_REAR) ?: lastTyreAirLeakStateLr),
            "tyreAirLeakStateRr" to (tyreDevice?.getTyreAirLeakState(BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_REAR) ?: lastTyreAirLeakStateRr),
            "tyreBatteryState" to (tyreDevice?.getTyreBatteryState() ?: lastTyreBatteryState),
            "tyreSystemState" to (tyreDevice?.getTyreSystemState() ?: lastTyreSystemState),
            "tyreTemperatureState" to (tyreDevice?.getTyreTemperatureState() ?: lastTyreTemperatureState),
            "tyreSignalStateLf" to (tyreDevice?.getTyreSignalState(BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_FRONT) ?: lastTyreSignalStateLf),
            "tyreSignalStateRf" to (tyreDevice?.getTyreSignalState(BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_FRONT) ?: lastTyreSignalStateRf),
            "tyreSignalStateLr" to (tyreDevice?.getTyreSignalState(BYDAutoTyreDevice.TYRE_COMMAND_AREA_LEFT_REAR) ?: lastTyreSignalStateLr),
            "tyreSignalStateRr" to (tyreDevice?.getTyreSignalState(BYDAutoTyreDevice.TYRE_COMMAND_AREA_RIGHT_REAR) ?: lastTyreSignalStateRr)
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
    private var pm2p5ListenerEnabled = false
    private var lastPm25OnlineState: Int = 0
    private var lastPm25CheckStateIn: Int = 0
    private var lastPm25CheckStateOut: Int = 0
    private var lastPm25LevelIn: Int = 0
    private var lastPm25LevelOut: Int = 0
    private var lastPm25ValueIn: Int = 0
    private var lastPm25ValueOut: Int = 0

    fun sendPm2p5Data() {
        methodChannel?.invokeMethod("onAirQualityDataChanged", getAirQualityData())
    }

    fun getAirQualityData(): Map<String, Any?> {
        return mapOf<String, Any?>(
            "pm25OnlineState" to (pm2p5Device?.getPM2p5OnlineState() ?: lastPm25OnlineState),
            "pm25CheckStateIn" to (pm2p5Device?.getPM2p5CheckState()?.getOrNull(0) ?: lastPm25CheckStateIn),
            "pm25CheckStateOut" to (pm2p5Device?.getPM2p5CheckState()?.getOrNull(1) ?: lastPm25CheckStateOut),
            "pm25LevelIn" to (pm2p5Device?.getPM2p5Level()?.getOrNull(0) ?: lastPm25LevelIn),
            "pm25LevelOut" to (pm2p5Device?.getPM2p5Level()?.getOrNull(1) ?: lastPm25LevelOut),
            "pm25ValueIn" to (pm2p5Device?.getPM2p5Value()?.getOrNull(0) ?: lastPm25ValueIn),
            "pm25ValueOut" to (pm2p5Device?.getPM2p5Value()?.getOrNull(1) ?: lastPm25ValueOut)
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

    fun getChargeData(): Map<String, Any?> {
        return mapOf<String, Any?>(
            "chargerFaultState" to (chargeDevice?.getChargerFaultState() ?: lastChargerFaultState),
            "chargerWorkState" to (chargeDevice?.getChargerWorkState() ?: lastChargerWorkState),
            "chargingCapacity" to (chargeDevice?.getChargingCapacity() ?: lastChargingCapacity),
            "chargingType" to (chargeDevice?.getChargingType() ?: lastChargingType),
            "chargingRestTimeHour" to (chargeDevice?.getChargingRestTime()?.getOrNull(0) ?: lastChargingRestTimeHour),
            "chargingRestTimeMinute" to (chargeDevice?.getChargingRestTime()?.getOrNull(1) ?: lastChargingRestTimeMinute),
            "chargingCapStateAc" to (chargeDevice?.getChargingCapState(0) ?: lastChargingCapStateAc),
            "chargingCapStateDc" to (chargeDevice?.getChargingCapState(1) ?: lastChargingCapStateDc),
            "chargingPortLockRebackState" to (chargeDevice?.getChargingPortLockRebackState() ?: lastChargingPortLockRebackState),
            "dischargeRequestState" to (chargeDevice?.getDischargeRequestState() ?: lastDischargeRequestState),
            "chargerState" to (chargeDevice?.getChargerState() ?: lastChargerState),
            "chargingGunState" to (chargeDevice?.getChargingGunState() ?: lastChargingGunState),
            "chargingPower" to (chargeDevice?.getChargingPower() ?: lastChargingPower),
            "batteryManagementDeviceState" to (chargeDevice?.getBatteryManagementDeviceState() ?: lastBatteryManagementDeviceState),
            "chargingScheduleEnableState" to (chargeDevice?.getChargingScheduleEnableState() ?: lastChargingScheduleEnableState),
            "chargingScheduleState" to (chargeDevice?.getChargingScheduleState() ?: lastChargingScheduleState),
            "chargingGunNotInsertedState" to (chargeDevice?.getChargingGunNotInsertedState() ?: lastChargingGunNotInsertedState),
            "chargingScheduleTimeHour" to (chargeDevice?.getChargingScheduleTime()?.getOrNull(0) ?: lastChargingScheduleTimeHour),
            "chargingScheduleTimeMinute" to (chargeDevice?.getChargingScheduleTime()?.getOrNull(1) ?: lastChargingScheduleTimeMinute)
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
        return mapOf<String, Any?>(
            "mediaType" to (mediaDevice?.getMediaType() ?: lastMediaType),
            "playMode" to (mediaDevice?.getPlayMode() ?: lastPlayMode),
            "playState" to (mediaDevice?.getPlayState() ?: lastPlayState),
            "fileName" to (mediaDevice?.getPlayMediaInfo()?.fileName ?: lastFileName),
            "artistName" to (mediaDevice?.getPlayMediaInfo()?.artistName ?: lastArtistName),
            "albumName" to (mediaDevice?.getPlayMediaInfo()?.albumName ?: lastAlbumName)
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
                sendCarData(buildCarData())
            }
            success
        } catch (e: Exception) {
            sendCarLog("设置媒体中心数据失败: ${e.message}")
            false
        }
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
    private var lastSteeringWheelAngle: Double = 0.0
    private var lastSteeringWheelSpeed: Double = 0.0
    private var lastFuelElecLowPower: Int = 0
    private var lastAlarmState: Int = 0
    private var lastMoonRoofConfig: Int = 0

    fun getBodyStatusData(): Map<String, Any?> {
        return mapOf<String, Any?>(
            "autoVIN" to (bodyStatusDevice?.getAutoVIN() ?: lastAutoVIN),
            "autoModelName" to (bodyStatusDevice?.getAutoModelName() ?: lastAutoModelName),
            "autoSystemState" to (bodyStatusDevice?.getAutoSystemState() ?: lastAutoSystemState),
            "doorStateLf" to (bodyStatusDevice?.getDoorState(BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_LEFT_FRONT) ?: lastDoorStateLf),
            "doorStateRf" to (bodyStatusDevice?.getDoorState(BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_RIGHT_FRONT) ?: lastDoorStateRf),
            "doorStateLr" to (bodyStatusDevice?.getDoorState(BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_LEFT_REAR) ?: lastDoorStateLr),
            "doorStateRr" to (bodyStatusDevice?.getDoorState(BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_RIGHT_REAR) ?: lastDoorStateRr),
            "doorStateHood" to (bodyStatusDevice?.getDoorState(BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_HOOD) ?: lastDoorStateHood),
            "doorStateLuggage" to (bodyStatusDevice?.getDoorState(BYDAutoBodyworkDevice.BODYWORK_CMD_DOOR_LUGGAGE_DOOR) ?: lastDoorStateLuggage),
            "windowStateLf" to (bodyStatusDevice?.getWindowState(BYDAutoBodyworkDevice.BODYWORK_CMD_WINDOW_LEFT_FRONT) ?: lastWindowStateLf),
            "windowStateRf" to (bodyStatusDevice?.getWindowState(BYDAutoBodyworkDevice.BODYWORK_CMD_WINDOW_RIGHT_FRONT) ?: lastWindowStateRf),
            "windowStateLr" to (bodyStatusDevice?.getWindowState(BYDAutoBodyworkDevice.BODYWORK_CMD_WINDOW_LEFT_REAR) ?: lastWindowStateLr),
            "windowStateRr" to (bodyStatusDevice?.getWindowState(BYDAutoBodyworkDevice.BODYWORK_CMD_WINDOW_RIGHT_REAR) ?: lastWindowStateRr),
            "moonRoofPercent" to (bodyStatusDevice?.getWindowOpenPercent(BYDAutoBodyworkDevice.BODYWORK_CMD_MOON_ROOF) ?: lastMoonRoofPercent),
            "sunshadePercent" to (bodyStatusDevice?.getWindowOpenPercent(BYDAutoBodyworkDevice.BODYWORK_CMD_SUNSHADE_PANEL) ?: lastSunshadePercent),
            "batteryVoltageLevel" to (bodyStatusDevice?.getBatteryVoltageLevel() ?: lastBatteryVoltageLevel),
            "powerLevel" to (bodyStatusDevice?.getPowerLevel() ?: lastPowerLevel),
            "steeringWheelAngle" to (bodyStatusDevice?.getSteeringWheelValue(BYDAutoBodyworkDevice.BODYWORK_CMD_STEERING_WHEEL_ANGEL) ?: lastSteeringWheelAngle),
            "steeringWheelSpeed" to (bodyStatusDevice?.getSteeringWheelValue(BYDAutoBodyworkDevice.BODYWORK_CMD_STEERING_WHEEL_SPEED) ?: lastSteeringWheelSpeed),
            "fuelElecLowPower" to (bodyStatusDevice?.getFuelElecLowPower() ?: lastFuelElecLowPower),
            "alarmState" to (bodyStatusDevice?.getAlarmState() ?: lastAlarmState),
            "moonRoofConfig" to (bodyStatusDevice?.getMoonRoofConfig() ?: lastMoonRoofConfig)
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
        return mapOf<String, Any?>(
            "lightAutoStatus" to (lightDevice?.getLightAutoStatus() ?: lastLightAutoStatus),
            "lightSide" to (lightDevice?.getLightStatus(BYDAutoLightDevice.LIGHT_SIDE) ?: lastLightSide),
            "lightLowBeam" to (lightDevice?.getLightStatus(BYDAutoLightDevice.LIGHT_LOW_BEAM) ?: lastLightLowBeam),
            "lightHighBeam" to (lightDevice?.getLightStatus(BYDAutoLightDevice.LIGHT_HIGH_BEAM) ?: lastLightHighBeam),
            "lightLeftTurnSignal" to (lightDevice?.getLightStatus(BYDAutoLightDevice.LIGHT_LEFT_TURN_SIGNAL) ?: lastLightLeftTurnSignal),
            "lightRightTurnSignal" to (lightDevice?.getLightStatus(BYDAutoLightDevice.LIGHT_RIGHT_TURN_SIGNAL) ?: lastLightRightTurnSignal),
            "lightFrontFog" to (lightDevice?.getLightStatus(BYDAutoLightDevice.LIGHT_FRONT_FOG) ?: lastLightFrontFog),
            "lightRearFog" to (lightDevice?.getLightStatus(BYDAutoLightDevice.LIGHT_REAR_FOG) ?: lastLightRearFog),
            "lightFoot" to (lightDevice?.getLightStatus(BYDAutoLightDevice.LIGHT_FOOT) ?: lastLightFoot),
            "afsSwitch" to (lightDevice?.getAFSSwitch() ?: lastAfsSwitch)
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