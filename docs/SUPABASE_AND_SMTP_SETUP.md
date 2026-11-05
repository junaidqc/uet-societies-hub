# UET Societies Hub - Supabase & Custom SMTP Setup Guide

This guide walks you through setting up Supabase (Free Tier) and configuring Custom SMTP (Brevo / Resend Free Tier) to ensure reliable OTP delivery for `@uet.edu.pk` student signups.

---

## 1. Supabase Project Setup (Zero Cost)

### Step 1: Create Supabase Project
1. Go to [supabase.com](https://supabase.com) and sign in (GitHub or email).
2. Click **New Project**.
3. Fill in the details:
   - **Name**: `uet-societies-hub`
   - **Database Password**: Generate and securely save a strong password.
   - **Region**: Choose the closest region (e.g. `Singapore` or `Frankfurt`).
   - **Pricing Plan**: **Free** ($0/month).
4. Click **Create new project** and wait 1-2 minutes for provisioning.

### Step 2: Run Database Migrations
1. In the Supabase Dashboard, navigate to the **SQL Editor** (icon on the left sidebar).
2. Run the migration scripts in numerical sequence, or run them all at once:
   - `supabase/migrations/20260101000001_core_schema.sql` (Creates all tables, constraints, check rules, indexes)
   - `supabase/migrations/20260101000002_functions_and_triggers.sql` (Enforces `@uet.edu.pk` domain trigger, profile sync, helper functions)
   - `supabase/migrations/20260101000003_rls_policies.sql` (Enforces RLS default deny and strict access policies across all 17 tables)
   - `supabase/migrations/20260101000004_storage_and_audit.sql` (Configures 4 storage buckets with 5MB limits and MIME allowlists + audit log triggers)
   - `supabase/migrations/20260101000005_society_registration_and_admin.sql` (Phase 2: Society registration workflow, approve/reject RPCs, admin rights management, logo storage policies)
   - `supabase/migrations/20260101000006_posts_and_events_enhancements.sql` (Phase 3: Public vs members-only RLS, post likes, comments, event interest RSVP, media upload policies)
   - `supabase/migrations/20260101000007_hiring_and_applications_enhancements.sql` (Phase 4: Hiring requirements, custom questions, auto-close pg_cron job, duplicate block, and direct group onboarding)
3. Run `supabase/seed.sql` to populate sample societies, President of ACM, pending AI Club request, sample pinned/public/members-only posts, events, and recruitment questionnaires.

### Step 3: Copy Client API Credentials
1. In the dashboard, go to **Project Settings** (gear icon) -> **API**.
2. Copy:
   - **Project URL** (e.g., `https://xyzcompany.supabase.co`)
   - **anon / public** key (e.g., `eyJhbGciOi...`)
3. Place these into `mobile/lib/core/config/env_config.dart` or `.env`.

---

## 2. Custom SMTP Setup (Brevo / Resend Free Tier)

> **Why is Custom SMTP Mandatory?**
> Supabase's default free built-in email service is capped at **3 to 30 emails per hour** and shares IP reputation across hundreds of projects. For an OTP verification flow during student registrations, the default limit will quickly throttle requests and delay OTPs. Using a dedicated free-tier SMTP provider (300 emails/day on Brevo or 100/day on Resend) guarantees **instant delivery** into students' inboxes.

### Option A: Brevo (Recommended - 300 free emails/day)
1. Sign up for a free account at [brevo.com](https://www.brevo.com).
2. Complete account verification and click on your profile name (top right) -> **SMTP & API**.
3. Under the **SMTP** tab, locate:
   - **SMTP Server**: `smtp-relay.brevo.com`
   - **Port**: `587`
   - **Login**: Your Brevo login email
4. Click **Generate a new SMTP key**, name it `uet-societies-hub`, and copy the generated password.
5. In Supabase Dashboard:
   - Go to **Authentication** -> **SMTP Settings**.
   - Toggle **Enable Custom SMTP** to **ON**.
   - Enter:
     - **Sender email**: `noreply@yourdomain.com` (or verified Brevo sender email)
     - **Sender name**: `UET Societies Hub`
     - **Host**: `smtp-relay.brevo.com`
     - **Port**: `587`
     - **Minimum interval between emails**: `10` seconds
     - **User**: Your Brevo SMTP login
     - **Password**: Your generated Brevo SMTP key
   - Click **Save**.

### Option B: Resend (100 free emails/day)
1. Sign up at [resend.com](https://resend.com).
2. Add your domain or use the sandbox test domain provided.
3. Under **API Keys**, create an API key with sending permissions.
4. In Supabase Dashboard -> **Authentication** -> **SMTP Settings**:
   - **Sender email**: `onboarding@resend.dev` (or your verified domain email)
   - **Sender name**: `UET Societies Hub`
   - **Host**: `smtp.resend.com`
   - **Port**: `465` (or `587`)
   - **User**: `resend`
   - **Password**: Your Resend API key (`re_...`)
   - Click **Save**.

---

## 3. Configuring Auth & Email OTP Templates

1. In Supabase Dashboard, go to **Authentication** -> **Providers** -> **Email**:
   - Ensure **Enable Email provider** is **ON**.
   - Ensure **Confirm email** is **ON**.
   - Ensure **Secure email change** is **ON**.
2. Go to **Authentication** -> **Email Templates** -> **Confirmation**:
   - Change subject to: `{{ .Token }} is your UET Societies Hub Verification Code`
   - Update body template to display the 6-digit code clearly:
     ```html
     <h2>Welcome to UET Societies Hub!</h2>
     <p>Your one-time verification code is:</p>
     <h1 style="font-size: 32px; letter-spacing: 4px; color: #00796B;">{{ .Token }}</h1>
     <p>This code expires in 10 minutes. If you did not request this, please ignore this email.</p>
     ```
3. Go to **Authentication** -> **Email Templates** -> **Reset Password**:
   - Change subject to: `Reset your UET Societies Hub Password`
   - Body:
     ```html
     <h2>Password Reset Request</h2>
     <p>Your password reset code is:</p>
     <h1 style="font-size: 32px; letter-spacing: 4px; color: #00796B;">{{ .Token }}</h1>
     <p>This code expires in 10 minutes.</p>
     ```
4. Click **Save**.

Your Supabase backend is now production-ready, completely free, and configured with strict RLS policies, automated `@uet.edu.pk` domain enforcement, and reliable high-speed email delivery!
