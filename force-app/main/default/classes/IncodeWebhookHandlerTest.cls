/**
 * IncodeWebhookHandlerTest
 *
 * Test coverage for IncodeWebhookHandler using Incode's actual payload structure:
 *   event_type: SESSION_SUCCEEDED | SESSION_FAILED | SESSION_PENDING_REVIEW | SESSION_STARTED
 *   interviewId, externalCustomerId
 *
 * Target coverage: >= 90%.
 */
@IsTest
private class IncodeWebhookHandlerTest {

    private static final String VALID_SECRET   = 'webhook-secret-xyz';
    private static final String SESSION_ID     = 'session-abc-001';
    private static final String EXTERNAL_ID    = '003000000000001AAA';

    @TestSetup
    static void makeData() {
        Incode_Config__c config = new Incode_Config__c(
            SetupOwnerId      = UserInfo.getOrganizationId(),
            API_Key__c        = 'test-api-key',
            Webhook_Secret__c = VALID_SECRET
        );
        insert config;

        Incode_Verification__c verif = new Incode_Verification__c(
            Session_ID__c         = SESSION_ID,
            Status__c             = 'Pending',
            Requested_Date__c     = System.now(),
            External_Reference__c = EXTERNAL_ID
        );
        insert verif;
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    private static RestRequest buildRequest(String secret, String body) {
        RestRequest req  = new RestRequest();
        req.requestURI   = '/services/apexrest/incode/webhook';
        req.httpMethod   = 'POST';
        req.requestBody  = Blob.valueOf(body);
        if (secret != null) {
            req.headers.put('X-Incode-Secret', secret);
        }
        return req;
    }

    private static void setContext(RestRequest req) {
        RestContext.request  = req;
        RestContext.response = new RestResponse();
    }

    private static String payload(String eventType) {
        return '{"interviewId":"' + SESSION_ID + '","event_type":"' + eventType
            + '","externalCustomerId":"' + EXTERNAL_ID + '"}';
    }

    // -----------------------------------------------------------------------
    // 401 — invalid secret
    // -----------------------------------------------------------------------

    @IsTest
    static void testWebhook_InvalidSecret_Returns401() {
        setContext(buildRequest('wrong-secret', payload('SESSION_SUCCEEDED')));

        Test.startTest();
        IncodeWebhookHandler.handleWebhook();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode);
    }

    @IsTest
    static void testWebhook_MissingSecret_Returns401() {
        setContext(buildRequest(null, payload('SESSION_SUCCEEDED')));

        Test.startTest();
        IncodeWebhookHandler.handleWebhook();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode);
    }

    // -----------------------------------------------------------------------
    // 400 — bad request bodies
    // -----------------------------------------------------------------------

    @IsTest
    static void testWebhook_EmptyBody_Returns400() {
        RestRequest req = buildRequest(VALID_SECRET, '');
        req.requestBody = null;
        setContext(req);

        Test.startTest();
        IncodeWebhookHandler.handleWebhook();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    @IsTest
    static void testWebhook_InvalidJson_Returns400() {
        setContext(buildRequest(VALID_SECRET, 'not-json'));

        Test.startTest();
        IncodeWebhookHandler.handleWebhook();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    @IsTest
    static void testWebhook_MissingInterviewId_Returns400() {
        setContext(buildRequest(VALID_SECRET, '{"event_type":"SESSION_SUCCEEDED"}'));

        Test.startTest();
        IncodeWebhookHandler.handleWebhook();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    // -----------------------------------------------------------------------
    // SESSION_STARTED — acknowledged without record update
    // -----------------------------------------------------------------------

    @IsTest
    static void testWebhook_SessionStarted_AcknowledgedOnly() {
        setContext(buildRequest(VALID_SECRET, payload('SESSION_STARTED')));

        Test.startTest();
        IncodeWebhookHandler.handleWebhook();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        System.assert(
            RestContext.response.responseBody.toString().contains('session_started_acknowledged'),
            'Should acknowledge SESSION_STARTED without updating record'
        );

        // Status should remain Pending
        Incode_Verification__c verif = [SELECT Status__c FROM Incode_Verification__c WHERE Session_ID__c = :SESSION_ID LIMIT 1];
        System.assertEquals('Pending', verif.Status__c);
    }

    // -----------------------------------------------------------------------
    // 200 — unknown session ID
    // -----------------------------------------------------------------------

    @IsTest
    static void testWebhook_UnknownSession_Returns200() {
        setContext(buildRequest(VALID_SECRET,
            '{"interviewId":"unknown-session","event_type":"SESSION_SUCCEEDED","externalCustomerId":"' + EXTERNAL_ID + '"}'
        ));

        Test.startTest();
        IncodeWebhookHandler.handleWebhook();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('no_matching_record'));
    }

    // -----------------------------------------------------------------------
    // SESSION_SUCCEEDED -> Approved
    // -----------------------------------------------------------------------

    @IsTest
    static void testWebhook_SessionSucceeded_SetsApproved() {
        Test.setMock(HttpCalloutMock.class, IncodeHttpMock.scoreSuccess());
        setContext(buildRequest(VALID_SECRET, payload('SESSION_SUCCEEDED')));

        Test.startTest();
        IncodeWebhookHandler.handleWebhook();
        Test.stopTest();

        Incode_Verification__c verif = [
            SELECT Status__c, Completed_Date__c FROM Incode_Verification__c WHERE Session_ID__c = :SESSION_ID LIMIT 1
        ];
        System.assertEquals('Approved', verif.Status__c);
        System.assertNotEquals(null, verif.Completed_Date__c);
        System.assertEquals(200, RestContext.response.statusCode);
    }

    // -----------------------------------------------------------------------
    // SESSION_FAILED -> Declined
    // -----------------------------------------------------------------------

    @IsTest
    static void testWebhook_SessionFailed_SetsDeclined() {
        Test.setMock(HttpCalloutMock.class, IncodeHttpMock.scoreSuccess());
        setContext(buildRequest(VALID_SECRET, payload('SESSION_FAILED')));

        Test.startTest();
        IncodeWebhookHandler.handleWebhook();
        Test.stopTest();

        Incode_Verification__c verif = [
            SELECT Status__c FROM Incode_Verification__c WHERE Session_ID__c = :SESSION_ID LIMIT 1
        ];
        System.assertEquals('Declined', verif.Status__c);
    }

    // -----------------------------------------------------------------------
    // SESSION_PENDING_REVIEW -> Pending
    // -----------------------------------------------------------------------

    @IsTest
    static void testWebhook_SessionPendingReview_SetsPending() {
        setContext(buildRequest(VALID_SECRET, payload('SESSION_PENDING_REVIEW')));

        Test.startTest();
        IncodeWebhookHandler.handleWebhook();
        Test.stopTest();

        Incode_Verification__c verif = [
            SELECT Status__c FROM Incode_Verification__c WHERE Session_ID__c = :SESSION_ID LIMIT 1
        ];
        System.assertEquals('Pending', verif.Status__c);
    }

    // -----------------------------------------------------------------------
    // Unknown event_type -> Error
    // -----------------------------------------------------------------------

    @IsTest
    static void testWebhook_UnknownEventType_SetsError() {
        setContext(buildRequest(VALID_SECRET, payload('SESSION_EXPIRED')));

        Test.startTest();
        IncodeWebhookHandler.handleWebhook();
        Test.stopTest();

        Incode_Verification__c verif = [
            SELECT Status__c FROM Incode_Verification__c WHERE Session_ID__c = :SESSION_ID LIMIT 1
        ];
        System.assertEquals('Error', verif.Status__c);
    }

    // -----------------------------------------------------------------------
    // mapEventType unit tests (via @TestVisible)
    // -----------------------------------------------------------------------

    @IsTest
    static void testMapEventType_AllValues() {
        // Underscore format (docs / older payloads)
        System.assertEquals('Approved', IncodeWebhookHandler.mapEventType('SESSION_SUCCEEDED'));
        System.assertEquals('Approved', IncodeWebhookHandler.mapEventType('session_succeeded'));
        System.assertEquals('Declined', IncodeWebhookHandler.mapEventType('SESSION_FAILED'));
        System.assertEquals('Pending',  IncodeWebhookHandler.mapEventType('SESSION_PENDING_REVIEW'));
        // Title Case with spaces (Incode production format)
        System.assertEquals('Approved', IncodeWebhookHandler.mapEventType('Session Succeeded'));
        System.assertEquals('Declined', IncodeWebhookHandler.mapEventType('Session Failed'));
        System.assertEquals('Pending',  IncodeWebhookHandler.mapEventType('Session Pending Review'));
        System.assertEquals('Pending',  IncodeWebhookHandler.mapEventType('Session Started'));
        // Edge cases
        System.assertEquals('Error',    IncodeWebhookHandler.mapEventType('UNKNOWN'));
        System.assertEquals('Error',    IncodeWebhookHandler.mapEventType(null));
        System.assertEquals('Error',    IncodeWebhookHandler.mapEventType(''));
    }

    // -----------------------------------------------------------------------
    // No secret configured — skip secret validation
    // -----------------------------------------------------------------------

    @IsTest
    static void testWebhook_NoSecretConfigured_AcceptsRequest() {
        // Clear the secret so validation is skipped
        Incode_Config__c config = [
            SELECT Id, Webhook_Secret__c
            FROM Incode_Config__c
            WHERE SetupOwnerId = :UserInfo.getOrganizationId()
            LIMIT 1
        ];
        config.Webhook_Secret__c = '';
        update config;

        // Send with no secret header — should still be processed
        // SESSION_SUCCEEDED triggers @future score fetch, so mock is required
        Test.setMock(HttpCalloutMock.class, IncodeHttpMock.scoreSuccess());
        setContext(buildRequest(null, payload('SESSION_SUCCEEDED')));

        Test.startTest();
        IncodeWebhookHandler.handleWebhook();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
    }
}
