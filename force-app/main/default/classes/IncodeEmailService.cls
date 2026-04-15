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
        mail.setSubject('Action required: Please complete your identity verification');
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
        return '<!DOCTYPE html><html><body style="font-family:Arial,sans-serif;color:#333;max-width:600px;margin:0 auto;padding:20px">'
            + '<p>' + greeting + '</p>'
            + '<p>We need to verify your identity as part of our onboarding process. '
            + 'Please click the button below to complete your verification — it only takes a few minutes.</p>'
            + '<p style="text-align:center;margin:32px 0">'
            + '<a href="' + verificationUrl + '" '
            + 'style="background-color:#0070d2;color:#fff;padding:14px 28px;text-decoration:none;'
            + 'border-radius:4px;font-size:16px;font-weight:bold">Verify My Identity</a>'
            + '</p>'
            + '<p style="font-size:13px;color:#666">If the button above does not work, copy and paste this link into your browser:</p>'
            + '<p style="font-size:13px;word-break:break-all;color:#0070d2">' + verificationUrl + '</p>'
            + '<hr style="border:none;border-top:1px solid #eee;margin:32px 0"/>'
            + '<p style="font-size:12px;color:#999">This link is unique to you. Please do not share it with others.</p>'
            + '</body></html>';
    }

    private static String buildPlainTextFallback(String firstName, String verificationUrl) {
        String greeting = String.isNotBlank(firstName) ? 'Hi ' + firstName + ',' : 'Hi,';
        return greeting + '\n\n'
            + 'We need to verify your identity as part of our onboarding process.\n\n'
            + 'Please visit the following link to complete your verification:\n'
            + verificationUrl + '\n\n'
            + 'This link is unique to you. Please do not share it with others.';
    }

    public class IncodeEmailException extends Exception {}
}
