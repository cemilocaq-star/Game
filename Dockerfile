FROM barichello/godot-ci:4.4.1

WORKDIR /game
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 \
    && rm -rf /var/lib/apt/lists/*
COPY . .
ENV OXENWAR_PORT=8081
EXPOSE 2456/udp
EXPOSE 8081/tcp
EXPOSE 10000/tcp

# Render sends HTTP health checks to PORT; the proxy exposes /health and
# tunnels WebSocket multiplayer upgrades to the private Godot listener.
CMD ["python3", "/game/server/render_entrypoint.py"]
