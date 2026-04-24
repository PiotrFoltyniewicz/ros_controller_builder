.PHONY: build up down logs shell teleop topics

# Build the Docker image
build:
	docker compose build

# Start the stack
up:
	docker compose up

# Start detached
up-d:
	docker compose up -d

# Stop and remove containers
down:
	docker compose down

# Follow logs
logs:
	docker compose logs -f ros2-turtle

# Open a shell inside the running container
shell:
	docker exec -it ros2_turtle bash

# Drive the turtle from keyboard (runs inside container)
teleop:
	docker exec -it ros2_turtle bash -c \
		"source /opt/ros/humble/setup.bash && \
		 ros2 run teleop_twist_keyboard teleop_twist_keyboard \
		 --ros-args --remap cmd_vel:=/turtle1/cmd_vel"

# List active topics
topics:
	docker exec -it ros2_turtle bash -c \
		"source /opt/ros/humble/setup.bash && ros2 topic list"

# Print your machine's IP (for Flutter app configuration)
ip:
	@echo "Your local IP addresses:"
	@hostname -I
