"""
IPC package for AI Sidecar.

Provides ZeroMQ-based inter-process communication between OpenKore (Perl) and
the AI Sidecar (Python).
"""

from ai_sidecar.ipc.zmq_server import ZMQServer

__all__ = ["ZMQServer"]