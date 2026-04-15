/**
 * IncodeService
 *
 * Initiates an Incode identity verification session via the /omni/start endpoint.
 * Creates an Incode_Verification__c record to track the session, then returns
 * the hosted verification URL so it can be emailed to the contact.
 *
 * All HTTP callouts go through the IncodeAPI Named Credential so no credentials
 * are hardcoded in Apex.
 */
public with sharing class IncodeService {

    private static final String NAMED_CREDENTIAL_DEMO  = 'callout:IncodeAPI';
    private static final String NAMED_CREDENTIAL_PROD  = 'callout:IncodeAPI_Production';
    private static final String OMNI_START_PATH        = '/omni/start';
    private static final String OMNI_ONBOARDING_URL    = '/omni/onboarding-url';

    /** Returns the Named Credential prefix for the configured environment. */
    private static String namedCredential(Incode_Config__c config) {
        return (config != null && config.Use_Production_API__c == true)
            ? NAMED_CREDENTIAL_PROD
            : NAMED_CREDENTIAL_DEMO;
    }

    /**
     * Lightweight result class returned to callers (e.g. the LWC controller).
     */
    public class SessionResult {
        @AuraEnabled public String sessionId;
        @AuraEnabled public String verificationUrl;
        @AuraEnabled public String verificationRecordId;
    }

    /**
     * Initiates a new verification session for the given Salesforce record.
     *
     * @param recordId    The 18-char Salesforce record ID (Contact, Lead, or Account).
     * @param email       The email address to which the verification link will be sent.
     * @param objectType  'Contact', 'Lead', or 'Account' — determines which lookup to populate.
     * @return            SessionResult with sessionId, verificationUrl, and verificationRecordId.
     */
    @AuraEnabled
    public static SessionResult startSession(String recordId, String email, String objectType) {

        Incode_Config__c config = Incode_Config__c.getInstance();
        if (config == null || String.isBlank(config.API_Key__c)) {
            throw new IncodeException('Incode API Key is not configured. Please populate Incode_Config__c.');
        }
        if (String.isBlank(config.Configuration_ID__c)) {
            throw new IncodeException('Incode Configuration ID is not set. Please add it to Incode Config custom settings.');
        }

        String apiKey          = config.API_Key__c;
        String configurationId = config.Configuration_ID__c;
        String nc              = namedCredential(config);

        // Build the /omni/start request body
        Map<String, Object> requestBody = new Map<String, Object>{
            'externalCustomerId' => recordId,
            'configurationId'    => configurationId,
            'countryCode'        => 'ALL',
            'language'           => 'en-US'
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint(nc + OMNI_START_PATH);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('x-api-key', apiKey);
        req.setHeader('api-version', '1.0');
        req.setBody(JSON.serialize(requestBody));
        req.setTimeout(30000);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new IncodeException(
                'Incode /omni/start returned HTTP ' + res.getStatusCode() + ': ' + res.getBody()
            );
        }

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        // Incode returns interviewId (or interviewCode) and a session token.
        String interviewId = (String) parsed.get('interviewId');
        if (String.isBlank(interviewId)) {
            interviewId = (String) parsed.get('interviewCode');
        }
        String sessionToken = (String) parsed.get('token');

        if (String.isBlank(interviewId)) {
            throw new IncodeException('Incode response missing interviewId/interviewCode: ' + res.getBody());
        }

        // Fetch the hosted onboarding URL via /omni/onboarding-url using the session token.
        // The token is passed as X-Incode-Hardware-Id (Incode's session auth header).
        String startUrl = null;
        if (String.isNotBlank(sessionToken)) {
            startUrl = fetchOnboardingUrl(nc, sessionToken, apiKey);
        }

        if (String.isBlank(startUrl)) {
            throw new IncodeException(
                'Could not retrieve onboarding URL from Incode. interviewId=' + interviewId
                + '. Check that your API key and Configuration ID are correct.'
            );
        }

        // Persist a verification record
        Incode_Verification__c verif = new Incode_Verification__c(
            Session_ID__c        = interviewId,
            Status__c            = 'Pending',
            Requested_Date__c    = System.now(),
            External_Reference__c = recordId,
            Verification_URL__c  = startUrl
        );

        if (objectType == 'Contact') {
            verif.Contact__c = recordId;
        } else if (objectType == 'Lead') {
            verif.Lead__c = recordId;
        } else if (objectType == 'Account') {
            verif.Account__c = recordId;
        }

        insert verif;

        SessionResult result     = new SessionResult();
        result.sessionId         = interviewId;
        result.verificationUrl   = startUrl;
        result.verificationRecordId = verif.Id;
        return result;
    }

    /**
     * Calls /omni/onboarding-url to retrieve the hosted verification link for a session.
     * Requires the session token returned by /omni/start as X-Incode-Hardware-Id.
     *
     * @param sessionToken  The JWT token from the /omni/start response.
     * @param apiKey        The Incode API key.
     * @return              The hosted onboarding URL, or null if unavailable.
     */
    @TestVisible
    private static String fetchOnboardingUrl(String nc, String sessionToken, String apiKey) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(nc + OMNI_ONBOARDING_URL);
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('x-api-key', apiKey);
        req.setHeader('api-version', '1.0');
        req.setHeader('X-Incode-Hardware-Id', sessionToken);
        req.setTimeout(30000);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            return null;
        }

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return (String) parsed.get('url');
    }

    /**
     * Retrieves the verification score from Incode for the given session.
     * Called by IncodeWebhookHandler after a session completes.
     *
     * @param interviewId  The Incode session/interview ID.
     * @return             The overall score as a Decimal, or null if unavailable.
     */
    public static Decimal getScore(String interviewId, String apiKey) {
        Incode_Config__c cfg = Incode_Config__c.getInstance();
        String nc = namedCredential(cfg);
        HttpRequest req = new HttpRequest();
        req.setEndpoint(nc + '/omni/get/score?id=' + EncodingUtil.urlEncode(interviewId, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('x-api-key', apiKey);
        req.setHeader('api-version', '1.0');
        req.setTimeout(30000);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            return null;
        }

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        Object overallScore = parsed.get('overall');
        if (overallScore == null) {
            return null;
        }
        return Decimal.valueOf(String.valueOf(overallScore));
    }

    /**
     * Retrieves OCR data from Incode for the given session.
     * Returns the raw JSON string for storage/processing.
     */
    public static String getOcrData(String interviewId, String apiKey) {
        Incode_Config__c cfg = Incode_Config__c.getInstance();
        String nc = namedCredential(cfg);
        HttpRequest req = new HttpRequest();
        req.setEndpoint(nc + '/omni/get/ocr-data?id=' + EncodingUtil.urlEncode(interviewId, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('x-api-key', apiKey);
        req.setHeader('api-version', '1.0');
        req.setTimeout(30000);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            return null;
        }
        return res.getBody();
    }

    /**
     * Returns all Incode_Verification__c records for the given parent record,
     * newest first. Called by the LWC to display the full history and poll
     * for status updates.
     *
     * @param recordId  The Salesforce Contact, Lead, or Account ID.
     * @return          List of Incode_Verification__c records (may be empty).
     */
    @AuraEnabled(cacheable=false)
    public static List<Incode_Verification__c> getVerifications(String recordId) {
        return [
            SELECT Id, Status__c, Score__c, Requested_Date__c, Completed_Date__c,
                   Verification_URL__c, Session_ID__c, Raw_Event_Type__c
            FROM Incode_Verification__c
            WHERE External_Reference__c = :recordId
            ORDER BY Requested_Date__c DESC
            LIMIT 50
        ];
    }

    public class IncodeException extends Exception {}
}
