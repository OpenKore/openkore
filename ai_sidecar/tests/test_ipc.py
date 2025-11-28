#!/usr/bin/env python3
"""
IPC Communication Test Script

This script tests the ZeroMQ communication between a simulated OpenKore client
(REQ socket) and the AI Sidecar server (REP socket).

Usage:
    # Start the sidecar first:
    python -m ai_sidecar.main
    
    # In another terminal, run this test:
    python -m ai_sidecar.tests.test_ipc
"""

import asyncio
import json
import sys
import time
from typing import Any

import zmq
import zmq.asyncio


class IPCTestClient:
    """Test client that simulates OpenKore's AI_Bridge plugin."""
    
    def __init__(self, address: str = "tcp://127.0.0.1:5555"):
        self.address = address
        self.context: zmq.asyncio.Context | None = None
        self.socket: zmq.asyncio.Socket | None = None
        self.tick_count = 0
        
    async def connect(self) -> None:
        """Establish ZMQ connection."""
        self.context = zmq.asyncio.Context()
        self.socket = self.context.socket(zmq.REQ)
        self.socket.setsockopt(zmq.RCVTIMEO, 1000)  # 1 second timeout for tests
        self.socket.setsockopt(zmq.SNDTIMEO, 1000)
        self.socket.setsockopt(zmq.LINGER, 0)
        self.socket.connect(self.address)
        print(f"✅ Connected to {self.address}")
        
    async def disconnect(self) -> None:
        """Close ZMQ connection."""
        if self.socket:
            self.socket.close()
            self.socket = None
        if self.context:
            self.context.term()
            self.context = None
        print("✅ Disconnected")
        
    async def send_and_receive(self, message: dict[str, Any]) -> dict[str, Any] | None:
        """Send a message and wait for response."""
        if not self.socket:
            raise RuntimeError("Not connected")
            
        json_msg = json.dumps(message)
        await self.socket.send_string(json_msg)
        
        try:
            response_json = await self.socket.recv_string()
            return json.loads(response_json)
        except zmq.Again:
            print("⚠️  Timeout waiting for response")
            return None
            
    def build_mock_state(self) -> dict[str, Any]:
        """Build a mock game state for testing."""
        self.tick_count += 1
        return {
            "character": {
                "name": "TestBot",
                "job_id": 4001,
                "base_level": 99,
                "job_level": 70,
                "hp": 15000,
                "hp_max": 20000,
                "sp": 500,
                "sp_max": 1000,
                "position": {"x": 150, "y": 200},
                "moving": False,
                "sitting": False,
                "attacking": False,
                "target_id": None,
                "status_effects": [],
                "weight": 5000,
                "weight_max": 10000,
                "zeny": 1000000,
            },
            "actors": [
                {
                    "id": 12345,
                    "type": 2,  # MONSTER
                    "name": "Poring",
                    "position": {"x": 155, "y": 205},
                    "hp": 50,
                    "hp_max": 50,
                    "moving": False,
                    "attacking": False,
                    "target_id": None,
                    "mob_id": 1002,
                },
                {
                    "id": 12346,
                    "type": 2,  # MONSTER
                    "name": "Drops",
                    "position": {"x": 160, "y": 195},
                    "hp": 55,
                    "hp_max": 55,
                    "moving": True,
                    "attacking": False,
                    "target_id": None,
                    "mob_id": 1113,
                },
            ],
            "inventory": [
                {
                    "index": 0,
                    "item_id": 501,
                    "name": "Red Potion",
                    "amount": 100,
                    "equipped": False,
                    "identified": True,
                    "type": 0,
                },
                {
                    "index": 1,
                    "item_id": 502,
                    "name": "Orange Potion",
                    "amount": 50,
                    "equipped": False,
                    "identified": True,
                    "type": 0,
                },
            ],
            "map": {
                "name": "prontera",
                "width": 400,
                "height": 400,
            },
            "ai_mode": 1,
        }


async def test_heartbeat(client: IPCTestClient) -> bool:
    """Test heartbeat message."""
    print("\n🔄 Testing heartbeat...")
    
    message = {
        "type": "heartbeat",
        "timestamp": int(time.time() * 1000),
        "source": "test_client",
        "status": "healthy",
        "stats": {
            "ticks_processed": 0,
            "errors_count": 0,
        },
        "version": "0.1.0-test",
    }
    
    response = await client.send_and_receive(message)
    
    if response:
        print(f"   Response type: {response.get('type')}")
        print(f"   Status: {response.get('status', 'N/A')}")
        if response.get("type") == "heartbeat":
            print("✅ Heartbeat test PASSED")
            return True
    
    print("❌ Heartbeat test FAILED")
    return False


async def test_state_update(client: IPCTestClient) -> bool:
    """Test state update and decision response."""
    print("\n🔄 Testing state update...")
    
    game_state = client.build_mock_state()
    
    message = {
        "type": "state_update",
        "timestamp": int(time.time() * 1000),
        "tick": client.tick_count,
        "payload": game_state,
    }
    
    response = await client.send_and_receive(message)
    
    if response:
        print(f"   Response type: {response.get('type')}")
        print(f"   Tick: {response.get('tick')}")
        print(f"   Actions: {len(response.get('actions', []))}")
        print(f"   Fallback mode: {response.get('fallback_mode', 'N/A')}")
        
        if response.get("type") == "decision":
            print("✅ State update test PASSED")
            return True
    
    print("❌ State update test FAILED")
    return False


async def test_multiple_ticks(client: IPCTestClient, count: int = 10) -> bool:
    """Test multiple rapid ticks."""
    print(f"\n🔄 Testing {count} rapid ticks...")
    
    success_count = 0
    total_time = 0.0
    
    for i in range(count):
        start = time.time()
        
        game_state = client.build_mock_state()
        message = {
            "type": "state_update",
            "timestamp": int(time.time() * 1000),
            "tick": client.tick_count,
            "payload": game_state,
        }
        
        response = await client.send_and_receive(message)
        
        elapsed = (time.time() - start) * 1000
        total_time += elapsed
        
        if response and response.get("type") == "decision":
            success_count += 1
            
    avg_time = total_time / count
    print(f"   Success rate: {success_count}/{count}")
    print(f"   Average round-trip: {avg_time:.2f}ms")
    print(f"   Total time: {total_time:.2f}ms")
    
    if success_count == count:
        print("✅ Multiple ticks test PASSED")
        return True
    
    print("❌ Multiple ticks test FAILED")
    return False


async def test_invalid_message(client: IPCTestClient) -> bool:
    """Test handling of invalid messages."""
    print("\n🔄 Testing invalid message handling...")
    
    message = {
        "type": "unknown_type",
        "data": "invalid",
    }
    
    response = await client.send_and_receive(message)
    
    if response:
        print(f"   Response type: {response.get('type')}")
        print(f"   Error: {response.get('error', 'N/A')}")
        
        # Should get error response for unknown type
        if response.get("type") == "error":
            print("✅ Invalid message test PASSED")
            return True
    
    print("❌ Invalid message test FAILED")
    return False


async def run_all_tests() -> None:
    """Run all IPC tests."""
    print("=" * 60)
    print("AI Sidecar IPC Communication Tests")
    print("=" * 60)
    
    client = IPCTestClient()
    
    try:
        await client.connect()
        
        results = {
            "heartbeat": await test_heartbeat(client),
            "state_update": await test_state_update(client),
            "multiple_ticks": await test_multiple_ticks(client, 10),
            "invalid_message": await test_invalid_message(client),
        }
        
        print("\n" + "=" * 60)
        print("Test Results Summary")
        print("=" * 60)
        
        passed = sum(1 for v in results.values() if v)
        total = len(results)
        
        for name, result in results.items():
            status = "✅ PASSED" if result else "❌ FAILED"
            print(f"  {name}: {status}")
            
        print(f"\nTotal: {passed}/{total} tests passed")
        
        if passed == total:
            print("\n🎉 All tests passed!")
            sys.exit(0)
        else:
            print("\n⚠️  Some tests failed")
            sys.exit(1)
            
    except zmq.error.ZMQError as e:
        print(f"\n❌ ZMQ Error: {e}")
        print("   Make sure the AI Sidecar is running:")
        print("   python -m ai_sidecar.main")
        sys.exit(1)
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        sys.exit(1)
        
    finally:
        await client.disconnect()


def main() -> None:
    """Entry point for test script."""
    asyncio.run(run_all_tests())


if __name__ == "__main__":
    main()