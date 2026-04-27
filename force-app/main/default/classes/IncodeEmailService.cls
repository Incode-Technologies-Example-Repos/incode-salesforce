public with sharing class IncodeEmailService {

    private static final String EMAIL_SUBJECT = 'Action Required: Complete Your Business Verification';

    // Inline SVG — white Incode wordmark (Gmail blocks data: URIs on img tags)
    private static final String LOGO_SVG =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 981 249" width="140" height="36"'
        + ' style="display:block;vertical-align:middle;" aria-label="incode"><g fill="#ffffff">'
        + '<path fill-rule="evenodd" clip-rule="evenodd" d="M350.8 62.93c0-.02.01-.03.03-.03'
        + ' 18.73 0 36.54 3.44 53.43 10.37.85.33 1.42 1.16 1.42 2.08v32.02c0 1.62-1.64 2.73-3.14 2.11'
        + '-17.02-7.18-32.56-10.74-46.61-10.74-17.45 0-30.27 4.3-38.66 12.83-8.38 8.47-12.64 22.22-12.64 41.18'
        + ' 0 19.95 4.19 36.32 12.39 45.22 8.14 8.9 21.46 13.38 40.02 13.38 15.17 0 30.4-3.68 45.81-10.99'
        + ' 1.49-.71 3.21.37 3.21 2.02v32.02c0 .91-.53 1.73-1.36 2.1-16.65 7.43-34.47 11.11-53.52 11.11'
        + '-23.49 0-43.28-6.44-59.38-19.33l-2.4-1.96-1.79-1.66C257.87 211.74 250.22 187.33 250.22 157.01'
        + 'c0-32.41 8.14-55.97 24.48-70.7C290.97 71.71 311.55 64.46 336.45 64.46c.02 0 .03-.01.03-.03z"/>'
        + '<path fill-rule="evenodd" clip-rule="evenodd" d="M43.59 67.97c1.35 0 2.45 1.1 2.45 2.45v169.59'
        + 'c0 1.35-1.1 2.45-2.45 2.45H5.54c-1.35 0-2.45-1.1-2.45-2.45V70.42c0-1.35 1.1-2.45 2.45-2.45h38.05z"/>'
        + '<path fill-rule="evenodd" clip-rule="evenodd" d="M162.52 63.19c0-.02.01-.03.03-.03'
        + ' 24.4 0 42.52 5.16 54.41 15.53 11.9 10.5 17.82 26.64 17.82 48.37v112.93c0 1.35-1.1 2.45-2.45 2.45'
        + 'h-35.49c-1.35 0-2.45-1.1-2.45-2.45V131.84c0-22.52-12.45-33.51-38.35-33.51-10.79 0-21.21 1.53-31.26 4.6'
        + 'l-2.02.67c-1 .33-1.68 1.27-1.68 2.33v134.12c0 1.35-1.1 2.45-2.45 2.45H83.15c-1.35 0-2.45-1.1-2.45-2.45'
        + 'V83.14c0-.84.48-1.62 1.23-2 10.42-5.28 23.06-9.64 37.92-12.95l4.93-1.04c13.06-2.64 25.63-3.93 37.7-3.93'
        + 'c.02 0 .03-.01.03-.03z"/>'
        + '<path fill-rule="evenodd" clip-rule="evenodd" d="M579.53 86.57c-14.37-15.83-35.7-23.75-63.82-23.75'
        + '-55.92 0-84.22 30.93-84.22 91.88 0 28.79 6.48 51.13 19.48 66.96l1.73 2.03c14.24 15.96 35.39 23.94 63.32 23.94'
        + 's56-8.04 70.8-24.24c14.74-16.14 22.07-39.04 22.07-68.62 0-29.58-7.09-52.35-21.4-68.09l.04-.11z'
        + 'M515.71 212.76c-15.47 0-26.57-4.85-33.48-14.55-7.09-9.88-10.67-24.37-10.67-43.51'
        + ' 0-19.15 3.45-33.51 10.36-43.15 6.72-9.45 17.88-14.24 33.85-14.24 15.97 0 27 4.67 34.03 13.93'
        + ' 7.15 9.45 10.79 23.94 10.79 43.45 0 39.1-14.86 58.07-44.89 58.07z"/>'
        + '<path fill-rule="evenodd" clip-rule="evenodd" d="M753.12 1.23c-1.35 0-2.45 1.1-2.45 2.46v63.65'
        + 'c0 1.77-1.82 2.96-3.47 2.33-4.78-1.83-9.93-3.28-15.52-4.41-8.2-1.6-15.48-2.39-21.76-2.39'
        + '-27.01 0-47.54 7.98-61.47 23.94-13.81 15.9-20.72 37.87-20.72 65.85 0 34.92 8.08 59.53 24.29 73.77'
        + 'C668.18 240.54 688.71 247.6 713.62 247.6c12.27 0 24.17-1.47 35.76-4.48 11.72-3.01 21.46-7.79 29.23-14.24'
        + ' 8.01-6.69 12.08-14.97 12.08-24.73V3.69c0-1.36-1.1-2.46-2.45-2.46h-35.12z"/>'
        + '<path fill-rule="evenodd" clip-rule="evenodd" d="M43.59 1.26c1.35 0 2.45 1.1 2.45 2.45v31.98'
        + 'c0 1.35-1.1 2.45-2.45 2.45H5.54c-1.35 0-2.45-1.1-2.45-2.45V3.71c0-1.35 1.1-2.45 2.45-2.45h38.05z"/>'
        + '<path d="M899.73 62.72c27.29 0 47.43 8.82 60.31 26.58 12.13 16.78 18.36 39.86 18.66 69.19v3.8'
        + 'c0 1.35-1.1 2.45-2.45 2.45H861.51c-1.44 0-2.57 1.24-2.4 2.67 1.69 13.8 6.22 24.32 13.69 31.75'
        + ' 8.32 8.27 20.21 12.43 35.79 12.43 10.29 0 20.08-1.29 29.39-3.86 9.36-2.51 17.62-5.82 24.76-9.8'
        + 'l3.39-1.9 2.41-1.71c1.62-1.15 3.86.01 3.86 2v33.79c0 .94-.54 1.8-1.39 2.21l-4.87 2.33c-.01 0-.01.01-.01.02'
        + ' 0 .01-.01.02-.01.02l-1.34.61c-18.05 7.84-38.69 11.76-61.97 11.76-26.3 0-47.13-8.02-62.22-24'
        + '-15.09-15.98-22.61-37.9-22.61-67.67 0-29.76 7.09-52.66 21.38-68.64 14.29-15.98 34.5-24 60.37-24z'
        + 'M898.68 96.46c-11.58 0-20.45 2.94-26.79 8.88-5.61 5.21-9.55 13.78-11.77 25.78l-.42 2.59'
        + 'c0 .03.01.06.03.08.02.02.04.03.07.03h74.98c1.43 0 2.52-1.28 2.3-2.69-1.91-11.39-5.55-19.78-10.97-25.29'
        + '-6.16-6.25-15.21-9.37-27.41-9.37z"/>'
        + '</g></svg>';

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
