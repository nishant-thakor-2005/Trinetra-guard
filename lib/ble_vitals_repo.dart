import 'dart:async';
import 'package:flutter/foundation.dart';
import 'vitals_repository.dart';
import 'constants/ble_constants.dart';

/// HARDWARE INTEGRATION STEPS (flutter_blue_plus):
/// 
/// Step 1: Scan for device name (kDeviceName)
///         -> FlutterBluePlus.startScan(withNames: [kDeviceName])
/// Step 2: Connect and discover services
///         -> device.connect() then device.discoverServices()
/// Step 3: Subscribe to characteristic (kServiceUUID, kCharacteristicUUID)
///         -> characteristic.setNotifyValue(true)
/// Step 4: Parse incoming bytes as UTF-8 JSON
///         -> utf8.decode(value)
/// Step 5: Map JSON to VitalsModel
///         -> VitalsModel.fromJson(jsonDecode(stringPayload))
/// Step 6: Push to StreamController
///         -> _controller.add(vitals)
/// Step 7: Implement auto-reconnect on disconnect
///         -> Listen to device.connectionState, use kMaxReconnectAttempts
/// 
class BLEVitalsRepo implements VitalsRepository {
  // TODO: Insert BLE device name here
  // TODO: Insert GATT Service UUID here
  // TODO: Insert GATT Characteristic UUID here

  @override
  Stream<VitalsModel> get vitalsStream {
    debugPrint('[BLERepo] NOT IMPLEMENTED — hardware pending');
    return const Stream.empty();
  }

  @override
  void triggerEmergency() {
    debugPrint('[BLERepo] NOT IMPLEMENTED — hardware pending');
    throw UnimplementedError();
  }

  @override
  void triggerNormal() {
    debugPrint('[BLERepo] NOT IMPLEMENTED — hardware pending');
    throw UnimplementedError();
  }
}
