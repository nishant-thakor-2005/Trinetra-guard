import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import 'vitals_bloc.dart';
import 'vitals_repository.dart';

// ─── Design Tokens ───────────────────────────────────────────────────────────
class _T {
  static const bg = Color(0xFF0A0A0A);
  static const surface = Color(0xFF141414);
  static const surface2 = Color(0xFF1C1C1E);
  static const accentGreen = Color(0xFF00E5CC);
  static const accentAmber = Color(0xFFF5A623);
  static const accentRed = Color(0xFFFF3B30);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textMuted = Color(0x66FFFFFF);    // 40% opacity
  static const textSecondary = Color(0xA6FFFFFF); // 65% opacity

  static Color spo2Arc(double spo2) {
    if (spo2 >= 94) return accentGreen;
    if (spo2 >= 90) return accentAmber;
    return accentRed;
  }
}

// ─── HomeScreen ───────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Tracks the "connected" status for the BLE dot — toggled by vitals arriving
  bool _bleConnected = false;
  String _lastUpdated = "--:--:--";
  bool _demoMode = false; // Demo mode flag for presentation safety

  @override
  Widget build(BuildContext context) {
    return BlocListener<VitalsBloc, VitalsState>(
      listener: (context, state) {
        if (state is VitalsUpdated) {
          final now = DateTime.now();
          setState(() {
            _lastUpdated = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
          });
        }
      },
      child: Scaffold(
        backgroundColor: _T.bg,
        body: SafeArea(
          child: BlocBuilder<VitalsBloc, VitalsState>(
            builder: (context, state) {
              // Extract vitals from state (null-safe)
              VitalsModel? vitals;
              if (state is VitalsUpdated) {
                vitals = state.vitals;
                _bleConnected = true;
              }

              return Column(
                children: [
                  _buildTopBar(_bleConnected),
                  Expanded(child: _buildContent(context, vitals)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ─── Section 1: Top Bar ─────────────────────────────────────────────────
  Widget _buildTopBar(bool connected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'TRINETRA',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _T.textMuted,
              letterSpacing: 4,
            ),
          ),
          Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'DEMO',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: _demoMode ? _T.accentAmber : _T.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 12,
                    width: 24,
                    child: Transform.scale(
                      scale: 0.6,
                      child: Switch(
                        value: _demoMode,
                        onChanged: (v) => setState(() => _demoMode = v),
                        activeColor: _T.accentAmber,
                        activeTrackColor: _T.accentAmber.withOpacity(0.2),
                        inactiveThumbColor: _T.textMuted,
                        inactiveTrackColor: Colors.white10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              _BleDot(connected: connected),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Main content scrollable area ────────────────────────────────────────
  Widget _buildContent(BuildContext context, VitalsModel? vitals) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 8),
            _buildVitalsRing(vitals?.spo2 ?? 0.0),
            const SizedBox(height: 32),
            _buildSecondaryCards(vitals),
            const SizedBox(height: 8),
            Text(
              "Updated: $_lastUpdated",
              style: const TextStyle(fontSize: 10, color: Colors.white54),
            ),
            const SizedBox(height: 12),
            _buildStatusChips(
              heatStress: vitals?.heatStress ?? false,
              sensorFit: vitals?.sensorFit ?? true,
            ),
            const SizedBox(height: 16),
            _buildModeIndicator(vitals?.mode ?? 'wrist'),
            const SizedBox(height: 32),
            _buildEmergencyButton(context),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ─── Section 2: SpO2 Radial Ring ────────────────────────────────────────
  Widget _buildVitalsRing(double spo2) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: spo2),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, animatedSpo2, _) {
        return SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Arc painter
              CustomPaint(
                size: const Size(220, 220),
                painter: _SpO2ArcPainter(
                  value: animatedSpo2,
                  color: _T.spo2Arc(animatedSpo2),
                ),
              ),
              // Center text
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    spo2 > 0 ? animatedSpo2.toStringAsFixed(0) : '--',
                    style: GoogleFonts.inter(
                      fontSize: 52,
                      fontWeight: FontWeight.w700,
                      color: _T.textPrimary,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'SPO2',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: _T.textMuted,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Section 3: Secondary Vitals Cards ──────────────────────────────────
  Widget _buildSecondaryCards(VitalsModel? vitals) {
    return Row(
      children: [
        Expanded(
          child: _VitalCard(
            icon: _PulseIcon(),
            value: vitals?.hr.toString() ?? '--',
            label: 'BPM',
            targetValue: vitals?.hr.toDouble() ?? 0,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _VitalCard(
            icon: const _ThermometerIcon(),
            value: vitals != null ? vitals.temp.toStringAsFixed(1) : '--',
            label: '°C',
            targetValue: vitals?.temp ?? 0,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _VitalCard(
            icon: const _BatteryIcon(),
            value: vitals != null ? vitals.bat.toStringAsFixed(0) : '--',
            label: 'BAT %',
            targetValue: vitals?.bat ?? 0.0,
          ),
        ),
      ],
    );
  }

  // ─── Section 4: Status Chips ────────────────────────────────────────────
  Widget _buildStatusChips({required bool heatStress, required bool sensorFit}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StatusChip(
          label: 'SENSOR FIT',
          active: sensorFit,
          activeColor: _T.accentGreen,
          inactiveColor: _T.accentAmber,
        ),
        const SizedBox(width: 10),
        _StatusChip(
          label: 'HEAT STRESS',
          active: heatStress,
          activeColor: _T.accentRed,
          inactiveColor: _T.accentGreen,
        ),
      ],
    );
  }

  // ─── Section 5: Mode Indicator ──────────────────────────────────────────
  Widget _buildModeIndicator(String mode) {
    final label = mode == 'chest' ? 'CHEST MODE' : 'WRIST MODE';
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w400,
        color: _T.textPrimary.withOpacity(0.3),
        letterSpacing: 2,
      ),
    );
  }

  // ─── Section 6: Emergency Trigger Button ─────────────────────────────────
  Widget _buildEmergencyButton(BuildContext context) {
    return _EmergencyButton(
      onPressed: () {
        if (_demoMode) {
          // Force trigger using simulated logic for the demo
          SimulatedVitalsRepo().triggerEmergency();
        } else {
          context.read<VitalsBloc>().add(TriggerEmergencyEvent());
        }
      },
    );
  }
}

// ─── SpO2 Arc Custom Painter ─────────────────────────────────────────────────
class _SpO2ArcPainter extends CustomPainter {
  final double value;
  final Color color;

  _SpO2ArcPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 8.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth;
    const startAngle = -math.pi * 0.75;
    const totalSweep = math.pi * 1.5;

    // Background arc
    final bgPaint = Paint()
      ..color = const Color(0xFF2A2A2E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweep,
      false,
      bgPaint,
    );

    if (value <= 0) return;

    // Foreground arc
    final fraction = ((value - 85.0) / 15.0).clamp(0.0, 1.0);
    final sweepAngle = totalSweep * fraction;

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_SpO2ArcPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}

// ─── Vital Card Widget ────────────────────────────────────────────────────────
class _VitalCard extends StatefulWidget {
  final Widget icon;
  final String value;
  final String label;
  final double targetValue;

  const _VitalCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.targetValue,
  });

  @override
  State<_VitalCard> createState() => _VitalCardState();
}

class _VitalCardState extends State<_VitalCard> {
  double _previousValue = 0;
  bool _isGlowing = false;

  @override
  void didUpdateWidget(covariant _VitalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.targetValue - oldWidget.targetValue).abs() >= 5) {
      setState(() { _isGlowing = true; });
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() { _isGlowing = false; });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        boxShadow: _isGlowing 
            ? [BoxShadow(color: _T.accentGreen.withOpacity(0.3), blurRadius: 12, spreadRadius: 2)] 
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.icon,
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: widget.targetValue),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            builder: (_, animVal, __) {
              final display = widget.targetValue == 0 ? '--' : widget.value;
              return Text(
                display,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: _T.textPrimary,
                  height: 1,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            widget.label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w400,
              color: _T.textMuted,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status Chip ─────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final Color inactiveColor;

  const _StatusChip({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = active ? activeColor : inactiveColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: dotColor,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── BLE Status Dot ──────────────────────────────────────────────────────────
class _BleDot extends StatelessWidget {
  final bool connected;
  const _BleDot({required this.connected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: connected ? _T.accentGreen : const Color(0xFF3A3A3C),
        shape: BoxShape.circle,
        boxShadow: connected
            ? [BoxShadow(color: _T.accentGreen.withOpacity(0.6), blurRadius: 6, spreadRadius: 1)]
            : [],
      ),
    );
  }
}

// ─── Emergency Button (with press animation) ──────────────────────────────────
class _EmergencyButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _EmergencyButton({required this.onPressed});

  @override
  State<_EmergencyButton> createState() => _EmergencyButtonState();
}

class _EmergencyButtonState extends State<_EmergencyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handlePress() async {
    await _controller.forward();
    widget.onPressed();
    await _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: (_) => _handlePress(),
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: _T.accentRed.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _T.accentRed.withOpacity(0.3),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            'SIMULATE EMERGENCY',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _T.accentRed,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Icon Widgets (pure Canvas, no SVG dependency) ───────────────────────────
class _PulseIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: CustomPaint(painter: _PulseLinePainter()),
    );
  }
}

class _PulseLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _T.textMuted
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final w = size.width;
    final h = size.height;
    path.moveTo(0, h * 0.5);
    path.lineTo(w * 0.2, h * 0.5);
    path.lineTo(w * 0.3, h * 0.1);
    path.lineTo(w * 0.45, h * 0.9);
    path.lineTo(w * 0.6, h * 0.5);
    path.lineTo(w * 0.75, h * 0.3);
    path.lineTo(w * 0.85, h * 0.5);
    path.lineTo(w, h * 0.5);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _ThermometerIcon extends StatelessWidget {
  const _ThermometerIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: CustomPaint(painter: _ThermometerPainter()),
    );
  }
}

class _ThermometerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _T.textMuted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    // Stem
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height * 0.6), paint);
    // Bulb
    final fill = Paint()
      ..color = _T.textMuted
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, size.height * 0.8), size.width * 0.22, fill);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _BatteryIcon extends StatelessWidget {
  const _BatteryIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: CustomPaint(painter: _BatteryPainter()),
    );
  }
}

class _BatteryPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _T.textMuted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height * 0.2, size.width * 0.86, size.height * 0.6),
      const Radius.circular(2),
    );
    canvas.drawRRect(body, paint);

    // Positive terminal nub
    final nubPaint = Paint()
      ..color = _T.textMuted
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.88, size.height * 0.37, size.width * 0.12, size.height * 0.26),
      nubPaint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}


