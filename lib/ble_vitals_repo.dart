import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'vitals_repository.dart';
import 'constants/ble_constants.dart';

/// BLEVitalsRepo — full hardware implementation using flutter_blue_plus.
///
/// Behaviour:
///   - Scans for a device advertising as [kDeviceName]
///   - Connects and discovers GATT services
///   - Subscribes to the notify characteristic ([kCharacteristicUUID])
///   - Parses incoming UTF-8 JSON bytes into [VitalsModel]
///   - Auto-reconnects on unexpected disconnect (up to [kMaxReconnectAttempts])
///   - Exposes [vitalsStream] to BLoC layer; no BLoC changes required
class BLEVitalsRepo implements VitalsRepository {
  // ─── Internal Stream ──────────────────────────────────────────────────
  final _controller = StreamController<VitalsModel>.broadcast();

  // ─── BLE State ────────────────────────────────────────────────────────
  BluetoothDevice? _device;
  BluetoothCharacteristic? _notifyChar;
  StreamSubscription<List<int>>?        _charSubscription;
  StreamSubscription<BluetoothConnectionState>? _connStateSubscription;

  int  _reconnectAttempts = 0;
  bool _intentionalDisconnect = false;
  bool _isConnecting = false;

  BLEVitalsRepo() {
    _startScan();
  }

  // ─── Step 1: Scan ─────────────────────────────────────────────────────
  Future<void> _startScan() async {
    if (_isConnecting) return;
    _isConnecting = true;
    _reconnectAttempts = 0; // Reset counter whenever we start a fresh scan
    _intentionalDisconnect = false;

    debugPrint('[BLERepo] Starting scan for "$kDeviceName"...');

    // Cancel any existing scan before starting a new one
    FlutterBluePlus.stopScan();

    FlutterBluePlus.startScan(
      withNames: [kDeviceName],
      timeout: Duration(seconds: kConnectionTimeoutSeconds),
    );

    FlutterBluePlus.scanResults.listen((results) async {
      for (final result in results) {
        if (result.device.platformName == kDeviceName) {
          debugPrint('[BLERepo] Found device: ${result.device.remoteId}');
          await FlutterBluePlus.stopScan();
          await _connect(result.device);
          break;
        }
      }
    }, onError: (e) {
      debugPrint('[BLERepo] Scan error: $e');
      _isConnecting = false;
      _scheduleReconnect();
    });

    // Handle scan timeout — device not found
    Future.delayed(Duration(seconds: kConnectionTimeoutSeconds + 1), () {
      if (_isConnecting && _device == null) {
        debugPrint('[BLERepo] Scan timeout. Device "$kDeviceName" not found.');
        _isConnecting = false;
        _scheduleReconnect();
      }
    });
  }

  // ─── Step 2: Connect ──────────────────────────────────────────────────
  Future<void> _connect(BluetoothDevice device) async {
    _device = device;

    // Monitor connection state for auto-reconnect
    _connStateSubscription?.cancel();
    _connStateSubscription = device.connectionState.listen((state) {
      debugPrint('[BLERepo] Connection state: $state');
      if (state == BluetoothConnectionState.disconnected && !_intentionalDisconnect) {
        debugPrint('[BLERepo] Unexpected disconnect. Will try to reconnect...');
        _charSubscription?.cancel();
        _notifyChar = null;
        _isConnecting = false;
        _scheduleReconnect();
      }
    });

    try {
      await device.connect(
        timeout: Duration(seconds: kConnectionTimeoutSeconds),
        autoConnect: false,
      );
      debugPrint('[BLERepo] Connected to ${device.platformName}.');
      _reconnectAttempts = 0; // Reset counter on success
      await _discoverAndSubscribe(device);
    } catch (e) {
      debugPrint('[BLERepo] Connection failed: $e');
      _isConnecting = false;
      _scheduleReconnect();
    }
  }

  // ─── Step 3: Discover Services & Subscribe ────────────────────────────
  Future<void> _discoverAndSubscribe(BluetoothDevice device) async {
    try {
      final services = await device.discoverServices();
      debugPrint('[BLERepo] Discovered ${services.length} services.');

      for (final service in services) {
        if (service.uuid.toString().toUpperCase() == kServiceUUID.toUpperCase()) {
          debugPrint('[BLERepo] Found target service: ${service.uuid}');

          for (final char in service.characteristics) {
            if (char.uuid.toString().toUpperCase() == kCharacteristicUUID.toUpperCase()) {
              debugPrint('[BLERepo] Found target characteristic: ${char.uuid}');
              _notifyChar = char;
              await _subscribeToCharacteristic(char);
              _isConnecting = false;
              return;
            }
          }
        }
      }

      debugPrint('[BLERepo] [ERROR] Target characteristic not found in services.');
      _isConnecting = false;
    } catch (e) {
      debugPrint('[BLERepo] [ERROR] Service discovery failed: $e');
      _isConnecting = false;
      _scheduleReconnect();
    }
  }

  // ─── Step 4–6: Subscribe, Decode UTF-8, Map to VitalsModel ───────────
  Future<void> _subscribeToCharacteristic(BluetoothCharacteristic char) async {
    try {
      await char.setNotifyValue(true);
      debugPrint('[BLERepo] Subscribed to notifications.');

      _charSubscription?.cancel();
      _charSubscription = char.lastValueStream.listen((rawBytes) {
        if (rawBytes.isEmpty) return;

        try {
          final jsonString = utf8.decode(rawBytes);
          
          final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
          final vitals = VitalsModel.fromJson(jsonMap);

          // Bad read check: if temperature and pressure are both 0.0 simultaneously
          if (vitals.temperature == 0.0 && vitals.pressure == 0.0) {
            debugPrint('[BLERepo] Bad read skipped (Temp/Pres are 0.0)');
            return;
          }

          debugPrint('[BLERepo] Received: $jsonString');
          _controller.add(vitals);
        } catch (e) {
          debugPrint('[BLERepo] Parse error: $e');
        }
      }, onError: (e) {
        debugPrint('[BLERepo] [ERROR] Characteristic stream error: $e');
      });
    } catch (e) {
      debugPrint('[BLERepo] [ERROR] setNotifyValue failed: $e');
      _scheduleReconnect();
    }
  }

  // ─── Step 7: Auto-Reconnect ───────────────────────────────────────────
  void _scheduleReconnect() {
    if (_intentionalDisconnect) return;

    _reconnectAttempts++;
    // Exponential backoff capped at 30 seconds
    final seconds = (kReconnectDelaySeconds * _reconnectAttempts).clamp(2, 30);
    final delay = Duration(seconds: seconds);
    
    debugPrint('[BLERepo] Reconnect attempt $_reconnectAttempts (waiting ${delay.inSeconds}s)...');

    Future.delayed(delay, () {
      if (!_intentionalDisconnect) {
        _startScan();
      }
    });
  }

  // ─── VitalsRepository interface ───────────────────────────────────────

  @override
  Stream<VitalsModel> get vitalsStream => _controller.stream;

  /// triggerEmergency: When the user presses the SOS button in the app,
  /// we could write to a writable characteristic here in future.
  /// For now, the ESP32 does not have a writable SOS char, so this is a no-op.
  @override
  void triggerEmergency() {
    debugPrint('[BLERepo] triggerEmergency called (write-back not yet implemented on firmware).');
  }

  @override
  void triggerNormal() {
    debugPrint('[BLERepo] triggerNormal called.');
  }

  /// Call this when the app is closing to cleanly disconnect.
  Future<void> dispose() async {
    _intentionalDisconnect = true;
    await _charSubscription?.cancel();
    await _connStateSubscription?.cancel();
    await _device?.disconnect();
    await _controller.close();
    debugPrint('[BLERepo] Disposed and disconnected.');
  }
}
