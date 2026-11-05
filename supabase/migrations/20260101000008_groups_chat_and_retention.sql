-- ============================================================================
-- Migration: 20260101000008_groups_chat_and_retention.sql
-- Project: UET Societies Hub
-- Description: Phase 5 & 5b: Groups, Realtime Chat, Notices, Polls, Tasks,
--              Member Removal/Permanent Ban, and Retention Cleanup.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. EXTEND GROUPS & MEMBERS
-- ----------------------------------------------------------------------------
-- Ensure banned/removed members cannot re-enter (FR-31)
CREATE TABLE IF NOT EXISTS public.group_banned_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    banned_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    UNIQUE (group_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_group_banned_group_user ON public.group_banned_users(group_id, user_id);

-- ----------------------------------------------------------------------------
-- 2. EXTEND GROUP MESSAGES (FR-27, FR-29, FR-30, FR-32, Phase 5b)
-- ----------------------------------------------------------------------------
-- Add message_type, attachment_path (for cleanup), poll_data, task_data
ALTER TABLE public.group_messages ADD COLUMN IF NOT EXISTS message_type TEXT NOT NULL DEFAULT 'text'
    CHECK (message_type IN ('text', 'image', 'document', 'notice', 'poll', 'task'));

-- Storing storage path explicitly on group_messages so files can be found & removed during retention cleanup
ALTER TABLE public.group_messages ADD COLUMN IF NOT EXISTS attachment_path TEXT;
ALTER TABLE public.group_messages ADD COLUMN IF NOT EXISTS poll_data JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.group_messages ADD COLUMN IF NOT EXISTS task_data JSONB DEFAULT '{}'::jsonb;

-- Retention Cleanup Indexes (Phase 5b requirement 4)
CREATE INDEX IF NOT EXISTS idx_group_messages_created_at ON public.group_messages(created_at ASC);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at ASC);
CREATE INDEX IF NOT EXISTS idx_group_messages_attachment_path ON public.group_messages(attachment_path) WHERE attachment_path IS NOT NULL;

-- ----------------------------------------------------------------------------
-- 3. STORAGE BUCKET FOR CHAT ATTACHMENTS (5 MB cap, image & doc allowlist)
-- ----------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'chat-attachments',
    'chat-attachments',
    false, -- Private!
    5242880, -- 5 MB cap
    ARRAY[
        'image/jpeg',
        'image/png',
        'image/webp',
        'application/pdf',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'text/plain'
    ]
)
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Storage Policies for chat-attachments
DROP POLICY IF EXISTS "chat_attachments_select_policy" ON storage.objects;
CREATE POLICY "chat_attachments_select_policy"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'chat-attachments'
    AND public.is_group_member((storage.foldername(name))[1]::uuid, auth.uid())
);

DROP POLICY IF EXISTS "chat_attachments_insert_policy" ON storage.objects;
CREATE POLICY "chat_attachments_insert_policy"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'chat-attachments'
    AND public.is_group_member((storage.foldername(name))[1]::uuid, auth.uid())
);

DROP POLICY IF EXISTS "chat_attachments_delete_policy" ON storage.objects;
CREATE POLICY "chat_attachments_delete_policy"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'chat-attachments'
    AND (
        (storage.foldername(name))[2] = auth.uid()::text
        OR public.is_system_admin(auth.uid())
    )
);

-- ----------------------------------------------------------------------------
-- 4. RLS POLICIES FOR GROUPS & MESSAGES (STRICT ZERO-TRUST PRIVACY)
-- ----------------------------------------------------------------------------
-- Drop and recreate to guarantee zero-leakage
DROP POLICY IF EXISTS "groups_select_policy" ON public.groups;
CREATE POLICY "groups_select_policy"
ON public.groups FOR SELECT
TO authenticated
USING (
    public.is_group_member(id, auth.uid())
    OR public.is_society_admin(society_id, auth.uid())
    OR public.is_system_admin(auth.uid())
);

DROP POLICY IF EXISTS "group_members_select_policy" ON public.group_members;
CREATE POLICY "group_members_select_policy"
ON public.group_members FOR SELECT
TO authenticated
USING (
    public.is_group_member(group_id, auth.uid())
    OR public.is_system_admin(auth.uid())
);

DROP POLICY IF EXISTS "group_messages_select_policy" ON public.group_messages;
CREATE POLICY "group_messages_select_policy"
ON public.group_messages FOR SELECT
TO authenticated
USING (
    public.is_group_member(group_id, auth.uid())
);

DROP POLICY IF EXISTS "group_messages_insert_policy" ON public.group_messages;
CREATE POLICY "group_messages_insert_policy"
ON public.group_messages FOR INSERT
TO authenticated
WITH CHECK (
    sender_id = auth.uid()
    AND public.is_group_member(group_id, auth.uid())
    AND NOT EXISTS (
        SELECT 1 FROM public.group_banned_users 
        WHERE group_id = group_messages.group_id AND user_id = auth.uid()
    )
);

-- ----------------------------------------------------------------------------
-- 5. RPC FUNCTIONS FOR GROUP LEAVE, MEMBER REMOVAL & PERMANENT BAN (FR-31)
-- ----------------------------------------------------------------------------
-- Leave Group (FR-31)
CREATE OR REPLACE FUNCTION public.leave_group(p_group_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    DELETE FROM public.group_members
    WHERE group_id = p_group_id AND user_id = v_user_id;

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Remove Member and Permanently Ban from Re-entering (FR-31)
CREATE OR REPLACE FUNCTION public.remove_group_member(
    p_group_id UUID,
    p_target_user_id UUID,
    p_permanent_block BOOLEAN DEFAULT TRUE,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_actor_id UUID := auth.uid();
    v_society_id UUID;
BEGIN
    SELECT society_id INTO v_society_id FROM public.groups WHERE id = p_group_id;

    -- Verify actor is society admin or system admin
    IF NOT (public.is_society_admin(v_society_id, v_actor_id) OR public.is_system_admin(v_actor_id)) THEN
        RAISE EXCEPTION 'Access Denied: Only group/society administrators can remove members.'
            USING ERRCODE = '42501';
    END IF;

    -- Delete from group members
    DELETE FROM public.group_members
    WHERE group_id = p_group_id AND user_id = p_target_user_id;

    -- If permanent block, record in group_banned_users to prevent re-entering
    IF p_permanent_block THEN
        INSERT INTO public.group_banned_users (group_id, user_id, banned_by, reason)
        VALUES (p_group_id, p_target_user_id, v_actor_id, p_reason)
        ON CONFLICT (group_id, user_id) DO UPDATE 
        SET reason = EXCLUDED.reason, created_at = timezone('utc'::text, now());
    END IF;

    -- Audit log
    INSERT INTO public.audit_log (actor_id, action, entity_type, entity_id, metadata)
    VALUES (
        v_actor_id,
        'REMOVE_GROUP_MEMBER',
        'group_members',
        p_group_id::text,
        jsonb_build_object('target_user_id', p_target_user_id, 'permanent_ban', p_permanent_block, 'reason', p_reason)
    );

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Vote on Poll
CREATE OR REPLACE FUNCTION public.vote_poll(
    p_message_id UUID,
    p_option_index INT
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_msg RECORD;
    v_poll JSONB;
    v_options JSONB;
    v_votes JSONB;
    v_user_id_str TEXT := v_user_id::text;
BEGIN
    SELECT * INTO v_msg FROM public.group_messages WHERE id = p_message_id;
    IF NOT FOUND OR v_msg.message_type != 'poll' THEN
        RAISE EXCEPTION 'Poll not found.' USING ERRCODE = 'P0002';
    END IF;

    -- Verify membership
    IF NOT public.is_group_member(v_msg.group_id, v_user_id) THEN
        RAISE EXCEPTION 'Access Denied: Only group members can vote.' USING ERRCODE = '42501';
    END IF;

    v_poll := v_msg.poll_data;
    v_votes := COALESCE(v_poll->'votes', '{}'::jsonb);

    -- Record user's choice (maps user_id -> option_index)
    v_votes := jsonb_set(v_votes, ARRAY[v_user_id_str], to_jsonb(p_option_index));
    v_poll := jsonb_set(v_poll, '{votes}', v_votes);

    UPDATE public.group_messages
    SET poll_data = v_poll
    WHERE id = p_message_id;

    RETURN jsonb_build_object('success', true, 'poll_data', v_poll);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Toggle Task Completion
CREATE OR REPLACE FUNCTION public.toggle_task_completion(p_message_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_msg RECORD;
    v_task JSONB;
    v_completed BOOLEAN;
BEGIN
    SELECT * INTO v_msg FROM public.group_messages WHERE id = p_message_id;
    IF NOT FOUND OR v_msg.message_type != 'task' THEN
        RAISE EXCEPTION 'Task not found.' USING ERRCODE = 'P0002';
    END IF;

    IF NOT public.is_group_member(v_msg.group_id, v_user_id) THEN
        RAISE EXCEPTION 'Access Denied.' USING ERRCODE = '42501';
    END IF;

    v_task := v_msg.task_data;
    v_completed := NOT COALESCE((v_task->>'is_completed')::boolean, false);
    v_task := jsonb_set(v_task, '{is_completed}', to_jsonb(v_completed));

    UPDATE public.group_messages
    SET task_data = v_task
    WHERE id = p_message_id;

    RETURN jsonb_build_object('success', true, 'is_completed', v_completed);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ----------------------------------------------------------------------------
-- 6. VAULT & PG_CRON SCHEDULER SETUP FOR DATA RETENTION (Phase 5b Requirement 3)
-- Calls Edge Function cleanup-old-data daily at 03:00 Asia/Karachi (22:00 UTC)
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    -- Ensure pg_net extension is available for HTTP requests
    CREATE EXTENSION IF NOT EXISTS "pg_net";

    -- Create or verify scheduled cron job
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        PERFORM cron.unschedule('daily-data-retention-cleanup')
        WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'daily-data-retention-cleanup');

        -- 22:00 UTC corresponds to 03:00 AM Asia/Karachi PKT
        PERFORM cron.schedule(
            'daily-data-retention-cleanup',
            '0 22 * * *',
            $cron$
            SELECT net.http_post(
                url := coalesce(current_setting('app.settings.edge_function_url', true), 'https://your-project.supabase.co/functions/v1/cleanup-old-data'),
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'Authorization', 'Bearer ' || coalesce(current_setting('app.settings.service_role_key', true), ''),
                    'x-cron-secret', coalesce(current_setting('app.settings.cron_secret', true), '')
                ),
                body := '{}'::jsonb
            );
            $cron$
        );
    END IF;
END $$;
