# OxenWar dedicated server

## Run locally

Install Godot 4.4.1, then from the repository root run:

```bash
godot --headless --path . -- --server
```

The server listens on UDP port **2456** and accepts up to 32 peers.

## Connect a client

Start the game normally. In the multiplayer field enter the server's public hostname or IP address. The default `127.0.0.1` is only for a server running on the same device/network.

## Deploy a dedicated UDP host

The included `Dockerfile` and `fly.toml` are a deployment template for a host that supports public UDP services. Review the provider's current pricing and networking limits before deploying. From a machine with the provider CLI authenticated:

```bash
fly launch --no-deploy --copy-config
fly deploy
```

This repository change does **not** create a hosted instance or incur hosting charges. Deployment requires an account and explicit approval by the project owner.

## Current multiplayer scope and limitations

- One shared session; no matchmaking, room browser, parties, or friend-only invites yet.
- ENet/UDP relays player position, facing direction, display name, and avatar color.
- The server rejects out-of-bounds and implausibly fast position updates.
- This first pass is a **server-relayed movement prototype**, not fully authoritative simulation. Client-side collision, jump, dash, score, pickups, and round events are not server-authoritative yet.
- Supabase account JWTs are not verified by this game server yet. Do not treat the client-supplied display name or cosmetics as trusted identity.
- Use a trusted private test server until JWT authentication, authoritative movement/physics, rate limits, and abuse controls are completed.
