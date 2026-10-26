# 0050. The connected D435 passes the Phase 6 checks

Date: 2026-10-26
Status: Accepted

## Context

Phase 6 asks for a detected RealSense camera, RGB and depth, ROS topics, an RViz view of the depth, and a reconnect that does not reinstall software. The camera was already installed from the Super+Space menu.

## Decision

- On 2026-10-26 the connected camera was a RealSense D435, serial 213622076118, firmware 5.17.3.10.
- `ros2 launch realsense2_camera rs_launch.py pointcloud.enable:=true` published color at 640×480 and depth at 848×480, both about 30 Hz. The topics were `/camera/camera/color/image_raw` and `/camera/camera/depth/image_rect_raw`.
- RViz opened `/opt/ros/lyrical/share/realsense2_camera/launch/default.rviz` and drew the depth point cloud. The operator confirmed that view.
- The operator unplugged the camera and plugged it back into the same port. `realsense2_camera_node` process 778564, started at 10:21, kept publishing depth at about 30 Hz. Nothing was reinstalled.
- That launch did not enable the infrared streams or the IMU. A camera stream to the second machine was not part of this run.

## Consequences

The Phase 6 acceptance checks are met on this camera. Infrared, IMU, and performance numbers remain unmeasured.
