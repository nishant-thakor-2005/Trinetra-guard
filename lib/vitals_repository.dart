import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

import 'vitals_model.dart';

export 'vitals_model.dart';

enum SimulationMode { normal, activity, emergency, recovery }

abstract class VitalsRepository {
  Stream<VitalsModel> get vitalsStream;
  void triggerEmergency();
  void triggerNormal();
}

class SimulatedVitalsRepo implements VitalsRepository {
  final _controller = StreamController<VitalsModel>.broadcast();
  final Random _random = Random();
  Timer? _timer;

  // Track ticks
  int _tickCount = 0;

  // Internal state (doubles for smooth transitions)
  double _hr = 72.0;
  double _spo2 = 98.0;
  double _temp = 36.6;
  bool _fall = false;
  bool _sos = false;
  double _bat = 85.0;
  bool _heatStress = false;
  bool _sensorFit = true;
  final String _modeLabel = 'wrist';

  // State management
  SimulationMode _simMode = SimulationMode.normal;
  
  // Emergency toggling
  bool _emergencyToggleA = true;
  
  // Target values for transitions
  double _targetHr = 72.0;
  double _targetSpo2 = 98.0;
  int _transitionTicksTotal = 0;
  int _transitionTicksElapsed = 0;
  
  // Timers for specific modes
  int _activityTicksRemaining = 0;
  int _recoveryTicksRemaining = 0;

  SimulatedVitalsRepo() {
    _startSimulation();
  }

  void _startSimulation() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      _generateTick();
    });
  }

  void _generateTick() {
    _tickCount++;

    // Behavior 1: Battery decreases 0.1 every 10 ticks, min 5.
    if (_tickCount % 10 == 0) {
      _bat = max(5.0, _bat - 0.1);
    }

    // Behavior 5: Sensor fit simulation
    if (_tickCount % 40 == 0) {
      _sensorFit = false;
    } else if ((_tickCount % 40) == 3) {
      _sensorFit = true;
    }

    // State machine updates
    switch (_simMode) {
      case SimulationMode.normal:
        // Behavior 2: Activity burst every 15 ticks
        if (_tickCount % 15 == 0) {
          _simMode = SimulationMode.activity;
          _activityTicksRemaining = 8; // 3 spike + 5 recovery
          _targetHr = 95.0 + _random.nextInt(16); // 95-110
          _targetSpo2 = 98.0 - (1.0 + _random.nextDouble()); // Drop 1-2 points
          _transitionTicksTotal = 3;
          _transitionTicksElapsed = 0;
        } else {
          // Behavior 1: Normal baseline drift (random walk)
          _hr = (_hr + (_random.nextDouble() * 2 - 1)).clamp(40.0, 180.0);
          _spo2 = (_spo2 + (_random.nextDouble() * 0.6 - 0.3)).clamp(94.0, 100.0);
          _temp = _temp + (_random.nextDouble() * 0.1 - 0.05);
        }
        break;

      case SimulationMode.activity:
        _activityTicksRemaining--;
        if (_activityTicksRemaining >= 5) {
          // Spike phase (first 3 ticks)
          _transitionTicksElapsed++;
          _hr += (_targetHr - _hr) / (_transitionTicksTotal - _transitionTicksElapsed + 1);
          _spo2 += (_targetSpo2 - _spo2) / (_transitionTicksTotal - _transitionTicksElapsed + 1);
        } else if (_activityTicksRemaining == 4) {
          // Setup recovery phase
          _targetHr = 72.0;
          _targetSpo2 = 98.0;
          _transitionTicksTotal = 5;
          _transitionTicksElapsed = 1;
          _hr += (_targetHr - _hr) / (_transitionTicksTotal - _transitionTicksElapsed + 1);
          _spo2 += (_targetSpo2 - _spo2) / (_transitionTicksTotal - _transitionTicksElapsed + 1);
        } else if (_activityTicksRemaining >= 0) {
          // Continue recovery
          _transitionTicksElapsed++;
          _hr += (_targetHr - _hr) / (_transitionTicksTotal - _transitionTicksElapsed + 1);
          _spo2 += (_targetSpo2 - _spo2) / (_transitionTicksTotal - _transitionTicksElapsed + 1);
        }

        if (_activityTicksRemaining <= 0) {
          _simMode = SimulationMode.normal;
        }
        break;

      case SimulationMode.emergency:
        if (_transitionTicksElapsed < _transitionTicksTotal) {
          _transitionTicksElapsed++;
          _hr += (_targetHr - _hr) / (_transitionTicksTotal - _transitionTicksElapsed + 1);
          _spo2 += (_targetSpo2 - _spo2) / (_transitionTicksTotal - _transitionTicksElapsed + 1);
        }
        break;

      case SimulationMode.recovery:
        _recoveryTicksRemaining--;
        _transitionTicksElapsed++;
        if (_transitionTicksElapsed <= _transitionTicksTotal) {
          _hr += (_targetHr - _hr) / (_transitionTicksTotal - _transitionTicksElapsed + 1);
          _spo2 += (_targetSpo2 - _spo2) / (_transitionTicksTotal - _transitionTicksElapsed + 1);
        }
        
        if (_recoveryTicksRemaining <= 0) {
          _simMode = SimulationMode.normal;
        }
        break;
    }

    // Behavior 8: Safeguards
    _hr = _hr.clamp(30.0, 200.0);
    _spo2 = _spo2.clamp(70.0, 100.0);
    _temp = _temp.clamp(30.0, 42.0);

    // Behavior 7: Logging
    if (_tickCount % 10 == 0) {
      debugPrint('[SimRepo] Tick: $_tickCount | HR: ${_hr.toStringAsFixed(1)} | SpO2: ${_spo2.toStringAsFixed(1)} | Mode: ${_simMode.name}');
    }

    _controller.add(VitalsModel(
      hr: _hr.round(),
      spo2: double.parse(_spo2.toStringAsFixed(1)),
      temp: double.parse(_temp.toStringAsFixed(1)),
      fall: _fall,
      sos: _sos,
      bat: double.parse(_bat.toStringAsFixed(1)),
      heatStress: _heatStress,
      sensorFit: _sensorFit,
      mode: _modeLabel,
    ));
  }

  @override
  Stream<VitalsModel> get vitalsStream => _controller.stream;

  @override
  void triggerEmergency() {
    // Behavior 3: Do not re-trigger if already in emergency
    if (_simMode == SimulationMode.emergency) return;

    _simMode = SimulationMode.emergency;
    _transitionTicksElapsed = 0;

    if (_emergencyToggleA) {
      // Mode A: Fall
      _fall = true;
      _targetHr = 45.0;
      _targetSpo2 = 88.0;
      _transitionTicksTotal = 4;
    } else {
      // Mode B: SpO2 Critical
      _fall = false;
      _targetHr = 105.0;
      _targetSpo2 = 86.0;
      _transitionTicksTotal = 6;
    }
    _emergencyToggleA = !_emergencyToggleA;
  }

  @override
  void triggerNormal() {
    // Behavior 4: Gradual recovery over 8 ticks
    _simMode = SimulationMode.recovery;
    _fall = false;
    _sos = false;
    _heatStress = false;
    _sensorFit = true;
    
    _targetHr = 72.0;
    _targetSpo2 = 98.0;
    _transitionTicksTotal = 8;
    _transitionTicksElapsed = 0;
    _recoveryTicksRemaining = 8;
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}

