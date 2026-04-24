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

    private class KybScoreResult {
        public Decimal overallValue;
        public String  overallStatus; // OK | FAIL | UNKNOWN
        public String  reasonMsg;
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
            Session_ID__c         = interviewId,
            Session_Token__c      = sessionToken,
            Status__c             = 'Pending',
            Requested_Date__c     = System.now(),
            External_Reference__c = recordId,
            Verification_URL__c   = startUrl
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

    /**
     * Polls /omni/get/score for every Pending verification on the given record,
     * maps overall.status (OK → Approved, FAIL → Declined, UNKNOWN → stay Pending),
     * persists the result, and returns the refreshed list.
     *
     * Called by the LWC every 10s instead of a passive getVerifications poll.
     * Callout happens before DML so no @future is needed.
     */
    @AuraEnabled
    public static List<Incode_Verification__c> pollAndUpdateStatus(String recordId) {
        Incode_Config__c config = Incode_Config__c.getInstance();
        if (config == null || String.isBlank(config.API_Key__c)) {
            return getVerifications(recordId);
        }

        List<Incode_Verification__c> pending = [
            SELECT Id, Session_ID__c, Session_Token__c, Status__c
            FROM Incode_Verification__c
            WHERE External_Reference__c = :recordId
            AND Status__c = 'Pending'
            LIMIT 10
        ];

        if (pending.isEmpty()) {
            return getVerifications(recordId);
        }

        List<Incode_Verification__c> toUpdate = new List<Incode_Verification__c>();

        for (Incode_Verification__c v : pending) {
            KybScoreResult score = fetchKybScore(v.Session_ID__c, v.Session_Token__c, config.API_Key__c);
            if (score == null || score.overallStatus == 'UNKNOWN' || String.isBlank(score.overallStatus)) {
                continue; // scores not ready yet, stay Pending
            }

            v.Status__c        = score.overallStatus == 'OK' ? 'Approved' : 'Declined';
            v.Completed_Date__c = System.now();
            if (score.overallValue != null) {
                v.Score__c = score.overallValue;
            }
            if (String.isNotBlank(score.reasonMsg)) {
                v.Raw_Event_Type__c = score.reasonMsg.length() > 255
                    ? score.reasonMsg.substring(0, 255)
                    : score.reasonMsg;
            }
            toUpdate.add(v);
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }

        return getVerifications(recordId);
    }

    private static KybScoreResult fetchKybScore(String interviewId, String sessionToken, String apiKey) {
        Incode_Config__c cfg = Incode_Config__c.getInstance();
        String nc = namedCredential(cfg);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(nc + '/omni/get/score?id=' + EncodingUtil.urlEncode(interviewId, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('x-api-key', apiKey);
        req.setHeader('api-version', '1.0');
        if (String.isNotBlank(sessionToken)) {
            req.setHeader('X-Incode-Hardware-Id', sessionToken);
        }
        req.setTimeout(30000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            return null;
        }

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        KybScoreResult result = new KybScoreResult();

        Map<String, Object> overall = (Map<String, Object>) parsed.get('overall');
        if (overall != null) {
            result.overallStatus = (String) overall.get('status');
            Object val = overall.get('value');
            if (val != null) {
                try { result.overallValue = Decimal.valueOf(String.valueOf(val)); } catch (Exception e) {}
            }
        }

        result.reasonMsg = (String) parsed.get('reasonMsg');
        return result;
    }

    /**
     * Authenticates with the Incode executive API using the Admin Email/Password
     * stored in Incode_Config__c and returns the bearer token.
     */
    private static String getAdminToken(String nc, String apiKey, String adminEmail, String adminPassword) {
        Map<String, Object> body = new Map<String, Object>{
            'email'    => adminEmail,
            'password' => adminPassword
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint(nc + '/executive/log-in');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('x-api-key', apiKey);
        req.setHeader('api-version', '1.0');
        req.setBody(JSON.serialize(body));
        req.setTimeout(30000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            return null;
        }

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return (String) parsed.get('token');
    }

    /**
     * Returns the full /omni/single-session JSON for a given verification record.
     * Caches the result in Session_Details__c so the callout only happens once.
     *
     * @param verificationId  The Salesforce Incode_Verification__c record Id.
     * @return                The raw JSON string from /omni/single-session, or null on error.
     */
    @AuraEnabled
    public static String fetchSessionDetails(String verificationId) {
        List<Incode_Verification__c> records = [
            SELECT Id, Session_ID__c, Session_Details__c
            FROM Incode_Verification__c
            WHERE Id = :verificationId
            LIMIT 1
        ];

        if (records.isEmpty()) {
            throw new IncodeException('Verification record not found: ' + verificationId);
        }

        Incode_Verification__c verif = records[0];

        if (String.isNotBlank(verif.Session_Details__c)) {
            return verif.Session_Details__c;
        }

        Incode_Config__c config = Incode_Config__c.getInstance();
        if (config == null || String.isBlank(config.API_Key__c)) {
            throw new IncodeException('Incode API Key is not configured.');
        }
        if (String.isBlank(config.Admin_Email__c) || String.isBlank(config.Admin_Password__c)) {
            throw new IncodeException('Admin Email and Admin Password must be set in Incode Config custom settings.');
        }

        String nc      = namedCredential(config);
        String apiKey  = config.API_Key__c;
        String token   = getAdminToken(nc, apiKey, config.Admin_Email__c, config.Admin_Password__c);

        if (String.isBlank(token)) {
            throw new IncodeException('Could not obtain admin token from Incode. Check Admin Email/Password in Incode Config.');
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint(nc + '/omni/single-session?id=' + EncodingUtil.urlEncode(verif.Session_ID__c, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('x-api-key', apiKey);
        req.setHeader('api-version', '1.0');
        req.setHeader('X-Incode-Hardware-Id', token);
        req.setTimeout(30000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new IncodeException('Incode /omni/single-session returned HTTP ' + res.getStatusCode() + ': ' + res.getBody());
        }

        String detailsJson = res.getBody();

        // Cache result so subsequent opens are instant
        verif.Session_Details__c = detailsJson.length() > 131072
            ? detailsJson.substring(0, 131072)
            : detailsJson;
        update verif;

        return detailsJson;
    }

    public class IncodeException extends Exception {}
}
