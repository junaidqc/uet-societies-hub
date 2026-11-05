-- ============================================================================
-- Migration: 20260101000006_posts_and_events_enhancements.sql
-- Project: UET Societies Hub
-- Description: Phase 3 migrations for post visibility (public vs members only),
--              post likes, post comments, event interests, and RLS policies.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. ADD VISIBILITY TO POSTS TABLE (FR-12)
-- ----------------------------------------------------------------------------
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS is_public BOOLEAN NOT NULL DEFAULT TRUE;

CREATE INDEX IF NOT EXISTS idx_posts_is_public ON public.posts(is_public);
CREATE INDEX IF NOT EXISTS idx_posts_is_pinned ON public.posts(is_pinned);

-- ----------------------------------------------------------------------------
-- 2. CREATE POST LIKES TABLE (FR-14)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.post_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    UNIQUE (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_post_likes_post_id ON public.post_likes(post_id);
CREATE INDEX IF NOT EXISTS idx_post_likes_user_id ON public.post_likes(user_id);

-- ----------------------------------------------------------------------------
-- 3. CREATE POST COMMENTS TABLE (FR-14)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.post_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT chk_comment_non_empty CHECK (trim(content) != '')
);

CREATE INDEX IF NOT EXISTS idx_post_comments_post_created ON public.post_comments(post_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_post_comments_user_id ON public.post_comments(user_id);

-- Trigger for updated_at on post_comments
DROP TRIGGER IF EXISTS trg_post_comments_updated_at ON public.post_comments;
CREATE TRIGGER trg_post_comments_updated_at BEFORE UPDATE ON public.post_comments
FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();

-- ----------------------------------------------------------------------------
-- 4. MEMBERSHIP CHECK HELPER FUNCTION (FR-12)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_society_member(p_society_id UUID, p_user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
BEGIN
    IF p_user_id IS NULL THEN
        RETURN FALSE;
    END IF;

    -- System Admin has access to all
    IF public.is_system_admin(p_user_id) THEN
        RETURN TRUE;
    END IF;

    -- Check if user is Society Admin or President
    IF EXISTS (
        SELECT 1 FROM public.society_admins
        WHERE society_id = p_society_id AND user_id = p_user_id
    ) THEN
        RETURN TRUE;
    END IF;

    -- Check if user belongs to any private/public committee group in this society
    IF EXISTS (
        SELECT 1 FROM public.group_members gm
        JOIN public.groups g ON g.id = gm.group_id
        WHERE g.society_id = p_society_id AND gm.user_id = p_user_id
    ) THEN
        RETURN TRUE;
    END IF;

    -- Check if user has an accepted hiring application for this society
    IF EXISTS (
        SELECT 1 FROM public.applications a
        JOIN public.hirings h ON h.id = a.hiring_id
        WHERE h.society_id = p_society_id AND a.user_id = p_user_id AND a.status = 'accepted'
    ) THEN
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ----------------------------------------------------------------------------
-- 5. RLS POLICIES FOR POSTS (ENFORCE PUBLIC VS MEMBERS ONLY)
-- ----------------------------------------------------------------------------
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "posts_select_policy" ON public.posts;

-- SELECT: Public posts viewable by everyone (Guests & Students).
-- Members-only posts viewable ONLY by members/admins of that society or System Admin.
CREATE POLICY "posts_select_policy"
ON public.posts FOR SELECT
USING (
    is_public = TRUE
    OR (
        auth.uid() IS NOT NULL
        AND (
            public.is_society_member(society_id, auth.uid())
            OR public.is_society_admin(society_id, auth.uid())
            OR public.is_system_admin(auth.uid())
        )
    )
);

-- ----------------------------------------------------------------------------
-- 6. RLS POLICIES FOR EVENTS (ENFORCE PUBLIC VS MEMBERS ONLY)
-- ----------------------------------------------------------------------------
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "events_select_policy" ON public.events;

CREATE POLICY "events_select_policy"
ON public.events FOR SELECT
USING (
    is_public = TRUE
    OR (
        auth.uid() IS NOT NULL
        AND (
            public.is_society_member(society_id, auth.uid())
            OR public.is_society_admin(society_id, auth.uid())
            OR public.is_system_admin(auth.uid())
        )
    )
);

-- ----------------------------------------------------------------------------
-- 7. RLS POLICIES FOR POST LIKES & COMMENTS (DEFAULT DENY)
-- ----------------------------------------------------------------------------
ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "post_likes_select_policy"
ON public.post_likes FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.posts p
        WHERE p.id = post_likes.post_id
        AND (
            p.is_public = TRUE
            OR (auth.uid() IS NOT NULL AND public.is_society_member(p.society_id, auth.uid()))
        )
    )
);

CREATE POLICY "post_likes_insert_policy"
ON public.post_likes FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
        SELECT 1 FROM public.posts p
        WHERE p.id = post_likes.post_id
        AND (
            p.is_public = TRUE
            OR public.is_society_member(p.society_id, auth.uid())
        )
    )
);

CREATE POLICY "post_likes_delete_policy"
ON public.post_likes FOR DELETE
TO authenticated
USING (
    auth.uid() = user_id
);

-- Post Comments Policies
ALTER TABLE public.post_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "post_comments_select_policy"
ON public.post_comments FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.posts p
        WHERE p.id = post_comments.post_id
        AND (
            p.is_public = TRUE
            OR (auth.uid() IS NOT NULL AND public.is_society_member(p.society_id, auth.uid()))
        )
    )
);

CREATE POLICY "post_comments_insert_policy"
ON public.post_comments FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
        SELECT 1 FROM public.posts p
        WHERE p.id = post_comments.post_id
        AND (
            p.is_public = TRUE
            OR public.is_society_member(p.society_id, auth.uid())
        )
    )
);

CREATE POLICY "post_comments_update_policy"
ON public.post_comments FOR UPDATE
TO authenticated
USING (
    auth.uid() = user_id
)
WITH CHECK (
    auth.uid() = user_id
);

CREATE POLICY "post_comments_delete_policy"
ON public.post_comments FOR DELETE
TO authenticated
USING (
    auth.uid() = user_id
    OR EXISTS (
        SELECT 1 FROM public.posts p
        WHERE p.id = post_comments.post_id
        AND public.is_society_admin(p.society_id, auth.uid())
    )
);

-- ----------------------------------------------------------------------------
-- 8. STORAGE POLICY FOR POST MEDIA
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "post_media_insert_policy" ON storage.objects;
CREATE POLICY "post_media_insert_policy"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'post-media'
    AND (
        -- Allow society admins to upload to post-media/{society_id}/*
        public.is_society_admin((storage.foldername(name))[1]::uuid, auth.uid())
        -- Or allow under their user_id
        OR (storage.foldername(name))[1] = auth.uid()::text
    )
);
