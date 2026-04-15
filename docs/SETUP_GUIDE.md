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

   > **Screenshot callout:** You should see both rows listed under Named Credentials. If either is missing, contact Incode support — the package may not have installed cleanly.

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
   | **Webhook Secret** | Optional. If Incode provided a webhook signing secret, enter it here. You can leave it blank for now and add it later. |
   | **Use Production API** | Leave **unchecked** for Demo. Check this box **only** when you are ready to go live with the Production environment. |

   > **Tip:** Start with the Demo environment. Once you have tested end-to-end and confirmed verifications are working, come back here, tick the "Use Production API" checkbox, and save.

5. Click **Save**.

   > **Screenshot callout:** After saving you should see one row listed under "Default Organisation Level Value" showing your Configuration ID in the name column.

---

## Step 3 — Activate the Salesforce Site (Webhook Endpoint)

The Incode platform needs a public HTTPS URL to send verification results back to Salesforce. This is handled by a Salesforce Site called **IncodeWebhook**. You need to make sure it is active.

1. In Setup, type `Sites` in Quick Find and click **Sites**.
2. Look for a site named **IncodeWebhook** in the list.
3. Check the **Status** column:
   - If it says **Active** — you are good. Move on to the next step.
   - If it says **Inactive** — click **Activate** in the action column.

   > **Screenshot callout:** The Status column should show a green dot and the word "Active" next to IncodeWebhook.

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

   > **Screenshot callout:** After saving, "Incode Webhook Guest" should appear in the Enabled Permission Sets list on the guest user's record.

---

## Step 5 — Register the Webhook URL in the Incode Dashboard

Now you will tell Incode where to send verification results.

1. Log in to the **Incode Dashboard** (your Incode account manager can provide the URL).
2. Navigate to **Configurations** → click your active configuration.
3. Find the **Webhooks** section.
4. Paste the full webhook URL you assembled in Step 3:
   ```
   https://yourcompany.my.salesforce-sites.com/IncodeWebhook/services/apexrest/incode/webhook
   ```
5. Set the HTTP method to **POST** (this is usually the default).
6. Save the configuration.

   > **Screenshot callout:** After saving, the Incode Dashboard should show your Salesforce URL listed as an active webhook endpoint.

   > **Tip:** If you chose to set a **Webhook Secret** in Step 2, make sure you also enter that same secret in the Incode Dashboard's webhook configuration. This allows the package to verify that incoming requests really are from Incode.

---

## Step 6 — Customise the Verification Email Template

When a Salesforce user clicks "Request Verification," an email is automatically sent to the contact containing a link to the Incode-hosted verification flow. You can customise the look and wording of this email.

1. In Setup, type `Classic Email Templates` in Quick Find and click the result.
   - Alternatively, go to **Email Templates** (the newer Lightning path: Setup → Email → Email Templates).
2. Navigate to the **Incode Templates** folder.
3. Click **Incode Verification Request** to open the template.
4. Click **Edit**.
5. You can change:
   - The **Subject** line (e.g. "Please verify your identity with [Company Name]")
   - The **body text** — keep the `{!verificationUrl}` merge field in place, as this is what generates the verification button link
   - Company branding, colours, or sign-off text
6. Click **Save**.

   > **Tip:** Do not remove or rename the `{!verificationUrl}` merge field. The package inserts the unique verification link here automatically. If the field is missing, contacts will receive an email with no link.

   > **Tip:** Send yourself a test email using the **Send Test and Verify Merge Fields** button in the template editor to preview how it looks before going live.

---

## Step 7 — Add the Component to Record Pages

The "Incode Identity Verification" sidebar card needs to be added to your Contact, Lead, and/or Account record pages using the Lightning App Builder.

Repeat these steps for each record type you want to enable (Contact, Lead, Account).

### For Contact pages:

1. Open any Contact record.
2. Click the **gear icon** in the top-right of the record page → **Edit Page**.
   - This opens the Lightning App Builder.
3. In the left panel, scroll down to **Custom** components. You should see **Incode Verification**.
4. Drag **Incode Verification** onto the right-hand sidebar of the page layout (the narrow column on the right).
5. Click **Save** → **Activate** (if prompted).
   - Choose **Activate for all users** unless you want to restrict it to specific profiles or apps.

   > **Screenshot callout:** The sidebar card should appear on the right side of the record page. You will see an email input field and a "Request Verification" button. If the component shows an error message about missing configuration, go back and check Step 2.

6. Click **Back** to return to the record.

Repeat for Lead and Account pages as needed. Each object has its own default record page in the Lightning App Builder.

> **Tip:** If your org uses multiple page layouts or record types, you may need to add the component to each page variant separately. Check with your Salesforce admin if you are unsure which page layout a particular user sees.

---

## Step 8 — Test End-to-End

Before rolling out to your team, do a test run using a real (or test) email address.

1. Open a Contact record (or Lead/Account, depending on what you have set up).
2. In the **Incode Identity Verification** sidebar card, you should see:
   - An email field pre-filled with the contact's email address
   - A **Request Verification** button
3. Confirm the email address is correct (or type in a test address you have access to).
4. Click **Request Verification**.
5. Within a few seconds, the card should update to show a new row in the verification history table with status **Pending**.
   - If you get an error message instead, jump to the Troubleshooting section below.
6. Check the inbox for the email address you used. You should receive an email with a verification link.
7. Click the link in the email. You will be taken to the Incode-hosted verification flow.
8. Complete the verification on your phone or browser (take a photo of an ID document and a selfie).
9. Return to the Salesforce Contact record. Within about 10 seconds (the component polls automatically), the status should update to **Approved** (green) or **Declined** (red).

   > **Screenshot callout:** A successful test will show a green "Approved" badge in the verification history table, with the Session ID, date, and a score value populated.

---

## Step 9 — Troubleshooting Common Issues

### "Request Verification" button shows an error immediately

**Most likely cause:** The API Key or Configuration ID in Custom Settings is incorrect or missing.

- Go back to Step 2 and double-check the values you entered. Make sure there are no extra spaces before or after the key.
- Confirm whether you should be using Demo or Production, and that the "Use Production API" checkbox matches your environment.

### Email is not received by the contact

**Possible causes:**
- The email address on the Contact record is missing or incorrect.
- Salesforce email deliverability is set to "System Email Only." Go to Setup → Email → Deliverability and check that the **Access Level** is set to **All Email**.
- The email went to the contact's spam folder.

### Verification status is not updating after the contact completes the flow

**Most likely cause:** The webhook is not configured correctly or the Site is not active.

- Confirm the Site is Active (Step 3).
- Confirm the full webhook URL is correctly registered in the Incode Dashboard (Step 5).
- Confirm the `Incode_Webhook_Guest` permission set is assigned to the Site Guest User (Step 4).
- In Setup → Sites → click the IncodeWebhook site → **Site History** to see if any requests have come in and whether they produced errors.

### "Incode Verification" component shows a configuration error on the record page

**Possible cause:** The Custom Settings have not been saved, or the permission set has not been assigned to the logged-in user.

- Verify Step 2 (Custom Settings) was completed.
- Verify the logged-in user has the `Incode_User` permission set assigned (Step 4).

### Component is not visible on the record page

The component needs to be added via Lightning App Builder. Go back to Step 7 and confirm you saved and activated the page.

### I see "Pending" status but it never changes

This usually means Incode sent a webhook but Salesforce rejected it. The most common reasons:
- The Site Guest User is missing the `Incode_Webhook_Guest` permission set (Step 4).
- The webhook URL registered in the Incode Dashboard has a typo.
- The Salesforce Site is inactive.

Check the **Site History** log (Setup → Sites → IncodeWebhook → Site History) for any 4xx or 5xx responses from recent webhook calls.

---

## Quick Reference Checklist

Use this checklist to confirm all steps are complete before going live:

- [ ] Obtained API Key and Configuration ID from Incode
- [ ] Named Credentials `IncodeAPI` and `IncodeAPI_Production` are present in Setup
- [ ] Custom Settings: API Key, Configuration ID, and Production toggle are configured
- [ ] Salesforce Site `IncodeWebhook` is Active
- [ ] Webhook URL registered in Incode Dashboard
- [ ] `Incode_User` permission set assigned to all relevant Salesforce users
- [ ] `Incode_Webhook_Guest` permission set assigned to the IncodeWebhook Site Guest User
- [ ] Verification email template reviewed and customised
- [ ] `Incode Verification` component added to Contact, Lead, and/or Account record pages
- [ ] End-to-end test completed successfully

---

*For additional support, contact your Incode account team or raise a support request through the Incode customer portal.*
