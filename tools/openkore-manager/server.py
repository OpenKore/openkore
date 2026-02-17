#!/usr/bin/env python3
"""Local OpenKore manager for multi-instance bot and Poseidon orchestration."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import threading
import time
import uuid
from collections import deque
from dataclasses import dataclass, field
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Dict, Optional
from urllib.parse import parse_qs, urlparse

BASE_DIR = Path(__file__).resolve().parent
STATIC_DIR = BASE_DIR / "static"
DATA_FILE = BASE_DIR / "instances.json"
LOGS_DIR = BASE_DIR / "logs"
LOGS_DIR.mkdir(parents=True, exist_ok=True)


@dataclass
class ManagedProcess:
    command: str
    cwd: Path
    label: str
    process: Optional[subprocess.Popen] = None
    logs: deque[str] = field(default_factory=lambda: deque(maxlen=4000))
    lock: threading.Lock = field(default_factory=threading.Lock)

    def start(self, log_file: Path) -> None:
        if self.is_running:
            return

        log_file.parent.mkdir(parents=True, exist_ok=True)
        proc = subprocess.Popen(
            self.command,
            cwd=str(self.cwd),
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            universal_newlines=True,
        )
        self.process = proc

        thread = threading.Thread(
            target=self._stream_output,
            args=(proc, log_file),
            name=f"{self.label}-stream",
            daemon=True,
        )
        thread.start()

    def _stream_output(self, proc: subprocess.Popen, log_file: Path) -> None:
        with log_file.open("a", encoding="utf-8") as handle:
            handle.write(f"\n[{time.ctime()}] START {self.label}: {self.command}\n")
            while True:
                line = proc.stdout.readline() if proc.stdout else ""
                if not line and proc.poll() is not None:
                    break
                if not line:
                    continue
                cleaned = line.rstrip("\n")
                with self.lock:
                    self.logs.append(cleaned)
                handle.write(cleaned + "\n")
                handle.flush()
            code = proc.poll()
            with self.lock:
                self.logs.append(f"[process exited with code {code}]")
            handle.write(f"[{time.ctime()}] EXIT {self.label}: {code}\n")

    def stop(self) -> None:
        if not self.process:
            return
        if self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=8)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait(timeout=3)
        self.process = None

    @property
    def is_running(self) -> bool:
        return bool(self.process and self.process.poll() is None)

    def read_logs(self, tail: int = 200) -> list[str]:
        with self.lock:
            return list(self.logs)[-tail:]

    def clear_logs(self) -> None:
        with self.lock:
            self.logs.clear()


class ManagerStore:
    def __init__(self, data_file: Path) -> None:
        self.data_file = data_file
        self.instances: Dict[str, dict] = {}
        self.processes: Dict[str, Dict[str, ManagedProcess]] = {}
        self.load()

    def load(self) -> None:
        if not self.data_file.exists():
            self.instances = {}
            return
        self.instances = json.loads(self.data_file.read_text(encoding="utf-8"))

    def save(self) -> None:
        self.data_file.write_text(
            json.dumps(self.instances, indent=2, ensure_ascii=False), encoding="utf-8"
        )

    def list_instances(self) -> list[dict]:
        response = []
        for instance_id, data in self.instances.items():
            proc = self.processes.get(instance_id, {})
            response.append(
                {
                    **data,
                    "id": instance_id,
                    "bot_running": proc.get("bot").is_running if proc.get("bot") else False,
                    "poseidon_running": proc.get("poseidon").is_running
                    if proc.get("poseidon")
                    else False,
                }
            )
        return response

    def create_instance(self, payload: dict) -> dict:
        instance_id = str(uuid.uuid4())[:8]
        name = payload["name"].strip()
        working_dir = Path(payload.get("working_dir") or ".").expanduser().resolve()

        data = {
            "name": name,
            "xkore_mode": payload.get("xkore_mode", "0"),
            "working_dir": str(working_dir),
            "bot_command": payload.get(
                "bot_command", "perl openkore.pl --interface 0"
            ),
            "poseidon_command": payload.get("poseidon_command", "perl poseidon.pl"),
            "created_at": int(time.time()),
        }

        self.instances[instance_id] = data
        self._ensure_process_map(instance_id)
        self.save()
        return {"id": instance_id, **data}

    def clone_instance(self, source_id: str, payload: dict) -> dict:
        source = self.instances[source_id]
        clone_name = payload.get("name", f"{source['name']}-clone")
        clone_workdir = Path(payload.get("working_dir") or source["working_dir"]).resolve()

        if payload.get("clone_control_dir"):
            src = Path(source["working_dir"]) / payload["clone_control_dir"]
            dst = clone_workdir / payload["clone_control_dir"]
            if src.exists() and not dst.exists():
                shutil.copytree(src, dst)

        clone_payload = {
            **source,
            "name": clone_name,
            "working_dir": str(clone_workdir),
        }
        return self.create_instance(clone_payload)

    def _ensure_process_map(self, instance_id: str) -> None:
        if instance_id in self.processes:
            return
        inst = self.instances[instance_id]
        cwd = Path(inst["working_dir"]) if inst["working_dir"] else Path.cwd()
        self.processes[instance_id] = {
            "bot": ManagedProcess(inst["bot_command"], cwd, f"{instance_id}:bot"),
            "poseidon": ManagedProcess(
                inst["poseidon_command"], cwd, f"{instance_id}:poseidon"
            ),
        }

    def perform_action(self, instance_id: str, target: str, action: str) -> None:
        if instance_id not in self.instances:
            raise KeyError("Instance not found")
        if target not in ("bot", "poseidon"):
            raise ValueError("Invalid target")

        self._ensure_process_map(instance_id)
        process = self.processes[instance_id][target]
        log_file = LOGS_DIR / f"{instance_id}-{target}.log"

        if action == "start":
            process.start(log_file)
        elif action == "stop":
            process.stop()
        elif action == "restart":
            process.stop()
            process.start(log_file)
        else:
            raise ValueError("Invalid action")

    def logs(self, instance_id: str, target: str, tail: int = 200) -> list[str]:
        self._ensure_process_map(instance_id)
        if target not in ("bot", "poseidon"):
            raise ValueError("Invalid target")
        return self.processes[instance_id][target].read_logs(tail)

    def clear_logs(self, instance_id: str, target: str) -> None:
        self._ensure_process_map(instance_id)
        self.processes[instance_id][target].clear_logs()


STORE = ManagerStore(DATA_FILE)


class ManagerHandler(SimpleHTTPRequestHandler):
    def translate_path(self, path: str) -> str:
        route = urlparse(path).path
        if route in ("/", ""):
            return str(STATIC_DIR / "index.html")
        return str(STATIC_DIR / route.lstrip("/"))

    def do_GET(self) -> None:
        route = urlparse(self.path)
        if route.path == "/api/instances":
            self._json_response(STORE.list_instances())
            return

        if route.path.startswith("/api/instances/") and route.path.endswith("/logs"):
            parts = route.path.strip("/").split("/")
            instance_id = parts[2]
            params = parse_qs(route.query)
            target = params.get("target", ["bot"])[0]
            tail = int(params.get("tail", ["200"])[0])
            try:
                logs = STORE.logs(instance_id, target, tail)
            except Exception as exc:
                self._json_response({"error": str(exc)}, HTTPStatus.BAD_REQUEST)
                return
            self._json_response({"logs": logs})
            return

        super().do_GET()

    def do_POST(self) -> None:
        route = urlparse(self.path)
        length = int(self.headers.get("Content-Length", "0"))
        payload = json.loads(self.rfile.read(length).decode("utf-8") or "{}")

        try:
            if route.path == "/api/instances":
                created = STORE.create_instance(payload)
                self._json_response(created, HTTPStatus.CREATED)
                return

            if route.path.startswith("/api/instances/") and route.path.endswith("/clone"):
                instance_id = route.path.strip("/").split("/")[2]
                cloned = STORE.clone_instance(instance_id, payload)
                self._json_response(cloned, HTTPStatus.CREATED)
                return

            if route.path.startswith("/api/instances/") and route.path.endswith("/clear-logs"):
                parts = route.path.strip("/").split("/")
                instance_id = parts[2]
                target = payload.get("target", "bot")
                STORE.clear_logs(instance_id, target)
                self._json_response({"ok": True})
                return

            if route.path.startswith("/api/instances/") and "/actions/" in route.path:
                parts = route.path.strip("/").split("/")
                instance_id, target, action = parts[2], parts[4], parts[5]
                STORE.perform_action(instance_id, target, action)
                self._json_response({"ok": True})
                return

            self._json_response({"error": "Not found"}, HTTPStatus.NOT_FOUND)
        except Exception as exc:  # API boundary
            self._json_response({"error": str(exc)}, HTTPStatus.BAD_REQUEST)

    def _json_response(self, data: dict | list, status: HTTPStatus = HTTPStatus.OK) -> None:
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def run(host: str, port: int) -> None:
    server = ThreadingHTTPServer((host, port), ManagerHandler)
    print(f"OpenKore Manager running at http://{host}:{port}")
    server.serve_forever()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="OpenKore local manager")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8787)
    args = parser.parse_args()
    run(args.host, args.port)
