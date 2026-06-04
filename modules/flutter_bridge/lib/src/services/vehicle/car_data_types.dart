class TyrePressure {
  final int leftFront;
  final int rightFront;
  final int leftRear;
  final int rightRear;

  TyrePressure({
    required this.leftFront,
    required this.rightFront,
    required this.leftRear,
    required this.rightRear,
  });

  Map<String, dynamic> toJson() {
    return {
      'leftFront': leftFront,
      'rightFront': rightFront,
      'leftRear': leftRear,
      'rightRear': rightRear,
    };
  }

  factory TyrePressure.fromJson(Map<String, dynamic> json) {
    return TyrePressure(
      leftFront: json['leftFront'] ?? 0,
      rightFront: json['rightFront'] ?? 0,
      leftRear: json['leftRear'] ?? 0,
      rightRear: json['rightRear'] ?? 0,
    );
  }
}

class SpeedData {
  final double currentSpeed;
  final int accelerateDeepness;
  final int brakeDeepness;

  SpeedData({
    required this.currentSpeed,
    required this.accelerateDeepness,
    required this.brakeDeepness,
  });

  Map<String, dynamic> toJson() {
    return {
      'currentSpeed': currentSpeed,
      'accelerateDeepness': accelerateDeepness,
      'brakeDeepness': brakeDeepness,
    };
  }

  factory SpeedData.fromJson(Map<String, dynamic> json) {
    return SpeedData(
      currentSpeed: (json['currentSpeed'] ?? 0.0) as double,
      accelerateDeepness: json['accelerateDeepness'] ?? 0,
      brakeDeepness: json['brakeDeepness'] ?? 0,
    );
  }
}

class StatisticData {
  final double drivingTime;
  final int elecDrivingRange;
  final double elecPercentage;
  final int fuelDrivingRange;
  final int fuelPercentage;
  final double lastElecConPHM;
  final double lastFuelConPHM;
  final double totalElecConPHM;
  final double totalFuelConPHM;
  final double totalFuelCon;
  final double totalElecCon;
  final int totalMileage;
  final int keyBatteryLevel;
  final int evMileage;

  StatisticData({
    required this.drivingTime,
    required this.elecDrivingRange,
    required this.elecPercentage,
    required this.fuelDrivingRange,
    required this.fuelPercentage,
    required this.lastElecConPHM,
    required this.lastFuelConPHM,
    required this.totalElecConPHM,
    required this.totalFuelConPHM,
    required this.totalFuelCon,
    required this.totalElecCon,
    required this.totalMileage,
    required this.keyBatteryLevel,
    required this.evMileage,
  });

  Map<String, dynamic> toJson() {
    return {
      'drivingTime': drivingTime,
      'elecDrivingRange': elecDrivingRange,
      'elecPercentage': elecPercentage,
      'fuelDrivingRange': fuelDrivingRange,
      'fuelPercentage': fuelPercentage,
      'lastElecConPHM': lastElecConPHM,
      'lastFuelConPHM': lastFuelConPHM,
      'totalElecConPHM': totalElecConPHM,
      'totalFuelConPHM': totalFuelConPHM,
      'totalFuelCon': totalFuelCon,
      'totalElecCon': totalElecCon,
      'totalMileage': totalMileage,
      'keyBatteryLevel': keyBatteryLevel,
      'evMileage': evMileage,
    };
  }

  factory StatisticData.fromJson(Map<String, dynamic> json) {
    return StatisticData(
      drivingTime: (json['drivingTime'] ?? 0.0) as double,
      elecDrivingRange: json['elecDrivingRange'] ?? 0,
      elecPercentage: (json['elecPercentage'] ?? 0.0) as double,
      fuelDrivingRange: json['fuelDrivingRange'] ?? 0,
      fuelPercentage: json['fuelPercentage'] ?? 0,
      lastElecConPHM: (json['lastElecConPHM'] ?? 0.0) as double,
      lastFuelConPHM: (json['lastFuelConPHM'] ?? 0.0) as double,
      totalElecConPHM: (json['totalElecConPHM'] ?? 0.0) as double,
      totalFuelConPHM: (json['totalFuelConPHM'] ?? 0.0) as double,
      totalFuelCon: (json['totalFuelCon'] ?? 0.0) as double,
      totalElecCon: (json['totalElecCon'] ?? 0.0) as double,
      totalMileage: json['totalMileage'] ?? 0,
      keyBatteryLevel: json['keyBatteryLevel'] ?? 0,
      evMileage: json['evMileage'] ?? 0,
    );
  }
}

class InstrumentData {
  final Map<int, int> malfunctionInfo;
  final int alarmBuzzleState;
  final Map<int, int> unit;
  final Map<int, int> maintenanceInfo;
  final double externalChargingPower;

  InstrumentData({
    required this.malfunctionInfo,
    required this.alarmBuzzleState,
    required this.unit,
    required this.maintenanceInfo,
    required this.externalChargingPower,
  });

  Map<String, dynamic> toJson() {
    return {
      'malfunctionInfo': malfunctionInfo,
      'alarmBuzzleState': alarmBuzzleState,
      'unit': unit,
      'maintenanceInfo': maintenanceInfo,
      'externalChargingPower': externalChargingPower,
    };
  }

  factory InstrumentData.fromJson(Map<String, dynamic> json) {
    return InstrumentData(
      malfunctionInfo: (json['malfunctionInfo'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(int.parse(k), v as int)) ?? {},
      alarmBuzzleState: json['alarmBuzzleState'] ?? 0,
      unit: (json['unit'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(int.parse(k), v as int)) ?? {},
      maintenanceInfo: (json['maintenanceInfo'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(int.parse(k), v as int)) ?? {},
      externalChargingPower: (json['externalChargingPower'] ?? 0.0) as double,
    );
  }

  factory InstrumentData.defaultData() {
    return InstrumentData(
      malfunctionInfo: {},
      alarmBuzzleState: 0,
      unit: {},
      maintenanceInfo: {},
      externalChargingPower: 0,
    );
  }
}

class AcData {
  final int acCompressorMode;
  final int acCompressorManualSign;
  final int acWindLevelManualSign;
  final int acWindModeManualSign;
  final int acStartState;
  final int acControlMode;
  final int acCycleMode;
  final int acWindMode;
  final int acDefrostStateFront;
  final int acDefrostStateRear;
  final int acWindLevel;
  final int acTemperatureMain;
  final int acTemperatureDeputy;
  final int acTemperatureRear;
  final int acTemperatureOut;
  final int temperatureUnit;
  final int acTemperatureControlMode;
  final int acVentilationState;
  final int rearAcStartState;

  AcData({
    required this.acCompressorMode,
    required this.acCompressorManualSign,
    required this.acWindLevelManualSign,
    required this.acWindModeManualSign,
    required this.acStartState,
    required this.acControlMode,
    required this.acCycleMode,
    required this.acWindMode,
    required this.acDefrostStateFront,
    required this.acDefrostStateRear,
    required this.acWindLevel,
    required this.acTemperatureMain,
    required this.acTemperatureDeputy,
    required this.acTemperatureRear,
    required this.acTemperatureOut,
    required this.temperatureUnit,
    required this.acTemperatureControlMode,
    required this.acVentilationState,
    required this.rearAcStartState,
  });

  Map<String, dynamic> toJson() {
    return {
      'acCompressorMode': acCompressorMode,
      'acCompressorManualSign': acCompressorManualSign,
      'acWindLevelManualSign': acWindLevelManualSign,
      'acWindModeManualSign': acWindModeManualSign,
      'acStartState': acStartState,
      'acControlMode': acControlMode,
      'acCycleMode': acCycleMode,
      'acWindMode': acWindMode,
      'acDefrostStateFront': acDefrostStateFront,
      'acDefrostStateRear': acDefrostStateRear,
      'acWindLevel': acWindLevel,
      'acTemperatureMain': acTemperatureMain,
      'acTemperatureDeputy': acTemperatureDeputy,
      'acTemperatureRear': acTemperatureRear,
      'acTemperatureOut': acTemperatureOut,
      'temperatureUnit': temperatureUnit,
      'acTemperatureControlMode': acTemperatureControlMode,
      'acVentilationState': acVentilationState,
      'rearAcStartState': rearAcStartState,
    };
  }

  factory AcData.fromJson(Map<String, dynamic> json) {
    return AcData(
      acCompressorMode: json['acCompressorMode'] ?? 0,
      acCompressorManualSign: json['acCompressorManualSign'] ?? 0,
      acWindLevelManualSign: json['acWindLevelManualSign'] ?? 0,
      acWindModeManualSign: json['acWindModeManualSign'] ?? 0,
      acStartState: json['acStartState'] ?? 0,
      acControlMode: json['acControlMode'] ?? 0,
      acCycleMode: json['acCycleMode'] ?? 0,
      acWindMode: json['acWindMode'] ?? 0,
      acDefrostStateFront: json['acDefrostStateFront'] ?? 0,
      acDefrostStateRear: json['acDefrostStateRear'] ?? 0,
      acWindLevel: json['acWindLevel'] ?? 0,
      acTemperatureMain: json['acTemperatureMain'] ?? 0,
      acTemperatureDeputy: json['acTemperatureDeputy'] ?? 0,
      acTemperatureRear: json['acTemperatureRear'] ?? 0,
      acTemperatureOut: json['acTemperatureOut'] ?? 0,
      temperatureUnit: json['temperatureUnit'] ?? 0,
      acTemperatureControlMode: json['acTemperatureControlMode'] ?? 0,
      acVentilationState: json['acVentilationState'] ?? 0,
      rearAcStartState: json['rearAcStartState'] ?? 0,
    );
  }

  factory AcData.defaultData() {
    return AcData(
      acCompressorMode: 0,
      acCompressorManualSign: 0,
      acWindLevelManualSign: 0,
      acWindModeManualSign: 0,
      acStartState: 0,
      acControlMode: 0,
      acCycleMode: 0,
      acWindMode: 0,
      acDefrostStateFront: 0,
      acDefrostStateRear: 0,
      acWindLevel: 0,
      acTemperatureMain: 0,
      acTemperatureDeputy: 0,
      acTemperatureRear: 0,
      acTemperatureOut: 0,
      temperatureUnit: 0,
      acTemperatureControlMode: 0,
      acVentilationState: 0,
      rearAcStartState: 0,
    );
  }
}

class DoorData {
  final int leftFront;
  final int leftRear;
  final int rightFront;
  final int rightRear;
  final int back;
  final int childlockLeft;
  final int childlockRight;

  DoorData({
    required this.leftFront,
    required this.leftRear,
    required this.rightFront,
    required this.rightRear,
    required this.back,
    required this.childlockLeft,
    required this.childlockRight,
  });

  Map<String, dynamic> toJson() {
    return {
      'leftFront': leftFront,
      'leftRear': leftRear,
      'rightFront': rightFront,
      'rightRear': rightRear,
      'back': back,
      'childlockLeft': childlockLeft,
      'childlockRight': childlockRight,
    };
  }

  factory DoorData.fromJson(Map<String, dynamic> json) {
    return DoorData(
      leftFront: json['leftFront'] ?? 0,
      leftRear: json['leftRear'] ?? 0,
      rightFront: json['rightFront'] ?? 0,
      rightRear: json['rightRear'] ?? 0,
      back: json['back'] ?? 0,
      childlockLeft: json['childlockLeft'] ?? 0,
      childlockRight: json['childlockRight'] ?? 0,
    );
  }

  factory DoorData.defaultData() {
    return DoorData(
      leftFront: 0,
      leftRear: 0,
      rightFront: 0,
      rightRear: 0,
      back: 0,
      childlockLeft: 0,
      childlockRight: 0,
    );
  }
}

class VehicleSettingData {
  final int acBTWind;
  final int acTunnelCycle;
  final int acPauseCycle;
  final int acAutoAir;
  final int pm25Power;
  final int pm25SwitchCheck;
  final int pm25TimeCheck;
  final int energyFeedback;
  final int socTarget;
  final int chargingPort;
  final int autoExternalRearMirrorFollowUp;
  final int lockOff;
  final int language;
  final int overspeedLock;
  final int safeWarnState;
  final int maintainRemindState;
  final int steerAssis;
  final int rearViewMirrorFlip;
  final int driverSeatAutoReturn;
  final int steerPositionAutoReturn;
  final int remoteControlUpwindowState;
  final int remoteControlDownwindowState;
  final int lockCarRiseWindow;
  final int microSwitchLockWindowState;
  final int microSwitchUnlockWindowState;
  final int backHomeLightDelayValue;
  final int leftHomeLightDelayValue;
  final int backDoorElectricMode;

  VehicleSettingData({
    required this.acBTWind,
    required this.acTunnelCycle,
    required this.acPauseCycle,
    required this.acAutoAir,
    required this.pm25Power,
    required this.pm25SwitchCheck,
    required this.pm25TimeCheck,
    required this.energyFeedback,
    required this.socTarget,
    required this.chargingPort,
    required this.autoExternalRearMirrorFollowUp,
    required this.lockOff,
    required this.language,
    required this.overspeedLock,
    required this.safeWarnState,
    required this.maintainRemindState,
    required this.steerAssis,
    required this.rearViewMirrorFlip,
    required this.driverSeatAutoReturn,
    required this.steerPositionAutoReturn,
    required this.remoteControlUpwindowState,
    required this.remoteControlDownwindowState,
    required this.lockCarRiseWindow,
    required this.microSwitchLockWindowState,
    required this.microSwitchUnlockWindowState,
    required this.backHomeLightDelayValue,
    required this.leftHomeLightDelayValue,
    required this.backDoorElectricMode,
  });

  Map<String, dynamic> toJson() {
    return {
      'acBTWind': acBTWind,
      'acTunnelCycle': acTunnelCycle,
      'acPauseCycle': acPauseCycle,
      'acAutoAir': acAutoAir,
      'pm25Power': pm25Power,
      'pm25SwitchCheck': pm25SwitchCheck,
      'pm25TimeCheck': pm25TimeCheck,
      'energyFeedback': energyFeedback,
      'socTarget': socTarget,
      'chargingPort': chargingPort,
      'autoExternalRearMirrorFollowUp': autoExternalRearMirrorFollowUp,
      'lockOff': lockOff,
      'language': language,
      'overspeedLock': overspeedLock,
      'safeWarnState': safeWarnState,
      'maintainRemindState': maintainRemindState,
      'steerAssis': steerAssis,
      'rearViewMirrorFlip': rearViewMirrorFlip,
      'driverSeatAutoReturn': driverSeatAutoReturn,
      'steerPositionAutoReturn': steerPositionAutoReturn,
      'remoteControlUpwindowState': remoteControlUpwindowState,
      'remoteControlDownwindowState': remoteControlDownwindowState,
      'lockCarRiseWindow': lockCarRiseWindow,
      'microSwitchLockWindowState': microSwitchLockWindowState,
      'microSwitchUnlockWindowState': microSwitchUnlockWindowState,
      'backHomeLightDelayValue': backHomeLightDelayValue,
      'leftHomeLightDelayValue': leftHomeLightDelayValue,
      'backDoorElectricMode': backDoorElectricMode,
    };
  }

  factory VehicleSettingData.fromJson(Map<String, dynamic> json) {
    return VehicleSettingData(
      acBTWind: json['acBTWind'] ?? 0,
      acTunnelCycle: json['acTunnelCycle'] ?? 0,
      acPauseCycle: json['acPauseCycle'] ?? 0,
      acAutoAir: json['acAutoAir'] ?? 0,
      pm25Power: json['pm25Power'] ?? 0,
      pm25SwitchCheck: json['pm25SwitchCheck'] ?? 0,
      pm25TimeCheck: json['pm25TimeCheck'] ?? 0,
      energyFeedback: json['energyFeedback'] ?? 0,
      socTarget: json['socTarget'] ?? 0,
      chargingPort: json['chargingPort'] ?? 0,
      autoExternalRearMirrorFollowUp: json['autoExternalRearMirrorFollowUp'] ?? 0,
      lockOff: json['lockOff'] ?? 0,
      language: json['language'] ?? 0,
      overspeedLock: json['overspeedLock'] ?? 0,
      safeWarnState: json['safeWarnState'] ?? 0,
      maintainRemindState: json['maintainRemindState'] ?? 0,
      steerAssis: json['steerAssis'] ?? 0,
      rearViewMirrorFlip: json['rearViewMirrorFlip'] ?? 0,
      driverSeatAutoReturn: json['driverSeatAutoReturn'] ?? 0,
      steerPositionAutoReturn: json['steerPositionAutoReturn'] ?? 0,
      remoteControlUpwindowState: json['remoteControlUpwindowState'] ?? 0,
      remoteControlDownwindowState: json['remoteControlDownwindowState'] ?? 0,
      lockCarRiseWindow: json['lockCarRiseWindow'] ?? 0,
      microSwitchLockWindowState: json['microSwitchLockWindowState'] ?? 0,
      microSwitchUnlockWindowState: json['microSwitchUnlockWindowState'] ?? 0,
      backHomeLightDelayValue: json['backHomeLightDelayValue'] ?? 0,
      leftHomeLightDelayValue: json['leftHomeLightDelayValue'] ?? 0,
      backDoorElectricMode: json['backDoorElectricMode'] ?? 0,
    );
  }

  factory VehicleSettingData.defaultData() {
    return VehicleSettingData(
      acBTWind: 0,
      acTunnelCycle: 0,
      acPauseCycle: 0,
      acAutoAir: 0,
      pm25Power: 0,
      pm25SwitchCheck: 0,
      pm25TimeCheck: 0,
      energyFeedback: 0,
      socTarget: 0,
      chargingPort: 0,
      autoExternalRearMirrorFollowUp: 0,
      lockOff: 0,
      language: 0,
      overspeedLock: 0,
      safeWarnState: 0,
      maintainRemindState: 0,
      steerAssis: 0,
      rearViewMirrorFlip: 0,
      driverSeatAutoReturn: 0,
      steerPositionAutoReturn: 0,
      remoteControlUpwindowState: 0,
      remoteControlDownwindowState: 0,
      lockCarRiseWindow: 0,
      microSwitchLockWindowState: 0,
      microSwitchUnlockWindowState: 0,
      backHomeLightDelayValue: 0,
      leftHomeLightDelayValue: 0,
      backDoorElectricMode: 0,
    );
  }
}

class EngineData {
  final double engineDisplacement;
  final String engineCode;
  final int enginePower;
  final int engineSpeed;
  final int engineCoolantLevel;
  final int oilLevel;

  EngineData({
    required this.engineDisplacement,
    required this.engineCode,
    required this.enginePower,
    required this.engineSpeed,
    required this.engineCoolantLevel,
    required this.oilLevel,
  });

  Map<String, dynamic> toJson() {
    return {
      'engineDisplacement': engineDisplacement,
      'engineCode': engineCode,
      'enginePower': enginePower,
      'engineSpeed': engineSpeed,
      'engineCoolantLevel': engineCoolantLevel,
      'oilLevel': oilLevel,
    };
  }

  factory EngineData.fromJson(Map<String, dynamic> json) {
    return EngineData(
      engineDisplacement: (json['engineDisplacement'] ?? 0.0) as double,
      engineCode: json['engineCode'] ?? '',
      enginePower: json['enginePower'] ?? 0,
      engineSpeed: json['engineSpeed'] ?? 0,
      engineCoolantLevel: json['engineCoolantLevel'] ?? 0,
      oilLevel: json['oilLevel'] ?? 0,
    );
  }

  factory EngineData.defaultData() {
    return EngineData(
      engineDisplacement: 0,
      engineCode: '',
      enginePower: 0,
      engineSpeed: 0,
      engineCoolantLevel: 0,
      oilLevel: 0,
    );
  }
}

class PanoramaData {
  final int panoOutputSignal;
  final int panoWorkState;
  final int backLineConfig;
  final int panoOutputState;
  final int panoRotation;
  final int displayMode;
  final int panoramaOnlineState;

  PanoramaData({
    required this.panoOutputSignal,
    required this.panoWorkState,
    required this.backLineConfig,
    required this.panoOutputState,
    required this.panoRotation,
    required this.displayMode,
    required this.panoramaOnlineState,
  });

  Map<String, dynamic> toJson() {
    return {
      'panoOutputSignal': panoOutputSignal,
      'panoWorkState': panoWorkState,
      'backLineConfig': backLineConfig,
      'panoOutputState': panoOutputState,
      'panoRotation': panoRotation,
      'displayMode': displayMode,
      'panoramaOnlineState': panoramaOnlineState,
    };
  }

  factory PanoramaData.fromJson(Map<String, dynamic> json) {
    return PanoramaData(
      panoOutputSignal: json['panoOutputSignal'] ?? 0,
      panoWorkState: json['panoWorkState'] ?? 0,
      backLineConfig: json['backLineConfig'] ?? 0,
      panoOutputState: json['panoOutputState'] ?? 0,
      panoRotation: json['panoRotation'] ?? 0,
      displayMode: json['displayMode'] ?? 0,
      panoramaOnlineState: json['panoramaOnlineState'] ?? 0,
    );
  }

  factory PanoramaData.defaultData() {
    return PanoramaData(
      panoOutputSignal: 0,
      panoWorkState: 0,
      backLineConfig: 0,
      panoOutputState: 0,
      panoRotation: 0,
      displayMode: 0,
      panoramaOnlineState: 0,
    );
  }
}

class SensorData {
  final int lightIntensity;

  SensorData({required this.lightIntensity});

  Map<String, dynamic> toJson() {
    return {'lightIntensity': lightIntensity};
  }

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(lightIntensity: json['lightIntensity'] ?? 0);
  }

  factory SensorData.defaultData() {
    return SensorData(lightIntensity: 0);
  }
}

class TimeData {
  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;
  final int second;
  final int timeFormat;

  TimeData({
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
    required this.second,
    required this.timeFormat,
  });

  Map<String, dynamic> toJson() {
    return {
      'year': year,
      'month': month,
      'day': day,
      'hour': hour,
      'minute': minute,
      'second': second,
      'timeFormat': timeFormat,
    };
  }

  factory TimeData.fromJson(Map<String, dynamic> json) {
    return TimeData(
      year: json['year'] ?? 0,
      month: json['month'] ?? 0,
      day: json['day'] ?? 0,
      hour: json['hour'] ?? 0,
      minute: json['minute'] ?? 0,
      second: json['second'] ?? 0,
      timeFormat: json['timeFormat'] ?? 0,
    );
  }

  factory TimeData.defaultData() {
    return TimeData(year: 0, month: 0, day: 0, hour: 0, minute: 0, second: 0, timeFormat: 0);
  }
}

class EnergyModeData {
  final int energyMode;
  final int operationMode;
  final int powerGenerationState;
  final int powerGenerationValue;
  final int roadSurfaceMode;

  EnergyModeData({
    required this.energyMode,
    required this.operationMode,
    required this.powerGenerationState,
    required this.powerGenerationValue,
    required this.roadSurfaceMode,
  });

  Map<String, dynamic> toJson() {
    return {
      'energyMode': energyMode,
      'operationMode': operationMode,
      'powerGenerationState': powerGenerationState,
      'powerGenerationValue': powerGenerationValue,
      'roadSurfaceMode': roadSurfaceMode,
    };
  }

  factory EnergyModeData.fromJson(Map<String, dynamic> json) {
    return EnergyModeData(
      energyMode: json['energyMode'] ?? 0,
      operationMode: json['operationMode'] ?? 0,
      powerGenerationState: json['powerGenerationState'] ?? 0,
      powerGenerationValue: json['powerGenerationValue'] ?? 0,
      roadSurfaceMode: json['roadSurfaceMode'] ?? 0,
    );
  }

  factory EnergyModeData.defaultData() {
    return EnergyModeData(energyMode: 0, operationMode: 0, powerGenerationState: 0, powerGenerationValue: 0, roadSurfaceMode: 0);
  }
}

class RadarData {
  final int leftFront;
  final int rightFront;
  final int leftRear;
  final int rightRear;
  final int left;
  final int right;
  final int frontLeftMid;
  final int frontRightMid;
  final int reverseRadarSwitch;

  RadarData({
    required this.leftFront,
    required this.rightFront,
    required this.leftRear,
    required this.rightRear,
    required this.left,
    required this.right,
    required this.frontLeftMid,
    required this.frontRightMid,
    required this.reverseRadarSwitch,
  });

  Map<String, dynamic> toJson() {
    return {
      'leftFront': leftFront,
      'rightFront': rightFront,
      'leftRear': leftRear,
      'rightRear': rightRear,
      'left': left,
      'right': right,
      'frontLeftMid': frontLeftMid,
      'frontRightMid': frontRightMid,
      'reverseRadarSwitch': reverseRadarSwitch,
    };
  }

  factory RadarData.fromJson(Map<String, dynamic> json) {
    return RadarData(
      leftFront: json['leftFront'] ?? 0,
      rightFront: json['rightFront'] ?? 0,
      leftRear: json['leftRear'] ?? 0,
      rightRear: json['rightRear'] ?? 0,
      left: json['left'] ?? 0,
      right: json['right'] ?? 0,
      frontLeftMid: json['frontLeftMid'] ?? 0,
      frontRightMid: json['frontRightMid'] ?? 0,
      reverseRadarSwitch: json['reverseRadarSwitch'] ?? 0,
    );
  }

  factory RadarData.defaultData() {
    return RadarData(leftFront: 0, rightFront: 0, leftRear: 0, rightRear: 0, left: 0, right: 0, frontLeftMid: 0, frontRightMid: 0, reverseRadarSwitch: 0);
  }
}

class TyreData {
  final int tyrePressureLf;
  final int tyrePressureRf;
  final int tyrePressureLr;
  final int tyrePressureRr;
  final int tyreAirLeakStateLf;
  final int tyreAirLeakStateRf;
  final int tyreAirLeakStateLr;
  final int tyreAirLeakStateRr;
  final int tyreBatteryState;
  final int tyreSystemState;
  final int tyreTemperatureState;
  final int tyreSignalStateLf;
  final int tyreSignalStateRf;
  final int tyreSignalStateLr;
  final int tyreSignalStateRr;

  TyreData({
    required this.tyrePressureLf,
    required this.tyrePressureRf,
    required this.tyrePressureLr,
    required this.tyrePressureRr,
    required this.tyreAirLeakStateLf,
    required this.tyreAirLeakStateRf,
    required this.tyreAirLeakStateLr,
    required this.tyreAirLeakStateRr,
    required this.tyreBatteryState,
    required this.tyreSystemState,
    required this.tyreTemperatureState,
    required this.tyreSignalStateLf,
    required this.tyreSignalStateRf,
    required this.tyreSignalStateLr,
    required this.tyreSignalStateRr,
  });

  Map<String, dynamic> toJson() {
    return {
      'tyrePressureLf': tyrePressureLf,
      'tyrePressureRf': tyrePressureRf,
      'tyrePressureLr': tyrePressureLr,
      'tyrePressureRr': tyrePressureRr,
      'tyreAirLeakStateLf': tyreAirLeakStateLf,
      'tyreAirLeakStateRf': tyreAirLeakStateRf,
      'tyreAirLeakStateLr': tyreAirLeakStateLr,
      'tyreAirLeakStateRr': tyreAirLeakStateRr,
      'tyreBatteryState': tyreBatteryState,
      'tyreSystemState': tyreSystemState,
      'tyreTemperatureState': tyreTemperatureState,
      'tyreSignalStateLf': tyreSignalStateLf,
      'tyreSignalStateRf': tyreSignalStateRf,
      'tyreSignalStateLr': tyreSignalStateLr,
      'tyreSignalStateRr': tyreSignalStateRr,
    };
  }

  factory TyreData.fromJson(Map<String, dynamic> json) {
    return TyreData(
      tyrePressureLf: json['tyrePressureLf'] ?? 0,
      tyrePressureRf: json['tyrePressureRf'] ?? 0,
      tyrePressureLr: json['tyrePressureLr'] ?? 0,
      tyrePressureRr: json['tyrePressureRr'] ?? 0,
      tyreAirLeakStateLf: json['tyreAirLeakStateLf'] ?? 0,
      tyreAirLeakStateRf: json['tyreAirLeakStateRf'] ?? 0,
      tyreAirLeakStateLr: json['tyreAirLeakStateLr'] ?? 0,
      tyreAirLeakStateRr: json['tyreAirLeakStateRr'] ?? 0,
      tyreBatteryState: json['tyreBatteryState'] ?? 0,
      tyreSystemState: json['tyreSystemState'] ?? 0,
      tyreTemperatureState: json['tyreTemperatureState'] ?? 0,
      tyreSignalStateLf: json['tyreSignalStateLf'] ?? 0,
      tyreSignalStateRf: json['tyreSignalStateRf'] ?? 0,
      tyreSignalStateLr: json['tyreSignalStateLr'] ?? 0,
      tyreSignalStateRr: json['tyreSignalStateRr'] ?? 0,
    );
  }

  factory TyreData.defaultData() {
    return TyreData(
      tyrePressureLf: 0, tyrePressureRf: 0, tyrePressureLr: 0, tyrePressureRr: 0,
      tyreAirLeakStateLf: 0, tyreAirLeakStateRf: 0, tyreAirLeakStateLr: 0, tyreAirLeakStateRr: 0,
      tyreBatteryState: 0, tyreSystemState: 0, tyreTemperatureState: 0,
      tyreSignalStateLf: 0, tyreSignalStateRf: 0, tyreSignalStateLr: 0, tyreSignalStateRr: 0,
    );
  }
}

class AirQualityData {
  final int pm25OnlineState;
  final int pm25CheckStateIn;
  final int pm25CheckStateOut;
  final int pm25LevelIn;
  final int pm25LevelOut;
  final int pm25ValueIn;
  final int pm25ValueOut;

  AirQualityData({
    required this.pm25OnlineState,
    required this.pm25CheckStateIn,
    required this.pm25CheckStateOut,
    required this.pm25LevelIn,
    required this.pm25LevelOut,
    required this.pm25ValueIn,
    required this.pm25ValueOut,
  });

  Map<String, dynamic> toJson() {
    return {
      'pm25OnlineState': pm25OnlineState,
      'pm25CheckStateIn': pm25CheckStateIn,
      'pm25CheckStateOut': pm25CheckStateOut,
      'pm25LevelIn': pm25LevelIn,
      'pm25LevelOut': pm25LevelOut,
      'pm25ValueIn': pm25ValueIn,
      'pm25ValueOut': pm25ValueOut,
    };
  }

  factory AirQualityData.fromJson(Map<String, dynamic> json) {
    return AirQualityData(
      pm25OnlineState: json['pm25OnlineState'] ?? 0,
      pm25CheckStateIn: json['pm25CheckStateIn'] ?? 0,
      pm25CheckStateOut: json['pm25CheckStateOut'] ?? 0,
      pm25LevelIn: json['pm25LevelIn'] ?? 0,
      pm25LevelOut: json['pm25LevelOut'] ?? 0,
      pm25ValueIn: json['pm25ValueIn'] ?? 0,
      pm25ValueOut: json['pm25ValueOut'] ?? 0,
    );
  }

  factory AirQualityData.defaultData() {
    return AirQualityData(
      pm25OnlineState: 0, pm25CheckStateIn: 0, pm25CheckStateOut: 0,
      pm25LevelIn: 0, pm25LevelOut: 0, pm25ValueIn: 0, pm25ValueOut: 0,
    );
  }
}

class ChargeData {
  final int chargerFaultState;
  final int chargerWorkState;
  final double chargingCapacity;
  final int chargingType;
  final int chargingRestTimeHour;
  final int chargingRestTimeMinute;
  final int chargingCapStateAc;
  final int chargingCapStateDc;
  final int chargingPortLockRebackState;
  final int dischargeRequestState;
  final int chargerState;
  final int chargingGunState;
  final double chargingPower;
  final int batteryManagementDeviceState;
  final int chargingScheduleEnableState;
  final int chargingScheduleState;
  final int chargingGunNotInsertedState;
  final int chargingScheduleTimeHour;
  final int chargingScheduleTimeMinute;

  ChargeData({
    required this.chargerFaultState,
    required this.chargerWorkState,
    required this.chargingCapacity,
    required this.chargingType,
    required this.chargingRestTimeHour,
    required this.chargingRestTimeMinute,
    required this.chargingCapStateAc,
    required this.chargingCapStateDc,
    required this.chargingPortLockRebackState,
    required this.dischargeRequestState,
    required this.chargerState,
    required this.chargingGunState,
    required this.chargingPower,
    required this.batteryManagementDeviceState,
    required this.chargingScheduleEnableState,
    required this.chargingScheduleState,
    required this.chargingGunNotInsertedState,
    required this.chargingScheduleTimeHour,
    required this.chargingScheduleTimeMinute,
  });

  Map<String, dynamic> toJson() {
    return {
      'chargerFaultState': chargerFaultState,
      'chargerWorkState': chargerWorkState,
      'chargingCapacity': chargingCapacity,
      'chargingType': chargingType,
      'chargingRestTimeHour': chargingRestTimeHour,
      'chargingRestTimeMinute': chargingRestTimeMinute,
      'chargingCapStateAc': chargingCapStateAc,
      'chargingCapStateDc': chargingCapStateDc,
      'chargingPortLockRebackState': chargingPortLockRebackState,
      'dischargeRequestState': dischargeRequestState,
      'chargerState': chargerState,
      'chargingGunState': chargingGunState,
      'chargingPower': chargingPower,
      'batteryManagementDeviceState': batteryManagementDeviceState,
      'chargingScheduleEnableState': chargingScheduleEnableState,
      'chargingScheduleState': chargingScheduleState,
      'chargingGunNotInsertedState': chargingGunNotInsertedState,
      'chargingScheduleTimeHour': chargingScheduleTimeHour,
      'chargingScheduleTimeMinute': chargingScheduleTimeMinute,
    };
  }

  factory ChargeData.fromJson(Map<String, dynamic> json) {
    return ChargeData(
      chargerFaultState: json['chargerFaultState'] ?? 0,
      chargerWorkState: json['chargerWorkState'] ?? 0,
      chargingCapacity: (json['chargingCapacity'] ?? 0.0) as double,
      chargingType: json['chargingType'] ?? 0,
      chargingRestTimeHour: json['chargingRestTimeHour'] ?? 0,
      chargingRestTimeMinute: json['chargingRestTimeMinute'] ?? 0,
      chargingCapStateAc: json['chargingCapStateAc'] ?? 0,
      chargingCapStateDc: json['chargingCapStateDc'] ?? 0,
      chargingPortLockRebackState: json['chargingPortLockRebackState'] ?? 0,
      dischargeRequestState: json['dischargeRequestState'] ?? 0,
      chargerState: json['chargerState'] ?? 0,
      chargingGunState: json['chargingGunState'] ?? 0,
      chargingPower: (json['chargingPower'] ?? 0.0) as double,
      batteryManagementDeviceState: json['batteryManagementDeviceState'] ?? 0,
      chargingScheduleEnableState: json['chargingScheduleEnableState'] ?? 0,
      chargingScheduleState: json['chargingScheduleState'] ?? 0,
      chargingGunNotInsertedState: json['chargingGunNotInsertedState'] ?? 0,
      chargingScheduleTimeHour: json['chargingScheduleTimeHour'] ?? 0,
      chargingScheduleTimeMinute: json['chargingScheduleTimeMinute'] ?? 0,
    );
  }

  factory ChargeData.defaultData() {
    return ChargeData(
      chargerFaultState: 0, chargerWorkState: 0, chargingCapacity: 0, chargingType: 0,
      chargingRestTimeHour: 0, chargingRestTimeMinute: 0,
      chargingCapStateAc: 0, chargingCapStateDc: 0, chargingPortLockRebackState: 0,
      dischargeRequestState: 0, chargerState: 0, chargingGunState: 0, chargingPower: 0,
      batteryManagementDeviceState: 0, chargingScheduleEnableState: 0, chargingScheduleState: 0,
      chargingGunNotInsertedState: 0, chargingScheduleTimeHour: 0, chargingScheduleTimeMinute: 0,
    );
  }
}

class MediaData {
  final int mediaType;
  final int playMode;
  final int playState;
  final String fileName;
  final String artistName;
  final String albumName;

  MediaData({
    required this.mediaType,
    required this.playMode,
    required this.playState,
    required this.fileName,
    required this.artistName,
    required this.albumName,
  });

  Map<String, dynamic> toJson() {
    return {
      'mediaType': mediaType,
      'playMode': playMode,
      'playState': playState,
      'fileName': fileName,
      'artistName': artistName,
      'albumName': albumName,
    };
  }

  factory MediaData.fromJson(Map<String, dynamic> json) {
    return MediaData(
      mediaType: json['mediaType'] ?? 0,
      playMode: json['playMode'] ?? 0,
      playState: json['playState'] ?? 0,
      fileName: json['fileName'] ?? '',
      artistName: json['artistName'] ?? '',
      albumName: json['albumName'] ?? '',
    );
  }

  factory MediaData.defaultData() {
    return MediaData(mediaType: 0, playMode: 0, playState: 0, fileName: '', artistName: '', albumName: '');
  }
}

class BodyStatusData {
  final String autoVIN;
  final int autoModelName;
  final int autoSystemState;
  final int doorStateLf;
  final int doorStateRf;
  final int doorStateLr;
  final int doorStateRr;
  final int doorStateHood;
  final int doorStateLuggage;
  final int windowStateLf;
  final int windowStateRf;
  final int windowStateLr;
  final int windowStateRr;
  final int moonRoofPercent;
  final int sunshadePercent;
  final int batteryVoltageLevel;
  final int powerLevel;
  final double steeringWheelAngle;
  final double steeringWheelSpeed;
  final int fuelElecLowPower;
  final int alarmState;
  final int moonRoofConfig;

  BodyStatusData({
    required this.autoVIN,
    required this.autoModelName,
    required this.autoSystemState,
    required this.doorStateLf,
    required this.doorStateRf,
    required this.doorStateLr,
    required this.doorStateRr,
    required this.doorStateHood,
    required this.doorStateLuggage,
    required this.windowStateLf,
    required this.windowStateRf,
    required this.windowStateLr,
    required this.windowStateRr,
    required this.moonRoofPercent,
    required this.sunshadePercent,
    required this.batteryVoltageLevel,
    required this.powerLevel,
    required this.steeringWheelAngle,
    required this.steeringWheelSpeed,
    required this.fuelElecLowPower,
    required this.alarmState,
    required this.moonRoofConfig,
  });

  Map<String, dynamic> toJson() {
    return {
      'autoVIN': autoVIN,
      'autoModelName': autoModelName,
      'autoSystemState': autoSystemState,
      'doorStateLf': doorStateLf,
      'doorStateRf': doorStateRf,
      'doorStateLr': doorStateLr,
      'doorStateRr': doorStateRr,
      'doorStateHood': doorStateHood,
      'doorStateLuggage': doorStateLuggage,
      'windowStateLf': windowStateLf,
      'windowStateRf': windowStateRf,
      'windowStateLr': windowStateLr,
      'windowStateRr': windowStateRr,
      'moonRoofPercent': moonRoofPercent,
      'sunshadePercent': sunshadePercent,
      'batteryVoltageLevel': batteryVoltageLevel,
      'powerLevel': powerLevel,
      'steeringWheelAngle': steeringWheelAngle,
      'steeringWheelSpeed': steeringWheelSpeed,
      'fuelElecLowPower': fuelElecLowPower,
      'alarmState': alarmState,
      'moonRoofConfig': moonRoofConfig,
    };
  }

  factory BodyStatusData.fromJson(Map<String, dynamic> json) {
    return BodyStatusData(
      autoVIN: json['autoVIN'] ?? '',
      autoModelName: json['autoModelName'] ?? 0,
      autoSystemState: json['autoSystemState'] ?? 0,
      doorStateLf: json['doorStateLf'] ?? 0,
      doorStateRf: json['doorStateRf'] ?? 0,
      doorStateLr: json['doorStateLr'] ?? 0,
      doorStateRr: json['doorStateRr'] ?? 0,
      doorStateHood: json['doorStateHood'] ?? 0,
      doorStateLuggage: json['doorStateLuggage'] ?? 0,
      windowStateLf: json['windowStateLf'] ?? 0,
      windowStateRf: json['windowStateRf'] ?? 0,
      windowStateLr: json['windowStateLr'] ?? 0,
      windowStateRr: json['windowStateRr'] ?? 0,
      moonRoofPercent: json['moonRoofPercent'] ?? 0,
      sunshadePercent: json['sunshadePercent'] ?? 0,
      batteryVoltageLevel: json['batteryVoltageLevel'] ?? 0,
      powerLevel: json['powerLevel'] ?? 0,
      steeringWheelAngle: (json['steeringWheelAngle'] ?? 0.0) as double,
      steeringWheelSpeed: (json['steeringWheelSpeed'] ?? 0.0) as double,
      fuelElecLowPower: json['fuelElecLowPower'] ?? 0,
      alarmState: json['alarmState'] ?? 0,
      moonRoofConfig: json['moonRoofConfig'] ?? 0,
    );
  }

  factory BodyStatusData.defaultData() {
    return BodyStatusData(
      autoVIN: '', autoModelName: 0, autoSystemState: 0,
      doorStateLf: 0, doorStateRf: 0, doorStateLr: 0, doorStateRr: 0,
      doorStateHood: 0, doorStateLuggage: 0,
      windowStateLf: 0, windowStateRf: 0, windowStateLr: 0, windowStateRr: 0,
      moonRoofPercent: 0, sunshadePercent: 0,
      batteryVoltageLevel: 0, powerLevel: 0,
      steeringWheelAngle: 0.0, steeringWheelSpeed: 0.0,
      fuelElecLowPower: 0, alarmState: 0, moonRoofConfig: 0,
    );
  }
}

class LightData {
  final int lightAutoStatus;
  final int lightSide;
  final int lightLowBeam;
  final int lightHighBeam;
  final int lightLeftTurnSignal;
  final int lightRightTurnSignal;
  final int lightFrontFog;
  final int lightRearFog;
  final int lightFoot;
  final int afsSwitch;

  LightData({
    required this.lightAutoStatus,
    required this.lightSide,
    required this.lightLowBeam,
    required this.lightHighBeam,
    required this.lightLeftTurnSignal,
    required this.lightRightTurnSignal,
    required this.lightFrontFog,
    required this.lightRearFog,
    required this.lightFoot,
    required this.afsSwitch,
  });

  Map<String, dynamic> toJson() {
    return {
      'lightAutoStatus': lightAutoStatus,
      'lightSide': lightSide,
      'lightLowBeam': lightLowBeam,
      'lightHighBeam': lightHighBeam,
      'lightLeftTurnSignal': lightLeftTurnSignal,
      'lightRightTurnSignal': lightRightTurnSignal,
      'lightFrontFog': lightFrontFog,
      'lightRearFog': lightRearFog,
      'lightFoot': lightFoot,
      'afsSwitch': afsSwitch,
    };
  }

  factory LightData.fromJson(Map<String, dynamic> json) {
    return LightData(
      lightAutoStatus: json['lightAutoStatus'] ?? 0,
      lightSide: json['lightSide'] ?? 0,
      lightLowBeam: json['lightLowBeam'] ?? 0,
      lightHighBeam: json['lightHighBeam'] ?? 0,
      lightLeftTurnSignal: json['lightLeftTurnSignal'] ?? 0,
      lightRightTurnSignal: json['lightRightTurnSignal'] ?? 0,
      lightFrontFog: json['lightFrontFog'] ?? 0,
      lightRearFog: json['lightRearFog'] ?? 0,
      lightFoot: json['lightFoot'] ?? 0,
      afsSwitch: json['afsSwitch'] ?? 0,
    );
  }

  factory LightData.defaultData() {
    return LightData(
      lightAutoStatus: 0, lightSide: 0, lightLowBeam: 0, lightHighBeam: 0,
      lightLeftTurnSignal: 0, lightRightTurnSignal: 0,
      lightFrontFog: 0, lightRearFog: 0, lightFoot: 0, afsSwitch: 0,
    );
  }
}

class CarData {
  final SpeedData speed;
  final StatisticData statistic;
  final InstrumentData instrument;
  final DoorData door;
  final VehicleSettingData vehicleSetting;
  final EngineData engine;
  final PanoramaData panorama;
  final AcData ac;
  final SensorData sensor;
  final TimeData time;
  final EnergyModeData energyMode;
  final RadarData radar;
  final TyreData tyre;
  final AirQualityData airQuality;
  final ChargeData charge;
  final MediaData media;
  final BodyStatusData bodyStatus;
  final LightData light;

  CarData({
    required this.speed,
    required this.statistic,
    required this.instrument,
    required this.door,
    required this.vehicleSetting,
    required this.engine,
    required this.panorama,
    required this.ac,
    required this.sensor,
    required this.time,
    required this.energyMode,
    required this.radar,
    required this.tyre,
    required this.airQuality,
    required this.charge,
    required this.media,
    required this.bodyStatus,
    required this.light,
  });

  Map<String, dynamic> toJson() {
    return {
      'speed': speed.toJson(),
      'statistic': statistic.toJson(),
      'instrument': instrument.toJson(),
      'door': door.toJson(),
      'vehicleSetting': vehicleSetting.toJson(),
      'engine': engine.toJson(),
      'panorama': panorama.toJson(),
      'ac': ac.toJson(),
      'sensor': sensor.toJson(),
      'time': time.toJson(),
      'energyMode': energyMode.toJson(),
      'radar': radar.toJson(),
      'tyre': tyre.toJson(),
      'airQuality': airQuality.toJson(),
      'charge': charge.toJson(),
      'media': media.toJson(),
      'bodyStatus': bodyStatus.toJson(),
      'light': light.toJson(),
    };
  }

  factory CarData.fromJson(Map<String, dynamic> json) {
    return CarData(
      speed: SpeedData.fromJson(json['speed'] ?? {}),
      statistic: StatisticData.fromJson(json['statistic'] ?? {}),
      instrument: InstrumentData.fromJson(json['instrument'] ?? {}),
      door: DoorData.fromJson(json['door'] ?? {}),
      vehicleSetting: VehicleSettingData.fromJson(json['vehicleSetting'] ?? {}),
      engine: EngineData.fromJson(json['engine'] ?? {}),
      panorama: PanoramaData.fromJson(json['panorama'] ?? {}),
      ac: AcData.fromJson(json['ac'] ?? {}),
      sensor: SensorData.fromJson(json['sensor'] ?? {}),
      time: TimeData.fromJson(json['time'] ?? {}),
      energyMode: EnergyModeData.fromJson(json['energyMode'] ?? {}),
      radar: RadarData.fromJson(json['radar'] ?? {}),
      tyre: TyreData.fromJson(json['tyre'] ?? {}),
      airQuality: AirQualityData.fromJson(json['airQuality'] ?? {}),
      charge: ChargeData.fromJson(json['charge'] ?? {}),
      media: MediaData.fromJson(json['media'] ?? {}),
      bodyStatus: BodyStatusData.fromJson(json['bodyStatus'] ?? {}),
      light: LightData.fromJson(json['light'] ?? {}),
    );
  }

  factory CarData.defaultData() {
    return CarData(
      speed: SpeedData.fromJson({}),
      statistic: StatisticData.fromJson({}),
      instrument: InstrumentData.defaultData(),
      door: DoorData.defaultData(),
      vehicleSetting: VehicleSettingData.defaultData(),
      engine: EngineData.defaultData(),
      panorama: PanoramaData.defaultData(),
      ac: AcData.defaultData(),
      sensor: SensorData.defaultData(),
      time: TimeData.defaultData(),
      energyMode: EnergyModeData.defaultData(),
      radar: RadarData.defaultData(),
      tyre: TyreData.defaultData(),
      airQuality: AirQualityData.defaultData(),
      charge: ChargeData.defaultData(),
      media: MediaData.defaultData(),
      bodyStatus: BodyStatusData.defaultData(),
      light: LightData.defaultData(),
    );
  }
}
