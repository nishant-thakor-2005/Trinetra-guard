
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'vitals_repository.dart';
import 'vitals_bloc.dart';
import 'dead_man_switch_overlay.dart';
import 'alert_service.dart';
import 'home_screen.dart';

// Top-level singletons (Mistake 2 fix — never inside builders)
final vitalsRepo = SimulatedVitalsRepo();
final alertService = AlertService(FirebaseDatabase.instance);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyCDzFAHAbKgrfqHyR0v0KqA6__m1RSGaIw",
      authDomain: "trinetra-guard.firebaseapp.com",
      projectId: "trinetra-guard",
      storageBucket: "trinetra-guard.firebasestorage.app",
      messagingSenderId: "233985015108",
      appId: "1:233985015108:web:39c77b8d1bbe74add26b11",
    ),
  );

  runApp(
    BlocProvider(
      create: (context) => VitalsBloc(vitalsRepo),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _AppShell(),
    );
  }
}

/// _AppShell — orchestrates overlay, alert pipeline, and emergency BLoC listener.
/// Renders the new premium HomeScreen as its visual child.
class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  OverlayEntry? _overlayEntry;
  VitalsModel? _lastKnownVitals;

  @override
  void initState() {
    super.initState();
    context.read<VitalsBloc>().add(StartMonitoring());
  }

  @override
  void dispose() {
    _removeOverlay(); // Mistake 4 safety net
    super.dispose();
  }

  void _showOverlay(BuildContext context) {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return BlocBuilder<VitalsBloc, VitalsState>(
          buildWhen: (previous, current) => current is DeadManSwitchTick,
          builder: (context, state) {
            int seconds = VitalsBloc.deadManSwitchDuration;
            if (state is DeadManSwitchTick) {
              seconds = state.secondsRemaining;
            }
            return DeadManSwitchOverlay(
              secondsRemaining: seconds,
              onCancel: () {
                context.read<VitalsBloc>().add(CancelDeadManSwitch());
                vitalsRepo.triggerNormal();
              },
            );
          },
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<VitalsBloc, VitalsState>(
      listener: (context, state) async {
        if (state is VitalsUpdated) {
          _lastKnownVitals = state.vitals;
        } else if (state is DeadManSwitchActive) {
          _showOverlay(context);
        } else if (state is VitalsMonitoring) {
          _removeOverlay();
        } else if (state is AlertPipeline) {
          _removeOverlay();
          vitalsRepo.triggerNormal();
          if (_lastKnownVitals != null) {
            final success = await alertService.triggerAlert(_lastKnownVitals!);

            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  success
                      ? "🚨 Alert Sent! Check WhatsApp."
                      : "⚠️ Offline: Alert queued and retrying...",
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: success ? Colors.green : Colors.orange,
              ),
            );
          }
        }
      },
      // The visual layer is now entirely the premium HomeScreen
      child: const HomeScreen(),
    );
  }
}