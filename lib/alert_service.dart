import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'vitals_repository.dart'; // Ensure VitalsModel is imported

class AlertService {
  // 1. Takes a FirebaseDatabase instance in constructor.
  final FirebaseDatabase _database;
  
  Timer? _retryTimer;
  bool _isAlertActive = false;

  AlertService(this._database);

  // 2. Has a single async method triggerAlert(VitalsModel vitals) that returns Future of bool.
  Future<bool> triggerAlert(VitalsModel vitals) async {
    debugPrint("AlertService: triggerAlert() requested.");

    // 7. Prevent triggering multiple alerts if one is already active.
    if (_isAlertActive) {
      debugPrint("AlertService: Blocked. Alert is already active/queued. Call cancelRetry() to clear.");
      return false;
    }
    
    _isAlertActive = true;

    final payload = {
      'hr': vitals.hr,
      'spo2': vitals.spo2,
      'temp': vitals.temp,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    // 3. Check connectivity using connectivity_plus.
    final hasConnection = await _checkIfOnline();

    if (hasConnection) {
      debugPrint("AlertService: Device is ONLINE. Attempting Firebase write...");
      // 4. If online: writes vitals data to Firebase...
      final success = await _writeToFirebase(payload);
      if (success) {
        debugPrint("AlertService: Firebase write SUCCESS. Alert dispatched.");
        _isAlertActive = false; // Reset so they can immediately test again
        return true;
      } else {
        debugPrint("AlertService: Firebase write FAILED (Possibly Permission Denied or Timeout). Falling back to queue.");
      }
    } else {
      debugPrint("AlertService: Device is OFFLINE. Queuing alert.");
    }

    // 5. If offline or write failed: save to SharedPreferences
    await _saveToPrefs(payload);
    
    // Starts a periodic retry every 30 seconds.
    _startRetryLoop();
    
    return false;
  }

  Future<bool> _checkIfOnline() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      debugPrint("AlertService: Raw connectivity result: $connectivityResult");
      
      bool isOnline = false;
      if (connectivityResult is List<ConnectivityResult>) {
         isOnline = !connectivityResult.contains(ConnectivityResult.none) && connectivityResult.isNotEmpty;
      } else {
         isOnline = connectivityResult != ConnectivityResult.none;
      }
      
      debugPrint("AlertService: Evaluated online status: $isOnline");
      return isOnline;
    } catch (e) {
      debugPrint("AlertService: Error checking connectivity ($e). Defaulting to online.");
      return true; // Fallback to true so Firebase handles errors
    }
  }

  Future<bool> _writeToFirebase(Map<String, dynamic> payload) async {
    try {
      debugPrint("AlertService: Writing to /emergency/active...");
      await _database.ref('/emergency/active').set(payload);
      
      debugPrint("AlertService: Writing true to /test/alert...");
      await _database.ref('/test/alert').set(true);
      
      return true;
    } catch (e) {
      debugPrint("AlertService: 🔥 ERROR writing to Firebase: $e");
      debugPrint("AlertService: Check your Firebase Realtime Database Security Rules!");
      return false;
    }
  }

  Future<void> _saveToPrefs(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_alert', jsonEncode(payload));
  }

  void _startRetryLoop() {
    _retryTimer?.cancel();
    
    // 5. Starts a periodic retry every 30 seconds that checks connectivity and retries the Firebase write.
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      final hasConnection = await _checkIfOnline();

      if (hasConnection) {
        final prefs = await SharedPreferences.getInstance();
        final pendingAlertJson = prefs.getString('pending_alert');
        
        if (pendingAlertJson != null) {
          final payload = jsonDecode(pendingAlertJson) as Map<String, dynamic>;
          final success = await _writeToFirebase(payload);
          
          if (success) {
            // 6. Stop retry loop once alert is successfully sent and remove pending_alert from SharedPreferences.
            await prefs.remove('pending_alert');
            _isAlertActive = false;
            cancelRetry();
          }
        } else {
          // If no pending alert is found, cancel loop.
          _isAlertActive = false;
          cancelRetry();
        }
      }
    });
  }

  // 8. Has a cancelRetry() method.
  void cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _isAlertActive = false;
  }
}
