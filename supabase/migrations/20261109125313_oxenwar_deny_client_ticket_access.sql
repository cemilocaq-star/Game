create policy "No client access to game tickets"
on public.oxenwar_game_tickets
for all to anon, authenticated
using (false)
with check (false);

create policy "No client access to server sessions"
on public.oxenwar_server_sessions
for all to anon, authenticated
using (false)
with check (false);
