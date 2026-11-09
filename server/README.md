# OxenWar authoritative dedicated server

## Local run

Install Godot 4.4.1 Standard, then run from the repository root:

```bash
godot --headless --path . -- --server
```

By default the dedicated server listens on UDP **2456** and accepts up to 32 ENet connections. Set `OXENWAR_TRANSPORT=websocket` to use Godot's WebSocket multiplayer transport instead; hosted web platforms inject `PORT`, and clients connect using `wss://your-hostname`. Each room supports up to 8 players. Game tickets expire after 60 seconds and can be redeemed once; the server-only session lasts 12 hours.

## What the server owns

- Supabase Auth verifies the access token over HTTPS and issues a short-lived, one-time HMAC game ticket. The client sends only that ticket over ENet; the server redeems it once through the Edge Function and receives a server-only session token.
- CharacterBody3D movement, gravity, jump, sprint, slide, dash, stamina and arena collision. Clients submit input, never positions or scores.
- Public quick-match assignment and private six-character room codes.
- Private-room admission based on the Supabase friendship row between the joining player and room owner.
- Lobby roster, room membership and 30-second reconnect reservations.
- Round timer, event selection/effect timers, collectible availability/respawn, score and XP awards.
- Match-result persistence through the `oxenwar-server-sync` Edge Function.

## Connect clients

Run the game normally and sign in. Enter the server's LAN/public hostname in the server field, then press **CONNECT**. For the WebSocket transport, use the complete `wss://` URL; for ENet, use a hostname/IP and expose UDP 2456. The client authenticates with its Supabase access token. After successful authentication it enters quick match automatically.

- **CREATE ROOM** creates a private room.
- Share its six-character code with an existing friend.
- The friend enters that code and presses **JOIN**. The server checks the friendship relation.
- **QUICK MATCH** joins or creates a public room.
- A reconnect within 30 seconds restores the player's room and movement/session state.

The default `127.0.0.1` is only valid when the game client and server run on the same device.

## Required server secret

The Supabase Edge Function is deployed with JWT verification enabled, but it also requires a second secret shared only by the game server and the Edge Function.

1. Generate a random secret locally (for example, `openssl rand -hex 32`). Do not paste it into chat, source files, or GitHub.
2. In Supabase Dashboard → Edge Functions → Secrets, set `OXENWAR_SERVER_SECRET`.
3. On the game-server host, set the exact same value as `OXENWAR_SERVER_SECRET`.
4. Restart/redeploy the server after setting it.

Without this secret, the one-time ticket handshake is disabled, so players cannot authenticate to the game server. The Edge Function deliberately rejects ticket issuance, redemption, friend checks and result sync.

## Deploy template

`Dockerfile` and `fly.toml` describe a Fly.io UDP service. `render.yaml` describes an optional Render WebSocket service for platforms that route HTTP/WebSocket traffic rather than UDP. Deployment is not performed by this repository change and no public server is online yet. A free web-service plan may sleep when idle and is suitable only for a prototype, not a reliability guarantee. From an authenticated host CLI, after reviewing the provider's current price, UDP support and account terms:

```bash
fly launch --no-deploy --copy-config
fly secrets set OXENWAR_SERVER_SECRET="<same-secret-as-Supabase>"
fly deploy
```

Hosting may incur charges. Do not create a paid instance without the account owner's/guardian's approval. After deployment, copy the public hostname into the game's server field. Keep UDP port 2456 open.

## Operational limitations

- Room state and reconnect reservations live in memory. A process restart closes rooms and drops active sessions.
- The server uses the existing arena geometry for collision; adding/changing maps requires updating the dedicated-server collision world too.
- Online friends can be invited from the in-game lobby by username; offline friends can use the shared private room code.
- The server runs a single match round per room. At round completion, results are synced and the room stops accepting movement; use quick match/create room for a new round.
- Real multi-device latency, reconnect and exploit testing remain required before public release.
