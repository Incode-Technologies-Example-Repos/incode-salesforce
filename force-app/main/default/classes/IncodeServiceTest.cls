/**
 * IncodeServiceTest
 *
 * Test coverage for IncodeService. All HTTP callouts are mocked.
 * Target coverage: >= 90%.
 */
@IsTest
private class IncodeServiceTest {

    // -----------------------------------------------------------------------
    // Test setup
    // -----------------------------------------------------------------------

    @TestSetup
    static void makeData() {
        // Create a default Incode_Config__c so the service can read the API key
        Incode_Config__c config = new Incode_Config__c(
            SetupOwnerId      = UserInfo.getOrganizationId(),
            API_Key__c        = 'test-api-key-abc123',
            Webhook_Secret__c = 'test-webhook-secret',
            Configuration_ID__c = 'test-config-id'
        );
        insert config;

        Contact c = new Contact(
            FirstName = 'Jane',
            LastName  = 'Doe',
            Email     = 'jane.doe@example.com'
        );
        insert c;

        Lead l = new Lead(
            FirstName = 'John',
            LastName  = 'Smith',
            Company   = 'Acme Corp',
            Email     = 'john.smith@example.com'
        );
        insert l;

        Account a = new Account(Name = 'Test Account');
        insert a;
    }

    // -----------------------------------------------------------------------
    // startSession — happy paths
    // -----------------------------------------------------------------------

    @IsTest
    static void testStartSession_Contact_Success() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];

        Test.setMock(HttpCalloutMock.class, IncodeHttpMock.omniStartSuccess());

        Test.startTest();
        IncodeService.SessionResult result = IncodeService.startSession(
            c.Id, 'jane.doe@example.com', 'Contact'
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('test-session-123', result.sessionId, 'Session ID should match mock');
        System.assert(String.isNotBlank(result.verificationUrl), 'URL should be populated');
        System.assert(result.verificationUrl.startsWith('https://'), 'URL should be a valid https link');
        System.assertNotEquals(null, result.verificationRecordId, 'Verification record should have been inserted');

        // Verify the Incode_Verification__c record was created with correct values
        Incode_Verification__c verif = [
            SELECT Session_ID__c, Status__c, Contact__c, External_Reference__c
            FROM Incode_Verification__c
            WHERE Id = :result.verificationRecordId
            LIMIT 1
        ];
        System.assertEquals('test-session-123', verif.Session_ID__c);
        System.assertEquals('Pending', verif.Status__c);
        System.assertEquals(c.Id, verif.Contact__c);
        System.assertEquals(c.Id, verif.External_Reference__c);
    }

    @IsTest
    static void testStartSession_Lead_Success() {
        Lead l = [SELECT Id FROM Lead LIMIT 1];

        Test.setMock(HttpCalloutMock.class, IncodeHttpMock.omniStartSuccess());

        Test.startTest();
        IncodeService.SessionResult result = IncodeService.startSession(
            l.Id, 'john.smith@example.com', 'Lead'
        );
        Test.stopTest();

        Incode_Verification__c verif = [
            SELECT Lead__c FROM Incode_Verification__c WHERE Id = :result.verificationRecordId
        ];
        System.assertEquals(l.Id, verif.Lead__c, 'Lead lookup should be populated');
    }

    @IsTest
    static void testStartSession_Account_Success() {
        Account a = [SELECT Id FROM Account LIMIT 1];

        Test.setMock(HttpCalloutMock.class, IncodeHttpMock.omniStartSuccess());

        Test.startTest();
        IncodeService.SessionResult result = IncodeService.startSession(
            a.Id, '', 'Account'
        );
        Test.stopTest();

        Incode_Verification__c verif = [
            SELECT Account__c FROM Incode_Verification__c WHERE Id = :result.verificationRecordId
        ];
        System.assertEquals(a.Id, verif.Account__c, 'Account lookup should be populated');
    }

    // -----------------------------------------------------------------------
    // startSession — error paths
    // -----------------------------------------------------------------------

    @IsTest
    static void testStartSession_ApiError_ThrowsException() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];

        Test.setMock(HttpCalloutMock.class, IncodeHttpMock.omniStartFailure());

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            IncodeService.startSession(c.Id, 'jane.doe@example.com', 'Contact');
        } catch (IncodeService.IncodeException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('400'), 'Exception should reference the HTTP status code');
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'IncodeException should have been thrown on API error');
    }

    @IsTest
    static void testStartSession_NoApiKey_ThrowsException() {
        // Delete the config so the API key is blank
        delete [SELECT Id FROM Incode_Config__c];

        Contact c = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            IncodeService.startSession(c.Id, 'jane.doe@example.com', 'Contact');
        } catch (IncodeService.IncodeException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'IncodeException should be thrown when API key is missing');
    }

    // -----------------------------------------------------------------------
    // getScore
    // -----------------------------------------------------------------------

    @IsTest
    static void testGetScore_Success() {
        Test.setMock(HttpCalloutMock.class, IncodeHttpMock.scoreSuccess());

        Test.startTest();
        Decimal score = IncodeService.getScore('test-session-123', 'test-api-key');
        Test.stopTest();

        System.assertEquals(0.95, score, 'Score should match mock response');
    }

    @IsTest
    static void testGetScore_ServerError_ReturnsNull() {
        Test.setMock(HttpCalloutMock.class, IncodeHttpMock.serverError());

        Test.startTest();
        Decimal score = IncodeService.getScore('test-session-123', 'test-api-key');
        Test.stopTest();

        System.assertEquals(null, score, 'Score should be null on server error');
    }

    // -----------------------------------------------------------------------
    // getOcrData
    // -----------------------------------------------------------------------

    @IsTest
    static void testGetOcrData_Success() {
        Test.setMock(HttpCalloutMock.class, IncodeHttpMock.ocrSuccess());

        Test.startTest();
        String ocrData = IncodeService.getOcrData('test-session-123', 'test-api-key');
        Test.stopTest();

        System.assertNotEquals(null, ocrData, 'OCR data should not be null on success');
        System.assert(ocrData.contains('John Doe'), 'OCR data should contain expected content');
    }

    @IsTest
    static void testGetOcrData_ServerError_ReturnsNull() {
        Test.setMock(HttpCalloutMock.class, IncodeHttpMock.serverError());

        Test.startTest();
        String ocrData = IncodeService.getOcrData('test-session-123', 'test-api-key');
        Test.stopTest();

        System.assertEquals(null, ocrData, 'OCR data should be null on server error');
    }
}
