# PHOTOSCAN — Beginner's Deployment Guide

This walks you from zero to a **working online store** — no command line, no
Docker. You'll do everything in your web browser. Follow the phases in order.

> **Good news:** your store starts working after Phase C. Phase D (the email /
> production automations) is an add-on you can switch on afterwards. So don't
> feel you must finish everything in one sitting.

**What you'll need**
- The storefront file `photoscan-store.html` (from the earlier step).
- The backend files in this folder.
- A free **Supabase** account → https://supabase.com
- A free **Make.com** account (only for Phase D) → https://www.make.com
- About 45–60 minutes the first time.

**A few words you'll see a lot**
- *Migration* = a block of database setup code. You paste it and click Run.
- *Edge Function* = a small backend program (your store's "waiter" that safely
  takes orders). You paste code and click Deploy.
- *RLS* = the security rule that stops a visitor from seeing anyone else's data.
- *Webhook* = a URL that, when called, kicks off an automation in Make.com.

---

## PHASE A — Create the database (≈15 min)

### A1. Make a Supabase project
1. Go to https://supabase.com and sign in (GitHub or email).
2. Click **New project**. Pick any name (e.g. `photoscan`).
3. Set a **database password** and **save it somewhere** — you may need it later.
4. Choose the region closest to your customers (e.g. *Mumbai* for India).
5. Click **Create new project** and wait ~2 minutes while it sets up.

### A2. Run the four database files
1. In the left sidebar click **SQL Editor**.
2. Click **+ New query**.
3. Open `backend/supabase/migrations/0001_schema.sql` on your computer, copy **all** of
   it, paste into the editor, and click **Run** (bottom-right). You should see
   *Success. No rows returned* — that's correct.
4. Click **+ New query** again and repeat for each file **in order**:
   - `0002_rls.sql`
   - `0003_storage_and_cron.sql`  *(if you see a warning about `pg_cron`, ignore
     it — that part is optional and commented out)*
   - `0004_seed.sql`  *(this one loads your 16 products)*
   - `0005_admin.sql`  *(needed for the admin panel — see `docs/admin-setup.md`)*
5. Check it worked: sidebar → **Table Editor** → click the **products** table.
   You should see all your products with prices. 🎉

### A3. Turn on guest checkout
Visitors need a lightweight identity to upload photos and place orders without
making an account.
1. Sidebar → **Authentication** → **Sign In / Providers** (or **Providers**).
2. Find **Anonymous** and turn it **On**. Save.

### A4. Confirm the photo storage exists
Sidebar → **Storage**. You should see a **private** bucket called
`personalization`. (Migration `0003` created it.) If it's there, you're set.

---

## PHASE B — Deploy the backend functions (≈15 min)

You'll create two functions now (`create-order` and `submit-b2b-lead`). The
third, `recover-carts`, is optional and covered at the end.

### B1. Find your keys (you'll need them in Phase C)
1. Sidebar → **Project Settings** (gear icon) → **API Keys** (or **API**).
2. Note these two — keep this tab open:
   - **Project URL** — looks like `https://abcdxyz.supabase.co`
   - **anon / publishable key** — a long string, **safe** for the browser.
   > Never use the **service_role / secret** key in the browser. The functions
   > use it automatically on the server; you don't paste it anywhere.

### B2. Create the `create-order` function
1. Sidebar → **Edge Functions**.
2. Click **Deploy a new function** → **Via Editor**.
3. Name it exactly: `create-order`
4. Delete the sample code. Open `backend/deploy-dashboard/create-order.ts`, copy **all**
   of it, and paste it in.
5. Click **Deploy** (or **Deploy function**). Wait for the green success note.

### B3. Create the `submit-b2b-lead` function
1. **Deploy a new function** → **Via Editor** again.
2. Name it exactly: `submit-b2b-lead`
3. Paste all of `backend/deploy-dashboard/submit-b2b-lead.ts`.
4. **Important:** this is a public form, so find the setting labelled
   **"Enforce JWT verification"** (or *Verify JWT*) and turn it **OFF** for this
   function. Leave it **ON** for `create-order`.
5. Click **Deploy**.

### B4. Note your function web address
Your functions now live at:
```
https://YOUR-PROJECT-URL/functions/v1/create-order
https://YOUR-PROJECT-URL/functions/v1/submit-b2b-lead
```
(Replace `YOUR-PROJECT-URL` with your Project URL host, e.g.
`https://abcdxyz.supabase.co`.) You'll paste these into the storefront next.

> You can skip Make.com for now — the functions are written to simply *skip*
> the webhook if it isn't set, so orders and leads still save to your database.

---

## PHASE C — Connect your storefront (≈15 min)

Now you edit `photoscan-store.html` so its buttons talk to the backend. Open the
file in any plain-text editor (VS Code is nice and free, but Notepad works).

Full copy-paste snippets are in **`frontend-wiring.md`**. Here's the minimum to
get orders and leads flowing:

### C1. Load Supabase + sign the visitor in

You'll make **two** small additions in the same spot. Use your editor's Find
(**Ctrl+F**, or **Cmd+F** on Mac) to jump there exactly — don't scroll and guess.

**Find the spot.** Search the file for this text (it appears once):
```
PHOTOSCAN storefront — data + logic
```
Just **above** it is the store's one and only opening `<script>` tag, and just
above that a line ending in `id="toasts"></div>`. That little block is your
anchor:
```html
<div class="toasts" id="toasts"></div>

<script>
/* ============================================================
   PHOTOSCAN storefront — data + logic
```
> Note: the fonts load from `<link>` tags up in the `<head>`, so there is **no**
> font `<script>`. This `<script>` — the one with that comment right under it —
> is the one you want.

**Addition 1 — load the Supabase library.** Put this on its own new line
**between** the `toasts` div and the `<script>` tag (i.e. just *above*
`<script>`):
```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
```

**Addition 2 — start Supabase.** Put this **immediately below** the `<script>`
line (just *above* the `/* ====` comment), filling in your two values from B1:
```js
const sb = supabase.createClient(
  "https://YOUR-PROJECT-URL",     // Project URL, e.g. https://abcdxyz.supabase.co
  "YOUR-ANON-KEY"                 // anon / publishable key
);
let AUTH_READY = (async () => {
  const { data } = await sb.auth.getSession();
  if (!data.session) await sb.auth.signInAnonymously();
})();
```

**After both additions**, that part of the file should look exactly like this
(your added lines are marked ← ADDED):
```html
<div class="toasts" id="toasts"></div>

<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>   <!-- ← ADDED (1) -->
<script>
const sb = supabase.createClient(                        // ← ADDED (2) starts here
  "https://YOUR-PROJECT-URL",
  "YOUR-ANON-KEY"
);
let AUTH_READY = (async () => {
  const { data } = await sb.auth.getSession();
  if (!data.session) await sb.auth.signInAnonymously();
})();                                                    // ← ADDED (2) ends here
/* ============================================================
   PHOTOSCAN storefront — data + logic
```
Save the file. Two common slip-ups: don't paste Addition 1 *inside* the
`<script>` tag (it's its own line, above it), and keep the original `<script>`
line — you're adding around it, not replacing it.

### C2. Make checkout create a real order
Find the function `function checkout(){` and replace its body using the
`checkout()` snippet in `frontend-wiring.md` (section 3). It sends the cart to
your `create-order` function and shows the real order number.

### C3. Make the B2B form save the lead
Find `function submitB2B(e){` and add the `fetch(...)` call from
`frontend-wiring.md` (section 4). Give the form inputs `name` attributes
(`company`, `contact`, `email`, `qty`, `occasion`) so the values are captured.

### C4. (Optional now) Real photo uploads
The live preview already works. To store the actual uploaded image for
production, follow section 1 of `frontend-wiring.md`. You can add this later.

### C5. Try it
1. Open your edited `photoscan-store.html` in a browser (double-click it).
2. Add a product to the bag and click **Secure checkout**.
3. Go back to Supabase → **Table Editor** → **orders**. Your order should be
   there, with the correct total. 🎉
4. Submit the bulk enquiry form, then check the **b2b_leads** table.

If those two tables fill up, **your store is functional.** Everything below is
enhancement.

---

## PHASE D — Turn on the automations (optional, ≈20 min)

This is what emails your customer, alerts your team, and pushes each
personalised order to a production board. You build three "scenarios" in
Make.com; the full field-by-field recipes are in the `make/` folder.

### D1. Create a Make.com webhook
1. Sign in at https://www.make.com → **Create a new scenario**.
2. Add the first module → search **Webhooks** → choose **Custom webhook**.
3. Click **Add**, name it (e.g. `photoscan-orders`), and **copy the URL** it
   gives you.

### D2. Give the webhook URL to your function
1. Back in Supabase → **Edge Functions** → **Secrets** (or Project Settings →
   Edge Functions → Secrets).
2. Add a secret:
   - Name: `MAKE_PRODUCTION_WEBHOOK_URL`
   - Value: the URL you copied.
3. Save. (No re-deploy needed.)

### D3. Build the rest of the scenario
Follow **`make/01-production-routing.md`** step by step — it lists each module
(iterate the items, create a row in Airtable/Google Sheets/Notion, send the
confirmation email, optional SMS/Slack). Turn the scenario **ON** at the end.

### D4. Repeat for the other two
- **B2B → CRM:** new Make webhook → save its URL as secret
  `MAKE_B2B_WEBHOOK_URL` → build using `make/02-b2b-crm-sync.md`.
- **Cart recovery:** new Make webhook → secret `MAKE_ABANDONED_WEBHOOK_URL` →
  build using `make/03-abandoned-cart-recovery.md`. This one also needs the
  optional `recover-carts` function + schedule (see next section).

Test D1–D3: place another order on your store, then watch the Make scenario run
(open it and click **Run once**, or check its History). A row should appear on
your board and a confirmation email should send.

---

## OPTIONAL — Abandoned-cart recovery function

Only needed if you want automatic "you left something behind" emails.
1. Deploy a third function `recover-carts` (Via Editor, paste
   `backend/deploy-dashboard/recover-carts.ts`, JWT verification can stay ON).
2. In `frontend-wiring.md` section 2, add the `persistCart()` call so carts are
   saved as customers build them.
3. Schedule it: open `backend/supabase/migrations/0003_storage_and_cron.sql`, uncomment
   the `cron.schedule(...)` block at the bottom, replace `<PROJECT_REF>` with
   your project id, and run it once in the SQL Editor. This pings the function
   every 15 minutes.

---

## Going truly live (when you're ready)

- **Payments:** the demo takes no money. Add Razorpay or Stripe *before* the
  `create-order` call and pass the payment id along. (Ask me and I'll wire the
  Razorpay flow specifically for India.)
- **Host the storefront:** upload `photoscan-store.html` to any static host —
  Netlify, Vercel, Cloudflare Pages, or even your existing web host — so it has
  a real web address.
- **Lock down security:** set the `STOREFRONT_ORIGIN` secret to your live domain
  so only your site can call the functions.

---

## Troubleshooting

- **Checkout says "failed":** open the browser console (F12 → Console) for the
  error. Usually the Project URL or anon key in C1 has a typo, or the
  `create-order` function name isn't spelled exactly.
- **B2B form does nothing / 401:** make sure you turned **off** JWT verification
  for `submit-b2b-lead` (step B3.4).
- **No order appears:** in Supabase → Edge Functions → click `create-order` →
  **Logs** to see what happened.
- **Photos not saved:** that's expected until you add section 1 of the wiring
  guide — the preview works regardless.
- **Products page empty:** re-run `0004_seed.sql`.

You've got this — take it one phase at a time.
