# Tingungu Admin Portal

The technical management interface for the Tingungu ecosystem, built with React and Vite.

## 🏗 Tech Stack

- **Framework:** React 19
- **Build Tool:** Vite
- **Backend:** Firebase (Authentication, Firestore, Hosting)
- **Data Visualization:** Recharts
- **Routing:** React Router DOM (v7)
- **Icons:** React Icons
- **Date Handling:** date-fns

## 🛠 Key Management Modules

Located in `src/pages/`, the portal provides a suite of management tools:

- **Dashboard:** Aggregated analytics and real-time activity tracking.
- **Societies Management:** CRUD operations for church societies and member affiliations.
- **Financial Oversight:** Monitoring giving (Tithes, Offerings) and wallet transactions.
- **Media Management:** Curating content for Tingungu TV (MediaPage).
- **Event Coordination:** Managing the church calendar and event notifications.
- **User Administration:** Role management and user activity logs.

## 🚀 Getting Started

### Prerequisites
- Node.js (>= 18.x)
- npm or yarn

### Installation
1. Navigate to the admin directory: `cd admin`
2. Install dependencies: `npm install`
3. Set up environment variables: Create a `.env` file with your Firebase configuration.

### Development
Run the development server:
```bash
npm run dev
```

### Production Build
Build the optimized bundle for hosting:
```bash
npm run build
```

## 🌐 Deployment
The portal is configured for **Firebase Hosting**. Deploy using the Firebase CLI:
```bash
firebase deploy --only hosting:admin
```

### Firestore access
Firestore management access requires the Firebase Authentication custom claim
`admin: true`, assigned through a trusted server or Firebase Admin SDK. Signing
in alone does not grant administrative access. Do not grant this claim from the
client or rely on the editable `users/{uid}.role` field for authorization.

---
© 2026 Tingungu Project
