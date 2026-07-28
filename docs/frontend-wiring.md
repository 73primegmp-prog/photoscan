# Wiring the storefront to this backend

The storefront (`photoscan-store.html`) runs fully in-memory today. To go live,
add the Supabase client, sign the shopper in anonymously, and replace the four
`//HOOK` comments with real calls. Nothing about the UI/animation changes.

---

## 0. Load the client + sign in (once, near the top of your `<script>`)

```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
```
```js
const sb = supabase.createClient(
  "https://<PROJECT_REF>.supabase.co",
  "<anon-public-key>"                 // safe to expose; RLS protects everything
);

// Guest-friendly identity so uploads & orders can be scoped by user id.
// Enable it once in Dashboard → Authentication → Providers → Anonymous.
let AUTH_READY = (async () => {
  const { data } = await sb.auth.getSession();
  if (!data.session) await sb.auth.signInAnonymously();
})();
```

Optional: replace the hard-coded `PRODUCTS`/`CATS` with a live fetch
(`sb.from('products').select('*')`) so the catalog is DB-driven. The demo array
already matches the seed, so this is not required to launch.

---

## 1. `onUpload()` — HOOK: upload photo to the private bucket

Currently the photo is kept as a base64 data URL in `studio.photo`. For
production, upload the file and keep the **storage path** instead (base64 must
never travel to the order API).

```js
// inside rd.onload, replacing the //HOOK line:
await AUTH_READY;
const uid  = (await sb.auth.getUser()).data.user.id;
const ext  = (f.name.split('.').pop() || 'jpg').toLowerCase();
const path = `${uid}/${crypto.randomUUID()}.${ext}`;
const { error } = await sb.storage.from('personalization')
                    .upload(path, f, { contentType: f.type, upsert: false });
if (error) { toast('Upload failed', error.message); return; }
studio.image_path = path;          // <-- carry this on the cart item
```

Then in `addFromStudio()` include `image_path: studio.image_path` on the pushed
cart object (alongside/instead of `photo`). Keep `photo` only for the live
preview thumbnail if you like — just don't send it to `create-order`.

---

## 2. `addFromStudio()` — HOOK: (optional) persist the in-progress cart

To power abandoned-cart recovery, upsert the cart snapshot whenever it changes
(debounce a little). Do the same inside `cItemQty`, `removeItem`, `addUpsell`.

```js
async function persistCart() {
  await AUTH_READY;
  const uid = (await sb.auth.getUser()).data.user.id;
  await sb.from('abandoned_carts').upsert({
    customer_id: uid,
    cart: cart.map(({photo, ...rest}) => rest),   // strip base64
    subtotal_inr: subtotal(),
    recovered: false, notified_at: null
  }, { onConflict: 'customer_id' });
}
```

---

## 3. `checkout()` — HOOK: create the order (server re-prices + routes to production)

Replace the demo order-id generation with a call to the edge function, then show
the real ref in your existing success modal.

Use `sb.functions.invoke` — it automatically attaches the shopper's auth token
and the anon apikey, so you don't hand-build headers or URLs.

```js
async function checkout(){
  if(!cart.length) return;
  await AUTH_READY;
  const { data: out, error } = await sb.functions.invoke('create-order', {
    body: {
      items: cart.map(i => ({
        product_id: i.id, qty: i.qty, material: i.mat,
        text: i.text, font: i.font, image_path: i.image_path || null
      })),
      contact: { email: /* collect at checkout */ null, phone: null }
    }
  });
  if(error || !out?.ok){ toast('Checkout failed', out?.error || 'Please retry'); return; }

  // mark cart recovered so no nudge fires, then render your existing modal:
  const uid = (await sb.auth.getUser()).data.user.id;
  await sb.from('abandoned_carts')
          .update({ recovered:true }).eq('customer_id', uid);

  showOrderModal(out.order_ref, out.total_inr);   // your current modal markup
}
```

> The function ignores any prices from the client and recomputes them from the
> `products` table, writes the order, mints signed photo URLs, and POSTs the
> production payload to Make.com. You get back `{ order_ref, order_id, total_inr }`.

To take real payment, insert a gateway (Razorpay/Stripe) **before** this call and
pass the verified payment id in `meta`; keep order creation server-side.

---

## 4. `submitB2B()` — HOOK: sync lead to CRM

```js
async function submitB2B(e){
  e.preventDefault();
  const f = e.target;
  await sb.functions.invoke('submit-b2b-lead', {
    body: {
      company:      f.company.value,
      contact_name: f.contact.value,
      email:        f.email.value,
      quantity_band:f.qty.value,
      occasion:     f.occasion.value,
      message:      f.message?.value || ""
    }
  });
  // keep your existing success-state UI + toast
}
```

(Give the B2B `<input>`s `name` attributes — `company`, `contact`, `email`,
`qty`, `occasion` — to match the above.)

---

## Deploy order recap
1. `supabase db push` (runs migrations 0001–0004).
2. Dashboard → Auth → enable **Anonymous** sign-ins.
3. Set function secrets, then
   `supabase functions deploy create-order submit-b2b-lead recover-carts`.
4. Build the 3 Make.com scenarios, paste their webhook URLs into the secrets.
5. Uncomment the pg_cron block in `0003` with your project ref.
6. Swap the 4 HOOKs above into the storefront. Ship.
