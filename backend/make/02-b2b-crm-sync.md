# Make.com Scenario 2 — B2B Lead → CRM + Sales Alert

**Triggered by:** the `submit-b2b-lead` edge function (`MAKE_B2B_WEBHOOK_URL`)
**Fires on:** every bulk-enquiry form submission.

### Incoming webhook payload
```json
{
  "event": "b2b_lead.created",
  "lead": {
    "id": "uuid", "company": "Acme Pvt Ltd", "contact_name": "R. Nair",
    "email": "r.nair@acme.com", "phone": "+91…",
    "quantity_band": "100 – 500", "occasion": "Awards / recognition",
    "message": "Annual awards night, ~200 trophies", "status": "new",
    "created_at": "2026-…Z"
  }
}
```

### Module chain
1. **Webhooks → Custom webhook** — receive the payload.
2. **CRM — Create/Update Contact** (HubSpot / Pipedrive / Zoho / Salesforce):
   match on email; map company, name, phone.
3. **CRM — Create a Deal / Opportunity**:
   - Title: `{{company}} — {{occasion}}`
   - Pipeline stage: *New lead*
   - Notes: quantity band + message.
   - Custom field: `source = storefront_b2b_form`, `lead_id = {{lead.id}}`.
4. **Slack / Email — notify sales** (`#b2b-leads` or sales@): company, quantity
   band, occasion, and a link to the new deal.
5. **Email — acknowledge the lead** (Gmail/SMTP) to `lead.email`:
   "Thanks — a corporate specialist will send your custom quote within 1
   business hour."
6. *(optional)* **Supabase — Update Row**: set `b2b_leads.status = 'contacted'`
   once the CRM deal is created, to keep both systems in step.

### Notes
- Keep this idempotent: matching the CRM contact on email prevents duplicates if
  the same buyer enquires twice.
