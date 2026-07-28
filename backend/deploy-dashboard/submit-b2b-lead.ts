// ============================================================================
// POST /submit-b2b-lead    [storefront HOOK: submitB2B()]
// Body: { company, contact_name, email, phone?, quantity_band?, occasion?, message? }
// Stores the lead (service role, RLS-shielded table) and fires the Make.com
// CRM-sync webhook (create deal + notify sales + acknowledge the lead).
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
const MAKE_WEBHOOK = Deno.env.get("MAKE_B2B_WEBHOOK_URL") ?? "";

const isEmail = (s: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s);

Deno.serve(async (req) => {
  const pf = preflight(req); if (pf) return pf;
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  let b: any;
  try { b = await req.json(); } catch { return json({ error: "invalid_json" }, 400); }

  if (!b?.company || !b?.contact_name || !b?.email || !isEmail(b.email))
    return json({ error: "missing_or_invalid_fields" }, 400);

  const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { persistSession: false },
  });

  const { data: lead, error } = await admin.from("b2b_leads").insert({
    company: b.company, contact_name: b.contact_name, email: b.email,
    phone: b.phone ?? null, quantity_band: b.quantity_band ?? null,
    occasion: b.occasion ?? null, message: b.message ?? null,
    meta: b.meta ?? {},
  }).select().single();
  if (error) return json({ error: "lead_insert_failed", detail: error.message }, 500);

  if (MAKE_WEBHOOK) {
    try {
      await fetch(MAKE_WEBHOOK, {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ event: "b2b_lead.created", lead }),
      });
    } catch (_) { /* don't fail the form on webhook error */ }
  }

  return json({ ok: true, lead_id: lead.id });
});
