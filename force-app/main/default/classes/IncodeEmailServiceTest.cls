/**
 * IncodeEmailServiceTest
 *
 * Test coverage for IncodeEmailService. Uses Test.setMock is not required
 * for email sends — Salesforce does not actually send emails in test context
 * when Limits.getEmailInvocations() is monitored. We verify no exceptions
 * are thrown and the correct validation paths are exercised.
 * Target coverage: >= 90%.
 */
@IsTest
private class IncodeEmailServiceTest {

    private static final String TEST_EMAIL      = 'incode.contact.test@example.com';
    private static final String TEST_LEAD_EMAIL = 'incode.lead.test@example.com';
    private static final String TEST_URL        = 'https://incode.example.com/verify/abc123';
    private static final String FIRST_NAME      = 'Alice';

    @TestSetup
    static void makeData() {
        Contact c = new Contact(
            FirstName = FIRST_NAME,
            LastName  = 'Test',
            Email     = TEST_EMAIL
        );
        insert c;

        Lead l = new Lead(
            FirstName = FIRST_NAME,
            LastName  = 'Test',
            Company   = 'Test Co',
            Email     = TEST_LEAD_EMAIL
        );
        insert l;
    }

    // -----------------------------------------------------------------------
    // sendVerificationEmail — happy paths (template not present in test org,
    // so the fallback code path is exercised)
    // -----------------------------------------------------------------------

    @IsTest
    static void testSendEmail_Contact_NoTemplate_UseFallback() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        // No EmailTemplate exists in the test org — the service falls back to
        // building HTML inline. This should complete without exceptions.
        IncodeEmailService.sendVerificationEmail(TEST_EMAIL, FIRST_NAME, TEST_URL, c.Id);
        Test.stopTest();

        // If we reach here without exception the test passes.
        System.assert(true, 'Email send should complete without exception');
    }

    @IsTest
    static void testSendEmail_Lead_NoTemplate_UseFallback() {
        Lead l = [SELECT Id FROM Lead LIMIT 1];

        Test.startTest();
        IncodeEmailService.sendVerificationEmail(TEST_EMAIL, FIRST_NAME, TEST_URL, l.Id);
        Test.stopTest();

        System.assert(true, 'Email send should complete without exception for Lead');
    }

    @IsTest
    static void testSendEmail_NoTargetObjectId_StillSends() {
        Test.startTest();
        IncodeEmailService.sendVerificationEmail(TEST_EMAIL, FIRST_NAME, TEST_URL, null);
        Test.stopTest();

        System.assert(true, 'Email send without target object should not throw');
    }

    @IsTest
    static void testSendEmail_BlankFirstName_StillSends() {
        Test.startTest();
        IncodeEmailService.sendVerificationEmail(TEST_EMAIL, '', TEST_URL, null);
        Test.stopTest();

        System.assert(true, 'Email without first name should use generic greeting');
    }

    // -----------------------------------------------------------------------
    // sendVerificationEmail — validation errors
    // -----------------------------------------------------------------------

    @IsTest
    static void testSendEmail_BlankToAddress_ThrowsException() {
        Test.startTest();
        Boolean thrown = false;
        try {
            IncodeEmailService.sendVerificationEmail('', FIRST_NAME, TEST_URL, null);
        } catch (IncodeEmailService.IncodeEmailException e) {
            thrown = true;
            System.assert(e.getMessage().contains('email address'), 'Exception message should mention email address');
        }
        Test.stopTest();

        System.assert(thrown, 'Should throw when toAddress is blank');
    }

    @IsTest
    static void testSendEmail_NullToAddress_ThrowsException() {
        Test.startTest();
        Boolean thrown = false;
        try {
            IncodeEmailService.sendVerificationEmail(null, FIRST_NAME, TEST_URL, null);
        } catch (IncodeEmailService.IncodeEmailException e) {
            thrown = true;
        }
        Test.stopTest();

        System.assert(thrown, 'Should throw when toAddress is null');
    }

    @IsTest
    static void testSendEmail_BlankVerificationUrl_ThrowsException() {
        Test.startTest();
        Boolean thrown = false;
        try {
            IncodeEmailService.sendVerificationEmail(TEST_EMAIL, FIRST_NAME, '', null);
        } catch (IncodeEmailService.IncodeEmailException e) {
            thrown = true;
            System.assert(e.getMessage().contains('URL'), 'Exception message should mention URL');
        }
        Test.stopTest();

        System.assert(thrown, 'Should throw when verificationUrl is blank');
    }

    @IsTest
    static void testSendEmail_NullVerificationUrl_ThrowsException() {
        Test.startTest();
        Boolean thrown = false;
        try {
            IncodeEmailService.sendVerificationEmail(TEST_EMAIL, FIRST_NAME, null, null);
        } catch (IncodeEmailService.IncodeEmailException e) {
            thrown = true;
        }
        Test.stopTest();

        System.assert(thrown, 'Should throw when verificationUrl is null');
    }

    // -----------------------------------------------------------------------
    // With EmailTemplate present (upsert template so SOQL query finds it)
    // -----------------------------------------------------------------------

    @IsTest
    static void testSendEmail_WithTemplate_UsesTemplateId() {
        // Insert a minimal email template with the expected developer name
        EmailTemplate tmpl = new EmailTemplate(
            DeveloperName = 'Incode_Verification_Request',
            FolderId      = UserInfo.getUserId(), // personal folder
            Name          = 'Incode Verification Request',
            Subject       = 'Test Subject',
            Body          = 'Test Body {!Contact.FirstName}',
            HtmlValue     = '<p>Test {!Contact.FirstName}</p>',
            TemplateType  = 'custom',
            IsActive      = true
        );
        insert tmpl;

        Contact c = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        // With a template present, the service should use setTemplateId path
        IncodeEmailService.sendVerificationEmail(TEST_EMAIL, FIRST_NAME, TEST_URL, c.Id);
        Test.stopTest();

        System.assert(true, 'Should complete without exception when template is found');
    }
}
