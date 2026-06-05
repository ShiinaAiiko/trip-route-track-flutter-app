package club.aiiko.trip

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * 车机数据测试模拟服务
 * 独立于 BYDAutoVehicleService，用于在非真实设备环境下模拟车机数据
 */
class TestBYDAutoVehicleService(private val methodChannel: MethodChannel?) {
    
    private var isTestRunning = false
    private var testHandler: Handler? = null
    private var testRunnable: Runnable? = null
    
    private var logCallback: ((String) -> Unit)? = null
    private var lastSendTime = 0L
    private var debounceDelayMs = 100
    
    // 测试数据变量
    private var testSpeed: Double = 60.0
    private var testAccelerateDepth: Int = 0
    private var testBrakeDepth: Int = 0
    private var testFuelPercentage: Int = 75
    private var testBatteryLevel: Int = 65
    private var testTotalMileage: Int = 39389
    private var testTyrePressureLf: Int = 230
    private var testTyrePressureRf: Int = 230
    private var testTyrePressureLr: Int = 230
    private var testTyrePressureRr: Int = 230
    private var testTemperatureMain: Int = 24
    private var testTemperatureOut: Int = 28
    private var testAcStartState: Int = 1
    private var testAcWindLevel: Int = 2
    private var testAcWindMode: Int = 0
    private var testRadarLf: Int = 150
    private var testRadarRf: Int = 150
    private var testRadarLr: Int = 180
    private var testRadarRr: Int = 180
    private var testPm25Value: Int = 35
    private var testSteeringWheelAngle: Double = 0.0
    private var testMoonRoofPercent: Int = 0
    private var testTimeHour: Int = 14
    private var testTimeMinute: Int = 30
    
    // 完整测试数据变量
    private var testDrivingTime: Double = 0.0
    private var testElecDrivingRange: Int = 300
    private var testFuelDrivingRange: Int = 400
    private var testLastElecConPHM: Double = 12.5
    private var testLastFuelConPHM: Double = 6.5
    private var testTotalElecConPHM: Double = 4500.0
    private var testTotalFuelConPHM: Double = 2800.0
    private var testTotalFuelCon: Double = 150.0
    private var testTotalElecCon: Double = 320.0
    private var testKeyBatteryLevel: Int = 75
    private var testEvMileage: Int = 12000
    private var testMalfunctionInfo: String? = null
    private var testAlarmBuzzleState: Int = 0
    private var testTemperatureUnit: Int = 0
    private var testPressureUnit: Int = 0
    private var testFuelConsumptionUnit: Int = 0
    private var testPowerUnit: Int = 0
    private var testMaintenanceInfo: String? = null
    private var testExternalChargingPower: Double = 0.0
    private var testDoorLockLeftFront: Int = 1
    private var testDoorLockLeftRear: Int = 1
    private var testDoorLockRightFront: Int = 1
    private var testDoorLockRightRear: Int = 1
    private var testDoorLockBack: Int = 1
    private var testDoorLockChildlockLeft: Int = 0
    private var testDoorLockChildlockRight: Int = 0
    private var testAcBTWind: Int = 0
    private var testAcTunnelCycle: Int = 0
    private var testAcPauseCycle: Int = 0
    private var testAcAutoAir: Int = 1
    private var testPm25Power: Int = 0
    private var testPm25SwitchCheck: Int = 1
    private var testPm25TimeCheck: Int = 0
    private var testEnergyFeedback: Int = 1
    private var testSocTarget: Int = 80
    private var testChargingPort: Int = 0
    private var testAutoExternalRearMirrorFollowUp: Int = 1
    private var testLockOff: Int = 0
    private var testLanguage: Int = 0
    private var testOverspeedLock: Int = 120
    private var testSafeWarnState: Int = 0
    private var testMaintainRemindState: Int = 0
    private var testSteerAssis: Int = 1
    private var testRearViewMirrorFlip: Int = 0
    private var testDriverSeatAutoReturn: Int = 1
    private var testSteerPositionAutoReturn: Int = 1
    private var testRemoteControlUpwindowState: Int = 0
    private var testRemoteControlDownwindowState: Int = 0
    private var testLockCarRiseWindow: Int = 1
    private var testMicroSwitchLockWindowState: Int = 0
    private var testMicroSwitchUnlockWindowState: Int = 0
    private var testBackHomeLightDelayValue: Int = 30
    private var testLeftHomeLightDelayValue: Int = 30
    private var testBackDoorElectricMode: Int = 0
    private var testEngineDisplacement: Int = 1500
    private var testEngineCode: String? = null
    private var testEnginePower: Int = 110
    private var testEngineSpeed: Int = 2000
    private var testEngineCoolantLevel: Int = 70
    private var testOilLevel: Int = 60
    private var testPanoOutputSignal: Int = 0
    private var testPanoWorkState: Int = 0
    private var testBackLineConfig: Int = 0
    private var testPanoOutputState: Int = 0
    private var testPanoRotation: Int = 0
    private var testDisplayMode: Int = 0
    private var testPanoramaOnlineState: Int = 0
    private var testAcCompressorMode: Int = 0
    private var testAcCompressorManualSign: Int = 0
    private var testAcWindLevelManualSign: Int = 0
    private var testAcWindModeManualSign: Int = 0
    private var testAcControlMode: Int = 0
    private var testAcCycleMode: Int = 0
    private var testAcDefrostStateFront: Int = 0
    private var testAcDefrostStateRear: Int = 0
    private var testAcTemperatureDeputy: Int = 24
    private var testAcTemperatureRear: Int = 24
    private var testAcTemperatureControlMode: Int = 0
    private var testAcVentilationState: Int = 0
    private var testRearAcStartState: Int = 0
    private var testLightIntensity: Int = 80
    private var testYear: Int = 2025
    private var testMonth: Int = 12
    private var testDay: Int = 25
    private var testSecond: Int = 0
    private var testTimeFormat: Int = 0
    private var testEnergyMode: Int = 1
    private var testOperationMode: Int = 0
    private var testPowerGenerationState: Int = 0
    private var testPowerGenerationValue: Int = 0
    private var testRoadSurfaceMode: Int = 0
    private var testRadarLeft: Int = 0
    private var testRadarRight: Int = 0
    private var testRadarFrontLeftMid: Int = 200
    private var testRadarFrontRightMid: Int = 200
    private var testReverseRadarSwitch: Int = 1
    private var testTyreAirLeakStateLf: Int = 0
    private var testTyreAirLeakStateRf: Int = 0
    private var testTyreAirLeakStateLr: Int = 0
    private var testTyreAirLeakStateRr: Int = 0
    private var testTyreBatteryState: Int = 1
    private var testTyreSystemState: Int = 0
    private var testTyreTemperatureState: Int = 1
    private var testTyreSignalStateLf: Int = 1
    private var testTyreSignalStateRf: Int = 1
    private var testTyreSignalStateLr: Int = 1
    private var testTyreSignalStateRr: Int = 1
    private var testPm25OnlineState: Int = 1
    private var testPm25CheckStateIn: Int = 0
    private var testPm25CheckStateOut: Int = 0
    private var testPm25LevelIn: Int = 2
    private var testPm25LevelOut: Int = 3
    private var testChargerFaultState: Int = 0
    private var testChargerWorkState: Int = 0
    private var testChargingCapacity: Double = 55.0
    private var testChargingType: Int = 0
    private var testChargingRestTimeHour: Int = 2
    private var testChargingRestTimeMinute: Int = 30
    private var testChargingCapStateAc: Int = 0
    private var testChargingCapStateDc: Int = 0
    private var testChargingPortLockRebackState: Int = 0
    private var testDischargeRequestState: Int = 0
    private var testChargerState: Int = 0
    private var testChargingGunState: Int = 0
    private var testChargingPower: Int = 0
    private var testBatteryManagementDeviceState: Int = 0
    private var testChargingScheduleEnableState: Int = 0
    private var testChargingScheduleState: Int = 0
    private var testChargingGunNotInsertedState: Int = 1
    private var testChargingScheduleTimeHour: Int = 22
    private var testChargingScheduleTimeMinute: Int = 0
    private var testMediaType: Int = 0
    private var testPlayMode: Int = 0
    private var testPlayState: Int = 0
    private var testFileName: String? = "test.mp3"
    private var testArtistName: String? = "Artist"
    private var testAlbumName: String? = "Album"
    private var testAutoVIN: String? = "VIN123456789"
    private var testAutoModelName: String? = "Model X"
    private var testAutoSystemState: Int = 0
    private var testDoorStateLf: Int = 0
    private var testDoorStateRf: Int = 0
    private var testDoorStateLr: Int = 0
    private var testDoorStateRr: Int = 0
    private var testDoorStateHood: Int = 0
    private var testDoorStateLuggage: Int = 0
    private var testWindowStateLf: Int = 100
    private var testWindowStateRf: Int = 100
    private var testWindowStateLr: Int = 100
    private var testWindowStateRr: Int = 100
    private var testSunshadePercent: Int = 0
    private var testBatteryVoltageLevel: Int = 12
    private var testPowerLevel: Int = 80
    private var testSteeringWheelSpeed: Double = 0.0
    private var testFuelElecLowPower: Int = 0
    private var testAlarmState: Int = 0
    private var testMoonRoofConfig: Int = 0
    private var testLightAutoStatus: Int = 1
    private var testLightSide: Int = 0
    private var testLightLowBeam: Int = 0
    private var testLightHighBeam: Int = 0
    private var testLightLeftTurnSignal: Int = 0
    private var testLightRightTurnSignal: Int = 0
    private var testLightFrontFog: Int = 0
    private var testLightRearFog: Int = 0
    private var testLightFoot: Int = 0
    private var testAfsSwitch: Int = 0
    
    fun setLogCallback(callback: (String) -> Unit) {
        logCallback = callback
    }
    
    fun testCarData(enabled: Boolean) {
        if (enabled) {
            startTestSimulation()
        } else {
            stopTestSimulation()
        }
    }
    
    fun setCarDataListenerDebounceDelay(delayMs: Int) {
        debounceDelayMs = delayMs
        sendLog("testCarData: 车机数据防抖延迟设置为: ${delayMs}ms")
    }
    
    fun isRunning(): Boolean = isTestRunning
    
    private fun sendLog(log: String) {
        logCallback?.invoke(log)
        Log.d("TestBYDAutoVehicleService", log)
    }
    
    private fun startTestSimulation() {
        if (isTestRunning) {
            sendLog("testCarData: 测试已在运行中，忽略重复启动")
            return
        }
        
        isTestRunning = true
        sendLog("testCarData: 启动车机数据模拟测试")
        sendLog("testCarData: 模拟高频数据变化 - 每100ms更新一次")
        
        testHandler = Handler(Looper.getMainLooper())
        testRunnable = object : Runnable {
            override fun run() {
                if (!isTestRunning) return
                
                // 模拟数据变化
                simulateTestDataChanges()
                
                // 发送完整车机数据
                sendTestCarData()
                
                // 每100ms更新一次
                testHandler?.postDelayed(this, 100)
            }
        }
        testHandler?.post(testRunnable!!)
    }
    
    private fun stopTestSimulation() {
        if (!isTestRunning) {
            sendLog("testCarData: 测试未在运行，忽略停止请求")
            return
        }
        
        isTestRunning = false
        testRunnable?.let { testHandler?.removeCallbacks(it) }
        testHandler = null
        testRunnable = null
        sendLog("testCarData: 停止车机数据模拟测试")
    }
    
    private fun simulateTestDataChanges() {
        // 车速变化 (0-120 km/h 波动)
        testSpeed = (testSpeed + (Math.random() * 10 - 5)).coerceIn(0.0, 120.0)
        
        // 加速深度变化 (0-100)
        testAccelerateDepth = (testAccelerateDepth + (Math.random() * 20 - 10).toInt()).coerceIn(0, 100)
        
        // 刹车深度变化 (0-100)
        testBrakeDepth = if (testAccelerateDepth > 50) 0 else (Math.random() * 30).toInt()
        
        // 总里程 (持续增加)
        testTotalMileage = (testTotalMileage + 0.01).toInt()
        
        // 电池电量波动
        if (Math.random() > 0.9) {
            testBatteryLevel = (testBatteryLevel + (if (Math.random() > 0.5) 1 else -1)).coerceIn(0, 100)
        }
        
        // 油耗波动
        if (Math.random() > 0.8) {
            testFuelPercentage = (testFuelPercentage + (Math.random() * 4 - 2).toInt()).coerceIn(0, 100)
        }
        
        // 轮胎压力微小波动
        testTyrePressureLf = (testTyrePressureLf + (Math.random() * 2 - 1).toInt()).coerceIn(200, 260)
        testTyrePressureRf = (testTyrePressureRf + (Math.random() * 2 - 1).toInt()).coerceIn(200, 260)
        testTyrePressureLr = (testTyrePressureLr + (Math.random() * 2 - 1).toInt()).coerceIn(200, 260)
        testTyrePressureRr = (testTyrePressureRr + (Math.random() * 2 - 1).toInt()).coerceIn(200, 260)
        
        // 空调温度微调
        if (Math.random() > 0.7) {
            testTemperatureMain = (testTemperatureMain + (if (Math.random() > 0.5) 1 else -1)).coerceIn(16, 32)
        }
        
        // 雷达距离变化
        testRadarLf = (testRadarLf + (Math.random() * 20 - 10).toInt()).coerceIn(50, 500)
        testRadarRf = (testRadarRf + (Math.random() * 20 - 10).toInt()).coerceIn(50, 500)
        testRadarLr = (testRadarLr + (Math.random() * 20 - 10).toInt()).coerceIn(50, 500)
        testRadarRr = (testRadarRr + (Math.random() * 20 - 10).toInt()).coerceIn(50, 500)
        
        // PM2.5波动
        testPm25Value = (testPm25Value + (Math.random() * 10 - 5).toInt()).coerceIn(0, 500)
        
        // 时间变化
        testTimeMinute = (testTimeMinute + 1) % 60
        if (testTimeMinute == 0) {
            testTimeHour = (testTimeHour + 1) % 24
        }
        
        // 方向盘角度
        testSteeringWheelAngle = if (testSpeed > 10) {
            (testSteeringWheelAngle + (Math.random() * 60 - 30)).coerceIn(-720.0, 720.0)
        } else {
            testSteeringWheelAngle * 0.9
        }
    }
    
    private fun sendTestCarData() {
        if (debounceDelayMs > 0) {
            val currentTime = System.currentTimeMillis()
            if (currentTime - lastSendTime < debounceDelayMs) {
                sendLog("testCarData: 防抖机制，距离上次发送不足${debounceDelayMs}ms，跳过")
                return
            }
            lastSendTime = currentTime
        }
        val carData = buildTestCarData()
        try {
            val jsonString = JSONObject(carData).toString()
            methodChannel?.invokeMethod("onCarDataChanged", jsonString)
            sendLog("testCarData: 发送测试数据，长度=${jsonString.length}")
        } catch (e: Exception) {
            sendLog("testCarData: 发送测试数据失败: ${e.message}")
        }
    }
    
    private fun buildTestCarData(): Map<String, Any?> {
        return mapOf(
            "speed" to mapOf(
                "currentSpeed" to testSpeed,
                "accelerateDeepness" to testAccelerateDepth,
                "brakeDeepness" to testBrakeDepth
            ),
            "statistic" to mapOf(
                "drivingTime" to testDrivingTime,
                "elecDrivingRange" to testElecDrivingRange,
                "elecPercentage" to testBatteryLevel.toDouble(),
                "fuelDrivingRange" to testFuelDrivingRange,
                "fuelPercentage" to testFuelPercentage,
                "lastElecConPHM" to testLastElecConPHM,
                "lastFuelConPHM" to testLastFuelConPHM,
                "totalElecConPHM" to testTotalElecConPHM,
                "totalFuelConPHM" to testTotalFuelConPHM,
                "totalFuelCon" to testTotalFuelCon,
                "totalElecCon" to testTotalElecCon,
                "totalMileage" to testTotalMileage,
                "keyBatteryLevel" to testKeyBatteryLevel,
                "evMileage" to testEvMileage
            ),
            "instrument" to mapOf(
                "malfunctionInfo" to testMalfunctionInfo,
                "alarmBuzzleState" to testAlarmBuzzleState,
                "unit" to mapOf(
                    "temperature" to testTemperatureUnit,
                    "pressure" to testPressureUnit,
                    "fuelConsumption" to testFuelConsumptionUnit,
                    "power" to testPowerUnit
                ),
                "maintenanceInfo" to testMaintenanceInfo,
                "externalChargingPower" to testExternalChargingPower
            ),
            "door" to mapOf(
                "leftFront" to testDoorLockLeftFront,
                "leftRear" to testDoorLockLeftRear,
                "rightFront" to testDoorLockRightFront,
                "rightRear" to testDoorLockRightRear,
                "back" to testDoorLockBack,
                "childlockLeft" to testDoorLockChildlockLeft,
                "childlockRight" to testDoorLockChildlockRight
            ),
            "vehicleSetting" to mapOf(
                "acBTWind" to testAcBTWind,
                "acTunnelCycle" to testAcTunnelCycle,
                "acPauseCycle" to testAcPauseCycle,
                "acAutoAir" to testAcAutoAir,
                "pm25Power" to testPm25Power,
                "pm25SwitchCheck" to testPm25SwitchCheck,
                "pm25TimeCheck" to testPm25TimeCheck,
                "energyFeedback" to testEnergyFeedback,
                "socTarget" to testSocTarget,
                "chargingPort" to testChargingPort,
                "autoExternalRearMirrorFollowUp" to testAutoExternalRearMirrorFollowUp,
                "lockOff" to testLockOff,
                "language" to testLanguage,
                "overspeedLock" to testOverspeedLock,
                "safeWarnState" to testSafeWarnState,
                "maintainRemindState" to testMaintainRemindState,
                "steerAssis" to testSteerAssis,
                "rearViewMirrorFlip" to testRearViewMirrorFlip,
                "driverSeatAutoReturn" to testDriverSeatAutoReturn,
                "steerPositionAutoReturn" to testSteerPositionAutoReturn,
                "remoteControlUpwindowState" to testRemoteControlUpwindowState,
                "remoteControlDownwindowState" to testRemoteControlDownwindowState,
                "lockCarRiseWindow" to testLockCarRiseWindow,
                "microSwitchLockWindowState" to testMicroSwitchLockWindowState,
                "microSwitchUnlockWindowState" to testMicroSwitchUnlockWindowState,
                "backHomeLightDelayValue" to testBackHomeLightDelayValue,
                "leftHomeLightDelayValue" to testLeftHomeLightDelayValue,
                "backDoorElectricMode" to testBackDoorElectricMode
            ),
            "engine" to mapOf(
                "engineDisplacement" to testEngineDisplacement,
                "engineCode" to testEngineCode,
                "enginePower" to testEnginePower,
                "engineSpeed" to testEngineSpeed,
                "engineCoolantLevel" to testEngineCoolantLevel,
                "oilLevel" to testOilLevel
            ),
            "panorama" to mapOf(
                "panoOutputSignal" to testPanoOutputSignal,
                "panoWorkState" to testPanoWorkState,
                "backLineConfig" to testBackLineConfig,
                "panoOutputState" to testPanoOutputState,
                "panoRotation" to testPanoRotation,
                "displayMode" to testDisplayMode,
                "panoramaOnlineState" to testPanoramaOnlineState
            ),
            "ac" to mapOf(
                "acCompressorMode" to testAcCompressorMode,
                "acCompressorManualSign" to testAcCompressorManualSign,
                "acWindLevelManualSign" to testAcWindLevelManualSign,
                "acWindModeManualSign" to testAcWindModeManualSign,
                "acStartState" to testAcStartState,
                "acControlMode" to testAcControlMode,
                "acCycleMode" to testAcCycleMode,
                "acWindMode" to testAcWindMode,
                "acDefrostStateFront" to testAcDefrostStateFront,
                "acDefrostStateRear" to testAcDefrostStateRear,
                "acWindLevel" to testAcWindLevel,
                "acTemperatureMain" to testTemperatureMain,
                "acTemperatureDeputy" to testAcTemperatureDeputy,
                "acTemperatureRear" to testAcTemperatureRear,
                "acTemperatureOut" to testTemperatureOut,
                "temperatureUnit" to testTemperatureUnit,
                "acTemperatureControlMode" to testAcTemperatureControlMode,
                "acVentilationState" to testAcVentilationState,
                "rearAcStartState" to testRearAcStartState
            ),
            "sensor" to mapOf(
                "lightIntensity" to testLightIntensity
            ),
            "time" to mapOf(
                "year" to testYear,
                "month" to testMonth,
                "day" to testDay,
                "hour" to testTimeHour,
                "minute" to testTimeMinute,
                "second" to testSecond,
                "timeFormat" to testTimeFormat
            ),
            "energyMode" to mapOf(
                "energyMode" to testEnergyMode,
                "operationMode" to testOperationMode,
                "powerGenerationState" to testPowerGenerationState,
                "powerGenerationValue" to testPowerGenerationValue,
                "roadSurfaceMode" to testRoadSurfaceMode
            ),
            "radar" to mapOf(
                "leftFront" to testRadarLf,
                "rightFront" to testRadarRf,
                "leftRear" to testRadarLr,
                "rightRear" to testRadarRr,
                "left" to testRadarLeft,
                "right" to testRadarRight,
                "frontLeftMid" to testRadarFrontLeftMid,
                "frontRightMid" to testRadarFrontRightMid,
                "reverseRadarSwitch" to testReverseRadarSwitch
            ),
            "tyre" to mapOf(
                "tyrePressureLf" to testTyrePressureLf,
                "tyrePressureRf" to testTyrePressureRf,
                "tyrePressureLr" to testTyrePressureLr,
                "tyrePressureRr" to testTyrePressureRr,
                "tyreAirLeakStateLf" to testTyreAirLeakStateLf,
                "tyreAirLeakStateRf" to testTyreAirLeakStateRf,
                "tyreAirLeakStateLr" to testTyreAirLeakStateLr,
                "tyreAirLeakStateRr" to testTyreAirLeakStateRr,
                "tyreBatteryState" to testTyreBatteryState,
                "tyreSystemState" to testTyreSystemState,
                "tyreTemperatureState" to testTyreTemperatureState,
                "tyreSignalStateLf" to testTyreSignalStateLf,
                "tyreSignalStateRf" to testTyreSignalStateRf,
                "tyreSignalStateLr" to testTyreSignalStateLr,
                "tyreSignalStateRr" to testTyreSignalStateRr
            ),
            "airQuality" to mapOf(
                "pm25OnlineState" to testPm25OnlineState,
                "pm25CheckStateIn" to testPm25CheckStateIn,
                "pm25CheckStateOut" to testPm25CheckStateOut,
                "pm25LevelIn" to testPm25LevelIn,
                "pm25LevelOut" to testPm25LevelOut,
                "pm25ValueIn" to testPm25Value,
                "pm25ValueOut" to testPm25Value
            ),
            "charge" to mapOf(
                "chargerFaultState" to testChargerFaultState,
                "chargerWorkState" to testChargerWorkState,
                "chargingCapacity" to testChargingCapacity,
                "chargingType" to testChargingType,
                "chargingRestTimeHour" to testChargingRestTimeHour,
                "chargingRestTimeMinute" to testChargingRestTimeMinute,
                "chargingCapStateAc" to testChargingCapStateAc,
                "chargingCapStateDc" to testChargingCapStateDc,
                "chargingPortLockRebackState" to testChargingPortLockRebackState,
                "dischargeRequestState" to testDischargeRequestState,
                "chargerState" to testChargerState,
                "chargingGunState" to testChargingGunState,
                "chargingPower" to testChargingPower,
                "batteryManagementDeviceState" to testBatteryManagementDeviceState,
                "chargingScheduleEnableState" to testChargingScheduleEnableState,
                "chargingScheduleState" to testChargingScheduleState,
                "chargingGunNotInsertedState" to testChargingGunNotInsertedState,
                "chargingScheduleTimeHour" to testChargingScheduleTimeHour,
                "chargingScheduleTimeMinute" to testChargingScheduleTimeMinute
            ),
            "media" to mapOf(
                "mediaType" to testMediaType,
                "playMode" to testPlayMode,
                "playState" to testPlayState,
                "fileName" to testFileName,
                "artistName" to testArtistName,
                "albumName" to testAlbumName
            ),
            "bodyStatus" to mapOf(
                "autoVIN" to testAutoVIN,
                "autoModelName" to testAutoModelName,
                "autoSystemState" to testAutoSystemState,
                "doorStateLf" to testDoorStateLf,
                "doorStateRf" to testDoorStateRf,
                "doorStateLr" to testDoorStateLr,
                "doorStateRr" to testDoorStateRr,
                "doorStateHood" to testDoorStateHood,
                "doorStateLuggage" to testDoorStateLuggage,
                "windowStateLf" to testWindowStateLf,
                "windowStateRf" to testWindowStateRf,
                "windowStateLr" to testWindowStateLr,
                "windowStateRr" to testWindowStateRr,
                "moonRoofPercent" to testMoonRoofPercent,
                "sunshadePercent" to testSunshadePercent,
                "batteryVoltageLevel" to testBatteryVoltageLevel,
                "powerLevel" to testPowerLevel,
                "steeringWheelAngle" to testSteeringWheelAngle,
                "steeringWheelSpeed" to testSteeringWheelSpeed,
                "fuelElecLowPower" to testFuelElecLowPower,
                "alarmState" to testAlarmState,
                "moonRoofConfig" to testMoonRoofConfig
            ),
            "light" to mapOf(
                "lightAutoStatus" to testLightAutoStatus,
                "lightSide" to testLightSide,
                "lightLowBeam" to testLightLowBeam,
                "lightHighBeam" to testLightHighBeam,
                "lightLeftTurnSignal" to testLightLeftTurnSignal,
                "lightRightTurnSignal" to testLightRightTurnSignal,
                "lightFrontFog" to testLightFrontFog,
                "lightRearFog" to testLightRearFog,
                "lightFoot" to testLightFoot,
                "afsSwitch" to testAfsSwitch
            ),
            "timestamp" to System.currentTimeMillis()
        )
    }
}
