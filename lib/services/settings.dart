import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends ChangeNotifier {
  Settings._();
  static final Settings I = Settings._();

  late SharedPreferences prefs;

  String themeMode = 'auto'; // auto | day | night
  String vehicleName = 'Mi camioneta';
  double tankLiters = 70;
  double kmPerLiter = 7;
  double manualPrice = 24.5;
  String fuelType = 'regular'; // regular | premium | diesel
  double manualFuelPct = 50;
  String obdAddress = '';
  String obdName = '';
  bool keepScreenOn = true;
  bool autoConnectObd = true;

  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    themeMode = prefs.getString('themeMode') ?? themeMode;
    vehicleName = prefs.getString('vehicleName') ?? vehicleName;
    tankLiters = prefs.getDouble('tankLiters') ?? tankLiters;
    kmPerLiter = prefs.getDouble('kmPerLiter') ?? kmPerLiter;
    manualPrice = prefs.getDouble('manualPrice') ?? manualPrice;
    fuelType = prefs.getString('fuelType') ?? fuelType;
    manualFuelPct = prefs.getDouble('manualFuelPct') ?? manualFuelPct;
    obdAddress = prefs.getString('obdAddress') ?? obdAddress;
    obdName = prefs.getString('obdName') ?? obdName;
    keepScreenOn = prefs.getBool('keepScreenOn') ?? keepScreenOn;
    autoConnectObd = prefs.getBool('autoConnectObd') ?? autoConnectObd;
  }

  Future<void> update(void Function(Settings s) fn) async {
    fn(this);
    notifyListeners();
    await prefs.setString('themeMode', themeMode);
    await prefs.setString('vehicleName', vehicleName);
    await prefs.setDouble('tankLiters', tankLiters);
    await prefs.setDouble('kmPerLiter', kmPerLiter);
    await prefs.setDouble('manualPrice', manualPrice);
    await prefs.setString('fuelType', fuelType);
    await prefs.setDouble('manualFuelPct', manualFuelPct);
    await prefs.setString('obdAddress', obdAddress);
    await prefs.setString('obdName', obdName);
    await prefs.setBool('keepScreenOn', keepScreenOn);
    await prefs.setBool('autoConnectObd', autoConnectObd);
  }
}
