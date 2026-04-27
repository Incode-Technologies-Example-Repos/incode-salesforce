public with sharing class IncodeEmailService {

    private static final String EMAIL_SUBJECT = 'Action Required: Complete Your Business Verification';

    // Text-based Incode wordmark — reliable across all email clients including Gmail/Outlook.
    // Blue square (brand accent) + bold "incode" wordmark in white.
    private static final String LOGO_SVG =
        '<table role="presentation" cellpadding="0" cellspacing="0" border="0">'
        + '<tr>'
        + '<td style="vertical-align:bottom;padding-right:3px;padding-bottom:4px;line-height:0;">'
        + '<div style="width:9px;height:9px;background-color:#006aff;font-size:0;line-height:0;">&nbsp;</div>'
        + '</td>'
        + '<td style="vertical-align:bottom;">'
        + '<span style="font-family:Arial,Helvetica,sans-serif;font-size:30px;font-weight:900;'
        + 'color:#ffffff;letter-spacing:-1px;line-height:1;display:inline-block;">incode</span>'
        + '</td>'
        + '</tr>'
        + '</table>';

    // Kept for backward compatibility — no longer used
    private static final String LOGO_B64 =
        'PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA5ODEg' +
        'MjQ5Ij48cGF0aCBmaWxsPSIjZmZmIiBmaWxsLXJ1bGU9ImV2ZW5vZGQiIGNsaXAtcnVsZT0iZXZl' +
        'bm9kZCIgZD0iTTM1MC44IDYyLjkyNzNDMzUwLjggNjIuOTEwMyAzNTAuODE0IDYyLjg5NjUgMzUw' +
        'LjgzMSA2Mi44OTY1QzM2OS41NjMgNjIuOTAwMiAzODcuMzcxIDY2LjMzNzQgNDA0LjI1NiA3My4y' +
        'NjkxQzQwNS4xMTEgNzMuNjAyMSA0MDUuNjc0IDc0LjQyNjUgNDA1LjY3NCA3NS4zNDUxVjEwNy4z' +
        'NjdDNDA1LjY3NCAxMDguOTkgNDA0LjAzIDExMC4wOTYgNDAyLjUyOSAxMDkuNDgxQzM4NS41MTIg' +
        'MTAyLjMgMzY5Ljk3NSA5OC43Mzk5IDM1NS45MTYgOTguNzM5OUMzMzguNDY4IDk4LjczOTkgMzI1' +
        'LjY0NCAxMDMuMDM2IDMxNy4yNTggMTExLjU2N0MzMDguODc0IDEyMC4wMzcgMzA0LjYyIDEzMy43' +
        'ODUgMzA0LjYyIDE1Mi43NUMzMDQuNjIgMTcyLjY5OCAzMDguODExIDE4OS4wNjYgMzE3LjAxMyAx' +
        'OTcuOTY1QzMyNS4xNTIgMjA2Ljg2NSAzMzguNDY4IDIxMS4zNDUgMzU3LjAyOCAyMTEuMzQ1QzM3' +
        'Mi4xOTQgMjExLjM0NSAzODcuNDIzIDIwNy42NjMgNDAyLjgzOCAyMDAuMzU5QzQwNC4zMjUgMTk5' +
        'LjY0NyA0MDYuMDQ0IDIwMC43MzMgNDA2LjA0NCAyMDIuMzgzVjIzNC40MDVDNDA2LjA0NCAyMzUu' +
        'MzEyIDQwNS41MTMgMjM2LjEzNiA0MDQuNjg3IDIzNi41MDlDMzg4LjA0IDI0My45MzUgMzcwLjIy' +
        'MiAyNDcuNjE5IDM1MS4xNyAyNDcuNjE5QzMyNy42NzkgMjQ3LjYxOSAzMDcuODg3IDI0MS4xNzQg' +
        'MjkxLjc5NCAyMjguMjg1TDI4OS4zOTEgMjI2LjMyMUwyODcuNjAzIDIyNC42NjRDMjcyLjE4OCAy' +
        'MTAuMjQgMjY0LjU0MiAxODUuODMyIDI2NC41NDIgMTU1LjUxMkMyNjQuNTQyIDEyMy4xMDYgMjcy' +
        'LjY4IDk5LjUzNzcgMjg5LjAyMSA4NC44MDc4QzMwNS4yODkgNzAuMjA2MiAzMjUuODc0IDYyLjk2' +
        'NCAzNTAuNzY5IDYyLjk1OEMzNTAuNzg2IDYyLjk1OCAzNTAuOCA2Mi45NDQzIDM1MC44IDYyLjky' +
        'NzNaIi8+PHBhdGggZmlsbD0iI2ZmZiIgZmlsbC1ydWxlPSJldmVub2RkIiBjbGlwLXJ1bGU9ImV2' +
        'ZW5vZGQiIGQ9Ik00My41ODg3IDY3Ljk2NjhDNDQuOTQxMyA2Ny45NjY4IDQ2LjAzNzkgNjkuMDY0' +
        'OSA0Ni4wMzc5IDcwLjQxOTRWMjQwLjAwNUM0Ni4wMzc5IDI0MS4zNTkgNDQuOTQxMyAyNDIuNDU3' +
        'IDQzLjU4ODcgMjQyLjQ1N0g1LjUzNjExQzQuMTgzNDYgMjQyLjQ1NyAzLjA4NjkxIDI0MS4zNTkg' +
        'My4wODY5MSAyNDAuMDA1VjcwLjQxOTRDMy4wODY5MSA2OS4wNjQ5IDQuMTgzNDYgNjcuOTY2OCA1' +
        'LjUzNjExIDY3Ljk2NjhINDMuNTg4N1oiLz48cGF0aCBmaWxsPSIjZmZmIiBmaWxsLXJ1bGU9ImV2' +
        'ZW5vZGQiIGNsaXAtcnVsZT0iZXZlbm9kZCIgZD0iTTE2Mi41MTggNjMuMTk0OEMxNjIuNTE4IDYz' +
        'LjE3NzggMTYyLjUzMiA2My4xNjQxIDE2Mi41NDkgNjMuMTY0MUMxODYuOTQ5IDYzLjE2ODQgMjA1' +
        'LjA2NiA2OC4zMjQxIDIxNi45NiA3OC42OTIxQzIyOC44NiA4OS4xODc0IDIzNC43NzkgMTA1LjMy' +
        'OSAyMzQuNzc5IDEyNy4wNTZWMjM5Ljk4OUMyMzQuNzc5IDI0MS4zNDQgMjMzLjY4MyAyNDIuNDQy' +
        'IDIzMi4zMyAyNDIuNDQySTE5Ni44NDNDMTk1LjQ5MSAyNDIuNDQyIDE5NC4zOTQgMjQxLjM0NCAX' +
        'OTQuMzk0IDIzOS45ODlWMTMxLjg0M0MxOTQuMzk0IDEwOS4zMTkgMTgxLjk0IDk4LjMzMjMgMTU2' +
        'LjA0NCA5OC4zMzIzQzE0NS4yNTQgOTguMzMyMyAxMzQuODM0IDk5Ljg2NjkgMTI0Ljc4NCAxMDIu' +
        'OTM2TDEyMi43NjMgMTAzLjYwNkMxMjEuNzYxIDEwMy45MzkgMTIxLjA4NSAxMDQuODc3IDEyMS4w' +
        'ODUgMTA1LjkzNFYyNDAuMDUxQzEyMS4wODUgMjQxLjQwNSAxMTkuOTg4IDI0Mi41MDMgMTE4LjYz' +
        'NSAyNDIuNTAzSDgzLjE0ODlDODEuNzk2MiAyNDIuNTAzIDgwLjY5OTcgMjQxLjQwNSA4MC42OTk3' +
        'IDI0MC4wNTFWODMuMTM5OEM4MC42OTk3IDgyLjI5NTEgODEuMTc3NCA4MS41MjMxIDgxLjkzMjkg' +
        'ODEuMTQ3MkM5Mi4zNTI3IDc1Ljg2ODkgMTA0Ljk5MiA3MS41MTEzIDExOS44NTIgNjguMTk2OEwx' +
        'MjQuNzg0IDY3LjE1MzVDMTM3Ljg0NCA2NC41MTY3IDE1MC40MTIgNjMuMjI3OCAxNjIuNDg3IDYz' +
        'LjIyNTZDMTYyLjUwNCA2My4yMjU2IDE2Mi41MTggNjMuMjExOCAxNjIuNTE4IDYzLjE5NDhaIi8+' +
        'PHBhdGggZmlsbD0iI2ZmZiIgZmlsbC1ydWxlPSJldmVub2RkIiBjbGlwLXJ1bGU9ImV2ZW5vZGQi' +
        'IGQ9Ik01NzkuNTI4IDg2LjU3MjVDNTY1LjE2MSA3MC43Mzc2IDU0My44MjkgNjIuODIwMyA1MTUu' +
        'NzEyIDYyLjgyMDNDNDU5Ljc4OSA2Mi44MjAzIDQzMS40ODkgOTMuNzUzNiA0MzEuNDg5IDE1NC42' +
        'OTlDNDMxLjQ4OSAxODMuNDg1IDQzNy45NjQgMjA1LjgyNSA0NTAuOTcyIDIyMS42Nkw0NTIuNjk5' +
        'IDIyMy42ODZDNDY2Ljk0MyAyMzkuNjQzIDQ4OC4wOSAyNDcuNjIzIDUxNi4wMiAyNDcuNjIzQzU0' +
        'My45NTEgMjQ3LjYyMyA1NjMuOTkgMjM5LjU4MiA1NzguNzg2IDIyMy4zNzlDNTkzLjUyMyAyMDcu' +
        'MjM3IDYwMC44NjEgMTg0LjM0NCA2MDAuODYxIDE1NC43NjFDNjAwLjg2MSAxMjUuMTc4IDU5My43' +
        'NyAxMDIuNDA3IDU3OS40NjQgODYuNjMzOEw1NzkuNTI4IDg2LjU3MjVaTTUxNS43MTIgMjEyLjc2' +
        'MUM1MDAuMjM4IDIxMi43NjEgNDg5LjEzOCAyMDcuOTEyIDQ4Mi4yMzQgMTk4LjIxNUM0NzUuMTQz' +
        'IDE4OC4zMzMgNDcxLjU2NyAxNzMuODQ5IDQ3MS41NjcgMTU0LjY5OUM0NzEuNTY3IDEzNS41NSA0' +
        'NzUuMDE4IDEyMS4xODggNDgxLjkyNSAxMTEuNTUzQzQ4OC42NDYgMTAyLjEwMSA0OTkuODA0IDk3' +
        'LjMxMzMgNTE1Ljc3NiA5Ny4zMTMzQzUzMS43NDQgOTcuMzEzMyA1NDIuNzggMTAxLjk3OCA1NDku' +
        'ODEgMTExLjI0NUM1NTYuOTYxIDEyMC42OTcgNTYwLjU5OCAxMzUuMTgyIDU2MC41OTggMTU0LjY5' +
        'OUM1NjAuNTk4IDE5My43OTYgNTQ1LjczOSAyMTIuNzYxIDUxNS43MTIgMjEyLjc2MVoiLz48cGF0' +
        'aCBmaWxsPSIjZmZmIiBmaWxsLXJ1bGU9ImV2ZW5vZGQiIGNsaXAtcnVsZT0iZXZlbm9kZCIgZD0i' +
        'TTc1My4xMjEgMS4yMzQzOEM3NTEuNzY4IDEuMjM0MzggNzUwLjY3MiAyLjMzMjQ1IDc1MC42NzIg' +
        'My42ODdWNjcuMzMyNkM3NTAuNjcyIDY5LjEwMTggNzQ4Ljg1NSA3MC4yOTQ2IDc0Ny4yMDUgNjku' +
        'NjYzNUM3NDIuNDI0IDY3LjgzNTMgNzM3LjI3MSA2Ni4zODY1IDczMS42ODEgNjUuMjUzOUM3MjMu' +
        'NDgxIDYzLjY1ODIgNzE2LjIwNCA2Mi44NjAzIDcwOS45MTcgNjIuODYwM0M2ODIuOTEgNjIuODYw' +
        'MyA2NjIuMzc4IDcwLjgzOTIgNjQ4LjQ0NSA4Ni43OTY3QzYzNC42MzQgMTAyLjY5MyA2MjcuNzI3' +
        'IDEyNC42NjYgNjI3LjcyNyAxNTIuNjUzQzYyNy43MjcgMTg3LjU3NSA2MzUuODA1IDIxMi4xODcg' +
        'NjUyLjAyMSAyMjYuNDI2QzY2OC4xNzYgMjQwLjU0MyA2ODguNzA3IDI0Ny42MDEgNzEzLjYxNiAy' +
        'NDcuNjAxQzcyNS44ODYgMjQ3LjYwMSA3MzcuNzg0IDI0Ni4xMjcgNzQ5LjM3NiAyNDMuMTJDNzYx' +
        'LjA5MSAyNDAuMTEzIDc3MC44MzQgMjM1LjMyNiA3NzguNjAzIDIyOC44ODFDNzg2LjYxNiAyMjIu' +
        'MTkxIDc5MC42ODcgMjEzLjkwNiA3OTAuNjg3IDIwNC4xNDdWMy42ODdDNzkwLjY4NyAyLjMzMjQ1' +
        'IDc4OS41OSAxLjIzNDM4IDc4OC4yMzggMS4yMzQzOEg3NTMuMTIxWiIvPjxwYXRoIGZpbGw9IiNm' +
        'ZmYiIGZpbGwtcnVsZT0iZXZlbm9kZCIgY2xpcC1ydWxlPSJldmVub2RkIiBkPSJNNDMuNTg4NyAx' +
        'LjI1NTg2QzQ0Ljk0MTMgMS4yNTU4NiA0Ni4wMzc5IDIuMzUzOTQgNDYuMDM3OSAzLjcwODQ5VjM1' +
        'LjY4OTlDNDYuMDM3OSAzNy4wNDQ1IDQ0Ljk0MTMgMzguMTQyNSA0My41ODg3IDM4LjE0MjVINS41' +
        'MzYxMUM0LjE4MzQ2IDM4LjE0MjUgMy4wODY5MSAzNy4wNDQ1IDMuMDg2OTEgMzUuNjg5OVYzLjcw' +
        'ODQ4QzMuMDg2OTEgMi4zNTM5NCA0LjE4MzQ2IDEuMjU1ODYgNS41MzYxMSAxLjI1NTg2SDQzLjU4' +
        'ODdaIi8+PHBhdGggZmlsbD0iI2ZmZiIgZD0iTTg5OS43MjUgNjIuNzE4OEM5MjcuMDE3IDYyLjcx' +
        'ODkgOTQ3LjE1OCA3MS41MzY4IDk2MC4wMzUgODkuMjk0OUM5NzIuMTcgMTA2LjA3NCA5NzguMzky' +
        'IDEyOS4xNjIgOTc4LjcwMSAxNTguNDk0VjE2Mi4yOTFDOTc4LjcwMSAxNjMuNjQzIDk3Ny42MDUg' +
        'MTY0LjczOCA5NzYuMjU0IDE2NC43MzhIODYxLjUwOUM4NjAuMDY4IDE2NC43MzkgODU4LjkzNyAx' +
        'NjUuOTggODU5LjExMiAxNjcuNDFDODYwLjgwNCAxODEuMjEzIDg2NS4zMzQgMTkxLjcyOCA4NzIu' +
        'ODA1IDE5OS4xNTVDODgxLjEyMyAyMDcuNDIyIDg5My4wMTEgMjExLjU4NyA5MDguNTk2IDIxMS41' +
        'ODdDOTE4Ljg4NiAyMTEuNTg3IDkyOC42NzkgMjEwLjI5OSA5MzcuOTgyIDIwNy43MjdDOTQ3LjM0' +
        'NSAyMDUuMjE2IDk1NS41OTkgMjAxLjkxIDk2Mi43NDcgMTk3LjkyOUw5NjYuMTMzIDE5Ni4wMzJM' +
        'OTY4LjU0NCAxOTQuMzE4Qzk3MC4xNjUgMTkzLjE2OCA5NzIuNDA5IDE5NC4zMjYgOTcyLjQwOSAx' +
        'OTYuMzE0VjIzMC4xQzk3Mi40MDkgMjMxLjA0MiA5NzEuODY3IDIzMS45MDEgOTcxLjAxOCAyMzIu' +
        'MzA4TDk2Ni4xNDUgMjM0LjY0Qzk2Ni4xMzggMjM0LjY0NCA5NjYuMTM0IDIzNC42NSA5NjYuMTMz' +
        'IDIzNC42NTdDOTY2LjEzMyAyMzQuNjY1IDk2Ni4xMjggMjM0LjY3MyA5NjYuMTIxIDIzNC42NzZM' +
        'OTY0Ljc3OCAyMzUuMjgzQzk0Ni43MjkgMjQzLjEyMiA5MjYuMDkyIDI0Ny4wNDEgOTAyLjgwNiAy' +
        'NDcuMDQxQzg3Ni41MDIgMjQ3LjA0MSA4NTUuNjggMjM5LjAxOSA4NDAuNTg3IDIyMy4wMzZDODI1' +
        'LjQ5NiAyMDcuMDUzIDgxNy45NzggMTg1LjEzMSA4MTcuOTc4IDE1NS4zNzFDODE3Ljk3OCAxMjUu' +
        'NjEgODI1LjA2MyAxMDIuNzA2IDgzOS4zNTYgODYuNzIzNUM4NTMuNjQ3IDcwLjc0MSA4NzMuODUz' +
        'IDYyLjcxODggODk5LjcyNSA2Mi43MTg4Wk04OTguNjc2IDk2LjQ1OTNDODU3LjA5NyA5Ni40NTk0' +
        'IDg3OC4yMjggOTkuNDAwMiA4NzEuODgzIDEwNS4zMzlDODY2LjI3NiAxMTAuNTQ1IDg2Mi4zMzMg' +
        'MTE5LjExOCA4NjAuMTEzIDEzMS4xMkw4NTkuNjkgMTMzLjcwNUM4NTkuNjg1IDEzMy43MzUgODU5' +
        'LjY5NiAxMzMuNzY1IDg1OS43MTYgMTMzLjc4N0M4NTkuNzM0IDEzMy44MDQgODU5Ljc1OSAxMzMu' +
        'ODE1IDg1OS43ODMgMTMzLjgxNUg5MzQuNzU5QzkzNi4xOTEgMTMzLjgxNSA5MzcuMjgzIDEzMi41' +
        'MzQgOTM3LjA1NyAxMzEuMTJDOTM1LjE0OSAxMTkuNzMgOTMxLjUxMSAxMTEuMzQxIDkyNi4wOTEg' +
        'MTA1LjgyOUM5MTkuOTI5IDk5LjU4MzcgOTEwLjg3NSA5Ni40NTkzIDg5OC42NzYgOTYuNDU5M1oi' +
        'Lz48L3N2Zz4=';

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

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ toAddress });
        mail.setSubject(EMAIL_SUBJECT);
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
            throw new IncodeEmailException('Email send failed: ' + errorMsg);
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
            + '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#f0f2f5">'
            + '<tr><td align="center" style="padding:40px 16px;">'

            // ── 600px card
            + '<table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0"'
            + ' style="max-width:600px;width:100%;border-radius:12px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.12);">'

            // ── HEADER ──────────────────────────────────────────────────────
            + '<tr><td bgcolor="#0f1422" style="background-color:#0f1422;padding:28px 40px 26px;">'
            + '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr>'
            + '<td valign="middle">'
            + LOGO_SVG
            + '<p style="margin:10px 0 0;font-size:10px;font-weight:700;color:#5a6a8a;'
            + 'text-transform:uppercase;letter-spacing:2px;line-height:1;">Business Verification Required</p>'
            + '</td>'
            + '<td align="right" valign="middle">'
            + '<span style="display:inline-block;background-color:#006aff;color:#ffffff;font-size:10px;'
            + 'font-weight:700;text-transform:uppercase;letter-spacing:1px;padding:5px 14px;border-radius:20px;'
            + 'white-space:nowrap;">Action Required</span>'
            + '</td>'
            + '</tr></table>'
            + '</td></tr>'

            // ── BODY ─────────────────────────────────────────────────────────
            + '<tr><td bgcolor="#ffffff" style="background-color:#ffffff;padding:36px 40px 32px;">'

            // Greeting
            + '<p style="margin:0 0 18px;font-size:17px;font-weight:700;color:#0f1422;line-height:1.4;">'
            + greeting
            + '</p>'

            // Intro paragraph
            + '<p style="margin:0 0 24px;font-size:15px;line-height:1.8;color:#444444;">'
            + 'To complete your onboarding, we need to verify your business through our '
            + '<strong style="color:#0f1422;">eKYB (electronic Know Your Business)</strong> process. '
            + 'This is a standard step required by financial regulations and '
            + 'Anti-Money Laundering (AML) compliance policies before your account can be fully activated.'
            + '</p>'

            // ── Info box: What to expect
            + '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"'
            + ' style="margin:0 0 32px;">'
            + '<tr><td style="background-color:#f0f5ff;border-left:4px solid #006aff;'
            + 'border-radius:0 8px 8px 0;padding:18px 22px;">'
            + '<p style="margin:0 0 12px;font-size:11px;font-weight:700;text-transform:uppercase;'
            + 'letter-spacing:1.2px;color:#006aff;">What to expect</p>'
            + '<table role="presentation" cellpadding="0" cellspacing="0" border="0">'
            + '<tr><td style="padding:5px 0;font-size:14px;color:#333;line-height:1.6;">'
            + '<span style="color:#006aff;font-weight:700;padding-right:8px;">&#10003;</span>'
            + 'Confirm your business name, registration number &amp; address</td></tr>'
            + '<tr><td style="padding:5px 0;font-size:14px;color:#333;line-height:1.6;">'
            + '<span style="color:#006aff;font-weight:700;padding-right:8px;">&#10003;</span>'
            + 'Provide beneficial ownership (UBO) information if applicable</td></tr>'
            + '<tr><td style="padding:5px 0;font-size:14px;color:#333;line-height:1.6;">'
            + '<span style="color:#006aff;font-weight:700;padding-right:8px;">&#10003;</span>'
            + 'Takes only <strong>~2 minutes</strong> to complete</td></tr>'
            + '<tr><td style="padding:5px 0;font-size:14px;color:#333;line-height:1.6;">'
            + '<span style="color:#006aff;font-weight:700;padding-right:8px;">&#10003;</span>'
            + 'Your data is encrypted and processed securely by Incode</td></tr>'
            + '</table>'
            + '</td></tr></table>'

            // ── CTA button (centered)
            + '<table role="presentation" align="center" cellpadding="0" cellspacing="0" border="0"'
            + ' style="margin:0 auto 28px;">'
            + '<tr><td align="center" bgcolor="#006aff"'
            + ' style="background-color:#006aff;border-radius:8px;padding:17px 48px;">'
            + '<a href="' + verificationUrl + '" target="_blank"'
            + ' style="color:#ffffff;text-decoration:none;font-size:16px;font-weight:700;'
            + 'letter-spacing:0.4px;white-space:nowrap;display:block;">'
            + 'Verify My Business &nbsp;&#8594;'
            + '</a>'
            + '</td></tr></table>'

            // Fallback URL
            + '<p style="margin:0 0 6px;font-size:13px;color:#999;text-align:center;">'
            + 'If the button above does not work, copy and paste this link into your browser:'
            + '</p>'
            + '<p style="margin:0 0 28px;font-size:12px;word-break:break-all;color:#006aff;text-align:center;">'
            + verificationUrl
            + '</p>'

            + '<hr style="border:none;border-top:1px solid #eeeeee;margin:0 0 20px;"/>'

            // Security notice
            + '<p style="margin:0;font-size:12px;color:#aaaaaa;line-height:1.75;">'
            + '<strong style="color:#888888;">Security notice:</strong> '
            + 'This link is unique to you and expires after a single use. '
            + 'Please do not forward or share it with anyone. '
            + 'If you were not expecting this email, please disregard it or contact our support team immediately.'
            + '</p>'
            + '</td></tr>'

            // ── FOOTER ───────────────────────────────────────────────────────
            + '<tr><td bgcolor="#0f1422" style="background-color:#0f1422;padding:20px 40px;">'
            + '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr>'
            + '<td><p style="margin:0;font-size:12px;color:#5a6a8a;">'
            + 'Powered by <strong style="color:#ffffff;">Incode Technologies</strong>'
            + '</p></td>'
            + '<td align="right"><p style="margin:0;font-size:11px;color:#5a6a8a;">'
            + '&copy; 2026 Incode Technologies, Inc.'
            + '</p></td>'
            + '</tr></table>'
            + '</td></tr>'

            + '</table>' // card
            + '</td></tr>'
            + '</table>' // outer wrapper
            + '</body></html>';
    }

    private static String buildPlainTextFallback(String firstName, String verificationUrl) {
        String greeting = String.isNotBlank(firstName) ? 'Hi ' + firstName + ',' : 'Hi,';
        return greeting + '\n\n'
            + 'ACTION REQUIRED: Complete Your Business Verification\n'
            + '------------------------------------------------------\n\n'
            + 'To complete your onboarding, we need to verify your business through our eKYB '
            + '(electronic Know Your Business) process. This is a standard requirement under '
            + 'financial regulations and Anti-Money Laundering (AML) compliance policies.\n\n'
            + 'WHAT TO EXPECT:\n'
            + '  + Confirm your business name, registration number & address\n'
            + '  + Provide beneficial ownership (UBO) information if applicable\n'
            + '  + Takes only ~2 minutes to complete\n'
            + '  + Your data is encrypted and processed securely\n\n'
            + 'VERIFY MY BUSINESS:\n'
            + verificationUrl + '\n\n'
            + '------------------------------------------------------\n'
            + 'Security notice: This link is unique to you and expires after a single use.\n'
            + 'Do not share it with anyone. If you were not expecting this message, please\n'
            + 'disregard it or contact our support team immediately.\n\n'
            + 'Powered by Incode Technologies | incode.com';
    }

    public class IncodeEmailException extends Exception {}
}
