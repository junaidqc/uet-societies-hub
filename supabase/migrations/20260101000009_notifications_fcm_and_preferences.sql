-- ============================================================================
-- Migration: 20260101000009_notifications_fcm_and_preferences.sql
-- Project: UET Societies Hub
-- Description: Phase 7: FCM Push Notifications, Notification Preferences (Per-Society/Group Mute),
--              and Deadline Reminders.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. NOTIFICATION PREFERENCES TABLE (FR-36, FR-37)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notification_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    society_id UUID REFERENCES public.societies(id) ON DELETE CASCADE,
    group_id UUID REFERENCES public.groups(id) ON DELETE CASCADE,
    is_muted BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT chk_pref_target CHECK (society_id IS NOT NULL OR group_id IS NOT NULL),
    UNIQUE (user_id, society_id, group_id)
);

CREATE INDEX IF NOT EXISTS idx_notif_pref_user ON public.notification_preferences(user_id);

-- RLS
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notif_pref_select_policy"
ON public.notification_preferences FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "notif_pref_insert_policy"
ON public.notification_preferences FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "notif_pref_update_policy"
ON public.notification_preferences FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "notif_pref_delete_policy"
ON public.notification_preferences FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- 2. HELPER FUNCTION TO CHECK IF TARGET IS MUTED
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_notification_muted(
    p_user_id UUID,
    p_society_id UUID DEFAULT NULL,
    p_group_id UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.notification_preferences
        WHERE user_id = p_user_id
          AND is_muted = TRUE
          AND (
              (p_society_id IS NOT NULL AND society_id = p_society_id)
              OR (p_group_id IS NOT NULL AND group_id = p_group_id)
          )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ----------------------------------------------------------------------------
-- 3. HIRING DEADLINE REMINDER (1 DAY BEFORE) VIA PG_CRON
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.dispatch_hiring_deadline_reminders()
RETURNS INTEGER AS $$
DECLARE
    v_rec RECORD;
    v_count INTEGER := 0;
BEGIN
    FOR v_rec IN (
        SELECT h.id as hiring_id, h.title, s.name as society_name, sh.user_id
        FROM public.hirings h
        JOIN public.societies s ON s.id = h.society_id
        JOIN public.saved_hirings sh ON sh.hiring_id = h.id
        WHERE h.status = 'open'
          AND h.deadline > timezone('utc'::text, now())
          AND h.deadline <= timezone('utc'::text, now() + interval '24 hours')
    ) LOOP
        -- Send in-app notification if not muted
        IF NOT public.is_notification_muted(v_rec.user_id, NULL, NULL) THEN
            INSERT INTO public.notifications (user_id, title, body, data)
            VALUES (
                v_rec.user_id,
                '⏰ Deadline Tomorrow: ' || v_rec.title,
                'Recruitment for ' || v_rec.society_name || ' closes within 24 hours. Submit your application now!',
                jsonb_build_object('hiring_id', v_rec.hiring_id, 'type', 'deadline_reminder')
            );
            v_count := v_count + 1;
        END IF;
    END LOOP;

    RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Schedule daily check at 08:00 AM (03:00 UTC)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        PERFORM cron.unschedule('daily-hiring-deadline-reminders')
        WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'daily-hiring-deadline-reminders');

        PERFORM cron.schedule(
            'daily-hiring-deadline-reminders',
            '0 3 * * *',
            'SELECT public.dispatch_hiring_deadline_reminders();'
        );
    END IF;
END $$;
