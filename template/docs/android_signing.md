# Android Signing & Google Play App Signing

## Overview

Two keys are involved in shipping a production Android app:

| Key                 | Purpose                                  | Who holds it |
| ------------------- | ---------------------------------------- | ------------ |
| **Upload key**      | Authenticates your upload to Google Play | You          |
| **App signing key** | Signs the APK installed on user devices  | Google Play  |

Google Play re-signs your AAB with the app signing key before distributing it. This means SHA fingerprints from **both** keys must be registered in Firebase for Google Sign-In to work on Play Store installs.

---

## Step 1: Generate the Upload Keystore

Run once. Store the file and passwords in a password manager immediately.

```bash
keytool -genkey -v \
  -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

- Password: minimum 6 characters, non-empty
- Distinguished name fields (first/last name, org, etc.) are certificate metadata, not shown to users

> **Critical:** If this key is lost, Google Play will reject all future updates. There is no recovery path.

---

## Step 2: Extract Fingerprints

### Staging (debug key)

```bash
cd android && ./gradlew signingReport
```

Look for the **`stagingDebug`** variant (or the relevant debug variant). Copy the SHA-1 and SHA-256.

### Production (upload key)

```bash
keytool -list -v -keystore ~/upload-keystore.jks -alias upload
```

Copy the SHA-1 and SHA-256.

---

## Step 3: Register Fingerprints in Firebase

For each Firebase project (staging + production):

1. Firebase Console → Project Settings → Your Android app
2. Click **Add fingerprint**
3. Add the SHA-1 and SHA-256 from Step 2

After adding fingerprints, re-download `google-services.json` for the affected project and replace the file in your flavor directories:

- `android/app/src/staging/google-services.json`
- `android/app/src/production/google-services.json`

---

## Step 4: Enroll in Google Play App Signing

This happens when you make your **first upload** to Play Console.

1. Upload your signed AAB (`make build-prod-aab`)
2. Play Console will prompt you to opt into Play App Signing. Accept it.
3. Go to Play Console → Release → Setup → App signing
4. Under "App signing key certificate", copy the SHA-1 and SHA-256
5. Add these to the **production** Firebase project (same as Step 3) alongside the upload key fingerprints

Both fingerprints can coexist in Firebase. Upload key fingerprints cover local release builds; Play signing key fingerprints cover installs from the Play Store.

---

## Step 5: Configure the Build

Add the keystore details to `.env.production` (already git-ignored):

```bash
UPLOAD_KEYSTORE_PATH=/Users/yourname/upload-keystore.jks
UPLOAD_KEY_ALIAS=upload
UPLOAD_STORE_PASSWORD=your_store_password
UPLOAD_KEY_PASSWORD=your_key_password
```

Then configure `android/app/build.gradle.kts` to use these for release builds:

```kotlin
signingConfigs {
    create("release") {
        storeFile = file(System.getenv("UPLOAD_KEYSTORE_PATH") ?: "")
        storePassword = System.getenv("UPLOAD_STORE_PASSWORD") ?: ""
        keyAlias = System.getenv("UPLOAD_KEY_ALIAS") ?: ""
        keyPassword = System.getenv("UPLOAD_KEY_PASSWORD") ?: ""
    }
}

buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
    }
}
```

> **Never commit the keystore file or passwords to git.**

---

## Summary Checklist

```
[ ] Upload keystore generated and backed up in password manager
[ ] Staging debug SHA-1 + SHA-256 added to Firebase staging project
[ ] Production upload key SHA-1 + SHA-256 added to Firebase production project
[ ] google-services.json re-downloaded and updated for both flavors
[ ] build.gradle.kts updated to use release signing config
[ ] .env.production updated with keystore path + passwords
[ ] First Play Store upload done, Play App Signing enrolled
[ ] Play App Signing key SHA-1 + SHA-256 added to Firebase production project
```
