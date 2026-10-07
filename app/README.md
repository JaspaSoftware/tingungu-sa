# Tingungu Mobile Application

A technical overview of the Tingungu Flutter application, designed as a comprehensive church companion and financial utility platform.

## 🏗 Architecture & Tech Stack

The application is built using **Flutter (v3.8.1 SDK)** with a service-oriented architecture to ensure modularity and scalability.

- **Frontend Framework:** Flutter (Dart)
- **Backend Infrastructure:** Firebase (Auth, Firestore, Hosting)
- **State Management:** Mix of `StatefulWidget` lifecycle management and `SharedPreferences` for local persistence.
- **Database:** Cloud Firestore (NoSQL) and direct MySQL integration for specific utility services.
- **Payment Gateways:**
  - **Google Pay:** Native integration via the `pay` package.
  - **PayFast:** Webview-based integration for credit card and instant EFT transactions.

## 🛠 Key Service Modules

The core logic is decoupled into dedicated service classes located in `lib/services/`:

- **`UserService`**: Handles Firebase Authentication and user profile synchronization.
- **`SocietyService`**: Manages church society data and member affiliations.
- **`PurchaseAirtimeService`**: Interfaces with third-party providers for airtime and utility procurement.
- **`DatabaseService`**: Centralized Firestore CRUD operations.
- **`MediaService`**: Handles content delivery for Tingungu TV (YouTube API integration).

## 🚀 Technical Features

- **Dynamic Onboarding:** Persisted launch state using `SharedPreferences`.
- **Wallet Infrastructure:** Real-time balance updates using Firestore Transactions to ensure data atomicity.
- **Theme Engine:** Custom Material 3 theme implementation with brand-specific color tokens (Primary: `#3B0D11`, Secondary: `#FB8B24`).
- **Deep Linking & Navigation:** Structured routing for seamless transitions between utility and spiritual content.

## 📋 Prerequisites & Setup

1. **Flutter SDK:** Ensure you are on the `stable` channel (>= 3.8.1).
2. **Firebase Configuration:** 
   - `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) must be present in their respective platform directories.
   - Run `flutterfire configure` to update `lib/firebase_options.dart`.
3. **Dependencies:** Run `flutter pub get` to install all required packages.

## ⚠️ Important Note on Credentials

The `main` branch currently utilizes **Sandbox/Test Credentials** for:
- PayFast Merchant ID/Key
- Google Pay Environment (`TEST`)
- Airtime Provider API Keys

Transitioning to production requires updating these tokens in the respective service configurations.

## Firestore security rollout

The root `firestore.rules` now denies access by default, restricts profile reads
to the owner and admins, and blocks client-side wallet and giving writes. Before
deploying these rules, migrate community member listings and other cross-user
profile reads to a separate public-profile collection, and move wallet,
transaction, and giving writes behind a trusted server that verifies payments.
Admin portal users also need the `admin: true` Firebase Authentication custom
claim, assigned through a trusted server or Firebase Admin SDK.

---
© 2026 Tingungu Project
