# FolioMed 🏥
Real-time clinical notes app for medical ward teams.
Text and emoji based. Built with Flutter + Firebase.

## Setup

### 1. Firebase Project
- Go to https://console.firebase.google.com
- Enable: Authentication (Email/Password), Firestore, Cloud Messaging
- Upgrade to Blaze plan (pay as you go)

### 2. Connect Firebase
- Install CLI: dart pub global activate flutterfire_cli
- Run: flutterfire configure --project=your-project-id
- This auto-generates firebase_options.dart and google-services.json

### 3. Deploy Rules
- npm install -g firebase-tools
- firebase login
- firebase deploy --only firestore:rules
- firebase deploy --only firestore:indexes

### 4. Run
- Mobile: flutter run
- Web: flutter run -d chrome

## Roles
- Doctor: create notes, manage patients
- Nurse: view notes, acknowledge updates
- Admin: manage wards and staff

## Ward ID
Users with the same wardId see each other's
notes and patients in real time.
