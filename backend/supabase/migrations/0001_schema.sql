-- ============================================================================
-- PHOTOSCAN · 0001 · SCHEMA
-- Tables for catalog, customers, orders, personalisation, B2B leads, carts.
-- Money is stored as whole INR (integer rupees) to match the storefront catalog.
-- ============================================================================

create extension if not exists "pgcrypto";      -- gen_random_uuid()

-- ---------- enums (idempotent) ----------
do $$ begin
  create type order_status as enum
    ('placed','in_production','proof_shared','shipped','delivered','cancelled');
exception when duplicate_object then null; end $$;

do $$ begin
  create type lead_status as enum ('new','contacted','quoted','won','lost');
exception when duplicate_object then null; end $$;

-- ---------- updated_at helper ----------
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

-- ---------- categories ----------
create table if not exists categories (
  id      text primary key,          -- 'corporate' | 'couples' | 'birthday' | 'eco'
  title   text not null,
  sort    int  not null default 0
);

-- ---------- products ----------
create table if not exists products (
  id          text primary key,       -- 'aw-acr'
  category_id text not null references categories(id) on delete restrict,
  name        text not null,
  sku         text not null unique,
  price_inr   int  not null check (price_inr >= 0),   -- sale price, whole rupees
  mrp_inr     int  not null check (mrp_inr  >= 0),    -- struck-through MRP
  material    text not null,          -- acrylic|wood|metal|led|ceramic|leather|plant
  fields      text[] not null default '{}',           -- ['photo','text']
  rating      numeric(2,1) not null default 5.0,
  reviews     int not null default 0,
  badge       text,
  blurb       text,
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);
create index if not exists products_category_idx on products(category_id) where active;

-- ---------- customers (profile row, id == auth.uid()) ----------
create table if not exists customers (
  id         uuid primary key references auth.users(id) on delete cascade,
  email      text,
  full_name  text,
  phone      text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
drop trigger if exists trg_customers_updated on customers;
create trigger trg_customers_updated before update on customers
  for each row execute function set_updated_at();

-- ---------- orders ----------
create table if not exists orders (
  id            uuid primary key default gen_random_uuid(),
  human_ref     text not null unique,            -- 'PS-482913'
  customer_id   uuid references customers(id) on delete set null,
  status        order_status not null default 'placed',
  subtotal_inr  int not null,
  delivery_inr  int not null default 0,
  savings_inr   int not null default 0,
  total_inr     int not null,
  contact_email text,
  contact_phone text,
  meta          jsonb not null default '{}',     -- coupon, utm, notes
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index if not exists orders_customer_idx on orders(customer_id);
create index if not exists orders_status_idx   on orders(status);
drop trigger if exists trg_orders_updated on orders;
create trigger trg_orders_updated before update on orders
  for each row execute function set_updated_at();

-- ---------- order_items ----------
create table if not exists order_items (
  id             uuid primary key default gen_random_uuid(),
  order_id       uuid not null references orders(id) on delete cascade,
  product_id     text references products(id) on delete set null,
  sku            text not null,
  name           text not null,
  material       text not null,
  unit_price_inr int  not null,
  qty            int  not null check (qty > 0),
  line_total_inr int  not null
);
create index if not exists order_items_order_idx on order_items(order_id);

-- ---------- personalisations (one per order_item that carries customisation) ----------
create table if not exists personalizations (
  id            uuid primary key default gen_random_uuid(),
  order_item_id uuid not null references order_items(id) on delete cascade,
  custom_text   text,
  font_style    text,                              -- 'serif' | 'mono' | ...
  image_path    text,                              -- storage object path in 'personalization' bucket
  created_at    timestamptz not null default now()
);
create index if not exists personalizations_item_idx on personalizations(order_item_id);

-- ---------- b2b_leads ----------
create table if not exists b2b_leads (
  id            uuid primary key default gen_random_uuid(),
  company       text not null,
  contact_name  text not null,
  email         text not null,
  phone         text,
  quantity_band text,                              -- '25 – 100' etc.
  occasion      text,                              -- 'Awards / recognition' etc.
  message       text,
  status        lead_status not null default 'new',
  source        text not null default 'storefront_b2b_form',
  meta          jsonb not null default '{}',
  created_at    timestamptz not null default now()
);
create index if not exists b2b_leads_status_idx on b2b_leads(status);

-- ---------- abandoned_carts (for recovery automation) ----------
create table if not exists abandoned_carts (
  id           uuid primary key default gen_random_uuid(),
  customer_id  uuid unique references customers(id) on delete cascade,
  cart         jsonb not null default '[]',
  subtotal_inr int  not null default 0,
  recovered    boolean not null default false,
  notified_at  timestamptz,
  updated_at   timestamptz not null default now()
);
create index if not exists abandoned_carts_stale_idx
  on abandoned_carts(updated_at) where recovered = false and notified_at is null;
drop trigger if exists trg_carts_updated on abandoned_carts;
create trigger trg_carts_updated before update on abandoned_carts
  for each row execute function set_updated_at();
