import 'package:flutter/foundation.dart';

/// VitalsModel specifically structured to match the ESP32 hardware output
/// while maintaining backward compatibility with the existing UI layer and simulation.
class VitalsModel {
  // --- Hardware Fields (Exact ESP32 Match) ---
  final double ax;
  final double ay;
  final double az;
  final double pressure;
  final double temp; // We'll keep this as 'temp' for UI compatibility
  final bool alert;

  // --- Legacy/Compatibility Fields ---
  final int hr;
  final double spo2;
  final bool fall;
  final bool sos;
  final double bat;
  final String mode;
  final bool sensorFit;
  final bool heatStress;

  // Convenience getter for code that might specifically look for 'temperature'
  double get temperature => temp;

  const VitalsModel({
    this.ax = 0.0,
    this.ay = 0.0,
    this.az = 0.0,
    this.pressure = 0.0,
    required this.temp,
    this.alert = false,
    this.hr = 0,
    this.spo2 = 0.0,
    this.fall = false,
    this.sos = false,
    this.bat = 85.0,
    this.mode = "wrist",
    this.sensorFit = true,
    this.heatStress = false,
  });

  /// Factory constructor to parse data from the ESP32 JSON payload:
  /// {"ax":0.02,"ay":0.01,"az":1.0,"pressure":1013.25,"temperature":26.5,"alert":true}
  factory VitalsModel.fromJson(Map<String, dynamic> json) {
    final bool alertVal = json['alert'] as bool? ?? false;
    
    return VitalsModel(
      ax: (json['ax'] as num?)?.toDouble() ?? 0.0,
      ay: (json['ay'] as num?)?.toDouble() ?? 0.0,
      az: (json['az'] as num?)?.toDouble() ?? 0.0,
      pressure: (json['pressure'] as num?)?.toDouble() ?? 0.0,
      // Map 'temperature' from JSON to our internal 'temp' field
      temp: (json['temperature'] as num?)?.toDouble() ?? 
            (json['temp'] as num?)?.toDouble() ?? 0.0,
      alert: alertVal,
      // Mapping and defaults
      fall: alertVal, // map alert -> fall
      hr: (json['hr'] as num?)?.toInt() ?? 0,
      spo2: (json['spo2'] as num?)?.toDouble() ?? 0.0,
      sos: json['sos'] as bool? ?? false,
      bat: (json['bat'] as num?)?.toDouble() ?? 85.0,
      mode: json['mode'] as String? ?? "wrist",
      sensorFit: json['sensor_fit'] as bool? ?? true,
      heatStress: json['heat_stress'] as bool? ?? false,
    );
  }

  /// Converts the model to JSON, including both hardware and legacy fields.
  Map<String, dynamic> toJson() {
    return {
      'ax': ax,
      'ay': ay,
      'az': az,
      'pressure': pressure,
      'temp': temp,
      'temperature': temp,
      'alert': alert,
      'hr': hr,
      'spo2': spo2,
      'fall': fall,
      'sos': sos,
      'bat': bat,
      'mode': mode,
      'sensor_fit': sensorFit,
      'heat_stress': heatStress,
    };
  }

  /// Standard copyWith for immutable state updates
  VitalsModel copyWith({
    double? ax,
    double? ay,
    double? az,
    double? pressure,
    double? temp,
    bool? alert,
    int? hr,
    double? spo2,
    bool? fall,
    bool? sos,
    double? bat,
    String? mode,
    bool? sensorFit,
    bool? heatStress,
  }) {
    return VitalsModel(
      ax: ax ?? this.ax,
      ay: ay ?? this.ay,
      az: az ?? this.az,
      pressure: pressure ?? this.pressure,
      temp: temp ?? this.temp,
      alert: alert ?? this.alert,
      hr: hr ?? this.hr,
      spo2: spo2 ?? this.spo2,
      fall: fall ?? this.fall,
      sos: sos ?? this.sos,
      bat: bat ?? this.bat,
      mode: mode ?? this.mode,
      sensorFit: sensorFit ?? this.sensorFit,
      heatStress: heatStress ?? this.heatStress,
    );
  }
}
