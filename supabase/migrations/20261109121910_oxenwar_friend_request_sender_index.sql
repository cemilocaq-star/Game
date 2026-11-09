create index if not exists friend_requests_sender_created_idx on public.friend_requests (sender_id, created_at desc);
