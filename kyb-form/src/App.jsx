import { useState } from 'react';
import './App.css';
import { startSession, submitEkyb, finishSession } from './services/incodeApi';

function getUrlParams() {
  const p = new URLSearchParams(window.location.search);
  return { token: p.get('token'), interviewId: p.get('interviewId') };
}

const COUNTRIES = [
  { code: 'US', name: 'United States', flag: '🇺🇸', isEU: false },
  { code: 'GB', name: 'United Kingdom', flag: '🇬🇧', isEU: true },
  { code: 'FR', name: 'France',         flag: '🇫🇷', isEU: true },
  { code: 'DE', name: 'Germany',        flag: '🇩🇪', isEU: true },
  { code: 'IT', name: 'Italy',          flag: '🇮🇹', isEU: true },
  { code: 'ES', name: 'Spain',          flag: '🇪🇸', isEU: true },
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

const KEY_LABELS = {
  name:                   'Business Name',
  tin:                    'Tax ID / TIN',
  address_verification:   'Address',
  address_deliverability: 'Address Deliverability',
  address_property_type:  'Property Type',
  cityMatch:              'City Match',
  postalCodeMatch:        'Postal Code Match',
  registrationStatus:     'Registration Status',
  ubo_name_match:         'UBO Name Match',
  directors_name_match:   'Director Name Match',
  entityType:             'Entity Type',
  people:                 'Associated People',
};

function getCheckClass(subLabel) {
  if (!subLabel) return 'info';
  const s = subLabel.toLowerCase();
  if (s === 'verified' || s === 'active' || s === 'deliverable' || s === 'commercial') return 'verified';
  if (s.includes('approximate') || s.includes('partial')) return 'approximate';
  if (s === 'unverified' || s === 'inactive' || s === 'failed') return 'unverified';
  return 'info';
}

function getCheckIcon(cls) {
  if (cls === 'verified')    return '✓';
  if (cls === 'approximate') return '~';
  if (cls === 'unverified')  return '✗';
  return 'i';
}

const STEPS = ['Country', 'Business', 'People', 'Results'];

function ProgressBar({ step }) {
  return (
    <div className="progress-wrapper">
      <div className="progress-steps">
        {STEPS.map((label, i) => {
          const idx = i + 1;
          const isCompleted = step > idx;
          const isActive = step === idx;
          return (
            <div
              key={label}
              className={`progress-step ${isActive ? 'active' : ''} ${isCompleted ? 'completed' : ''}`}
            >
              <div className="step-circle">
                {isCompleted ? '✓' : idx}
              </div>
              <span className="step-label">{label}</span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function PersonList({ label, people, onChange }) {
  const updatePerson = (i, field, value) => {
    const updated = people.map((p, idx) => idx === i ? { ...p, [field]: value } : p);
    onChange(updated);
  };
  const addPerson = () => onChange([...people, { firstName: '', lastName: '' }]);
  const removePerson = (i) => onChange(people.filter((_, idx) => idx !== i));

  return (
    <div>
      <div className="people-list">
        {people.map((p, i) => (
          <div className="person-row" key={i}>
            <input
              type="text"
              placeholder="First name"
              value={p.firstName}
              onChange={e => updatePerson(i, 'firstName', e.target.value)}
            />
            <input
              type="text"
              placeholder="Last name"
              value={p.lastName}
              onChange={e => updatePerson(i, 'lastName', e.target.value)}
            />
            <button
              type="button"
              className="btn-remove"
              onClick={() => removePerson(i)}
              disabled={people.length === 1}
              title="Remove"
            >
              ×
            </button>
          </div>
        ))}
      </div>
      <button type="button" className="btn-add" onClick={addPerson}>
        + Add another {label}
      </button>
    </div>
  );
}

function CheckItem({ item }) {
  if (item.key === 'entityType') {
    return (
      <div className="check-item">
        <div className="check-icon info">{getCheckIcon('info')}</div>
        <div className="check-content">
          <div className="check-label">{KEY_LABELS.entityType}</div>
          <div className="check-value">{item.entityType?.entityType || '—'}</div>
        </div>
        <span className="check-badge info">Info</span>
      </div>
    );
  }

  if (item.key === 'people') {
    return (
      <div className="check-item" style={{ flexDirection: 'column', alignItems: 'stretch' }}>
        <div style={{ display: 'flex', gap: 12, alignItems: 'flex-start' }}>
          <div className="check-icon info">{getCheckIcon('info')}</div>
          <div className="check-label" style={{ paddingTop: 2 }}>{KEY_LABELS.people}</div>
        </div>
        {item.people && item.people.length > 0 && (
          <div className="people-section">
            <table className="people-table">
              <tbody>
                {item.people.map((person, i) => (
                  <tr key={i}>
                    <td>{person.name}</td>
                    <td>{person.titles?.map(t => t.title).join(', ') || '—'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    );
  }

  const cls = getCheckClass(item.sub_label);
  const inputNote = item.uboName_input || item.directorsName_input;

  return (
    <div className="check-item">
      <div className={`check-icon ${cls}`}>{getCheckIcon(cls)}</div>
      <div className="check-content">
        <div className="check-label">{KEY_LABELS[item.key] || item.key}</div>
        {inputNote && <div className="check-value">Input: {inputNote}</div>}
        {item.reasonCodes?.length > 0 && (
          <div className="check-value">Codes: {item.reasonCodes.join(', ')}</div>
        )}
      </div>
      {item.sub_label && (
        <span className={`check-badge ${cls}`}>{item.sub_label}</span>
      )}
    </div>
  );
}

function getFinishStatusMeta(action, scoreStatus) {
  if (action === 'approved' || scoreStatus === 'OK') {
    return { cls: 'status-approved', icon: '✅', title: 'Verification Passed', desc: 'The business has been successfully verified.' };
  }
  if (action === 'rejected' || scoreStatus === 'FAIL') {
    return { cls: 'status-rejected', icon: '❌', title: 'Verification Failed', desc: 'The business could not be verified with the information provided.' };
  }
  if (action === 'manualReview') {
    return { cls: 'status-review', icon: '🔍', title: 'Manual Review Required', desc: 'This verification requires additional review by our compliance team.' };
  }
  return { cls: 'status-none', icon: '📋', title: 'Verification Submitted', desc: 'The verification results are shown below.' };
}

export default function App() {
  const { token: presetToken, interviewId: presetInterviewId } = getUrlParams();

  const [step, setStep] = useState(1);
  const [country, setCountry] = useState(null);
  const [form, setForm] = useState({
    businessName: '', taxId: '', street: '', houseNo: '',
    addressLine2: '', city: '', state: '', postalCode: '',
  });
  const [ubos, setUbos] = useState([{ firstName: '', lastName: '' }]);
  const [directors, setDirectors] = useState([{ firstName: '', lastName: '' }]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [fieldErrors, setFieldErrors] = useState({});
  const [kybResults, setKybResults] = useState(null);
  const [finishData, setFinishData] = useState(null);

  const updateForm = (field, value) => {
    setForm(prev => ({ ...prev, [field]: value }));
    if (fieldErrors[field]) setFieldErrors(prev => ({ ...prev, [field]: null }));
  };

  const handleCountrySelect = (c) => {
    setCountry(c);
    setStep(2);
  };

  const validateStep2 = () => {
    const errors = {};
    if (!form.businessName.trim()) errors.businessName = 'Required';
    if (!form.taxId.trim())        errors.taxId = 'Required';
    if (!form.city.trim())         errors.city = 'Required';
    if (!form.postalCode.trim())   errors.postalCode = 'Required';
    if (country?.code === 'US' && !form.state) errors.state = 'Required';
    setFieldErrors(errors);
    return Object.keys(errors).length === 0;
  };

  const handleSubmit = async () => {
    setError(null);
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

      const [kybData, finishResult] = await Promise.all([
        submitEkyb(token, payload),
        finishSession(token),
      ]);

      setKybResults(kybData.kyb || []);
      setFinishData(finishResult);
    } catch (err) {
      setError(err.message || 'An unexpected error occurred. Please try again.');
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
    setKybResults(null);
    setFinishData(null);
    setError(null);
    setFieldErrors({});
  };

  const statusMeta = finishData
    ? getFinishStatusMeta(finishData.action, finishData.scoreStatus)
    : null;

  return (
    <div className="app">
      <header className="header">
        <div className="logo">
          <div className="logo-dot" />
          <span className="logo-text">incode</span>
        </div>
        <span className="header-badge">eKYB</span>
      </header>

      <main className="main">
        <div className="form-container">
          <ProgressBar step={step} />

          {/* ── STEP 1: Country ──────────────────── */}
          {step === 1 && (
            <div className="step-card">
              <h2 className="step-title">Select your country</h2>
              <p className="step-subtitle">
                Choose the country where your business is registered.
              </p>
              <div className="country-grid">
                {COUNTRIES.map(c => (
                  <button
                    key={c.code}
                    type="button"
                    className={`country-card ${country?.code === c.code ? 'selected' : ''}`}
                    onClick={() => handleCountrySelect(c)}
                  >
                    <span className="country-flag">{c.flag}</span>
                    <span className="country-name">{c.name}</span>
                  </button>
                ))}
              </div>
            </div>
          )}

          {/* ── STEP 2: Business info ─────────────── */}
          {step === 2 && (
            <div className="step-card">
              <h2 className="step-title">Business information</h2>
              <p className="step-subtitle">
                Enter your registered business details. Fields marked <span style={{ color: '#ef4444' }}>*</span> are required.
              </p>

              <div className="form-grid">
                <div className="field full">
                  <label>Business Name <span className="required">*</span></label>
                  <input
                    type="text"
                    placeholder="e.g. Acme Corporation Ltd"
                    value={form.businessName}
                    onChange={e => updateForm('businessName', e.target.value)}
                    className={fieldErrors.businessName ? 'error' : ''}
                  />
                  {fieldErrors.businessName && <span className="field-error">{fieldErrors.businessName}</span>}
                </div>

                <div className="field full">
                  <label>Tax ID / Registration Number <span className="required">*</span></label>
                  <input
                    type="text"
                    placeholder={country?.code === 'US' ? 'e.g. 123456789' : 'e.g. GB450020358'}
                    value={form.taxId}
                    onChange={e => updateForm('taxId', e.target.value)}
                    className={fieldErrors.taxId ? 'error' : ''}
                  />
                  {fieldErrors.taxId && <span className="field-error">{fieldErrors.taxId}</span>}
                </div>

                <div className="field" style={{ gridColumn: '1 / 2' }}>
                  <label>Street</label>
                  <input
                    type="text"
                    placeholder="e.g. Mission St"
                    value={form.street}
                    onChange={e => updateForm('street', e.target.value)}
                  />
                </div>

                <div className="field">
                  <label>House / Building No.</label>
                  <input
                    type="text"
                    placeholder="e.g. 101"
                    value={form.houseNo}
                    onChange={e => updateForm('houseNo', e.target.value)}
                  />
                </div>

                <div className="field full">
                  <label>Address Line 2</label>
                  <input
                    type="text"
                    placeholder="Floor, Suite, Unit (optional)"
                    value={form.addressLine2}
                    onChange={e => updateForm('addressLine2', e.target.value)}
                  />
                </div>

                <div className="field">
                  <label>City <span className="required">*</span></label>
                  <input
                    type="text"
                    placeholder="e.g. San Francisco"
                    value={form.city}
                    onChange={e => updateForm('city', e.target.value)}
                    className={fieldErrors.city ? 'error' : ''}
                  />
                  {fieldErrors.city && <span className="field-error">{fieldErrors.city}</span>}
                </div>

                {country?.code === 'US' ? (
                  <div className="field">
                    <label>State <span className="required">*</span></label>
                    <select
                      value={form.state}
                      onChange={e => updateForm('state', e.target.value)}
                      className={fieldErrors.state ? 'error' : ''}
                    >
                      <option value="">Select state…</option>
                      {US_STATES.map(([code, name]) => (
                        <option key={code} value={code}>{name}</option>
                      ))}
                    </select>
                    {fieldErrors.state && <span className="field-error">{fieldErrors.state}</span>}
                  </div>
                ) : (
                  <div className="field">
                    <label>Region / State</label>
                    <input
                      type="text"
                      placeholder="e.g. Île-de-France"
                      value={form.state}
                      onChange={e => updateForm('state', e.target.value)}
                    />
                  </div>
                )}

                <div className="field">
                  <label>Postal Code <span className="required">*</span></label>
                  <input
                    type="text"
                    placeholder={country?.code === 'US' ? '94105' : 'W1F 0DQ'}
                    value={form.postalCode}
                    onChange={e => updateForm('postalCode', e.target.value)}
                    className={fieldErrors.postalCode ? 'error' : ''}
                  />
                  {fieldErrors.postalCode && <span className="field-error">{fieldErrors.postalCode}</span>}
                </div>
              </div>

              <div className="btn-actions">
                <button type="button" className="btn-back" onClick={() => setStep(1)}>
                  Back
                </button>
                <button
                  type="button"
                  className="btn-primary"
                  onClick={() => { if (validateStep2()) setStep(3); }}
                >
                  Continue →
                </button>
              </div>
            </div>
          )}

          {/* ── STEP 3: People ────────────────────── */}
          {step === 3 && (
            <div className="step-card">
              <h2 className="step-title">Beneficial owners &amp; directors</h2>
              <p className="step-subtitle">
                Provide the names of beneficial owners (UBOs)
                {country?.isEU ? ' and company directors' : ''} associated with the business.
              </p>

              <div className="section-divider">
                <h3>Beneficial Owners (UBOs)</h3>
                <div className="divider-line" />
              </div>
              <PersonList label="UBO" people={ubos} onChange={setUbos} />

              {country?.isEU && (
                <>
                  <div className="section-divider">
                    <h3>Directors</h3>
                    <div className="divider-line" />
                  </div>
                  <PersonList label="Director" people={directors} onChange={setDirectors} />
                </>
              )}

              <div className="btn-actions">
                <button type="button" className="btn-back" onClick={() => setStep(2)}>
                  Back
                </button>
                <button
                  type="button"
                  className="btn-primary"
                  onClick={handleSubmit}
                >
                  Submit Verification →
                </button>
              </div>
            </div>
          )}

          {/* ── STEP 4: Results ───────────────────── */}
          {step === 4 && (
            <div className="step-card">
              {loading ? (
                <div className="loading-screen">
                  <div className="spinner" />
                  <div>
                    <p style={{ color: '#e2e8f0', fontWeight: 600, marginBottom: 6 }}>
                      Verifying your business…
                    </p>
                    <p>This usually takes a few seconds. Please don't close this page.</p>
                  </div>
                </div>
              ) : error ? (
                <>
                  <h2 className="step-title">Verification Error</h2>
                  <div className="error-banner" style={{ marginTop: 16 }}>
                    <span className="error-icon">⚠</span>
                    <span>{error}</span>
                  </div>
                  <div className="btn-actions" style={{ justifyContent: 'center' }}>
                    <button type="button" className="btn-back" onClick={() => setStep(3)}>
                      Go Back
                    </button>
                    <button type="button" className="btn-primary" onClick={handleSubmit}>
                      Retry →
                    </button>
                  </div>
                </>
              ) : (
                <>
                  <h2 className="step-title">Verification Results</h2>
                  <p className="step-subtitle" style={{ marginBottom: 20 }}>
                    {country?.flag} {form.businessName}
                  </p>

                  {statusMeta && (
                    <div className={`result-status ${statusMeta.cls}`}>
                      <span className="status-icon">{statusMeta.icon}</span>
                      <div className="status-info">
                        <h3>{statusMeta.title}</h3>
                        <p>{statusMeta.desc}</p>
                      </div>
                    </div>
                  )}

                  <div className="checks-list">
                    {(kybResults || []).map((item, i) => (
                      <CheckItem key={i} item={item} />
                    ))}
                  </div>

                  <button type="button" className="btn-restart" onClick={handleRestart}>
                    Start New Verification
                  </button>
                </>
              )}
            </div>
          )}
        </div>
      </main>

      <footer className="footer">
        Powered by Incode Technologies — incode.com
      </footer>
    </div>
  );
}
