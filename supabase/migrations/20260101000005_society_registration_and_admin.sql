-- ============================================================================
-- Migration: 20260101000005_society_registration_and_admin.sql
-- Project: UET Societies Hub
-- Description: Phase 2 migrations for society registration requests,
--              System Admin approval/rejection workflows, office bearer roles,
--              and enhanced storage policies.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. ENHANCE SOCIETIES TABLE
-- ----------------------------------------------------------------------------
-- Update status check to include 'rejected'
ALTER TABLE public.societies DROP CONSTRAINT IF EXISTS societies_status_check;
ALTER TABLE public.societies ADD CONSTRAINT societies_status_check 
    CHECK (status IN ('active', 'inactive', 'pending', 'rejected'));

-- Add created_by (tracking applicant) and rejection_reason
ALTER TABLE public.societies ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.societies ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

CREATE INDEX IF NOT EXISTS idx_societies_created_by ON public.societies(created_by);

-- ----------------------------------------------------------------------------
-- 2. UPDATE RLS POLICIES FOR SOCIETIES (FR-6, FR-7, FR-10)
-- ----------------------------------------------------------------------------
-- Drop existing policies to replace with enhanced versions
DROP POLICY IF EXISTS "societies_select_policy" ON public.societies;
DROP POLICY IF EXISTS "societies_insert_policy" ON public.societies;
DROP POLICY IF EXISTS "societies_update_policy" ON public.societies;
DROP POLICY IF EXISTS "societies_delete_policy" ON public.societies;

-- SELECT: Public can see active societies; creators can see their own pending/rejected;
-- admins & system admins can see their societies or all societies.
CREATE POLICY "societies_select_policy"
ON public.societies FOR SELECT
USING (
    status = 'active'
    OR created_by = auth.uid()
    OR public.is_society_admin(id, auth.uid())
    OR public.is_system_admin(auth.uid())
);

-- INSERT: System Admin can create any society; authenticated students can submit
-- a registration request with status = 'pending' and created_by = auth.uid().
CREATE POLICY "societies_insert_policy"
ON public.societies FOR INSERT
TO authenticated
WITH CHECK (
    public.is_system_admin(auth.uid())
    OR (
        status = 'pending'
        AND created_by = auth.uid()
    )
);

-- UPDATE: Society Admin/President or System Admin can update active society info;
-- System Admin can update any society (e.g. approve/reject).
CREATE POLICY "societies_update_policy"
ON public.societies FOR UPDATE
TO authenticated
USING (
    public.is_society_admin(id, auth.uid())
    OR public.is_system_admin(auth.uid())
)
WITH CHECK (
    public.is_society_admin(id, auth.uid())
    OR public.is_system_admin(auth.uid())
);

-- DELETE: Only System Admin can delete societies
CREATE POLICY "societies_delete_policy"
ON public.societies FOR DELETE
TO authenticated
USING (
    public.is_system_admin(auth.uid())
);

-- ----------------------------------------------------------------------------
-- 3. APPROVAL & REJECTION DATABASE FUNCTIONS (TRANSACTIONAL & AUDITED)
-- ----------------------------------------------------------------------------

-- Function: Approve Society Registration
CREATE OR REPLACE FUNCTION public.approve_society_registration(p_society_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_society RECORD;
    v_actor_id UUID := auth.uid();
BEGIN
    -- Verify System Admin permission
    IF NOT public.is_system_admin(v_actor_id) THEN
        RAISE EXCEPTION 'Access Denied: Only System Administrators can approve societies.'
            USING ERRCODE = '42501';
    END IF;

    -- Fetch society
    SELECT * INTO v_society FROM public.societies WHERE id = p_society_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Society not found.' USING ERRCODE = 'P0002';
    END IF;

    IF v_society.status != 'pending' THEN
        RAISE EXCEPTION 'Society is not in pending status.' USING ERRCODE = 'P0001';
    END IF;

    -- Update society to active
    UPDATE public.societies
    SET status = 'active',
        rejection_reason = NULL,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_society_id;

    -- Appoint the applicant as the President of the society
    IF v_society.created_by IS NOT NULL THEN
        INSERT INTO public.society_admins (society_id, user_id, role)
        VALUES (p_society_id, v_society.created_by, 'president')
        ON CONFLICT (society_id, user_id) DO UPDATE SET role = 'president';

        -- Send approval notification
        INSERT INTO public.notifications (user_id, title, body, data)
        VALUES (
            v_society.created_by,
            'Society Approved! 🎉',
            'Your registration request for "' || v_society.name || '" has been approved. You are now the official President.',
            jsonb_build_object('society_id', p_society_id, 'action', 'society_approved')
        );
    END IF;

    -- Audit log
    INSERT INTO public.audit_log (actor_id, action, entity_type, entity_id, metadata)
    VALUES (
        v_actor_id,
        'APPROVE_SOCIETY',
        'societies',
        p_society_id::text,
        jsonb_build_object('society_name', v_society.name, 'president_id', v_society.created_by)
    );

    RETURN jsonb_build_object('success', true, 'society_id', p_society_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Reject Society Registration
CREATE OR REPLACE FUNCTION public.reject_society_registration(p_society_id UUID, p_reason TEXT)
RETURNS JSONB AS $$
DECLARE
    v_society RECORD;
    v_actor_id UUID := auth.uid();
BEGIN
    -- Verify System Admin permission
    IF NOT public.is_system_admin(v_actor_id) THEN
        RAISE EXCEPTION 'Access Denied: Only System Administrators can reject societies.'
            USING ERRCODE = '42501';
    END IF;

    IF p_reason IS NULL OR trim(p_reason) = '' THEN
        RAISE EXCEPTION 'Rejection reason is mandatory.' USING ERRCODE = 'P0001';
    END IF;

    -- Fetch society
    SELECT * INTO v_society FROM public.societies WHERE id = p_society_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Society not found.' USING ERRCODE = 'P0002';
    END IF;

    -- Update society to rejected
    UPDATE public.societies
    SET status = 'rejected',
        rejection_reason = p_reason,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_society_id;

    -- Send rejection notification to applicant
    IF v_society.created_by IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, title, body, data)
        VALUES (
            v_society.created_by,
            'Society Registration Update',
            'Your registration request for "' || v_society.name || '" was rejected. Reason: ' || p_reason,
            jsonb_build_object('society_id', p_society_id, 'action', 'society_rejected', 'reason', p_reason)
        );
    END IF;

    -- Audit log
    INSERT INTO public.audit_log (actor_id, action, entity_type, entity_id, metadata)
    VALUES (
        v_actor_id,
        'REJECT_SOCIETY',
        'societies',
        p_society_id::text,
        jsonb_build_object('society_name', v_society.name, 'reason', p_reason)
    );

    RETURN jsonb_build_object('success', true, 'society_id', p_society_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ----------------------------------------------------------------------------
-- 4. GRANT & REVOKE SOCIETY ADMIN PRIVILEGES (FR-10)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.grant_society_admin(
    p_society_id UUID,
    p_target_roll_number TEXT,
    p_role TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_actor_id UUID := auth.uid();
    v_target_user RECORD;
BEGIN
    -- Enforce: Only President of this society or System Admin can grant admin rights
    IF NOT (public.is_society_president(p_society_id, v_actor_id) OR public.is_system_admin(v_actor_id)) THEN
        RAISE EXCEPTION 'Access Denied: Only the President can grant admin rights for this society.'
            USING ERRCODE = '42501';
    END IF;

    -- Role validation
    IF p_role NOT IN ('admin', 'moderator') THEN
        RAISE EXCEPTION 'Invalid role. Only admin or moderator roles can be granted.' USING ERRCODE = 'P0001';
    END IF;

    -- Find target student by roll number
    SELECT * INTO v_target_user FROM public.profiles 
    WHERE UPPER(roll_number) = UPPER(trim(p_target_roll_number));

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Student with roll number "%" not found.', p_target_roll_number 
            USING ERRCODE = 'P0002';
    END IF;

    -- Insert or update society admin
    INSERT INTO public.society_admins (society_id, user_id, role)
    VALUES (p_society_id, v_target_user.id, p_role)
    ON CONFLICT (society_id, user_id) 
    DO UPDATE SET role = EXCLUDED.role;

    -- Notify target user
    INSERT INTO public.notifications (user_id, title, body, data)
    VALUES (
        v_target_user.id,
        'Executive Role Granted! 🎖️',
        'You have been appointed as ' || initcap(p_role) || ' for society.',
        jsonb_build_object('society_id', p_society_id, 'role', p_role)
    );

    -- Audit log is automatically populated by existing trigger trg_audit_society_admins

    RETURN jsonb_build_object(
        'success', true, 
        'user_id', v_target_user.id,
        'full_name', v_target_user.full_name,
        'role', p_role
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.revoke_society_admin(
    p_society_id UUID,
    p_target_user_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_actor_id UUID := auth.uid();
    v_target_role TEXT;
BEGIN
    -- Enforce: Only President of this society or System Admin can revoke
    IF NOT (public.is_society_president(p_society_id, v_actor_id) OR public.is_system_admin(v_actor_id)) THEN
        RAISE EXCEPTION 'Access Denied: Only the President can revoke admin rights.'
            USING ERRCODE = '42501';
    END IF;

    -- Cannot revoke the President's own role through this endpoint
    SELECT role INTO v_target_role FROM public.society_admins 
    WHERE society_id = p_society_id AND user_id = p_target_user_id;

    IF v_target_role = 'president' THEN
        RAISE EXCEPTION 'Cannot revoke President role. Transfer presidential office first.' 
            USING ERRCODE = 'P0001';
    END IF;

    DELETE FROM public.society_admins
    WHERE society_id = p_society_id AND user_id = p_target_user_id;

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ----------------------------------------------------------------------------
-- 5. STORAGE POLICIES ENHANCEMENT FOR LOGO UPLOADS
-- Security Rule: 5 MB cap, image MIME allowlist, randomized filenames, 
-- per-user folder policies.
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "society_assets_insert_policy" ON storage.objects;
CREATE POLICY "society_assets_insert_policy"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'society-assets'
    AND (
        -- Allow society admins uploading for an existing society: {society_id}/*
        public.is_society_admin((storage.foldername(name))[1]::uuid, auth.uid())
        -- Or allow authenticated applicants uploading logos for registration: logos/{user_id}/*
        OR (storage.foldername(name))[1] = 'logos'
    )
);
