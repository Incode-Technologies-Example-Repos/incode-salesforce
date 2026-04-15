/**
 * IncodeHttpMock
 *
 * Shared HttpCalloutMock used by all Incode test classes.
 * Routes requests by URL path so that multi-call flows (e.g. /omni/start
 * followed by /omni/onboarding-url) each get the correct response.
 */
@IsTest
public class IncodeHttpMock implements HttpCalloutMock {

    // Each entry in this list is checked in order; first match wins.
    private List<RouteEntry> routes = new List<RouteEntry>();

    // Fallback when no route matches
    private Integer defaultStatus = 200;
    private String  defaultBody   = '{}';

    private class RouteEntry {
        String  urlContains;
        Integer statusCode;
        String  body;
        RouteEntry(String urlContains, Integer statusCode, String body) {
            this.urlContains = urlContains;
            this.statusCode  = statusCode;
            this.body        = body;
        }
    }

    public IncodeHttpMock() {}

    /** Constructor for single-endpoint mocks (backwards compat). */
    public IncodeHttpMock(Integer statusCode, String body) {
        this.defaultStatus = statusCode;
        this.defaultBody   = body;
    }

    /**
     * Register a route: requests whose URL contains `urlContains` get this response.
     * Routes are evaluated in registration order; first match wins.
     */
    public IncodeHttpMock addRoute(String urlContains, Integer statusCode, String body) {
        routes.add(new RouteEntry(urlContains, statusCode, body));
        return this; // fluent
    }

    public HTTPResponse respond(HTTPRequest req) {
        String endpoint = req.getEndpoint();
        for (RouteEntry r : routes) {
            if (endpoint.contains(r.urlContains)) {
                HttpResponse res = new HttpResponse();
                res.setStatusCode(r.statusCode);
                res.setHeader('Content-Type', 'application/json');
                res.setBody(r.body);
                return res;
            }
        }
        // Fallback
        HttpResponse res = new HttpResponse();
        res.setStatusCode(defaultStatus);
        res.setHeader('Content-Type', 'application/json');
        res.setBody(defaultBody);
        return res;
    }

    // -----------------------------------------------------------------------
    // Factory helpers
    // -----------------------------------------------------------------------

    /**
     * Full happy-path mock for startSession():
     *   1st call  -> /omni/start         -> returns token + interviewId
     *   2nd call  -> /omni/onboarding-url -> returns hosted URL
     */
    public static IncodeHttpMock omniStartSuccess() {
        return new IncodeHttpMock()
            .addRoute('/omni/start',
                200,
                '{"interviewId":"test-session-123","token":"test-jwt-token"}')
            .addRoute('/omni/onboarding-url',
                200,
                '{"url":"https://demo-onboarding.incodesmile.com/client/hello?token=test-jwt-token"}');
    }

    /** Returns a failed /omni/start response. */
    public static IncodeHttpMock omniStartFailure() {
        return new IncodeHttpMock(400, '{"error":"Bad Request"}');
    }

    /** Returns a successful /omni/get/score response. */
    public static IncodeHttpMock scoreSuccess() {
        return new IncodeHttpMock(200, '{"overall":0.95,"liveness":0.98,"idValidation":0.91}');
    }

    /** Returns a successful /omni/get/ocr-data response. */
    public static IncodeHttpMock ocrSuccess() {
        return new IncodeHttpMock(200, '{"name":"John Doe","dob":"1990-01-01"}');
    }

    /** Returns a server error for any endpoint. */
    public static IncodeHttpMock serverError() {
        return new IncodeHttpMock(500, '{"error":"Internal Server Error"}');
    }
}
