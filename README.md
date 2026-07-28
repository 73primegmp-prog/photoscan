# PHOTOSCAN

Personalised gifting & corporate-awards store, with a live customisation studio,
a customer storefront, and an admin panel — all backed by Supabase.

```
photoscan/
├── index.html            ← customer website (the storefront)
├── config.js             ← your Supabase URL + anon key (both pages read this)
├── admin/
│   └── index.html        ← admin panel (orders, photos, leads, catalog)
├── backend/
│   ├── supabase/
│   │   ├── migrations/    ← database: schema, security, storage, seed, admin
│   │   └── functions/     ← create-order, submit-b2b-lead, recover-carts
│   ├── deploy-dashboard/  ← same functions, self-contained for copy-paste
│   ├── make/              ← Make.com automation recipes (production, CRM, recovery)
│   └── .env.example       ← function secrets template
└── docs/
    ├── START-HERE-deployment-guide.md   ← beginner, browser-only walkthrough
    ├── admin-setup.md                   ← turn on the admin panel
    ├── frontend-wiring.md               ← how the pages call the backend
    └── ADVANCED-cli-deployment.md       ← command-line path
```

## What each part does

**Customer website (`index.html`).** Browse gifts, personalise them with a live
preview (upload a photo, type engraving text, pick a finish), and check out.
Checkout, photo upload, and the bulk-quote form all talk to the backend.

**Admin panel (`admin/index.html`).** Staff sign in to see every order with the
customer's photo and engraving text, update order/enquiry statuses, and edit
catalog prices. Protected by database rules — safe to host publicly.

**Backend (`backend/`).** Supabase Postgres with Row Level Security, a private
photo bucket, and three Edge Functions. The `create-order` function re-prices
every cart server-side so totals can't be tampered with. Optional Make.com
scenarios push orders to a production board and send emails.

## Quick start

1. **Create a Supabase project** and run the SQL files in
   `backend/supabase/migrations/` in order (`0001` → `0005`) via the SQL Editor.
2. **Enable Anonymous sign-ins** (Authentication → Providers) for guest checkout.
3. **Deploy the functions** — paste `backend/deploy-dashboard/*.ts` into
   Supabase → Edge Functions (turn off JWT verification for `submit-b2b-lead`).
4. **Fill in `config.js`** with your Project URL and anon key.
5. **Create an admin user** and add them to the `admins` table
   (see `docs/admin-setup.md`).
6. Open `index.html` (shop) and `admin/index.html` (admin) — done.

**Full step-by-step walkthrough (start here): `docs/FULL-SETUP.md`** — every
click from an empty screen to a live, hosted store with the admin panel.

## Put it on GitHub

From this folder:
```bash
git init
git add .
git commit -m "PHOTOSCAN: storefront + admin + backend"
git branch -M main
git remote add origin https://github.com/<your-username>/photoscan.git
git push -u origin main
```
(Create the empty `photoscan` repo on github.com first, without a README.)

## Host it for free (GitHub Pages)

1. Push to GitHub (above).
2. Repo → **Settings** → **Pages** → Source: **Deploy from a branch** →
   `main` / `root` → Save.
3. After a minute your site is live:
   - Storefront: `https://<username>.github.io/photoscan/`
   - Admin: `https://<username>.github.io/photoscan/admin/`
4. In `config.js`, and in the `STOREFRONT_ORIGIN` function secret, use that
   storefront URL so only your site can call the backend.

> Netlify, Vercel, and Cloudflare Pages work the same way — point them at this
> repo and they serve `index.html` and `/admin` automatically.

## Security notes
- The **anon key** in `config.js` is meant to be public; RLS protects your data.
- **Never** commit the `service_role` / secret key. It's only used inside Edge
  Functions, where Supabase injects it automatically.
- Payments aren't wired yet (checkout takes no money). Add Razorpay/Stripe before
  `create-order` when you're ready to go live.
