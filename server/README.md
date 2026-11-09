# OxenWar authoritative dedicated server

## Local run

Install Godot 4.4.1 Standard, then run from the repository root:

```bash
godot --headless --path . -- --server
```

The dedicated server listens on UDP **2456** and accepts up to 32 ENet connections. Each room supports up to 8 players.

## What the server owns

- Supabase access-token verification through `/auth/v1/user`; identity and profile are fetched using the verified token.
- CharacterBody3D movement, gravity, jump, sprint, slide, dash, stamina and arena collision. Clients submit input, never positions or scores.
- Public quick-match assignment and private six-character room codes.
- Private-room admission based on the Supabase friendship row between the joining player and room owner.
- Lobby roster, room membership and 30-second reconnect reservations.
- Round timer, event selection/effect timers, collectible availability/respawn, score and XP awards.
- Match-result persistence through the `oxenwar-server-sync` Edge Function.

## Connect clients

Run the game normally and sign in. Enter the server's LAN/public hostname in the server field, then press **CONNECT**. The client authenticates with its Supabase access token. After successful authentication it enters quick match automatically.

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

Without this secret, players can still authenticate and play on the server, but match stats and collection totals will not be persisted; the Edge Function deliberately rejects the sync request.

## Deploy template

`Dockerfile` and `fly.toml` describe a Fly.io UDP service. Deployment is not performed by this repository change and no public server is online yet. From an authenticated host CLI, after reviewing the provider's current price, UDP support and account terms:

```bash
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
