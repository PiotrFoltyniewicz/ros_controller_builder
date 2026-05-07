class ControllerComponent {
  final String type; // e.g., 'dpad', 'button', 'camera'
  final String topic;
  final double x;
  final double y;
  final double width;
  final double height;
  final Map<String, dynamic> properties;

  ControllerComponent({
    required this.type,
    required this.topic,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.properties,
  });

  ControllerComponent copyWith({
    String? type,
    String? topic,
    double? x,
    double? y,
    double? width,
    double? height,
    Map<String, dynamic>? properties,
  }) {
    return ControllerComponent(
      type: type ?? this.type,
      topic: topic ?? this.topic,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      properties: properties ?? Map<String, dynamic>.from(this.properties),
    );
  }

  factory ControllerComponent.fromJson(Map<String, dynamic> json) {
    return ControllerComponent(
      type: json['type'] ?? 'unknown',
      topic: json['topic'] ?? '',
      x: (json['x'] ?? 0.0).toDouble(),
      y: (json['y'] ?? 0.0).toDouble(),
      width: (json['width'] ?? 100.0).toDouble(),
      height: (json['height'] ?? 100.0).toDouble(),
      properties: json['properties'] ?? <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'topic': topic,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'properties': properties,
    };
  }
}

class CustomController {
  final String id;
  final String name;
  final String themeColor;
  final List<ControllerComponent> components;

  CustomController({
    required this.id,
    required this.name,
    required this.themeColor,
    required this.components,
    this.sourcePath,
  });

  final String? sourcePath;

  CustomController copyWith({
    String? id,
    String? name,
    String? themeColor,
    List<ControllerComponent>? components,
    String? sourcePath,
  }) {
    return CustomController(
      id: id ?? this.id,
      name: name ?? this.name,
      themeColor: themeColor ?? this.themeColor,
      components: components ?? List<ControllerComponent>.from(this.components),
      sourcePath: sourcePath ?? this.sourcePath,
    );
  }

  factory CustomController.fromJson(Map<String, dynamic> json, {String? sourcePath}) {
    var compList = json['components'] as List? ?? [];
    return CustomController(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown',
      themeColor: json['themeColor'] ?? '#00E5A0',
      components: compList.map((c) => ControllerComponent.fromJson(c)).toList(),
      sourcePath: sourcePath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'themeColor': themeColor,
      'components': components.map((c) => c.toJson()).toList(),
    };
  }
}