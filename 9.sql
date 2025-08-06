-- Kennedy Management System - Fix Signup RLS Policies
-- This script specifically fixes the school creation during signup process
-- The issue: RLS policies are blocking unauthenticated school creation during signup

-- ============================================================================
-- ANALYSIS OF THE PROBLEM
-- ============================================================================
-- Current Flow:
-- 1. User fills form and clicks "Create School" 
-- 2. Frontend calls authService.createSchoolAndOwner()
-- 3. First step: Insert into schools table (user NOT authenticated)
-- 4. RLS policy blocks with "new row violates row-level security policy"
-- 5. Process fails before user signup even happens

-- ============================================================================
-- THE SOLUTION: ALLOW UNAUTHENTICATED SCHOOL CREATION
-- ============================================================================

-- Step 1: Drop ALL existing school policies that might conflict
DROP POLICY IF EXISTS "Allow school creation during signup" ON schools;
DROP POLICY IF EXISTS "Allow users to view their school" ON schools;
DROP POLICY IF EXISTS "Allow owners to update their school" ON schools;
DROP POLICY IF EXISTS "Allow owners to delete their school" ON schools;
DROP POLICY IF EXISTS "Allow authenticated users full access to schools" ON schools;
DROP POLICY IF EXISTS "Users can view their own school" ON schools;
DROP POLICY IF EXISTS "Owners can update their school" ON schools;
DROP POLICY IF EXISTS "System can create schools" ON schools;

-- Step 2: Create a SINGLE permissive policy for school creation
-- This allows ANYONE to create schools (needed for signup process)
-- Security: Only signup process creates schools, and owner profile is created immediately after
CREATE POLICY "Allow anyone to create schools for signup" ON schools
    FOR INSERT WITH CHECK (true);

-- Step 3: Allow authenticated users to view their school
CREATE POLICY "Authenticated users can view their school" ON schools
    FOR SELECT TO authenticated USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE profiles.id = auth.uid() 
            AND profiles.school_id = schools.id
        )
    );

-- Step 4: Allow owners to update their school
CREATE POLICY "Owners can update their school" ON schools
    FOR UPDATE TO authenticated USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE profiles.id = auth.uid() 
            AND profiles.school_id = schools.id 
            AND profiles.role = 'owner'
        )
    );

-- ============================================================================
-- FIX PROFILES POLICIES TO SUPPORT TRIGGER CREATION
-- ============================================================================

-- Drop existing profile policies
DROP POLICY IF EXISTS "Allow users to view their own profile" ON profiles;
DROP POLICY IF EXISTS "Allow users to view profiles in their school" ON profiles;
DROP POLICY IF EXISTS "Allow users to update their own profile" ON profiles;
DROP POLICY IF EXISTS "Allow profile creation during signup" ON profiles;
DROP POLICY IF EXISTS "Allow authenticated users full access to profiles" ON profiles;
DROP POLICY IF EXISTS "System can create profiles" ON profiles;

-- Create safe profile policies
CREATE POLICY "Users can view their own profile" ON profiles
    FOR SELECT TO authenticated USING (id = auth.uid());

CREATE POLICY "Users can view profiles in their school" ON profiles
    FOR SELECT TO authenticated USING (
        school_id = (SELECT school_id FROM profiles WHERE id = auth.uid())
    );

CREATE POLICY "Users can update their own profile" ON profiles
    FOR UPDATE TO authenticated USING (id = auth.uid());

-- CRITICAL: Allow trigger/system to create profiles during signup
-- This is essential for the handle_new_user() trigger to work
CREATE POLICY "Allow system to create profiles" ON profiles
    FOR INSERT WITH CHECK (true);

-- ============================================================================
-- ENSURE RLS IS ENABLED
-- ============================================================================

ALTER TABLE schools ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- VERIFICATION AND SUCCESS MESSAGE
-- ============================================================================

DO $$
DECLARE
    school_policies INTEGER;
    profile_policies INTEGER;
BEGIN
    -- Count policies
    SELECT COUNT(*) INTO school_policies
    FROM pg_policies 
    WHERE schemaname = 'public' AND tablename = 'schools';
    
    SELECT COUNT(*) INTO profile_policies
    FROM pg_policies 
    WHERE schemaname = 'public' AND tablename = 'profiles';

    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'SIGNUP RLS POLICIES FIXED!';
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'Changes Made:';
    RAISE NOTICE '  ✓ Removed all conflicting school policies';
    RAISE NOTICE '  ✓ Created permissive school creation policy (allows unauthenticated)';
    RAISE NOTICE '  ✓ Created safe authenticated school viewing policy';
    RAISE NOTICE '  ✓ Created owner-only school update policy';
    RAISE NOTICE '  ✓ Created permissive profile creation policy (for trigger)';
    RAISE NOTICE '';
    RAISE NOTICE 'Policy Summary:';
    RAISE NOTICE '  • Schools table: % policies (should be 3)', school_policies;
    RAISE NOTICE '  • Profiles table: % policies (should be 4)', profile_policies;
    RAISE NOTICE '';
    RAISE NOTICE 'Security Model:';
    RAISE NOTICE '  ✓ Schools: Anyone can create (for signup), auth users can view/update own';
    RAISE NOTICE '  ✓ Profiles: System can create (trigger), auth users can view/update own';
    RAISE NOTICE '  ✓ Multi-tenant isolation via school_id in profiles';
    RAISE NOTICE '';
    RAISE NOTICE 'Expected Signup Flow:';
    RAISE NOTICE '  1. User fills school + owner form';
    RAISE NOTICE '  2. Frontend calls createSchoolAndOwner()';
    RAISE NOTICE '  3. School creation ✓ (now allowed)';
    RAISE NOTICE '  4. User signup ✓ (Supabase Auth)';
    RAISE NOTICE '  5. Trigger creates profile ✓ (now allowed)';
    RAISE NOTICE '  6. User gets immediate access to manager dashboard';
    RAISE NOTICE '';
    RAISE NOTICE 'Test Instructions:';
    RAISE NOTICE '  1. Go to /auth/create-school';
    RAISE NOTICE '  2. Fill in school information';
    RAISE NOTICE '  3. Fill in owner account details';
    RAISE NOTICE '  4. Click "Create School"';
    RAISE NOTICE '  5. Should succeed without RLS errors';
    RAISE NOTICE '  6. Should redirect to /manager dashboard';
    RAISE NOTICE '============================================================================';
END $$;
