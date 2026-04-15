import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import startSession      from '@salesforce/apex/IncodeService.startSession';
import getVerifications  from '@salesforce/apex/IncodeService.getVerifications';
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
    @track verifications   = [];   // full history list
    @track isPolling       = false;

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
    // Computed properties
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

    /** Enriched list with badge class and display label for each row */
    get verificationRows() {
        return this.verifications.map((v, idx) => ({
            ...v,
            rowKey:     v.Id,
            isLatest:   idx === 0,
            badgeClass: this._badgeClass(v.Status__c),
            badgeStyle: this._badgeStyle(v.Status__c)
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
        return base + 'background-color:#dd7a01;'; // Pending / anything else
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
                title:   'Verification Requested',
                message: 'Verification email sent to ' + this.recipientEmail,
                variant: 'success'
            }));

            // Reload full list so the new record appears immediately
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

    // -------------------------------------------------------------------------
    // Data loading + polling
    // -------------------------------------------------------------------------

    async _loadVerifications() {
        try {
            const records = await getVerifications({ recordId: this.recordId });
            this.verifications = records || [];

            // If the most recent one is still pending, start polling
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
            const records = await getVerifications({ recordId: this.recordId });
            if (!records) return;

            const prevLatestStatus = this.latestVerification?.Status__c;
            this.verifications = records;

            const newLatestStatus = this.latestVerification?.Status__c;
            const hasPending = records.some(v => !FINAL_STATUSES.has(v.Status__c));

            if (!hasPending) {
                this._stopPolling();
            }

            // Toast only when the most recent record transitions to a final status
            if (newLatestStatus !== prevLatestStatus && FINAL_STATUSES.has(newLatestStatus)) {
                const variant = newLatestStatus === 'Approved' ? 'success' : 'error';
                this.dispatchEvent(new ShowToastEvent({
                    title:   'Verification ' + newLatestStatus,
                    message: 'Identity verification is now: ' + newLatestStatus,
                    variant: variant
                }));
            }
        } catch (e) {
            console.error('incodeVerification: _pollStatus error', e);
        }
    }
}
