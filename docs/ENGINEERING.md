# Incode Identity Verification for Salesforce — Engineering Reference

**Repository:** https://github.com/incode-id/incode-salesforce  
**Package type:** Salesforce Second-Generation Managed Package (2GP)  
**API version:** 59.0  
**Last updated:** April 2026

This document is the internal reference for engineers maintaining, extending, or deploying this package. It assumes familiarity with Salesforce DX, Apex, Lightning Web Components, and REST APIs.

---

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Salesforce Org                              │
│                                                                     │
│  ┌──────────────────────┐     ┌───────────────────────────────┐    │
│  │  LWC: incodeVerifi-  │────▶│  Apex: IncodeService          │    │
│  │  cation              │     │  - startSession()             │    │
│  │  - Email input       │     │  - getOnboardingUrl()         │    │
│  │  - Request button    │     │  - getVerifications()         │    │
│  │  - History table     │◀────│  - saveVerificationRecord()   │    │
│  │  - 10s auto-poll     │     └──────────────┬────────────────┘    │
│  └──────────────────────┘                    │                     │
│                                              │ Named Credential     │
│  ┌──────────────────────────────────┐        │ (IncodeAPI /         │
│  │  Custom Object:                  │        │  IncodeAPI_Prod)     │
│  │  Incode_Verification__c          │        │                     │
│  │  - Session_ID__c                 │        ▼                     │
│  │  - Status__c                     │  ┌──────────────────────┐   │
│  │  - Score__c                      │  │  Incode REST API     │   │
│  │  - Contact__c / Lead__c /        │  │  /omni/start         │   │
│  │    Account__c                    │  │  /omni/onboarding-url│   │
│  └──────────────┬───────────────────┘  └──────────────────────┘   │
│                 │                                                   │
│                 │ writes                                            │
│                 ▼                                                   │
│  ┌──────────────────────────────────┐                              │
│  │  Apex: IncodeWebhookHandler      │◀─── POST (Incode platform)   │
│  │  @RestResource (without sharing) │     via Salesforce Site      │
│  │  /incode/webhook                 │     (IncodeWebhook)          │
│  └──────────────────────────────────┘                              │
│                                                                     │
│  ┌──────────────────────────────────┐                              │
│  │  Apex: IncodeEmailService        │──▶ Salesforce Email          │
│  │  - sendVerificationEmail()       │    (to end-user contact)     │
│  └──────────────────────────────────┘                              │
│                                                                     │
│  ┌──────────────────────────────────┐                              │
│  │  Custom Setting: Incode_Config__c│                              │
│  │  - API_Key__c                    │                              │
│  │  - Configuration_ID__c           │                              │
│  │  - Use_Production_API__c         │                              │
│  └──────────────────────────────────┘                              │
└─────────────────────────────────────────────────────────────────────┘
```

**Data flow summary:**
- The LWC calls `IncodeService` via `@wire` (for reads) and `@AuraEnabled` imperative calls (for writes).
- `IncodeService` calls the Incode REST API using Named Credentials, persists results to `Incode_Verification__c`, and triggers `IncodeEmailService`.
- The Incode platform completes verification out-of-band and fires a POST to the Salesforce Site endpoint.
- `IncodeWebhookHandler` processes the POST and updates the `Incode_Verification__c` record status.
- The LWC polls every 10 seconds by re-calling `getVerifications()`, picking up the updated status.

---

## 2. End-to-End Flow

### Step-by-step with API calls

1. **User opens a Contact/Lead/Account record.**  
   The `incodeVerification` LWC mounts. It calls `IncodeService.getVerifications(recordId)` via `@wire` to populate the history table with any existing verification attempts.

2. **User enters an email and clicks "Request Verification."**  
   The LWC calls `IncodeService.requestVerification(recordId, email, objectType)` imperatively.

3. **`IncodeService.startSession()` — POST to `/omni/start`**
   ```
   POST https://demo-api.incodesmile.com/omni/start
   Headers:
     X-Incode-Hardware-Id: <Configuration_ID__c>
     X-Incode-Hardware-Id: <from Incode_Config__c>
     api-version: 1.0
     Content-Type: application/json
     Authorization: (via Named Credential — sets X-Api-Key header)
   Body:
     { "configurationId": "<Configuration_ID__c>" }
   Response:
     { "token": "<session_token>", "interviewId": "<session_id>" }
   ```

4. **`IncodeService.getOnboardingUrl()` — GET to `/omni/onboarding-url`**
   ```
   GET https://demo-api.incodesmile.com/omni/onboarding-url?token=<session_token>
   Headers:
     X-Incode-Hardware-Id: <Configuration_ID__c>
     api-version: 1.0
     Authorization: (via Named Credential)
   Response:
     { "url": "https://onboarding.incodesmile.com/session/<session_id>" }
   ```

5. **`IncodeService` creates an `Incode_Verification__c` record** with status `Pending`, the session token, onboarding URL, and a lookup to the Contact/Lead/Account.

6. **`IncodeEmailService.sendVerificationEmail()` is called.**  
   It looks up the `Incode_Verification_Request` email template in the `Incode_Templates` folder. If the template is found, it is used; otherwise it falls back to inline HTML. The onboarding URL is passed as a merge field value. Salesforce sends the email to the contact's email address.

7. **Contact receives the email and clicks the verification link.**  
   They complete the Incode-hosted flow on their device (photo ID + selfie).

8. **Incode fires a webhook POST** to the registered URL:  
   `https://<site-domain>/IncodeWebhook/services/apexrest/incode/webhook`

9. **`IncodeWebhookHandler.doPost()` processes the payload.**  
   It matches the session ID in the payload to an `Incode_Verification__c` record, maps the `eventType` to a Salesforce status value, and updates the record.

10. **The LWC polls (every 10 seconds) by re-calling `getVerifications()`.**  
    The refreshed data returns the new status, and the LWC updates the status badge in the history table.

---

## 3. Component Reference

### 3.1 `IncodeService` (Apex)

**Location:** `force-app/main/default/classes/IncodeService.cls`

This is the central service class. All outbound Incode API calls go through here.

**Key methods:**

| Method | Access | Description |
|---|---|---|
| `requestVerification(recordId, email, objectType)` | `@AuraEnabled` | Orchestrates the full request: calls `startSession()`, then `getOnboardingUrl()`, then saves the record and sends the email. |
| `getVerifications(recordId)` | `@AuraEnabled(cacheable=true)` | Returns all `Incode_Verification__c` records related to the given record ID (Contact, Lead, or Account), ordered by `Requested_Date__c` descending. Used by the LWC `@wire`. |
| `startSession()` | private | Calls `POST /omni/start`. Reads `Incode_Config__c` to get the Configuration ID and choose the correct Named Credential. Returns the raw response body. |
| `getOnboardingUrl(sessionToken)` | private | Calls `GET /omni/onboarding-url`. Returns the hosted verification URL string. |
| `saveVerificationRecord(sessionId, url, recordId, objectType)` | private | Inserts a new `Incode_Verification__c` with status `Pending` and looks up the correct relationship field based on `objectType` (`Contact`, `Lead`, or `Account`). |

**Design notes:**
- The class runs `with sharing` because it is called from the LWC by a logged-in user, and we want standard Salesforce sharing rules to apply to record queries.
- The Named Credential is selected at runtime by checking `Incode_Config__c.Use_Production_API__c`. If true, `IncodeAPI_Production` is used; otherwise `IncodeAPI`.
- JSON deserialization from Incode API responses currently uses `Map<String, Object>` casting rather than typed wrapper classes. This is a known limitation (see Section 9).

---

### 3.2 `IncodeWebhookHandler` (Apex)

**Location:** `force-app/main/default/classes/IncodeWebhookHandler.cls`

A `@RestResource` global class that accepts inbound POST requests from the Incode platform.

**Annotation:**
```apex
@RestResource(urlMapping='/incode/webhook/*')
global without sharing class IncodeWebhookHandler {
    @HttpPost
    global static void doPost() { ... }
}
```

**Why `without sharing`:** The Site Guest User who receives the webhook has a very restricted profile. Running `without sharing` allows the handler to query and update `Incode_Verification__c` records regardless of the guest user's sharing access. This is intentional and safe because the handler does nothing other than update the status of an existing verification record — it does not expose data to the caller.

**Event type mapping:**

| Incode `eventType` value | Salesforce `Status__c` value |
|---|---|
| `ONBOARDING_FINISHED` | `Approved` |
| `SESSION_SUCCEEDED` | `Approved` |
| `ID_VALIDATION_FINISHED` | `Approved` |
| `SESSION_FAILED` | `Declined` |
| `ONBOARDING_FAILED` | `Declined` |
| Any other value | `Declined` |

**Important quirk:** Incode's documented event name in some versions of their API reference is `SESSION_SUCCEEDED`, but the actual event fired in both demo and production environments is `ONBOARDING_FINISHED`. The handler normalises multiple variants to account for this. Do not remove the `ONBOARDING_FINISHED` case — it is the real event name.

**Score fetch:** After updating the status to `Approved`, the handler enqueues a `@future(callout=true)` method to fetch the verification score from the Incode API. This is necessary because you cannot make a callout from a context where DML has already occurred in the same transaction. The future method calls a score endpoint, then updates `Score__c` on the record in a separate transaction.

**Webhook secret validation:** If `Incode_Config__c.Webhook_Secret__c` is populated, `doPost()` reads the `X-Incode-Signature` header from the incoming request and validates it using HMAC-SHA256. If validation fails, the handler returns HTTP 401 and does not process the payload. If the secret field is blank, signature validation is skipped.

---

### 3.3 `IncodeEmailService` (Apex)

**Location:** `force-app/main/default/classes/IncodeEmailService.cls`

Handles outbound email sending to the end-user contact.

**Key method:**
```apex
public static void sendVerificationEmail(String toAddress, String verificationUrl, String contactName)
```

**Template lookup logic:**
1. Queries for `EmailTemplate` where `DeveloperName = 'Incode_Verification_Request'` and folder name contains `Incode_Templates`.
2. If found, uses `Messaging.SingleEmailMessage.setTemplateId()` and sets `verificationUrl` as a custom merge field value via a wrapper object.
3. If not found (template was deleted or folder was renamed), falls back to inline HTML with a hardcoded button style.

**Note:** The fallback path is a safety net for broken environments. In production, the template should always exist. If you need to modify the email design significantly, edit the template in Salesforce rather than the Apex fallback.

---

### 3.4 `IncodePostInstall` (Apex)

**Location:** `force-app/main/default/classes/IncodePostInstall.cls`

Implements `InstallHandler`. Runs automatically when the package is installed or upgraded. Currently sets a default placeholder value in `Incode_Config__c` so the object exists and the LWC does not throw a null pointer on first load. It does not set a real API Key — the admin must do that manually after installation (see the Setup Guide).

---

### 3.5 `incodeVerification` (LWC)

**Location:** `force-app/main/default/lwc/incodeVerification/`

The main UI component, placed in the record page sidebar.

**Files:**
- `incodeVerification.js` — controller logic
- `incodeVerification.html` — template
- `incodeVerification.css` — styling
- `incodeVerification.js-meta.xml` — metadata (targets: `lightning__RecordPage`)

**Key behaviours:**

- **Wire adapter:** Uses `@wire(getVerifications, { recordId: '$recordId' })` to reactively load verification history whenever `recordId` changes.
- **Email pre-fill:** On mount, calls a separate `@wire` to fetch the record's `Email` field (for Contact/Lead) or `PersonEmail` (for Account Person Records) and pre-fills the email input.
- **Request Verification button:** Calls `requestVerification` imperatively. Disables the button and shows a spinner while the callout is in progress. On success, refreshes the wire adapter using `refreshApex()`.
- **Auto-polling:** Uses `setInterval` with a 10,000ms interval to call `refreshApex()` after a request has been made and the status is still `Pending`. Polling stops when the status transitions to `Approved`, `Declined`, or `Error`, or when the component is disconnected.
- **Status badges:** Status values are mapped to CSS classes:
  - `Approved` → green badge
  - `Declined` / `Error` → red badge
  - `Pending` → orange badge
- **Object type detection:** Uses `this.objectApiName` (passed automatically by the platform) to determine whether the record is a Contact, Lead, or Account, and passes this to `IncodeService` so the correct lookup field is populated.

---

### 3.6 Test Classes

| Class | What it covers |
|---|---|
| `IncodeServiceTest` | `requestVerification()`, `getVerifications()`, error handling when config is missing |
| `IncodeWebhookHandlerTest` | All webhook event type mappings, signature validation, malformed payload handling |
| `IncodeEmailServiceTest` | Template-based send, fallback HTML send, null address handling |
| `IncodeHttpMock` | Implements `HttpCalloutMock`. Returns canned JSON responses for `/omni/start` and `/omni/onboarding-url` calls |

Run all tests together — `IncodeHttpMock` must be in the same test run context for the mock to intercept HTTP calls.

---

## 4. Data Model

### `Incode_Verification__c` (Custom Object)

| Field API Name | Type | Description |
|---|---|---|
| `Session_ID__c` | Text(255) | Incode session/interview ID returned by `/omni/start` |
| `Status__c` | Picklist | `Pending`, `Approved`, `Declined`, `Error` |
| `Requested_Date__c` | DateTime | Timestamp when the Salesforce user clicked "Request Verification" |
| `Completed_Date__c` | DateTime | Timestamp from the webhook payload when the session finished |
| `Score__c` | Number(5,2) | Overall identity verification score returned by Incode (0–100) |
| `Verification_URL__c` | URL | The Incode-hosted onboarding URL sent to the contact |
| `Raw_Event_Type__c` | Text(255) | The raw `eventType` string from the Incode webhook payload, stored for debugging |
| `External_Reference__c` | Text(255) | Optional external reference or customer ID passed through the session |
| `Contact__c` | Lookup(Contact) | Populated when verification is initiated from a Contact record |
| `Lead__c` | Lookup(Lead) | Populated when verification is initiated from a Lead record |
| `Account__c` | Lookup(Account) | Populated when verification is initiated from an Account record |

Only one of `Contact__c`, `Lead__c`, or `Account__c` will be populated per record. The LWC queries based on `recordId` matching any of the three fields.

**OWD:** Private. Sharing is handled by the `Incode_User` permission set granting Read/Write on the object.

---

### `Incode_Config__c` (Custom Setting — Hierarchy)

| Field API Name | Type | Description |
|---|---|---|
| `API_Key__c` | Text(255) | Incode API Key. Stored in Custom Settings rather than a Named Credential password field so it can be read in Apex and included in request headers. |
| `Configuration_ID__c` | Text(255) | Incode Configuration ID, sent as `X-Incode-Hardware-Id` header and in the request body to `/omni/start`. |
| `Webhook_Secret__c` | Text(255) | Optional HMAC signing secret. If populated, webhook signature validation is enforced. |
| `Use_Production_API__c` | Checkbox | When checked, the `IncodeAPI_Production` Named Credential is used. When unchecked, `IncodeAPI` (demo) is used. |

Retrieved in Apex with:
```apex
Incode_Config__c config = Incode_Config__c.getOrgDefaults();
```

---

## 5. Incode API Integration Details

### Authentication

The Incode API authenticates via an `X-Api-Key` header. Named Credentials are configured to inject this header automatically, with the API key value stored in the Named Credential's password field (not in Custom Settings — see note below).

> **Note:** `API_Key__c` in `Incode_Config__c` is used to read the key in Apex code that constructs request headers manually where Named Credential header injection is insufficient. Both the Named Credential and the Custom Setting must hold the same key value.

### Endpoints Used

**1. Start a session**
```
POST /omni/start
Host: demo-api.incodesmile.com (or saas-api.incodesmile.com for production)

Headers:
  X-Incode-Hardware-Id: <Configuration_ID__c>
  api-version: 1.0
  Content-Type: application/json
  X-Api-Key: <API_Key__c>

Body:
{
  "configurationId": "<Configuration_ID__c>"
}

Success response (200):
{
  "token": "eyJhbG...",
  "interviewId": "6421abc123def456abc789"
}
```

The `token` is a short-lived JWT used as the session token for subsequent calls. The `interviewId` is the persistent session identifier stored as `Session_ID__c`.

**2. Get onboarding URL**
```
GET /omni/onboarding-url?token=<token>
Host: demo-api.incodesmile.com

Headers:
  X-Incode-Hardware-Id: <Configuration_ID__c>
  api-version: 1.0
  X-Api-Key: <API_Key__c>

Success response (200):
{
  "url": "https://onboarding.incodesmile.com/session/6421abc123def456abc789?token=eyJhbG..."
}
```

### Known API Quirks

- **`ONBOARDING_FINISHED` vs `SESSION_SUCCEEDED`:** Incode's API documentation (as of early 2025) refers to `SESSION_SUCCEEDED` as the success event type. In practice, both the demo and production environments fire `ONBOARDING_FINISHED`. The webhook handler normalises both. When Incode updates their documentation or changes the event name again, update the mapping table in `IncodeWebhookHandler`.

- **Session token expiry:** The `token` from `/omni/start` is short-lived. It is used only to call `/omni/onboarding-url` immediately after — do not store it. The `interviewId` is the durable identifier.

- **Score availability:** The score is not available in the webhook payload. A separate API call is required after the session completes to fetch the score. This is done asynchronously via a `@future` method to avoid the Apex DML-then-callout restriction.

### Error Handling

`IncodeService` wraps all HTTP callouts in try-catch. If the callout fails or returns a non-2xx status, an `AuraHandledException` is thrown with a user-friendly message. The LWC catches this and displays the message in a toast notification. The `Incode_Verification__c` record is only created after a successful `/omni/onboarding-url` response — a failed session start does not leave orphan records.

---

## 6. Webhook Flow in Detail

### Inbound request shape

Incode sends a POST with `Content-Type: application/json`:

```json
{
  "interviewId": "6421abc123def456abc789",
  "eventType": "ONBOARDING_FINISHED",
  "timestamp": "2026-04-14T10:23:45Z",
  "customerId": "optional-external-reference"
}
```

### Handler logic (`IncodeWebhookHandler.doPost`)

```
1. Read RestRequest body → deserialise JSON to Map<String, Object>
2. If Webhook_Secret__c is set:
   a. Read X-Incode-Signature header
   b. Compute HMAC-SHA256 of raw request body using the secret
   c. If signatures do not match → return HTTP 401, stop
3. Extract interviewId and eventType from payload
4. Query:
   SELECT Id, Status__c FROM Incode_Verification__c
   WHERE Session_ID__c = :interviewId
   LIMIT 1
5. If no record found → return HTTP 404
6. Map eventType to status:
   ONBOARDING_FINISHED | SESSION_SUCCEEDED | ID_VALIDATION_FINISHED → 'Approved'
   SESSION_FAILED | ONBOARDING_FAILED | anything else              → 'Declined'
7. Update record:
   - Status__c = mapped status
   - Raw_Event_Type__c = raw eventType string
   - Completed_Date__c = DateTime.now()
8. If status is Approved → call fetchAndSaveScore(recordId, interviewId) as @future
9. Return HTTP 200
```

### Why `without sharing`

The Salesforce Site where the webhook endpoint lives uses a Guest User profile. Guest Users do not have access to most custom objects unless explicitly granted. Rather than granting overly broad object permissions to the guest profile, the handler runs `without sharing` — this bypasses sharing rules for the duration of the method execution. The handler's blast radius is limited: it can only update the specific `Incode_Verification__c` record matching the session ID from the payload.

### Registering the endpoint

The endpoint URL pattern is:
```
https://<My Domain>-<Site Subdomain>.salesforce-sites.com/IncodeWebhook/services/apexrest/incode/webhook
```

The Salesforce Site named `IncodeWebhook` must be Active. Its guest user profile must allow access to the `IncodeWebhookHandler` Apex class (this is granted via the `Incode_Webhook_Guest` permission set).

---

## 7. Deploying to a New Org

### Prerequisites

- Salesforce CLI (`sf` or `sfdx`) installed
- An authenticated target org (`sf org login web -a <alias>`)
- Node.js (for any pre-deploy scripts if added in future)

### Clone and deploy

```bash
# Clone the repository
git clone https://github.com/incode-id/incode-salesforce.git
cd incode-salesforce

# Authenticate to the target org
sf org login web --alias target-org --instance-url https://login.salesforce.com

# Deploy all metadata
sf project deploy start \
  --source-dir force-app \
  --target-org target-org \
  --wait 10

# Assign permission sets to the running user (for testing)
sf org assign permset \
  --name Incode_User \
  --target-org target-org

# Assign the webhook guest permission set
# (must be done via the Site Guest User — see Setup Guide Step 4)
```

### Post-deploy manual steps

After deployment, the following cannot be automated via metadata deploy and must be done manually in Setup:

1. **Named Credential passwords:** Enter the Incode API Key into the Named Credential password field for both `IncodeAPI` and `IncodeAPI_Production`.
2. **Custom Settings:** Enter the API Key and Configuration ID (see Setup Guide Step 2).
3. **Activate the Salesforce Site:** Sites deploy in an inactive state and must be manually activated (Setup → Sites → Activate).
4. **Register webhook URL in Incode Dashboard** (see Setup Guide Step 5).
5. **Add the LWC to record pages** via Lightning App Builder.
6. **Assign permission sets to users.**

### Deploying only specific components

```bash
# Deploy only the Apex classes
sf project deploy start \
  --source-dir force-app/main/default/classes \
  --target-org target-org

# Deploy only the LWC
sf project deploy start \
  --source-dir force-app/main/default/lwc/incodeVerification \
  --target-org target-org

# Deploy to a scratch org (for development)
sf org create scratch \
  --definition-file config/project-scratch-def.json \
  --alias scratch-org \
  --duration-days 7

sf project deploy start \
  --source-dir force-app \
  --target-org scratch-org
```

---

## 8. Running Tests

### Run all package tests

```bash
sf apex run test \
  --class-names IncodeServiceTest,IncodeWebhookHandlerTest,IncodeEmailServiceTest \
  --target-org target-org \
  --wait 5 \
  --result-format human
```

### Run tests with code coverage

```bash
sf apex run test \
  --class-names IncodeServiceTest,IncodeWebhookHandlerTest,IncodeEmailServiceTest \
  --target-org target-org \
  --code-coverage \
  --result-format json \
  --output-dir test-results/ \
  --wait 10
```

### Expected coverage

| Class | Expected Coverage |
|---|---|
| `IncodeService` | > 85% |
| `IncodeWebhookHandler` | > 90% |
| `IncodeEmailService` | > 80% |
| `IncodePostInstall` | > 75% |

AppExchange submission requires a minimum of 75% code coverage across all Apex classes. The current test suite meets this threshold. `IncodeHttpMock` itself is not subject to the coverage requirement as it is a test utility class.

### Running a specific test method

```bash
sf apex run test \
  --tests IncodeWebhookHandlerTest.testOnboardingFinishedEvent \
  --target-org target-org \
  --wait 5
```

### Checking test history in the org

```bash
sf apex get test \
  --test-run-id <runId> \
  --target-org target-org \
  --result-format human
```

---

## 9. Known Limitations and Future Work

### CRUD/FLS checks

The current implementation does not enforce field-level security (FLS) or object-level CRUD checks before performing DML or SOQL. This is acceptable for an internal/managed package in a controlled org, but **must be addressed before AppExchange submission**. Salesforce Security Review requires that all code respect FLS using `Security.stripInaccessible()` or equivalent patterns.

**Affected classes:** `IncodeService`, `IncodeWebhookHandler`

**Suggested fix:** Wrap all DML in `SObjectAccessDecision` checks using `Security.stripInaccessible(AccessType.CREATABLE, records)` before insert, and `AccessType.UPDATABLE` before update.

### Typed JSON deserialization

Incode API response parsing currently uses raw `Map<String, Object>` and explicit casting:

```apex
Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
String sessionToken = (String) responseMap.get('token');
```

This is fragile — if Incode changes a field name or nests the data differently, the cast will throw a runtime exception. **Future work:** Create typed Apex wrapper classes (`IncodeStartSessionResponse`, `IncodeOnboardingUrlResponse`) and use `JSON.deserialize(body, IncodeStartSessionResponse.class)` for type-safe parsing.

### Namespace registration

The package is not yet registered with a namespace. All custom fields and classes currently live in the default namespace. Before submitting to AppExchange, a namespace must be registered in the Partner Business Org and added to `sfdx-project.json`. **This is a breaking change** for any existing installations — plan for a migration path.

### Score fetch reliability

The `@future` method for fetching the verification score after webhook receipt is a best-effort operation. If the future call fails (e.g., Incode API is temporarily unavailable), the score is silently lost — the `Score__c` field remains null. **Future work:** Implement a retry mechanism using a Platform Event or a scheduled job to back-fill missing scores.

### Polling vs. Push

The LWC currently polls every 10 seconds, which creates up to 6 API calls per minute per open record page. This is functional but not efficient at scale. **Future work:** Replace the polling mechanism with a Salesforce Platform Event subscription. `IncodeWebhookHandler` would publish a Platform Event on each status update, and the LWC would subscribe using `lightning/empApi` for instant, push-based updates.

### Multi-object query limitation

`IncodeService.getVerifications()` queries `Incode_Verification__c` using the `recordId` against all three lookup fields:
```apex
WHERE Contact__c = :recordId OR Lead__c = :recordId OR Account__c = :recordId
```
This works but prevents the use of selective indexes. For orgs with very large numbers of verification records, this query may become slow or hit governor limits. **Future work:** Pass the object type from the LWC and use a single indexed lookup field in the query.

### Email deliverability dependency

The package relies on Salesforce's built-in email delivery. Orgs with restrictive email relay configurations or third-party email providers may find that verification emails are blocked or throttled. This is outside the package's control but should be documented for admins.

---

## 10. Environment Switching (Demo vs Production)

The package supports two Incode API environments, controlled by a single checkbox in Custom Settings.

| Setting | Named Credential Used | API Base URL |
|---|---|---|
| `Use_Production_API__c` = false (default) | `IncodeAPI` | `https://demo-api.incodesmile.com` |
| `Use_Production_API__c` = true | `IncodeAPI_Production` | `https://saas-api.incodesmile.com` |

### How it works in code

```apex
Incode_Config__c config = Incode_Config__c.getOrgDefaults();
String namedCredential = config.Use_Production_API__c ? 'IncodeAPI_Production' : 'IncodeAPI';

HttpRequest req = new HttpRequest();
req.setEndpoint('callout:' + namedCredential + '/omni/start');
req.setMethod('POST');
```

### Switching environments

1. Go to Setup → Custom Settings → Incode Config → Manage.
2. Click **Edit** on the default row.
3. Toggle the **Use Production API** checkbox.
4. Click **Save**.

No code changes or redeployment is required. The Named Credential URL is read at runtime.

**Important:** Make sure the correct API Key is stored in both Named Credential password fields. The Demo API Key and Production API Key are different. When switching to Production, update both:
- The `API_Key__c` field in Custom Settings
- The password field on the `IncodeAPI_Production` Named Credential

### Testing the environment switch

In a scratch org or sandbox, you can temporarily override the Named Credential endpoint in tests using the `IncodeHttpMock` class:

```apex
Test.setMock(HttpCalloutMock.class, new IncodeHttpMock());
Test.startTest();
IncodeService.requestVerification(contactId, 'test@example.com', 'Contact');
Test.stopTest();
```

`IncodeHttpMock` intercepts all callouts regardless of which Named Credential is selected, making it environment-agnostic for unit testing.

---

## Appendix: File Structure

```
incode-salesforce/
├── config/
│   └── project-scratch-def.json
├── force-app/main/default/
│   ├── classes/
│   │   ├── IncodeService.cls
│   │   ├── IncodeService.cls-meta.xml
│   │   ├── IncodeWebhookHandler.cls
│   │   ├── IncodeWebhookHandler.cls-meta.xml
│   │   ├── IncodeEmailService.cls
│   │   ├── IncodeEmailService.cls-meta.xml
│   │   ├── IncodePostInstall.cls
│   │   ├── IncodePostInstall.cls-meta.xml
│   │   ├── IncodeServiceTest.cls
│   │   ├── IncodeServiceTest.cls-meta.xml
│   │   ├── IncodeWebhookHandlerTest.cls
│   │   ├── IncodeWebhookHandlerTest.cls-meta.xml
│   │   ├── IncodeEmailServiceTest.cls
│   │   ├── IncodeEmailServiceTest.cls-meta.xml
│   │   ├── IncodeHttpMock.cls
│   │   └── IncodeHttpMock.cls-meta.xml
│   ├── customMetadata/
│   ├── customPermissions/
│   ├── lwc/
│   │   └── incodeVerification/
│   │       ├── incodeVerification.html
│   │       ├── incodeVerification.js
│   │       ├── incodeVerification.css
│   │       └── incodeVerification.js-meta.xml
│   ├── namedCredentials/
│   │   ├── IncodeAPI.namedCredential-meta.xml
│   │   └── IncodeAPI_Production.namedCredential-meta.xml
│   ├── objects/
│   │   └── Incode_Verification__c/
│   │       └── fields/
│   ├── permissionsets/
│   │   ├── Incode_User.permissionset-meta.xml
│   │   └── Incode_Webhook_Guest.permissionset-meta.xml
│   └── sites/
│       └── IncodeWebhook.site-meta.xml
├── docs/
│   ├── SETUP_GUIDE.md
│   └── ENGINEERING.md
└── sfdx-project.json
```
