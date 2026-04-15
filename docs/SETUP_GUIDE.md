# Incode Identity Verification for Salesforce — Admin Setup Guide

This guide walks you through everything you need to do after installing the **Incode Identity Verification for Salesforce** package. By the end, your team will be able to trigger identity verification directly from any Contact, Lead, or Account record and see results update in real time.

You do not need to be a developer to complete this guide. Each step is numbered and takes about 30–45 minutes total.

---

## Before You Begin

### What you will need from Incode

Before starting, make sure you have received the following from your Incode account team:

| Item | Where to find it |
|---|---|
| **API Key** | Incode Dashboard → Settings → API Keys |
| **Configuration ID** | Incode Dashboard → Configurations → copy the ID of your active configuration |
| **Webhook URL slot** | Incode Dashboard → Configurations → Webhooks (you will paste a URL here in Step 5) |
| **Environment** | Confirm whether you are connecting to the **Demo** environment (`demo-api.incodesmile.com`) or the **Production** environment (`saas-api.incodesmile.com`) |

> **Tip:** If you do not yet have an Incode account or API credentials, contact your Incode sales representative before proceeding. Nothing in this guide will work without a valid API Key and Configuration ID.

### Salesforce prerequisites

- You must be a **Salesforce System Administrator** (or have the "Customize Application" and "Modify All Data" permissions).
- The package must already be installed. If you have not installed it yet, install it from the AppExchange listing before continuing.
- Your org must have **My Domain** enabled (Setup → My Domain). Lightning Experience components require My Domain to be active.

---

## Step 1 — Verify Named Credentials

Named Credentials store the Incode API base URL so Apex code can call the API securely. The package ships with two Named Credentials — one for Demo, one for Production. You do not need to change the URLs, but you should confirm they are present.

1. In Salesforce, click the **gear icon** (top-right) → **Setup**.
2. In the Quick Find box, type `Named Credentials` and click the result.
3. You should see two entries in the list:

   | Developer Name | URL |
   |---|---|
   | `IncodeAPI` | `https://demo-api.incodesmile.com` |
   | `IncodeAPI_Production` | `https://saas-api.incodesmile.com` |

   If either is missing, contact Incode support — the package may not have installed cleanly.

4. You do not need to edit these. The package switches between them automatically based on the Custom Setting you configure in Step 2.

---

## Step 2 — Configure Custom Settings

Custom Settings are where you enter your Incode API Key, Configuration ID, and choose whether to use Demo or Production. This is the most important configuration step.

1. In Setup, type `Custom Settings` in Quick Find and click the result.
2. Find **Incode Config** in the list and click **Manage** next to it.
3. Click **New** (at the top of the page, above the Default Organisation Level Value section).
4. Fill in the fields:

   | Field | What to enter |
   |---|---|
   | **API Key** | Your Incode API Key (e.g. `eyJhbG...`) |
   | **Configuration ID** | Your Incode Configuration ID (e.g. `6421abc123def456`) |
   | **Webhook Secret** | Optional. Leave blank for now — add it later if Incode provides one. |
   | **Use Production API** | Leave **unchecked** for Demo. Check this box **only** when you are ready to go live. |

5. Click **Save**.

   > **Tip:** Start with the Demo environment. Once you have tested end-to-end and confirmed verifications are working, come back here, tick "Use Production API", and save.

---

## Step 3 — Activate the Salesforce Site (Webhook Endpoint)

The Incode platform needs a public HTTPS URL to send verification results back to Salesforce. This is handled by a Salesforce Site called **IncodeWebhook**. You need to make sure it is active.

1. In Setup, type `Sites` in Quick Find and click **Sites**.
2. Look for a site named **IncodeWebhook** in the list.
3. Check the **Status** column:
   - If it says **Active** — you are good. Move on to the next step.
   - If it says **Inactive** — click **Activate** in the action column.
4. Once active, note the **Site URL** in the Domain column. It will look something like:
   ```
   https://yourcompany.my.salesforce-sites.com/IncodeWebhook
   ```
5. Copy this URL. You will need it in Step 5.

   > **Tip:** To get the full webhook path, append `/services/apexrest/incode/webhook` to the Site URL. The complete URL you will paste into the Incode Dashboard is:
   > ```
   > https://yourcompany.my.salesforce-sites.com/IncodeWebhook/services/apexrest/incode/webhook
   > ```

---

## Step 4 — Assign Permission Sets

Two permission sets are included with the package. You need to assign them to the right people.

### Incode_User (for Salesforce users who will request verifications)

1. In Setup, type `Permission Sets` in Quick Find and click the result.
2. Click **Incode User** from the list.
3. Click **Manage Assignments** → **Add Assignments**.
4. Select all users who should be able to request identity verifications (e.g. your sales team, ops team).
5. Click **Assign**.

   > **Tip:** You can also assign permission sets from a user's record. Go to the user record → Permission Set Assignments → Edit Assignments.

### Incode_Webhook_Guest (for the Site guest user — required for webhooks)

This permission set must be assigned to the **Site Guest User** so Incode's webhook can write results back to Salesforce.

1. In Setup, go to **Sites** → click **IncodeWebhook** → click **Public Access Settings**.
2. On the Profile page that opens, scroll down and click **View Users**.
3. You should see one user — the Site Guest User (e.g. `Site Guest User, IncodeWebhook`).
4. Click that user's name to open their user record.
5. Scroll down to **Permission Set Assignments** and click **Edit Assignments**.
6. Move **Incode Webhook Guest** from the Available column to the Enabled column.
7. Click **Save**.

---

## Step 5 — Register the Webhook URL in the Incode Dashboard

You are registering a **Session Completion webhook** — this fires the moment a user finishes (or fails) their verification flow and is what triggers the status update back in Salesforce. Without it, status will stay Pending indefinitely.

1. Log in to the **Incode Dashboard** (your Incode account manager can provide the URL).
2. Navigate to **Configurations** and click the configuration whose **Configuration ID matches what you entered in Step 2**.
3. Inside the configuration, scroll down to the **Webhooks** section and click **Add Webhook** (or **+ New**).
4. Fill in the webhook form:

   | Field | Value |
   |---|---|
   | **URL** | The full Salesforce URL from Step 3 (e.g. `https://yourcompany.my.salesforce-sites.com/IncodeWebhook/services/apexrest/incode/webhook`) |
   | **Method** | `POST` |
   | **Event / Trigger** | Select **Onboarding Finished** (also shown as "Session Complete" or `ONBOARDING_FINISHED` depending on your dashboard version). This is the event that fires when a user completes or fails verification. |
   | **Secret** | If you entered a Webhook Secret in Step 2, enter that same value here. Otherwise leave blank. |

5. Click **Save** (or **Create**).

   > **Why this specific event?** The package listens for `ONBOARDING_FINISHED` — the event Incode fires when a verification session ends. Other mid-flow events (document capture steps, liveness checks) do not need to be registered.

---

## Step 6 — Customise the Verification Email Template

When a Salesforce user clicks "Request Verification," an email is automatically sent to the contact containing a link to the Incode-hosted verification flow. You can customise the look and wording of this email.

1. In Setup, type `Classic Email Templates` in Quick Find and click the result.
2. Navigate to the **Incode Templates** folder.
3. Click **Incode Verification Request** to open the template.
4. Click **Edit**.
5. You can change:
   - The **Subject** line (e.g. "Please verify your identity with [Company Name]")
   - The **body text** — keep the `{!verificationUrl}` merge field in place
   - Company branding, colours, or sign-off text
6. Click **Save**.

   > **Tip:** Do not remove or rename the `{!verificationUrl}` merge field. This is what generates the verification link. If the field is missing, contacts will receive an email with no link.

   > **Tip:** Use the **Send Test and Verify Merge Fields** button to preview the email before going live.

---

## Step 7 — Add the Component to Record Pages

The "Incode Identity Verification" sidebar card needs to be added to your Contact, Lead, and/or Account record pages using the Lightning App Builder.

Repeat these steps for each record type you want to enable (Contact, Lead, Account).

### For Contact pages:

1. Open any Contact record.
2. Click the **gear icon** in the top-right of the record page → **Edit Page**.
3. In the left panel, scroll down to **Custom** components. You should see **Incode Verification**.
4. Drag **Incode Verification** onto the right-hand sidebar of the page layout.
5. Click **Save** → **Activate** → choose **Activate for all users**.
6. Click **Back** to return to the record.

   > If the component shows an error message about missing configuration, go back and check Step 2.

Repeat for Lead and Account pages as needed.

---

## Step 8 — Test End-to-End

Before rolling out to your team, do a test run using a real (or test) email address.

1. Open a Contact record.
2. In the **Incode Identity Verification** sidebar card, confirm the email address (or type in a test address you have access to).
3. Click **Request Verification**.
4. The history table should update within seconds to show a **Pending** row.
5. Check the inbox — you should receive an email with a verification link.
6. Click the link, complete the verification (ID photo + selfie).
7. Return to the Salesforce record. Within ~10 seconds the status should update to **Approved** (green) or **Declined** (red).

---

## Step 9 — Troubleshooting Common Issues

**"Request Verification" button shows an error immediately**
→ Check Custom Settings (Step 2). API Key or Configuration ID is likely wrong or has extra spaces. Confirm the Demo/Production checkbox matches your environment.

**Email is not received by the contact**
→ Check Setup → Email → Deliverability — Access Level must be set to **All Email**. Also check spam.

**Verification status is not updating after the contact completes the flow**
→ Confirm the Site is Active (Step 3). Confirm the **ONBOARDING_FINISHED** event webhook is registered in the Incode Dashboard for the correct configuration (Step 5). Confirm `Incode_Webhook_Guest` is assigned to the Site Guest User (Step 4). Check Setup → Sites → IncodeWebhook → **Site History** for 4xx/5xx errors.

**Component shows a configuration error on the record page**
→ Verify Custom Settings were saved (Step 2) and the logged-in user has the `Incode_User` permission set (Step 4).

**Component is not visible on the record page**
→ Must be added via Lightning App Builder. Go back to Step 7 and confirm you saved and activated the page.

---

## Quick Reference Checklist

- [ ] Obtained API Key and Configuration ID from Incode
- [ ] Named Credentials `IncodeAPI` and `IncodeAPI_Production` are present in Setup
- [ ] Custom Settings: API Key, Configuration ID, and Production toggle configured
- [ ] Salesforce Site `IncodeWebhook` is Active
- [ ] Webhook URL registered in Incode Dashboard, **ONBOARDING_FINISHED** event selected, for the correct configuration
- [ ] `Incode_User` permission set assigned to all relevant Salesforce users
- [ ] `Incode_Webhook_Guest` permission set assigned to the IncodeWebhook Site Guest User
- [ ] Verification email template reviewed and customised
- [ ] `Incode Verification` component added to Contact, Lead, and/or Account record pages
- [ ] End-to-end test completed successfully

---

*For additional support, contact your Incode account team or raise a support request through the Incode customer portal.*
