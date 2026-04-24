import 'package:flutter/material.dart';
import 'ros_bridge.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Turtle Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E5A0),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
      ),
      home: const ControllerPage(),
    );
  }
}

// ---------------------------------------------------------------------------
// Controller page
// ---------------------------------------------------------------------------

class ControllerPage extends StatefulWidget {
  const ControllerPage({super.key});

  @override
  State<ControllerPage> createState() => _ControllerPageState();
}

class _ControllerPageState extends State<ControllerPage> {
  final _ros = RosBridge();
  final _hostController = TextEditingController(text: '192.168.1.x');

  static const double _speed = 2.0;
  static const double _turnSpeed = 1.8;

  @override
  void dispose() {
    _ros.dispose();
    _hostController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final host = _hostController.text.trim();
    await _ros.connect(host);
    if (_ros.status == ConnectionStatus.connected) {
      _ros.advertise();
    }
  }

  Color _statusColor(ConnectionStatus s) => switch (s) {
        ConnectionStatus.connected => const Color(0xFF00E5A0),
        ConnectionStatus.connecting => Colors.amber,
        ConnectionStatus.error => Colors.redAccent,
        ConnectionStatus.disconnected => Colors.grey,
      };

  String _statusLabel(ConnectionStatus s) => switch (s) {
        ConnectionStatus.connected => 'Connected',
        ConnectionStatus.connecting => 'Connecting…',
        ConnectionStatus.error => 'Error',
        ConnectionStatus.disconnected => 'Disconnected',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────────
              const Text(
                'Turtle Controller',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              StreamBuilder<ConnectionStatus>(
                stream: _ros.statusStream,
                initialData: ConnectionStatus.disconnected,
                builder: (_, snap) {
                  final s = snap.data!;
                  return Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _statusColor(s),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _statusLabel(s),
                        style: TextStyle(color: _statusColor(s), fontSize: 13),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 28),

              // ── Connection row ───────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hostController,
                      decoration: InputDecoration(
                        labelText: 'Robot IP',
                        hintText: '192.168.1.x',
                        prefixIcon: const Icon(Icons.wifi),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1A1A1A),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                  ),
                  const SizedBox(width: 12),
                  StreamBuilder<ConnectionStatus>(
                    stream: _ros.statusStream,
                    initialData: ConnectionStatus.disconnected,
                    builder: (_, snap) {
                      final connected = snap.data == ConnectionStatus.connected;
                      return FilledButton(
                        onPressed: connected ? _ros.disconnect : _connect,
                        style: FilledButton.styleFrom(
                          backgroundColor: connected
                              ? Colors.redAccent
                              : const Color(0xFF00E5A0),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(connected ? 'Disconnect' : 'Connect'),
                      );
                    },
                  ),
                ],
              ),

              const Spacer(),

              // ── Controls ─────────────────────────────────────────────────
              StreamBuilder<ConnectionStatus>(
                stream: _ros.statusStream,
                initialData: ConnectionStatus.disconnected,
                builder: (_, snap) {
                  final enabled = snap.data == ConnectionStatus.connected;
                  return Column(
                    children: [
                      // Forward
                      _ControlButton(
                        icon: Icons.arrow_upward_rounded,
                        label: 'Forward',
                        enabled: enabled,
                        onPressStart: () => _ros.publishTwist(linearX: _speed),
                        onPressEnd: _ros.stop,
                      ),
                      const SizedBox(height: 12),
                      // Left / Right row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ControlButton(
                            icon: Icons.arrow_back_rounded,
                            label: 'Left',
                            enabled: enabled,
                            onPressStart: () =>
                                _ros.publishTwist(angularZ: _turnSpeed),
                            onPressEnd: _ros.stop,
                          ),
                          const SizedBox(width: 12),
                          // Stop button in centre
                          GestureDetector(
                            onTap: enabled ? _ros.stop : null,
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: enabled
                                    ? const Color(0xFF1A1A1A)
                                    : const Color(0xFF111111),
                                borderRadius: BorderRadius.circular(36),
                                border: Border.all(
                                  color: enabled
                                      ? Colors.grey.shade600
                                      : Colors.grey.shade800,
                                ),
                              ),
                              child: Icon(
                                Icons.stop_rounded,
                                size: 32,
                                color: enabled
                                    ? Colors.white70
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _ControlButton(
                            icon: Icons.arrow_forward_rounded,
                            label: 'Right',
                            enabled: enabled,
                            onPressStart: () =>
                                _ros.publishTwist(angularZ: -_turnSpeed),
                            onPressEnd: _ros.stop,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Backward
                      _ControlButton(
                        icon: Icons.arrow_downward_rounded,
                        label: 'Backward',
                        enabled: enabled,
                        onPressStart: () => _ros.publishTwist(linearX: -_speed),
                        onPressEnd: _ros.stop,
                      ),
                    ],
                  );
                },
              ),

              const Spacer(),

              // ── Hint ─────────────────────────────────────────────────────
              Center(
                child: Text(
                  'Hold buttons to move • Release to stop',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable hold-to-move button
// ---------------------------------------------------------------------------

class _ControlButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onPressStart,
    required this.onPressEnd,
  });

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFF00E5A0);

    return GestureDetector(
      onTapDown: widget.enabled
          ? (_) {
              setState(() => _pressed = true);
              widget.onPressStart();
            }
          : null,
      onTapUp: widget.enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onPressEnd();
            }
          : null,
      onTapCancel: widget.enabled
          ? () {
              setState(() => _pressed = false);
              widget.onPressEnd();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: _pressed
              ? accent.withOpacity(0.15)
              : widget.enabled
                  ? const Color(0xFF1A1A1A)
                  : const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _pressed
                ? accent
                : widget.enabled
                    ? Colors.grey.shade700
                    : Colors.grey.shade800,
            width: _pressed ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.icon,
              size: 32,
              color: _pressed
                  ? accent
                  : widget.enabled
                      ? Colors.white70
                      : Colors.grey.shade700,
            ),
            const SizedBox(height: 4),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 10,
                color: _pressed
                    ? accent
                    : widget.enabled
                        ? Colors.white38
                        : Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
