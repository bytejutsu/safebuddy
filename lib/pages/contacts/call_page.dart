import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CallPage extends StatefulWidget {
  final String contactName;
  final String contactPhone;
  final bool isIncoming;

  const CallPage({
    super.key,
    required this.contactName,
    required this.contactPhone,
    this.isIncoming = false,
  });

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage>
    with SingleTickerProviderStateMixin {
  static const _blue = Color(0xFF2196F3);

  bool _callAccepted = false;
  bool _muted = false;
  bool _speakerOn = false;
  bool _onHold = false;
  int _secondsElapsed = 0;
  Timer? _callTimer;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    if (!widget.isIncoming) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _acceptCall();
      });
    }
  }

  void _acceptCall() {
    setState(() => _callAccepted = true);
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _secondsElapsed++);
    });
  }

  void _endCall() {
    _callTimer?.cancel();
    Get.back();
  }

  String _formatDuration(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isEmpty ? '?' : name[0].toUpperCase();
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D1B2A), Color(0xFF1B2A3B)],
          ),
        ),
        child: SafeArea(
          child: widget.isIncoming && !_callAccepted
              ? _buildIncomingCall()
              : _buildActiveCall(),
        ),
      ),
    );
  }

  Widget _buildIncomingCall() {
    return Column(
      children: [
        const SizedBox(height: 60),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.phone_in_talk,
                  color: Colors.greenAccent, size: 14),
              const SizedBox(width: 6),
              Text('Incoming Voice Call',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8), fontSize: 13)),
            ],
          ),
        ),

        const SizedBox(height: 40),

        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, child) =>
              Transform.scale(scale: _pulseAnim.value, child: child),
          child: Container(
            width: 110, height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                  colors: [Color(0xFF2196F3), Color(0xFF1565C0)]),
              boxShadow: [
                BoxShadow(
                    color: _blue.withOpacity(0.5),
                    blurRadius: 30,
                    spreadRadius: 8),
              ],
            ),
            child: Center(
              child: Text(_initials(widget.contactName),
                  style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ),
        ),

        const SizedBox(height: 28),

        Text(widget.contactName,
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5)),

        const SizedBox(height: 6),

        Text(widget.contactPhone,
            style: TextStyle(
                fontSize: 15, color: Colors.white.withOpacity(0.5))),

        const Spacer(),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 50),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _RoundCallButton(
                icon: Icons.call_end,
                color: Colors.red,
                label: 'Decline',
                size: 68,
                onTap: _endCall,
              ),
              _RoundCallButton(
                icon: Icons.call,
                color: Colors.green,
                label: 'Accept',
                size: 68,
                onTap: _acceptCall,
              ),
            ],
          ),
        ),

        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildActiveCall() {
    return Column(
      children: [
        const SizedBox(height: 50),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7, height: 7,
                decoration: const BoxDecoration(
                    color: Colors.greenAccent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                _onHold ? 'On Hold' : 'Connected',
                style: TextStyle(
                  color: _onHold ? Colors.orangeAccent : Colors.greenAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),

        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
                colors: [Color(0xFF2196F3), Color(0xFF1565C0)]),
            boxShadow: [
              BoxShadow(
                  color: _blue.withOpacity(0.4),
                  blurRadius: 24,
                  spreadRadius: 4),
            ],
          ),
          child: Center(
            child: Text(_initials(widget.contactName),
                style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
        ),

        const SizedBox(height: 20),

        Text(widget.contactName,
            style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white)),

        const SizedBox(height: 8),

        
        Text(
          _callAccepted ? _formatDuration(_secondsElapsed) : 'Connecting...',
          style:
              TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.55)),
        ),

        const Spacer(),


        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ControlButton(
                    icon: _muted ? Icons.mic_off : Icons.mic,
                    label: _muted ? 'Unmute' : 'Mute',
                    active: _muted,
                    activeColor: Colors.red,
                    onTap: () => setState(() => _muted = !_muted),
                  ),
                  _ControlButton(
                    icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
                    label: 'Speaker',
                    active: _speakerOn,
                    activeColor: _blue,
                    onTap: () => setState(() => _speakerOn = !_speakerOn),
                  ),
                  _ControlButton(
                    icon: _onHold ? Icons.play_arrow : Icons.pause,
                    label: _onHold ? 'Resume' : 'Hold',
                    active: _onHold,
                    activeColor: Colors.orange,
                    onTap: () => setState(() => _onHold = !_onHold),
                  ),
                ],
              ),
              const SizedBox(height: 36),
              _RoundCallButton(
                icon: Icons.call_end,
                color: Colors.red,
                label: 'End Call',
                size: 70,
                onTap: _endCall,
              ),
            ],
          ),
        ),

        const SizedBox(height: 60),
      ],
    );
  }
}

class _RoundCallButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final double size;
  final VoidCallback onTap;

  const _RoundCallButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: size, height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 16,
                    spreadRadius: 2),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.42),
          ),
          const SizedBox(height: 10),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.65), fontSize: 13)),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 58, height: 58,
            decoration: BoxDecoration(
              color: active
                  ? activeColor.withOpacity(0.25)
                  : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: active
                    ? activeColor.withOpacity(0.6)
                    : Colors.white.withOpacity(0.1),
                width: 1.5,
              ),
            ),
            child: Icon(icon,
                color: active ? activeColor : Colors.white.withOpacity(0.75),
                size: 26),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.55), fontSize: 12)),
        ],
      ),
    );
  }
}