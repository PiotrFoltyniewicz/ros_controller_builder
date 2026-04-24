# ROS2 TurtleSim — Docker + WiFi

Run a ROS2 Humble stack (TurtleSim + rosbridge WebSocket) in Docker, reachable from any device on your local WiFi — including a Flutter mobile app.

## Architecture

```
Flutter app (phone)
    |  ws://<HOST_IP>:9090   (rosbridge WebSocket)
    |  http://<HOST_IP>:8080  (web_video_server — optional)
    |
  [ WiFi / LAN ]
    |
Docker container  (network_mode: host)
  ├── turtlesim_node        ← publishes /turtle1/pose, subscribes /turtle1/cmd_vel
  ├── rosbridge_server      ← bridges ROS2 topics ↔ WebSocket JSON
  └── web_video_server      ← streams camera/image topics over HTTP
```

## Quick start

```bash
# 1. Build the image (takes a few minutes first time)
make build

# 2. Start all nodes
make up

# 3. Find your machine's IP
make ip
```

Your Flutter app should connect to `ws://<that IP>:9090`.

## Useful commands

| Command | What it does |
|---|---|
| `make up-d` | Start in background |
| `make logs` | Stream container logs |
| `make shell` | Open bash inside container |
| `make teleop` | Drive turtle from keyboard |
| `make topics` | List all active ROS2 topics |
| `make down` | Stop everything |

## Connecting from Flutter

Install the `roslibdart` package (or use a plain WebSocket + JSON):

```yaml
# pubspec.yaml
dependencies:
  roslibdart: ^0.1.0   # check pub.dev for latest
```

Minimal Flutter snippet:

```dart
import 'package:roslibdart/roslibdart.dart';

final ros = Ros(url: 'ws://192.168.1.x:9090');
await ros.connect();

final cmdVel = Topic(
  ros: ros,
  name: '/turtle1/cmd_vel',
  type: 'geometry_msgs/Twist',
);

// Move forward
await cmdVel.publish({
  'linear':  {'x': 2.0, 'y': 0.0, 'z': 0.0},
  'angular': {'x': 0.0, 'y': 0.0, 'z': 0.0},
});
```

Subscribe to the turtle's pose:

```dart
final pose = Topic(
  ros: ros,
  name: '/turtle1/pose',
  type: 'turtlesim/Pose',
);
pose.subscribe((message) {
  print('x=${message['x']}  y=${message['y']}');
});
```

## Key ROS2 topics

| Topic | Type | Direction |
|---|---|---|
| `/turtle1/cmd_vel` | `geometry_msgs/Twist` | app → turtle |
| `/turtle1/pose` | `turtlesim/Pose` | turtle → app |
| `/turtle1/rotate_absolute/goal` | action | app → turtle |

## Network notes

- The container uses `network_mode: host` — it shares your machine's IP directly. No port-forwarding needed.
- Make sure your firewall allows TCP on ports **9090** and **8080**.
- All ROS2 devices on the same WiFi must share the same `ROS_DOMAIN_ID` (default: 0).
- For production/isolation switch to bridge mode and uncomment the `ports:` block in `docker-compose.yml`.

## Headless vs display

TurtleSim normally opens an X11 window. In Docker it runs **headless by default** — the turtle node still publishes/subscribes to all topics, the graphical window just won't appear. If you want the window, see the commented `DISPLAY`/`X11-unix` lines in `docker-compose.yml`.
