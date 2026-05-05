# Incode Identity Verification — Salesforce Integration Guide

**Version:** 1.0  
**Last updated:** April 2026  
**Applies to:** Salesforce Lightning Experience (API v59.0+)

---

## Table of Contents

1. [Overview](#1-overview)
2. [How It Works](#2-how-it-works)
3. [Prerequisites](#3-prerequisites)
4. [Installation](#4-installation)
5. [Configuration](#5-configuration)
   - 5.1 [Named Credentials](#51-named-credentials)
   - 5.2 [Custom Settings](#52-custom-settings)
   - 5.3 [Activating the Webhook Site](#53-activating-the-webhook-site)
   - 5.4 [Assigning Permission Sets](#54-assigning-permission-sets)
6. [Webhook Registration](#6-webhook-registration)
7. [Adding the Component to Record Pages](#7-adding-the-component-to-record-pages)
8. [Email Template Customization](#8-email-template-customization)
9. [End-to-End Testing](#9-end-to-end-testing)
10. [Switching to Production](#10-switching-to-production)
11. [Component Reference](#11-component-reference)
12. [Data Model Reference](#12-data-model-reference)
13. [Security Model](#13-security-model)
14. [Troubleshooting](#14-troubleshooting)
15. [FAQ](#15-faq)

---

## 1. Overview

The **Incode Identity Verification for Salesforce** package brings Incode's eKYB (electronic Know Your Business) capabilities directly into your Salesforce org. It allows your team to request, track, and review business identity verification sessions without leaving Salesforce.

### What it does

- Lets Salesforce users trigger a business verification flow from any **Contact**, **Lead**, or **Account** record
- Sends a branded verification email to the individual, containing a link to the Incode-hosted verification experience
- Automatically updates the Salesforce record when verification completes — no manual refresh required
- Displays a full history of verification attempts with real-time status tracking
- Shows detailed eKYB output — entity type, verified fields, UBOs, directors, applied business rules, and individual name match results — directly within the Salesforce record

### Supported objects

| Salesforce Object | Supported |
|---|---|
| Contact | ✓ |
| Lead | ✓ |
| Account | ✓ |

### Supported regions

The integration supports Incode configurations for both US and EU workflows. The eKYB output automatically adapts to the data structure returned by Incode for each region.

---

## 2. How It Works

Understanding the end-to-end flow helps with troubleshooting and configuration.

```
┌────────────────────────────────────────────────────────────┐
│  Salesforce Org                                            │
│                                                            │
│  1. User clicks "Request Verification" in the LWC         │
│         │                                                  │
│         ▼                                                  │
│  2. Apex calls POST /omni/start  ──────────────────────▶  │  Incode API
│     → receives session token + interviewId                │  (Demo or Prod)
│         │                                                  │
│         ▼                                                  │
│  3. Apex calls GET /omni/onboarding-url                   │
│     → receives hosted verification URL                    │
│         │                                                  │
│         ▼                                                  │
│  4. Incode_Verification__c record created (Status: Pending)│
│         │                                                  │
│         ▼                                                  │
│  5. Verification email sent to contact (via Salesforce)   │
│                                                            │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ (out of band) ─ ─ ─ ─ ─ ─ ─ │
│                                                            │
│  6. Contact completes verification on Incode-hosted flow  │
│                                                            │
│  7. Incode fires POST webhook ◀──────────────────────────  │  Incode Platform
│     → IncodeWebhookHandler updates Status__c              │
│     → Score fetched asynchronously                        │
│         │                                                  │
│         ▼                                                  │
│  8. LWC detects status change (10s polling)               │
│     → History table updates, toast notification fires     │
└────────────────────────────────────────────────────────────┘
```

### Status lifecycle

| Status | Meaning |
|---|---|
| **Pending** | Session created; contact has not yet completed verification |
| **Approved** | Verification completed and passed Incode's business rules |
| **Declined** | Verification completed but did not pass |
| **Error** | An unexpected error occurred during the session |

---

## 3. Prerequisites

### From Incode

Before you begin, obtain the following from your Incode account team:

| Item | Where to find it | Required |
|---|---|---|
| **API Key** | Incode Dashboard → Settings → API Keys | Yes |
| **Configuration ID** | Incode Dashboard → Configurations → your active configuration | Yes |
| **Admin Email** | The email address of your Incode admin user | Yes (for viewing session details) |
| **Admin Password** | The password for your Incode admin user | Yes (for viewing session details) |
| **Webhook Secret** | Incode Dashboard → Configurations → Webhooks | Recommended |
| **Environment** | Confirm Demo (`demo-api.incodesmile.com`) or Production (`saas-api.incodesmile.com`) | Yes |

> **Note:** The Admin Email and Admin Password are used to authenticate against the Incode API when a Salesforce user opens a completed verification's detail view. They are not used during the verification request flow itself.

### Salesforce requirements

- **Edition:** Any edition that supports Apex, Lightning Web Components, and Salesforce Sites (Enterprise, Unlimited, Developer, or Performance)
- **My Domain:** Must be enabled and deployed to users (Setup → My Domain)
- **Lightning Experience:** Required. Classic is not supported
- **Administrator access:** Required to complete all configuration steps
- **Outbound Email:** Setup → Email → Deliverability must be set to **All Email**

---

## 4. Installation

### Option A — AppExchange installation *(recommended)*

1. Navigate to the Incode Identity Verification listing on AppExchange.
2. Click **Get It Now**.
3. Choose whether to install in a **Production** org or a **Sandbox**.
4. Select **Install for All Users** (you will restrict access via permission sets in Step 5.4).
5. Approve any third-party access prompts and click **Install**.

The package installs all metadata automatically, including Apex classes, the LWC component, custom objects, permission sets, email templates, and the webhook Site.

### Option B — Manual deployment via Salesforce CLI

For orgs where AppExchange installation is not available (e.g., sandboxes receiving metadata from version control):

```bash
# 1. Clone the repository
git clone https://github.com/Incode-Technologies-Example-Repos/incode-salesforce.git
cd incode-salesforce

# 2. Authenticate to your target org
sf org login web --alias my-org --instance-url https://login.salesforce.com

# 3. Deploy all metadata
sf project deploy start \
  --source-dir force-app \
  --target-org my-org \
  --wait 15
```

> **After deployment:** Salesforce Sites deploy in an **Inactive** state and must be activated manually. See Section 5.3.

### Verifying the installation

After installation, confirm the following are present in your org:

| What to check | Where to look |
|---|---|
| **Apex classes** (8 total) | Setup → Apex Classes → search "Incode" |
| **Lightning component** `incodeVerification` | Setup → Lightning Components → search "Incode" |
| **Custom object** `Incode_Verification__c` | Setup → Object Manager → Incode Verification |
| **Custom setting** `Incode_Config__c` | Setup → Custom Settings → Incode Config |
| **Named Credentials** (2) | Setup → Named Credentials → search "Incode" |
| **Permission sets** (2) | Setup → Permission Sets → search "Incode" |
| **Salesforce Site** `IncodeWebhook` | Setup → Sites |
| **Email template folder** `Incode Templates` | Setup → Classic Email Templates |

---

## 5. Configuration

Work through each sub-section in order. All steps take approximately 30–45 minutes total.

---

### 5.1 Named Credentials

Named Credentials store the Incode API base URLs. The package ships with two — one for Demo, one for Production.

1. Go to **Setup → Named Credentials**.
2. Confirm both entries exist:

   | Developer Name | Endpoint URL |
   |---|---|
   | `IncodeAPI` | `https://demo-api.incodesmile.com` |
   | `IncodeAPI_Production` | `https://saas-api.incodesmile.com` |

3. You do not need to modify the URLs. The package selects the correct credential at runtime based on your Custom Settings configuration (Section 5.2).

> **If a Named Credential is missing:** The package did not install cleanly. Re-run the deployment or contact Incode support.

---

### 5.2 Custom Settings

Custom Settings are where you enter your Incode API credentials. This is the most important configuration step — the package will not function without it.

1. Go to **Setup → Custom Settings**.
2. Find **Incode Config** and click **Manage**.
3. Click **New** in the *Default Organization Level Value* section.
4. Complete the following fields:

   | Field | Description | Example |
   |---|---|---|
   | **API Key** | Your Incode API Key | `2b39fa6f0bd332c0...` |
   | **Configuration ID** | Your Incode Configuration ID | `69d7bfec433f587dad41a824` |
   | **Admin Email** | Incode admin user email (for session detail view) | `admin@yourcompany.com` |
   | **Admin Password** | Incode admin user password | `••••••••` |
   | **Webhook Secret** | Optional. HMAC signing secret for webhook validation | `whsec_abc123...` |
   | **Use Production API** | Leave **unchecked** during setup. Enable only when ready for production | ☐ |

5. Click **Save**.

> **Security note:** The API Key and Admin Password are stored as plain text in Custom Settings. Restrict access to the Incode Config custom setting to System Administrators only via profiles and permission sets.

> **Environment note:** Start with the Demo environment (checkbox unchecked). The Demo API uses real Incode services but with test credentials — no production data is affected.

---

### 5.3 Activating the Webhook Site

Salesforce Sites provide a public HTTPS endpoint that Incode uses to deliver verification results back to your org. The Site is included in the package but must be manually activated.

1. Go to **Setup → Sites**.
2. Find **IncodeWebhook** in the list.
3. If the Status column shows **Inactive**, click **Activate**.
4. Once active, note your full webhook endpoint URL. It follows this pattern:

   ```
   https://<your-domain>.my.salesforce-sites.com/IncodeWebhook/services/apexrest/incode/webhook
   ```

   You will paste this URL into the Incode Dashboard in Section 6.

> **Finding your domain:** The exact domain is shown in the **Site URL** column of the Sites list. If your org uses a custom domain, it may differ from the default pattern above.

---

### 5.4 Assigning Permission Sets

The package includes two permission sets. Both must be assigned correctly for the integration to work.

#### Incode_User — for Salesforce users who request verifications

Assign this to everyone on your team who needs to initiate or view identity verifications.

1. Go to **Setup → Permission Sets → Incode User**.
2. Click **Manage Assignments → Add Assignments**.
3. Select the relevant users and click **Assign**.

#### Incode_Webhook_Guest — for the Site guest user

This permission set must be assigned to the **IncodeWebhook Site Guest User** so that inbound webhook requests from Incode have permission to update verification records.

1. Go to **Setup → Sites**.
2. Click the **IncodeWebhook** site name.
3. Click **Public Access Settings**.
4. On the profile page, click **View Users** (under the Users section).
5. Click the guest user's name to open their record (it will be named something like *Site Guest User, IncodeWebhook*).
6. Scroll to **Permission Set Assignments** and click **Edit Assignments**.
7. Move **Incode Webhook Guest** to the Enabled column and click **Save**.

> **Why this is required:** The Salesforce Site uses a Guest User profile with minimal permissions by default. Without the `Incode_Webhook_Guest` permission set, incoming webhooks will fail silently with a permission error — verifications will never update from Pending.

---

## 6. Webhook Registration

Register the Salesforce webhook endpoint in the Incode Dashboard so that the Incode platform can notify Salesforce when a verification session completes.

1. Log in to the **Incode Dashboard**.
2. Go to **Configurations** and open the configuration whose ID you entered in Section 5.2.
3. Scroll to the **Webhooks** section and click **Add Webhook**.
4. Fill in the form:

   | Field | Value |
   |---|---|
   | **URL** | Your Salesforce Site webhook URL from Section 5.3 |
   | **Method** | `POST` |
   | **Event** | `ONBOARDING_FINISHED` |
   | **Secret** | If you set a Webhook Secret in Section 5.2, enter that same value here |

5. Click **Save**.

> **Why `ONBOARDING_FINISHED`?** This is the event Incode fires when a verification session ends — regardless of whether the result is a pass or fail. Other in-progress events (e.g. document capture step, liveness check) do not need to be registered.

> **HMAC signature validation:** If you configure a Webhook Secret, every inbound webhook is validated using HMAC-SHA256. If the signature does not match, the request is rejected with HTTP 401. This is strongly recommended for production deployments.

### Verifying webhook delivery

After registering, trigger a test verification (see Section 9). Then check **Setup → Sites → IncodeWebhook → View Site History** to confirm the webhook is reaching Salesforce with HTTP 200 responses.

---

## 7. Adding the Component to Record Pages

The **Incode Business Verification** component must be added to your record pages using the Lightning App Builder. Repeat the steps below for each object you want to enable (Contact, Lead, Account).

### Adding to a Contact page

1. Open any **Contact** record.
2. Click the **gear icon** (top-right of the record page) → **Edit Page**.
3. In the left-hand component panel, scroll to the **Custom** section.
4. Find **Incode Verification** and drag it onto the right-hand sidebar.
5. Click **Save**.
6. Click **Activate** → select **Activate for All Users** → click **Save**.
7. Click **← Back** to return to the record.

Repeat for Lead and Account record pages as needed.

> **Tip:** You can also add the component to specific App and Profile combinations using the **Activation** options in the App Builder, enabling the component for select teams or record types only.

---

## 8. Email Template Customization

When a verification is requested, Salesforce automatically sends a branded email to the individual containing their verification link. The default template is professional and ready to use, but you may want to adjust the subject line or body text.

1. Go to **Setup → Classic Email Templates**.
2. Navigate to the **Incode Templates** folder.
3. Click **Incode Verification Request** to open the template.
4. Click **Edit**.
5. Customize as needed:
   - **Subject** — e.g., *"Please complete your business verification for [Company Name]"*
   - **Body text** — adjust messaging, tone, or branding
   - **Colours / logo** — update header colour (`#0070d2` by default) or add a company logo

6. Click **Save**.

> **Important:** The merge field `{!verificationUrl}` must remain in the email body exactly as written. This is replaced at send time with the unique Incode verification link. Removing or renaming it will result in emails with no verification link.

> **Testing:** Use the **Send Test and Verify Merge Fields** button within the template editor to preview the rendered email before going live.

---

## 9. End-to-End Testing

Complete a full test verification before rolling out to your team.

### Test steps

1. Open a **Contact** record.
2. In the **Incode Business Verification** sidebar component, confirm the email address is pre-filled (or enter a test email address you have access to).
3. Click **Request Verification**.
4. Confirm:
   - The history table shows a new row with status **Pending** (orange).
   - A verification email arrives in the specified inbox within 1–2 minutes.
5. Click the verification link in the email and complete the Incode-hosted verification flow.
6. Return to the Salesforce record. Within 10–15 seconds, the status row should update to **Approved** (green) or **Declined** (red).
7. Click the completed row to open the **Session Details** modal and confirm the eKYB output is visible.

### What a successful test confirms

| Check | What it validates |
|---|---|
| Row appears as Pending | API Key, Configuration ID, and Named Credentials are correct |
| Verification email is received | Salesforce email deliverability is configured correctly |
| Status updates after completion | Webhook is registered and the Site Guest User has the correct permission set |
| Session Details modal loads | Admin Email and Admin Password are correct in Custom Settings |

---

## 10. Switching to Production

Once you have successfully tested end-to-end using the Demo environment, follow these steps to go live.

1. Obtain your **Production API Key** from the Incode Dashboard (it is different from the Demo API Key).
2. Go to **Setup → Custom Settings → Incode Config → Manage → Edit**.
3. Update the following fields:
   - **API Key** — replace with your Production API Key
   - **Use Production API** — check this box ✓
4. Click **Save**.
5. Go to **Setup → Named Credentials → IncodeAPI_Production**.
6. Click **Edit** and update the **Password** field with your Production API Key.
7. Click **Save**.
8. In the **Incode Dashboard**, ensure the webhook URL is registered under your **Production** configuration (not just Demo). Register it following the same steps in Section 6.

> **The Production API Key and Demo API Key are separate credentials.** You must update both the Custom Settings and the Named Credential password when switching environments. Leaving either with the Demo key while the other uses the Production key will cause authentication failures.

### Rolling back to Demo

To revert to the Demo environment:
1. Go to **Custom Settings → Incode Config → Manage → Edit**.
2. Uncheck **Use Production API** and restore the Demo API Key.
3. Click **Save**.

No redeployment is required for either switch.

---

## 11. Component Reference

### Incode Business Verification (LWC)

The sidebar component placed on Contact, Lead, and Account record pages.

#### Features

| Feature | Description |
|---|---|
| **Email pre-fill** | Automatically populates the email field from the record's Email field (Contact/Lead) or account name field |
| **Request Verification** | Initiates a new session via the Incode API and sends the verification email |
| **Verification history** | Lists all past verification attempts for the record, newest first |
| **Auto-polling** | Refreshes the status every 10 seconds while any session is Pending |
| **Status badges** | Colour-coded status indicators (green = Approved, red = Declined/Error, orange = Pending) |
| **Session Details modal** | Opens on click for completed sessions; shows full eKYB output |

#### Session Details modal sections

| Section | Content |
|---|---|
| **Customer Input** | Business name, Tax ID, address, and any UBO names or directors submitted for verification |
| **eKYB Output** | Entity type, overall result, verification results table (business name, TIN, address, deliverability, etc.), verification notes, applied business rule |
| **Key People & UBOs** | Collapsible list of beneficial owners and directors. Each person is expandable to show their title(s) or role. Match status indicators show whether submitted names were verified |

#### UBO match status indicators

In the Key People & UBOs section, individual people display a coloured indicator showing the result of any name match check:

| Indicator | Colour | Meaning |
|---|---|---|
| `✓` | Green | The name was submitted and verified |
| `~` | Amber | The name was submitted and returned an approximate match |
| `!` | Red | The name was submitted but could not be verified |

Hovering over any indicator reveals the exact match result text from the Incode API.

> **Region note:** For EU sessions, verification results for UBOs and Directors are shown separately (`uboNameVerificationResults` and `directorsVerificationResults`). Each entry shows independently with its own match status. For US sessions, the match status reflects the overall `uboNameMatch` field.

---

## 12. Data Model Reference

### Incode_Verification__c (Custom Object)

One record is created per verification attempt. Multiple attempts are allowed per Contact/Lead/Account.

| Field | Type | Description |
|---|---|---|
| `Session_ID__c` | Text(255) | Incode session identifier (`interviewId`) from the `/omni/start` API response. This is the durable identifier for the session. |
| `Status__c` | Picklist | Current status: `Pending`, `Approved`, `Declined`, `Error` |
| `Requested_Date__c` | DateTime | When the Salesforce user clicked "Request Verification" |
| `Completed_Date__c` | DateTime | When the Incode platform sent the completion webhook |
| `Score__c` | Number(5,2) | Overall verification score (0–100) fetched after session completion |
| `Verification_URL__c` | URL | The Incode-hosted verification link sent to the contact |
| `Raw_Event_Type__c` | Text(255) | The raw `event_type` value from the incoming webhook (useful for debugging) |
| `External_Reference__c` | Text(255) | The Salesforce record ID of the parent Contact/Lead/Account |
| `Contact__c` | Lookup | Parent Contact record (populated when initiated from a Contact) |
| `Lead__c` | Lookup | Parent Lead record (populated when initiated from a Lead) |
| `Account__c` | Lookup | Parent Account record (populated when initiated from an Account) |
| `Session_Token__c` | Text(255) | Short-lived session token from `/omni/start` (used internally; not for display) |
| `Session_Details__c` | Long Text(131,072) | Cached full session JSON from the Incode `/omni/single-session` endpoint |

> **Note:** `Session_Details__c` is populated the first time a user opens a completed session's detail view. Subsequent views load from this cached value without a live API call.

### Incode_Config__c (Custom Setting — Hierarchy)

Org-level configuration for the Incode integration. Only System Administrators should edit this.

| Field | Type | Description |
|---|---|---|
| `API_Key__c` | Text(255) | Incode API Key — injected into `x-api-key` request headers |
| `Configuration_ID__c` | Text(255) | Incode Configuration ID — sent with every `/omni/start` request |
| `Admin_Email__c` | Text(255) | Incode admin email — used to authenticate against `/executive/log-in` when loading session details |
| `Admin_Password__c` | Text(255) | Incode admin password — same authentication context |
| `Webhook_Secret__c` | Text(255) | Optional HMAC-SHA256 signing secret for webhook signature validation |
| `Use_Production_API__c` | Checkbox | Controls which Named Credential and API environment is used |

---

## 13. Security Model

### Apex classes

| Class | Sharing Model | Reason |
|---|---|---|
| `IncodeService` | `with sharing` | Runs in user context; standard sharing rules apply to record queries |
| `IncodeEmailService` | `with sharing` | Runs in user context |
| `IncodeWebhookHandler` | `without sharing` | Runs as Site Guest User, which has no access to custom objects by default; `without sharing` is required for the handler to query and update verification records |
| `IncodePostInstall` | `global` | Required for `InstallHandler` interface |

### Permission sets

| Permission Set | Assigned to | Access granted |
|---|---|---|
| `Incode_User` | Salesforce users who request/view verifications | Create, Read, Edit on `Incode_Verification__c`; access to `IncodeService`, `IncodeEmailService`; read-only on `Incode_Config__c` |
| `Incode_Webhook_Guest` | IncodeWebhook Site Guest User | Read and Edit on `Incode_Verification__c` (Status, Completed Date, Score, Raw Event Type fields only); access to `IncodeWebhookHandler` |

### Webhook security

If `Webhook_Secret__c` is populated in Custom Settings, all inbound webhook requests are validated using HMAC-SHA256 before any processing occurs:

1. The handler reads the `X-Incode-Signature` header from the request.
2. It computes an HMAC-SHA256 digest of the raw request body using the stored secret.
3. If the computed digest does not match the header value, the request is rejected with **HTTP 401** and no data is changed.

This prevents unauthorized parties from sending forged status updates to your Salesforce org. Enabling webhook signature validation is strongly recommended for production deployments.

### Named Credentials

API endpoint URLs are managed through Salesforce Named Credentials rather than hardcoded strings. This ensures:
- The API Key is not exposed in Apex source code or version control
- Switching environments (Demo ↔ Production) requires only a Custom Setting toggle, not a code change
- Salesforce's credential management handles token storage with encryption at rest

---

## 14. Troubleshooting

### "Request Verification" button shows an error immediately

**Likely cause:** API Key or Configuration ID is missing or incorrect in Custom Settings.

**Resolution:**
1. Go to **Setup → Custom Settings → Incode Config → Manage**.
2. Click **Edit** on the Default Organisation Level Value row.
3. Verify that `API_Key__c` and `Configuration_ID__c` are populated and contain no extra whitespace.
4. Confirm the **Use Production API** checkbox matches the environment you are using.

---

### Verification email is not received

**Likely causes:**
- Salesforce email deliverability is restricted
- Email landed in spam

**Resolution:**
1. Go to **Setup → Email → Deliverability**.
2. Confirm **Access Level** is set to **All Email**.
3. Check the recipient's spam/junk folder.
4. Use the **Send Test** button on the email template to verify Salesforce can send mail from the org.

---

### Verification status is stuck on Pending after the contact completes the flow

This is the most common post-setup issue. Work through the following checks in order:

1. **Is the Site active?**  
   Go to **Setup → Sites**. Confirm IncodeWebhook shows **Active** in the Status column.

2. **Is the webhook registered for the correct event?**  
   Log in to the Incode Dashboard → your Configuration → Webhooks. Confirm the event is `ONBOARDING_FINISHED` (not `SESSION_SUCCEEDED` — the actual fired event is `ONBOARDING_FINISHED`).

3. **Is the webhook URL correct?**  
   The URL must match exactly:  
   `https://<your-domain>.my.salesforce-sites.com/IncodeWebhook/services/apexrest/incode/webhook`

4. **Does the Site Guest User have the permission set?**  
   Follow the steps in Section 5.4 to verify `Incode_Webhook_Guest` is assigned to the IncodeWebhook Guest User.

5. **Are there errors in the Site log?**  
   Go to **Setup → Sites → IncodeWebhook → View Site History**. Look for 4xx or 5xx status codes on incoming POST requests. A 401 means the webhook secret does not match. A 403/500 likely means the guest user permissions are not correct.

---

### Session Details modal shows an error

**Likely cause:** Admin Email or Admin Password is missing or incorrect in Custom Settings.

**Resolution:**
1. Go to **Setup → Custom Settings → Incode Config → Manage → Edit**.
2. Verify that `Admin_Email__c` and `Admin_Password__c` are populated with valid Incode admin credentials.
3. Confirm the credentials work by logging in to the Incode Dashboard with the same email and password.

---

### Component is not visible on the record page

**Resolution:** The component must be added manually via Lightning App Builder. See Section 7. Confirm you clicked **Activate** after saving the page, and that the activation applies to the correct app/profile/record type combination.

---

### Component shows a configuration error on load

**Resolution:** Verify that the logged-in Salesforce user has the `Incode_User` permission set assigned. Without it, the user cannot access the `IncodeService` Apex class or the `Incode_Verification__c` object.

---

## 15. FAQ

**Can multiple verification attempts be made for the same record?**  
Yes. Each click of "Request Verification" creates a new `Incode_Verification__c` record. The component shows the full history with the most recent attempt at the top, marked with a "latest" badge.

**Can I use this with sandbox or developer orgs?**  
Yes. Use the Demo environment (uncheck **Use Production API** in Custom Settings) and point the Incode Dashboard webhook at your sandbox Site URL.

**Does the component work with Person Accounts?**  
Person Accounts are not explicitly supported in the current version. The component targets standard Account records. Support for Person Accounts can be added in a future release.

**What happens if the contact's email address is wrong?**  
The verification email will bounce or go undelivered. The `Incode_Verification__c` record will stay in Pending status indefinitely. You can initiate a new verification request with the corrected email — the old Pending record will remain in the history.

**How long does the verification session link remain valid?**  
Session link validity is configured in the Incode Dashboard under the flow configuration. Contact your Incode account team to adjust the expiry window.

**Can the verification email be sent in languages other than English?**  
The email template can be edited to any language (Section 8). The Incode-hosted verification flow language is controlled by the `language` parameter sent when the session is created — it is currently set to `en-US`. Contact Incode support if multi-language session flows are required.

**Is data from the verification stored in Salesforce?**  
The `Incode_Verification__c` record stores status, score, timestamps, and a cached copy of the full session JSON (up to 128KB) for use in the detail view. No personally identifiable information from the verification (e.g. ID document images, selfie photos) is stored in Salesforce.

**What Incode API endpoints does this integration use?**

| Endpoint | Purpose |
|---|---|
| `POST /omni/start` | Create a new verification session |
| `GET /omni/onboarding-url` | Retrieve the hosted verification link |
| `GET /omni/get/score` | Fetch the verification score after completion |
| `GET /omni/single-session` | Load full session details for the modal view |
| `POST /executive/log-in` | Authenticate as admin to access single-session data |

---

## Support

For questions about this integration, contact the **Incode developer support team** or visit the Incode Developer Hub.

For Salesforce-specific issues (org configuration, permission sets, deployment errors), refer to [Salesforce Help & Training](https://help.salesforce.com).

---

*Incode Identity Verification for Salesforce — © Incode Technologies Inc.*
