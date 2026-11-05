-- ============================================================================
-- Migration: 20260101000003_rls_policies.sql
-- Project: UET Societies Hub
-- Description: Complete Row Level Security (RLS) policies for ALL tables.
--              Default deny enforced on every table. IDOR prevention strictly baked in.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. ENABLE RLS ON ALL TABLES (DEFAULT DENY)
-- ----------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.societies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.society_admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_interests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hirings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_hirings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- 2. PROFILES POLICIES
-- ----------------------------------------------------------------------------
-- Anyone can view profiles (needed for author display, society admins, community)
CREATE POLICY "profiles_select_policy"
ON public.profiles FOR SELECT
USING (true);

-- Users can update only their own profile; cannot elevate is_system_admin
CREATE POLICY "profiles_update_policy"
ON public.profiles FOR UPDATE
TO authenticated
USING (
    auth.uid() = id OR public.is_system_admin(auth.uid())
)
WITH CHECK (
    (auth.uid() = id AND is_system_admin = (SELECT is_system_admin FROM public.profiles WHERE id = auth.uid()))
    OR public.is_system_admin(auth.uid())
);

CREATE POLICY "profiles_delete_policy"
ON public.profiles FOR DELETE
TO authenticated
USING (
    auth.uid() = id OR public.is_system_admin(auth.uid())
);

-- ----------------------------------------------------------------------------
-- 3. SOCIETIES POLICIES
-- ----------------------------------------------------------------------------
-- Public/Guest can view active societies; admins can view draft/pending societies
CREATE POLICY "societies_select_policy"
ON public.societies FOR SELECT
USING (
    status = 'active'
    OR public.is_society_admin(id, auth.uid())
    OR public.is_system_admin(auth.uid())
);

-- Only System Admin can create new societies
CREATE POLICY "societies_insert_policy"
ON public.societies FOR INSERT
TO authenticated
WITH CHECK (
    public.is_system_admin(auth.uid())
);

-- Society President, Society Admin, or System Admin can update society profile
CREATE POLICY "societies_update_policy"
ON public.societies FOR UPDATE
TO authenticated
USING (
    public.is_society_admin(id, auth.uid())
)
WITH CHECK (
    public.is_society_admin(id, auth.uid())
);

-- Only System Admin can delete societies
CREATE POLICY "societies_delete_policy"
ON public.societies FOR DELETE
TO authenticated
USING (
    public.is_system_admin(auth.uid())
);

-- ----------------------------------------------------------------------------
-- 4. SOCIETY ADMINS POLICIES
-- ----------------------------------------------------------------------------
CREATE POLICY "society_admins_select_policy"
ON public.society_admins FOR SELECT
USING (true);

CREATE POLICY "society_admins_insert_policy"
ON public.society_admins FOR INSERT
TO authenticated
WITH CHECK (
    public.is_society_president(society_id, auth.uid())
);

CREATE POLICY "society_admins_update_policy"
ON public.society_admins FOR UPDATE
TO authenticated
USING (
    public.is_society_president(society_id, auth.uid())
);

CREATE POLICY "society_admins_delete_policy"
ON public.society_admins FOR DELETE
TO authenticated
USING (
    public.is_society_president(society_id, auth.uid())
);

-- ----------------------------------------------------------------------------
-- 5. FOLLOWS POLICIES
-- ----------------------------------------------------------------------------
CREATE POLICY "follows_select_policy"
ON public.follows FOR SELECT
USING (
    auth.uid() = user_id OR public.is_society_admin(society_id, auth.uid())
);

CREATE POLICY "follows_insert_policy"
ON public.follows FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = user_id
);

CREATE POLICY "follows_delete_policy"
ON public.follows FOR DELETE
TO authenticated
USING (
    auth.uid() = user_id
);

-- ----------------------------------------------------------------------------
-- 6. POSTS POLICIES
-- ----------------------------------------------------------------------------
-- Public feed reading (Guest & Student access)
CREATE POLICY "posts_select_policy"
ON public.posts FOR SELECT
USING (true);

-- Only Society Admin or President can create posts for their society
CREATE POLICY "posts_insert_policy"
ON public.posts FOR INSERT
TO authenticated
WITH CHECK (
    public.is_society_admin(society_id, auth.uid())
    AND author_id = auth.uid()
);

CREATE POLICY "posts_update_policy"
ON public.posts FOR UPDATE
TO authenticated
USING (
    public.is_society_admin(society_id, auth.uid())
)
WITH CHECK (
    public.is_society_admin(society_id, auth.uid())
);

CREATE POLICY "posts_delete_policy"
ON public.posts FOR DELETE
TO authenticated
USING (
    public.is_society_admin(society_id, auth.uid())
);

-- ----------------------------------------------------------------------------
-- 7. EVENTS POLICIES
-- ----------------------------------------------------------------------------
CREATE POLICY "events_select_policy"
ON public.events FOR SELECT
USING (
    is_public = TRUE OR public.is_society_admin(society_id, auth.uid())
);

CREATE POLICY "events_insert_policy"
ON public.events FOR INSERT
TO authenticated
WITH CHECK (
    public.is_society_admin(society_id, auth.uid())
);

CREATE POLICY "events_update_policy"
ON public.events FOR UPDATE
TO authenticated
USING (
    public.is_society_admin(society_id, auth.uid())
);

CREATE POLICY "events_delete_policy"
ON public.events FOR DELETE
TO authenticated
USING (
    public.is_society_admin(society_id, auth.uid())
);

-- ----------------------------------------------------------------------------
-- 8. EVENT INTERESTS POLICIES
-- ----------------------------------------------------------------------------
CREATE POLICY "event_interests_select_policy"
ON public.event_interests FOR SELECT
USING (true);

CREATE POLICY "event_interests_insert_policy"
ON public.event_interests FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = user_id
);

CREATE POLICY "event_interests_update_policy"
ON public.event_interests FOR UPDATE
TO authenticated
USING (
    auth.uid() = user_id
);

CREATE POLICY "event_interests_delete_policy"
ON public.event_interests FOR DELETE
TO authenticated
USING (
    auth.uid() = user_id
);

-- ----------------------------------------------------------------------------
-- 9. HIRINGS POLICIES
-- ----------------------------------------------------------------------------
CREATE POLICY "hirings_select_policy"
ON public.hirings FOR SELECT
USING (
    status = 'open' OR public.is_society_admin(society_id, auth.uid())
);

CREATE POLICY "hirings_insert_policy"
ON public.hirings FOR INSERT
TO authenticated
WITH CHECK (
    public.is_society_admin(society_id, auth.uid())
);

CREATE POLICY "hirings_update_policy"
ON public.hirings FOR UPDATE
TO authenticated
USING (
    public.is_society_admin(society_id, auth.uid())
);

CREATE POLICY "hirings_delete_policy"
ON public.hirings FOR DELETE
TO authenticated
USING (
    public.is_society_admin(society_id, auth.uid())
);

-- ----------------------------------------------------------------------------
-- 10. APPLICATIONS POLICIES (Strict IDOR Prevention)
-- ----------------------------------------------------------------------------
-- Students see only their own applications; Society Admins see applications for their hiring
CREATE POLICY "applications_select_policy"
ON public.applications FOR SELECT
TO authenticated
USING (
    user_id = auth.uid() OR public.is_hiring_manager(hiring_id, auth.uid())
);

-- Students can insert applications for themselves only
CREATE POLICY "applications_insert_policy"
ON public.applications FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = user_id
);

-- Only hiring managers can update application status and feedback
-- Applicants can update their submission ONLY while in 'submitted' status
CREATE POLICY "applications_update_policy"
ON public.applications FOR UPDATE
TO authenticated
USING (
    (auth.uid() = user_id AND status = 'submitted')
    OR public.is_hiring_manager(hiring_id, auth.uid())
)
WITH CHECK (
    (auth.uid() = user_id AND status = 'submitted')
    OR public.is_hiring_manager(hiring_id, auth.uid())
);

CREATE POLICY "applications_delete_policy"
ON public.applications FOR DELETE
TO authenticated
USING (
    (auth.uid() = user_id AND status = 'submitted')
    OR public.is_system_admin(auth.uid())
);

-- ----------------------------------------------------------------------------
-- 11. SAVED HIRINGS POLICIES
-- ----------------------------------------------------------------------------
CREATE POLICY "saved_hirings_select_policy"
ON public.saved_hirings FOR SELECT
TO authenticated
USING (
    auth.uid() = user_id
);

CREATE POLICY "saved_hirings_insert_policy"
ON public.saved_hirings FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = user_id
);

CREATE POLICY "saved_hirings_delete_policy"
ON public.saved_hirings FOR DELETE
TO authenticated
USING (
    auth.uid() = user_id
);

-- ----------------------------------------------------------------------------
-- 12. GROUPS POLICIES (Private committee groups)
-- ----------------------------------------------------------------------------
CREATE POLICY "groups_select_policy"
ON public.groups FOR SELECT
TO authenticated
USING (
    is_private = FALSE OR public.is_group_member(id, auth.uid())
);

CREATE POLICY "groups_insert_policy"
ON public.groups FOR INSERT
TO authenticated
WITH CHECK (
    public.is_society_admin(society_id, auth.uid())
);

CREATE POLICY "groups_update_policy"
ON public.groups FOR UPDATE
TO authenticated
USING (
    public.is_society_admin(society_id, auth.uid())
);

CREATE POLICY "groups_delete_policy"
ON public.groups FOR DELETE
TO authenticated
USING (
    public.is_society_admin(society_id, auth.uid())
);

-- ----------------------------------------------------------------------------
-- 13. GROUP MEMBERS POLICIES
-- ----------------------------------------------------------------------------
CREATE POLICY "group_members_select_policy"
ON public.group_members FOR SELECT
TO authenticated
USING (
    public.is_group_member(group_id, auth.uid())
);

CREATE POLICY "group_members_insert_policy"
ON public.group_members FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.groups g
        WHERE g.id = group_id AND public.is_society_admin(g.society_id, auth.uid())
    )
);

CREATE POLICY "group_members_delete_policy"
ON public.group_members FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.groups g
        WHERE g.id = group_id AND public.is_society_admin(g.society_id, auth.uid())
    )
    OR auth.uid() = user_id
);

-- ----------------------------------------------------------------------------
-- 14. GROUP MESSAGES POLICIES (Strict chat privacy)
-- ----------------------------------------------------------------------------
CREATE POLICY "group_messages_select_policy"
ON public.group_messages FOR SELECT
TO authenticated
USING (
    public.is_group_member(group_id, auth.uid())
);

CREATE POLICY "group_messages_insert_policy"
ON public.group_messages FOR INSERT
TO authenticated
WITH CHECK (
    public.is_group_member(group_id, auth.uid())
    AND sender_id = auth.uid()
);

CREATE POLICY "group_messages_update_policy"
ON public.group_messages FOR UPDATE
TO authenticated
USING (
    sender_id = auth.uid()
);

CREATE POLICY "group_messages_delete_policy"
ON public.group_messages FOR DELETE
TO authenticated
USING (
    sender_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.groups g
        WHERE g.id = group_id AND public.is_society_admin(g.society_id, auth.uid())
    )
);

-- ----------------------------------------------------------------------------
-- 15. NOTIFICATIONS POLICIES
-- ----------------------------------------------------------------------------
CREATE POLICY "notifications_select_policy"
ON public.notifications FOR SELECT
TO authenticated
USING (
    auth.uid() = user_id
);

CREATE POLICY "notifications_update_policy"
ON public.notifications FOR UPDATE
TO authenticated
USING (
    auth.uid() = user_id
)
WITH CHECK (
    auth.uid() = user_id
);

CREATE POLICY "notifications_delete_policy"
ON public.notifications FOR DELETE
TO authenticated
USING (
    auth.uid() = user_id
);

-- ----------------------------------------------------------------------------
-- 16. DEVICE TOKENS POLICIES
-- ----------------------------------------------------------------------------
CREATE POLICY "device_tokens_select_policy"
ON public.device_tokens FOR SELECT
TO authenticated
USING (
    auth.uid() = user_id
);

CREATE POLICY "device_tokens_insert_policy"
ON public.device_tokens FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = user_id
);

CREATE POLICY "device_tokens_update_policy"
ON public.device_tokens FOR UPDATE
TO authenticated
USING (
    auth.uid() = user_id
);

CREATE POLICY "device_tokens_delete_policy"
ON public.device_tokens FOR DELETE
TO authenticated
USING (
    auth.uid() = user_id
);

-- ----------------------------------------------------------------------------
-- 17. REPORTS POLICIES
-- ----------------------------------------------------------------------------
CREATE POLICY "reports_select_policy"
ON public.reports FOR SELECT
TO authenticated
USING (
    reporter_id = auth.uid() OR public.is_system_admin(auth.uid())
);

CREATE POLICY "reports_insert_policy"
ON public.reports FOR INSERT
TO authenticated
WITH CHECK (
    reporter_id = auth.uid()
);

CREATE POLICY "reports_update_policy"
ON public.reports FOR UPDATE
TO authenticated
USING (
    public.is_system_admin(auth.uid())
);

-- ----------------------------------------------------------------------------
-- 18. AUDIT LOG POLICIES (Immutable system admin view)
-- ----------------------------------------------------------------------------
CREATE POLICY "audit_log_select_policy"
ON public.audit_log FOR SELECT
TO authenticated
USING (
    public.is_system_admin(auth.uid())
);

CREATE POLICY "audit_log_insert_policy"
ON public.audit_log FOR INSERT
TO authenticated
WITH CHECK (
    public.is_system_admin(auth.uid())
);
