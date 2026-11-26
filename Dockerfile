FROM barichello/godot-ci:4.4.1

WORKDIR /game
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 \
    && rm -rf /var/lib/apt/lists/*
COPY . .
# Build the class-name cache and imported resources once, at image build time. Without this the headless
# server cannot resolve class_name types (ArcadePlayer, GraphicsManager, ...) and main.gd fails to parse.
RUN godot --headless --editor --path /game --quit > /tmp/godot-import.log 2>&1 || true \
    && cat /tmp/godot-import.log | tail -40 \
    && ! grep -E "SCRIPT ERROR: (Parse Error|Compile Error)|Failed to load script" /tmp/godot-import.log
ENV OXENWAR_PORT=8081
EXPOSE 2456/udp
EXPOSE 8081/tcp
EXPOSE 10000/tcp

# Render sends HTTP health checks to PORT; the proxy exposes /health and
# tunnels WebSocket multiplayer upgrades to the private Godot listener.
CMD ["python3", "/game/server/render_entrypoint.py"]
