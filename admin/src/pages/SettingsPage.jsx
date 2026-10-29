import { FiAlertTriangle, FiKey } from 'react-icons/fi';

const CONFIG_GROUPS = [
  {
    title: 'Payments and airtime',
    variables: [
      'PAYFAST_SANDBOX',
      'PAYFAST_MERCHANT_ID',
      'PAYFAST_MERCHANT_KEY',
      'PAYFAST_PASSPHRASE',
      'PUBLIC_API_URL',
      'FLASH_BASE_URL',
      'FLASH_TOKEN',
      'FLASH_ACCOUNT_NUMBER',
    ],
  },
  {
    title: 'Database and Firebase Admin',
    variables: [
      'DB_HOST',
      'DB_PORT',
      'DB_NAME',
      'DB_USER',
      'DB_PASSWORD',
      'FIREBASE_SERVICE_ACCOUNT',
      'FIREBASE_PROJECT_ID',
    ],
  },
];

export default function SettingsPage() {
  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Settings</h1>
          <p>Integration configuration is managed by deployment administrators.</p>
        </div>
      </div>

      <div className="alert alert-info">
        <FiKey size={16} style={{ flexShrink: 0, marginTop: 1 }} />
        <span>
          API credentials are read from the API host environment. They are not
          stored in Firestore or exposed in the admin or mobile app bundles.
        </span>
      </div>

      <div className="card">
        <div className="card-header">
          <h3>Azure App Service configuration</h3>
        </div>
        <div className="card-body">
          <p>
            Set these values in the API App Service configuration and restart
            the service after changing them. Do not enter secret values in this
            portal or commit them to source control.
          </p>
          {CONFIG_GROUPS.map(({ title, variables }) => (
            <section key={title} style={{ marginTop: 24 }}>
              <h4>{title}</h4>
              <ul>
                {variables.map(variable => <li key={variable}><code>{variable}</code></li>)}
              </ul>
            </section>
          ))}
        </div>
      </div>

      <div className="alert alert-error" style={{ marginTop: 20 }}>
        <FiAlertTriangle size={16} style={{ flexShrink: 0, marginTop: 1 }} />
        <span>
          If credentials were previously entered in the old Firestore
          <code> admin_settings/config </code>
          document, remove that document using trusted Firebase administration
          and rotate every credential it contained. This portal no longer reads
          or writes that collection.
        </span>
      </div>
    </div>
  );
}
