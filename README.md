# UET Societies Hub

Official, secure, and zero-cost serverless ecosystem for student societies, executive recruitment, campus events, and committee collaboration at the University of Engineering & Technology (UET).

---

## 1. System Architecture & Zero-Cost Stack

The platform is designed to operate at **\$0/month operating cost** using only managed free-tier infrastructure:

| Component | Technology | Free Tier Provider | Responsibility |
| :--- | :--- | :--- | :--- |
| **Mobile Client** | Flutter 3.16+ (Dart), Riverpod, `go_router` | Native Android & iOS (minSdk 21, portrait locked) | Student UX, offline state, guest mode, realtime UI |
| **Backend & Database** | PostgreSQL 15+ with Row Level Security (RLS) | Supabase Free Tier | 17 tables, default-deny RLS, DB triggers, SQL functions |
| **Authentication** | Supabase Auth (Email OTP) | Brevo / Resend Free Tier Custom SMTP | Enforced `@uet.edu.pk` domain via database trigger |
| **Object Storage** | Supabase Storage (5 MB cap) | Supabase Storage (1 GB free) | Society logos, post media, resumes, private chat files |
| **Realtime Messaging** | Supabase Realtime (WebSocket engine) | Supabase Realtime | Committee group chat, live notices, polls, and tasks |
| **Serverless Functions** | Deno / TypeScript Edge Functions | Supabase Edge Functions (500K free invocations) | 30-day data retention cleanup, FCM HTTP v1 dispatcher |
| **Scheduled Tasks** | `pg_cron` + `pg_net` + Supabase Vault | Supabase PostgreSQL Extensions | Daily hiring deadline auto-close, 24h deadline reminders |
| **Push Notifications** | Firebase Cloud Messaging (HTTP v1) | Google Firebase Spark Plan (Free) | Realtime push alerts with OAuth2 JWT service account |
| **Automated Backups** | GitHub Actions + `pg_dump` | GitHub Actions (2,000 free minutes/month) | Daily PostgreSQL dump with 30-day artifact retention |

---

## 2. Requirements Traceability Matrix (FR-1 .. FR-40, UC-1 .. UC-3)

| Requirement | Description | Implementation Status |
| :--- | :--- | :--- |
| **FR-1 .. FR-5** | Signup with `@uet.edu.pk` email trigger, OTP verification, login, profile edit, guest splash | ✅ Complete (`features/auth`, `features/profile`, Migration 01-04) |
| **FR-6 .. FR-10** | Society registration charter, System Admin approve/reject, public directory, follow/unfollow | ✅ Complete (`features/societies`, Migration 05) |
| **FR-11 .. FR-17** | Society Admin posts & events, Public vs Members-only RLS, feed newest-first, RSVP Interested | ✅ Complete (`features/feed`, `features/home`, Migration 06) |
| **FR-18 .. FR-25** | Recruitment posts, deadline sorting, pg_cron auto-close, custom questions form, review console | ✅ Complete (`features/hiring`, Migration 07) |
| **FR-26 .. FR-32** | Private committee groups, realtime chat, attachments, notices, polls, tasks, member permanent ban | ✅ Complete (`features/groups`, Migration 08, Edge Function `cleanup-old-data`) |
| **FR-33 .. FR-34** | President role governance, assign admin privileges, manage executive roster | ✅ Complete (`society_management_screen.dart`, Migration 05) |
| **FR-35** | Unified Campus Calendar showing events and hiring deadlines (works in guest mode) | ✅ Complete (`features/calendar`, `calendar_screen.dart`) |
| **FR-36 .. FR-37** | Push notifications via FCM HTTP v1, in-app notification center, per-society/group mute toggles | ✅ Complete (`send-push-notification`, `notifications_screen.dart`, Migration 09) |
| **FR-38 .. FR-40** | Report post/comment/society, System Admin moderation queue, delete content, metrics console | ✅ Complete (`features/admin`, `admin_dashboard_screen.dart`, Migration 10) |
| **UC-1 .. UC-2** | Student applies in <= 5 taps, duplicate-apply blocked, direct group onboarding for recruits | ✅ Complete (`apply_hiring_screen.dart`, `admin_applications_screen.dart`) |
| **UC-3** | Hiring directory and campus calendar fully accessible to guest users | ✅ Complete (`hiring_screen.dart`, `calendar_screen.dart`) |
| **NFR-10** | Automated daily database backups via GitHub Actions without human intervention | ✅ Complete (`.github/workflows/supabase_daily_backup.yml`) |

---

## 3. Database Migrations Overview

All database schema, functions, triggers, and RLS policies reside in `/supabase/migrations`:

1. `20260101000001_core_schema.sql`: 17 core relational tables, foreign keys, and indexes.
2. `20260101000002_functions_and_triggers.sql`: `@uet.edu.pk` domain enforcement trigger, profile sync, timestamps.
3. `20260101000003_rls_policies.sql`: Default-deny Row Level Security policies across all tables.
4. `20260101000004_storage_and_audit.sql`: Storage buckets (`society-logos`, `post-media`, `resumes`), 5 MB caps, audit logging.
5. `20260101000005_society_registration_and_admin.sql`: Charter request approval/rejection RPCs, president admin assignment.
6. `20260101000006_posts_and_events_enhancements.sql`: Members-only vs public post RLS, likes, comments, and event RSVPs.
7. `20260101000007_hiring_and_applications_enhancements.sql`: Custom form questions, unique application constraint, pg_cron auto-close.
8. `20260101000008_groups_chat_and_retention.sql`: Committee groups, `chat-attachments` bucket, permanent ban, 30-day retention scheduling.
9. `20260101000009_notifications_fcm_and_preferences.sql`: Per-society/group mute preferences, 24h deadline reminder cron.
10. `20260101000010_reports_and_moderation.sql`: Student reporting queue, moderation RPCs (`delete_reported_content`, `suspend_society`), system metrics.

---

## 4. Setup & Deployment Instructions

### Step 1: Clone Repository & Configure Environment
```bash
cp .env.example mobile/.env
```
Fill in your Supabase project URL and anon key in `mobile/.env`:
```properties
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOi...
```

### Step 2: Apply Migrations and Seed Database
Using the Supabase CLI:
```bash
supabase db reset
# Or link to your remote project and push:
supabase link --project-ref your-project-ref
supabase db push
supabase db execute --file supabase/seed.sql
```

### Step 3: Deploy Edge Functions
```bash
# Set secrets
supabase secrets set CRON_SECRET="your-secure-cron-secret-32-chars"
supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'

# Deploy
supabase functions deploy cleanup-old-data --no-verify-jwt
supabase functions deploy send-push-notification --no-verify-jwt
```

### Step 4: Run Automated SQL Verification Tests
Execute the SQL test suites in the Supabase SQL Editor:
```sql
-- 1. Verify RLS Group Privacy (confirms non-member cannot read private group rows or messages)
\i supabase/tests/rls_group_security_test.sql

-- 2. Verify 30-Day Retention Cleanup (confirms 31-day-old message & file removed, 29-day-old preserved)
\i supabase/tests/retention_cleanup_test.sql
```

### Step 5: Launch Flutter Mobile Client
```bash
cd mobile
flutter pub get
flutter run
```

---

## 5. Security & Verification Summary

- **Email Domain Security**: Trigger `trg_enforce_uet_email_domain` blocks all registrations not ending in `@uet.edu.pk`.
- **Zero Secrets in Client**: Flutter client bundles only `SUPABASE_ANON_KEY`. All elevated tasks execute through PostgreSQL RLS or Edge Functions.
- **Strict IDOR Prevention**: Applications, private messages, and private committee groups are completely invisible to non-members at the database query level.
- **Automated Retention**: Edge Function `cleanup-old-data` purges messages and storage files older than 30 days every night at 03:00 PKT (22:00 UTC).
- **Audit Logging**: All administrative decisions are permanently recorded in `public.audit_log`.

---

## 6. Comprehensive Manual Test Checklist

- [ ] **Guest Mode**: Launch app -> tap "Continue as Guest" -> browse societies, public feed, hiring listings, and campus calendar without login prompts.
- [ ] **Student Signup**: Sign up with `student@gmail.com` -> verify rejected by DB trigger. Sign up with `student@uet.edu.pk` -> verify OTP received.
- [ ] **Society Registration**: Student registers charter -> System Admin approves charter via System Admin Console -> Society appears in public directory.
- [ ] **Public vs Members Post**: Admin posts "Members Only" announcement -> verify Guest and Non-Member cannot see it in feed.
- [ ] **Recruitment Application**: Student applies for open hiring in <= 5 taps -> verify duplicate submission is blocked.
- [ ] **Committee Group Chat**: Admin selects applicant -> applicant onboarded to group -> verify realtime messages, photo attachment, and poll voting.
- [ ] **Retention Banner**: Open group chat -> verify notice banner: *"Messages and attachments in this group disappear after 30 days."*
- [ ] **Campus Calendar**: Tap Calendar icon -> verify events and hiring deadlines displayed with days-left countdown.
- [ ] **Push Mute**: Open Notification Settings -> mute specific society -> verify in-app preferences updated.
- [ ] **Moderation**: Report a post -> open System Admin Console -> verify report in queue -> tap "Delete Content" -> verify post deleted and audit logged.
