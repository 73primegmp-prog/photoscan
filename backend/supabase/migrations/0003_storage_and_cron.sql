-- ============================================================================
-- PHOTOSCAN · 0003 · PRIVATE STORAGE BUCKET + ABANDONED-CART CRON
-- ============================================================================

-- ---------- private bucket for customer-uploaded photos ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('personalization', 'personalization', false, 15728640,   -- 15 MB
        array['image/jpeg','image/png','image/webp','image/heic'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Object paths are namespaced by user id:  personalization/<uid>/<uuid>.<ext>
-- A user may only write/read inside their own <uid> folder. Production systems
-- read originals via short-lived signed URLs minted by the Edge Function
-- (service role), so no public read is ever granted.

drop policy if exists pers_obj_insert on storage.objects;
create policy pers_obj_insert on storage.objects
  for insert to authenticated with check (
    bucket_id = 'personalization'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists pers_obj_select on storage.objects;
create policy pers_obj_select on storage.objects
  for select to authenticated using (
    bucket_id = 'personalization'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists pers_obj_delete on storage.objects;
create policy pers_obj_delete on storage.objects
  for delete to authenticated using (
    bucket_id = 'personalization'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ============================================================================
-- ABANDONED-CART RECOVERY  (pg_cron → pg_net → Edge Function)
-- Runs every 15 min and pings the `recover-carts` function, which finds stale
-- carts and fires the Make.com recovery webhook. Fill in <PROJECT_REF> and set
-- the service key once via:  select vault.create_secret('<KEY>','service_role_key');
-- ============================================================================
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Example schedule (uncomment & edit host after deploying the function):
--
-- select cron.schedule(
--   'photoscan-recover-carts',
--   '*/15 * * * *',
--   $$
--   select net.http_post(
--     url     := 'https://<PROJECT_REF>.supabase.co/functions/v1/recover-carts',
--     headers := jsonb_build_object(
--                  'Content-Type','application/json',
--                  'Authorization','Bearer ' ||
--                    (select decrypted_secret from vault.decrypted_secrets
--                     where name = 'service_role_key')),
--     body    := '{}'::jsonb
--   );
--   $$
-- );
