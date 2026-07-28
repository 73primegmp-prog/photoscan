// Shared CORS + JSON helpers for all PHOTOSCAN edge functions.
// Lock ALLOW_ORIGIN down to your storefront domain in production.
export const ALLOW_ORIGIN = Deno.env.get("STOREFRONT_ORIGIN") ?? "*";

export const corsHeaders = {
  "Access-Control-Allow-Origin": ALLOW_ORIGIN,
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// Handle the browser preflight. Returns a Response when it was an OPTIONS call.
export function preflight(req: Request): Response | null {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  return null;
}
