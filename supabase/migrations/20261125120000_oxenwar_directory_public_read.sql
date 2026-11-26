-- Guests (no sign-in) also need to find a server or a room by code. The two read functions only return
-- the host address, mode and map of servers that registered themselves, which is public by design.
-- Tables stay locked: no direct table access for anon/authenticated. Applied to the live project 2026-11-26.
grant execute on function public.oxenwar_find_server() to anon;
grant execute on function public.oxenwar_find_room_server(text) to anon;
