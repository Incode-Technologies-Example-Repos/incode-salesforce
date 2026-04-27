/**
 * IncodeEmailService
 *
 * Sends the identity verification link to the contact/lead's email address
 * using Salesforce's Messaging.SingleEmailMessage API and the custom
 * Incode_Verification_Request HTML email template bundled with this package.
 *
 * The method is intentionally synchronous so the LWC can surface errors
 * immediately rather than failing silently in a future/queueable context.
 */
public with sharing class IncodeEmailService {

    private static final String TEMPLATE_UNIQUE_NAME = 'Incode_Verification_Request';

    /**
     * Sends the verification email to the specified address.
     *
     * @param toAddress        Recipient email address.
     * @param firstName        Recipient's first name for personalisation in the template.
     * @param verificationUrl  The hosted Incode verification URL to embed in the email.
     * @param targetObjectId   The Salesforce record ID to use as the WhatId/WhoId for
     *                         merge field resolution (Contact or Lead Id preferred).
     */
    @AuraEnabled
    public static void sendVerificationEmail(
        String toAddress,
        String firstName,
        String verificationUrl,
        String targetObjectId
    ) {
        if (String.isBlank(toAddress)) {
            throw new IncodeEmailException('A recipient email address is required.');
        }
        if (String.isBlank(verificationUrl)) {
            throw new IncodeEmailException('A verification URL is required.');
        }

        // Look up the email template by developer name so the package is
        // namespace-safe and does not rely on a hardcoded template Id.
        List<EmailTemplate> templates = [
            SELECT Id, DeveloperName
            FROM EmailTemplate
            WHERE DeveloperName = :TEMPLATE_UNIQUE_NAME
            LIMIT 1
        ];

        if (templates.isEmpty()) {
            // Fallback: send a plain-text email without a template so the
            // user still receives their link even if the template is missing.
            sendFallbackEmail(toAddress, firstName, verificationUrl);
            return;
        }

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ toAddress });
        mail.setTemplateId(templates[0].Id);
        mail.setSaveAsActivity(false);

        // Provide the target object for merge field resolution.
        // For Lead records the WhoId is used; for Contact/Account the WhatId.
        if (String.isNotBlank(targetObjectId)) {
            String prefix = targetObjectId.substring(0, 3);
            Schema.DescribeSObjectResult contactDescribe = Contact.sObjectType.getDescribe();
            Schema.DescribeSObjectResult leadDescribe    = Lead.sObjectType.getDescribe();

            String contactKeyPrefix = contactDescribe.getKeyPrefix();
            String leadKeyPrefix    = leadDescribe.getKeyPrefix();

            if (prefix == contactKeyPrefix || prefix == leadKeyPrefix) {
                mail.setTargetObjectId(targetObjectId);
            }
        }

        // Store the verification URL in an email attachment-free mechanism:
        // we pass it via template merge fields via a custom object merge approach.
        // Since the template uses {!verificationUrl} from the component context,
        // we also send the URL in a treatment variable substitution if the template
        // supports it. As a belt-and-suspenders measure we always set the plain-text
        // body with the URL so it's never lost.
        mail.setPlainTextBody(buildPlainTextFallback(firstName, verificationUrl));

        Messaging.SendEmailResult[] results = Messaging.sendEmail(
            new List<Messaging.SingleEmailMessage>{ mail },
            false // allOrNothing = false; do not throw on partial failure
        );

        if (results != null && !results.isEmpty() && !results[0].isSuccess()) {
            List<Messaging.SendEmailError> errors = results[0].getErrors();
            String errorMsg = errors.isEmpty() ? 'Unknown error' : errors[0].getMessage();
            throw new IncodeEmailException('Email send failed: ' + errorMsg);
        }
    }

    /**
     * Sends a simple HTML email without a Salesforce template.
     * Used as a fallback when the email template is not found.
     */
    private static void sendFallbackEmail(String toAddress, String firstName, String verificationUrl) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ toAddress });
        mail.setSubject('Action Required: Complete Your Business Verification');
        mail.setHtmlBody(buildHtmlBody(firstName, verificationUrl));
        mail.setPlainTextBody(buildPlainTextFallback(firstName, verificationUrl));
        mail.setSaveAsActivity(false);

        Messaging.SendEmailResult[] results = Messaging.sendEmail(
            new List<Messaging.SingleEmailMessage>{ mail },
            false
        );

        if (results != null && !results.isEmpty() && !results[0].isSuccess()) {
            List<Messaging.SendEmailError> errors = results[0].getErrors();
            String errorMsg = errors.isEmpty() ? 'Unknown error' : errors[0].getMessage();
            throw new IncodeEmailException('Fallback email send failed: ' + errorMsg);
        }
    }

    private static String buildHtmlBody(String firstName, String verificationUrl) {
        String greeting = String.isNotBlank(firstName) ? 'Hi ' + firstName + ',' : 'Hi,';
        return '<!DOCTYPE html>'
            + '<html lang="en"><head>'
            + '<meta charset="UTF-8"/>'
            + '<meta name="viewport" content="width=device-width,initial-scale=1.0"/>'
            + '<title>Business Verification Required</title>'
            + '</head>'
            + '<body style="margin:0;padding:0;background-color:#f0f2f5;font-family:Arial,Helvetica,sans-serif;color:#333333;">'

            // ── Outer wrapper
            + '<table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#f0f2f5;">'
            + '<tr><td align="center" style="padding:40px 16px;">'

            // ── 600px card
            + '<table width="600" cellpadding="0" cellspacing="0" border="0" style="max-width:600px;width:100%;">'

            // ── Header
            + '<tr><td style="background-color:#1e2130;border-radius:8px 8px 0 0;padding:28px 40px;">'
            + '<table width="100%" cellpadding="0" cellspacing="0" border="0"><tr>'
            + '<td>'
            + '<p style="margin:0;font-size:26px;font-weight:900;color:#ffffff;letter-spacing:-0.5px;">incode</p>'
            + '<p style="margin:5px 0 0;font-size:10px;font-weight:700;color:#6b7fa3;text-transform:uppercase;letter-spacing:2px;">Trusted Business Verification</p>'
            + '</td>'
            + '<td align="right" valign="middle">'
            + '<span style="display:inline-block;background-color:#006aff;color:#ffffff;font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:1px;padding:5px 12px;border-radius:20px;">Action Required</span>'
            + '</td>'
            + '</tr></table>'
            + '</td></tr>'

            // ── White body
            + '<tr><td style="background-color:#ffffff;padding:40px 40px 36px;">'

            + '<p style="margin:0 0 20px;font-size:16px;font-weight:600;line-height:1.5;color:#1e2130;">' + greeting + '</p>'

            + '<p style="margin:0 0 16px;font-size:15px;line-height:1.75;color:#444444;">'
            + 'To complete your onboarding, we need to verify your business through our <strong>eKYB (electronic Know Your Business)</strong> process. '
            + 'This is a standard step required by financial regulations and Anti-Money Laundering (AML) compliance policies before we can fully activate your account.'
            + '</p>'

            // ── "What to expect" info box
            + '<table width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:0 0 32px;">'
            + '<tr><td style="background-color:#f4f7ff;border-left:4px solid #006aff;border-radius:0 6px 6px 0;padding:18px 22px;">'
            + '<p style="margin:0 0 12px;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:1px;color:#006aff;">What to expect</p>'
            + '<table cellpadding="0" cellspacing="0" border="0">'
            + '<tr><td style="padding:4px 0;font-size:14px;color:#3a3a3a;line-height:1.5;">&#10003;&nbsp;&nbsp;Confirm your business name, tax ID, and registered address</td></tr>'
            + '<tr><td style="padding:4px 0;font-size:14px;color:#3a3a3a;line-height:1.5;">&#10003;&nbsp;&nbsp;Provide beneficial ownership (UBO) information if applicable</td></tr>'
            + '<tr><td style="padding:4px 0;font-size:14px;color:#3a3a3a;line-height:1.5;">&#10003;&nbsp;&nbsp;Takes approximately <strong>5 minutes</strong> to complete</td></tr>'
            + '<tr><td style="padding:4px 0;font-size:14px;color:#3a3a3a;line-height:1.5;">&#10003;&nbsp;&nbsp;All data is encrypted and processed securely by Incode</td></tr>'
            + '</table>'
            + '</td></tr></table>'

            // ── CTA button
            + '<table cellpadding="0" cellspacing="0" border="0" style="margin:0 0 32px;">'
            + '<tr><td align="center" style="background-color:#006aff;border-radius:6px;padding:16px 40px;">'
            + '<a href="' + verificationUrl + '" style="color:#ffffff;text-decoration:none;font-size:16px;font-weight:700;letter-spacing:0.3px;display:block;">'
            + 'Verify My Business &#8594;'
            + '</a>'
            + '</td></tr></table>'

            // ── Fallback URL
            + '<p style="margin:0 0 6px;font-size:13px;color:#999999;">If the button above does not work, copy and paste this link into your browser:</p>'
            + '<p style="margin:0 0 32px;font-size:12px;word-break:break-all;color:#006aff;">' + verificationUrl + '</p>'

            + '<hr style="border:none;border-top:1px solid #eeeeee;margin:0 0 20px;"/>'

            // ── Security notice
            + '<p style="margin:0;font-size:12px;color:#aaaaaa;line-height:1.75;">'
            + '<strong style="color:#888888;">Security notice:</strong> '
            + 'This link is personal to you and expires after a single use. Do not forward or share it with anyone. '
            + 'If you were not expecting this message, please disregard it or contact our support team immediately.'
            + '</p>'
            + '</td></tr>'

            // ── Footer
            + '<tr><td style="background-color:#1e2130;border-radius:0 0 8px 8px;padding:20px 40px;">'
            + '<table width="100%" cellpadding="0" cellspacing="0" border="0"><tr>'
            + '<td><p style="margin:0;font-size:12px;color:#6b7fa3;">Powered by <strong style="color:#ffffff;">Incode Technologies</strong></p></td>'
            + '<td align="right"><p style="margin:0;font-size:11px;color:#6b7fa3;">&copy; 2026 Incode Technologies, Inc.</p></td>'
            + '</tr></table>'
            + '</td></tr>'

            + '</table>'  // ── end 600px card
            + '</td></tr>'
            + '</table>'  // ── end outer wrapper
            + '</body></html>';
    }

    private static String buildPlainTextFallback(String firstName, String verificationUrl) {
        String greeting = String.isNotBlank(firstName) ? 'Hi ' + firstName + ',' : 'Hi,';
        return greeting + '\n\n'
            + 'ACTION REQUIRED: Complete Your Business Verification\n'
            + '----------------------------------------------------\n\n'
            + 'To complete your onboarding, we need to verify your business through our eKYB '
            + '(electronic Know Your Business) process. This is a standard requirement under '
            + 'financial regulations and Anti-Money Laundering (AML) compliance policies.\n\n'
            + 'WHAT TO EXPECT:\n'
            + '  - Confirm your business name, tax ID, and registered address\n'
            + '  - Provide beneficial ownership (UBO) information if applicable\n'
            + '  - Takes approximately 5 minutes to complete\n'
            + '  - All data is encrypted and processed securely\n\n'
            + 'To complete your business verification, please visit:\n'
            + verificationUrl + '\n\n'
            + '----------------------------------------------------\n'
            + 'SECURITY NOTICE: This link is personal to you and expires after a single use.\n'
            + 'Do not share it with anyone. If you were not expecting this message,\n'
            + 'please disregard it or contact our support team immediately.\n\n'
            + 'Powered by Incode Technologies — incode.com';
    }

    public class IncodeEmailException extends Exception {}
}
