# Dadaroo Firebase Setup Guide

## Prerequisites

- Flutter SDK 3.7.2+
- Firebase CLI (`npm install -g firebase-tools`)
- A Google account

## 1. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **Add Project** and name it `dadaroo`
3. Enable Google Analytics (optional)

## 2. Configure Flutter App

### Option A: Automatic (Recommended)

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Run configuration (this generates lib/firebase_options.dart)
flutterfire configure --project=YOUR_PROJECT_ID
```

This will auto-generate `lib/firebase_options.dart` with your real config values.

### Option B: Manual

1. In Firebase Console, add an **Android** app:
   - Package name: `com.example.dadaroo`
   - Download `google-services.json` to `android/app/`

2. Add an **iOS** app:
   - Bundle ID: `com.example.dadaroo`
   - Download `GoogleService-Info.plist` to `ios/Runner/`

3. Update `lib/firebase_options.dart` with the values from your Firebase Console (Project Settings > General > Your apps).

## 3. Enable Firebase Services

### Authentication
1. Firebase Console > Authentication > Sign-in method
2. Enable **Email/Password**

### Cloud Firestore
1. Firebase Console > Firestore Database > Create database
2. Start in **test mode** for development
3. Deploy security rules (see below)

### Cloud Messaging (Push Notifications)
1. Firebase Console > Cloud Messaging
2. For iOS: Upload your APNs key/certificate

## 4. Firestore Security Rules

Deploy these rules to `firestore.rules`:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own profile
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }

    // Family groups - members can read, creators can write
    match /familyGroups/{groupId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null
        && request.auth.uid in resource.data.memberIds;
    }

    // Deliveries - family members can read/write
    match /deliveries/{deliveryId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null;
    }

    // Ratings - authenticated users
    match /ratings/{ratingId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }

    // Notification requests - authenticated users can create
    match /notificationRequests/{docId} {
      allow create: if request.auth != null;
      allow read: if false;
    }
  }
}
```

## 5. Firestore Indexes

Create these composite indexes in Firebase Console > Firestore > Indexes:

| Collection   | Fields                                    | Query Scope |
|-------------|-------------------------------------------|-------------|
| deliveries  | `familyGroupId` ASC, `isActive` ASC       | Collection  |
| deliveries  | `familyGroupId` ASC, `isActive` ASC, `startTime` DESC | Collection |

## 6. Cloud Functions (Optional - for Push Notifications)

Push notifications require a Cloud Function to watch `notificationRequests` and send via FCM.

```bash
cd functions
npm install
firebase deploy --only functions
```

Example Cloud Function (`functions/index.js`):

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendNotification = functions.firestore
  .document('notificationRequests/{docId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (data.processed) return;

    const message = {
      notification: {
        title: data.title,
        body: data.body,
      },
      data: data.data || {},
    };

    if (data.familyGroupId) {
      // Send to family topic
      message.topic = `family_${data.familyGroupId}`;
    } else if (data.targetUid) {
      // Send to specific user
      const userDoc = await admin.firestore()
        .collection('users').doc(data.targetUid).get();
      const token = userDoc.data()?.fcmToken;
      if (token) {
        message.token = token;
      }
    }

    await admin.messaging().send(message);
    await snap.ref.update({ processed: true });
  });
```

## 7. Android Setup

In `android/app/build.gradle`, ensure:
```gradle
defaultConfig {
    minSdkVersion 21
}
```

Add to `android/app/src/main/AndroidManifest.xml` for GPS:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

For Google Maps, add your API key in `AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
```

## 8. iOS Setup

In `ios/Runner/Info.plist`, add GPS permission strings:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Dadaroo needs your location to track food deliveries</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>Dadaroo needs background location for delivery tracking</string>
```

For Google Maps, add your API key in `ios/Runner/AppDelegate.swift`:
```swift
GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
```

## 9. Run the App

```bash
flutter pub get
flutter run
```

## Firestore Data Structure

```
users/
  {uid}/
    uid, name, email, role, familyGroupId,
    totalDeliveries, averageRating, fcmToken, badges[]

familyGroups/
  {groupId}/
    id, name, inviteCode, createdBy,
    memberIds[], dadIds[], createdAt

deliveries/
  {deliveryId}/
    id, dadName, dadUid, familyGroupId,
    takeawayType, customTakeawayName,
    startTime, arrivalTime, estimatedDurationSeconds,
    isActive, rating{}, gpsTrail[],
    currentLatitude, currentLongitude

ratings/
  {deliveryId}/
    deliveryId, rating{}, average, createdAt

notificationRequests/
  {docId}/
    familyGroupId, targetUid, title, body,
    type, data{}, createdAt, processed
```
