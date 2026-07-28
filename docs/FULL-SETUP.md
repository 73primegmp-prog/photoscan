# PHOTOSCAN — Full Setup, Start to Finish

Follow these parts **in order**. By the end you'll have a live customer store and
a working admin panel, hosted free. No coding experience needed — you'll paste
code that's already written and click buttons.

- **Your Supabase project URL** (already set in the code): `https://tysmnahbphsbgziywwic.supabase.co`
- **Time:** about 60–90 minutes the first time.
- **Symbols:** 🌐 = click in a website · 📄 = edit a file · 📋 = copy-paste code.

Quick map of what you'll do:
1. Create the Supabase project → 2. Build the database → 3. Turn on guest
checkout → 4. Deploy 3 functions → 5. Add your key to `config.js` → 6. Make your
admin login → 7. Test everything → 8. Push to GitHub → 9. Go live free →
10. (Optional) automations.

---

## PART 0 — Get ready

1. **Download and unzip** `photoscan-github-repo.zip`. You'll get a `photoscan-repo`
   folder — that's your project. Keep it somewhere easy to find.
2. **Install a text editor** (to edit one file). Free: [VS Code](https://code.visualstudio.com).
   Notepad (Windows) / TextEdit (Mac) also work.
3. **Create two free accounts** (no card needed):
   - Supabase → https://supabase.com
   - Make.com → https://www.make.com  *(only needed for Part 10 — skip for now)*

---

## PART 1 — Create your Supabase project

> If you already created the project at the URL above, jump to Part 2.

1. 🌐 Go to https://supabase.com and **Sign in**.
2. Click **New project**.
3. Name it `photoscan`, set a **database password** (save it somewhere safe),
   and pick the region closest to your customers (e.g. **Mumbai** for India).
4. Click **Create new project** and wait ~2 minutes.

### Get your keys (you'll need them twice later)
5. 🌐 Left sidebar → **Project Settings** (gear icon) → **API Keys** (or **API**).
6. Note these two, keep the tab open:
   - **Project URL** — should be `https://tysmnahbphsbgziywwic.supabase.co`
   - **anon / public key** — a long string starting `eyJ...` (browser-safe).
   - ⚠️ Ignore the **service_role / secret** key — you never paste that anywhere.

---

## PART 2 — Build the database (run 5 files)

1. 🌐 Left sidebar → **SQL Editor** → **+ New query**.
2. 📄 On your computer open `backend/supabase/migrations/0001_schema.sql`,
   select **all**, copy.
3. 📋 Paste into the editor, click **Run** (bottom-right).
   You should see *Success. No rows returned* — that's correct.
4. Repeat **one at a time, in this exact order** (New query → paste → Run):
   - `0002_rls.sql`
   - `0003_storage_and_cron.sql` — if you see a yellow `pg_cron` note, ignore it.
   - `0004_seed.sql` — loads your 16 products.
   - `0005_admin.sql` — sets up admin access for the panel.
5. **Check it worked:** sidebar → **Table Editor** → open **products**. You
   should see all your products with prices. 🎉

---

## PART 3 — Turn on guest checkout

Visitors need a lightweight identity to upload photos and order without signing up.

1. 🌐 Sidebar → **Authentication** → **Sign In / Providers** (or **Providers**).
2. Find **Anonymous**, switch it **On**, **Save**.

---

## PART 4 — Deploy the 3 backend functions

These are the small programs that take orders and enquiries. You'll paste each
one in the browser — no command line.

### 4a. create-order
1. 🌐 Sidebar → **Edge Functions** → **Deploy a new function** → **Via Editor**.
2. Name it exactly: `create-order`
3. Delete the sample code. 📄 Open `backend/deploy-dashboard/create-order.ts`,
   copy **all**, 📋 paste it in.
4. Click **Deploy** and wait for the green success message.

### 4b. submit-b2b-lead
1. **Deploy a new function** → **Via Editor**.
2. Name it exactly: `submit-b2b-lead`
3. Paste all of `backend/deploy-dashboard/submit-b2b-lead.ts`.
4. **Important:** find the setting **"Enforce JWT verification"** (or *Verify
   JWT*) and turn it **OFF** for this function only — it's a public form.
   Leave it ON for the other two.
5. Click **Deploy**.

### 4c. recover-carts  *(optional — for abandoned-cart emails; you can add later)*
1. **Deploy a new function** → **Via Editor**, name `recover-carts`.
2. Paste all of `backend/deploy-dashboard/recover-carts.ts`, **Deploy**.

Your functions now live at:
```
https://tysmnahbphsbgziywwic.supabase.co/functions/v1/create-order
https://tysmnahbphsbgziywwic.supabase.co/functions/v1/submit-b2b-lead
```

---

## PART 5 — Add your key to config.js

This one file powers both the store and the admin panel.

1. 📄 Open `config.js` (in the top level of `photoscan-repo`) in your text editor.
2. Replace `PASTE_YOUR_ANON_KEY_HERE` with the **anon / public key** from Part 1
   (keep the quotes). It should look like:
   ```js
   window.PHOTOSCAN_CONFIG = {
     SUPABASE_URL: "https://tysmnahbphsbgziywwic.supabase.co",
     ANON_KEY: "eyJhbGciOiJIUzI1NiIsInR5cCI6..."
   };
   ```
3. **Save** the file.

---

## PART 6 — Create your admin login

The admin panel needs a real account, and that account must be on the `admins`
list.

1. 🌐 Sidebar → **Authentication** → **Users** → **Add user** → **Create new user**.
2. Enter **your email** and a **strong password**. Tick **Auto Confirm User** so
   you can log in immediately. Click **Create user**.
3. 🌐 Sidebar → **SQL Editor** → **+ New query**. 📋 Paste this (use your email):
   ```sql
   insert into admins (id, email)
   select id, email from auth.users where email = 'you@yourbusiness.com';
   ```
4. Click **Run**. It should report *Success* / 1 row.
   (Repeat for any teammate after you create their user.)

---

## PART 7 — Test everything locally

### Test the store
1. 📄 Double-click `index.html` to open it in your browser.
2. Open a product, upload a photo if you like, add it to the bag, click
   **Secure checkout**. You should get a real order number like `PS-482913`.
3. 🌐 Supabase → **Table Editor** → **orders** — your order is there with the
   right total. Check **order_items** and **personalizations** too.
4. Submit the bulk-quote form, then check the **b2b_leads** table.

### Test the admin panel
5. 📄 Open `admin/index.html` in your browser.
6. Sign in with the email/password from Part 6.
7. You should see your test order under **Orders** — click the row to expand and
   see the customer's photo + engraving text. Change its status; try the
   **Catalog** and **Bulk enquiries** tabs.

If orders, leads, and the admin login all work, **your system is functional.**
Parts 8–9 put it online; Part 10 adds emails.

> Something failed? Jump to **Troubleshooting** at the bottom.

---

## PART 8 — Put it on GitHub

You'll need a free GitHub account (https://github.com). Pick **one** option
below. If you've never used Git, use **Option A** — it's all done in your web
browser, nothing to install.

### Option A — Upload in your browser (easiest, no installs)
1. 🌐 On github.com click **+** (top right) → **New repository**.
2. Repository name: `photoscan`. Leave everything else default and click
   **Create repository**.
3. On the new empty repo page, click the **uploading an existing file** link
   (or **Add file → Upload files**).
4. On your computer, **open the `photoscan-repo` folder** and select everything
   *inside* it — `index.html`, `config.js`, and the `admin`, `backend`, `docs`
   folders. **Drag them onto the GitHub page.**
   > Important: drag the **contents** of `photoscan-repo`, not the folder itself,
   > so that `index.html` lands at the top level. GitHub keeps the `admin/`
   > subfolder intact automatically.
5. Wait for the files to finish uploading, then click **Commit changes**.
6. Done — skip to **Part 9**.

### Option B — GitHub Desktop (no terminal)
1. 🌐 On github.com click **+** (top right) → **New repository**. Name it
   `photoscan`, leave it empty (no README), **Create repository**.
2. Open **GitHub Desktop** → **File → Add local repository** → choose your
   `photoscan-repo` folder. If it says the folder isn't a repository, click
   **create a repository** — GitHub Desktop sets it up for you.
3. Give it a summary (e.g. "first commit"), click **Commit to main**, then
   **Publish repository** → pick your `photoscan` repo → **Publish**.

### Option C — Terminal
Open a terminal **inside the `photoscan-repo` folder** and run:
```bash
git init
git add .
git commit -m "PHOTOSCAN: storefront + admin + backend"
git branch -M main
git remote add origin https://github.com/<your-username>/photoscan.git
git push -u origin main
```

---

## PART 9 — Go live for free (GitHub Pages)

1. 🌐 On github.com open your `photoscan` repo → **Settings** → **Pages**.
2. Under **Source**, choose **Deploy from a branch** → Branch: **main** →
   Folder: **/ (root)** → **Save**.
3. Wait ~1 minute, then refresh. Your site is live:
   - **Store:** `https://<username>.github.io/photoscan/`
   - **Admin:** `https://<username>.github.io/photoscan/admin/`
4. **Lock it down (recommended):** 🌐 Supabase → **Edge Functions** →
   **Secrets** → add:
   - Name `STOREFRONT_ORIGIN`, Value `https://<username>.github.io`
   This makes the backend only accept calls from your real site.
   *(Note: after setting this, the store won't work from a double-clicked local
   file anymore — test on the live URL instead. That's expected.)*
5. Open your live store URL and place a test order to confirm it all works online.

🎉 **You're live.** Share the store link with customers; keep the admin link for
your team.

---

## PART 10 — (Optional) Turn on automations

This sends order/confirmation emails and pushes each order to a production board.
Your store already saves everything without it — this is the extra layer.

Build three Make.com scenarios using the recipes in `backend/make/`:

1. 🌐 Make.com → **Create a new scenario** → add module → **Webhooks → Custom
   webhook** → **Add** → **copy the URL**.
2. 🌐 Supabase → **Edge Functions** → **Secrets** → add the URL under the right
   name:
   - Order production/emails → `MAKE_PRODUCTION_WEBHOOK_URL`
     (recipe: `backend/make/01-production-routing.md`)
   - B2B → CRM → `MAKE_B2B_WEBHOOK_URL`
     (recipe: `backend/make/02-b2b-crm-sync.md`)
   - Cart recovery → `MAKE_ABANDONED_WEBHOOK_URL`
     (recipe: `backend/make/03-abandoned-cart-recovery.md`)
3. Finish each scenario's remaining modules per the recipe and switch it **ON**.
4. Cart recovery also needs the `recover-carts` function (Part 4c) and a schedule
   — see the pg_cron block at the bottom of `0003_storage_and_cron.sql`.

Test: place an order on your live store and watch the Make scenario run (open it
→ **Run once**, or check **History**).

---

## PART 11 — When you're ready to sell for real

- **Payments:** checkout currently takes **no money**. Add Razorpay (best for
  India) or Stripe *before* the order is created. Ask me and I'll add it to the
  repo and commit it.
- **Custom domain:** point e.g. `shop.yourbrand.com` at GitHub Pages (Settings →
  Pages → Custom domain), and update `STOREFRONT_ORIGIN` to match.
- **Real product photos:** the previews are crafted graphics; swap in photography
  when you have it.
- **Update the live site later:** edit files → commit → push. GitHub Pages
  redeploys automatically in about a minute.

---

## Troubleshooting

- **Checkout stuck on "Placing order…" or "Checkout failed"** — press **F12** →
  **Console** to see the error. Usually the anon key in `config.js` is wrong/
  missing, or a function name is misspelled. Check Supabase → Edge Functions →
  `create-order` → **Logs**.
- **B2B form does nothing / 401 error** — make sure JWT verification is **OFF**
  for `submit-b2b-lead` (Part 4b, step 4).
- **Admin says "not an admin"** — you missed Part 6 step 3, or used a different
  email. Re-run the insert with the exact email you logged in with.
- **Admin shows no photos** — confirm `0005_admin.sql` ran and the order actually
  had a photo uploaded. Links expire hourly and refresh when you reopen the order.
- **Products page empty** — re-run `0004_seed.sql`.
- **Live site can't reach backend after Part 9 step 4** — your `STOREFRONT_ORIGIN`
  must exactly match your site origin, e.g. `https://username.github.io`
  (no trailing path, no slash).

Take it one part at a time — you've got this.
