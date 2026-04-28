import { useState, useEffect, useRef } from 'react';
import './App.css';
import { startSession, submitEkyb, finishSession } from './services/incodeApi';

function getUrlParams() {
  const p = new URLSearchParams(window.location.search);
  return { token: p.get('token'), interviewId: p.get('interviewId') };
}

// ── Logo ──────────────────────────────────────────────────────
function IncodeLogo({ className }) {
  return (
    <svg className={className} viewBox="0 0 981 249" fill="currentColor" xmlns="http://www.w3.org/2000/svg" aria-label="Incode">
      <path fillRule="evenodd" clipRule="evenodd" d="M350.8 62.9273C350.8 62.9103 350.814 62.8965 350.831 62.8965C369.563 62.9002 387.371 66.3374 404.256 73.2691C405.111 73.6021 405.674 74.4265 405.674 75.3451V107.367C405.674 108.99 404.03 110.096 402.529 109.481C385.512 102.3 369.975 98.7399 355.916 98.7399C338.468 98.7399 325.644 103.036 317.258 111.567C308.874 120.037 304.62 133.785 304.62 152.75C304.62 172.698 308.811 189.066 317.013 197.965C325.152 206.865 338.468 211.345 357.028 211.345C372.194 211.345 387.423 207.663 402.838 200.359C404.325 199.647 406.044 200.733 406.044 202.383V234.405C406.044 235.312 405.513 236.136 404.687 236.509C388.04 243.935 370.222 247.619 351.17 247.619C327.679 247.619 307.887 241.174 291.794 228.285L289.391 226.321L287.603 224.664C272.188 210.24 264.542 185.832 264.542 155.512C264.542 123.106 272.68 99.5377 289.021 84.8078C305.289 70.2062 325.874 62.964 350.769 62.958C350.786 62.958 350.8 62.9443 350.8 62.9273Z"/>
      <path fillRule="evenodd" clipRule="evenodd" d="M43.5887 67.9668C44.9413 67.9668 46.0379 69.0649 46.0379 70.4194V240.005C46.0379 241.359 44.9413 242.457 43.5887 242.457H5.53611C4.18346 242.457 3.08691 241.359 3.08691 240.005V70.4194C3.08691 69.0649 4.18346 67.9668 5.53611 67.9668H43.5887Z"/>
      <path fillRule="evenodd" clipRule="evenodd" d="M162.518 63.1948C162.518 63.1778 162.532 63.1641 162.549 63.1641C186.949 63.1684 205.066 68.3241 216.96 78.6921C228.86 89.1874 234.779 105.329 234.779 127.056V239.989C234.779 241.344 233.683 242.442 232.33 242.442H196.843C195.491 242.442 194.394 241.344 194.394 239.989V131.843C194.394 109.319 181.94 98.3323 156.044 98.3323C145.254 98.3323 134.834 99.8669 124.784 102.936L122.763 103.606C121.761 103.939 121.085 104.877 121.085 105.934V240.051C121.085 241.405 119.988 242.503 118.635 242.503H83.1489C81.7962 242.503 80.6997 241.405 80.6997 240.051V83.1398C80.6997 82.2951 81.1774 81.5231 81.9329 81.1472C92.3527 75.8689 104.992 71.5113 119.852 68.1968L124.784 67.1535C137.844 64.5167 150.412 63.2278 162.487 63.2256C162.504 63.2256 162.518 63.2118 162.518 63.1948Z"/>
      <path fillRule="evenodd" clipRule="evenodd" d="M579.528 86.5725C565.161 70.7376 543.829 62.8203 515.712 62.8203C459.789 62.8203 431.489 93.7536 431.489 154.699C431.489 183.485 437.964 205.825 450.972 221.66L452.699 223.686C466.943 239.643 488.09 247.623 516.02 247.623C543.951 247.623 563.99 239.582 578.786 223.379C593.523 207.237 600.861 184.344 600.861 154.761C600.861 125.178 593.77 102.407 579.464 86.6338L579.528 86.5725ZM515.712 212.761C500.238 212.761 489.138 207.912 482.234 198.215C475.143 188.333 471.567 173.849 471.567 154.699C471.567 135.55 475.018 121.188 481.925 111.553C488.646 102.101 499.804 97.3133 515.776 97.3133C531.744 97.3133 542.78 101.978 549.81 111.245C556.961 120.697 560.598 135.182 560.598 154.699C560.598 193.796 545.739 212.761 515.712 212.761Z"/>
      <path fillRule="evenodd" clipRule="evenodd" d="M753.121 1.23438C751.768 1.23438 750.672 2.33245 750.672 3.687V67.3326C750.672 69.1018 748.855 70.2946 747.205 69.6635C742.424 67.8353 737.271 66.3865 731.681 65.2539C723.481 63.6582 716.204 62.8603 709.917 62.8603C682.91 62.8603 662.378 70.8392 648.445 86.7967C634.634 102.693 627.727 124.666 627.727 152.653C627.727 187.575 635.805 212.187 652.021 226.426C668.176 240.543 688.707 247.601 713.616 247.601C725.886 247.601 737.784 246.127 749.376 243.12C761.091 240.113 770.834 235.326 778.603 228.881C786.616 222.191 790.687 213.906 790.687 204.147V3.687C790.687 2.33245 789.59 1.23438 788.238 1.23438H753.121ZM750.64 200.679C750.652 200.668 750.672 200.676 750.672 200.693V201.357C750.672 201.376 750.67 201.394 750.667 201.412C750.157 204.04 747.259 206.364 741.424 208.443C734.517 210.837 725.947 212.064 715.712 212.064C698.139 212.064 686.177 206.97 679.334 196.843C672.305 186.471 668.79 171.986 668.79 153.328C668.79 116.134 684.019 97.9672 715.034 97.9672C721.198 97.9672 727.549 98.8264 734.086 100.484C739.08 101.772 743.765 103.429 748.081 105.578L749.312 106.235C750.11 106.662 750.608 107.494 750.608 108.399V200.666C750.608 200.682 750.628 200.691 750.64 200.679Z"/>
      <path fillRule="evenodd" clipRule="evenodd" d="M43.5887 1.25586C44.9413 1.25586 46.0379 2.35394 46.0379 3.70849V35.6899C46.0379 37.0445 44.9413 38.1425 43.5887 38.1425H5.53611C4.18346 38.1425 3.08691 37.0445 3.08691 35.6899V3.70848C3.08691 2.35394 4.18346 1.25586 5.53611 1.25586H43.5887Z"/>
      <path d="M899.725 62.7188C927.017 62.7189 947.158 71.5368 960.035 89.2949C972.17 106.074 978.392 129.162 978.701 158.494V162.291C978.701 163.643 977.605 164.738 976.254 164.738H861.509C860.068 164.739 858.937 165.98 859.112 167.41C860.804 181.213 865.334 191.728 872.805 199.155C881.123 207.422 893.011 211.587 908.596 211.587C918.886 211.587 928.679 210.299 937.982 207.727C947.345 205.216 955.599 201.91 962.747 197.929L966.133 196.032L968.544 194.318C970.165 193.168 972.409 194.326 972.409 196.314V230.1C972.409 231.042 971.867 231.901 971.018 232.308L966.145 234.64C966.138 234.644 966.134 234.65 966.133 234.657C966.133 234.665 966.128 234.673 966.121 234.676L964.778 235.283C946.729 243.122 926.092 247.041 902.806 247.041C876.502 247.041 855.68 239.019 840.587 223.036C825.496 207.053 817.978 185.131 817.978 155.371C817.978 125.61 825.063 102.706 839.356 86.7235C853.647 70.741 873.853 62.7188 899.725 62.7188ZM898.676 96.4593C887.097 96.4594 878.228 99.4002 871.883 105.339C866.276 110.545 862.333 119.118 860.113 131.12L859.69 133.705C859.685 133.735 859.696 133.765 859.716 133.787C859.734 133.804 859.759 133.815 859.783 133.815H934.759C936.191 133.815 937.283 132.534 937.057 131.12C935.149 119.73 931.511 111.341 926.091 105.829C919.929 99.5837 910.875 96.4593 898.676 96.4593Z"/>
    </svg>
  );
}

// ── Verified badge ────────────────────────────────────────────
function VerifiedBadge() {
  return (
    <div className="verified-badge">
      <svg width="15" height="15" viewBox="0 0 15 15" fill="none">
        <circle cx="7.5" cy="7.5" r="7.5" fill="#006aff"/>
        <path d="M4.5 7.5l2 2 4-4" stroke="white" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
      </svg>
      <span className="verified-text">verified by</span>
      <IncodeLogo className="verified-logo" />
    </div>
  );
}

// ── Flag image ────────────────────────────────────────────────
function FlagImg({ code, name, size = 'md' }) {
  const w = size === 'sm' ? 20 : 28;
  const h = size === 'sm' ? 15 : 21;
  return (
    <img
      src={`https://flagcdn.com/w40/${code.toLowerCase()}.png`}
      srcSet={`https://flagcdn.com/w80/${code.toLowerCase()}.png 2x`}
      width={w} height={h}
      alt={name}
      style={{ borderRadius: 2, display: 'block', objectFit: 'cover', flexShrink: 0 }}
    />
  );
}

// ── Countries ─────────────────────────────────────────────────
const EU_CODES = new Set(['GB', 'FR', 'DE', 'IT', 'ES']);

const COUNTRIES = [
  { code: 'AF', name: 'Afghanistan' },
  { code: 'AL', name: 'Albania' },
  { code: 'DZ', name: 'Algeria' },
  { code: 'AO', name: 'Angola' },
  { code: 'AI', name: 'Anguilla' },
  { code: 'AG', name: 'Antigua and Barbuda' },
  { code: 'AR', name: 'Argentina' },
  { code: 'AM', name: 'Armenia' },
  { code: 'AW', name: 'Aruba' },
  { code: 'AU', name: 'Australia' },
  { code: 'AT', name: 'Austria' },
  { code: 'AZ', name: 'Azerbaijan' },
  { code: 'BS', name: 'Bahamas' },
  { code: 'BH', name: 'Bahrain' },
  { code: 'BD', name: 'Bangladesh' },
  { code: 'BB', name: 'Barbados' },
  { code: 'BY', name: 'Belarus' },
  { code: 'BE', name: 'Belgium' },
  { code: 'BZ', name: 'Belize' },
  { code: 'BJ', name: 'Benin' },
  { code: 'BM', name: 'Bermuda' },
  { code: 'BT', name: 'Bhutan' },
  { code: 'BO', name: 'Bolivia' },
  { code: 'BQ', name: 'Bonaire' },
  { code: 'BA', name: 'Bosnia and Herzegovina' },
  { code: 'BW', name: 'Botswana' },
  { code: 'BR', name: 'Brazil' },
  { code: 'VG', name: 'British Virgin Islands' },
  { code: 'BN', name: 'Brunei' },
  { code: 'BG', name: 'Bulgaria' },
  { code: 'BF', name: 'Burkina Faso' },
  { code: 'BI', name: 'Burundi' },
  { code: 'KH', name: 'Cambodia' },
  { code: 'CM', name: 'Cameroon' },
  { code: 'CA', name: 'Canada' },
  { code: 'CV', name: 'Cape Verde' },
  { code: 'KY', name: 'Cayman Islands' },
  { code: 'CF', name: 'Central African Republic' },
  { code: 'TD', name: 'Chad' },
  { code: 'CL', name: 'Chile' },
  { code: 'CN', name: 'China' },
  { code: 'CO', name: 'Colombia' },
  { code: 'KM', name: 'Comoros' },
  { code: 'CG', name: 'Congo' },
  { code: 'CK', name: 'Cook Islands' },
  { code: 'CR', name: 'Costa Rica' },
  { code: 'HR', name: 'Croatia' },
  { code: 'CU', name: 'Cuba' },
  { code: 'CW', name: 'Curacao' },
  { code: 'CY', name: 'Cyprus' },
  { code: 'CZ', name: 'Czechia' },
  { code: 'DK', name: 'Denmark' },
  { code: 'DJ', name: 'Djibouti' },
  { code: 'DM', name: 'Dominica' },
  { code: 'DO', name: 'Dominican Republic' },
  { code: 'TL', name: 'East Timor' },
  { code: 'EC', name: 'Ecuador' },
  { code: 'EG', name: 'Egypt' },
  { code: 'SV', name: 'El Salvador' },
  { code: 'GQ', name: 'Equatorial Guinea' },
  { code: 'ER', name: 'Eritrea' },
  { code: 'EE', name: 'Estonia' },
  { code: 'ET', name: 'Ethiopia' },
  { code: 'FK', name: 'Falkland Islands' },
  { code: 'FJ', name: 'Fiji Islands' },
  { code: 'FI', name: 'Finland' },
  { code: 'FR', name: 'France' },
  { code: 'GP', name: 'France Guadeloupe / French Guiana' },
  { code: 'GA', name: 'Gabon' },
  { code: 'GM', name: 'Gambia' },
  { code: 'GE', name: 'Georgia' },
  { code: 'DE', name: 'Germany' },
  { code: 'GH', name: 'Ghana' },
  { code: 'GR', name: 'Greece' },
  { code: 'GD', name: 'Grenada' },
  { code: 'GT', name: 'Guatemala' },
  { code: 'GN', name: 'Guinea' },
  { code: 'GW', name: 'Guinea-Bissau' },
  { code: 'GY', name: 'Guyana' },
  { code: 'HT', name: 'Haiti' },
  { code: 'HN', name: 'Honduras' },
  { code: 'HK', name: 'Hong Kong' },
  { code: 'HU', name: 'Hungary' },
  { code: 'IS', name: 'Iceland' },
  { code: 'IN', name: 'India' },
  { code: 'ID', name: 'Indonesia' },
  { code: 'IR', name: 'Iran' },
  { code: 'IQ', name: 'Iraq' },
  { code: 'IE', name: 'Ireland' },
  { code: 'IL', name: 'Israel' },
  { code: 'IT', name: 'Italy' },
  { code: 'CI', name: 'Ivory Coast' },
  { code: 'JM', name: 'Jamaica' },
  { code: 'JP', name: 'Japan' },
  { code: 'JO', name: 'Jordan' },
  { code: 'KZ', name: 'Kazakhstan' },
  { code: 'KE', name: 'Kenya' },
  { code: 'KI', name: 'Kiribati' },
  { code: 'XK', name: 'Kosovo' },
  { code: 'KW', name: 'Kuwait' },
  { code: 'KG', name: 'Kyrgyzstan' },
  { code: 'LA', name: 'Laos' },
  { code: 'LV', name: 'Latvia' },
  { code: 'LB', name: 'Lebanon' },
  { code: 'LS', name: 'Lesotho' },
  { code: 'LR', name: 'Liberia' },
  { code: 'LY', name: 'Libya' },
  { code: 'LI', name: 'Liechtenstein' },
  { code: 'LT', name: 'Lithuania' },
  { code: 'LU', name: 'Luxembourg' },
  { code: 'MO', name: 'Macau S.A.R' },
  { code: 'MK', name: 'Macedonia' },
  { code: 'MG', name: 'Madagascar' },
  { code: 'MW', name: 'Malawi' },
  { code: 'MY', name: 'Malaysia' },
  { code: 'ML', name: 'Mali' },
  { code: 'MT', name: 'Malta' },
  { code: 'MH', name: 'Marshall Islands' },
  { code: 'MU', name: 'Mauritius' },
  { code: 'YT', name: 'Mayotte' },
  { code: 'MX', name: 'Mexico' },
  { code: 'FM', name: 'Micronesia' },
  { code: 'MD', name: 'Moldova' },
  { code: 'MN', name: 'Mongolia' },
  { code: 'ME', name: 'Montenegro' },
  { code: 'MS', name: 'Montserrat' },
  { code: 'MA', name: 'Morocco' },
  { code: 'MZ', name: 'Mozambique' },
  { code: 'MM', name: 'Myanmar' },
  { code: 'NA', name: 'Namibia' },
  { code: 'NP', name: 'Nepal' },
  { code: 'NC', name: 'New Caledonia' },
  { code: 'NZ', name: 'New Zealand' },
  { code: 'NI', name: 'Nicaragua' },
  { code: 'NE', name: 'Niger' },
  { code: 'NG', name: 'Nigeria' },
  { code: 'NO', name: 'Norway' },
  { code: 'OM', name: 'Oman' },
  { code: 'PK', name: 'Pakistan' },
  { code: 'PW', name: 'Palau' },
  { code: 'PS', name: 'Palestine' },
  { code: 'PA', name: 'Panama' },
  { code: 'PG', name: 'Papua New Guinea' },
  { code: 'PY', name: 'Paraguay' },
  { code: 'PE', name: 'Peru' },
  { code: 'PH', name: 'Philippines' },
  { code: 'PL', name: 'Poland' },
  { code: 'PT', name: 'Portugal' },
  { code: 'PR', name: 'Puerto Rico' },
  { code: 'QA', name: 'Qatar' },
  { code: 'RE', name: 'Reunion' },
  { code: 'RO', name: 'Romania' },
  { code: 'RU', name: 'Russia' },
  { code: 'RW', name: 'Rwanda' },
  { code: 'BL', name: 'Saint Barthelemy' },
  { code: 'SH', name: 'Saint Helena' },
  { code: 'KN', name: 'Saint Kitts & Nevis' },
  { code: 'LC', name: 'Saint Lucia' },
  { code: 'MF', name: 'Saint Martin' },
  { code: 'PM', name: 'Saint Pierre & Miquelon' },
  { code: 'VC', name: 'Saint Vincent & the Grenadines' },
  { code: 'WS', name: 'Samoa' },
  { code: 'ST', name: 'Sao Tome and Principe' },
  { code: 'SA', name: 'Saudi Arabia' },
  { code: 'SN', name: 'Senegal' },
  { code: 'RS', name: 'Serbia' },
  { code: 'SC', name: 'Seychelles' },
  { code: 'SL', name: 'Sierra Leone' },
  { code: 'SG', name: 'Singapore' },
  { code: 'SX', name: 'Sint Maarten' },
  { code: 'SK', name: 'Slovakia' },
  { code: 'SI', name: 'Slovenia' },
  { code: 'SB', name: 'Solomon Islands' },
  { code: 'SO', name: 'Somalia' },
  { code: 'ZA', name: 'South Africa' },
  { code: 'KR', name: 'South Korea' },
  { code: 'SS', name: 'South Sudan' },
  { code: 'ES', name: 'Spain' },
  { code: 'LK', name: 'Sri Lanka' },
  { code: 'SD', name: 'Sudan' },
  { code: 'SR', name: 'Suriname' },
  { code: 'SZ', name: 'Swaziland' },
  { code: 'SE', name: 'Sweden' },
  { code: 'CH', name: 'Switzerland' },
  { code: 'SY', name: 'Syria' },
  { code: 'TW', name: 'Taiwan' },
  { code: 'TJ', name: 'Tajikistan' },
  { code: 'TZ', name: 'Tanzania' },
  { code: 'TH', name: 'Thailand' },
  { code: 'TG', name: 'Togo' },
  { code: 'TO', name: 'Tonga' },
  { code: 'TT', name: 'Trinidad & Tobago' },
  { code: 'TN', name: 'Tunisia' },
  { code: 'TR', name: 'Turkey' },
  { code: 'TM', name: 'Turkmenistan' },
  { code: 'TC', name: 'Turks and Caicos Islands' },
  { code: 'UG', name: 'Uganda' },
  { code: 'UA', name: 'Ukraine' },
  { code: 'AE', name: 'United Arab Emirates' },
  { code: 'GB', name: 'United Kingdom' },
  { code: 'US', name: 'United States of America' },
  { code: 'UY', name: 'Uruguay' },
  { code: 'VI', name: 'US Virgin Islands' },
  { code: 'UZ', name: 'Uzbekistan' },
  { code: 'VU', name: 'Vanuatu' },
  { code: 'VE', name: 'Venezuela' },
  { code: 'VN', name: 'Vietnam' },
  { code: 'EH', name: 'Western Sahara' },
  { code: 'YE', name: 'Yemen' },
  { code: 'ZM', name: 'Zambia' },
  { code: 'ZW', name: 'Zimbabwe' },
];

const US_STATES = [
  ['AL','Alabama'],['AK','Alaska'],['AZ','Arizona'],['AR','Arkansas'],
  ['CA','California'],['CO','Colorado'],['CT','Connecticut'],['DE','Delaware'],
  ['FL','Florida'],['GA','Georgia'],['HI','Hawaii'],['ID','Idaho'],
  ['IL','Illinois'],['IN','Indiana'],['IA','Iowa'],['KS','Kansas'],
  ['KY','Kentucky'],['LA','Louisiana'],['ME','Maine'],['MD','Maryland'],
  ['MA','Massachusetts'],['MI','Michigan'],['MN','Minnesota'],['MS','Mississippi'],
  ['MO','Missouri'],['MT','Montana'],['NE','Nebraska'],['NV','Nevada'],
  ['NH','New Hampshire'],['NJ','New Jersey'],['NM','New Mexico'],['NY','New York'],
  ['NC','North Carolina'],['ND','North Dakota'],['OH','Ohio'],['OK','Oklahoma'],
  ['OR','Oregon'],['PA','Pennsylvania'],['RI','Rhode Island'],['SC','South Carolina'],
  ['SD','South Dakota'],['TN','Tennessee'],['TX','Texas'],['UT','Utah'],
  ['VT','Vermont'],['VA','Virginia'],['WA','Washington'],['WV','West Virginia'],
  ['WI','Wisconsin'],['WY','Wyoming'],
];

// ── Tax ID validation ─────────────────────────────────────────
function getTaxIdHint(countryCode) {
  switch (countryCode) {
    case 'US': return 'EIN: 9 digits, e.g. 123456789';
    case 'GB': return 'Registration No. (7–8 digits) or VAT No. (9 digits)';
    case 'FR': return 'SIREN, SIRET, RCS, RC, or VAT number';
    case 'ES': return 'CIF: A12345678 · NIF: 12345678A · Foreign: A1234567B';
    case 'IT': return 'CCIAA: AA123456 · Company ID: IT12345678 · VAT: 11 digits';
    case 'DE': return 'VAT: DE123456789 · SafeNo: DE12345678 · Reg: HRB1234';
    default: return null;
  }
}

function validateTaxId(value, countryCode) {
  const v = value.trim().toUpperCase();
  if (!v) return null;

  switch (countryCode) {
    case 'US': {
      const digits = v.replace(/\D/g, '');
      if (digits.length !== 9) return 'EIN must be exactly 9 digits';
      return null;
    }
    case 'GB': {
      const digits = v.replace(/\D/g, '');
      if (digits.length < 7 || digits.length > 9)
        return 'Enter a valid Registration No. (7–8 digits) or VAT No. (9 digits)';
      return null;
    }
    case 'FR': {
      if (v.length < 2) return 'Please enter a valid Tax ID';
      return null;
    }
    case 'ES': {
      const p1 = /^[A-Z]\d{8}$/;
      const p2 = /^[A-Z]\d{7}[A-Z]$/;
      const p3 = /^\d{8}[A-Z]$/;
      if (!p1.test(v) && !p2.test(v) && !p3.test(v))
        return 'Expected: A12345678 (CIF), 12345678A (NIF), or A1234567B (foreign NIF)';
      return null;
    }
    case 'IT': {
      const p1 = /^[A-Z]{2}-?\d{6,7}$/;
      const p2 = /^IT\d{8}$/;
      const p3 = /^\d{11}$/;
      if (!p1.test(v) && !p2.test(v) && !p3.test(v))
        return 'Expected: AA123456 (CCIAA), IT12345678 (company ID), or 11-digit code';
      return null;
    }
    case 'DE': {
      const vat  = /^DE\d{9}$/;
      const safe = /^DE\d{8}$/;
      const hrb  = /^HRB\s*\d{3,6}[A-Z]?$/;
      const hra  = /^HRA\s*\d{4,6}$/;
      const plain = /^\d{4,6}$/;
      if (!vat.test(v) && !safe.test(v) && !hrb.test(v) && !hra.test(v) && !plain.test(v))
        return 'Expected: DE123456789, HRB1234, HRA12345, or 4–6 digit registration number';
      return null;
    }
    default:
      return null;
  }
}

// ── Country dropdown ──────────────────────────────────────────
function CountryDropdown({ value, onChange }) {
  const [open, setOpen] = useState(false);
  const [search, setSearch] = useState('');
  const ref = useRef(null);
  const searchRef = useRef(null);

  useEffect(() => {
    const handler = (e) => {
      if (ref.current && !ref.current.contains(e.target)) {
        setOpen(false);
        setSearch('');
      }
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, []);

  useEffect(() => {
    if (open && searchRef.current) searchRef.current.focus();
  }, [open]);

  const filtered = COUNTRIES.filter(c =>
    c.name.toLowerCase().includes(search.toLowerCase()) ||
    c.code.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className={`country-dropdown${open ? ' open' : ''}`} ref={ref}>
      <button type="button" className="dropdown-trigger" onClick={() => setOpen(o => !o)}>
        <div className="dropdown-value">
          {value ? (
            <>
              <FlagImg code={value.code} name={value.name} size="sm" />
              <span>{value.name}</span>
            </>
          ) : (
            <span className="dropdown-placeholder">Select country…</span>
          )}
        </div>
        <svg className={`dropdown-chevron${open ? ' flipped' : ''}`} width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <polyline points="6 9 12 15 18 9"/>
        </svg>
      </button>

      {open && (
        <div className="dropdown-panel">
          <div className="dropdown-search-row">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
            </svg>
            <input
              ref={searchRef}
              type="text"
              placeholder="Search countries…"
              value={search}
              onChange={e => setSearch(e.target.value)}
            />
          </div>
          <div className="dropdown-list">
            {filtered.length > 0 ? filtered.map(c => (
              <button key={c.code} type="button"
                className={`dropdown-item${value?.code === c.code ? ' selected' : ''}`}
                onClick={() => { onChange(c); setOpen(false); setSearch(''); }}>
                <FlagImg code={c.code} name={c.name} size="sm" />
                <span>{c.name}</span>
                {value?.code === c.code && (
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#006aff" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" style={{ marginLeft: 'auto' }}>
                    <polyline points="20 6 9 17 4 12"/>
                  </svg>
                )}
              </button>
            )) : (
              <div className="dropdown-empty">No countries found for "{search}"</div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

// ── Person section ────────────────────────────────────────────
function PersonSection({ title, description, nameLabel, surnameLabel, addLabel, people, onChange }) {
  const update = (i, field, val) => onChange(people.map((p, idx) => idx === i ? { ...p, [field]: val } : p));
  const add = () => onChange([...people, { firstName: '', lastName: '' }]);
  const remove = (i) => onChange(people.filter((_, idx) => idx !== i));

  return (
    <div className="person-section">
      <h3 className="person-section-title">{title}</h3>
      <p className="person-section-desc">{description}</p>
      <div className="person-rows">
        {people.map((p, i) => (
          <div className="person-row" key={i}>
            <div className="field">
              <label>{nameLabel}</label>
              <input type="text" placeholder="Name"
                value={p.firstName} onChange={e => update(i, 'firstName', e.target.value)} />
            </div>
            <div className="field">
              <label>{surnameLabel}</label>
              <input type="text" placeholder="Surname"
                value={p.lastName} onChange={e => update(i, 'lastName', e.target.value)} />
            </div>
            {i > 0 && (
              <button type="button" className="btn-remove-inline" onClick={() => remove(i)} title="Remove">×</button>
            )}
          </div>
        ))}
      </div>
      <button type="button" className="btn-add-link" onClick={add}>
        + {addLabel}
      </button>
    </div>
  );
}

// ── App ───────────────────────────────────────────────────────
export default function App() {
  const { token: presetToken } = getUrlParams();

  const [step, setStep] = useState(1);
  const [country, setCountry] = useState(null);
  const [form, setForm] = useState({
    businessName: '', taxId: '', street: '', houseNo: '',
    addressLine2: '', city: '', state: '', postalCode: '',
  });
  const [ubos, setUbos] = useState([{ firstName: '', lastName: '' }]);
  const [directors, setDirectors] = useState([{ firstName: '', lastName: '' }]);
  const [loading, setLoading] = useState(false);
  const [submitError, setSubmitError] = useState(null);
  const [fieldErrors, setFieldErrors] = useState({});

  const updateForm = (field, value) => {
    setForm(prev => ({ ...prev, [field]: value }));
    if (fieldErrors[field]) setFieldErrors(prev => ({ ...prev, [field]: null }));
  };

  const handleTaxIdChange = (value) => {
    let processed = value;
    if (country?.code === 'US') {
      processed = value.replace(/\D/g, '').slice(0, 9);
    }
    updateForm('taxId', processed);
  };

  const handleTaxIdBlur = () => {
    if (form.taxId) {
      const err = validateTaxId(form.taxId, country?.code);
      if (err) setFieldErrors(prev => ({ ...prev, taxId: err }));
    }
  };

  const handleCountrySelect = (c) => {
    setCountry({ ...c, isEU: EU_CODES.has(c.code) });
    setForm(prev => ({ ...prev, taxId: '', state: '' }));
    setFieldErrors({});
  };

  const validateStep2 = () => {
    const errors = {};
    if (!form.businessName.trim()) errors.businessName = 'Required';
    if (!form.taxId.trim()) {
      errors.taxId = 'Required';
    } else {
      const taxErr = validateTaxId(form.taxId, country?.code);
      if (taxErr) errors.taxId = taxErr;
    }
    if (!form.city.trim()) errors.city = 'Required';
    if (!form.postalCode.trim()) errors.postalCode = 'Required';
    if (country?.code === 'US' && !form.state) errors.state = 'Required';
    setFieldErrors(errors);
    return Object.keys(errors).length === 0;
  };

  const handleSubmit = async () => {
    setSubmitError(null);
    setLoading(true);
    setStep(4);

    try {
      const token = presetToken || (await startSession()).token;

      const uboNames = ubos
        .filter(p => p.firstName.trim() || p.lastName.trim())
        .map(p => `${p.firstName} ${p.lastName}`.trim());

      const payload = {
        businessName:  form.businessName.trim(),
        taxId:         form.taxId.trim(),
        street:        form.street.trim(),
        houseNo:       form.houseNo.trim(),
        addressLine2:  form.addressLine2.trim(),
        city:          form.city.trim(),
        postalCode:    form.postalCode.trim(),
        country:       country.code,
        uboNames,
      };

      if (form.state.trim()) payload.state = form.state.trim();

      if (country.isEU) {
        payload.directors = directors
          .filter(p => p.firstName.trim() || p.lastName.trim())
          .map(p => `${p.firstName} ${p.lastName}`.trim());
      }

      await Promise.all([submitEkyb(token, payload), finishSession(token)]);
    } catch (err) {
      setSubmitError(err.message || 'An unexpected error occurred. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleRestart = () => {
    setStep(1);
    setCountry(null);
    setForm({ businessName: '', taxId: '', street: '', houseNo: '', addressLine2: '', city: '', state: '', postalCode: '' });
    setUbos([{ firstName: '', lastName: '' }]);
    setDirectors([{ firstName: '', lastName: '' }]);
    setSubmitError(null);
    setFieldErrors({});
  };

  const taxIdHint = country ? getTaxIdHint(country.code) : null;

  return (
    <div className="app">
      <div className="card">

        {/* ── Logo ── */}
        <div className="card-logo">
          <IncodeLogo className="logo-svg" />
        </div>

        {/* ── Content ── */}
        <div className="card-body">

          {/* STEP 1 — Country */}
          {step === 1 && (
            <div className="step-content" key="step1">
              <h2 className="step-title">Where is your business registered?</h2>
              <p className="step-subtitle">Select the country where your business is registered.</p>
              <div className="field">
                <label className="field-label">Country</label>
                <CountryDropdown value={country} onChange={handleCountrySelect} />
              </div>
              <div className="btn-actions single">
                <button type="button" className="btn-primary"
                  disabled={!country}
                  onClick={() => setStep(2)}>
                  Continue
                </button>
              </div>
            </div>
          )}

          {/* STEP 2 — Business details */}
          {step === 2 && (
            <div className="step-content" key="step2">
              <h2 className="step-title">Business details</h2>
              <div className="form-stack">
                <div className="field">
                  <label className="field-label">Business name</label>
                  <input type="text" placeholder="e.g. Acme Corporation Ltd"
                    value={form.businessName}
                    onChange={e => updateForm('businessName', e.target.value)}
                    className={fieldErrors.businessName ? 'error' : ''} />
                  {fieldErrors.businessName && <span className="field-error">{fieldErrors.businessName}</span>}
                </div>

                <div className="field">
                  <label className="field-label">Tax ID</label>
                  <input type="text"
                    placeholder={country?.code === 'US' ? '123456789' : 'Enter Tax ID'}
                    value={form.taxId}
                    onChange={e => handleTaxIdChange(e.target.value)}
                    onBlur={handleTaxIdBlur}
                    className={fieldErrors.taxId ? 'error' : ''}
                    inputMode={country?.code === 'US' ? 'numeric' : 'text'} />
                  {taxIdHint && !fieldErrors.taxId && (
                    <span className="field-hint">{taxIdHint}</span>
                  )}
                  {fieldErrors.taxId && <span className="field-error">{fieldErrors.taxId}</span>}
                </div>

                <div className="field">
                  <label className="field-label">Street</label>
                  <input type="text" placeholder="e.g. Mission St"
                    value={form.street}
                    onChange={e => updateForm('street', e.target.value)} />
                </div>

                <div className="form-row">
                  <div className="field">
                    <label className="field-label">House number</label>
                    <input type="text" placeholder="e.g. 101"
                      value={form.houseNo}
                      onChange={e => updateForm('houseNo', e.target.value)} />
                  </div>
                  <div className="field">
                    <label className="field-label">Address line 2 <span className="optional">(Optional)</span></label>
                    <input type="text" placeholder="Floor, Suite, Unit…"
                      value={form.addressLine2}
                      onChange={e => updateForm('addressLine2', e.target.value)} />
                  </div>
                </div>

                <div className="form-row">
                  <div className="field">
                    <label className="field-label">City</label>
                    <input type="text" placeholder="e.g. San Francisco"
                      value={form.city}
                      onChange={e => updateForm('city', e.target.value)}
                      className={fieldErrors.city ? 'error' : ''} />
                    {fieldErrors.city && <span className="field-error">{fieldErrors.city}</span>}
                  </div>
                  {country?.code === 'US' && (
                    <div className="field">
                      <label className="field-label">State</label>
                      <select value={form.state}
                        onChange={e => updateForm('state', e.target.value)}
                        className={fieldErrors.state ? 'error' : ''}>
                        <option value="">Select state…</option>
                        {US_STATES.map(([code, name]) => (
                          <option key={code} value={code}>{name}</option>
                        ))}
                      </select>
                      {fieldErrors.state && <span className="field-error">{fieldErrors.state}</span>}
                    </div>
                  )}
                </div>

                <div className="field half">
                  <label className="field-label">Postal code</label>
                  <input type="text"
                    placeholder={country?.code === 'US' ? '94105' : 'e.g. W1F 0DQ'}
                    value={form.postalCode}
                    onChange={e => updateForm('postalCode', e.target.value)}
                    className={fieldErrors.postalCode ? 'error' : ''} />
                  {fieldErrors.postalCode && <span className="field-error">{fieldErrors.postalCode}</span>}
                </div>
              </div>

              <div className="btn-actions">
                <button type="button" className="btn-back" onClick={() => setStep(1)}>Back</button>
                <button type="button" className="btn-primary"
                  onClick={() => { if (validateStep2()) setStep(3); }}>
                  Continue
                </button>
              </div>
            </div>
          )}

          {/* STEP 3 — People */}
          {step === 3 && (
            <div className="step-content" key="step3">
              <PersonSection
                title="Unique Beneficial Owner"
                description="Provide the names of beneficial owners associated to the business"
                nameLabel="UBO (Unique Beneficial Owner) name"
                surnameLabel="UBO surname"
                addLabel="Add another UBO (Optional)"
                people={ubos}
                onChange={setUbos}
              />

              {country?.isEU && (
                <PersonSection
                  title="Director"
                  description="Enter the name of the person legally responsible for managing the business."
                  nameLabel="Director name"
                  surnameLabel="Director surname"
                  addLabel="Add another director (Optional)"
                  people={directors}
                  onChange={setDirectors}
                />
              )}

              <div className="btn-actions">
                <button type="button" className="btn-back" onClick={() => setStep(2)}>Back</button>
                <button type="button" className="btn-primary" onClick={handleSubmit}>
                  Submit
                </button>
              </div>
            </div>
          )}

          {/* STEP 4 — Processing / Success / Error */}
          {step === 4 && (
            <div className="step-content center" key="step4">
              {loading ? (
                <>
                  <div className="spinner" />
                  <p className="status-label">Processing…</p>
                </>
              ) : submitError ? (
                <>
                  <div className="status-icon-circle error">
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
                      <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
                    </svg>
                  </div>
                  <p className="status-label">Submission failed</p>
                  <p className="status-sub">{submitError}</p>
                  <div className="btn-actions" style={{ justifyContent: 'center', marginTop: 24 }}>
                    <button type="button" className="btn-back" onClick={() => setStep(3)}>Go Back</button>
                    <button type="button" className="btn-primary" onClick={handleSubmit}>Try Again</button>
                  </div>
                </>
              ) : (
                <>
                  <div className="status-icon-circle success">
                    <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                      <polyline points="20 6 9 17 4 12"/>
                    </svg>
                  </div>
                  <p className="status-label">eKYB verified!</p>
                </>
              )}
            </div>
          )}

        </div>

        {/* ── Footer ── */}
        <div className="card-footer">
          <VerifiedBadge />
        </div>

      </div>
    </div>
  );
}
