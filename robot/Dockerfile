FROM ros:humble-ros-base

# Install TurtleSim, rosbridge suite, and web video server
RUN apt-get update && apt-get install -y \
    ros-humble-turtlesim \
    ros-humble-rosbridge-suite \
    ros-humble-web-video-server \
    ros-humble-teleop-twist-keyboard \
    python3-pip \
    ros-humble-rmw-cyclonedds-cpp \
    && rm -rf /var/lib/apt/lists/*

# Create a workspace
WORKDIR /ros2_ws

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Source ROS2 on every shell
RUN echo "source /opt/ros/humble/setup.bash" >> /root/.bashrc

EXPOSE 9090
EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
