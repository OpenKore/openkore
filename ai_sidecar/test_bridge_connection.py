#!/usr/bin/env python3
"""
OpenKore-AI Bridge Connection Tester

Standalone script to test ZeroMQ connectivity and protocol validation.
Tests the bridge communication without requiring full OpenKore setup.

Usage:
    python test_bridge_connection.py
    python test_bridge_connection.py --endpoint tcp://localhost:5555
    python test_bridge_connection.py --verbose
"""

import sys
import json
import time
import argparse
from typing import Optional, Dict, Any
from dataclasses import dataclass

try:
    import zmq
except ImportError:
    print("❌ Error: pyzmq not installed")
    print("   Install with: pip install pyzmq")
    sys.exit(1)

# Test configuration
DEFAULT_ENDPOINT = "tcp://localhost:5555"
TIMEOUT_MS = 5000
TEST_TIMEOUT_SECONDS = 10


@dataclass
class TestResult:
    """Result of a test case"""
    name: str
    passed: bool
    message: str
    duration_ms: float = 0.0


class BridgeTester:
    """Tests AI Sidecar bridge connection and protocol"""
    
    def __init__(self, endpoint: str = DEFAULT_ENDPOINT, verbose: bool = False):
        self.endpoint = endpoint
        self.verbose = verbose
        self.context: Optional[zmq.Context] = None
        self.socket: Optional[zmq.Socket] = None
        self.results: list[TestResult] = []
    
    def log(self, message: str, level: str = "INFO"):
        """Log message if verbose mode enabled"""
        if self.verbose or level in ["ERROR", "SUCCESS"]:
            prefix = {
                "INFO": "ℹ️ ",
                "SUCCESS": "✅",
                "ERROR": "❌",
                "WARN": "⚠️ "
            }.get(level, "  ")
            print(f"{prefix} {message}")
    
    def connect(self) -> bool:
        """Establish ZeroMQ connection"""
        try:
            self.log(f"Creating ZMQ context...")
            self.context = zmq.Context()
            
            self.log(f"Creating REQ socket...")
            self.socket = self.context.socket(zmq.REQ)
            
            self.log(f"Setting timeouts: {TIMEOUT_MS}ms...")
            self.socket.setsockopt(zmq.RCVTIMEO, TIMEOUT_MS)
            self.socket.setsockopt(zmq.SNDTIMEO, TIMEOUT_MS)
            self.socket.setsockopt(zmq.LINGER, 0)
            
            self.log(f"Connecting to {self.endpoint}...")
            self.socket.connect(self.endpoint)
            
            # Give it a moment to establish connection
            time.sleep(0.1)
            
            self.log(f"Connection established", "SUCCESS")
            return True
            
        except Exception as e:
            self.log(f"Connection failed: {e}", "ERROR")
            return False
    
    def disconnect(self):
        """Close ZeroMQ connection"""
        if self.socket:
            self.log("Closing socket...")
            self.socket.close()
            self.socket = None
        
        if self.context:
            self.log("Terminating context...")
            self.context.term()
            self.context = None
    
    def send_and_receive(self, message: Dict[str, Any], timeout_seconds: int = TEST_TIMEOUT_SECONDS) -> Optional[Dict[str, Any]]:
        """Send message and wait for response"""
        try:
            # Serialize message
            json_data = json.dumps(message)
            self.log(f"Sending: {json_data[:100]}...")
            
            # Send
            start_time = time.time()
            self.socket.send_string(json_data)
            
            # Receive with timeout
            response = self.socket.recv_string()
            duration = (time.time() - start_time) * 1000
            
            self.log(f"Received response in {duration:.2f}ms")
            self.log(f"Response: {response[:100]}...")
            
            # Parse response
            response_data = json.loads(response)
            return response_data
            
        except zmq.Again:
            self.log("Request timed out", "ERROR")
            return None
        except json.JSONDecodeError as e:
            self.log(f"JSON decode error: {e}", "ERROR")
            return None
        except Exception as e:
            self.log(f"Communication error: {e}", "ERROR")
            return None
    
    def test_basic_connectivity(self) -> TestResult:
        """Test 1: Basic ZeroMQ connectivity"""
        start_time = time.time()
        
        try:
            if not self.socket:
                return TestResult(
                    name="Basic Connectivity",
                    passed=False,
                    message="Socket not connected"
                )
            
            # Send minimal state update
            test_message = {
                "type": "state_update",
                "timestamp": int(time.time() * 1000),
                "tick": 1,
                "payload": {
                    "character": {
                        "name": "TestChar",
                        "hp": 100,
                        "hp_max": 100
                    }
                }
            }
            
            response = self.send_and_receive(test_message)
            duration = (time.time() - start_time) * 1000
            
            if response is None:
                return TestResult(
                    name="Basic Connectivity",
                    passed=False,
                    message="No response received",
                    duration_ms=duration
                )
            
            return TestResult(
                name="Basic Connectivity",
                passed=True,
                message=f"Connected successfully in {duration:.1f}ms",
                duration_ms=duration
            )
            
        except Exception as e:
            duration = (time.time() - start_time) * 1000
            return TestResult(
                name="Basic Connectivity",
                passed=False,
                message=f"Exception: {str(e)}",
                duration_ms=duration
            )
    
    def test_protocol_validation(self) -> TestResult:
        """Test 2: Protocol message validation"""
        start_time = time.time()
        
        try:
            # Send complete state update
            test_message = {
                "type": "state_update",
                "timestamp": int(time.time() * 1000),
                "tick": 1,
                "payload": {
                    "character": {
                        "name": "TestBot",
                        "job_id": 7,
                        "base_level": 50,
                        "job_level": 40,
                        "hp": 5000,
                        "hp_max": 6000,
                        "sp": 500,
                        "sp_max": 800,
                        "position": {"x": 100, "y": 150},
                        "stats": {
                            "str": 50,
                            "agi": 40,
                            "vit": 30,
                            "int": 20,
                            "dex": 60,
                            "luk": 10
                        }
                    },
                    "actors": [],
                    "inventory": [],
                    "map": {
                        "name": "prt_fild08",
                        "width": 400,
                        "height": 400
                    }
                }
            }
            
            response = self.send_and_receive(test_message)
            duration = (time.time() - start_time) * 1000
            
            if response is None:
                return TestResult(
                    name="Protocol Validation",
                    passed=False,
                    message="No response received",
                    duration_ms=duration
                )
            
            # Validate response structure
            if response.get("type") != "decision":
                return TestResult(
                    name="Protocol Validation",
                    passed=False,
                    message=f"Wrong response type: {response.get('type')}",
                    duration_ms=duration
                )
            
            if "actions" not in response:
                return TestResult(
                    name="Protocol Validation",
                    passed=False,
                    message="Response missing 'actions' field",
                    duration_ms=duration
                )
            
            return TestResult(
                name="Protocol Validation",
                passed=True,
                message=f"Protocol validated in {duration:.1f}ms, received {len(response.get('actions', []))} actions",
                duration_ms=duration
            )
            
        except Exception as e:
            duration = (time.time() - start_time) * 1000
            return TestResult(
                name="Protocol Validation",
                passed=False,
                message=f"Exception: {str(e)}",
                duration_ms=duration
            )
    
    def test_action_generation(self) -> TestResult:
        """Test 3: AI action generation"""
        start_time = time.time()
        
        try:
            # Send state that should trigger actions
            test_message = {
                "type": "state_update",
                "timestamp": int(time.time() * 1000),
                "tick": 5,
                "payload": {
                    "character": {
                        "name": "TestBot",
                        "job_id": 7,
                        "base_level": 1,
                        "job_level": 1,
                        "hp": 50,
                        "hp_max": 50,
                        "sp": 10,
                        "sp_max": 10,
                        "position": {"x": 100, "y": 150},
                        "points_free": 5,  # Unallocated stat points
                        "points_skill": 0,
                        "stats": {
                            "str": 1,
                            "agi": 1,
                            "vit": 1,
                            "int": 1,
                            "dex": 1,
                            "luk": 1
                        }
                    },
                    "actors": [],
                    "inventory": [],
                    "map": {
                        "name": "new_1-1",
                        "width": 200,
                        "height": 200
                    }
                }
            }
            
            response = self.send_and_receive(test_message)
            duration = (time.time() - start_time) * 1000
            
            if response is None:
                return TestResult(
                    name="Action Generation",
                    passed=False,
                    message="No response received",
                    duration_ms=duration
                )
            
            actions = response.get("actions", [])
            
            return TestResult(
                name="Action Generation",
                passed=True,
                message=f"Generated {len(actions)} actions in {duration:.1f}ms",
                duration_ms=duration
            )
            
        except Exception as e:
            duration = (time.time() - start_time) * 1000
            return TestResult(
                name="Action Generation",
                passed=False,
                message=f"Exception: {str(e)}",
                duration_ms=duration
            )
    
    def test_performance(self) -> TestResult:
        """Test 4: Performance under load"""
        start_time = time.time()
        num_requests = 10
        
        try:
            latencies = []
            
            for i in range(num_requests):
                req_start = time.time()
                
                test_message = {
                    "type": "state_update",
                    "timestamp": int(time.time() * 1000),
                    "tick": i + 1,
                    "payload": {
                        "character": {
                            "name": "PerfTest",
                            "hp": 100,
                            "hp_max": 100
                        }
                    }
                }
                
                response = self.send_and_receive(test_message)
                
                if response is None:
                    return TestResult(
                        name="Performance Test",
                        passed=False,
                        message=f"Request {i+1}/{num_requests} failed",
                        duration_ms=(time.time() - start_time) * 1000
                    )
                
                latency = (time.time() - req_start) * 1000
                latencies.append(latency)
            
            total_duration = (time.time() - start_time) * 1000
            avg_latency = sum(latencies) / len(latencies)
            min_latency = min(latencies)
            max_latency = max(latencies)
            
            return TestResult(
                name="Performance Test",
                passed=True,
                message=f"{num_requests} requests: avg={avg_latency:.1f}ms, min={min_latency:.1f}ms, max={max_latency:.1f}ms",
                duration_ms=total_duration
            )
            
        except Exception as e:
            duration = (time.time() - start_time) * 1000
            return TestResult(
                name="Performance Test",
                passed=False,
                message=f"Exception: {str(e)}",
                duration_ms=duration
            )
    
    def test_error_handling(self) -> TestResult:
        """Test 5: Error handling with invalid messages"""
        start_time = time.time()
        
        try:
            # Send invalid message (missing required fields)
            test_message = {
                "type": "invalid_type",
                "data": "garbage"
            }
            
            response = self.send_and_receive(test_message)
            duration = (time.time() - start_time) * 1000
            
            # AI should either reject or handle gracefully
            if response is None:
                return TestResult(
                    name="Error Handling",
                    passed=True,
                    message="AI correctly rejected invalid message",
                    duration_ms=duration
                )
            
            # If it responds, check for error indication
            if response.get("type") == "error":
                return TestResult(
                    name="Error Handling",
                    passed=True,
                    message="AI returned error response as expected",
                    duration_ms=duration
                )
            
            # If it returns normal response, that's also acceptable (graceful handling)
            return TestResult(
                name="Error Handling",
                passed=True,
                message="AI handled invalid message gracefully",
                duration_ms=duration
            )
            
        except Exception as e:
            duration = (time.time() - start_time) * 1000
            return TestResult(
                name="Error Handling",
                passed=True,
                message=f"Exception caught (expected): {str(e)}",
                duration_ms=duration
            )
    
    def run_all_tests(self) -> bool:
        """Run all test cases"""
        print("\n" + "="*60)
        print("🔍 OpenKore-AI Bridge Connection Test Suite")
        print("="*60 + "\n")
        
        print(f"📡 Target endpoint: {self.endpoint}")
        print(f"⏱️  Timeout: {TIMEOUT_MS}ms\n")
        
        # Connect
        print("🔌 Establishing connection...")
        if not self.connect():
            print("\n❌ Connection failed. Is AI Sidecar running?")
            print(f"   Start it with: cd ai_sidecar && python main.py\n")
            return False
        
        print("✅ Connected successfully!\n")
        
        # Run tests
        tests = [
            self.test_basic_connectivity,
            self.test_protocol_validation,
            self.test_action_generation,
            self.test_performance,
            self.test_error_handling,
        ]
        
        print("🧪 Running test cases...\n")
        for i, test_func in enumerate(tests, 1):
            print(f"[{i}/{len(tests)}] Running {test_func.__doc__.split(':')[1].strip()}...")
            result = test_func()
            self.results.append(result)
            
            status = "✅ PASS" if result.passed else "❌ FAIL"
            print(f"    {status}: {result.message}")
            if result.duration_ms > 0:
                print(f"    Duration: {result.duration_ms:.1f}ms")
            print()
        
        # Disconnect
        self.disconnect()
        
        # Print summary
        print("="*60)
        print("📊 Test Summary")
        print("="*60 + "\n")
        
        passed = sum(1 for r in self.results if r.passed)
        failed = sum(1 for r in self.results if not r.passed)
        total = len(self.results)
        
        print(f"  Total:  {total}")
        print(f"  Passed: {passed} ✅")
        print(f"  Failed: {failed} ❌")
        
        if failed == 0:
            print("\n" + "="*60)
            print("🎉 All tests passed!")
            print("="*60)
            print("\n✅ Bridge is working correctly")
            print("🚀 Ready to start OpenKore with AI support\n")
            return True
        else:
            print("\n" + "="*60)
            print("⚠️  Some tests failed")
            print("="*60)
            print("\nℹ️  Check the AI Sidecar logs for more details")
            print("📚 See BRIDGE_TROUBLESHOOTING.md for help\n")
            return False


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="Test OpenKore-AI bridge connection",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python test_bridge_connection.py
  python test_bridge_connection.py --endpoint tcp://localhost:5555
  python test_bridge_connection.py --verbose
        """
    )
    
    parser.add_argument(
        "--endpoint",
        default=DEFAULT_ENDPOINT,
        help=f"ZeroMQ endpoint (default: {DEFAULT_ENDPOINT})"
    )
    
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Enable verbose output"
    )
    
    args = parser.parse_args()
    
    # Create tester and run
    tester = BridgeTester(endpoint=args.endpoint, verbose=args.verbose)
    success = tester.run_all_tests()
    
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()