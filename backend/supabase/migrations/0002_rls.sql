-- ============================================================================
-- PHOTOSCAN · 0002 · ROW LEVEL SECURITY
-- Principle: the browser (anon/authenticated key) can READ the public catalog
-- and READ ONLY ITS OWN customer/order/cart rows. All WRITES that must be
-- trusted (orders, items, personalisations, leads) go through Edge Functions
-- running with the service-role key, which bypasses RLS. The browser never
-- writes prices or order rows directly.
-- ============================================================================

alter table categories       enable row level security;
alter table products         enable row level security;
alter table customers        enable row level security;
alter table orders           enable row level security;
alter table order_items      enable row level security;
alter table personalizations enable row level security;
alter table b2b_leads        enable row level security;
alter table abandoned_carts  enable row level security;

-- ---------- catalog: public read only ----------
drop policy if exists cat_read on categories;
create policy cat_read on categories
  for select to anon, authenticated using (true);

drop policy if exists prod_read on products;
create policy prod_read on products
  for select to anon, authenticated using (active = true);

-- ---------- customers: a user sees & edits only their own profile ----------
drop policy if exists cust_self_select on customers;
create policy cust_self_select on customers
  for select to authenticated using (id = auth.uid());

drop policy if exists cust_self_insert on customers;
create policy cust_self_insert on customers
  for insert to authenticated with check (id = auth.uid());

drop policy if exists cust_self_update on customers;
create policy cust_self_update on customers
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- ---------- orders: read own only; NO client insert (service role only) ----------
drop policy if exists order_self_select on orders;
create policy order_self_select on orders
  for select to authenticated using (customer_id = auth.uid());

-- ---------- order_items: read only when the parent order is yours ----------
drop policy if exists item_self_select on order_items;
create policy item_self_select on order_items
  for select to authenticated using (
    exists (select 1 from orders o
            where o.id = order_items.order_id and o.customer_id = auth.uid())
  );

-- ---------- personalisations: read only via your own order_item ----------
drop policy if exists pers_self_select on personalizations;
create policy pers_self_select on personalizations
  for select to authenticated using (
    exists (
      select 1 from order_items oi
      join orders o on o.id = oi.order_id
      where oi.id = personalizations.order_item_id and o.customer_id = auth.uid()
    )
  );

-- ---------- b2b_leads: NO client read; inserts go through the Edge Function ----------
-- (No select/insert policy for anon/authenticated → only service role can touch it.)

-- ---------- abandoned_carts: a user manages only its own cart snapshot ----------
drop policy if exists cart_self_all on abandoned_carts;
create policy cart_self_all on abandoned_carts
  for all to authenticated
  using (customer_id = auth.uid())
  with check (customer_id = auth.uid());
