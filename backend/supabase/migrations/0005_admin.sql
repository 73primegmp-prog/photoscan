-- ============================================================================
-- PHOTOSCAN · 0005 · ADMIN ROLE + POLICIES
-- Creates an `admins` allow-list and grants those users read access to every
-- order/lead/personalisation (and the private photo bucket), plus the ability
-- to update statuses and edit the catalog. Everyone else stays locked out by
-- the policies from 0002. No service-role key is ever needed in the browser.
--
-- TO MAKE YOURSELF AN ADMIN (after you've signed up a user for the admin panel):
--   insert into admins (id, email)
--   select id, email from auth.users where email = 'you@yourbusiness.com';
-- ============================================================================

create table if not exists admins (
  id         uuid primary key references auth.users(id) on delete cascade,
  email      text,
  created_at timestamptz not null default now()
);
alter table admins enable row level security;

-- Is the current caller an admin? SECURITY DEFINER so the check itself isn't
-- blocked by RLS on the admins table.
create or replace function is_admin()
returns boolean
language sql stable security definer set search_path = public
as $$ select exists (select 1 from admins a where a.id = auth.uid()); $$;

revoke all on function is_admin() from public;
grant execute on function is_admin() to anon, authenticated;

-- An admin may see the admin list (e.g. to confirm their own access).
drop policy if exists admins_self_read on admins;
create policy admins_self_read on admins
  for select to authenticated using (is_admin());

-- ---------- read access across the store ----------
drop policy if exists order_admin_select on orders;
create policy order_admin_select on orders
  for select to authenticated using (is_admin());

drop policy if exists order_admin_update on orders;
create policy order_admin_update on orders
  for update to authenticated using (is_admin()) with check (is_admin());

drop policy if exists item_admin_select on order_items;
create policy item_admin_select on order_items
  for select to authenticated using (is_admin());

drop policy if exists pers_admin_select on personalizations;
create policy pers_admin_select on personalizations
  for select to authenticated using (is_admin());

drop policy if exists lead_admin_select on b2b_leads;
create policy lead_admin_select on b2b_leads
  for select to authenticated using (is_admin());

drop policy if exists lead_admin_update on b2b_leads;
create policy lead_admin_update on b2b_leads
  for update to authenticated using (is_admin()) with check (is_admin());

-- ---------- catalog editing (price, active, etc.) ----------
drop policy if exists prod_admin_write on products;
create policy prod_admin_write on products
  for all to authenticated using (is_admin()) with check (is_admin());

drop policy if exists cat_admin_write on categories;
create policy cat_admin_write on categories
  for all to authenticated using (is_admin()) with check (is_admin());

-- ---------- private photo bucket: admins can read (→ mint signed URLs) ----------
drop policy if exists pers_obj_admin_select on storage.objects;
create policy pers_obj_admin_select on storage.objects
  for select to authenticated
  using (bucket_id = 'personalization' and is_admin());
