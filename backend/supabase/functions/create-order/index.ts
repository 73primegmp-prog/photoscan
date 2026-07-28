// ============================================================================
// POST /create-order      [storefront HOOK: checkout()]
// Body: { items: [{ product_id, qty, material, text?, font?, image_path? }],
//         contact?: { email, phone } }
//
// - Resolves the caller from their (anonymous or real) JWT.
// - RE-PRICES every line from the `products` table — client prices are ignored.
// - Writes order + order_items + personalizations with the service-role client.
// - Mints short-lived signed URLs for each uploaded photo and POSTs the whole
//   production payload to the Make.com webhook (dashboard + email/SMS).
// ============================================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { json, preflight } from "../_shared/cors.ts";

const SUPABASE_URL   = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY    = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const MAKE_WEBHOOK   = Deno.env.get("MAKE_PRODUCTION_WEBHOOK_URL") ?? "";
const SIGNED_TTL     = Number(Deno.env.get("SIGNED_URL_TTL") ?? "604800"); // 7 days
const FREE_SHIP_MIN  = 499;
const DELIVERY_FEE   = 49;

Deno.serve(async (req) => {
  const pf = preflight(req); if (pf) return pf;
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { persistSession: false },
  });

  // --- who is ordering? (anonymous auth is fine) ---
  const jwt = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
  const { data: userData } = await admin.auth.getUser(jwt);
  const user = userData?.user ?? null;

  let payload: any;
  try { payload = await req.json(); }
  catch { return json({ error: "invalid_json" }, 400); }

  const items = Array.isArray(payload?.items) ? payload.items : [];
  if (!items.length) return json({ error: "empty_cart" }, 400);

  // --- ensure a customer profile row exists ---
  if (user) {
    await admin.from("customers").upsert({
      id: user.id,
      email: payload?.contact?.email ?? user.email ?? null,
      phone: payload?.contact?.phone ?? null,
    }, { onConflict: "id" });
  }

  // --- authoritative pricing from the DB ---
  const ids = [...new Set(items.map((i: any) => i.product_id))];
  const { data: prods, error: prodErr } = await admin
    .from("products").select("*").in("id", ids).eq("active", true);
  if (prodErr) return json({ error: "catalog_lookup_failed" }, 500);

  const byId = new Map(prods!.map((p: any) => [p.id, p]));
  let subtotal = 0, savings = 0;
  const lineRows: any[] = [];

  for (const it of items) {
    const p = byId.get(it.product_id);
    if (!p) return json({ error: "unknown_product", product_id: it.product_id }, 400);
    const qty = Math.max(1, parseInt(it.qty, 10) || 1);
    const line = p.price_inr * qty;
    subtotal += line;
    savings  += (p.mrp_inr - p.price_inr) * qty;
    lineRows.push({ product: p, qty, line, perso: {
      custom_text: it.text ?? null, font_style: it.font ?? null,
      image_path: it.image_path ?? null, material: it.material ?? p.material,
    }});
  }

  const delivery = subtotal >= FREE_SHIP_MIN ? 0 : DELIVERY_FEE;
  const total    = subtotal + delivery;
  const humanRef = "PS-" + Math.floor(100000 + Math.random() * 900000);

  // --- persist order ---
  const { data: order, error: oErr } = await admin.from("orders").insert({
    human_ref: humanRef, customer_id: user?.id ?? null, subtotal_inr: subtotal,
    delivery_inr: delivery, savings_inr: savings, total_inr: total,
    contact_email: payload?.contact?.email ?? null,
    contact_phone: payload?.contact?.phone ?? null,
    meta: payload?.meta ?? {},
  }).select().single();
  if (oErr) return json({ error: "order_insert_failed", detail: oErr.message }, 500);

  // --- items + personalisations + signed image URLs for production ---
  const productionLines: any[] = [];
  for (const r of lineRows) {
    const { data: item } = await admin.from("order_items").insert({
      order_id: order.id, product_id: r.product.id, sku: r.product.sku,
      name: r.product.name, material: r.perso.material,
      unit_price_inr: r.product.price_inr, qty: r.qty, line_total_inr: r.line,
    }).select().single();

    let signedUrl: string | null = null;
    if (r.perso.image_path) {
      await admin.from("personalizations").insert({
        order_item_id: item!.id, custom_text: r.perso.custom_text,
        font_style: r.perso.font_style, image_path: r.perso.image_path,
      });
      const { data: signed } = await admin.storage
        .from("personalization").createSignedUrl(r.perso.image_path, SIGNED_TTL);
      signedUrl = signed?.signedUrl ?? null;
    } else if (r.perso.custom_text) {
      await admin.from("personalizations").insert({
        order_item_id: item!.id, custom_text: r.perso.custom_text,
        font_style: r.perso.font_style,
      });
    }

    productionLines.push({
      sku: r.product.sku, name: r.product.name, material: r.perso.material,
      qty: r.qty, engraving_text: r.perso.custom_text, font: r.perso.font_style,
      photo_url: signedUrl,   // short-lived link the makers/dashboard pull from
    });
  }

  // --- fire the production + notification workflow (non-blocking best-effort) ---
  if (MAKE_WEBHOOK) {
    try {
      await fetch(MAKE_WEBHOOK, {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          event: "order.placed",
          order: {
            id: order.id, ref: humanRef, total_inr: total, subtotal_inr: subtotal,
            delivery_inr: delivery, savings_inr: savings,
            email: payload?.contact?.email ?? null,
            phone: payload?.contact?.phone ?? null,
            placed_at: order.created_at,
          },
          lines: productionLines,
        }),
      });
    } catch (_) { /* webhook failure must not fail the order */ }
  }

  return json({ ok: true, order_ref: humanRef, order_id: order.id, total_inr: total });
});
