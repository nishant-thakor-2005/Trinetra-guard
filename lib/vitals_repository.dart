import 'dart:async';
import 'dart:math';

class VitalsModel {
  final int hr;
  final double spo2;
  final double temp;
  final bool fall;
  final bool sos;
  final double bat;
  final bool heatStress;
  final bool sensorFit;
  final String mode;

  const VitalsModel({
    required this.hr,
    required this.spo2,
    required this.temp,
    required this.fall,
    required this.sos,
    required this.bat,
    this.heatStress = false,
    this.sensorFit = true,
    this.mode = 'wrist',
  });
}

abstract class VitalsRepository {
  Stream<VitalsModel> get vitalsStream;
  void triggerEmergency();
  void triggerNormal();
}

class SimulatedVitalsRepo implements VitalsRepository {
  final _controller = StreamController<VitalsModel>.broadcast();
  final Random _random = Random();
  Timer? _timer;

  // Baseline state
  int _hr = 72;
  double _spo2 = 98.0;
  double _temp = 36.6;
  bool _fall = false;
  bool _sos = false;
  double _bat = 85.0;
  bool _heatStress = false;
  bool _sensorFit = true;
  String _mode = 'wrist';

  bool _isEmergency = false;

  SimulatedVitalsRepo() {
    _startSimulation();
  }

  void _startSimulation() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      _generateTick();
    });
  }

  void _generateTick() {
    _bat = max(0.0, _bat - 0.1);

    if (_isEmergency) {
      _fall = true;
      _spo2 = 88.0;
      _heatStress = true;
    } else {
      _fall = false;
      _heatStress = false;

      int hrDrift = _random.nextInt(5) - 2;
      _hr = (_hr + hrDrift).clamp(40, 180);

      double spo2Drift = (_random.nextDouble() - 0.5);
      _spo2 = (_spo2 + spo2Drift).clamp(85.0, 100.0);

      double tempDrift = (_random.nextDouble() * 0.2) - 0.1;
      _temp = _temp + tempDrift;
    }

    _controller.add(VitalsModel(
      hr: _hr,
      spo2: double.parse(_spo2.toStringAsFixed(1)),
      temp: double.parse(_temp.toStringAsFixed(1)),
      fall: _fall,
      sos: _sos,
      bat: double.parse(_bat.toStringAsFixed(1)),
      heatStress: _heatStress,
      sensorFit: _sensorFit,
      mode: _mode,
    ));
  }

  @override
  Stream<VitalsModel> get vitalsStream => _controller.stream;

  @override
  void triggerEmergency() {
    _isEmergency = true;
  }

  @override
  void triggerNormal() {
    _isEmergency = false;
    _hr = 72;
    _spo2 = 98.0;
    _temp = 36.6;
    _fall = false;
    _sos = false;
    _heatStress = false;
    _sensorFit = true;
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}

