-- ============================================================================
-- SQL Security Test: rls_group_security_test.sql
-- Description: Proves that an unauthorized user or non-member CANNOT read
--              any group row or message via PostgreSQL RLS.
-- ============================================================================

DO $$
DECLARE
    v_society_id UUID := '11111111-1111-1111-1111-111111111111'; -- ACM UET
    v_member_id UUID := gen_random_uuid();
    v_outsider_id UUID := gen_random_uuid();
    v_group_id UUID := gen_random_uuid();
    v_message_id UUID := gen_random_uuid();
    v_count INT;
BEGIN
    RAISE NOTICE '=== STARTING RLS GROUP PRIVACY TEST ===';

    -- 1. Create two test student users in profiles
    INSERT INTO public.profiles (id, email, full_name, roll_number, department, semester)
    VALUES 
        (v_member_id, 'member@uet.edu.pk', 'Verified Member', '2022-CS-991', 'Computer Science', 6),
        (v_outsider_id, 'outsider@uet.edu.pk', 'Eavesdropper Outsider', '2022-EE-992', 'Electrical Engineering', 4);

    -- 2. Create a private group for the society
    INSERT INTO public.groups (id, society_id, name, description, is_private)
    VALUES (v_group_id, v_society_id, 'Confidential Core Committee', 'Strictly private group', TRUE);

    -- 3. Add ONLY v_member_id to the group
    INSERT INTO public.group_members (group_id, user_id, role)
    VALUES (v_group_id, v_member_id, 'member');

    -- 4. Insert a confidential message into the group
    INSERT INTO public.group_messages (id, group_id, sender_id, content)
    VALUES (v_message_id, v_group_id, v_member_id, 'Top secret agenda: Internal debate motions.');

    -- ========================================================================
    -- TEST A: Non-member (v_outsider_id) attempts to read the private group
    -- ========================================================================
    -- Simulate context of the outsider
    PERFORM set_config('request.jwt.claim.sub', v_outsider_id::text, true);
    PERFORM set_config('role', 'authenticated', true);

    SELECT count(*) INTO v_count FROM public.groups WHERE id = v_group_id;
    IF v_count != 0 THEN
        RAISE EXCEPTION 'SECURITY FAILURE: Outsider was able to select private group row!';
    ELSE
        RAISE NOTICE 'TEST A PASSED: Non-member cannot select private group row (count = 0).';
    END IF;

    -- ========================================================================
    -- TEST B: Non-member (v_outsider_id) attempts to read messages in the group
    -- ========================================================================
    SELECT count(*) INTO v_count FROM public.group_messages WHERE group_id = v_group_id;
    IF v_count != 0 THEN
        RAISE EXCEPTION 'SECURITY FAILURE: Outsider was able to read private group messages!';
    ELSE
        RAISE NOTICE 'TEST B PASSED: Non-member cannot read private group messages (count = 0).';
    END IF;

    -- ========================================================================
    -- TEST C: Non-member (v_outsider_id) attempts to send a message to the group
    -- ========================================================================
    BEGIN
        INSERT INTO public.group_messages (group_id, sender_id, content)
        VALUES (v_group_id, v_outsider_id, 'Unauthorized message attempt');
        RAISE EXCEPTION 'SECURITY FAILURE: Outsider was able to insert into private group!';
    EXCEPTION
        WHEN insufficient_privilege OR check_violation THEN
            RAISE NOTICE 'TEST C PASSED: Non-member blocked from posting messages via RLS.';
    END;

    -- ========================================================================
    -- TEST D: Authorized Member (v_member_id) CAN read the group and message
    -- ========================================================================
    PERFORM set_config('request.jwt.claim.sub', v_member_id::text, true);
    PERFORM set_config('role', 'authenticated', true);

    SELECT count(*) INTO v_count FROM public.groups WHERE id = v_group_id;
    IF v_count != 1 THEN
        RAISE EXCEPTION 'MEMBER FAILURE: Authorized member could not view group!';
    ELSE
        RAISE NOTICE 'TEST D1 PASSED: Authorized member successfully reads group row.';
    END IF;

    SELECT count(*) INTO v_count FROM public.group_messages WHERE id = v_message_id;
    IF v_count != 1 THEN
        RAISE EXCEPTION 'MEMBER FAILURE: Authorized member could not view message!';
    ELSE
        RAISE NOTICE 'TEST D2 PASSED: Authorized member successfully reads message row.';
    END IF;

    RAISE NOTICE '=== ALL RLS GROUP SECURITY TESTS PASSED SUCCESSFULLY! ===';

    -- Cleanup test entries
    DELETE FROM public.groups WHERE id = v_group_id;
    DELETE FROM public.profiles WHERE id IN (v_member_id, v_outsider_id);
END $$;
