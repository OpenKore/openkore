"""
Portal database for navigation system.

Parses OpenKore portal data files and builds a weighted graph
of map connections for pathfinding.
"""

import os
import re
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple

from ai_sidecar.utils.logging import get_logger
from ai_sidecar.navigation.models import (
    Portal,
    PortalType,
    KafraDestination,
    WarpNPC,
    MapInfo,
    MapCategory,
)

logger = get_logger(__name__)


@dataclass
class MapConnection:
    """Represents a connection between two maps with all available portals."""
    from_map: str
    to_map: str
    portals: List[Portal] = field(default_factory=list)
    
    @property
    def min_cost(self) -> int:
        """Get minimum zeny cost for this connection."""
        if not self.portals:
            return 0
        return min(p.cost for p in self.portals)
    
    @property
    def fastest_portal(self) -> Optional[Portal]:
        """Get the portal with shortest walk time."""
        if not self.portals:
            return None
        return min(self.portals, key=lambda p: p.estimated_walk_time)
    
    @property
    def cheapest_portal(self) -> Optional[Portal]:
        """Get the portal with lowest cost."""
        if not self.portals:
            return None
        return min(self.portals, key=lambda p: p.cost)


class PortalDatabase:
    """
    Database of portals and map connections.
    
    Parses OpenKore portal files and provides:
    - Graph of map connections
    - Portal lookup by source/destination
    - Kafra teleport destinations
    - Warp NPC information
    """
    
    # Default tables directory relative to this file
    DEFAULT_TABLES_DIR = Path(__file__).parent.parent.parent / "tables"
    
    def __init__(self, tables_dir: Optional[Path] = None):
        """
        Initialize portal database.
        
        Args:
            tables_dir: Path to OpenKore tables directory
        """
        self.tables_dir = tables_dir or self.DEFAULT_TABLES_DIR
        
        # Core data structures
        self._portals: List[Portal] = []
        self._map_connections: Dict[str, Dict[str, MapConnection]] = defaultdict(dict)
        self._maps: Dict[str, MapInfo] = {}
        self._kafra_npcs: Dict[str, WarpNPC] = {}
        self._warp_npcs: Dict[str, WarpNPC] = {}
        
        # Graph adjacency list for pathfinding
        self._adjacency: Dict[str, Set[str]] = defaultdict(set)
        
        # Statistics
        self._portal_count = 0
        self._map_count = 0
        self._connection_count = 0
        
        logger.info(
            "Initializing portal database",
            tables_dir=str(self.tables_dir)
        )
    
    def load(self) -> bool:
        """
        Load all portal data from files.
        
        Returns:
            True if loaded successfully
        """
        try:
            # Load main portal data
            portals_file = self.tables_dir / "portals.txt"
            if portals_file.exists():
                self._load_portals_file(portals_file)
            else:
                logger.warning(
                    "Portal file not found, using built-in data",
                    path=str(portals_file)
                )
                self._load_builtin_portals()
            
            # Load city/map names
            cities_file = self.tables_dir / "cities.txt"
            if cities_file.exists():
                self._load_cities_file(cities_file)
            
            # Build graph structure
            self._build_graph()
            
            # Add kafra services
            self._add_kafra_services()
            
            logger.info(
                "Portal database loaded successfully",
                portals=self._portal_count,
                maps=self._map_count,
                connections=self._connection_count
            )
            return True
            
        except Exception as e:
            logger.error(
                "Failed to load portal database",
                error=str(e),
                exc_info=True
            )
            return False
    
    def _load_portals_file(self, filepath: Path) -> None:
        """
        Parse OpenKore portals.txt file.
        
        Format: source_map src_x src_y dest_map dest_x dest_y [cost] [conversation]
        
        Args:
            filepath: Path to portals.txt
        """
        logger.debug("Loading portals file", path=str(filepath))
        
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            for line_num, line in enumerate(f, 1):
                line = line.strip()
                
                # Skip empty lines and comments
                if not line or line.startswith('#'):
                    continue
                
                portal = self._parse_portal_line(line, line_num)
                if portal:
                    self._portals.append(portal)
                    self._portal_count += 1
        
        logger.debug(
            "Loaded portals from file",
            count=self._portal_count
        )
    
    def _parse_portal_line(self, line: str, line_num: int) -> Optional[Portal]:
        """
        Parse a single portal line.
        
        Args:
            line: Line from portals.txt
            line_num: Line number for error reporting
            
        Returns:
            Portal object or None if parsing fails
        """
        try:
            parts = line.split()
            
            if len(parts) < 6:
                logger.debug(
                    "Skipping invalid portal line",
                    line_num=line_num,
                    content=line[:50]
                )
                return None
            
            # Basic portal info
            from_map = parts[0]
            from_x = int(parts[1])
            from_y = int(parts[2])
            to_map = parts[3]
            to_x = int(parts[4])
            to_y = int(parts[5])
            
            # Optional cost (default 0)
            cost = 0
            if len(parts) > 6 and parts[6].isdigit():
                cost = int(parts[6])
            
            # Optional conversation sequence
            conversation = None
            conv_start = 7 if len(parts) > 6 and parts[6].isdigit() else 6
            if len(parts) > conv_start:
                conversation = ' '.join(parts[conv_start:])
            
            # Determine portal type
            portal_type = self._determine_portal_type(
                from_map, to_map, cost, conversation
            )
            
            return Portal(
                from_map=from_map,
                from_x=from_x,
                from_y=from_y,
                to_map=to_map,
                to_x=to_x,
                to_y=to_y,
                portal_type=portal_type,
                cost=cost,
                conversation=conversation,
            )
            
        except (ValueError, IndexError) as e:
            logger.debug(
                "Failed to parse portal line",
                line_num=line_num,
                error=str(e)
            )
            return None
    
    def _determine_portal_type(
        self,
        from_map: str,
        to_map: str,
        cost: int,
        conversation: Optional[str]
    ) -> PortalType:
        """
        Determine the type of portal based on properties.
        
        Args:
            from_map: Source map
            to_map: Destination map
            cost: Zeny cost
            conversation: Conversation sequence
            
        Returns:
            PortalType enum value
        """
        # Kafra indicators
        kafra_maps = {
            'alberta', 'aldebaran', 'comodo', 'geffen', 'izlude',
            'lighthalzen', 'morocc', 'payon', 'prontera', 'rachel',
            'veins', 'yuno', 'hugel', 'einbroch', 'einbech'
        }
        
        # Check for kafra service (has cost and conversation)
        if cost > 0 and conversation:
            if from_map.lower() in kafra_maps:
                return PortalType.KAFRA
            return PortalType.WARP_NPC
        
        # Check for dungeon warps
        dungeon_patterns = ['_dun', 'dun_', 'cave', 'tower', 'crypt']
        if any(p in to_map.lower() for p in dungeon_patterns):
            return PortalType.DUNGEON_WARP
        
        # Check for guild hall
        if 'guild' in to_map.lower() or 'agit' in to_map.lower():
            return PortalType.GUILD_HALL
        
        # Check for instance
        if 'ins_' in to_map.lower() or '@' in to_map:
            return PortalType.INSTANCE
        
        # Default to standard portal
        return PortalType.PORTAL
    
    def _load_cities_file(self, filepath: Path) -> None:
        """
        Load city/map display names from cities.txt.
        
        Format: map_name.rsw#Display Name#
        
        Args:
            filepath: Path to cities.txt
        """
        logger.debug("Loading cities file", path=str(filepath))
        
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                
                # Parse format: map_name.rsw#Display Name#
                match = re.match(r'^([^.]+)\.rsw#(.+)#$', line)
                if match:
                    map_name = match.group(1)
                    display_name = match.group(2)
                    
                    if map_name not in self._maps:
                        self._maps[map_name] = MapInfo(name=map_name)
                    
                    self._maps[map_name].display_name = display_name
                    self._categorize_map(self._maps[map_name])
    
    def _categorize_map(self, map_info: MapInfo) -> None:
        """
        Categorize a map based on its name.
        
        Args:
            map_info: MapInfo object to categorize
        """
        name = map_info.name.lower()
        
        # City maps
        cities = {
            'prontera', 'geffen', 'payon', 'morocc', 'alberta',
            'izlude', 'aldebaran', 'yuno', 'comodo', 'lutie',
            'umbala', 'niflheim', 'einbroch', 'einbech', 'hugel',
            'lighthalzen', 'rachel', 'veins', 'moscovia', 'mid_camp',
            'manuk', 'splendide', 'brasilis', 'dicastes01', 'mora'
        }
        
        if name in cities or any(c in name for c in ['_in', 'in_']):
            map_info.category = MapCategory.CITY
            map_info.danger_level = 0
            map_info.has_kafra = name in cities
            return
        
        # Dungeons
        dungeon_patterns = ['_dun', 'dun_', 'cave', 'tower', 'crypt', 'gld_', 'tur_']
        if any(p in name for p in dungeon_patterns):
            map_info.category = MapCategory.DUNGEON
            map_info.danger_level = 5
            map_info.is_teleport_allowed = False
            return
        
        # PvP maps
        if 'pvp_' in name or 'arena' in name:
            map_info.category = MapCategory.PVP
            map_info.danger_level = 8
            map_info.is_save_point_allowed = False
            return
        
        # Guild maps
        if 'guild' in name or 'agit' in name:
            map_info.category = MapCategory.GVG
            map_info.danger_level = 7
            return
        
        # Fields - default
        map_info.category = MapCategory.FIELD
        map_info.danger_level = 3
    
    def _build_graph(self) -> None:
        """Build the graph structure from loaded portals."""
        logger.debug("Building navigation graph")
        
        # Track unique maps
        unique_maps: Set[str] = set()
        
        for portal in self._portals:
            from_map = portal.from_map
            to_map = portal.to_map
            
            unique_maps.add(from_map)
            unique_maps.add(to_map)
            
            # Add to adjacency list
            self._adjacency[from_map].add(to_map)
            
            # Create or update connection
            if to_map not in self._map_connections[from_map]:
                self._map_connections[from_map][to_map] = MapConnection(
                    from_map=from_map,
                    to_map=to_map
                )
            
            self._map_connections[from_map][to_map].portals.append(portal)
        
        # Create MapInfo for any missing maps
        for map_name in unique_maps:
            if map_name not in self._maps:
                self._maps[map_name] = MapInfo(name=map_name)
                self._categorize_map(self._maps[map_name])
        
        self._map_count = len(unique_maps)
        self._connection_count = sum(
            len(conns) for conns in self._map_connections.values()
        )
        
        # Update connected_maps for each MapInfo
        for map_name, neighbors in self._adjacency.items():
            if map_name in self._maps:
                self._maps[map_name].connected_maps = list(neighbors)
        
        logger.debug(
            "Graph built",
            maps=self._map_count,
            connections=self._connection_count
        )
    
    def _add_kafra_services(self) -> None:
        """Add common Kafra teleport services."""
        kafra_destinations = {
            'prontera': [
                KafraDestination('Geffen', 'geffen', 119, 66, 1200, 1),
                KafraDestination('Payon', 'payon', 161, 58, 1200, 2),
                KafraDestination('Morocc', 'morocc', 156, 46, 1200, 3),
                KafraDestination('Alberta', 'alberta', 28, 234, 1200, 4),
                KafraDestination('Izlude', 'izlude', 94, 103, 600, 5),
                KafraDestination('Aldebaran', 'aldebaran', 140, 131, 1800, 6),
            ],
            'geffen': [
                KafraDestination('Prontera', 'prontera', 156, 180, 1200, 1),
                KafraDestination('Payon', 'payon', 161, 58, 1800, 2),
                KafraDestination('Morocc', 'morocc', 156, 46, 1800, 3),
                KafraDestination('Alberta', 'alberta', 28, 234, 1800, 4),
                KafraDestination('Aldebaran', 'aldebaran', 140, 131, 1200, 5),
            ],
            'payon': [
                KafraDestination('Prontera', 'prontera', 156, 180, 1200, 1),
                KafraDestination('Geffen', 'geffen', 119, 66, 1800, 2),
                KafraDestination('Morocc', 'morocc', 156, 46, 1200, 3),
                KafraDestination('Alberta', 'alberta', 28, 234, 1200, 4),
            ],
            'morocc': [
                KafraDestination('Prontera', 'prontera', 156, 180, 1200, 1),
                KafraDestination('Geffen', 'geffen', 119, 66, 1800, 2),
                KafraDestination('Payon', 'payon', 161, 58, 1200, 3),
                KafraDestination('Alberta', 'alberta', 28, 234, 1200, 4),
            ],
            'alberta': [
                KafraDestination('Prontera', 'prontera', 156, 180, 1200, 1),
                KafraDestination('Geffen', 'geffen', 119, 66, 1800, 2),
                KafraDestination('Payon', 'payon', 161, 58, 1200, 3),
                KafraDestination('Morocc', 'morocc', 156, 46, 1200, 4),
            ],
        }
        
        for city, destinations in kafra_destinations.items():
            # Create kafra NPC
            kafra = WarpNPC(
                npc_name=f"Kafra Employee",
                map_name=city,
                x=155 if city == 'prontera' else 150,
                y=180 if city == 'prontera' else 150,
                destinations=destinations,
                conversation_sequence="c r0"
            )
            self._kafra_npcs[city] = kafra
            
            # Add virtual portals for kafra destinations
            for dest in destinations:
                portal = Portal(
                    from_map=city,
                    from_x=kafra.x,
                    from_y=kafra.y,
                    to_map=dest.map_name,
                    to_x=dest.x,
                    to_y=dest.y,
                    portal_type=PortalType.KAFRA,
                    cost=dest.cost,
                    conversation="c r0 c r" + str(dest.menu_option - 1)
                )
                
                # Add to connections if not already present
                if dest.map_name not in self._map_connections[city]:
                    self._map_connections[city][dest.map_name] = MapConnection(
                        from_map=city,
                        to_map=dest.map_name
                    )
                
                self._map_connections[city][dest.map_name].portals.append(portal)
                self._adjacency[city].add(dest.map_name)
        
        logger.debug(
            "Added kafra services",
            count=len(kafra_destinations)
        )
    
    def _load_builtin_portals(self) -> None:
        """Load minimal built-in portal data when file not found."""
        builtin = [
            # Prontera connections
            Portal('prontera', 237, 320, 'prt_fild08', 176, 21, PortalType.PORTAL),
            Portal('prontera', 22, 203, 'prt_fild05', 367, 205, PortalType.PORTAL),
            Portal('prontera', 289, 203, 'prt_fild04', 21, 193, PortalType.PORTAL),
            Portal('prontera', 156, 22, 'prt_fild01', 156, 383, PortalType.PORTAL),
            Portal('prontera', 156, 296, 'prt_fild02', 156, 22, PortalType.PORTAL),
            
            # Prontera to other cities (field connections)
            Portal('prt_fild05', 21, 145, 'geffen', 215, 119, PortalType.PORTAL),
            Portal('prt_fild02', 372, 269, 'izlude', 21, 100, PortalType.PORTAL),
            
            # Geffen connections
            Portal('geffen', 215, 119, 'gef_fild00', 176, 21, PortalType.PORTAL),
            Portal('geffen', 22, 68, 'gef_fild01', 367, 68, PortalType.PORTAL),
            
            # Payon connections  
            Portal('payon', 185, 110, 'pay_fild01', 176, 383, PortalType.PORTAL),
            Portal('payon', 97, 131, 'pay_arche', 97, 30, PortalType.PORTAL),
            
            # Morocc connections
            Portal('morocc', 289, 203, 'moc_fild01', 21, 203, PortalType.PORTAL),
            Portal('morocc', 156, 22, 'moc_fild02', 156, 383, PortalType.PORTAL),
            
            # Alberta connections
            Portal('alberta', 117, 35, 'alb_ship', 117, 170, PortalType.PORTAL),
            Portal('alberta', 245, 76, 'alde_dun01', 245, 165, PortalType.PORTAL),
        ]
        
        for portal in builtin:
            self._portals.append(portal)
            self._portal_count += 1
        
        logger.debug(
            "Loaded builtin portals",
            count=len(builtin)
        )
    
    # Public API methods
    
    def get_neighbors(self, map_name: str) -> List[str]:
        """
        Get all maps directly connected to the given map.
        
        Args:
            map_name: Source map name
            
        Returns:
            List of connected map names
        """
        return list(self._adjacency.get(map_name, set()))
    
    def get_connection(
        self, from_map: str, to_map: str
    ) -> Optional[MapConnection]:
        """
        Get the connection between two maps.
        
        Args:
            from_map: Source map
            to_map: Destination map
            
        Returns:
            MapConnection or None if not connected
        """
        return self._map_connections.get(from_map, {}).get(to_map)
    
    def get_portals(
        self, from_map: str, to_map: Optional[str] = None
    ) -> List[Portal]:
        """
        Get portals from a map, optionally filtered by destination.
        
        Args:
            from_map: Source map
            to_map: Optional destination filter
            
        Returns:
            List of portals
        """
        if to_map:
            conn = self.get_connection(from_map, to_map)
            return conn.portals if conn else []
        
        result = []
        for conn in self._map_connections.get(from_map, {}).values():
            result.extend(conn.portals)
        return result
    
    def get_map_info(self, map_name: str) -> Optional[MapInfo]:
        """
        Get information about a map.
        
        Args:
            map_name: Map name
            
        Returns:
            MapInfo or None
        """
        return self._maps.get(map_name)
    
    def get_kafra_destinations(self, map_name: str) -> List[KafraDestination]:
        """
        Get available Kafra destinations from a map.
        
        Args:
            map_name: Current map
            
        Returns:
            List of available destinations
        """
        kafra = self._kafra_npcs.get(map_name)
        return kafra.destinations if kafra else []
    
    def is_connected(self, from_map: str, to_map: str) -> bool:
        """
        Check if two maps are directly connected.
        
        Args:
            from_map: Source map
            to_map: Destination map
            
        Returns:
            True if directly connected
        """
        return to_map in self._adjacency.get(from_map, set())
    
    def get_all_maps(self) -> List[str]:
        """Get list of all known maps."""
        return list(self._maps.keys())
    
    def get_statistics(self) -> Dict[str, int]:
        """Get database statistics."""
        return {
            'portals': self._portal_count,
            'maps': self._map_count,
            'connections': self._connection_count,
            'kafra_cities': len(self._kafra_npcs),
        }