revoke update on public.friend_requests from authenticated;
grant update (status) on public.friend_requests to authenticated;
revoke insert on public.friend_requests from authenticated;
grant insert (sender_id, receiver_id) on public.friend_requests to authenticated;
revoke insert, update, delete on public.player_cosmetics from authenticated;
revoke insert, update, delete on public.cosmetic_catalog from authenticated;
revoke insert, update, delete on public.player_roles from authenticated;
revoke insert, update, delete on public.friendships from authenticated;
