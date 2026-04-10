#!/usr/bin/env python3
"""
WiVRn Full Body Tracking - Webcam-based Pose Estimation
Uses MediaPipe for real-time pose detection and maps to VR tracking
"""

import cv2
import mediapipe as mp
import numpy as np
import socket
import struct
import json
import threading
import time
import logging
from collections import deque
from dataclasses import dataclass
from enum import Enum

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class TrackingPoint(Enum):
    """MediaPipe pose landmarks mapped to VR trackers"""
    HEAD = 0  # Nose approximation
    CHEST = 1  # Mid-shoulder
    WAIST = 23  # Mid-hip
    LEFT_FOOT = 31
    RIGHT_FOOT = 32
    LEFT_ELBOW = 13
    RIGHT_ELBOW = 14
    LEFT_HAND = 19
    RIGHT_HAND = 20
    LEFT_KNEE = 25
    RIGHT_KNEE = 26

@dataclass
class TrackerData:
    """Tracking data structure sent to OpenXR service"""
    device_id: int
    position: tuple  # (x, y, z)
    rotation: tuple  # (qx, qy, qz, qw) quaternion
    velocity: tuple  # (vx, vy, vz)
    timestamp: float

class PoseFilter:
    """Kalman-like filter for smooth tracking"""
    def __init__(self, smoothing_factor=0.7):
        self.smoothing_factor = smoothing_factor
        self.previous_position = np.array([0, 0, 0])
        self.previous_velocity = np.array([0, 0, 0])
    
    def update(self, position, dt):
        # Exponential smoothing
        smoothed = (self.smoothing_factor * position + 
                   (1 - self.smoothing_factor) * self.previous_position)
        
        # Estimate velocity
        if dt > 0:
            velocity = (smoothed - self.previous_position) / dt
        else:
            velocity = self.previous_velocity
        
        self.previous_position = smoothed
        self.previous_velocity = velocity
        
        return smoothed, velocity

class DepthEstimator:
    """Estimate Z-depth from camera using shoulder width ratio"""
    def __init__(self, calibration_distance=1.5, reference_shoulder_width=0.45):
        self.calibration_distance = calibration_distance  # meters
        self.reference_shoulder_width = reference_shoulder_width  # meters
    
    def estimate_depth(self, landmarks, frame_width):
        """Estimate depth based on shoulder width relative to frame"""
        if landmarks is None or len(landmarks) < 32:
            return self.calibration_distance
        
        left_shoulder = landmarks[11]
        right_shoulder = landmarks[12]
        
        shoulder_distance_pixels = abs(right_shoulder.x - left_shoulder.x) * frame_width
        
        if shoulder_distance_pixels < 10:
            return self.calibration_distance
        
        # Inverse relationship: wider shoulders = closer to camera
        depth = (self.reference_shoulder_width * frame_width) / shoulder_distance_pixels
        depth = np.clip(depth, 0.3, 4.0)  # 30cm to 4m
        
        return depth

class WebcamTracker:
    """Main webcam tracking service"""
    def __init__(self, camera_id=0, output_port=9876, enable_preview=True):
        self.camera_id = camera_id
        self.output_port = output_port
        self.enable_preview = enable_preview
        
        # MediaPipe setup
        self.mp_pose = mp.solutions.pose
        self.mp_drawing = mp.solutions.drawing_utils
        self.pose = self.mp_pose.Pose(
            static_image_mode=False,
            model_complexity=1,
            smooth_landmarks=True,
            enable_segmentation=False,
            smooth_segmentation=False,
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5
        )
        
        # Camera and tracking
        self.cap = None
        self.depth_estimator = DepthEstimator()
        self.filters = {}  # Per-tracker smoothing filters
        self.running = False
        self.socket = None
        
        # Calibration
        self.calibration_poses = deque(maxlen=30)
        self.is_calibrated = False
        self.person_offset = np.array([0, 0, 0])  # XYZ offset for VR space
        
        self._initialize_filters()
    
    def _initialize_filters(self):
        """Create filters for all tracking points"""
        for point in TrackingPoint:
            self.filters[point.value] = PoseFilter()
    
    def setup_camera(self):
        """Initialize webcam"""
        self.cap = cv2.VideoCapture(self.camera_id)
        if not self.cap.isOpened():
            logger.error(f"Failed to open camera {self.camera_id}")
            return False
        
        # Set camera properties for better tracking
        self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
        self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)
        self.cap.set(cv2.CAP_PROP_FPS, 30)
        self.cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)  # Minimal buffering
        
        logger.info(f"Camera {self.camera_id} initialized")
        return True
    
    def setup_socket(self):
        """Create UDP socket for sending tracking data"""
        try:
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            self.socket.connect(('127.0.0.1', self.output_port))
            logger.info(f"Socket connected to localhost:{self.output_port}")
            return True
        except Exception as e:
            logger.error(f"Failed to setup socket: {e}")
            return False
    
    def quaternion_from_vectors(self, vec1, vec2):
        """Calculate rotation quaternion between two 3D vectors"""
        vec1 = np.array(vec1, dtype=float)
        vec2 = np.array(vec2, dtype=float)
        
        vec1 = vec1 / (np.linalg.norm(vec1) + 1e-10)
        vec2 = vec2 / (np.linalg.norm(vec2) + 1e-10)
        
        cross = np.cross(vec1, vec2)
        w = 1 + np.dot(vec1, vec2)
        
        if np.linalg.norm(cross) < 1e-6:
            if w > 0:
                return (0, 0, 0, 1)
            else:
                return (1, 0, 0, 0)
        
        q = np.concatenate([cross, [w]])
        q = q / (np.linalg.norm(q) + 1e-10)
        return tuple(q)
    
    def landmarks_to_tracking_data(self, landmarks, frame_width, frame_height, frame_time):
        """Convert MediaPipe landmarks to tracker data"""
        if landmarks is None or len(landmarks) < 33:
            return None
        
        depth = self.depth_estimator.estimate_depth(landmarks, frame_width)
        tracking_data = {}
        
        # Map each landmark to VR tracker
        tracker_mapping = {
            TrackingPoint.HEAD.value: 11,  # Nose
            TrackingPoint.CHEST.value: 12,  # Mid-shoulder
            TrackingPoint.WAIST.value: 23,  # Mid-hip
            TrackingPoint.LEFT_FOOT.value: 31,
            TrackingPoint.RIGHT_FOOT.value: 32,
            TrackingPoint.LEFT_ELBOW.value: 13,
            TrackingPoint.RIGHT_ELBOW.value: 14,
            TrackingPoint.LEFT_HAND.value: 19,
            TrackingPoint.RIGHT_HAND.value: 20,
            TrackingPoint.LEFT_KNEE.value: 25,
            TrackingPoint.RIGHT_KNEE.value: 26,
        }
        
        for tracker_id, landmark_idx in tracker_mapping.items():
            landmark = landmarks[landmark_idx]
            
            # Convert normalized coordinates to 3D space
            x = (landmark.x - 0.5) * 2.0  # -1 to 1
            y = (0.5 - landmark.y) * 2.0  # Invert Y, -1 to 1
            z = depth
            
            position = np.array([x, y, z])
            
            # Apply smoothing filter
            if tracker_id in self.filters:
                dt = 0.016  # 60fps assumed
                position, velocity = self.filters[tracker_id].update(position, dt)
            else:
                velocity = np.array([0, 0, 0])
            
            # Estimate rotation from neighboring joints
            rotation = (0, 0, 0, 1)  # Identity quaternion
            if landmark_idx in [13, 14]:  # Elbows - calculate from shoulder-wrist
                shoulder_idx = 11 if landmark_idx == 13 else 12
                hand_idx = 19 if landmark_idx == 13 else 20
                
                shoulder = np.array([landmarks[shoulder_idx].x, 
                                    landmarks[shoulder_idx].y, 0])
                hand = np.array([landmarks[hand_idx].x, 
                               landmarks[hand_idx].y, 0])
                arm_dir = hand - shoulder
                rotation = self.quaternion_from_vectors([0, 1, 0], arm_dir)
            
            tracking_data[tracker_id] = TrackerData(
                device_id=tracker_id,
                position=tuple(position),
                rotation=rotation,
                velocity=tuple(velocity),
                timestamp=frame_time
            )
        
        return tracking_data
    
    def send_tracking_data(self, tracking_data):
        """Send tracking data via UDP socket"""
        if not self.socket or not tracking_data:
            return
        
        for tracker_id, data in tracking_data.items():
            try:
                # Pack data: id, pos(3), rot(4), vel(3), timestamp
                packet = struct.pack(
                    '=IfffffffffQ',
                    data.device_id,
                    data.position[0], data.position[1], data.position[2],
                    data.rotation[0], data.rotation[1], data.rotation[2], data.rotation[3],
                    data.velocity[0], data.velocity[1], data.velocity[2],
                    int(data.timestamp * 1e6)  # Microseconds
                )
                self.socket.send(packet)
            except Exception as e:
                logger.warning(f"Failed to send tracking data: {e}")
    
    def calibrate(self):
        """Simple calibration: average poses over ~1 second"""
        logger.info("Calibration started - stand in T-pose for 2 seconds")
        time.sleep(2)
        
        if len(self.calibration_poses) > 0:
            avg_pose = np.mean(list(self.calibration_poses), axis=0)
            self.person_offset = avg_pose
            self.is_calibrated = True
            logger.info("Calibration complete")
        else:
            logger.warning("Calibration failed - no poses recorded")
    
    def run(self):
        """Main tracking loop"""
        if not self.setup_camera() or not self.setup_socket():
            return
        
        self.running = True
        frame_count = 0
        start_time = time.time()
        
        logger.info("Tracking started. Press 'c' to calibrate, 'q' to quit")
        
        try:
            while self.running:
                ret, frame = self.cap.read()
                if not ret:
                    logger.error("Failed to read frame")
                    break
                
                # Flip for selfie view
                frame = cv2.flip(frame, 1)
                frame_height, frame_width, _ = frame.shape
                
                # Convert to RGB for MediaPipe
                frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                
                # Get pose
                results = self.pose.process(frame_rgb)
                
                if results.pose_landmarks:
                    frame_time = time.time()
                    tracking_data = self.landmarks_to_tracking_data(
                        results.pose_landmarks, frame_width, frame_height, frame_time
                    )
                    
                    if tracking_data:
                        self.send_tracking_data(tracking_data)
                        
                        # Store for calibration
                        if not self.is_calibrated:
                            poses = np.array([
                                [lm.x, lm.y, lm.z] for lm in results.pose_landmarks
                            ])
                            self.calibration_poses.append(np.mean(poses, axis=0))
                    
                    # Draw skeleton
                    if self.enable_preview:
                        self.mp_drawing.draw_landmarks(frame, results.pose_landmarks, 
                                                      self.mp_pose.POSE_CONNECTIONS)
                
                # Display info
                if self.enable_preview:
                    fps = frame_count / (time.time() - start_time)
                    status = "CALIBRATED" if self.is_calibrated else "CALIBRATING"
                    cv2.putText(frame, f"FPS: {fps:.1f} | {status}", (10, 30),
                              cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
                    cv2.putText(frame, "Press 'c' for calibration, 'q' to quit", (10, 70),
                              cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
                    cv2.imshow('WiVRn Full Body Tracking', frame)
                    
                    key = cv2.waitKey(1) & 0xFF
                    if key == ord('q'):
                        self.running = False
                    elif key == ord('c'):
                        threading.Thread(target=self.calibrate, daemon=True).start()
                
                frame_count += 1
        
        except KeyboardInterrupt:
            logger.info("Interrupted by user")
        finally:
            self.cleanup()
    
    def cleanup(self):
        """Cleanup resources"""
        self.running = False
        if self.cap:
            self.cap.release()
        if self.socket:
            self.socket.close()
        cv2.destroyAllWindows()
        logger.info("Cleanup complete")

if __name__ == '__main__':
    tracker = WebcamTracker(camera_id=0, output_port=9876, enable_preview=True)
    tracker.run()
