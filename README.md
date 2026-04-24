# Incode Business Verification — Salesforce Integration

A Salesforce Lightning Web Component (LWC) package that integrates [Incode's eKYB (electronic Know Your Business)](https://developer.incode.com) verification flow directly into your Salesforce org. It supports both US and EU verification flows and is designed to be placed on Contact, Lead, or Account record pages.

---

## What It Does

- Sends a business verification link via email to a contact or lead
- Tracks verification status in real time (polling + webhook)
- Displays a detailed session modal with:
  - Customer-submitted business data (name, tax ID, address, UBOs, directors)
  - eKYB output: registration status, TIN verification, address checks, entity type
  - Key People & UBOs with per-person match indicators (Verified / Approximate / Unverified)
  - Applied business rule and overall pass/fail result

---

## Repository Structure

```
force-app/
  main/default/
    classes/
      IncodeService.cls           # Apex: session management, status polling, detail fetch
      IncodeEmailService.cls      # Apex: sends the verification email
      IncodeWebhookHandler.cls    # Apex: receives and processes Incode webhook events
    lwc/
      incodeVerification/         # Lightning Web Component (UI)
    objects/
      Incode_Config__c/           # Custom metadata: API key, admin credentials, webhook URL
      Incode_Verification__c/     # Custom object: one record per verification session
    emailTemplates/
      Incode_Templates/           # Email template for the verification invitation
    pages/                        # Visualforce pages used by the webhook endpoint
docs/
  SALESFORCE_INTEGRATION_GUIDE.md   # Full setup & configuration guide (Markdown)
  salesforce-integration-guide.html # Branded HTML version of the guide
  SETUP_GUIDE.md                    # Quick-start guide
  ENGINEERING.md                    # Engineering reference
```

---

## Quick Start

1. **Deploy** the package to your Salesforce org:
   ```bash
   sf project deploy start --source-dir force-app --target-org <your-org-alias>
   ```

2. **Configure** the `Incode_Config__c` custom setting with your API key, environment, and webhook secret.

3. **Register** the webhook URL in the [Incode Dashboard](https://dashboard.incode.com) pointing to your org's Visualforce endpoint.

4. **Add** the `incodeVerification` LWC to a Contact, Lead, or Account Lightning record page via App Builder.

For full setup instructions, see [docs/SALESFORCE_INTEGRATION_GUIDE.md](docs/SALESFORCE_INTEGRATION_GUIDE.md) or open [docs/salesforce-integration-guide.html](docs/salesforce-integration-guide.html) in a browser.

---

## Requirements

- Salesforce API version 59.0+
- Incode API key (obtain from [Incode Dashboard](https://dashboard.incode.com))
- Salesforce CLI (`sf`) for deployment

---

## License

Copyright © Incode Technologies. All rights reserved.
