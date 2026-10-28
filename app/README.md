# Tingungu Mobile Application

A technical overview of the Tingungu Flutter application, designed as a comprehensive church companion and financial utility platform.

## 🏗 Architecture & Tech Stack

The application is built using **Flutter (v3.8.1 SDK)** with a service-oriented architecture to ensure modularity and scalability.

- **Frontend Framework:** Flutter (Dart)
- **Backend Infrastructure:** Firebase (Auth, Firestore, Hosting)
- **State Management:** Mix of `StatefulWidget` lifecycle management and `SharedPreferences` for local persistence.
- **Database:** Cloud Firestore (NoSQL) and direct MySQL integration for specific utility services.
- **Payment Gateways:**
  - **PayFast:** Webview-based integration for credit card and instant EFT transactions.

## 🛠 Key Service Modules

The core logic is decoupled into dedicated service classes located in `lib/services/`:

- **`UserService`**: Wraps Firebase session sign-out; sign-in/registration use Firebase Authentication and Firestore profile documents directly.
- **`SocietyService`**: Manages church society data and member affiliations.
- **`PurchaseAirtimeService`**: Interfaces with third-party providers for airtime and utility procurement.
- **`DatabaseService`**: Centralized Firestore CRUD operations.
- **`MediaService`**: Handles content delivery for Tingungu TV (YouTube API integration).
- **`ApiClient`**: Centralizes JSON requests, Firebase bearer tokens for protected API routes, timeouts, and HTTP errors.

The app bootstrap listens to Firebase Auth state: onboarding is shown only for
unauthenticated first launches, and the home screen is shown only for a signed-in
user. The public church directory uses the read-only MySQL projections at
`API_BASE_URL`. Older PHP profile/media endpoints remain at
`LEGACY_BACKEND_URL` for legacy media delivery; Firebase Authentication and
the Firestore private profile are the app's identity/profile sources.
Invitation-based community endpoints are a separate legacy integration and
require `COMMUNITY_API_BASE_URL`.

## 🚀 Technical Features

- **Dynamic Onboarding:** Persisted launch state using `SharedPreferences`.
- **Wallet Infrastructure:** Reads the Firestore wallet projection and transaction history; wallet, giving, and airtime mutations are performed by the trusted API.
- **Theme Engine:** Custom Material 3 theme implementation with brand-specific color tokens (Primary: `#3B0D11`, Secondary: `#FB8B24`).
- **Deep Linking & Navigation:** Structured routing for seamless transitions between utility and spiritual content.

## 📋 Prerequisites & Setup

1. **Flutter SDK:** Ensure you are on the `stable` channel (>= 3.8.1).
2. **Firebase Configuration:**
   - `Firebase.initializeApp` uses the generated `lib/firebase_options.dart`. Its Android project/app IDs match `android/app/google-services.json` and the Gradle application ID; its iOS bundle ID matches the Xcode project.
   - The options target Firebase project `tingungu-sa`. The FlutterFire CLI was unavailable during the latest validation, so this already-matching generated file was not overwritten.
   - If you change Firebase apps, sign in to the intended Firebase project, install the FlutterFire CLI, then run `flutterfire configure` and review the generated IDs before release. Do not copy in credentials from a different Firebase app.
3. **Dependencies:** Run `flutter pub get` to install all required packages.
4. **Tingungu TV:** The playlist API key and playlist ID are build-time configuration, not source-code values. Set `YOUTUBE_API_KEY` as a GitHub Actions secret and `YOUTUBE_PLAYLIST_ID` as a repository variable to populate the deployed web app. Without them, the TV service logs that it is unconfigured and returns no videos.

## ⚠️ Important Note on Credentials

Google Pay is not included in the app's payment choices; the example TEST
merchant configuration has been removed. Do not add or enable Google Pay until
the production merchant and gateway configuration has been provisioned and
validated.

Production PayFast and Flash/Airtime credentials belong only in the API host's
secret settings, never in Flutter assets or source. In production the API now
requires `PAYFAST_SANDBOX=false`, PayFast merchant settings, `PUBLIC_API_URL`,
and the Flash base URL/token/account number; startup fails clearly if these
values are missing or invalid. Local development can continue using the
sandbox/test values in `api/.env.example`.

Firebase client options identify the Firebase app and are not secrets. Protect
data with Firebase Security Rules and server-side authorization rather than
trying to hide client configuration.

## Data ownership and Firestore security

Firebase Authentication owns identity; Firestore `users/{uid}` contains private
member profile data, while `public_profiles/{uid}` is restricted to the safe
member-visible projection and presence fields. The root Firestore rules prevent
client changes to wallet balances, roles, payments, giving records, airtime
orders, and transactions. A Firebase `users/{uid}.role` value is display-only;
administrative authorization requires the `admin: true` custom claim.

Districts, circuits, societies, appointments, and public minister projections
come from MySQL through the read-only API. The former Firestore directory
mirrors are blocked for client access; reconcile any required records into
MySQL before retiring those legacy mirrors. Curated notices, media, events, and
giving-option reads remain in Firestore. Giving-option changes are routed
through the admin-only API, and all financial writes remain server-side.

---
© 2026 Tingungu Project
