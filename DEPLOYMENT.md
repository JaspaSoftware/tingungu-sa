# Deployment layout

The Azure Static Web Apps workflow builds one site layout:

- `/` — public pages from `website/`
- `/app/` — Flutter web app
- `/admin/` — React admin portal

All public site links to the app are same-origin paths, so they follow the
Static Web App host instead of a separately hard-coded hostname. The app and
admin use `https://tingungu-api.azurewebsites.net/api`; the public contact form
posts to that API's `/api/contact` endpoint.

The contact endpoint stores submissions as open documents in Firestore's
`support_tickets` collection. Admins can review and resolve them in the admin
portal. This requires the API's Firebase Admin credentials to have access to
the Tingungu Firebase project.

## Required deployment configuration

Configure these GitHub Actions secrets for the admin build:

- `VITE_FIREBASE_API_KEY`
- `VITE_FIREBASE_AUTH_DOMAIN`
- `VITE_FIREBASE_PROJECT_ID`
- `VITE_FIREBASE_STORAGE_BUCKET`
- `VITE_FIREBASE_MESSAGING_SENDER_ID`
- `VITE_FIREBASE_APP_ID`
- `AZURE_STATIC_WEB_APPS_API_TOKEN`

To populate Tingungu TV, configure the `YOUTUBE_API_KEY` GitHub secret and
`YOUTUBE_PLAYLIST_ID` repository variable. Restrict the Google API key to the
YouTube Data API and the applicable app/web origins.

Configure the API's Azure App Service with its Firebase Admin credentials and
`DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, and `DB_NAME`. Startup fails
when these values are missing, the database cannot be reached, or the required
directory tables (`districts`, `circuits`, `societies`, `persons`, `categories`,
and `appointments`) have not been migrated/seeded. Configure `ALLOWED_ORIGINS`
with the deployed Static Web App origin. Add the production custom domain there
too if one is configured.

Production payment integrations must also be provisioned in Azure App Service
settings (not in Flutter or checked-in files): set `PAYFAST_SANDBOX=false`,
`PAYFAST_MERCHANT_ID`, `PAYFAST_MERCHANT_KEY`, `PAYFAST_PASSPHRASE`,
`PUBLIC_API_URL`,
`FLASH_BASE_URL`, `FLASH_TOKEN`, and `FLASH_ACCOUNT_NUMBER`. The API rejects
production startup while these settings are missing, keeps PayFast in sandbox
for non-production environments by default, and requires HTTPS integration
URLs. Google Pay is not currently offered by the app; do not enable it until a
production merchant and gateway configuration has been supplied and tested.

The API exposes read-only district, circuit, and society directory endpoints
without sign-in. Writes, user management, minister records, and statistics
require a Firebase ID token with the admin custom claim. Payments and airtime
continue to enforce their own authentication; PayFast's server notification
uses its signature and provider verification.

## Data ownership and migration

| Data | Source of truth | Access path |
| --- | --- | --- |
| User identity and sign-in | Firebase Authentication | Firebase Auth |
| Private member profile | Firestore `users/{uid}` | Owner and custom-claim admin reads; limited profile-field client edits |
| Public member projection and presence | Firestore `public_profiles/{uid}` | Signed-in reads of the explicitly safe projection; owner writes |
| Districts, circuits, societies, ministers, appointments | MySQL | Public read-only API projections; admin API for directory maintenance |
| Notices, curated media, events | Firestore | Signed-in app reads; custom-claim admins manage them |
| Giving options | Firestore | Signed-in reads; custom-claim admin API writes |
| Wallet balances, giving records, payments, airtime orders, transactions | Firestore, written by the API | Trusted API/Firebase Admin SDK writes; owner/admin transaction reads |
| Support tickets | Firestore | API creates; custom-claim admins review and update ticket status |
| Integration credentials | Azure App Service environment | API runtime only; never Firestore/client bundles |

Firebase `users/{uid}.role` is display metadata only. Administrative access is
granted exclusively by the Firebase Authentication `admin: true` custom claim.
The admin portal's member page edits profile names only; assigning claims,
suspending accounts, or deleting Firebase Authentication users requires a
trusted Firebase Admin operation.

The mobile app no longer reads or writes member profiles through the legacy PHP
profile endpoints. Treat any existing PHP profile records as non-authoritative;
audit other consumers and archive or retire those records separately before
decommissioning the legacy service.

The former Firestore directory mirrors are no longer read or writable by
clients. Back up and reconcile any records needed from `districts`, `circuits`,
`societies`, `ministers`, `categories`, and `appointments` into the MySQL
directory before retiring those mirrors. Load or initialize canonical
directory data through the API's `npm run mysql-seed` workflow, not a Firestore
mirror. The mobile app now reads the public MySQL API projection; published
minister phone/email fields are returned only for active appointments.

The former `admin_settings/config` document must be deleted through trusted
Firebase administration. Rotate any credentials that may have been entered
there. The admin Settings page no longer reads or writes the document.

For a local Firebase Hosting deployment, first build Flutter web with
`--base-href /app/`, build the admin portal with its `.env` values, then run
`npm run prepare:deploy`. Firebase Hosting and Azure Static Web Apps both use
the resulting `deploy/` layout.
