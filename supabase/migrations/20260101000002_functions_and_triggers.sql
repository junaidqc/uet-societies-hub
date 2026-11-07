-- ============================================================================
-- Migration: 20260101000002_functions_and_triggers.sql
-- Project: UET Societies Hub
-- Description: Triggers for @uet.edu.pk enforcement, profile sync, timestamps, 
--              and role-checking security helper functions.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. ENFORCE @uet.edu.pk EMAIL DOMAIN ON auth.users
-- Security Rule: "Signup only with @uet.edu.pk email (enforced by a DB trigger 
-- on auth.users, not just the app)"
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_uet_email_domain()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.email IS NULL OR LOWER(NEW.email) NOT LIKE '%@uet.edu.pk' THEN
        RAISE EXCEPTION 'Access Denied: Only verified @uet.edu.pk email addresses are allowed to register.'
            USING ERRCODE = 'P0001';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop if exists and recreate trigger on auth.users
DROP TRIGGER IF EXISTS trg_enforce_uet_email ON auth.users;
CREATE TRIGGER trg_enforce_uet_email
BEFORE INSERT OR UPDATE OF email ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.check_uet_email_domain();

-- ----------------------------------------------------------------------------
-- 2. AUTO-SYNC NEW AUTH USER TO public.profiles
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER AS $$
DECLARE
    v_full_name TEXT;
    v_roll_number TEXT;
    v_department TEXT;
    v_semester INT;
    v_is_system_admin BOOLEAN;
BEGIN
    v_full_name := COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1));
    v_roll_number := COALESCE(NEW.raw_user_meta_data->>'roll_number', 'PENDING-' || substr(NEW.id::text, 1, 8));
    v_department := COALESCE(NEW.raw_user_meta_data->>'department', 'Computer Science');
    v_semester := COALESCE((NEW.raw_user_meta_data->>'semester')::INT, 1);
    v_is_system_admin := FALSE;

    INSERT INTO public.profiles (
        id,
        email,
        full_name,
        roll_number,
        department,
        semester,
        is_system_admin,
        created_at,
        updated_at
    ) VALUES (
        NEW.id,
        LOWER(NEW.email),
        v_full_name,
        v_roll_number,
        v_department,
        v_semester,
        v_is_system_admin,
        timezone('utc'::text, now()),
        timezone('utc'::text, now())
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        full_name = COALESCE(EXCLUDED.full_name, public.profiles.full_name),
        department = COALESCE(EXCLUDED.department, public.profiles.department),
        semester = COALESCE(EXCLUDED.semester, public.profiles.semester),
        updated_at = timezone('utc'::text, now());

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_on_auth_user_created ON auth.users;
CREATE TRIGGER trg_on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_auth_user();

-- ----------------------------------------------------------------------------
-- 3. AUTOMATIC updated_at TIMESTAMP REFRESHER
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to tables with updated_at column
DROP TRIGGER IF EXISTS trg_profiles_updated_at ON public.profiles;
CREATE TRIGGER trg_profiles_updated_at BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();

DROP TRIGGER IF EXISTS trg_societies_updated_at ON public.societies;
CREATE TRIGGER trg_societies_updated_at BEFORE UPDATE ON public.societies
FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();

DROP TRIGGER IF EXISTS trg_posts_updated_at ON public.posts;
CREATE TRIGGER trg_posts_updated_at BEFORE UPDATE ON public.posts
FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();

DROP TRIGGER IF EXISTS trg_events_updated_at ON public.events;
CREATE TRIGGER trg_events_updated_at BEFORE UPDATE ON public.events
FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();

DROP TRIGGER IF EXISTS trg_hirings_updated_at ON public.hirings;
CREATE TRIGGER trg_hirings_updated_at BEFORE UPDATE ON public.hirings
FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();

DROP TRIGGER IF EXISTS trg_applications_updated_at ON public.applications;
CREATE TRIGGER trg_applications_updated_at BEFORE UPDATE ON public.applications
FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();

DROP TRIGGER IF EXISTS trg_groups_updated_at ON public.groups;
CREATE TRIGGER trg_groups_updated_at BEFORE UPDATE ON public.groups
FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();

-- ----------------------------------------------------------------------------
-- 4. SECURITY & ROLE HELPER FUNCTIONS (FOR RLS)
-- ----------------------------------------------------------------------------

-- Check if calling user is System Admin
CREATE OR REPLACE FUNCTION public.is_system_admin(p_user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
BEGIN
    IF p_user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    RETURN EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = p_user_id AND is_system_admin = TRUE
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Check if user is Society Admin or President or System Admin
CREATE OR REPLACE FUNCTION public.is_society_admin(p_society_id UUID, p_user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
BEGIN
    IF p_user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    IF public.is_system_admin(p_user_id) THEN
        RETURN TRUE;
    END IF;
    RETURN EXISTS (
        SELECT 1 FROM public.society_admins
        WHERE society_id = p_society_id AND user_id = p_user_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Check if user is Society President or System Admin
CREATE OR REPLACE FUNCTION public.is_society_president(p_society_id UUID, p_user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
BEGIN
    IF p_user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    IF public.is_system_admin(p_user_id) THEN
        RETURN TRUE;
    END IF;
    RETURN EXISTS (
        SELECT 1 FROM public.society_admins
        WHERE society_id = p_society_id AND user_id = p_user_id AND role = 'president'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Check if user is Member of a Group (or Society Admin / System Admin)
CREATE OR REPLACE FUNCTION public.is_group_member(p_group_id UUID, p_user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
DECLARE
    v_society_id UUID;
BEGIN
    IF p_user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    IF public.is_system_admin(p_user_id) THEN
        RETURN TRUE;
    END IF;

    -- Direct group membership check
    IF EXISTS (
        SELECT 1 FROM public.group_members
        WHERE group_id = p_group_id AND user_id = p_user_id
    ) THEN
        RETURN TRUE;
    END IF;

    -- Check if society admin of the group's society
    SELECT society_id INTO v_society_id FROM public.groups WHERE id = p_group_id;
    IF v_society_id IS NOT NULL AND public.is_society_admin(v_society_id, p_user_id) THEN
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Check if user has permission to review hiring applications for a hiring
CREATE OR REPLACE FUNCTION public.is_hiring_manager(p_hiring_id UUID, p_user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
DECLARE
    v_society_id UUID;
BEGIN
    IF p_user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    IF public.is_system_admin(p_user_id) THEN
        RETURN TRUE;
    END IF;

    SELECT society_id INTO v_society_id FROM public.hirings WHERE id = p_hiring_id;
    IF v_society_id IS NOT NULL AND public.is_society_admin(v_society_id, p_user_id) THEN
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
