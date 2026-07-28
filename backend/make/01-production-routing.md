# Make.com Scenario 1 — Order → Production Dashboard + Customer Notifications

**Triggered by:** the `create-order` edge function (`MAKE_PRODUCTION_WEBHOOK_URL`)
**Fires on:** every successful checkout.

### Incoming webhook payload
```json
{
  "event": "order.placed",
  "order": {
    "id": "uuid", "ref": "PS-482913", "total_inr": 1248,
    "subtotal_inr": 1199, "delivery_inr": 49, "savings_inr": 300,
    "email": "buyer@example.com", "phone": "+91…", "placed_at": "2026-…Z"
  },
  "lines": [
    { "sku": "AW-ACR-11", "name": "Summit Acrylic Excellence Award",
      "material": "acrylic", "qty": 1,
      "engraving_text": "For Priya · Employee of the Year",
      "font": "serif",
      "photo_url": "https://…signed…"   // null when no photo
    }
  ]
}
```

### Module chain
1. **Webhooks → Custom webhook** — receive the payload above.
2. **Iterator** — iterate `lines[]` so each personalised item becomes its own
   production task.
3. **Production dashboard — Create a Record** (pick your tool):
   - *Airtable / Google Sheets / Notion / Trello / ClickUp.*
   - Map: Order Ref, SKU, Product, Material, Qty, Engraving Text, Font,
     **Photo** (use `photo_url`; in Airtable attach via the URL, in Sheets store
     the link). Set status = `Queued`.
4. **Array aggregator** — regroup the iterated lines back into one order summary
   (for the customer email).
5. **Email — Send an email** (Gmail/SMTP) to `order.email`:
   - Subject: `Your PHOTOSCAN order {{order.ref}} is confirmed 🎁`
   - Body: order summary + "we'll share a design proof before we print."
6. **SMS — Send a message** (Twilio/MSG91) to `order.phone` (Router branch, only
   if phone present): short confirmation with the order ref.
7. **Slack — Create a message** to `#production`: "New order {{order.ref}},
   {{lines count}} item(s)." (optional but recommended.)

### Notes
- `photo_url` is a **time-limited signed URL** (default 7 days). If your makers
  need permanent copies, add a step that downloads it and stores it in your own
  drive on receipt.
- Return a 200 quickly; do heavy work in later modules so the storefront isn't
  blocked (the edge function already treats this call as best-effort).
