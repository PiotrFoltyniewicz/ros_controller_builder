import 'package:flutter/material.dart';
import '../models/custom_controller.dart';
import '../ros_bridge.dart';

class CustomControllerRenderer extends StatelessWidget {
  final CustomController controllerConfig;
  final RosBridge ros;
  final bool enabled;
  final bool isEditing;
  final Function(int index, ControllerComponent newComp)? onComponentUpdated;
  final Function(int index)? onComponentDeleted;

  const CustomControllerRenderer({
    super.key,
    required this.controllerConfig,
    required this.ros,
    this.enabled = true,
    this.isEditing = false,
    this.onComponentUpdated,
    this.onComponentDeleted,
  });

  Color _parseColor(String colorString) {
    if (colorString.startsWith('#')) {
      final hex = colorString.substring(1);
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
    }
    return const Color(0xFF00E5A0);
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _parseColor(controllerConfig.themeColor);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131313),
        border: Border.all(color: themeColor, width: 2),
        borderRadius: BorderRadius.circular(16)
      ),
      // We clip behavior to avoid inputs going out of bound, though 
      // developers should position them carefully in the JSON model.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: controllerConfig.components.asMap().entries.map((entry) {
            final idx = entry.key;
            final comp = entry.value;

            Widget child = _buildComponent(comp, themeColor);
            
            if (isEditing) {
              child = Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onPanUpdate: (details) {
                      if (onComponentUpdated != null) {
                        final newX = comp.x + details.delta.dx;
                        final newY = comp.y + details.delta.dy;
                        onComponentUpdated!(idx, comp.copyWith(x: newX, y: newY));
                      }
                    },
                    onTap: () => _showTopicEditor(context, idx, comp),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.redAccent, width: 2, style: BorderStyle.solid),
                        color: Colors.redAccent.withOpacity(0.1),
                      ),
                      child: Stack(
                        children: [
                          AbsorbPointer(child: child),
                          const Positioned(
                            top: 2, right: 2,
                            child: Icon(Icons.edit, color: Colors.white70, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -10,
                    right: -10,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        if (onComponentUpdated != null) {
                          final newW = (comp.width + details.delta.dx).clamp(40.0, 1000.0);
                          final newH = (comp.height + details.delta.dy).clamp(40.0, 1000.0);
                          onComponentUpdated!(idx, comp.copyWith(width: newW, height: newH));
                        }
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.open_with, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              );
            }

            return Positioned(
              left: comp.x,
              top: comp.y,
              width: comp.width,
              height: comp.height,
              child: child,
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showTopicEditor(BuildContext context, int index, ControllerComponent comp) {
    final tc = TextEditingController(text: comp.topic);
    
    List<String> supportedTypes = [];
    if (comp.type == 'button') {
      supportedTypes = ['std_msgs/Empty', 'std_msgs/String', 'std_msgs/Bool'];
    } else if (comp.type == 'slider') {
      supportedTypes = ['std_msgs/Float64', 'std_msgs/Int32'];
    } else if (comp.type == 'dpad') {
      supportedTypes = ['geometry_msgs/Twist'];
    }

    String currentType = comp.properties['rosType'] ?? (supportedTypes.isNotEmpty ? supportedTypes.first : '');
    if (supportedTypes.isNotEmpty && !supportedTypes.contains(currentType)) {
      currentType = supportedTypes.first;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Edit ${comp.type.toUpperCase()}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tc,
                  decoration: const InputDecoration(labelText: 'Topic name'),
                ),
                const SizedBox(height: 16),
                if (supportedTypes.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: currentType,
                    decoration: const InputDecoration(labelText: 'Message Type'),
                    items: supportedTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => currentType = val);
                      }
                    },
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (onComponentDeleted != null) {
                    onComponentDeleted!(index);
                  }
                  Navigator.pop(ctx);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: const Text('Delete'),
              ),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  final newProps = Map<String, dynamic>.from(comp.properties);
                  if (currentType.isNotEmpty) {
                    newProps['rosType'] = currentType;
                  }
                  if (onComponentUpdated != null) {
                    onComponentUpdated!(index, comp.copyWith(
                      topic: tc.text.trim(),
                      properties: newProps,
                    ));
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildComponent(ControllerComponent comp, Color themeColor) {
    switch (comp.type) {
      case 'dpad':
        return _buildDpad(comp, themeColor);
      case 'button':
        return _buildButton(comp, themeColor);
      case 'slider':
        return _buildSlider(comp, themeColor);
      case 'camera':
        return Container(
          color: Colors.grey[900],
          child: const Center(
            child: Icon(Icons.camera_alt, color: Colors.white54, size: 36),
          ),
        );
      default:
        return Container(
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.3),
            border: Border.all(color: Colors.red, width: 2),
          ),
          child: Center(child: Text("Unknown:\n${comp.type}", textAlign: TextAlign.center, style: const TextStyle(fontSize: 10))),
        );
    }
  }

  Widget _buildDpad(ControllerComponent comp, Color themeColor) {
    final double linearSpeed = (comp.properties['linearSpeed'] ?? 2.0).toDouble();
    final double angularSpeed = (comp.properties['angularSpeed'] ?? 1.8).toDouble();

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Forward
        _DpadButton(
          icon: Icons.arrow_upward_rounded,
          color: themeColor,
          enabled: enabled,
          onPressStart: () => ros.publishTwist(
            topic: comp.topic,
            linearX: linearSpeed
          ),
          onPressEnd: () => ros.stop(topic: comp.topic),
        ),
        // Left / Middle / Right row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _DpadButton(
              icon: Icons.arrow_back_rounded,
              color: themeColor,
              enabled: enabled,
              onPressStart: () => ros.publishTwist(
                topic: comp.topic,
                angularZ: angularSpeed
              ),
              onPressEnd: () => ros.stop(topic: comp.topic),
            ),
            // Reverse button in center
            _DpadButton(
              icon: Icons.arrow_downward_rounded,
              color: themeColor,
              enabled: enabled,
              onPressStart: () => ros.publishTwist(
                topic: comp.topic,
                linearX: -linearSpeed
              ),
              onPressEnd: () => ros.stop(topic: comp.topic),
            ),
            _DpadButton(
              icon: Icons.arrow_forward_rounded,
              color: themeColor,
              enabled: enabled,
              onPressStart: () => ros.publishTwist(
                topic: comp.topic,
                angularZ: -angularSpeed
              ),
              onPressEnd: () => ros.stop(topic: comp.topic),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSlider(ControllerComponent comp, Color themeColor) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? themeColor.withOpacity(0.1) : Colors.white10,
        borderRadius: BorderRadius.circular(comp.height / 2),
        border: Border.all(color: enabled ? themeColor : Colors.white24, width: 2),
      ),
      child: Center(
        child: Slider(
          value: 0.5,
          onChanged: enabled ? (val) {
            // Will add publish logic based on std_msgs/Float64 or int later
          } : null,
          activeColor: themeColor,
          inactiveColor: themeColor.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildButton(ControllerComponent comp, Color themeColor) {
    final label = comp.properties['label']?.toString() ?? '!';
    return GestureDetector(
      // Add logic here to publish simple std_msgs/String or empty to a topic depending on requirements later
      onTap: () {
        if (!enabled) return;
        debugPrint("Button pressed targeting topic ${comp.topic}");
      },
      child: Container(
        decoration: BoxDecoration(
          color: enabled ? themeColor.withOpacity(0.2) : Colors.white10,
          border: Border.all(
            color: enabled ? themeColor : Colors.white24,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: enabled ? themeColor : Colors.white24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _DpadButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;

  const _DpadButton({
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onPressStart,
    required this.onPressEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: enabled ? (_) => onPressStart() : null,
      onTapUp: enabled ? (_) => onPressEnd() : null,
      onTapCancel: enabled ? onPressEnd : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: enabled ? color.withOpacity(0.1) : Colors.white10,
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled ? color.withOpacity(0.5) : Colors.white24,
            width: 2,
          ),
        ),
        child: Icon(
          icon,
          size: 28,
          color: enabled ? color : Colors.white24,
        ),
      ),
    );
  }
}
