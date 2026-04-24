#!/bin/bash
set -e

source /opt/ros/humble/setup.bash

echo "========================================="
echo "  ROS2 Humble + TurtleSim"
echo "  rosbridge WebSocket  -> port 9090"
echo "  web_video_server     -> port 8080"
echo "========================================="

# Run all nodes in background, keep container alive
ros2 run turtlesim turtlesim_node &
TURTLE_PID=$!

sleep 2  # wait for turtlesim to register its topics

ros2 launch rosbridge_server rosbridge_websocket_launch.xml &
BRIDGE_PID=$!

ros2 run web_video_server web_video_server &
VIDEO_PID=$!

echo "All nodes started."
echo "  TurtleSim PID : $TURTLE_PID"
echo "  rosbridge PID : $BRIDGE_PID"
echo "  video server  : $VIDEO_PID"
echo ""
echo "Connect your Flutter app to:"
echo "  ws://<HOST_IP>:9090"

# Keep container running; forward signals for clean shutdown
trap "kill $TURTLE_PID $BRIDGE_PID $VIDEO_PID 2>/dev/null; exit 0" SIGTERM SIGINT

wait $TURTLE_PID $BRIDGE_PID $VIDEO_PID
