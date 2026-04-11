#!/usr/bin/env python3
"""
WiVRn Full Body Tracking - Flatpak Compatible Version
Supports running inside WiVRn Flatpak sandbox with argument parsing
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
import argparse
import sys
from collections import deque
from dataclasses import dataclass
from enum import Enum

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class TrackingPoint(Enum):
    """MediaPipe pose landmarks mapped to VR trackers"""
    HEAD = 0
    CHEST = 1
    WAIST = 23
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
    position: tuple
    rotation: tuple
    velocity: tuple
    timestamp: float

class PoseFilter:
    """Kalman-like filter for smooth tracking"""
    def __init__(self, smoothing_factor=0.7):
        self.smoothing_factor = smoothing_factor
        self.previous_position = np.array([0, 0, 0])
        self.previous_velocity = np.array([0, 0, 0])
    
    def update(self, position, dt):
        smoothed = (self.smoothing_factor * position + 
                   (1 - self.smoothing_factor) * self.previous_position)
        
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
        self.calibration_distance = calibration_distance
        self.reference_shoulder_width = reference_shoulder_width
    
    def estimate_depth(self, landmarks, frame_width):
        if landmarks is None or len(landmarks) < 32:
            return self.calibration_distance
        
        left_shoulder = landmarks[11]
        right_shoulder = landmarks[12]
        
        shoulder_distance_pixels = abs(right_shoulder.x - left_shoulder.x) * frame_width
        
        if shoulder_distance_pixels < 10:
            return self.calibration_distance
        
        depth = (self.reference_shoulder_width * frame_width) / shoulder_distance_pixels
        depth = np.clip(depth, 0.3, 4.0)
        
        return depth

class WebcamTracker:
    """Main webcam tracking service"""
    def __init__(self, camera_id=0, output_port=9876, enable_preview=True, 
                 config_file=None, smoothing_factor=0.7, detection_confidence=0.5,
                 tracking_confidence=0.5):
        self.camera_id = camera_id
        self.output_port = output_port
        self.enable_preview = enable_preview
        self.config_file = config_file
        
        # Load config if provided
        if config_file:
            self.load_config(config_file)
        
        # MediaPipe setup
        self.mp_pose = mp.solutions.pose
        self.mp_drawing = mp.solutions.drawing_utils
        self.pose = self.mp_pose.Pose(
            static_image_mode=False,
            model_complexity=1,
            smooth_landmarks=True,
            enable_segmentation=False,
            smooth_segmentation=False,
            min_detection_confidence=detection_confidence,
            min_tracking_confidence=tracking_confidence
        )
        
        # Camera and tracking
        self.cap = None
        self.depth_estimator = DepthEstimator()
        self.filters = {}
        self.running = False
        self.socket = None
        self.smoothing_factor = smoothing_factor
        
        self._initialize_filters()
    
    def load_config(self, config_file):
        """Load configuration from JSON file"""
        try:
            with open(config_file, 'r') as f:
                config = json.load(f)
            
            if 'webcam' in config:
                self.camera_id = config['webcam'].get('camera_id', 0)
                self.enable_preview = config['webcam'].get('enable_preview', True)
            
            if 'pose_estimation' in config:
                self.smoothing_factor = config['pose_estimation'].get('smoothing_factor', 0.7)
            
            logger.info(f"Configuration loaded from: {config_file}")
        except Exception as e:
            logger.warning(f"Failed to load config: {e}")
    
    def _initialize_filters(self):
        """Create filters for all tracking points"""
        for point in TrackingPoint:
            self.filters[point.value] = PoseFilter(self.smoothing_factor)
    
    def setup_camera(self):
        """Initialize webcam"""
        self.cap = cv2.VideoCapture(self.camera_id)
        if not self.cap.isOpened():
            logger.error(f"Failed to open camera {self.camera_id}")
            return False
        
        self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
        self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)
        self.cap.set(cv2.CAP_PROP_FPS, 30)
        self.cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
        
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
        
        tracker_mapping = {
            TrackingPoint.HEAD.value: 11,
            TrackingPoint.CHEST.value: 12,
            TrackingPoint.WAIST.value: 23,
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
            
            x = (landmark.x - 0.5) * 2.0
            y = (0.5 - landmark.y) * 2.0
            z = depth
            
            position = np.array([x, y, z])
            
            if tracker_id in self.filters:
                dt = 0.016
                position, velocity = self.filters[tracker_id].update(position, dt)
            else:
                velocity = np.array([0, 0, 0])
            
            rotation = (0, 0, 0, 1)
            if landmark_idx in [13, 14]:
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
                packet = struct.pack(
                    '=IfffffffffQ',
                    data.device_id,
                    data.position[0], data.position[1], data.position[2],
                    data.rotation[0], data.rotation[1], data.rotation[2], data.rotation[3],
                    data.velocity[0], data.velocity[1], data.velocity[2],
                    int(data.timestamp * 1e6)
                )
                self.socket.send(packet)
            except Exception as e:
                logger.warning(f"Failed to send tracking data: {e}")
    
    def run(self):
        """Main tracking loop"""
        if not self.setup_camera() or not self.setup_socket():
            return
        
        self.running = True
        frame_count = 0
        start_time = time.time()
        
        logger.info("Tracking started. Press 'q' to quit")
        
        try:
            while self.running:
                ret, frame = self.cap.read()
                if not ret:
                    logger.error("Failed to read frame")
                    break
                
                frame = cv2.flip(frame, 1)
                frame_height, frame_width, _ = frame.shape
                
                frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                
                results = self.pose.process(frame_rgb)
                
                if results.pose_landmarks:
                    frame_time = time.time()
                    tracking_data = self.landmarks_to_tracking_data(
                        results.pose_landmarks, frame_width, frame_height, frame_time
                    )
                    
                    if tracking_data:
                        self.send_tracking_data(tracking_data)
                
                if self.enable_preview:
                    if results.pose_landmarks:
                        self.mp_drawing.draw_landmarks(frame, results.pose_landmarks, 
                                                      self.mp_pose.POSE_CONNECTIONS)
                    
                    fps = frame_count / (time.time() - start_time) if start_time else 0
                    cv2.putText(frame, f"FPS: {fps:.1f}", (10, 30),
                              cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
                    cv2.putText(frame, "Press 'q' to quit", (10, 70),
                              cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
                    cv2.imshow('WiVRn FBT - Flatpak', frame)
                    
                    key = cv2.waitKey(1) & 0xFF
                    if key == ord('q'):
                        self.running = False
                
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

def main():
    parser = argparse.ArgumentParser(
        description='WiVRn Full Body Tracking - Flatpak Version'
    )
    parser.add_argument('--config', '-c', type=str,
                       help='Configuration file path')
    parser.add_argument('--camera-id', type=int, default=0,
                       help='Camera device ID (default: 0)')
    parser.add_argument('--port', type=int, default=9876,
                       help='UDP output port (default: 9876)')
    parser.add_argument('--no-preview', dest='enable_preview', action='store_false',
                       help='Disable preview window (default: enabled)')
    parser.add_argument('--smoothing', type=float, default=0.7,
                       help='Pose smoothing factor 0.1-1.0 (default: 0.7)')
    parser.add_argument('--detection-confidence', type=float, default=0.5,
                       help='Detection confidence 0.0-1.0 (default: 0.5)')
    parser.add_argument('--tracking-confidence', type=float, default=0.5,
                       help='Tracking confidence 0.0-1.0 (default: 0.5)')
    
    args = parser.parse_args()
    
    logger.info("=" * 60)
    logger.info("WiVRn Full Body Tracking - Flatpak Version")
    logger.info("=" * 60)
    logger.info(f"Camera ID: {args.camera_id}")
    logger.info(f"Port: {args.port}")
    logger.info(f"Preview: {args.enable_preview}")
    logger.info(f"Smoothing: {args.smoothing}")
    logger.info("=" * 60)
    
    tracker = WebcamTracker(
        camera_id=args.camera_id,
        output_port=args.port,
        enable_preview=args.enable_preview,
        config_file=args.config,
        smoothing_factor=args.smoothing,
        detection_confidence=args.detection_confidence,
        tracking_confidence=args.tracking_confidence
    )
    tracker.run()

if __name__ == '__main__':
    main()
