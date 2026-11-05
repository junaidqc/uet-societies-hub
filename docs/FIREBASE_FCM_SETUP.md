# Firebase Cloud Messaging (FCM HTTP v1) Setup Guide

This guide details how to configure zero-cost Firebase Cloud Messaging (FCM HTTP v1) for **UET Societies Hub**, integrating with Supabase Edge Functions and Flutter.

---

## 1. Firebase Project Setup (Free Tier / Spark Plan)

1. Open the [Firebase Console](https://console.firebase.google.com/).
2. Click **Create a project** and name it `uet-societies-hub`.
3. Disable Google Analytics (optional, zero-cost requirement) and click **Create Project**.

---

## 2. Register Android & iOS Applications

### Android Configuration
1. In Firebase Console, click the **Android** icon.
2. Enter the Package Name: `com.uet.societies_hub`.
3. App nickname: `UET Societies Hub Android`.
4. Download the `google-services.json` file.
5. Move `google-services.json` to:
   ```
   d:\MVP\mobile\android\app\google-services.json
   ```
6. Ensure `mobile/android/app/build.gradle` has `minSdkVersion 21`.

### iOS Configuration (Optional for Android-first builds)
1. In Firebase Console, register iOS app with bundle ID `com.uet.societiesHub`.
2. Download `GoogleService-Info.plist` and place it in `mobile/ios/Runner/GoogleService-Info.plist`.

---

## 3. Generate Service Account for FCM HTTP v1

Supabase Edge Functions dispatch notifications via Google's modern **FCM HTTP v1 API** (which replaces deprecated legacy server keys).

1. In Firebase Console, go to **Project Settings** (gear icon) -> **Service Accounts**.
2. Click **Generate new private key** -> **Generate key**.
3. Save the downloaded `.json` file securely (e.g. `firebase-service-account.json`).
4. The JSON contains:
   ```json
   {
     "type": "service_account",
     "project_id": "uet-societies-hub",
     "private_key_id": "...",
     "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgk...\n-----END PRIVATE KEY-----\n",
     "client_email": "firebase-adminsdk-xxxxx@uet-societies-hub.iam.gserviceaccount.com"
   }
   ```

---

## 4. Store Credentials in Supabase Edge Function Secrets

> [!CAUTION]
> Never commit your service account JSON file to Git or bundle it in the Flutter client. It must only reside in Supabase Edge Function environment secrets.

Run the Supabase CLI command or set it in the Supabase Dashboard:

```bash
# Using Supabase CLI:
supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account","project_id":"...","private_key":"...","client_email":"..."}'
```

Alternatively, in the Supabase Dashboard:
1. Navigate to **Project Settings** -> **Edge Functions**.
2. Click **Add new secret**.
3. Name: `FIREBASE_SERVICE_ACCOUNT_JSON`.
4. Value: Paste the raw contents of the JSON key file.

---

## 5. Deploy the `send-push-notification` Edge Function

Deploy the function to Supabase:

```bash
supabase functions deploy send-push-notification --no-verify-jwt
```

---

## 6. How Notification Dispatch Works

The Edge Function handles:
1. **Trigger Handling**:
   - `new_post`: Alerts all followers of the society.
   - `new_hiring`: Alerts all followers of the society.
   - `deadline_reminder`: Dispatched automatically by `pg_cron` daily at 08:00 PKT (03:00 UTC) to students with saved hirings closing in 24 hours.
   - `application_status`: Alerts applicant on Under Review / Shortlisted / Selected / Rejected.
   - `group_message`: Alerts committee members when a new message is posted.
2. **Preference Filtering**:
   - Checks `public.notification_preferences` for `is_muted = TRUE` on `society_id` or `group_id`.
   - Users who muted the society/group receive NO push notifications, respecting student privacy and quiet hours.
3. **In-App Mirroring**:
   - Automatically writes records to `public.notifications` so students can view alerts in-app even without Google Play Services.
