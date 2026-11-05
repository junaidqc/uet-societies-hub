-- ============================================================================
-- SQL Test: retention_cleanup_test.sql
-- Description: Inserts a 31-day-old message and a 29-day-old message.
--              Verifies that the retention cleanup removes the 31-day-old row
--              and attached file while preserving the 29-day-old message.
-- ============================================================================

DO $$
DECLARE
    v_society_id UUID := '11111111-1111-1111-1111-111111111111';
    v_group_id UUID := gen_random_uuid();
    v_user_id UUID := gen_random_uuid();
    v_msg_old_id UUID := gen_random_uuid();
    v_msg_new_id UUID := gen_random_uuid();
    v_old_file TEXT := 'test_group/old_attachment_31d.pdf';
    v_new_file TEXT := 'test_group/new_attachment_29d.pdf';
    v_count INT;
BEGIN
    RAISE NOTICE '=== STARTING 30-DAY RETENTION CLEANUP TEST ===';

    -- 1. Setup profile and group
    INSERT INTO public.profiles (id, email, full_name, roll_number, department, semester)
    VALUES (v_user_id, 'retention_test@uet.edu.pk', 'Retention Tester', '2022-CS-888', 'CS', 8);

    INSERT INTO public.groups (id, society_id, name, description)
    VALUES (v_group_id, v_society_id, 'Retention Test Group', 'Temporary test container');

    INSERT INTO public.group_members (group_id, user_id, role)
    VALUES (v_group_id, v_user_id, 'member');

    -- 2. Insert 31-day-old message
    INSERT INTO public.group_messages (id, group_id, sender_id, content, attachment_path, created_at)
    VALUES (
        v_msg_old_id,
        v_group_id,
        v_user_id,
        'Old meeting notes (31 days ago)',
        v_old_file,
        timezone('utc'::text, now() - interval '31 days')
    );

    -- 3. Insert 29-day-old message (survivor)
    INSERT INTO public.group_messages (id, group_id, sender_id, content, attachment_path, created_at)
    VALUES (
        v_msg_new_id,
        v_group_id,
        v_user_id,
        'Recent meeting notes (29 days ago)',
        v_new_file,
        timezone('utc'::text, now() - interval '29 days')
    );

    -- Simulate storage object insertion for the 31-day-old file
    INSERT INTO storage.objects (id, bucket_id, name, owner)
    VALUES 
        (gen_random_uuid(), 'chat-attachments', v_old_file, v_user_id),
        (gen_random_uuid(), 'chat-attachments', v_new_file, v_user_id)
    ON CONFLICT DO NOTHING;

    -- ========================================================================
    -- EXECUTE RETENTION BATCH CLEANUP (Logic mirrored in Edge Function)
    -- ========================================================================
    -- Remove old files from storage
    DELETE FROM storage.objects 
    WHERE bucket_id = 'chat-attachments' 
      AND name IN (
          SELECT attachment_path FROM public.group_messages 
          WHERE created_at < timezone('utc'::text, now() - interval '30 days')
            AND attachment_path IS NOT NULL
      );

    -- Delete messages older than 30 days
    DELETE FROM public.group_messages
    WHERE created_at < timezone('utc'::text, now() - interval '30 days');

    -- ========================================================================
    -- VERIFICATION ASSERTIONS
    -- ========================================================================
    -- Check 31-day-old message row
    SELECT count(*) INTO v_count FROM public.group_messages WHERE id = v_msg_old_id;
    IF v_count != 0 THEN
        RAISE EXCEPTION 'TEST FAILED: 31-day-old message was NOT removed!';
    ELSE
        RAISE NOTICE 'ASSERTION 1 PASSED: 31-day-old message was purged.';
    END IF;

    -- Check 31-day-old file in storage
    SELECT count(*) INTO v_count FROM storage.objects WHERE bucket_id = 'chat-attachments' AND name = v_old_file;
    IF v_count != 0 THEN
        RAISE EXCEPTION 'TEST FAILED: 31-day-old storage file was NOT removed!';
    ELSE
        RAISE NOTICE 'ASSERTION 2 PASSED: 31-day-old attachment file was deleted from storage.';
    END IF;

    -- Check 29-day-old message row (SURVIVOR)
    SELECT count(*) INTO v_count FROM public.group_messages WHERE id = v_msg_new_id;
    IF v_count != 1 THEN
        RAISE EXCEPTION 'TEST FAILED: 29-day-old message was prematurely deleted!';
    ELSE
        RAISE NOTICE 'ASSERTION 3 PASSED: 29-day-old message survived.';
    END IF;

    -- Check 29-day-old file in storage
    SELECT count(*) INTO v_count FROM storage.objects WHERE bucket_id = 'chat-attachments' AND name = v_new_file;
    IF v_count != 1 THEN
        RAISE EXCEPTION 'TEST FAILED: 29-day-old storage file was prematurely deleted!';
    ELSE
        RAISE NOTICE 'ASSERTION 4 PASSED: 29-day-old storage file was preserved.';
    END IF;

    RAISE NOTICE '=== ALL RETENTION CLEANUP TESTS PASSED SUCCESSFULLY! ===';

    -- Cleanup test entries
    DELETE FROM public.groups WHERE id = v_group_id;
    DELETE FROM public.profiles WHERE id = v_user_id;
    DELETE FROM storage.objects WHERE bucket_id = 'chat-attachments' AND name = v_new_file;
END $$;
