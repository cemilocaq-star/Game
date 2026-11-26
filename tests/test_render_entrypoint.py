#!/usr/bin/env python3
"""Local-only integration tests for the Render HTTP health/WebSocket tunnel."""
from __future__ import annotations

import asyncio
import importlib.util
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "server" / "render_entrypoint.py"
SPEC = importlib.util.spec_from_file_location("oxenwar_render_entrypoint", SCRIPT)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("Could not load Render entrypoint module")
ENTRYPOINT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ENTRYPOINT)


FULL_UPGRADE = (
    b"GET /multiplayer HTTP/1.1\r\n"
    b"Host: localhost\r\n"
    b"Upgrade: websocket\r\n"
    b"Connection: Upgrade\r\n"
    b"Sec-WebSocket-Version: 13\r\n"
    b"Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\r\n"
)


async def test_health_endpoint() -> None:
    server = await asyncio.start_server(ENTRYPOINT._handle_client, "127.0.0.1", 0)
    port = int(server.sockets[0].getsockname()[1])
    try:
        reader, writer = await asyncio.open_connection("127.0.0.1", port)
        writer.write(
            b"GET /health HTTP/1.1\r\n"
            b"Host: localhost\r\n"
            b"Connection: close\r\n\r\n"
        )
        await writer.drain()
        response = await asyncio.wait_for(reader.read(), timeout=3.0)
        writer.close()
        await writer.wait_closed()
        if not response.startswith(b"HTTP/1.1 200 OK\r\n"):
            raise AssertionError(f"Health endpoint returned unexpected response: {response!r}")
        if b'{"status":"ok","service":"oxenwar"}' not in response:
            raise AssertionError("Health endpoint did not return the expected JSON readiness body")
    finally:
        server.close()
        await server.wait_closed()


async def test_plain_http_is_not_forwarded() -> None:
    # Nothing listens on the backend port: a forwarded request would get 503, a locally answered one 200.
    old_backend_port = ENTRYPOINT.BACKEND_PORT
    ENTRYPOINT.BACKEND_PORT = 1
    server = await asyncio.start_server(ENTRYPOINT._handle_client, "127.0.0.1", 0)
    port = int(server.sockets[0].getsockname()[1])
    try:
        for request, expected in ((b"GET / HTTP/1.1\r\nHost: x\r\nAccept: */*\r\n\r\n", b"HTTP/1.1 200 OK"),
                                  (b"HEAD / HTTP/1.1\r\nHost: x\r\nA: b\r\n\r\n", b"HTTP/1.1 200 OK"),
                                  (b"POST /x HTTP/1.1\r\nHost: x\r\nA: b\r\n\r\n", b"HTTP/1.1 405")):
            reader, writer = await asyncio.open_connection("127.0.0.1", port)
            writer.write(request)
            await writer.drain()
            response = await asyncio.wait_for(reader.read(), timeout=3.0)
            writer.close()
            await writer.wait_closed()
            if not response.startswith(expected):
                raise AssertionError(f"Plain HTTP request {request[:12]!r} got {response[:40]!r}")
    finally:
        ENTRYPOINT.BACKEND_PORT = old_backend_port
        server.close()
        await server.wait_closed()


async def test_incomplete_upgrade_is_not_forwarded() -> None:
    # A backend that fails the test if anything reaches it (Godot would log "Not enough response headers").
    reached = []

    async def forbidden_backend(reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        reached.append(True)
        writer.close()

    backend = await asyncio.start_server(forbidden_backend, "127.0.0.1", 0)
    old_backend_port = ENTRYPOINT.BACKEND_PORT
    ENTRYPOINT.BACKEND_PORT = int(backend.sockets[0].getsockname()[1])
    proxy = await asyncio.start_server(ENTRYPOINT._handle_client, "127.0.0.1", 0)
    port = int(proxy.sockets[0].getsockname()[1])
    try:
        bad_requests = (
            b"GET / HTTP/1.1\r\nHost: x\r\nUpgrade: websocket\r\n\r\n",
            b"GET / HTTP/1.1\r\nHost: x\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n",
            b"GET / HTTP/1.1\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: a\r\nSec-WebSocket-Version: 13\r\n\r\n",
            b"POST / HTTP/1.1\r\nHost: x\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: a\r\nSec-WebSocket-Version: 13\r\n\r\n",
        )
        for request in bad_requests:
            reader, writer = await asyncio.open_connection("127.0.0.1", port)
            writer.write(request)
            await writer.drain()
            response = await asyncio.wait_for(reader.read(), timeout=3.0)
            writer.close()
            await writer.wait_closed()
            if not response.startswith(b"HTTP/1.1 400"):
                raise AssertionError(f"Incomplete upgrade {request[:30]!r} got {response[:40]!r}")
        if reached:
            raise AssertionError("An incomplete WebSocket upgrade reached the Godot backend")
    finally:
        ENTRYPOINT.BACKEND_PORT = old_backend_port
        proxy.close()
        backend.close()
        await proxy.wait_closed()
        await backend.wait_closed()


async def test_websocket_tunnel() -> None:
    async def dummy_godot_backend(
        reader: asyncio.StreamReader, writer: asyncio.StreamWriter
    ) -> None:
        try:
            request = await asyncio.wait_for(
                reader.readuntil(b"\r\n\r\n"), timeout=3.0
            )
            if not request.startswith(b"GET /multiplayer "):
                raise AssertionError("Proxy did not forward the WebSocket request path")
            writer.write(
                b"HTTP/1.1 101 Switching Protocols\r\n"
                b"Upgrade: websocket\r\n"
                b"Connection: Upgrade\r\n\r\n"
            )
            await writer.drain()
            payload = await asyncio.wait_for(reader.readexactly(4), timeout=3.0)
            if payload != b"PING":
                raise AssertionError("Proxy changed the WebSocket data frame bytes")
            writer.write(b"PONG")
            await writer.drain()
        finally:
            writer.close()
            try:
                await writer.wait_closed()
            except ConnectionError:
                pass

    backend = await asyncio.start_server(dummy_godot_backend, "127.0.0.1", 0)
    backend_port = int(backend.sockets[0].getsockname()[1])
    old_backend_port = ENTRYPOINT.BACKEND_PORT
    ENTRYPOINT.BACKEND_PORT = backend_port
    proxy = await asyncio.start_server(ENTRYPOINT._handle_client, "127.0.0.1", 0)
    proxy_port = int(proxy.sockets[0].getsockname()[1])
    try:
        reader, writer = await asyncio.open_connection("127.0.0.1", proxy_port)
        writer.write(
            b"GET /multiplayer HTTP/1.1\r\n"
            b"Host: localhost\r\n"
            b"Upgrade: websocket\r\n"
            b"Connection: Upgrade\r\n"
            b"Sec-WebSocket-Version: 13\r\n"
            b"Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\r\n"
        )
        await writer.drain()
        handshake = await asyncio.wait_for(
            reader.readuntil(b"\r\n\r\n"), timeout=3.0
        )
        if not handshake.startswith(b"HTTP/1.1 101 Switching Protocols"):
            raise AssertionError(f"WebSocket upgrade did not pass through proxy: {handshake!r}")
        writer.write(b"PING")
        await writer.drain()
        payload = await asyncio.wait_for(reader.readexactly(4), timeout=3.0)
        if payload != b"PONG":
            raise AssertionError("WebSocket tunnel did not pass backend data to client")
        writer.close()
        await writer.wait_closed()
    finally:
        proxy.close()
        backend.close()
        await proxy.wait_closed()
        await backend.wait_closed()
        ENTRYPOINT.BACKEND_PORT = old_backend_port


async def test_backend_unavailable() -> None:
    listener = await asyncio.start_server(ENTRYPOINT._handle_client, "127.0.0.1", 0)
    port = listener.sockets[0].getsockname()[1]
    original = ENTRYPOINT.BACKEND_PORT
    # Keep a TCP socket bound but not listening, avoiding a free-port race.
    import socket
    try:
        with socket.socket() as unavailable:
            unavailable.bind(("127.0.0.1", 0))
            ENTRYPOINT.BACKEND_PORT = unavailable.getsockname()[1]
            reader, writer = await asyncio.open_connection("127.0.0.1", port)
            try:
                writer.write(FULL_UPGRADE)
                await writer.drain()
                response = await asyncio.wait_for(reader.read(), timeout=4.0)
                assert response.startswith(b"HTTP/1.1 503 Service Unavailable\r\n"), response
            finally:
                writer.close()
                await writer.wait_closed()
    finally:
        ENTRYPOINT.BACKEND_PORT = original
        listener.close()
        await listener.wait_closed()


async def main() -> None:
    await test_health_endpoint()
    await test_plain_http_is_not_forwarded()
    await test_incomplete_upgrade_is_not_forwarded()
    await test_websocket_tunnel()
    await test_backend_unavailable()
    print("PASS: Render /health endpoint bidirectional WebSocket tunnel and unavailable-backend response")


if __name__ == "__main__":
    asyncio.run(main())
