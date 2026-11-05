# Release APK & App Bundle Build Guide

This guide details how to generate production-ready, signed release builds (`APK` and `AAB`) for **UET Societies Hub** on Android (minSdkVersion 21+, portrait locked).

---

## 1. Prerequisites

- Flutter SDK (>=3.16.0)
- Java Development Kit (JDK 17+)
- Android SDK Build Tools (API 34)

---

## 2. Generate a Production Keystore

Open your terminal or command prompt and run the Java `keytool` command:

```bash
keytool -genkey -v -keystore uet-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias uet-societies-hub \
  -storetype JKS
```

When prompted:
1. Enter a secure password for the keystore.
2. Fill out organization info (e.g., `University of Engineering and Technology`).
3. Place the generated `uet-release-key.jks` file in:
   ```
   mobile/android/app/uet-release-key.jks
   ```

> [!CAUTION]
> Never commit `uet-release-key.jks` or `key.properties` to version control. They are added to `.gitignore`.

---

## 3. Configure `android/key.properties`

Create a file named `key.properties` inside `mobile/android/`:

```properties
storePassword=YOUR_SECURE_STORE_PASSWORD
keyPassword=YOUR_SECURE_KEY_PASSWORD
keyAlias=uet-societies-hub
storeFile=uet-release-key.jks
```

---

## 4. Verify Signing Configuration in `build.gradle`

Ensure `mobile/android/app/build.gradle` contains the release signing block:

```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    defaultConfig {
        applicationId "com.uet.societies_hub"
        minSdkVersion 21
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
    }

    signingConfigs {
        release {
            if (keystorePropertiesFile.exists()) {
                keyAlias keystoreProperties['keyAlias']
                keyPassword keystoreProperties['keyPassword']
                storeFile file(keystoreProperties['storeFile'])
                storePassword keystoreProperties['storePassword']
            }
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
```

---

## 5. ProGuard / R8 Rules (`android/app/proguard-rules.pro`)

Create or update `mobile/android/app/proguard-rules.pro`:

```proguard
# Flutter & Engine
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }

# Supabase Flutter & Realtime
-keep class io.supabase.** { *; }

# Firebase Cloud Messaging
-keep class com.google.firebase.** { *; }

# Net / GSON / JSON
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
```

---

## 6. Build Commands

Navigate to `/mobile` and execute the release build:

### Build Standalone Universal APK:
```bash
cd mobile
flutter clean
flutter pub get
flutter build apk --release --split-per-abi
```
Outputs:
- `mobile/build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` (~18 MB)
- `mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (~21 MB)
- `mobile/build/app/outputs/flutter-apk/app-x86_64-release.apk` (~22 MB)

### Build Universal Fat APK:
```bash
flutter build apk --release
```
Output:
- `mobile/build/app/outputs/flutter-apk/app-release.apk`

### Build Google Play Store Bundle (.aab):
```bash
flutter build appbundle --release
```
Output:
- `mobile/build/app/outputs/bundle/release/app-release.aab`

---

## 7. Release Verification Checklist

- [ ] `minSdkVersion` is strictly set to `21`.
- [ ] Portrait orientation is locked in `AndroidManifest.xml` (`android:screenOrientation="portrait"`).
- [ ] Only `SUPABASE_ANON_KEY` is configured in `.env`; NO service role keys are present.
- [ ] All network permissions are declared in `AndroidManifest.xml`:
  ```xml
  <uses-permission android:name="android.permission.INTERNET"/>
  <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
  ```
