"""
Human movement humanization for anti-detection.

Generates human-like movement patterns with path inefficiency,
Bezier curves, random pauses, and speed variations to prevent
bot detection through movement pattern analysis.
"""

import math
import random
from enum import Enum
from pathlib import Path
from typing import Optional

import structlog
from pydantic import BaseModel, Field, ConfigDict

logger = structlog.get_logger(__name__)


class MovementPattern(str, Enum):
    """Types of movement patterns."""
    DIRECT = "direct"              # Straight line (suspicious if too common)
    CURVED = "curved"              # Natural curved path
    ZIGZAG = "zigzag"              # Avoiding obstacles (imaginary)
    WANDERING = "wandering"        # Casual exploration
    URGENT = "urgent"              # Quick with shortcuts
    FOLLOWING = "following"        # Following another player


class PathPoint(BaseModel):
    """Point on a movement path."""
    
    model_config = ConfigDict(frozen=False)
    
    x: int = Field(description="X coordinate")
    y: int = Field(description="Y coordinate")
    delay_before_ms: int = Field(default=0, ge=0, description="Pause before moving here")
    is_waypoint: bool = Field(default=False, description="Intentional stop point")
    
    def distance_to(self, other: "PathPoint") -> float:
        """Calculate distance to another point."""
        return math.sqrt((self.x - other.x) ** 2 + (self.y - other.y) ** 2)


class HumanPath(BaseModel):
    """Human-like path with natural variations."""
    
    model_config = ConfigDict(frozen=False)
    
    points: list[PathPoint] = Field(default_factory=list, description="Path waypoints")
    pattern_type: MovementPattern = Field(description="Type of movement pattern")
    total_distance: float = Field(ge=0.0, description="Total path length in cells")
    estimated_time_ms: int = Field(ge=0, description="Estimated completion time")
    
    # Human elements
    path_efficiency: float = Field(
        default=0.85,
        ge=0.5,
        le=1.0,
        description="Path efficiency (0.7-0.95, humans aren't optimal)"
    )
    pause_points: list[int] = Field(
        default_factory=list,
        description="Indices where pauses occur"
    )
    direction_changes: int = Field(default=0, ge=0, description="Number of direction changes")
    
    @property
    def start_point(self) -> Optional[PathPoint]:
        """Get starting point."""
        return self.points[0] if self.points else None
    
    @property
    def end_point(self) -> Optional[PathPoint]:
        """Get ending point."""
        return self.points[-1] if self.points else None
    
    def get_optimal_distance(self) -> float:
        """Calculate optimal straight-line distance."""
        if len(self.points) < 2:
            return 0.0
        start = self.points[0]
        end = self.points[-1]
        return start.distance_to(end)


class MovementHumanizer:
    """
    Generate human-like movement patterns.
    
    Features:
    - Path inefficiency (humans don't walk perfect lines)
    - Random pauses mid-path
    - Curved movements instead of straight
    - Realistic movement speed variation
    - Looking around behavior (camera movement simulation)
    - Collision avoidance patterns
    """
    
    def __init__(self, data_dir: Path | None = None, data_path: Path | None = None):
        self.log = structlog.get_logger()
        self.movement_history: list[HumanPath] = []
        # Support both parameters for backwards compatibility
        final_data_dir = data_dir or data_path or Path("data/mimicry/movement")
        self.data_dir = Path(final_data_dir)
        
        # Movement parameters
        self.base_speed_cells_per_sec = 5.0  # Average walking speed
        self.min_pause_distance = 10  # Minimum distance before pausing
        
        self.log.info("movement_humanizer_initialized", data_dir=str(data_dir))
        
    def humanize_path(self, start: tuple[int, int], end: tuple[int, int], urgency: float = 0.5) -> HumanPath:
        """Convert optimal path to human-like path with natural characteristics."""
        distance = math.sqrt((end[0] - start[0]) ** 2 + (end[1] - start[1]) ** 2)
        
        # Choose pattern and efficiency based on distance and urgency
        if urgency > 0.8:
            pattern, efficiency = MovementPattern.URGENT, 0.95
        elif distance < 5:
            pattern, efficiency = MovementPattern.DIRECT, 0.90
        elif random.random() < 0.3:
            pattern, efficiency = MovementPattern.WANDERING, 0.75
        else:
            pattern, efficiency = MovementPattern.CURVED, random.uniform(0.80, 0.92)
        
        # Generate base path
        points = (
            self.generate_bezier_path(start, end, control_points=2) if pattern == MovementPattern.CURVED else
            self._generate_zigzag_path(start, end) if pattern == MovementPattern.ZIGZAG else
            self._generate_wandering_path(start, end) if pattern == MovementPattern.WANDERING else
            self.generate_bezier_path(start, end, control_points=1)
        )
        
        # Add noise and pauses based on urgency
        if urgency < 0.8:
            points = self.add_path_noise(points, 0.3 if pattern == MovementPattern.WANDERING else 0.15)
        if urgency < 0.7 and distance > self.min_pause_distance:
            points = self.add_pause_points(points, 0.2 if pattern == MovementPattern.WANDERING else 0.1)
        
        # Calculate statistics
        total_distance = sum(points[i].distance_to(points[i + 1]) for i in range(len(points) - 1))
        estimated_time_ms = int((total_distance / (self.base_speed_cells_per_sec * (0.8 + urgency * 0.4))) * 1000)
        
        path = HumanPath(
            points=points,
            pattern_type=pattern,
            total_distance=total_distance,
            estimated_time_ms=estimated_time_ms,
            path_efficiency=efficiency,
            pause_points=[i for i, p in enumerate(points) if p.delay_before_ms > 0],
            direction_changes=self._count_direction_changes(points)
        )
        
        self.movement_history.append(path)
        if len(self.movement_history) > 100:
            self.movement_history.pop(0)
        
        self.log.debug("path_humanized", pattern=pattern.value, distance=round(total_distance, 2), efficiency=round(efficiency, 2))
        return path
    
    def add_path_noise(
        self,
        points: list[PathPoint],
        noise_factor: float = 0.3
    ) -> list[PathPoint]:
        """
        Add natural deviation to path points.
        Not random noise - coherent curves.
        
        Args:
            points: Original path points
            noise_factor: Strength of deviation (0.0-1.0)
            
        Returns:
            Path with natural deviations
        """
        if len(points) <= 2:
            return points
        
        noisy_points = [points[0]]  # Keep start point exact
        
        for i in range(1, len(points) - 1):
            point = points[i]
            
            # Add coherent noise (influenced by neighboring points)
            prev_noise_x = noisy_points[-1].x - points[i - 1].x
            prev_noise_y = noisy_points[-1].y - points[i - 1].y
            
            # Continue previous deviation trend with random variation
            noise_x = prev_noise_x * 0.5 + random.uniform(-noise_factor, noise_factor)
            noise_y = prev_noise_y * 0.5 + random.uniform(-noise_factor, noise_factor)
            
            noisy_point = PathPoint(
                x=int(point.x + noise_x),
                y=int(point.y + noise_y),
                delay_before_ms=point.delay_before_ms,
                is_waypoint=point.is_waypoint
            )
            noisy_points.append(noisy_point)
        
        noisy_points.append(points[-1])  # Keep end point exact
        
        return noisy_points
    
    def generate_bezier_path(
        self,
        start: tuple[int, int],
        end: tuple[int, int],
        control_points: int = 2
    ) -> list[PathPoint]:
        """
        Generate smooth curved path using Bezier curves.
        More natural than straight lines.
        
        Args:
            start: Starting position
            end: Ending position
            control_points: Number of control points (1-3)
            
        Returns:
            List of path points forming smooth curve
        """
        # Generate control points
        controls = []
        
        for i in range(control_points):
            # Position control points off the straight line
            t = (i + 1) / (control_points + 1)
            
            # Interpolate between start and end
            base_x = start[0] + (end[0] - start[0]) * t
            base_y = start[1] + (end[1] - start[1]) * t
            
            # Offset perpendicular to line
            dx = end[0] - start[0]
            dy = end[1] - start[1]
            dist = math.sqrt(dx * dx + dy * dy)
            
            if dist > 0:
                # Perpendicular vector
                perp_x = -dy / dist
                perp_y = dx / dist
                
                # Random offset
                offset = random.uniform(-dist * 0.2, dist * 0.2)
                
                ctrl_x = int(base_x + perp_x * offset)
                ctrl_y = int(base_y + perp_y * offset)
                controls.append((ctrl_x, ctrl_y))
        
        # Generate Bezier curve points
        num_segments = max(int(math.sqrt(
            (end[0] - start[0]) ** 2 + (end[1] - start[1]) ** 2
        )), 5)
        
        all_points = [start] + controls + [end]
        bezier_points = []
        
        for i in range(num_segments + 1):
            t = i / num_segments
            point = self._bezier_point(all_points, t)
            bezier_points.append(PathPoint(x=int(point[0]), y=int(point[1])))
        
        return bezier_points
    
    def _bezier_point(self, points: list[tuple[int, int]], t: float) -> tuple[float, float]:
        """
        Calculate point on Bezier curve at parameter t.
        Uses De Casteljau's algorithm.
        """
        if len(points) == 1:
            return points[0]
        
        new_points = []
        for i in range(len(points) - 1):
            x = points[i][0] * (1 - t) + points[i + 1][0] * t
            y = points[i][1] * (1 - t) + points[i + 1][1] * t
            new_points.append((x, y))
        
        return self._bezier_point(new_points, t)
    
    def add_pause_points(
        self,
        path: list[PathPoint],
        pause_chance: float = 0.15
    ) -> list[PathPoint]:
        """
        Add random pauses along path.
        Humans stop to look around, check inventory, etc.
        
        Args:
            path: Original path
            pause_chance: Probability of pause at each point
            
        Returns:
            Path with pause delays added
        """
        if len(path) <= 2:
            return path
        
        # Don't pause at start or end
        for i in range(1, len(path) - 1):
            if random.random() < pause_chance:
                # Short pause: 500-2000ms
                path[i].delay_before_ms = random.randint(500, 2000)
                path[i].is_waypoint = True
        
        return path
    
    def get_movement_speed_variation(self, num_points: int) -> list[float]:
        """
        Generate speed variation along path.
        Humans don't walk at constant speed.
        Slower at turns, faster on straightaways.
        
        Args:
            num_points: Number of path points
            
        Returns:
            List of speed multipliers (0.7 - 1.2)
        """
        speeds = []
        
        for i in range(num_points):
            # Base speed variation
            base_speed = random.uniform(0.9, 1.1)
            
            # Slower at start and end
            if i < 3 or i >= num_points - 3:
                base_speed *= 0.85
            
            # Random micro-variations
            if random.random() < 0.1:
                base_speed *= random.uniform(0.7, 0.9)
            
            speeds.append(max(0.7, min(1.2, base_speed)))
        
        return speeds
    
    def simulate_obstacle_avoidance(self, path: list[PathPoint], obstacles: list[tuple[int, int]]) -> list[PathPoint]:
        """Add realistic obstacle avoidance behavior."""
        if not obstacles or len(path) <= 2:
            return path
        
        avoided_path = [path[0]]
        for i in range(1, len(path)):
            point = path[i]
            min_dist = min(math.sqrt((point.x - ox) ** 2 + (point.y - oy) ** 2) for ox, oy in obstacles)
            
            if min_dist < 3:
                avoided_path.append(PathPoint(
                    x=point.x + random.randint(-2, 2),
                    y=point.y + random.randint(-2, 2),
                    delay_before_ms=point.delay_before_ms,
                    is_waypoint=point.is_waypoint
                ))
            else:
                avoided_path.append(point)
        
        return avoided_path
    
    def _generate_zigzag_path(
        self,
        start: tuple[int, int],
        end: tuple[int, int]
    ) -> list[PathPoint]:
        """Generate zigzag movement pattern."""
        points = [PathPoint(x=start[0], y=start[1])]
        
        num_zigs = random.randint(2, 4)
        for i in range(1, num_zigs + 1):
            t = i / (num_zigs + 1)
            x = int(start[0] + (end[0] - start[0]) * t)
            y = int(start[1] + (end[1] - start[1]) * t)
            
            # Add perpendicular offset
            offset = random.randint(-3, 3) * (1 if i % 2 == 0 else -1)
            points.append(PathPoint(x=x + offset, y=y))
        
        points.append(PathPoint(x=end[0], y=end[1]))
        return points
    
    def _generate_wandering_path(
        self,
        start: tuple[int, int],
        end: tuple[int, int]
    ) -> list[PathPoint]:
        """Generate casual wandering pattern."""
        points = [PathPoint(x=start[0], y=start[1])]
        
        # Add several random waypoints
        num_waypoints = random.randint(3, 6)
        for i in range(1, num_waypoints + 1):
            t = i / (num_waypoints + 1)
            x = int(start[0] + (end[0] - start[0]) * t)
            y = int(start[1] + (end[1] - start[1]) * t)
            
            # Large random offset for wandering
            x += random.randint(-5, 5)
            y += random.randint(-5, 5)
            
            points.append(PathPoint(x=x, y=y, is_waypoint=True))
        
        points.append(PathPoint(x=end[0], y=end[1]))
        return points
    
    def _count_direction_changes(self, points: list[PathPoint]) -> int:
        """Count significant direction changes in path."""
        if len(points) < 3:
            return 0
        
        changes = 0
        prev_angle = 0.0
        
        for i in range(1, len(points) - 1):
            dx1 = points[i].x - points[i - 1].x
            dy1 = points[i].y - points[i - 1].y
            dx2 = points[i + 1].x - points[i].x
            dy2 = points[i + 1].y - points[i].y
            
            angle1 = math.atan2(dy1, dx1)
            angle2 = math.atan2(dy2, dx2)
            
            angle_diff = abs(angle2 - angle1)
            if angle_diff > math.pi:
                angle_diff = 2 * math.pi - angle_diff
            
            # Count as direction change if > 30 degrees
            if angle_diff > math.pi / 6:
                changes += 1
        
        return changes
    
    def detect_suspicious_pattern(self) -> tuple[bool, str]:
        """Self-check: detect if recent movement is too robotic."""
        if len(self.movement_history) < 10:
            return False, ""
        
        recent = self.movement_history[-10:]
        avg_efficiency = sum(p.path_efficiency for p in recent) / len(recent)
        
        if avg_efficiency > 0.95:
            return True, "Path efficiency too high"
        if sum(len(p.pause_points) for p in recent) == 0:
            return True, "No pauses in recent paths"
        if sum(p.direction_changes for p in recent) / len(recent) < 1.0:
            return True, "Too few direction changes"
        
        pattern_counts = {path.pattern_type: sum(1 for p in recent if p.pattern_type == path.pattern_type) for path in recent}
        if any(count >= 8 for count in pattern_counts.values()):
            return True, "Pattern repetition detected"
        
        return False, ""
    
    def get_movement_stats(self) -> dict:
        """Get movement statistics for analysis."""
        if not self.movement_history:
            return {}
        
        recent = self.movement_history[-20:]
        
        return {
            "total_paths": len(self.movement_history),
            "recent_avg_efficiency": sum(p.path_efficiency for p in recent) / len(recent),
            "recent_avg_pauses": sum(len(p.pause_points) for p in recent) / len(recent),
            "recent_avg_direction_changes": sum(p.direction_changes for p in recent) / len(recent),
            "pattern_distribution": {
                pattern.value: sum(1 for p in recent if p.pattern_type == pattern)
                for pattern in MovementPattern
            }
        }