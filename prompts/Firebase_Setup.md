# Firebase FCM Integration

Version: 1.0.0

Status: APPROVED

---

# Purpose

Integrate Firebase Cloud Messaging into Pokatuha with minimal manual work.

---

# Existing Configuration

Firebase Project already exists.

Android package already exists.

google-services.json is already included in:

android/app/google-services.json

Never ask the developer to create another Firebase project.

Never ask the developer to download another configuration file.

---

# Allowed Firebase Services

Allowed

✅ Firebase Cloud Messaging

Forbidden

❌ Firestore

❌ Realtime Database

❌ Authentication

❌ Storage

❌ Analytics

❌ Crashlytics

❌ Performance

❌ Remote Config

❌ App Distribution

❌ In-App Messaging

---

# AI Responsibilities

Automatically:

Detect Flutter version.

Detect Gradle version.

Detect Kotlin version.

Detect Android Gradle Plugin version.

Install required packages.

Generate firebase_options.dart.

Configure initialization.

Configure Android Manifest.

Configure notification permissions.

Fix Gradle compatibility.

Fix deprecated APIs.

---

# Flutter Packages

Allowed

firebase_core

firebase_messaging

Do not install additional Firebase packages.

---

# Notification Permission

Android 13+

Automatically request POST_NOTIFICATIONS permission.

Do not require manual developer changes.

---

# Debug

Print FCM token only in Debug builds.

Never expose token in Release builds.

---

# Push Behaviour

FCM is used only for:

Wake application

Reconnect WebRTC

Trigger synchronization

Never transfer:

Chat history

GPS tracks

Photos

Videos

Archive

User profile

---

# Error Handling

Automatically fix dependency conflicts whenever possible.

Do not ask the developer to edit Gradle manually unless impossible.

---

# Success Criteria

Developer executes:

flutter pub get

flutter run

Everything required for FCM works automatically.

---

End of document.