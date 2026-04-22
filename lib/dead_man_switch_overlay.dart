import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DeadManSwitchOverlay extends StatefulWidget {
  final int secondsRemaining;
  final VoidCallback onCancel;

  const DeadManSwitchOverlay({
    super.key,
    required this.secondsRemaining,
    required this.onCancel,
  });

  @override
  State<DeadManSwitchOverlay> createState() => _DeadManSwitchOverlayState();
}

class _DeadManSwitchOverlayState extends State<DeadManSwitchOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();

    // 6. Pulses between red and dark red with 1 second duration
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _colorAnimation = ColorTween(
      begin: Colors.red.withOpacity(0.7),
      end: Colors.red[900]?.withOpacity(0.9),
    ).animate(_pulseController);

    // 7. Haptic feedback once immediately when shown
    HapticFeedback.heavyImpact();
  }

  @override
  void didUpdateWidget(DeadManSwitchOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 7. Haptic feedback every 5 seconds
    if (widget.secondsRemaining != oldWidget.secondsRemaining) {
      if (widget.secondsRemaining % 5 == 0 && widget.secondsRemaining > 0) {
        HapticFeedback.heavyImpact();
      }
    }
  }

  @override
  void dispose() {
    // 8. Clean removal / prevents memory leaks
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 2. Wrap in Material with transparent color so it works correctly if 
    // inserted directly into an OverlayEntry
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _colorAnimation,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            color: _colorAnimation.value,
            // 9. Wrap UI in SafeArea
            child: SafeArea(
              child: child!,
            ),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 4. "EMERGENCY DETECTED..." text above the number
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                "EMERGENCY DETECTED\n—\nPress CANCEL to abort",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 48),
            
            // 3. Large countdown number in the center
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                '${widget.secondsRemaining}',
                key: ValueKey<int>(widget.secondsRemaining),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 140,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
            ),
            
            const SizedBox(height: 64),
            
            // 5. Large white CANCEL button below the number
            ElevatedButton(
              onPressed: widget.onCancel,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red[900],
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 8,
              ),
              child: const Text(
                "CANCEL",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
