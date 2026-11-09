#!/usr/bin/env python3
"""Render HTTP health endpoint and transparent WebSocket tunnel for OxenWar."""
from __future__ import annotations

import asyncio
import os
import signal
import subprocess
import sys

PUBLIC_PORT = int(os.environ.get("PORT", "10000"))
BACKEND_HOST = "127.0.0.1"
BACKEND_PORT = int(os.environ.get("OXENWAR_PORT", "8081"))
GAME_COMMAND = [
    "godot",
    "--headless",
    "--path",
    "/game",
    "--",
    "--server",
]


async def _copy_stream(source: asyncio.StreamReader, destination: asyncio.StreamWriter) -> None:
    try:
        while True:
            chunk = await source.read(65536)
            if not chunk:
                break
            destination.write(chunk)
            await destination.drain()
    except (ConnectionError, asyncio.CancelledError):
        pass
    finally:
        try:
            destination.close()
        except Exception:
            pass


async def _handle_client(
    reader: asyncio.StreamReader, writer: asyncio.StreamWriter
) -> None:
    backend_writer: asyncio.StreamWriter | None = None
    try:
        header = await asyncio.wait_for(reader.readuntil(b"\r\n\r\n"), timeout=10)
        request_line = header.split(b"\r\n", 1)[0].decode("latin-1", errors="replace")
        if request_line.startswith("GET /health "):
            body = b'{"status":"ok","service":"oxenwar"}\n'
            writer.write(
                b"HTTP/1.1 200 OK\r\n"
                b"Content-Type: application/json\r\n"
                b"Cache-Control: no-store\r\n"
                + f"Content-Length: {len(body)}\r\n".encode("ascii")
                + b"Connection: close\r\n\r\n"
                + body
            )
            await writer.drain()
            return

        backend_reader, backend_writer = await asyncio.open_connection(
            BACKEND_HOST, BACKEND_PORT
        )
        backend_writer.write(header)
        await backend_writer.drain()
        await asyncio.gather(
            _copy_stream(reader, backend_writer),
            _copy_stream(backend_reader, writer),
        )
    except (asyncio.IncompleteReadError, asyncio.LimitOverrunError, asyncio.TimeoutError, ConnectionError):
        # Do not log request headers, tickets, cookies or other client data.
        pass
    finally:
        if backend_writer is not None:
            backend_writer.close()
            try:
                await backend_writer.wait_closed()
            except (ConnectionError, asyncio.CancelledError):
                pass
        writer.close()
        try:
            await writer.wait_closed()
        except (ConnectionError, asyncio.CancelledError):
            pass


async def _wait_for_backend(process: subprocess.Popen[bytes]) -> None:
    loop = asyncio.get_running_loop()
    deadline = loop.time() + 30.0
    while loop.time() < deadline:
        if process.poll() is not None:
            raise RuntimeError("Godot dedicated server exited before becoming ready.")
        try:
            reader, writer = await asyncio.wait_for(
                asyncio.open_connection(BACKEND_HOST, BACKEND_PORT), timeout=1.0
            )
            writer.close()
            await writer.wait_closed()
            return
        except (OSError, asyncio.TimeoutError):
            await asyncio.sleep(0.25)
    raise RuntimeError("Godot dedicated server did not open its WebSocket port in time.")


async def _run() -> int:
    process = subprocess.Popen(GAME_COMMAND)
    try:
        await _wait_for_backend(process)
        server = await asyncio.start_server(_handle_client, "0.0.0.0", PUBLIC_PORT)
        stop_event = asyncio.Event()
        loop = asyncio.get_running_loop()
        for sig in (signal.SIGTERM, signal.SIGINT):
            try:
                loop.add_signal_handler(sig, stop_event.set)
            except NotImplementedError:
                pass

        serve_task = asyncio.create_task(server.serve_forever())
        stop_task = asyncio.create_task(stop_event.wait())
        process_task = asyncio.create_task(asyncio.to_thread(process.wait))
        done, pending = await asyncio.wait(
            {serve_task, stop_task, process_task},
            return_when=asyncio.FIRST_COMPLETED,
        )
        server.close()
        await server.wait_closed()
        for task in pending:
            task.cancel()
        await asyncio.gather(*pending, return_exceptions=True)
        if process.poll() is None:
            process.terminate()
            try:
                await asyncio.wait_for(asyncio.to_thread(process.wait), timeout=20)
            except asyncio.TimeoutError:
                process.kill()
                await asyncio.to_thread(process.wait)
        return process.returncode or 0
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                await asyncio.wait_for(asyncio.to_thread(process.wait), timeout=10)
            except asyncio.TimeoutError:
                process.kill()
                await asyncio.to_thread(process.wait)


if __name__ == "__main__":
    try:
        raise SystemExit(asyncio.run(_run()))
    except Exception as exc:
        # Keep startup diagnostics concise and avoid dumping environment/secrets.
        print(f"OxenWar Render entrypoint failed: {type(exc).__name__}", file=sys.stderr)
        raise SystemExit(1)
