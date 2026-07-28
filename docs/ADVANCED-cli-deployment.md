> **New here? Use `START-HERE-deployment-guide.md` instead** — it's browser-only,
> no terminal. This file is the faster command-line path for once you're comfortable.

# PHOTOSCAN — Deployment Runbook

Follow these phases in order. By the end you'll have a live storefront that takes
personalised orders, stores photos privately, routes them to production, captures
B2B leads into your CRM, and emails abandoned carts.

**Time:** ~60–90 min the first time.
**You'll need:** the `photoscan-backend` folder, `photoscan-store.html`, a
Supabase account (free), a Make.com account (free), and Node.js 20+ installed
(check with `node -v`).

Legend: 🖥️ = terminal command · 🌐 = something you click in a dashboard.

---

## Phase A — Create the Supabase project

1. 🌐 Go to **database.new** (or app.supabase.com → New project). Pick an org,
   name it `photoscan`, set a strong **database password** (save it), choose the
   region closest to your customers (e.g. Mumbai for India), create.
2. Wait ~2 min for provisioning.
3. 🌐 Open **Project Settings → API** and copy these three — you'll reuse them:
   - **Project URL** — `https://<PROJECT_REF>.supabase.co`
   - **anon / publishable key** (safe for the browser)
   - **service_role / secret key** (server only — never put in the storefront)

> The `<PROJECT_REF>` is the sub-domain in the Project URL. You'll paste it a few
> times below.

---

## Phase B — Create the database (SQL Editor, no tooling needed)

1. 🌐 Left sidebar → **SQL Editor** → **+ New query**.
2. Open `supabase/migrations/0001_schema.sql`, paste its **entire** contents,
   click **Run**. You should see "Success".
3. Repeat, in order, for:
   - `0002_rls.sql`
   - `0003_storage_and_cron.sql`
   - `0004_seed.sql`
4. 🌐 Go to **Table Editor**. Confirm you see `products` with **16 rows** and
   `categories` with **4 rows**. If yes, the schema, security, storage bucket,
   and catalog are all in.

> If `0003` errors on `create extension pg_cron` / `pg_net`, open **Database →
> Extensions**, enable **pg_cron** and **pg_net**, then re-run `0003`. (You can
> skip cron entirely and still launch — recovery just won't be automated yet.)

---

## Phase C — Turn on guest checkout (Anonymous auth)

1. 🌐 **Authentication → Sign In / Providers** (some plans: *Providers*).
2. Under **General configuration**, enable **Allow anonymous sign-ins**. Save.
3. Recommended: on the same Auth settings area, enable **CAPTCHA / Turnstile**
   later to stop bots creating guest users. Not required to launch.

---

## Phase D — Confirm the private photo bucket

1. 🌐 **Storage**. You should see a bucket named **personalization** created by
   migration `0003`, marked **Private** (not public). That's correct — customer
   photos must never be public. If it's missing, re-run `0003`.

---

## Phase E — Deploy the Edge Functions (CLI)

The three functions live in `supabase/functions/`. Deploy them with the Supabase
CLI. You do **not** need Docker for these remote commands.

Run everything from inside the `photoscan-backend` folder:

```bash
cd path/to/photoscan-backend

# 1. Log in (opens a browser to grab an access token)
npx supabase login

# 2. Link this folder to your project (paste your PROJECT_REF)
npx supabase link --project-ref <PROJECT_REF>

# 3. Deploy all three functions (config.toml sets their JWT rules)
npx supabase functions deploy create-order
npx supabase functions deploy submit-b2b-lead
npx supabase functions deploy recover-carts
```

> Using `npx supabase …` needs no global install. Prefer a pinned install?
> `npm install supabase --save-dev` then use `npx supabase …` as above.

**Set the runtime secrets** (do this once; updating them later needs no redeploy).
⚠️ Never set names starting with `SUPABASE_` — `SUPABASE_URL` and
`SUPABASE_SERVICE_ROLE_KEY` are injected automatically and will be rejected here.

```bash
npx supabase secrets set \
  STOREFRONT_ORIGIN=https://your-storefront-domain.com \
  SIGNED_URL_TTL=604800 \
  ABANDON_IDLE_MINUTES=60
```

(You'll add the three `MAKE_*` webhook URLs in Phase F once you have them.)

Verify: `npx supabase secrets list` shows your keys.

---

## Phase F — Build the Make.com automations

Create three scenarios. For each: add a **Webhooks → Custom webhook** trigger,
copy the URL it generates, then build the rest per the spec files.

1. **Production routing** — `make/01-production-routing.md`. Copy its webhook URL.
2. **B2B → CRM** — `make/02-b2b-crm-sync.md`. Copy its webhook URL.
3. **Cart recovery** — `make/03-abandoned-cart-recovery.md`. Copy its webhook URL.

Now hand those URLs to the functions (runtime secrets, no redeploy needed):

```bash
npx supabase secrets set \
  MAKE_PRODUCTION_WEBHOOK_URL=https://hook.eu2.make.com/xxxx \
  MAKE_B2B_WEBHOOK_URL=https://hook.eu2.make.com/yyyy \
  MAKE_ABANDONED_WEBHOOK_URL=https://hook.eu2.make.com/zzzz
```

In Make, turn each scenario **ON** (schedule = "immediately"). Tip: while
building, use each webhook's **"Run once / Determine data structure"** so Make
learns the payload shape from a real test call (see Phase I test).

---

## Phase G — Schedule abandoned-cart recovery (optional but recommended)

1. 🌐 SQL Editor → run once to stash your service key in the vault:
   ```sql
   select vault.create_secret('<your-service_role-key>', 'service_role_key');
   ```
2. 🌐 Open `0003_storage_and_cron.sql`, find the commented `cron.schedule(...)`
   block at the bottom, replace `<PROJECT_REF>`, uncomment it, and run that block
   in the SQL Editor. It now pings `recover-carts` every 15 min.
3. Check it registered: `select * from cron.job;`

---

## Phase H — Wire the storefront to the backend

Open `photoscan-store.html` and apply the four edits in `frontend-wiring.md`:

1. Add the supabase-js script tag + create the client with your **Project URL**
   and **anon key**, and the anonymous sign-in snippet (top of your `<script>`).
2. `onUpload()` → upload the photo to the `personalization` bucket, keep the
   returned `image_path` on the cart item.
3. `checkout()` → call `sb.functions.invoke('create-order', …)` and show the
   returned real order ref in your existing success modal.
4. `submitB2B()` → call `sb.functions.invoke('submit-b2b-lead', …)`. (Give the
   B2B inputs `name` attributes: `company`, `contact`, `email`, `qty`,
   `occasion`.)

Optional: also add the `persistCart()` upsert so recovery has carts to work with.

---

## Phase I — Publish the storefront

It's a single static file — any static host works. Easiest drag-and-drop options:

- **Netlify Drop:** 🌐 app.netlify.com/drop → drag `photoscan-store.html`
  (rename to `index.html` first). Live in seconds.
- **Cloudflare Pages** or **Vercel:** create a project, upload the file.
- **GitHub Pages:** commit `index.html` to a repo, enable Pages.

After it's live, copy the final domain and:
```bash
npx supabase secrets set STOREFRONT_ORIGIN=https://your-live-domain
```
This locks the functions' CORS to your site.

---

## Phase J — End-to-end smoke test

Do a real run on the live site and watch it flow through:

1. **Personalise + order:** open a product, upload a photo, add engraving text,
   add to bag, checkout.
   - 🌐 Supabase **Table Editor → orders**: a new row with a `PS-` ref.
   - 🌐 **order_items / personalizations**: matching rows; `image_path` set.
   - 🌐 **Storage → personalization/**: your photo under a `<uid>/…` folder.
   - 🌐 **Make** scenario 1 history: one run; your production board got a record
     and the confirmation email fired.
2. **Price integrity:** the order `total_inr` was recomputed server-side — even
   if someone edits prices in the browser, the DB total is authoritative.
3. **B2B lead:** submit the bulk form.
   - 🌐 **b2b_leads** table gets a row; **Make** scenario 2 created the CRM deal.
4. **Recovery:** add to cart, don't check out. After `ABANDON_IDLE_MINUTES`, the
   cron fires scenario 3 and you get the recovery email once.

If all four pass, you're live. 🎉

---

## Troubleshooting

- **CORS error in the browser console** → `STOREFRONT_ORIGIN` doesn't match your
  live domain exactly (scheme + host, no trailing slash). Re-set and retry.
- **401 / "Invalid JWT" on checkout** → anonymous sign-ins aren't enabled
  (Phase C), or the client didn't finish `signInAnonymously()` before the call —
  ensure you `await AUTH_READY`.
- **Photo upload "new row violates row-level security"** → the object path isn't
  prefixed with the user's id. Use `${uid}/<uuid>.<ext>` exactly (Phase H, step 2).
- **`unknown_product` from create-order** → the cart item's `product_id` must be
  the catalog `id` (e.g. `cp-led`), not the SKU. Send `i.id`.
- **Make scenario didn't fire** → confirm the `MAKE_*` secret is set
  (`npx supabase secrets list`) and the scenario is switched ON. Check the
  function logs: 🌐 **Edge Functions → [function] → Logs**.
- **Order works but no email** → that's a Make step, not the backend. Check
  scenario 1's email module and its run history for errors.
- **Secrets rejected** → you tried to set a `SUPABASE_*` name. Those are
  reserved and provided automatically; only set `STOREFRONT_ORIGIN`, `MAKE_*`,
  and the two tuning values.

## Go-live checklist
- [ ] 16 products + 4 categories visible in Table Editor
- [ ] Anonymous sign-ins ON
- [ ] `personalization` bucket exists and is **Private**
- [ ] 3 functions deployed; `secrets list` shows STOREFRONT_ORIGIN + 3 MAKE_* + tuning
- [ ] 3 Make scenarios ON with webhook URLs wired
- [ ] cron job registered (or recovery deferred on purpose)
- [ ] storefront wired (4 hooks) and published
- [ ] full smoke test passed (order, photo, production, lead, recovery)
- [ ] payment gateway added before real charges (see frontend-wiring.md)
