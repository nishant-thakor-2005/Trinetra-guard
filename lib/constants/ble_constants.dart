/// This file is the single source of truth for all BLE configuration.
/// 
/// Firmware person needs to provide the exact Service UUID and 
/// Characteristic UUID once the hardware is finalized.

// The name the ESP32-S3 broadcasts over BLE.
const String kDeviceName = 'TRINETRA_GUARD';

// The primary GATT Service UUID containing vitals characteristics.
// TODO: Replace with actual firmware UUID
const String kServiceUUID = 'REPLACE_WITH_FIRMWARE_UUID';

// The GATT Characteristic UUID that emits JSON vitals data.
// TODO: Replace with actual firmware UUID
const String kCharacteristicUUID = 'REPLACE_WITH_FIRMWARE_UUID';

// Time to wait before attempting a reconnection after an unexpected drop.
const int kReconnectDelaySeconds = 2;

// Maximum time to scan/attempt connection before timing out.
const int kConnectionTimeoutSeconds = 10;

// Addition 3: Prevents infinite reconnect loop when device is unavailable.
const int kMaxReconnectAttempts = 5;

// Addition 1: Connection state enum for UI status
enum BLEConnectionState { disconnected, scanning, connecting, connected }
