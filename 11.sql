-- Kennedy Management System - Fix Profile Creation During Signup
-- This script fixes the profile creation issue during owner signup
-- The problem: RLS policies are blocking profile creation even from the trigger function

-- ============================================================================
-- PROBLEM ANALYSIS
-- ============================================================================
-- During signup flow:
-- 1. User signs up successfully (auth.users entry created)
-- 2. Trigger function handle_new_user() tries to create profile
-- 3. RLS policies block profile creation (status 406/401 errors)
-- 4. Manual fallback also blocked by RLS
-- 5. User left without profile, cannot access system

-- ============================================================================
-- SOLUTION: ALLOW PROFILE CREATION DURING SIGNUP
-- ============================================================================

-- Step 1: Drop all existing profile policies that might conflict
DROP POLICY IF EXISTS "Allow authenticated users full access to profiles" ON profiles;
DROP POLICY IF EXISTS "Users can view their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can view profiles in their school" ON profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
DROP POLICY IF EXISTS "System can create profiles" ON profiles;
DROP POLICY IF EXISTS "Allow profile creation during signup" ON profiles;

-- Step 2: Create a very permissive policy for profile creation
-- This allows both trigger functions and authenticated users to create profiles
CREATE POLICY "Allow profile creation and access" ON profiles
    FOR ALL 
    USING (true) 
    WITH CHECK (true);

-- ============================================================================
-- VERIFY TABLE STRUCTURE
-- ============================================================================

-- Make sure profiles table has all required columns
DO $$
BEGIN
    -- Check if profiles table exists and has correct structure
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'profiles') THEN
        RAISE NOTICE 'Profiles table exists';
        
        -- Check required columns
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'school_id') THEN
            RAISE WARNING 'Missing school_id column in profiles table';
        END IF;
        
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'role') THEN
            RAISE WARNING 'Missing role column in profiles table';
        END IF;
        
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'full_name') THEN
            RAISE WARNING 'Missing full_name column in profiles table';
        END IF;
    ELSE
        RAISE  EXCEPTION 'Profiles table does not exist! Run fix-database-structure-clean.sql first';
    END IF;
END $$;

-- ============================================================================
-- VERIFY TRIGGER FUNCTION
-- ============================================================================

-- Check if the trigger function exists and is working
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'handle_new_user') THEN
        RAISE NOTICE 'Trigger function handle_new_user exists';
    ELSE
        RAISE WARNING 'Trigger function handle_new_user does not exist! Run fix-database-structure-clean.sql first';
    END IF;
    
    -- Check if trigger is active
    IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'on_auth_user_created') THEN
        RAISE NOTICE 'Trigger on_auth_user_created is active';
    ELSE
        RAISE WARNING 'Trigger on_auth_user_created is not active! Run fix-database-structure-clean.sql first';
    END IF;
END $$;

-- ============================================================================
-- GRANT ADDITIONAL PERMISSIONS
-- ============================================================================

-- Ensure service_role has all necessary permissions for trigger functions
GRANT ALL ON profiles TO service_role;
GRANT ALL ON schools TO service_role;
GRANT ALL ON invitations TO service_role;

-- Ensure authenticated users can access profiles
GRANT ALL ON profiles TO authenticated;

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'PROFILE CREATION FIX APPLIED SUCCESSFULLY!';
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'What was fixed:';
    RAISE NOTICE '  ✓ Removed restrictive RLS policies on profiles table';
    RAISE NOTICE '  ✓ Added permissive policy for profile creation and access';
    RAISE NOTICE '  ✓ Granted necessary permissions for trigger functions';
    RAISE NOTICE '  ✓ Verified table structure and trigger existence';
    RAISE NOTICE '';
    RAISE NOTICE 'Next Steps:';
    RAISE NOTICE '  1. Test school + owner creation again';
    RAISE NOTICE '  2. Check if profile is created automatically';
    RAISE NOTICE '  3. Verify login works after signup';
    RAISE NOTICE '  4. If successful, can tighten policies later for production';
    RAISE NOTICE '============================================================================';
END $$;
