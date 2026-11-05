-- ============================================================================
-- Migration: 20260101000010_reports_and_moderation.sql
-- Project: UET Societies Hub
-- Description: Phase 8: Moderation & System Admin Dashboard (FR-38..FR-40).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. EXTEND REPORTS TABLE
-- ----------------------------------------------------------------------------
ALTER TABLE public.reports ADD COLUMN IF NOT EXISTS admin_notes TEXT;
ALTER TABLE public.reports ADD COLUMN IF NOT EXISTS resolved_by UUID REFERENCES public.profiles(id);
ALTER TABLE public.reports ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMPTZ;

-- ----------------------------------------------------------------------------
-- 2. SYSTEM ADMIN DASHBOARD METRICS (FR-38..FR-40)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_system_dashboard_metrics()
RETURNS JSONB AS $$
DECLARE
    v_actor_id UUID := auth.uid();
    v_total_users INT;
    v_total_societies INT;
    v_total_posts INT;
    v_active_hirings INT;
    v_pending_reports INT;
BEGIN
    IF NOT public.is_system_admin(v_actor_id) THEN
        RAISE EXCEPTION 'Access Denied: System Admin only.' USING ERRCODE = '42501';
    END IF;

    SELECT count(*) INTO v_total_users FROM public.profiles;
    SELECT count(*) INTO v_total_societies FROM public.societies WHERE status = 'active';
    SELECT count(*) INTO v_total_posts FROM public.posts;
    SELECT count(*) INTO v_active_hirings FROM public.hirings WHERE status = 'open';
    SELECT count(*) INTO v_pending_reports FROM public.reports WHERE status = 'pending';

    RETURN jsonb_build_object(
        'total_users', v_total_users,
        'total_societies', v_total_societies,
        'total_posts', v_total_posts,
        'active_hirings', v_active_hirings,
        'pending_reports', v_pending_reports
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ----------------------------------------------------------------------------
-- 3. ADMINISTRATIVE MODERATION RPC FUNCTIONS
-- ----------------------------------------------------------------------------
-- Resolve or Dismiss a Report
CREATE OR REPLACE FUNCTION public.resolve_report(
    p_report_id UUID,
    p_status TEXT,
    p_admin_notes TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_actor_id UUID := auth.uid();
BEGIN
    IF NOT public.is_system_admin(v_actor_id) THEN
        RAISE EXCEPTION 'Access Denied.' USING ERRCODE = '42501';
    END IF;

    UPDATE public.reports
    SET status = p_status,
        admin_notes = p_admin_notes,
        resolved_by = v_actor_id,
        resolved_at = timezone('utc'::text, now())
    WHERE id = p_report_id;

    INSERT INTO public.audit_log (actor_id, action, entity_type, entity_id, metadata)
    VALUES (
        v_actor_id,
        'RESOLVE_REPORT',
        'reports',
        p_report_id::text,
        jsonb_build_object('status', p_status, 'notes', p_admin_notes)
    );

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Delete Reported Content (Post / Message / Event)
CREATE OR REPLACE FUNCTION public.delete_reported_content(
    p_report_id UUID,
    p_reason TEXT DEFAULT 'Violated UET Community Guidelines'
)
RETURNS JSONB AS $$
DECLARE
    v_actor_id UUID := auth.uid();
    v_report RECORD;
BEGIN
    IF NOT public.is_system_admin(v_actor_id) THEN
        RAISE EXCEPTION 'Access Denied.' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_report FROM public.reports WHERE id = p_report_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Report not found.' USING ERRCODE = 'P0002';
    END IF;

    IF v_report.target_type = 'post' THEN
        DELETE FROM public.posts WHERE id = v_report.target_id;
    ELSIF v_report.target_type = 'message' THEN
        DELETE FROM public.group_messages WHERE id = v_report.target_id;
    ELSIF v_report.target_type = 'event' THEN
        DELETE FROM public.events WHERE id = v_report.target_id;
    END IF;

    -- Mark report as resolved
    UPDATE public.reports
    SET status = 'resolved',
        admin_notes = 'Content deleted by administrator. Reason: ' || p_reason,
        resolved_by = v_actor_id,
        resolved_at = timezone('utc'::text, now())
    WHERE id = p_report_id;

    -- Audit log
    INSERT INTO public.audit_log (actor_id, action, entity_type, entity_id, metadata)
    VALUES (
        v_actor_id,
        'DELETE_REPORTED_CONTENT',
        v_report.target_type,
        v_report.target_id::text,
        jsonb_build_object('report_id', p_report_id, 'reason', p_reason)
    );

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Suspend Society
CREATE OR REPLACE FUNCTION public.suspend_society(
    p_society_id UUID,
    p_reason TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_actor_id UUID := auth.uid();
BEGIN
    IF NOT public.is_system_admin(v_actor_id) THEN
        RAISE EXCEPTION 'Access Denied.' USING ERRCODE = '42501';
    END IF;

    UPDATE public.societies
    SET status = 'inactive',
        rejection_reason = p_reason,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_society_id;

    INSERT INTO public.audit_log (actor_id, action, entity_type, entity_id, metadata)
    VALUES (
        v_actor_id,
        'SUSPEND_SOCIETY',
        'societies',
        p_society_id::text,
        jsonb_build_object('reason', p_reason)
    );

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
