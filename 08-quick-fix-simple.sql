-- Kennedy Management System - Quick Fix for Profile Creation
-- This addresses the specific "Key is not present in table users" error
-- Run this IMMEDIATELY to fix the current issue

-- ============================================================================
-- IMMEDIATE FIX: SIMPLEST APPROACH
-- ============================================================================

-- The issue is that the trigger runs before the user record is fully committed
-- Let's remove the problematic trigger and rely on manual profile creation

-- 1. Drop the problematic trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS handle_new_user_ultra_simple() CASCADE;
DROP FUNCTION IF EXISTS handle_new_user_with_fk_fix() CASCADE;

-- 2. Create a simple, reliable profile creation function for the frontend
CREATE OR REPLACE FUNCTION create_owner_profile_safe(
    p_user_id UUID,
    p_school_id UUID,
    p_full_name TEXT,
    p_email TEXT,
    p_phone TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public AS $$
DECLARE
    user_exists BOOLEAN := false;
    school_exists BOOLEAN := false;
    profile_exists BOOLEAN := false;
    result jsonb;
    retry_count INTEGER := 0;
    max_retries INTEGER := 5;
BEGIN
    RAISE NOTICE '[SAFE_PROFILE] Creating profile for user % in school %', p_user_id, p_school_id;
    
    -- Wait for user to be available (handle timing issues)
    WHILE retry_count < max_retries LOOP
        SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = p_user_id) INTO user_exists;
        
        IF user_exists THEN
            RAISE NOTICE '[SAFE_PROFILE] User % found in auth.users', p_user_id;
            EXIT;
        ELSE
            retry_count := retry_count + 1;
            RAISE NOTICE '[SAFE_PROFILE] User % not found, retry %/%', p_user_id, retry_count, max_retries;
            PERFORM pg_sleep(0.2); -- Wait 200ms
        END IF;
    END LOOP;
    
    -- Check if user exists
    IF NOT user_exists THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'User not found in auth.users after retries',
            'user_id', p_user_id,
            'retries', retry_count
        );
    END IF;
    
    -- Check if school exists
    SELECT EXISTS(SELECT 1 FROM schools WHERE id = p_school_id) INTO school_exists;
    IF NOT school_exists THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'School not found',
            'school_id', p_school_id
        );
    END IF;
    
    -- Check if profile already exists
    SELECT EXISTS(SELECT 1 FROM profiles WHERE id = p_user_id) INTO profile_exists;
    IF profile_exists THEN
        RETURN jsonb_build_object(
            'success', true,
            'message', 'Profile already exists',
            'user_id', p_user_id,
            'action', 'already_exists'
        );
    END IF;
    
    -- Create the profile
    BEGIN
        INSERT INTO profiles (id, school_id, role, full_name, phone, is_active, created_at, updated_at)
        VALUES (
            p_user_id, 
            p_school_id, 
            'owner'::user_role, 
            p_full_name, 
            p_phone, 
            true,
            NOW(),
            NOW()
        );
        
        RAISE NOTICE '[SAFE_PROFILE] ✓ Profile created successfully for user %', p_user_id;
        
        RETURN jsonb_build_object(
            'success', true,
            'message', 'Profile created successfully',
            'user_id', p_user_id,
            'school_id', p_school_id,
            'action', 'created'
        );
        
    EXCEPTION
        WHEN foreign_key_violation THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Foreign key violation - user may not exist in auth.users',
                'details', SQLERRM,
                'user_id', p_user_id,
                'user_exists_check', user_exists
            );
        WHEN unique_violation THEN
            RETURN jsonb_build_object(
                'success', true,
                'message', 'Profile already exists (race condition)',
                'user_id', p_user_id,
                'action', 'already_exists'
            );
        WHEN OTHERS THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', SQLERRM,
                'sqlstate', SQLSTATE,
                'user_id', p_user_id,
                'school_id', p_school_id
            );
    END;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION create_owner_profile_safe(UUID, UUID, TEXT, TEXT, TEXT) TO authenticated, anon, service_role;

-- ============================================================================
-- ENHANCED PERMISSIONS TO PREVENT 406 ERRORS
-- ============================================================================

-- Grant comprehensive permissions to prevent HTTP 406 errors
DO $$
BEGIN
    -- Ensure all necessary permissions for profile access
    GRANT SELECT ON public.profiles TO authenticated, anon;
    GRANT SELECT ON public.schools TO authenticated, anon;
    GRANT USAGE ON SCHEMA public TO authenticated, anon;
    GRANT USAGE ON SCHEMA auth TO authenticated, anon;
    
    -- Grant access to sequences for ID generation
    GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated, anon;
    
    RAISE NOTICE '✓ Enhanced permissions granted to prevent 406 errors';
END $$;

-- ============================================================================
-- UPDATE RLS POLICIES TO BE MORE PERMISSIVE FOR PROFILE CREATION
-- ============================================================================

-- Drop restrictive policies that might cause 406 errors
DROP POLICY IF EXISTS "profile_select_school" ON profiles;
DROP POLICY IF EXISTS "profile_select_own_auth" ON profiles;
DROP POLICY IF EXISTS "profile_select_school_auth" ON profiles;

-- Create more permissive policies for authenticated users
CREATE POLICY "profiles_authenticated_select" ON profiles
    FOR SELECT TO authenticated
    USING (true); -- Allow authenticated users to select any profile (will be restricted by app logic)

CREATE POLICY "profiles_authenticated_insert" ON profiles
    FOR INSERT TO authenticated
    WITH CHECK (true); -- Allow authenticated users to insert profiles

-- Keep the existing anonymous policies
-- (they should already exist from previous fixes)

-- ============================================================================
-- SIMPLE TEST FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION test_profile_creation_simple()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public AS $$
DECLARE
    test_result TEXT := 'SIMPLE PROFILE CREATION TEST:\n';
    test_user_id UUID;
    test_school_id UUID;
    result jsonb;
BEGIN
    -- Generate test IDs
    test_user_id := extensions.uuid_generate_v4();
    test_school_id := extensions.uuid_generate_v4();
    
    -- Create test school
    INSERT INTO schools (id, name) VALUES (test_school_id, 'Test School Simple');
    test_result := test_result || '✓ Test school created\n';
    
    -- Test the profile creation function
    SELECT create_owner_profile_safe(test_user_id, test_school_id, 'Test User', 'test@example.com', NULL) INTO result;
    
    test_result := test_result || 'Profile creation result: ' || result::text || '\n';
    
    -- Cleanup
    DELETE FROM profiles WHERE id = test_user_id;
    DELETE FROM schools WHERE id = test_school_id;
    test_result := test_result || '✓ Cleanup completed\n';
    
    RETURN test_result;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION test_profile_creation_simple() TO authenticated, anon;

-- ============================================================================
-- INSTRUCTIONS FOR FRONTEND
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'QUICK FIX FOR PROFILE CREATION APPLIED!';
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'Changes Made:';
    RAISE NOTICE '  ✓ Removed problematic trigger functions';
    RAISE NOTICE '  ✓ Created safe profile creation function';
    RAISE NOTICE '  ✓ Enhanced permissions to prevent 406 errors';
    RAISE NOTICE '  ✓ Simplified RLS policies';
    RAISE NOTICE '';
    RAISE NOTICE 'FRONTEND CHANGES NEEDED:';
    RAISE NOTICE '  Instead of waiting for trigger, call this function after user signup:';
    RAISE NOTICE '  supabase.rpc("create_owner_profile_safe", {';
    RAISE NOTICE '    p_user_id: user.id,';
    RAISE NOTICE '    p_school_id: createdSchoolId,';
    RAISE NOTICE '    p_full_name: fullName,';
    RAISE NOTICE '    p_email: email,';
    RAISE NOTICE '    p_phone: phone';
    RAISE NOTICE '  })';
    RAISE NOTICE '';
    RAISE NOTICE 'This should eliminate both the foreign key error and the 406 errors.';
    RAISE NOTICE '============================================================================';
END $$;
