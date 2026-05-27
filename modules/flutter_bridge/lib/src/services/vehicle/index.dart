export 'car_data_types.dart';
export 'speed_service.dart';
export 'statistic_service.dart';
export 'instrument_service.dart';
export 'door_service.dart';
export 'vehicle_setting_service.dart';
export 'engine_service.dart';
export 'panorama_service.dart';
export 'ac_service.dart';
export 'sensor_service.dart';
export 'time_service.dart';
export 'energy_mode_service.dart';
export 'radar_service.dart';
export 'tyre_service.dart';
export 'air_quality_service.dart';
export 'charge_service.dart';
export 'media_service.dart';
export 'body_status_service.dart';
export 'light_service.dart';

import 'speed_service.dart';
import 'statistic_service.dart';
import 'instrument_service.dart';
import 'door_service.dart';
import 'vehicle_setting_service.dart';
import 'engine_service.dart';
import 'panorama_service.dart';
import 'ac_service.dart';
import 'sensor_service.dart';
import 'time_service.dart';
import 'energy_mode_service.dart';
import 'radar_service.dart';
import 'tyre_service.dart';
import 'air_quality_service.dart';
import 'charge_service.dart';
import 'media_service.dart';
import 'body_status_service.dart';
import 'light_service.dart';

class VehicleServices {
  final SpeedService speed;
  final StatisticService statistic;
  final InstrumentService instrument;
  final DoorService door;
  final VehicleSettingService vehicleset;
  final EngineService engine;
  final PanoramaService panorama;
  final AcService ac;
  final SensorService sensor;
  final TimeService time;
  final EnergyModeService energyMode;
  final RadarService radar;
  final TyreService tyre;
  final AirQualityService airQuality;
  final ChargeService charge;
  final MediaService media;
  final BodyStatusService bodyStatus;
  final LightService light;

  VehicleServices._internal()
      : speed = SpeedService(),
        statistic = StatisticService(),
        instrument = InstrumentService(),
        door = DoorService(),
        vehicleset = VehicleSettingService(),
        engine = EngineService(),
        panorama = PanoramaService(),
        ac = AcService(),
        sensor = SensorService(),
        time = TimeService(),
        energyMode = EnergyModeService(),
        radar = RadarService(),
        tyre = TyreService(),
        airQuality = AirQualityService(),
        charge = ChargeService(),
        media = MediaService(),
        bodyStatus = BodyStatusService(),
        light = LightService();

  static final VehicleServices _instance = VehicleServices._internal();

  factory VehicleServices() => _instance;

  void dispose() {
    speed.dispose();
    statistic.dispose();
    instrument.dispose();
    door.dispose();
    vehicleset.dispose();
    engine.dispose();
    panorama.dispose();
    ac.dispose();
    sensor.dispose();
    time.dispose();
    energyMode.dispose();
    radar.dispose();
    tyre.dispose();
    airQuality.dispose();
    charge.dispose();
    media.dispose();
    bodyStatus.dispose();
    light.dispose();
  }
}