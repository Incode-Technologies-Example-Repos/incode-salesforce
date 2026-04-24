import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import startSession          from '@salesforce/apex/IncodeService.startSession';
import getVerifications      from '@salesforce/apex/IncodeService.getVerifications';
import pollAndUpdateStatus   from '@salesforce/apex/IncodeService.pollAndUpdateStatus';
import fetchSessionDetails   from '@salesforce/apex/IncodeService.fetchSessionDetails';
import sendVerificationEmail from '@salesforce/apex/IncodeEmailService.sendVerificationEmail';

import CONTACT_EMAIL_FIELD      from '@salesforce/schema/Contact.Email';
import CONTACT_FIRSTNAME_FIELD  from '@salesforce/schema/Contact.FirstName';
import LEAD_EMAIL_FIELD         from '@salesforce/schema/Lead.Email';
import LEAD_FIRSTNAME_FIELD     from '@salesforce/schema/Lead.FirstName';
import ACCOUNT_NAME_FIELD       from '@salesforce/schema/Account.Name';

const CONTACT_FIELDS = [CONTACT_EMAIL_FIELD, CONTACT_FIRSTNAME_FIELD];
const LEAD_FIELDS    = [LEAD_EMAIL_FIELD, LEAD_FIRSTNAME_FIELD];
const ACCOUNT_FIELDS = [ACCOUNT_NAME_FIELD];

const POLL_INTERVAL_MS = 10000;
const FINAL_STATUSES   = new Set(['Approved', 'Declined', 'Error']);

export default class IncodeVerification extends LightningElement {
    @api recordId;
    @api objectApiName;

    @track recipientEmail  = '';
    @track errorMessage    = '';
    @track emailSent       = false;
    @track isLoading       = false;
    @track verifications   = [];
    @track isPolling       = false;

    // Modal state
    @track showModal        = false;
    @track modalLoading     = false;
    @track modalError       = '';
    @track _modalDetails    = null; // interviews[0] from the API response
    @track _selectedRow     = null;

    _cachedFirstName = '';
    _pollTimer       = null;

    // -------------------------------------------------------------------------
    // Lifecycle
    // -------------------------------------------------------------------------

    connectedCallback() {
        this._loadVerifications();
    }

    disconnectedCallback() {
        this._stopPolling();
    }

    // -------------------------------------------------------------------------
    // Wire: pre-populate email + first name from the parent record
    // -------------------------------------------------------------------------

    @wire(getRecord, { recordId: '$recordId', fields: '$_fieldsForObjectType' })
    wiredRecord({ error, data }) {
        if (data) {
            this.recipientEmail   = this._extractEmail(data) || '';
            this._cachedFirstName = this._extractFirstName(data) || '';
        }
        if (error) console.error('incodeVerification: getRecord error', error);
    }

    get _fieldsForObjectType() {
        if (this.objectApiName === 'Contact') return CONTACT_FIELDS;
        if (this.objectApiName === 'Lead')    return LEAD_FIELDS;
        return ACCOUNT_FIELDS;
    }

    _extractEmail(data) {
        if (this.objectApiName === 'Contact') return getFieldValue(data, CONTACT_EMAIL_FIELD);
        if (this.objectApiName === 'Lead')    return getFieldValue(data, LEAD_EMAIL_FIELD);
        return '';
    }

    _extractFirstName(data) {
        if (this.objectApiName === 'Contact') return getFieldValue(data, CONTACT_FIRSTNAME_FIELD) || '';
        if (this.objectApiName === 'Lead')    return getFieldValue(data, LEAD_FIRSTNAME_FIELD) || '';
        return '';
    }

    // -------------------------------------------------------------------------
    // Computed properties — history list
    // -------------------------------------------------------------------------

    get isButtonDisabled() {
        return this.isLoading || !this.recipientEmail;
    }

    get hasVerifications() {
        return this.verifications && this.verifications.length > 0;
    }

    get latestVerification() {
        return this.hasVerifications ? this.verifications[0] : null;
    }

    get verificationRows() {
        return this.verifications.map((v, idx) => ({
            ...v,
            rowKey:      v.Id,
            isLatest:    idx === 0,
            isClickable: FINAL_STATUSES.has(v.Status__c),
            badgeClass:  this._badgeClass(v.Status__c),
            badgeStyle:  this._badgeStyle(v.Status__c)
        }));
    }

    _badgeClass(status) {
        if (status === 'Approved')                       return 'badge-success';
        if (status === 'Declined' || status === 'Error') return 'badge-error';
        return 'badge-pending';
    }

    _badgeStyle(status) {
        const base = 'display:inline-block;padding:3px 12px;border-radius:12px;font-size:12px;font-weight:700;letter-spacing:0.3px;text-transform:uppercase;color:#ffffff;';
        if (status === 'Approved')  return base + 'background-color:#2e844a;';
        if (status === 'Declined')  return base + 'background-color:#ba0517;';
        if (status === 'Error')     return base + 'background-color:#ba0517;';
        return base + 'background-color:#dd7a01;';
    }

    // -------------------------------------------------------------------------
    // Computed properties — modal header
    // -------------------------------------------------------------------------

    get modalTitle() {
        if (!this._selectedRow) return 'Session Details';
        return 'Session: ' + (this._selectedRow.Session_ID__c || '');
    }

    get modalStatusStyle() {
        if (!this._selectedRow) return '';
        return this._badgeStyle(this._selectedRow.Status__c);
    }

    get modalStatusLabel() {
        return this._selectedRow ? this._selectedRow.Status__c : '';
    }

    get modalRawEvent() {
        return this._selectedRow ? this._selectedRow.Raw_Event_Type__c : '';
    }

    // -------------------------------------------------------------------------
    // Computed properties — Customer Input (businessVerificationRequest)
    // -------------------------------------------------------------------------

    get _bvr() {
        return this._modalDetails && this._modalDetails.businessVerificationRequest;
    }

    get bvrBusinessName() {
        return (this._bvr && this._bvr.businessName) || '—';
    }

    get bvrTaxId() {
        return (this._bvr && this._bvr.taxId) || '—';
    }

    get bvrAddress() {
        const r = this._bvr;
        if (!r) return '—';
        const street = [r.houseNo, r.street].filter(p => p).join(' ');
        const parts  = [street, r.addressLine2, r.city, r.state, r.postalCode, r.country].filter(p => p);
        return parts.length ? parts.join(', ') : '—';
    }

    get bvrRegistrationNumber() {
        return (this._bvr && (this._bvr.registrationNumber || this._bvr.businessRegistrationNumber)) || '—';
    }

    get bvrPhone() {
        return (this._bvr && this._bvr.phone) || '—';
    }

    get bvrWebsite() {
        return (this._bvr && this._bvr.website) || '—';
    }

    get bvrUboNames() {
        const names = (this._bvr && this._bvr.uboNames) || [];
        return names.length ? names.join(', ') : null;
    }

    get bvrDirectors() {
        const names = (this._bvr && this._bvr.directors) || [];
        return names.length ? names.join(', ') : null;
    }

    // -------------------------------------------------------------------------
    // Computed properties — eKYB Output (businessVerification)
    // -------------------------------------------------------------------------

    get _bv() {
        return this._modalDetails && this._modalDetails.businessVerification;
    }

    // Overall status lives at the interview root level as totalScoreStatus (OK/FAIL)
    get bvOverallStatus() {
        if (!this._modalDetails) return null;
        return this._modalDetails.totalScoreStatus || null;
    }

    get bvOverallStatusStyle() {
        const s = this.bvOverallStatus;
        if (!s) return '';
        if (s === 'OK')   return 'display:inline-block;padding:2px 10px;border-radius:10px;font-size:12px;font-weight:700;text-transform:uppercase;color:#fff;background-color:#2e844a;';
        if (s === 'FAIL') return 'display:inline-block;padding:2px 10px;border-radius:10px;font-size:12px;font-weight:700;text-transform:uppercase;color:#fff;background-color:#ba0517;';
        return 'display:inline-block;padding:2px 10px;border-radius:10px;font-size:12px;font-weight:700;text-transform:uppercase;color:#fff;background-color:#dd7a01;';
    }

    get bvEntityType() {
        const bv = this._bv;
        if (!bv) return '—';
        const et = bv.entityType;
        if (!et) return '—';
        if (typeof et === 'object') return et.entityType || '—';
        return String(et);
    }

    get bvVerifiedBusinessName() {
        return (this._bv && this._bv.businessName) || null;
    }

    get bvRegistrationStatus() {
        return (this._bv && this._bv.registrationStatus) || null;
    }

    // Verification result rows — string fields on businessVerification
    get verificationBadges() {
        const bv = this._bv;
        if (!bv) return [];
        const fields = [
            { key: 'businessName',          label: 'Verified Business Name'  },
            { key: 'tinVerification',       label: 'TIN Verification'        },
            { key: 'registrationStatus',    label: 'Registration Status'     },
            { key: 'addressVerification',   label: 'Address Verification'    },
            { key: 'cityVerification',      label: 'City Verification'       },
            { key: 'postalCodeVerification',label: 'Postal Code Verification' },
            { key: 'addressDeliverability', label: 'Address Deliverability'  },
            { key: 'addressPropertyType',   label: 'Property Type'           },
        ];
        return fields
            .filter(f => bv[f.key] != null && bv[f.key] !== '')
            .map(f => ({
                key:        f.key,
                label:      f.label,
                value:      String(bv[f.key]),
                badgeClass: this._stringVerificationStyle(String(bv[f.key]))
            }));
    }

    // Verification messages — API returns an object like {tinVerificationMessage: "..."}
    get verificationMessages() {
        const bv = this._bv;
        if (!bv || !bv.verificationMessages) return [];
        const msgs = bv.verificationMessages;
        if (Array.isArray(msgs)) {
            return msgs.map((m, i) => ({ key: i, message: typeof m === 'string' ? m : JSON.stringify(m) }));
        }
        // object form: {tinVerificationMessage: "...", ...}
        return Object.keys(msgs)
            .filter(k => msgs[k])
            .map((k, i) => ({ key: i, label: this._camelToLabel(k), message: String(msgs[k]) }));
    }

    get hasVerificationMessages() {
        return this.verificationMessages.length > 0;
    }

    // Applied rule (why session passed/failed)
    get appliedRule() {
        return (this._modalDetails && this._modalDetails.appliedTotalRule) || null;
    }

    get appliedRuleStyle() {
        const rule = this.appliedRule;
        if (!rule) return '';
        return rule.status === 'FAIL'
            ? 'color:#ba0517;font-weight:700;'
            : 'color:#2e844a;font-weight:700;';
    }

    // People / UBOs — EU (uboNameVerificationResults / directorsVerificationResults)
    //               or US (businessVerification.people with titles)
    get beneficialOwners() {
        if (!this._modalDetails) return [];

        const bavH       = this._modalDetails.bavHolders;
        const uboResults = (this._bv && this._bv.uboNameVerificationResults) || [];
        const dirResults = (this._bv && this._bv.directorsVerificationResults) || [];
        const isEuMode   = uboResults.length > 0 || dirResults.length > 0;

        // bavHolders takes highest priority
        if (bavH && bavH.length > 0) {
            return this._mapUsPersonList(bavH);
        }

        // EU mode — no titles, per-person match result, role = UBO | Director
        if (isEuMode) {
            const merged = [
                ...uboResults.map(r => ({ name: r.name, role: 'UBO',      rawMatch: r.uboNameMatch })),
                ...dirResults.map(r => ({ name: r.name, role: 'Director', rawMatch: r.uboNameMatch }))
            ];
            return merged.map((p, i) => {
                const status = this._matchStatus(p.rawMatch);
                return {
                    key:          i,
                    name:         p.name || '—',
                    titleList:    [{ key: i + '_0', label: p.role }],
                    titleCount:   1,
                    titlePreview: p.role,
                    hasTitles:    true,
                    ...this._statusDot(status, p.rawMatch)
                };
            });
        }

        // US mode — people array with titles
        const people = (this._bv && this._bv.people) || [];
        if (people.length > 0) {
            return this._mapUsPersonList(people);
        }

        return [];
    }

    _mapUsPersonList(list) {
        const submittedNames = ((this._bvr && this._bvr.uboNames) || [])
            .map(n => String(n).toUpperCase().trim());
        const uboMatchVerified =
            String((this._bv && this._bv.uboNameMatch) || '').toUpperCase() === 'VERIFIED';

        return list.map((p, i) => {
            const seen = new Set();
            const uniqueTitles = (p.titles || [])
                .map(t => t.title || t)
                .filter(t => {
                    const k = String(t).toUpperCase();
                    if (seen.has(k)) return false;
                    seen.add(k);
                    return true;
                });
            const titleArr   = uniqueTitles.length ? uniqueTitles : (p.role ? [p.role] : []);
            const personName = p.name || [p.firstName, p.lastName].filter(x => x).join(' ') || '—';
            const isVerifiedUbo = uboMatchVerified &&
                submittedNames.includes(personName.toUpperCase().trim());
            return {
                key:          i,
                name:         personName,
                titleList:    titleArr.map((t, j) => ({ key: i + '_' + j, label: String(t) })),
                titleCount:   titleArr.length,
                titlePreview: titleArr.join(', ') || '—',
                hasTitles:    titleArr.length > 0,
                ...this._statusDot(isVerifiedUbo ? 'verified' : null, isVerifiedUbo ? 'Verified' : null)
            };
        });
    }

    _matchStatus(rawMatch) {
        if (!rawMatch) return null;
        const v = String(rawMatch).toUpperCase().trim();
        if (v === 'VERIFIED' || v === 'EXACT MATCH') return 'verified';
        if (v.includes('APPROXIMATE') || v.includes('SIMILAR')) return 'approximate';
        return 'unverified';
    }

    _statusDot(status, label) {
        if (!status) return { hasStatusDot: false, statusDotClass: '', statusDotChar: '', statusDotLabel: '' };
        const char = status === 'verified' ? '✓' : (status === 'approximate' ? '~' : '!');
        return {
            hasStatusDot:   true,
            statusDotClass: 'ubo-status-dot ubo-status-dot_' + status,
            statusDotChar:  char,
            statusDotLabel: label || ''
        };
    }

    get hasBeneficialOwners() {
        return this.beneficialOwners.length > 0;
    }

    get beneficialOwnersCount() {
        return this.beneficialOwners.length;
    }

    // -------------------------------------------------------------------------
    // Event handlers
    // -------------------------------------------------------------------------

    handleEmailChange(event) {
        this.recipientEmail = event.target.value;
        this.errorMessage   = '';
    }

    async handleRequestVerification() {
        if (!this.recipientEmail) {
            this.errorMessage = 'Please enter an email address.';
            return;
        }

        this.isLoading    = true;
        this.errorMessage = '';
        this.emailSent    = false;

        try {
            const result = await startSession({
                recordId:   this.recordId,
                email:      this.recipientEmail,
                objectType: this.objectApiName
            });

            await sendVerificationEmail({
                toAddress:       this.recipientEmail,
                firstName:       this._cachedFirstName,
                verificationUrl: result.verificationUrl,
                targetObjectId:  this.recordId
            });

            this.emailSent = true;

            this.dispatchEvent(new ShowToastEvent({
                title:   'Business Verification Requested',
                message: 'Business verification email sent to ' + this.recipientEmail,
                variant: 'success'
            }));

            await this._loadVerifications();

        } catch (error) {
            const msg = error?.body?.message || error?.message || 'An unexpected error occurred.';
            this.errorMessage = msg;
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error', message: msg, variant: 'error', mode: 'sticky'
            }));
        } finally {
            this.isLoading = false;
        }
    }

    handleReset() {
        this.emailSent    = false;
        this.errorMessage = '';
    }

    async handleRowClick(event) {
        const verificationId = event.currentTarget.dataset.id;
        const row = this.verifications.find(v => v.Id === verificationId);
        if (!row || !FINAL_STATUSES.has(row.Status__c)) return;

        this._selectedRow  = row;
        this._modalDetails = null;
        this.modalError    = '';
        this.modalLoading  = true;
        this.showModal     = true;

        try {
            const json = await fetchSessionDetails({ verificationId });
            const parsed = json ? JSON.parse(json) : null;
            // API wraps the session inside interviews[]
            this._modalDetails = (parsed && parsed.interviews && parsed.interviews[0])
                ? parsed.interviews[0]
                : parsed;
        } catch (e) {
            this.modalError = e?.body?.message || e?.message || 'Could not load session details.';
        } finally {
            this.modalLoading = false;
        }
    }

    handleModalClose() {
        this.showModal     = false;
        this._selectedRow  = null;
        this._modalDetails = null;
        this.modalError    = '';
    }

    // -------------------------------------------------------------------------
    // Data loading + polling
    // -------------------------------------------------------------------------

    async _loadVerifications() {
        try {
            const records = await getVerifications({ recordId: this.recordId });
            this.verifications = records || [];

            const hasPending = this.verifications.some(v => !FINAL_STATUSES.has(v.Status__c));
            if (hasPending) {
                this._startPolling();
            } else {
                this._stopPolling();
            }
        } catch (e) {
            console.error('incodeVerification: _loadVerifications error', e);
        }
    }

    _startPolling() {
        if (this._pollTimer) return;
        this.isPolling  = true;
        this._pollTimer = setInterval(() => this._pollStatus(), POLL_INTERVAL_MS);
    }

    _stopPolling() {
        if (this._pollTimer) {
            clearInterval(this._pollTimer);
            this._pollTimer = null;
        }
        this.isPolling = false;
    }

    async _pollStatus() {
        try {
            const records = await pollAndUpdateStatus({ recordId: this.recordId });
            if (!records) return;

            const prevLatestStatus = this.latestVerification?.Status__c;
            this.verifications = records;

            const newLatestStatus = this.latestVerification?.Status__c;
            const hasPending = records.some(v => !FINAL_STATUSES.has(v.Status__c));

            if (!hasPending) {
                this._stopPolling();
            }

            if (newLatestStatus !== prevLatestStatus && FINAL_STATUSES.has(newLatestStatus)) {
                const variant = newLatestStatus === 'Approved' ? 'success' : 'error';
                this.dispatchEvent(new ShowToastEvent({
                    title:   'Business Verification ' + newLatestStatus,
                    message: 'Business verification is now: ' + newLatestStatus,
                    variant: variant
                }));
            }
        } catch (e) {
            console.error('incodeVerification: _pollStatus error', e);
        }
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    _stringVerificationStyle(val) {
        if (!val) return 'ver-badge ver-badge-na';
        const v = val.toUpperCase();
        if (['VERIFIED', 'DELIVERABLE', 'ACTIVE', 'OK', 'PASS'].includes(v)) return 'ver-badge ver-badge-ok';
        if (['UNVERIFIED', 'UNDELIVERABLE', 'INACTIVE', 'FAIL'].includes(v))  return 'ver-badge ver-badge-fail';
        if (v === 'ALTERNATE NAME') return 'ver-badge ver-badge-unknown';
        return 'ver-badge ver-badge-na';
    }

    _camelToLabel(key) {
        return key
            .replace(/([A-Z])/g, ' $1')
            .replace(/^./, s => s.toUpperCase());
    }

    _personStatusStyle(status) {
        if (!status) return '';
        const s = status.toUpperCase();
        if (s === 'OK' || s === 'APPROVED') return 'color:#2e844a;font-weight:700;';
        if (s === 'FAIL' || s === 'DECLINED') return 'color:#ba0517;font-weight:700;';
        return 'color:#dd7a01;font-weight:700;';
    }
}
