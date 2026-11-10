#!/usr/bin/env python3
"""End-to-end smoke test: real Godot WebSocket server behind Render's proxy."""
from __future__ import annotations

import base64
import os
import socket
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def _health_check(port: int, process: subprocess.Popen[str], timeout: float = 30.0) -> None:
    deadline = time.monotonic() + timeout
    last_error = "health endpoint did not respond"
    while time.monotonic() < deadline:
        if process.poll() is not None:
            output = process.stdout.read() if process.stdout else ""
            raise AssertionError(
                f"Render entrypoint exited early with code {process.returncode}: {output[-4000:]}"
            )
        try:
            with socket.create_connection(("127.0.0.1", port), timeout=1.0) as client:
                client.sendall(
                    b"GET /health HTTP/1.1\r\n"
                    + f"Host: 127.0.0.1:{port}\r\n".encode("ascii")
                    + b"Connection: close\r\n\r\n"
                )
                response = client.recv(2048)
                if response.startswith(b"HTTP/1.1 200 OK") and b'"status":"ok"' in response:
                    return
                last_error = repr(response[:300])
        except OSError as exc:
            last_error = str(exc)
        time.sleep(0.2)
    raise AssertionError(f"Render health endpoint did not become ready: {last_error}")


def _websocket_upgrade(port: int) -> bytes:
    key = base64.b64encode(os.urandom(16))
    request = (
        b"GET /multiplayer HTTP/1.1\r\n"
        + f"Host: 127.0.0.1:{port}\r\n".encode("ascii")
        + b"Upgrade: websocket\r\n"
        + b"Connection: Upgrade\r\n"
        + b"Sec-WebSocket-Version: 13\r\n"
        + b"Sec-WebSocket-Key: "
        + key
        + b"\r\n\r\n"
    )
    with socket.create_connection(("127.0.0.1", port), timeout=5.0) as client:
        client.settimeout(5.0)
        client.sendall(request)
        response = bytearray()
        while b"\r\n\r\n" not in response and len(response) < 8192:
            chunk = client.recv(1024)
            if not chunk:
                break
            response.extend(chunk)
    return bytes(response)


def main() -> int:
    public_port = _free_port()
    backend_port = _free_port()
    while backend_port == public_port:
        backend_port = _free_port()

    env = os.environ.copy()
    env.update(
        {
            "PORT": str(public_port),
            "OXENWAR_PORT": str(backend_port),
            "OXENWAR_TRANSPORT": "websocket",
            "OXENWAR_SERVER_SECRET": "ci-live-websocket-smoke-test-only",
            "OXENWAR_GAME_PATH": str(ROOT),
        }
    )
    process = subprocess.Popen(
        [sys.executable, str(ROOT / "server" / "render_entrypoint.py")],
        cwd=ROOT,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    try:
        _health_check(public_port, process)
        response = _websocket_upgrade(public_port)
        if not response.startswith(b"HTTP/1.1 101 Switching Protocols"):
            output = process.stdout.read() if process.poll() is not None and process.stdout else ""
            raise AssertionError(
                f"Real Godot WebSocket upgrade failed: {response[:1000]!r}; {output[-3000:]}"
            )
        if b"Sec-WebSocket-Accept:" not in response:
            raise AssertionError("Godot proxy response omitted Sec-WebSocket-Accept")
        print("PASS: real Godot WebSocket handshake succeeds through Render health/proxy entrypoint")
        return 0
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=12)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
        if process.stdout:
            process.stdout.close()


if __name__ == "__main__":
    raise SystemExit(main())
