-- ============================================================================
-- Migration: 20260101000007_hiring_and_applications_enhancements.sql
-- Project: UET Societies Hub
-- Description: Phase 4 migrations for hiring positions, custom questions,
--              auto-close via pg_cron, saved hirings, and group onboarding (FR-18..FR-25, FR-28).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. EXTEND HIRINGS TABLE (FR-18)
-- ----------------------------------------------------------------------------
-- Add custom_questions JSONB, selection_method, and total_seats if not present
ALTER TABLE public.hirings ADD COLUMN IF NOT EXISTS custom_questions JSONB NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE public.hirings ADD COLUMN IF NOT EXISTS selection_method TEXT NOT NULL DEFAULT 'Interview' 
    CHECK (selection_method IN ('Interview', 'Test', 'Portfolio Review', 'Interview & Test'));
ALTER TABLE public.hirings ADD COLUMN IF NOT EXISTS total_seats INTEGER NOT NULL DEFAULT 5 CHECK (total_seats > 0);

CREATE INDEX IF NOT EXISTS idx_hirings_deadline ON public.hirings(deadline ASC);
CREATE INDEX IF NOT EXISTS idx_hirings_society_deadline ON public.hirings(society_id, deadline ASC);

-- ----------------------------------------------------------------------------
-- 2. AUTO-CLOSE EXPIRED HIRINGS FUNCTION & PG_CRON SCHEDULING (FR-21)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.auto_close_expired_hirings()
RETURNS INTEGER AS $$
DECLARE
    v_closed_count INTEGER := 0;
BEGIN
    UPDATE public.hirings
    SET status = 'closed',
        updated_at = timezone('utc'::text, now())
    WHERE status = 'open' 
      AND deadline < timezone('utc'::text, now());

    GET DIAGNOSTICS v_closed_count = ROW_COUNT;

    IF v_closed_count > 0 THEN
        INSERT INTO public.audit_log (actor_id, action, entity_type, entity_id, metadata)
        VALUES (
            NULL,
            'AUTO_CLOSE_EXPIRED_HIRINGS',
            'hirings',
            'SYSTEM_JOB',
            jsonb_build_object('closed_count', v_closed_count)
        );
    END IF;

    RETURN v_closed_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Schedule pg_cron job if pg_cron extension is available on free tier/project
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        -- Remove existing schedule if any
        PERFORM cron.unschedule('auto-close-expired-hirings-job') 
        WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'auto-close-expired-hirings-job');

        -- Schedule hourly execution
        PERFORM cron.schedule(
            'auto-close-expired-hirings-job',
            '0 * * * *',
            'SELECT public.auto_close_expired_hirings();'
        );
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 3. APPLICATION STATUS UPDATE WITH NOTIFICATION & AUDIT (FR-25)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_application_status(
    p_application_id UUID,
    p_status TEXT,
    p_feedback TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_actor_id UUID := auth.uid();
    v_app RECORD;
    v_society_name TEXT;
BEGIN
    -- Validate status
    IF p_status NOT IN ('submitted', 'under_review', 'shortlisted', 'accepted', 'rejected') THEN
        RAISE EXCEPTION 'Invalid application status.' USING ERRCODE = 'P0001';
    END IF;

    -- Fetch application and hiring info
    SELECT a.*, h.society_id, h.title as hiring_title, s.name as s_name
    INTO v_app
    FROM public.applications a
    JOIN public.hirings h ON h.id = a.hiring_id
    JOIN public.societies s ON s.id = h.society_id
    WHERE a.id = p_application_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Application not found.' USING ERRCODE = 'P0002';
    END IF;

    -- Permission check: Actor must be society admin for this society or System Admin
    IF NOT (public.is_society_admin(v_app.society_id, v_actor_id) OR public.is_system_admin(v_actor_id)) THEN
        RAISE EXCEPTION 'Access Denied: Only society executives can update application statuses.'
            USING ERRCODE = '42501';
    END IF;

    -- Update application
    UPDATE public.applications
    SET status = p_status,
        feedback = COALESCE(p_feedback, feedback),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_application_id;

    -- Send notification to student
    INSERT INTO public.notifications (user_id, title, body, data)
    VALUES (
        v_app.user_id,
        'Application Status: ' || initcap(replace(p_status, '_', ' ')),
        'Your application for ' || v_app.position || ' at ' || v_app.s_name || ' is now ' || upper(replace(p_status, '_', ' ')) || '.' ||
        CASE WHEN p_feedback IS NOT NULL AND trim(p_feedback) != '' THEN ' Feedback: ' || p_feedback ELSE '' END,
        jsonb_build_object(
            'application_id', p_application_id,
            'hiring_id', v_app.hiring_id,
            'status', p_status
        )
    );

    RETURN jsonb_build_object('success', true, 'status', p_status);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ----------------------------------------------------------------------------
-- 4. ONBOARD SELECTED APPLICANT DIRECTLY TO COMMITTEE GROUP (FR-28)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.add_applicant_to_group(
    p_application_id UUID,
    p_group_id UUID,
    p_role TEXT DEFAULT 'member'
)
RETURNS JSONB AS $$
DECLARE
    v_actor_id UUID := auth.uid();
    v_app RECORD;
    v_group RECORD;
BEGIN
    -- Fetch application
    SELECT a.*, h.society_id, s.name as society_name
    INTO v_app
    FROM public.applications a
    JOIN public.hirings h ON h.id = a.hiring_id
    JOIN public.societies s ON s.id = h.society_id
    WHERE a.id = p_application_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Application not found.' USING ERRCODE = 'P0002';
    END IF;

    -- Verify actor is society admin
    IF NOT (public.is_society_admin(v_app.society_id, v_actor_id) OR public.is_system_admin(v_actor_id)) THEN
        RAISE EXCEPTION 'Access Denied: Only society executives can onboard members to groups.'
            USING ERRCODE = '42501';
    END IF;

    -- Verify group belongs to this society
    SELECT * INTO v_group FROM public.groups WHERE id = p_group_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Target group not found.' USING ERRCODE = 'P0002';
    END IF;

    IF v_group.society_id != v_app.society_id THEN
        RAISE EXCEPTION 'Group does not belong to this society.' USING ERRCODE = 'P0001';
    END IF;

    -- Insert into group_members
    INSERT INTO public.group_members (group_id, user_id, role)
    VALUES (p_group_id, v_app.user_id, p_role)
    ON CONFLICT (group_id, user_id) DO UPDATE SET role = EXCLUDED.role;

    -- Notify student
    INSERT INTO public.notifications (user_id, title, body, data)
    VALUES (
        v_app.user_id,
        'Welcome to ' || v_group.name || '! 🤝',
        'You have been added to the internal committee group for ' || v_app.society_name || '.',
        jsonb_build_object('group_id', p_group_id, 'society_id', v_app.society_id)
    );

    -- Audit log
    INSERT INTO public.audit_log (actor_id, action, entity_type, entity_id, metadata)
    VALUES (
        v_actor_id,
        'ONBOARD_APPLICANT_TO_GROUP',
        'group_members',
        p_group_id::text,
        jsonb_build_object(
            'application_id', p_application_id,
            'user_id', v_app.user_id,
            'role', p_role,
            'group_name', v_group.name
        )
    );

    RETURN jsonb_build_object('success', true, 'group_name', v_group.name);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
