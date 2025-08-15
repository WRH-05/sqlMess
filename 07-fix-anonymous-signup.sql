-- Kennedy Management System - Fix Anonymous Signup Issues
-- This script addresses RLS policy violations during school creation by anonymous users
-- Run this SEVENTH after all other files

-- ============================================================================
-- TEMPORARY DISABLE RLS FOR TESTING (DO NOT USE IN PRODUCTION)
-- ============================================================================

-- This is a temporary approach to identify the exact issue
-- Comment this section out once the real issue is identified

-- ============================================================================
-- ENHANCED ANONYMOUS USER PERMISSIONS
-- ============================================================================

-- Ensure anonymous users have all necessary permissions for signup
DO $$
BEGIN
    -- Grant comprehensive permissions to anonymous users for signup
    GRANT INSERT, SELECT ON schools TO anon;
    GRANT INSERT, SELECT ON profiles TO anon;
    GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO anon;
    
    -- Grant schema access
    GRANT USAGE ON SCHEMA public TO anon;
    GRANT USAGE ON SCHEMA extensions TO anon;
    GRANT USAGE ON SCHEMA auth TO anon;
    
    -- Grant function access
    GRANT EXECUTE ON FUNCTION extensions.uuid_generate_v4() TO anon;
    
    -- Try to grant access to auth functions that might be needed
    BEGIN
        GRANT SELECT ON auth.users TO anon;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Could not grant SELECT on auth.users to anon (this might be expected)';
    END;
    
    RAISE NOTICE 'Enhanced anonymous permissions granted successfully';
END $$;

-- ============================================================================
-- ALTERNATIVE RLS POLICIES FOR SIGNUP FLOW
-- ============================================================================

-- Drop existing policies and recreate with more permissive rules for signup
DROP POLICY IF EXISTS "school_insert_for_signup" ON schools;
DROP POLICY IF EXISTS "school_select_for_signup" ON schools;
DROP POLICY IF EXISTS "profile_insert_system" ON profiles;
DROP POLICY IF EXISTS "profile_select_for_signup" ON profiles;

-- Create simplified policies that definitely allow anonymous access
CREATE POLICY "schools_allow_anon_insert" ON schools
    FOR INSERT 
    TO anon
    WITH CHECK (true);

CREATE POLICY "schools_allow_anon_select" ON schools
    FOR SELECT 
    TO anon
    USING (true);

CREATE POLICY "profiles_allow_anon_insert" ON profiles
    FOR INSERT 
    TO anon
    WITH CHECK (true);

CREATE POLICY "profiles_allow_anon_select" ON profiles
    FOR SELECT 
    TO anon
    USING (true);

-- Keep the existing authenticated user policies
CREATE POLICY "school_select_own_auth" ON schools
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE profiles.id = (SELECT auth.uid()) 
            AND profiles.school_id = schools.id
        )
    );

CREATE POLICY "profile_select_own_auth" ON profiles
    FOR SELECT TO authenticated
    USING (id = (select auth.uid()));

CREATE POLICY "profile_select_school_auth" ON profiles
    FOR SELECT TO authenticated
    USING (
        id != (SELECT auth.uid()) AND
        EXISTS (
            SELECT 1 FROM profiles owner_profile 
            WHERE owner_profile.id = (SELECT auth.uid())
            AND owner_profile.school_id = profiles.school_id
        )
    );

-- ============================================================================
-- FALLBACK: TEMPORARY RLS BYPASS (ONLY FOR DEBUGGING)
-- ============================================================================

-- Uncomment these lines ONLY if you need to temporarily bypass RLS for testing
-- WARNING: This removes security! Only use for debugging, then re-enable RLS

-- ALTER TABLE schools DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;

-- To re-enable after testing:
-- ALTER TABLE schools ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- VERIFY PERMISSIONS AND POLICIES
-- ============================================================================

DO $$
DECLARE
    policy_count INTEGER;
    permission_count INTEGER;
BEGIN
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'ANONYMOUS SIGNUP FIX VERIFICATION';
    RAISE NOTICE '============================================================================';
    
    -- Check if RLS is enabled
    SELECT COUNT(*) INTO policy_count
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relname = 'schools'
    AND n.nspname = 'public'
    AND c.relrowsecurity = true;
    
    IF policy_count > 0 THEN
        RAISE NOTICE '✓ RLS is enabled on schools table';
    ELSE
        RAISE NOTICE '✗ RLS is NOT enabled on schools table';
    END IF;
    
    -- Check anonymous policies
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE schemaname = 'public' 
    AND tablename = 'schools' 
    AND (policyname = 'schools_allow_anon_insert' OR policyname = 'schools_allow_anon_select');
    
    RAISE NOTICE 'Anonymous school policies found: %', policy_count;
    
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE schemaname = 'public' 
    AND tablename = 'profiles' 
    AND (policyname = 'profiles_allow_anon_insert' OR policyname = 'profiles_allow_anon_select');
    
    RAISE NOTICE 'Anonymous profile policies found: %', policy_count;
    
    -- Check permissions
    SELECT COUNT(*) INTO permission_count
    FROM information_schema.table_privileges
    WHERE table_schema = 'public'
    AND table_name = 'schools'
    AND grantee = 'anon'
    AND privilege_type IN ('INSERT', 'SELECT');
    
    RAISE NOTICE 'Anonymous permissions on schools: %', permission_count;
    
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'If the issue persists, check:';
    RAISE NOTICE '1. Frontend code is using the correct Supabase configuration';
    RAISE NOTICE '2. The school creation is happening before user profile creation';
    RAISE NOTICE '3. The signup flow is properly structured';
    RAISE NOTICE '4. Consider temporarily disabling RLS for debugging (see comments above)';
    RAISE NOTICE '============================================================================';
END $$;

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'ANONYMOUS SIGNUP FIX APPLIED SUCCESSFULLY!';
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'Changes Made:';
    RAISE NOTICE '  ✓ Enhanced anonymous user permissions';
    RAISE NOTICE '  ✓ Simplified RLS policies for signup flow';
    RAISE NOTICE '  ✓ Added fallback options for debugging';
    RAISE NOTICE '';
    RAISE NOTICE 'Next Steps:';
    RAISE NOTICE '  1. Test school creation with anonymous user';
    RAISE NOTICE '  2. If still failing, check frontend signup implementation';
    RAISE NOTICE '  3. Consider using the RLS bypass temporarily for debugging';
    RAISE NOTICE '  4. Re-enable stricter policies once working';
    RAISE NOTICE '============================================================================';
END $$;
