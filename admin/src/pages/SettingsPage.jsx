import { useState, useEffect } from 'react';
import { db } from '../firebase';
import { doc, getDoc, setDoc } from 'firebase/firestore';
import { FiSave, FiKey, FiCreditCard, FiZap, FiBarChart2, FiGlobe, FiSmartphone } from 'react-icons/fi';

const SECTIONS = [
  {
    id: 'payfast',
    label: 'PayFast Integration',
    icon: FiCreditCard,
    fields: [
      { key: 'merchantId', label: 'Merchant ID', type: 'text', placeholder: '14362369' },
      { key: 'merchantKey', label: 'Merchant Key', type: 'password', placeholder: 'Your PayFast merchant key' },
      { key: 'passphrase', label: 'Passphrase', type: 'password', placeholder: 'Your PayFast passphrase' },
      { key: 'sandbox', label: 'Sandbox Mode', type: 'checkbox' },
    ],
  },
  {
    id: 'flash',
    label: 'Flash / VAS Integration',
    icon: FiZap,
    fields: [
      { key: 'apiKey', label: 'API Key', type: 'password', placeholder: 'Flash API key' },
      { key: 'baseUrl', label: 'Base URL', type: 'text', placeholder: 'https://api.flashgroup.co.za' },
      { key: 'accountNumber', label: 'Account Number', type: 'text', placeholder: 'Your Flash account number' },
    ],
  },
  {
    id: 'google',
    label: 'Google Services',
    icon: FiBarChart2,
    fields: [
      { key: 'analyticsId', label: 'Google Analytics Measurement ID', type: 'text', placeholder: 'G-XXXXXXXXXX' },
      { key: 'youtubeApiKey', label: 'YouTube Data API Key', type: 'password', placeholder: 'YouTube API key for Tingungu TV' },
      { key: 'youtubePlaylistId', label: 'YouTube Playlist ID', type: 'text', placeholder: 'Playlist ID for Tingungu TV' },
    ],
  },
  {
    id: 'app',
    label: 'App Configuration',
    icon: FiGlobe,
    fields: [
      { key: 'appVersion', label: 'App Version', type: 'text', placeholder: '1.0.0' },
      { key: 'supportEmail', label: 'Support Email', type: 'email', placeholder: 'support@tingungu.co.za' },
      { key: 'websiteUrl', label: 'Website URL', type: 'text', placeholder: 'https://www.tingungu.co.za' },
      { key: 'maintenanceMode', label: 'Maintenance Mode', type: 'checkbox' },
    ],
  },
  {
    id: 'mobileServices',
    label: 'Mobile Services',
    icon: FiSmartphone,
    fields: [
      { key: 'airtimeEnabled', label: 'Airtime Purchases Enabled', type: 'checkbox' },
      { key: 'dataEnabled', label: 'Data Bundles Enabled', type: 'checkbox' },
      { key: 'electricityEnabled', label: 'Electricity Tokens Enabled', type: 'checkbox' },
      { key: 'chatEnabled', label: 'Lufuno Assistant Enabled', type: 'checkbox' },
      { key: 'xpressiveCultureUrl', label: 'Xpressive Culture URL', type: 'url', placeholder: 'https://wa.me/c/...' },
      { key: 'fempreneursUrl', label: 'Fempreneurs URL', type: 'url', placeholder: 'https://fempreneurs.co.za/...' },
    ],
  },
];

export default function SettingsPage() {
  const [settings, setSettings] = useState({});
  const [saving, setSaving] = useState(null);
  const [saved, setSaved] = useState(null);

  useEffect(() => {
    getDoc(doc(db, 'admin_settings', 'config')).then(d => {
      if (d.exists()) setSettings(d.data());
    });
  }, []);

  const handleChange = (section, key, value) => {
    setSettings(prev => ({
      ...prev,
      [section]: { ...(prev[section] || {}), [key]: value }
    }));
  };

  const saveSection = async (sectionId) => {
    setSaving(sectionId);
    try {
      await setDoc(doc(db, 'admin_settings', 'config'), settings, { merge: true });
      setSaved(sectionId);
      setTimeout(() => setSaved(null), 2000);
    } finally {
      setSaving(null);
    }
  };

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Settings</h1>
          <p>Configure API keys and app-wide integrations</p>
        </div>
      </div>

      <div className="alert alert-info">
        <FiKey size={16} style={{ flexShrink: 0, marginTop: 1 }} />
        <span>Settings are stored securely in Firestore. API keys are never exposed in the app bundle. Changes take effect immediately for new requests.</span>
      </div>

      {SECTIONS.map(({ id, label, icon: Icon, fields }) => {
        const sectionData = settings[id] || {};
        return (
          <div className="card settings-section" key={id} style={{ marginBottom: 20 }}>
            <div className="card-header" style={{ borderBottom: '1px solid var(--border)', paddingBottom: 16 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <div style={{ width: 36, height: 36, background: 'rgba(59,13,17,0.08)', borderRadius: 8, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <Icon size={18} style={{ color: 'var(--maroon)' }} />
                </div>
                <h3>{label}</h3>
              </div>
              <button
                className={`btn btn-sm ${saved === id ? 'btn-orange' : 'btn-primary'}`}
                onClick={() => saveSection(id)}
                disabled={saving === id}
              >
                <FiSave size={13} />
                {saved === id ? 'Saved!' : saving === id ? 'Saving...' : 'Save'}
              </button>
            </div>
            <div className="card-body">
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0 24px' }}>
                {fields.map(({ key, label: fLabel, type, placeholder }) => (
                  <div className="form-group" key={key} style={type === 'checkbox' ? { display: 'flex', alignItems: 'center', gap: 10 } : {}}>
                    {type === 'checkbox' ? (
                      <>
                        <input
                          type="checkbox"
                          id={`${id}-${key}`}
                          checked={sectionData[key] || false}
                          onChange={e => handleChange(id, key, e.target.checked)}
                        />
                        <label htmlFor={`${id}-${key}`} className="form-label" style={{ marginBottom: 0 }}>{fLabel}</label>
                      </>
                    ) : (
                      <>
                        <label className="form-label">{fLabel}</label>
                        <input
                          type={type}
                          className="form-control"
                          placeholder={placeholder}
                          value={sectionData[key] || ''}
                          onChange={e => handleChange(id, key, e.target.value)}
                        />
                      </>
                    )}
                  </div>
                ))}
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
}
