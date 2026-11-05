-- ============================================================================
-- Seed Data: seed.sql
-- Project: UET Societies Hub
-- Description: Sample initial data including official UET Societies and 
--              one System Admin account.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. SYSTEM ADMIN SEED USER (auth.users & profiles)
-- ----------------------------------------------------------------------------
-- Note: Email is compliant with the '@uet.edu.pk' domain constraint.
-- Password: AdminPassword123!
DO $$
DECLARE
    v_admin_id UUID := '00000000-0000-0000-0000-000000000001';
BEGIN
    -- Insert auth user if not present
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = v_admin_id) THEN
        INSERT INTO auth.users (
            instance_id,
            id,
            aud,
            role,
            email,
            encrypted_password,
            email_confirmed_at,
            raw_app_meta_data,
            raw_user_meta_data,
            created_at,
            updated_at
        ) VALUES (
            '00000000-0000-0000-0000-000000000000',
            v_admin_id,
            'authenticated',
            'authenticated',
            'admin@uet.edu.pk',
            crypt('AdminPassword123!', gen_salt('bf')),
            timezone('utc'::text, now()),
            '{"provider":"email","providers":["email"]}',
            '{"full_name":"Director Student Affairs","roll_number":"ADMIN-DSA-01","department":"Administration","semester":8,"is_system_admin":true}',
            timezone('utc'::text, now()),
            timezone('utc'::text, now())
        );

        -- Ensure profiles record has is_system_admin = TRUE
        INSERT INTO public.profiles (
            id,
            email,
            full_name,
            roll_number,
            department,
            semester,
            bio,
            is_system_admin,
            created_at,
            updated_at
        ) VALUES (
            v_admin_id,
            'admin@uet.edu.pk',
            'Director Student Affairs',
            'ADMIN-DSA-01',
            'Administration',
            8,
            'Official System Administrator for UET Societies Hub portal.',
            TRUE,
            timezone('utc'::text, now()),
            timezone('utc'::text, now())
        ) ON CONFLICT (id) DO UPDATE SET
            is_system_admin = TRUE;
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 2. SAMPLE UET SOCIETIES
-- ----------------------------------------------------------------------------
INSERT INTO public.societies (id, name, slug, category, description, logo_url, banner_url, status, email, website, social_links)
VALUES
(
    '11111111-1111-1111-1111-111111111111',
    'ACM UET Lahore',
    'acm-uet',
    'Technical',
    'Association for Computing Machinery, UET Lahore Student Chapter is the premier tech society organizing hackathons, coding workshops, and tech conferences.',
    'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=150',
    'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?w=800',
    'active',
    'acm@uet.edu.pk',
    'https://acm.uet.edu.pk',
    '{"facebook": "https://fb.com/acmuet", "linkedin": "https://linkedin.com/company/acmuet"}'::jsonb
),
(
    '22222222-2222-2222-2222-222222222222',
    'IEEE UET Student Branch',
    'ieee-uet',
    'Technical',
    'IEEE UET Student Branch empowers students with technological innovation and excellence for the benefit of humanity through IEEE conferences and robotics competitions.',
    'https://images.unsplash.com/photo-1518770660439-4636190af475?w=150',
    'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=800',
    'active',
    'ieee@uet.edu.pk',
    'https://ieee.uet.edu.pk',
    '{"facebook": "https://fb.com/ieeeuet", "linkedin": "https://linkedin.com/company/ieeeuet"}'::jsonb
),
(
    '33333333-3333-3333-3333-333333333333',
    'UET Debating Society',
    'uet-debating-society',
    'Literary',
    'The premier oratorical forum of UET Lahore cultivating parliamentary debating, declamations, and public speaking champions across national circuits.',
    'https://images.unsplash.com/photo-1475721027785-f74eccf877e2?w=150',
    'https://images.unsplash.com/photo-1475721027785-f74eccf877e2?w=800',
    'active',
    'debating@uet.edu.pk',
    'https://debating.uet.edu.pk',
    '{"facebook": "https://fb.com/uds.uet"}'::jsonb
),
(
    '44444444-4444-4444-4444-444444444444',
    'Environmental Protection Society (EPS)',
    'eps-uet',
    'Social',
    'Dedicated to green campus initiatives, tree plantation drives, environmental sustainability, and eco-friendly awareness campaigns across UET.',
    'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=150',
    'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=800',
    'active',
    'eps@uet.edu.pk',
    'https://eps.uet.edu.pk',
    '{"facebook": "https://fb.com/epsuet"}'::jsonb
),
(
    '55555555-5555-5555-5555-555555555555',
    'UET Blood Donor Society (BDS)',
    'bds-uet',
    'Social',
    'Connecting voluntary blood donors with patients in urgent need across teaching hospitals in Lahore. Serving humanity with every drop.',
    'https://images.unsplash.com/photo-1615461066841-6116e61058f4?w=150',
    'https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?w=800',
    'active',
    'bds@uet.edu.pk',
    'https://bds.uet.edu.pk',
    '{"facebook": "https://fb.com/bdsuet"}'::jsonb
)
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 3. SAMPLE HIRING (FR-18..FR-25, UC-1)
-- ----------------------------------------------------------------------------
INSERT INTO public.hirings (
    id,
    society_id,
    title,
    description,
    positions,
    deadline,
    status,
    requirements,
    selection_method,
    total_seats,
    custom_questions
) VALUES (
    'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
    '11111111-1111-1111-1111-111111111111', -- ACM UET
    'Annual Executive Recruitment 2026',
    'Join ACM UET team for technical event management, web dev, competitive programming, and social media marketing.',
    '["Mobile App Developer", "UI/UX Designer", "Event Coordinator", "Media & Graphics Lead"]'::jsonb,
    timezone('utc'::text, now() + interval '14 days'),
    'open',
    'Must be a currently enrolled UET Lahore student in Semester 2 to 8.',
    'Interview & Test',
    12,
    '[
        {"id": "q1", "question": "Why do you want to join ACM UET?", "required": true},
        {"id": "q2", "question": "GitHub profile or design portfolio link", "required": false},
        {"id": "q3", "question": "Previous technical or event management experience", "required": true}
    ]'::jsonb
) ON CONFLICT (id) DO UPDATE SET
    custom_questions = EXCLUDED.custom_questions,
    selection_method = EXCLUDED.selection_method,
    total_seats = EXCLUDED.total_seats;

-- Sample Group for ACM UET (For FR-28 Onboarding Selected Applicants to Groups)
INSERT INTO public.groups (
    id,
    society_id,
    name,
    description,
    is_private
) VALUES (
    'c1111111-1111-1111-1111-111111111111',
    '11111111-1111-1111-1111-111111111111', -- ACM UET
    'ACM Executive Working Committee',
    'Official internal working group for elected and selected ACM executives.',
    TRUE
) ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 4. SAMPLE SOCIETY ADMINS & OFFICE BEARERS (FR-8, FR-10)
-- ----------------------------------------------------------------------------
-- Assign the Admin account as President of ACM UET for executive console testing
INSERT INTO public.society_admins (society_id, user_id, role)
VALUES 
(
    '11111111-1111-1111-1111-111111111111', -- ACM UET
    '00000000-0000-0000-0000-000000000001', -- Admin User
    'president'
)
ON CONFLICT (society_id, user_id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 5. SAMPLE PENDING SOCIETY REQUEST (To test FR-7 System Admin Approval Screen)
-- ----------------------------------------------------------------------------
INSERT INTO public.societies (
    id,
    name,
    slug,
    category,
    description,
    logo_url,
    status,
    email,
    website,
    created_by
) VALUES (
    '99999999-9999-9999-9999-999999999999',
    'UET Artificial Intelligence Club',
    'uet-ai-club',
    'Technical',
    'A student-led initiative fostering machine learning research, Kaggle competitions, LLM hackathons, and AI alignment discussions.',
    'https://images.unsplash.com/photo-1620712943543-bcc4688e7485?w=150',
    'pending',
    'aiclub@uet.edu.pk',
    'https://ai.uet.edu.pk',
-- ----------------------------------------------------------------------------
-- 6. SAMPLE POSTS & EVENTS (FR-11..FR-17)
-- ----------------------------------------------------------------------------
-- Public Pinned Post (ACM UET)
INSERT INTO public.posts (
    id,
    society_id,
    author_id,
    title,
    content,
    is_pinned,
    is_public,
    media_urls,
    created_at
) VALUES (
    'e1111111-1111-1111-1111-111111111111',
    '11111111-1111-1111-1111-111111111111', -- ACM UET
    '00000000-0000-0000-0000-000000000001',
    'Welcome to Spring 2026! 🚀 ACM Orientation Week',
    'We are excited to welcome freshmen and returning students to the Spring 2026 semester! Join us for hackathons, competitive programming, and tech bootcamps.',
    TRUE,
    TRUE,
    '["https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?w=800"]'::jsonb,
    timezone('utc'::text, now() - interval '2 hours')
) ON CONFLICT (id) DO NOTHING;

-- Members-Only Post (ACM UET) - To verify RLS (Guests see only public posts)
INSERT INTO public.posts (
    id,
    society_id,
    author_id,
    title,
    content,
    is_pinned,
    is_public,
    created_at
) VALUES (
    'e2222222-2222-2222-2222-222222222222',
    '11111111-1111-1111-1111-111111111111', -- ACM UET
    '00000000-0000-0000-0000-000000000001',
    '🔒 Internal Council Meeting: Budget Allocation & Venue Booking',
    'Dear core executive members, please review the finalized budget sheet for the upcoming coding championship before Thursday 5 PM.',
    FALSE,
    FALSE, -- Members only!
    timezone('utc'::text, now() - interval '4 hours')
) ON CONFLICT (id) DO NOTHING;

-- Public Event 1 (ACM UET)
INSERT INTO public.events (
    id,
    society_id,
    title,
    description,
    venue,
    start_time,
    end_time,
    banner_url,
    registration_link,
    is_public
) VALUES (
    'f1111111-1111-1111-1111-111111111111',
    '11111111-1111-1111-1111-111111111111', -- ACM UET
    'UET Hackathon 2026: Code the Future',
    '48-hour high-intensity software hackathon solving smart campus challenges with generative AI.',
    'Main Auditorium & CS Labs',
    timezone('utc'::text, now() + interval '5 days'),
    timezone('utc'::text, now() + interval '7 days'),
    'https://images.unsplash.com/photo-1504384308090-c894fdcc538d?w=800',
    'https://hackathon.uet.edu.pk',
    TRUE
) ON CONFLICT (id) DO NOTHING;

-- Public Event 2 (IEEE UET)
INSERT INTO public.events (
    id,
    society_id,
    title,
    description,
    venue,
    start_time,
    end_time,
    banner_url,
    registration_link,
    is_public
) VALUES (
    'f2222222-2222-2222-2222-222222222222',
    '22222222-2222-2222-2222-222222222222', -- IEEE UET
    'RoboTech Expo 2026 & Line Following Contest',
    'Showcasing autonomous line-follower robots and industrial automation projects by engineering students.',
    'Chemical Engineering Hall',
    timezone('utc'::text, now() + interval '12 days'),
    timezone('utc'::text, now() + interval '13 days'),
    'https://images.unsplash.com/photo-1485827404703-89b55fcc595e?w=800',
    'https://robotech.uet.edu.pk',
    TRUE
) ON CONFLICT (id) DO NOTHING;


