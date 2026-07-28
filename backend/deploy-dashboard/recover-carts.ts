// ============================================================================
// POST /recover-carts     [invoked by pg_cron every 15 min — see 0003 migration]
// Finds carts idle > IDLE_MINUTES with items, not yet recovered or notified,
// and fires one Make.com recovery webhook per cart, then stamps notified_at so
// each shopper is nudged only once. Protect with the service-role bearer.
// ============================================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ---- inlined CORS/JSON helpers (self-contained for dashboard paste) ----
// Shared CORS + JSON helpers for all PHOTOSCAN edge functions.
// Lock ALLOW_ORIGIN down to your storefront domain in production.
const ALLOW_ORIGIN = Deno.env.get("STOREFRONT_ORIGIN") ?? "*";

const corsHeaders = {
  "Access-Control-Allow-Origin": ALLOW_ORIGIN,
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// Handle the browser preflight. Returns a Response when it was an OPTIONS call.
function preflight(req: Request): Response | null {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  return null;
}
// ------------------------------------------------------------------------

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const MAKE_WEBHOOK = Deno.env.get("MAKE_ABANDONED_WEBHOOK_URL") ?? "";
const IDLE_MINUTES = Number(Deno.env.get("ABANDON_IDLE_MINUTES") ?? "60");

Deno.serve(async (req) => {
  // Only the cron job (service key) may run this.
  const jwt = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
  if (jwt !== SERVICE_KEY) return json({ error: "unauthorized" }, 401);

  const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { persistSession: false },
  });

  const cutoff = new Date(Date.now() - IDLE_MINUTES * 60_000).toISOString();

  const { data: carts, error } = await admin
    .from("abandoned_carts")
    .select("id, customer_id, cart, subtotal_inr, updated_at, customers(email, full_name)")
    .eq("recovered", false)
    .is("notified_at", null)
    .lt("updated_at", cutoff)
    .gt("subtotal_inr", 0)
    .limit(100);
  if (error) return json({ error: "query_failed", detail: error.message }, 500);

  let notified = 0;
  for (const c of carts ?? []) {
    const email = (c as any).customers?.email;
    if (!email) continue;
    if (MAKE_WEBHOOK) {
      try {
        await fetch(MAKE_WEBHOOK, {
          method: "POST", headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            event: "cart.abandoned",
            email,
            name: (c as any).customers?.full_name ?? null,
            subtotal_inr: c.subtotal_inr,
            items: c.cart,
          }),
        });
      } catch (_) { continue; }
    }
    await admin.from("abandoned_carts")
      .update({ notified_at: new Date().toISOString() }).eq("id", c.id);
    notified++;
  }

  return json({ ok: true, scanned: carts?.length ?? 0, notified });
});
