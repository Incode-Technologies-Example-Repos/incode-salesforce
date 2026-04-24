/**
 * IncodeWebhookHandler
 *
 * Exposes a public REST endpoint via a Salesforce Site that receives inbound
 * POST requests from Incode when a verification session completes.
 *
 * Endpoint: POST /incode/webhook
 *
 * Security:
 *   - If Webhook_Secret__c is configured in Incode_Config__c, enforces it
 *     against the X-Incode-Secret header. If left blank, validation is skipped
 *     (Incode does not send a secret header by default).
 *   - Runs without sharing so that the guest Site user can read/write the
 *     Incode_Verification__c record regardless of sharing rules.
 *
 * Incode payload fields (per https://developer.incode.com/docs/session-webhooks):
 *   - event_type       : SESSION_SUCCEEDED | SESSION_FAILED | SESSION_PENDING_REVIEW | SESSION_STARTED
 *   - interviewId      : unique session identifier
 *   - externalCustomerId : the Salesforce record ID passed at session creation
 *   - onboardingStatus : always "ONBOARDING_FINISHED" for completed sessions
 *   - identityId       : only present on SESSION_SUCCEEDED
 *
 * Flow:
 *   1. Optional secret validation.
 *   2. Parse event_type and interviewId from request body.
 *   3. Find matching Incode_Verification__c record by Session_ID__c.
 *   4. Update status synchronously.
 *   5. Enqueue @future job to fetch score from /omni/get/score.
 *   6. Return HTTP 200 immediately so Incode does not retry.
 */
@RestResource(urlMapping='/incode/webhook/*')
global without sharing class IncodeWebhookHandler {

    @HttpPost
    global static void handleWebhook() {
        RestRequest  req = RestContext.request;
        RestResponse res = RestContext.response;

        // --- 1. Optional shared secret validation ---
        Incode_Config__c config = Incode_Config__c.getInstance();

        if (config != null && String.isNotBlank(config.Webhook_Secret__c)) {
            String incomingSecret = req.headers.get('X-Incode-Secret');
            if (config.Webhook_Secret__c != incomingSecret) {
                res.statusCode = 401;
                res.responseBody = Blob.valueOf('{"error":"Unauthorized"}');
                return;
            }
        }

        // --- 2. Parse request body ---
        String body = req.requestBody != null ? req.requestBody.toString() : '';
        if (String.isBlank(body)) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('{"error":"Empty request body"}');
            return;
        }

        Map<String, Object> payload;
        try {
            payload = (Map<String, Object>) JSON.deserializeUntyped(body);
        } catch (Exception e) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('{"error":"Invalid JSON"}');
            return;
        }

        String interviewId        = (String) payload.get('interviewId');
        String externalCustomerId = (String) payload.get('externalCustomerId');

        // Incode uses different field names depending on environment/version.
        // Try every known variant so we always capture the event type.
        String eventType = (String) payload.get('event_type');       // snake_case (docs)
        if (String.isBlank(eventType)) eventType = (String) payload.get('eventType');         // camelCase
        if (String.isBlank(eventType)) eventType = (String) payload.get('onboardingStatus'); // alternate field
        if (String.isBlank(eventType)) eventType = (String) payload.get('status');            // generic fallback

        if (String.isBlank(interviewId)) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('{"error":"Missing interviewId"}');
            return;
        }

        // Acknowledge SESSION_STARTED immediately — no record update needed.
        // Normalise so both "Session Started" and "SESSION_STARTED" match.
        String normalisedEvent = String.isBlank(eventType)
            ? '' : eventType.toUpperCase().replace(' ', '_');

        if (normalisedEvent == 'SESSION_STARTED') {
            res.statusCode = 200;
            res.responseBody = Blob.valueOf('{"result":"session_started_acknowledged"}');
            return;
        }

        // --- 3. Find matching verification record ---
        List<Incode_Verification__c> verifs = [
            SELECT Id, Status__c
            FROM Incode_Verification__c
            WHERE Session_ID__c = :interviewId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (verifs.isEmpty()) {
            // Return 200 so Incode does not keep retrying an unknown session.
            res.statusCode = 200;
            res.responseBody = Blob.valueOf('{"result":"no_matching_record"}');
            return;
        }

        Incode_Verification__c verif = verifs[0];

        // Map Incode event_type to our Status__c picklist values
        String mappedStatus = mapEventType(eventType);

        // Store what we received for debugging. If eventType is still blank,
        // store the raw body (truncated) so we can inspect the actual payload.
        String debugValue = String.isNotBlank(eventType)
            ? eventType
            : (body.length() > 255 ? body.substring(0, 255) : body);

        // --- 4. Update status synchronously ---
        verif.Status__c          = mappedStatus;
        verif.Completed_Date__c  = System.now();
        verif.Raw_Event_Type__c  = debugValue;
        Database.update(verif, AccessLevel.SYSTEM_MODE);

        // --- 5. Fetch score asynchronously for completed sessions ---
        if ((mappedStatus == 'Approved' || mappedStatus == 'Declined')
            && config != null
            && String.isNotBlank(config.API_Key__c))
        {
            fetchResultsAsync(verif.Id, interviewId, config.API_Key__c);
        }

        // --- 6. Acknowledge receipt ---
        res.statusCode = 200;
        res.responseBody = Blob.valueOf('{"result":"ok"}');
    }

    /**
     * Maps Incode event_type values to Salesforce Status__c picklist values.
     *
     * Incode event types:
     *   SESSION_SUCCEEDED      -> Approved
     *   SESSION_FAILED         -> Declined
     *   SESSION_PENDING_REVIEW -> Pending
     *   anything else          -> Error
     */
    @TestVisible
    private static String mapEventType(String eventType) {
        if (String.isBlank(eventType)) {
            return 'Error';
        }
        // Normalise: uppercase + collapse spaces to underscores so both
        // "Session Succeeded" (Incode production) and "SESSION_SUCCEEDED"
        // (Incode docs / older payloads) match the same branch.
        String normalised = eventType.toUpperCase().replace(' ', '_').replace('-', '_');
        if (normalised == 'SESSION_SUCCEEDED'
            || normalised == 'ONBOARDING_FINISHED'
            || normalised == 'COMPLETE'
            || normalised == 'COMPLETED') {
            return 'Approved';
        }
        if (normalised == 'SESSION_FAILED'
            || normalised == 'FAILED'
            || normalised == 'DECLINED') {
            return 'Declined';
        }
        if (normalised == 'SESSION_PENDING_REVIEW'
            || normalised == 'PENDING_REVIEW'
            || normalised == 'MANUAL_REVIEW') {
            return 'Pending';
        }
        if (normalised == 'SESSION_STARTED'
            || normalised == 'STARTED') {
            return 'Pending';
        }
        return 'Error';
    }

    /**
     * Fetches the verification score from Incode in an @future context so we
     * can make outbound callouts after the synchronous DML above completes.
     */
    @future(callout=true)
    private static void fetchResultsAsync(String verifId, String interviewId, String apiKey) {
        Decimal score = IncodeService.getScore(interviewId, apiKey);

        List<Incode_Verification__c> records = [
            SELECT Id, Score__c
            FROM Incode_Verification__c
            WHERE Id = :verifId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (records.isEmpty()) {
            return;
        }

        Incode_Verification__c record = records[0];
        if (score != null) {
            record.Score__c = score;
        }
        Database.update(record, AccessLevel.SYSTEM_MODE);
    }
}
