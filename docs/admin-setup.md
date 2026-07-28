# Admin panel — setup

The admin panel (`/admin`) lets your team see every order with the customer's
uploaded photo and engraving text, change order/enquiry statuses, and edit
catalog prices. It's a plain web page: all access is enforced by the database,
so even though the page is public, nobody sees anything without an admin login.

## One-time setup

### 1. Run the admin migration
In Supabase → **SQL Editor**, paste and run
`backend/supabase/migrations/0005_admin.sql`. This creates the `admins`
allow-list, the security rules that grant admins access, and lets admins read
the private photo bucket.

### 2. Create your admin login
1. Supabase → **Authentication** → **Users** → **Add user** → **Create new user**.
2. Enter your email + a strong password. (Tick "Auto Confirm User" so you can log
   in right away.)
3. Copy the new user's **UID** (or just use the email in the next step).

### 3. Grant that user admin rights
In **SQL Editor**, run (use your email):
```sql
insert into admins (id, email)
select id, email from auth.users where email = 'you@yourbusiness.com';
```
Re-run this line for each teammate you want to add (after creating their user).

### 4. Fill in config.js
Make sure `/config.js` at the repo root has your Project URL and anon key (the
same file the storefront uses). The admin panel reads `../config.js`.

## Using it
- Open `/admin/` (locally: open `admin/index.html`; hosted: `your-site/admin/`).
- Sign in with the email/password from step 2.
- **Overview** — today's orders, revenue, open orders, new enquiries.
- **Orders** — click a row to expand the production cards: each shows the
  customer's photo (click to open full size), the engraving text in their chosen
  font, the SKU, material and quantity. Change status from the dropdown.
- **Bulk enquiries** — every B2B request; set status as you work the lead.
- **Catalog** — edit sale price or toggle a product active/inactive; Save.

## Notes
- Photo links are **signed** and expire after 1 hour — they're generated fresh
  each time you open an order, so they can't be shared permanently by accident.
- Status changes save instantly. There's no delete button by design (safer);
  use "Cancelled" for orders you want to void.
- Want to restrict who can even load the page? Put the repo (or just `/admin`)
  in a **private** host, or add Cloudflare Access / Netlify password protection.
  The database is already safe either way.
