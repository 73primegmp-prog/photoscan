# Make.com Scenario 3 — Abandoned-Cart Recovery Email

**Triggered by:** the `recover-carts` edge function (`MAKE_ABANDONED_WEBHOOK_URL`),
which pg_cron pings every 15 min. The function does the "which carts are stale
and un-notified" logic and stamps `notified_at`, so Make only has to send.

### Incoming webhook payload (one call per stale cart)
```json
{
  "event": "cart.abandoned",
  "email": "buyer@example.com",
  "name": "Aarav",
  "subtotal_inr": 899,
  "items": [
    { "id": "cp-led", "name": "Aurora LED Acrylic Photo Stand",
      "qty": 1, "price": 899, "material": "led", "text": "Aarav & Meera" }
  ]
}
```

### Module chain
1. **Webhooks → Custom webhook** — receive the payload.
2. **Email — Send an email** to `email`:
   - Subject: `You left something personal behind ✨`
   - Body: greet `name`, list `items` (name + qty), show `subtotal_inr`,
     and a **Return to cart** button linking back to the storefront.
   - Optional: include a one-time discount code to lift conversion.
3. *(optional)* **Router → delay 24h → second email** if still not recovered.

### Why the logic lives in the edge function, not Make
- One source of truth for "stale" (`ABANDON_IDLE_MINUTES`).
- `notified_at` stamping guarantees a shopper is emailed **once**, even if the
  cron overlaps.
- Make stays a thin "send the message" layer — easy to swap Gmail for SendGrid,
  Klaviyo, etc.

### Marking a cart recovered
When a shopper checks out, have the storefront (or the `create-order` function)
set `abandoned_carts.recovered = true` for that `customer_id` so no nudge is
sent after purchase.
