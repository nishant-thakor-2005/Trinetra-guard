import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'vitals_repository.dart';

// --- EVENTS ---
abstract class VitalsEvent extends Equatable {
  const VitalsEvent();

  @override
  List<Object?> get props => [];
}

class StartMonitoring extends VitalsEvent {}

class StopMonitoring extends VitalsEvent {}

class CancelDeadManSwitch extends VitalsEvent {}

class ResetMonitoring extends VitalsEvent {}

class TriggerEmergencyEvent extends VitalsEvent {}

// Private events to handle asynchronous stream data within the Bloc
class _VitalsReceived extends VitalsEvent {
  final VitalsModel vitals;
  const _VitalsReceived(this.vitals);

  @override
  List<Object?> get props => [vitals];
}

class _CountdownTick extends VitalsEvent {
  final int secondsRemaining;
  const _CountdownTick(this.secondsRemaining);

  @override
  List<Object?> get props => [secondsRemaining];
}


// --- STATES ---
abstract class VitalsState extends Equatable {
  const VitalsState();

  @override
  List<Object?> get props => [];
}

class VitalsInitial extends VitalsState {}

class VitalsMonitoring extends VitalsState {}

class VitalsUpdated extends VitalsState {
  final VitalsModel vitals;
  const VitalsUpdated(this.vitals);

  @override
  List<Object?> get props => [vitals];
}

class DeadManSwitchActive extends VitalsState {
  final DateTime startTime;
  const DeadManSwitchActive(this.startTime);

  @override
  List<Object?> get props => [startTime];
}

class DeadManSwitchTick extends VitalsState {
  final int secondsRemaining;
  const DeadManSwitchTick(this.secondsRemaining);

  @override
  List<Object?> get props => [secondsRemaining];
}

class AlertPipeline extends VitalsState {}


// --- BLOC ---
class VitalsBloc extends Bloc<VitalsEvent, VitalsState> {
  static const int deadManSwitchDuration = 30;

  final VitalsRepository _repository;
  
  StreamSubscription<VitalsModel>? _vitalsSubscription;
  StreamSubscription<int>? _countdownSubscription;

  bool _emergencyActive = false;
  bool _isEmergencySuppressed = false;

  VitalsBloc(this._repository) : super(VitalsInitial()) {
    on<StartMonitoring>(_onStartMonitoring);
    on<StopMonitoring>(_onStopMonitoring);
    on<CancelDeadManSwitch>(_onCancelDeadManSwitch);
    on<ResetMonitoring>(_onResetMonitoring);
    on<TriggerEmergencyEvent>(_onTriggerEmergency);
    on<_VitalsReceived>(_onVitalsReceived);
    on<_CountdownTick>(_onCountdownTick);
  }

  void _onStartMonitoring(StartMonitoring event, Emitter<VitalsState> emit) {
    // 2. Subscribes to repository stream (cancel any existing subscription)
    _vitalsSubscription?.cancel();
    _emergencyActive = false;
    _isEmergencySuppressed = false;
    emit(VitalsMonitoring());

    _vitalsSubscription = _repository.vitalsStream.listen(
      (vitals) => add(_VitalsReceived(vitals)),
    );
  }

  void _onStopMonitoring(StopMonitoring event, Emitter<VitalsState> emit) {
    // 9. On StopMonitoring event, cancels all subscriptions
    _vitalsSubscription?.cancel();
    _countdownSubscription?.cancel();
    _emergencyActive = false;
    _isEmergencySuppressed = false;
    emit(VitalsInitial());
  }

  void _onVitalsReceived(_VitalsReceived event, Emitter<VitalsState> emit) {
    // TEMPORARY DEBUG PRINT: Remove after confirming connection
    print("DEBUG: VitalsReceived -> HR: ${event.vitals.hr}, SpO2: ${event.vitals.spo2}, Temp: ${event.vitals.temp}");

    // 3. Emits VitalsUpdated state on each packet
    emit(VitalsUpdated(event.vitals));

    // 4. Detects emergency condition: fall==true OR spo2 < 90
    final isEmergency = event.vitals.fall == true || event.vitals.spo2 < 90;

    if (isEmergency) {
      // 5. Emits DeadManSwitchActive state if not currently active AND not suppressed
      if (!_emergencyActive && !_isEmergencySuppressed) {
        _emergencyActive = true;
        final startTime = DateTime.now();
        emit(DeadManSwitchActive(startTime));

        _startCountdown();
      }
    } else {
      // If vitals return to normal, we clear the suppression flag 
      // so a future emergency can successfully trigger the switch again.
      _isEmergencySuppressed = false;
    }
  }

  void _startCountdown() {
    _countdownSubscription?.cancel();
    
    // 6. Runs a countdown emitting DeadManSwitchTick using Stream.periodic
    _countdownSubscription = Stream.periodic(
      const Duration(seconds: 1), 
      (count) => deadManSwitchDuration - count - 1
    ).take(deadManSwitchDuration).listen((secondsRemaining) {
      add(_CountdownTick(secondsRemaining));
    });
  }

  void _onCountdownTick(_CountdownTick event, Emitter<VitalsState> emit) {
    if (event.secondsRemaining > 0) {
      emit(DeadManSwitchTick(event.secondsRemaining));
    } else {
      // 8. On countdown reaching zero, emits AlertPipeline state
      _countdownSubscription?.cancel();
      emit(AlertPipeline());
    }
  }

  void _onCancelDeadManSwitch(CancelDeadManSwitch event, Emitter<VitalsState> emit) {
    // 7. On CancelDeadManSwitch event, cancels countdown and emits VitalsMonitoring
    _countdownSubscription?.cancel();
    _emergencyActive = false;
    
    // Set suppression flag to ignore subsequent abnormal vitals until they normalize
    _isEmergencySuppressed = true;
    
    emit(VitalsMonitoring());
  }

  void _onResetMonitoring(ResetMonitoring event, Emitter<VitalsState> emit) {
    _countdownSubscription?.cancel();
    _emergencyActive = false;
    
    // Scenario 6: Cooldown after reset (ignore triggers for 3 seconds)
    _isEmergencySuppressed = true;
    Timer(const Duration(seconds: 3), () {
      _isEmergencySuppressed = false;
    });
    
    emit(VitalsMonitoring());
    debugPrint('[DMS] System reset — ready'); // Scenario 5
  }

  void _onTriggerEmergency(TriggerEmergencyEvent event, Emitter<VitalsState> emit) {
    _repository.triggerEmergency();
  }

  @override
  Future<void> close() {
    // 10 & 11. Override close() to cancel all active subscriptions to avoid memory leaks
    _vitalsSubscription?.cancel();
    _countdownSubscription?.cancel();
    return super.close();
  }
}
