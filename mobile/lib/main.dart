import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'ros_bridge.dart';
import 'models/custom_controller.dart';
import 'widgets/custom_controller_renderer.dart';

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
      home: const MainMenuPage(),
    );
  }
}

// ---------------------------------------------------------------------------
// Main Menu page
// ---------------------------------------------------------------------------

class MainMenuPage extends StatefulWidget {
  const MainMenuPage({super.key});

  @override
  State<MainMenuPage> createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage> {
  final _ros = RosBridge();
  final _hostController = TextEditingController(text: '192.168.1.x');

  List<CustomController> _presets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final controllerPaths = manifest.listAssets()
          .where((String key) => key.startsWith('assets/controllers/') && key.endsWith('.json'))
          .toList();

      List<CustomController> loaded = [];
      for (String path in controllerPaths) {
        final jsonStr = await rootBundle.loadString(path);
        loaded.add(CustomController.fromJson(jsonDecode(jsonStr), sourcePath: path));
      }

      setState(() {
        _presets = loaded;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Failed to load presets: $e');
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _ros.dispose();
    _hostController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final host = _hostController.text.trim();
    await _ros.connect(host);
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

  Color _parseColor(String colorString) {
    if (colorString.startsWith('#')) {
      final hex = colorString.substring(1);
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
    }
    return const Color(0xFF00E5A0);
  }

  void _openController(CustomController config) {
    // Advertise needed topics
    if (_ros.status == ConnectionStatus.connected) {
      for (final comp in config.components) {
        if (comp.type == 'dpad') {
          _ros.advertise(topic: comp.topic);
        }
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ControllerPage(
          controllerConfig: config,
          ros: _ros,
        ),
      ),
    ).then((_) {
      // Reload presets upon return in case we edited and saved
      setState(() { _loading = true; });
      _loadPresets();
    });
  }

  Future<void> _createNewPreset(BuildContext context) async {
    final tc = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Controller Name'),
        content: TextField(
          controller: tc,
          decoration: const InputDecoration(labelText: 'Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, tc.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    final id = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final fileName = '${id}_${DateTime.now().millisecondsSinceEpoch}.json';
    final path = 'assets/controllers/$fileName';
    final absPath = '/home/piotr/Projects/ros_controller_builder/mobile/$path';

    final newController = CustomController(
      id: id,
      name: name,
      themeColor: '#00E5A0',
      components: [],
      sourcePath: path,
    );

    try {
      final file = File(absPath);
      file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(newController.toJson()));
      setState(() {
        _presets.add(newController);
      });
    } catch (e) {
      debugPrint("Failed to create preset: $e");
    }
  }

  Future<void> _deletePreset(CustomController preset) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Preset?'),
        content: Text('Are you sure you want to delete "${preset.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (preset.sourcePath != null) {
          final file = File('/home/piotr/Projects/ros_controller_builder/mobile/${preset.sourcePath}');
          if (file.existsSync()) {
            file.deleteSync();
          }
        }
        setState(() {
          _presets.removeWhere((p) => p.id == preset.id && p.sourcePath == preset.sourcePath);
        });
      } catch (e) {
        debugPrint("Failed to delete preset: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Persistent Connection Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF161616),
                border: Border(bottom: BorderSide(color: Colors.grey.shade900)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ROS 2 Controller Builder',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _hostController,
                          decoration: InputDecoration(
                            labelText: 'Robot IP',
                            hintText: '192.168.1.x',
                            prefixIcon: const Icon(Icons.wifi, size: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF0D0D0D),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
                                horizontal: 16,
                                vertical: 16,
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
                ],
              ),
            ),
            
            // Presets Grid
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.builder(
                      padding: const EdgeInsets.all(24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: _presets.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _presets.length) {
                          // "Create Controller" tile
                          return InkWell(
                            onTap: () => _createNewPreset(context),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white24, style: BorderStyle.solid),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_circle_outline, size: 48, color: Colors.white54),
                                  SizedBox(height: 12),
                                  Text(
                                    'Create New',
                                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final preset = _presets[index];
                        final cColor = _parseColor(preset.themeColor);
                        return InkWell(
                          onTap: () => _openController(preset),
                          onLongPress: () => _deletePreset(preset),
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: cColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: cColor.withOpacity(0.5)),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.gamepad, size: 48, color: cColor),
                                      const SizedBox(height: 12),
                                      Text(
                                        preset.name,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: cColor, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${preset.components.length} components',
                                        style: TextStyle(color: Colors.white54, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20),
                                  color: Colors.redAccent,
                                  onPressed: () => _deletePreset(preset),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Controller Page
// ---------------------------------------------------------------------------

class ControllerPage extends StatefulWidget {
  final CustomController controllerConfig;
  final RosBridge ros;

  const ControllerPage({
    super.key,
    required this.controllerConfig,
    required this.ros,
  });

  @override
  State<ControllerPage> createState() => _ControllerPageState();
}

class _ControllerPageState extends State<ControllerPage> {
  late CustomController _config;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _config = widget.controllerConfig;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_config.name),
        centerTitle: true,
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.add),
              color: Colors.white,
              onPressed: _showAddComponentDialog,
            ),
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit),
            color: _isEditing ? Colors.greenAccent : Colors.white,
            onPressed: () {
              if (_isEditing) {
                // User is saving edits
                if (_config.sourcePath != null) {
                  try {
                    // Try to save directly to the workspace file if running on a compatible descriptor
                    final file = File('/home/piotr/Projects/ros_controller_builder/mobile/${_config.sourcePath}');
                    if (file.existsSync()) {
                      file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(_config.toJson()));
                    } else {
                      debugPrint("Cannot save to source path natively: file does not exist locally");
                    }
                  } catch (e) {
                    debugPrint("Save failed: $e");
                  }
                }
              }
              setState(() {
                _isEditing = !_isEditing;
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: StreamBuilder<ConnectionStatus>(
            stream: widget.ros.statusStream,
            initialData: widget.ros.status,
            builder: (_, snap) {
              // Disable standard controller output while editing
              final enabled = snap.data == ConnectionStatus.connected && !_isEditing;
              return CustomControllerRenderer(
                controllerConfig: _config,
                ros: widget.ros,
                enabled: enabled,
                isEditing: _isEditing,
                onComponentUpdated: (index, newComp) {
                  setState(() {
                    final newComps = List<ControllerComponent>.from(_config.components);
                    newComps[index] = newComp;
                    _config = _config.copyWith(components: newComps);
                  });
                },
                onComponentDeleted: (index) {
                  setState(() {
                    final newComps = List<ControllerComponent>.from(_config.components);
                    newComps.removeAt(index);
                    _config = _config.copyWith(components: newComps);
                  });
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showAddComponentDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add Component'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.gamepad),
                title: const Text('D-Pad'),
                onTap: () => _addComponent('dpad', 240, 240, {'linearSpeed': 2.0, 'angularSpeed': 1.8}, ctx),
              ),
              ListTile(
                leading: const Icon(Icons.radio_button_checked),
                title: const Text('Button'),
                onTap: () => _addComponent('button', 70, 70, {'label': 'Btn', 'rosType': 'std_msgs/Empty'}, ctx),
              ),
              ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('Slider'),
                onTap: () => _addComponent('slider', 220, 60, {'rosType': 'std_msgs/Float64', 'min': 0.0, 'max': 1.0}, ctx),
              ),
            ],
          ),
        );
      }
    );
  }

  void _addComponent(String type, double width, double height, Map<String, dynamic> props, BuildContext ctx) {
    Navigator.pop(ctx);
    setState(() {
      final newComps = List<ControllerComponent>.from(_config.components);
      newComps.add(
        ControllerComponent(
          type: type,
          topic: '/new_$type',
          x: 20,
          y: 20,
          width: width,
          height: height,
          properties: props,
        )
      );
      _config = _config.copyWith(components: newComps);
    });
  }
}
