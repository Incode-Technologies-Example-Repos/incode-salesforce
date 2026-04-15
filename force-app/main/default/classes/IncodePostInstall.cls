/**
 * IncodePostInstall
 *
 * Runs automatically after the managed package is installed or upgraded.
 * Implements InstallHandler so Salesforce invokes the onInstall method.
 *
 * Responsibilities:
 *   1. Creates a default Incode_Config__c hierarchy custom setting record
 *      if one does not already exist (so the admin only needs to fill in values).
 *   2. Logs installation details to a custom log object / debug output.
 *   3. Sends a setup-instructions email to the installing admin so they know
 *      exactly what to configure after installation.
 *
 * Note: Salesforce Sites and Guest User permissions cannot be created
 * programmatically via Apex in a managed package post-install context —
 * those must be deployed as metadata. The Site metadata is included in the
 * package; this script handles runtime configuration that requires DML.
 */
global class IncodePostInstall implements InstallHandler {

    global void onInstall(InstallContext ctx) {
        try {
            ensureConfigRecord();
            sendSetupInstructions(ctx);
        } catch (Exception e) {
            // Never let a post-install script throw — it would block installation.
            System.debug(LoggingLevel.ERROR, 'IncodePostInstall error: ' + e.getMessage());
        }
    }

    /**
     * Creates a default org-level Incode_Config__c record if one does not exist.
     * The admin will update the field values; this just ensures the record is present.
     */
    private static void ensureConfigRecord() {
        Incode_Config__c existing = Incode_Config__c.getInstance();
        if (existing == null || existing.Id == null) {
            Incode_Config__c config = new Incode_Config__c(
                SetupOwnerId  = UserInfo.getOrganizationId(),
                Webhook_Secret__c = '',
                API_Key__c        = ''
            );
            insert config;
        }
    }

    /**
     * Sends a plain-text setup instructions email to the installing admin.
     */
    private static void sendSetupInstructions(InstallContext ctx) {
        if (ctx == null || ctx.installerID() == null) {
            return;
        }

        List<User> admins = [
            SELECT Email, FirstName
            FROM User
            WHERE Id = :ctx.installerID()
            LIMIT 1
        ];
        if (admins.isEmpty()) {
            return;
        }

        User admin = admins[0];
        String greeting = String.isNotBlank(admin.FirstName)
            ? 'Hi ' + admin.FirstName + ','
            : 'Hi,';

        String orgId = UserInfo.getOrganizationId();

        String instructions =
              greeting + '\n\n'
            + 'Thank you for installing the Incode Identity Verification package.\n\n'
            + 'To complete setup, please follow these steps:\n\n'
            + '1. ENTER YOUR INCODE API KEY\n'
            + '   Go to Setup > Custom Settings > Incode Config > Manage.\n'
            + '   Click "New" (org default) and enter your Incode API key in the API Key field.\n\n'
            + '2. ENTER YOUR WEBHOOK SECRET\n'
            + '   In the same Incode Config record, enter the shared secret you configured\n'
            + '   in the Incode dashboard into the Webhook Secret field.\n\n'
            + '3. UPDATE THE NAMED CREDENTIAL BASE URL (if needed)\n'
            + '   Go to Setup > Named Credentials > IncodeAPI.\n'
            + '   Update the URL to your Incode environment base URL if different from the default.\n\n'
            + '4. CONFIGURE YOUR INCODE DASHBOARD WEBHOOK\n'
            + '   In the Incode dashboard, set the webhook callback URL to:\n'
            + '   https://[your-org-domain].my.salesforce-sites.com/incode/webhook\n'
            + '   Replace [your-org-domain] with your Salesforce org\'s My Domain.\n\n'
            + '5. ADD THE COMPONENT TO PAGE LAYOUTS\n'
            + '   Go to any Contact, Lead, or Account record page.\n'
            + '   Click the gear icon > Edit Page.\n'
            + '   Drag the "Incode Verification" component onto the page.\n'
            + '   Save and activate.\n\n'
            + '6. ACTIVATE THE SALESFORCE SITE\n'
            + '   Go to Setup > Sites.\n'
            + '   Find the "IncodeWebhook" site and click Activate if it is not already active.\n\n'
            + 'For support, contact your Incode account representative.\n\n'
            + 'Organisation ID: ' + orgId;

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ admin.Email });
        mail.setSubject('Incode Identity Verification — Installation Complete');
        mail.setPlainTextBody(instructions);
        mail.setSaveAsActivity(false);

        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail }, false);
    }
}
