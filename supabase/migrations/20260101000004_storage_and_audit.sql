-- ============================================================================
-- Migration: 20260101000004_storage_and_audit.sql
-- Project: UET Societies Hub
-- Description: Storage buckets setup (5MB cap, MIME allowlist, folder isolation)
--              and automatic audit trail logging triggers.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. STORAGE BUCKETS SETUP
-- ----------------------------------------------------------------------------
-- Insert buckets into storage.buckets if not exists
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
    ('avatars', 'avatars', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp']),
    ('society-assets', 'society-assets', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp']),
    ('post-media', 'post-media', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp']),
    ('resumes', 'resumes', false, 5242880, ARRAY['application/pdf'])
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- ----------------------------------------------------------------------------
-- 2. STORAGE OBJECT POLICIES
-- ----------------------------------------------------------------------------

-- Avatars Policies:
-- Public can view avatars
CREATE POLICY "avatars_select_policy"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

-- User can upload only into their own folder: avatars/{user_id}/*
CREATE POLICY "avatars_insert_policy"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- User can update/delete their own avatar
CREATE POLICY "avatars_update_policy"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "avatars_delete_policy"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Society Assets Policies:
CREATE POLICY "society_assets_select_policy"
ON storage.objects FOR SELECT
USING (bucket_id = 'society-assets');

CREATE POLICY "society_assets_insert_policy"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'society-assets'
    AND public.is_society_admin((storage.foldername(name))[1]::uuid, auth.uid())
);

-- Post Media Policies:
CREATE POLICY "post_media_select_policy"
ON storage.objects FOR SELECT
USING (bucket_id = 'post-media');

CREATE POLICY "post_media_insert_policy"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'post-media'
    AND public.is_society_admin((storage.foldername(name))[1]::uuid, auth.uid())
);

-- Resumes Policies (STRICT PRIVATE STORAGE):
-- Only applicant or authorized hiring reviewer can view resume
CREATE POLICY "resumes_select_policy"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'resumes'
    AND (
        (storage.foldername(name))[1] = auth.uid()::text
        OR public.is_system_admin(auth.uid())
        OR EXISTS (
            SELECT 1 FROM public.applications a
            WHERE a.resume_url LIKE '%' || name
            AND public.is_hiring_manager(a.hiring_id, auth.uid())
        )
    )
);

-- Applicant can only insert into their own folder: resumes/{user_id}/*
CREATE POLICY "resumes_insert_policy"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'resumes'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Applicant can update/delete their own resume
CREATE POLICY "resumes_update_policy"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'resumes'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "resumes_delete_policy"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'resumes'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- ----------------------------------------------------------------------------
-- 3. AUTOMATIC AUDIT LOGGING TRIGGERS (NO PII / NO SECRETS)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.log_society_admin_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO public.audit_log (actor_id, action, entity_type, entity_id, metadata)
        VALUES (
            auth.uid(),
            'ASSIGN_SOCIETY_ADMIN',
            'society_admins',
            NEW.id::text,
            jsonb_build_object('society_id', NEW.society_id, 'assigned_user_id', NEW.user_id, 'role', NEW.role)
        );
    ELSIF (TG_OP = 'DELETE') THEN
        INSERT INTO public.audit_log (actor_id, action, entity_type, entity_id, metadata)
        VALUES (
            auth.uid(),
            'REMOVE_SOCIETY_ADMIN',
            'society_admins',
            OLD.id::text,
            jsonb_build_object('society_id', OLD.society_id, 'removed_user_id', OLD.user_id, 'role', OLD.role)
        );
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_audit_society_admins ON public.society_admins;
CREATE TRIGGER trg_audit_society_admins
AFTER INSERT OR DELETE ON public.society_admins
FOR EACH ROW EXECUTE FUNCTION public.log_society_admin_changes();

-- Application status changes audit
CREATE OR REPLACE FUNCTION public.log_application_status_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF (OLD.status IS DISTINCT FROM NEW.status) THEN
        INSERT INTO public.audit_log (actor_id, action, entity_type, entity_id, metadata)
        VALUES (
            auth.uid(),
            'UPDATE_APPLICATION_STATUS',
            'applications',
            NEW.id::text,
            jsonb_build_object(
                'hiring_id', NEW.hiring_id,
                'position', NEW.position,
                'old_status', OLD.status,
                'new_status', NEW.status
            )
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_audit_application_status ON public.applications;
CREATE TRIGGER trg_audit_application_status
AFTER UPDATE OF status ON public.applications
FOR EACH ROW EXECUTE FUNCTION public.log_application_status_changes();
