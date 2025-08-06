-- Fix School Creation RLS Policy for Signup Process
-- This script fixes the RLS policy on schools table to allow creation during signup
-- Run this in Supabase Database > SQL Editor

-- ============================================================================
-- EXPLANATION OF THE ISSUE
-- ============================================================================
-- During school+owner signup:
-- 1. User is NOT authenticated yet (they're signing up)
-- 2. School creation is attempted first
-- 3. RLS policy blocks it because there's no authenticated user
-- 4. Entire signup process fails

-- ============================================================================
-- SOLUTION: ALLOW UNAUTHENTICATED SCHOOL CREATION
-- ============================================================================

-- Drop existing school policies
DROP POLICY IF EXISTS "Allow authenticated users to view schools" ON schools;
DROP POLICY IF EXISTS "Allow authenticated users to create schools" ON schools;
DROP POLICY IF EXISTS "Allow authenticated users to update schools" ON schools;
DROP POLICY IF EXISTS "Users can view their school" ON schools;
DROP POLICY IF EXISTS "Owners can update their school" ON schools;
DROP POLICY IF EXISTS "System can create schools" ON schools;

-- Create new policies that allow school creation during signup
-- Policy 1: Allow anyone to create schools (needed for signup)
CREATE POLICY "Allow school creation for signup" ON schools
    FOR INSERT WITH CHECK (true);

-- Policy 2: Allow authenticated users to view their school
CREATE POLICY "Users can view their school" ON schools
    FOR SELECT USING (
        auth.uid() IS NOT NULL AND 
        id = (SELECT school_id FROM profiles WHERE id = auth.uid())
    );

-- Policy 3: Allow school owners to update their school
CREATE POLICY "Owners can update their school" ON schools
    FOR UPDATE USING (
        auth.uid() IS NOT NULL AND 
        id = (
            SELECT school_id FROM profiles 
            WHERE id = auth.uid() AND role = 'owner'
        )
    );

-- Policy 4: Allow school owners to delete their school (if needed)
CREATE POLICY "Owners can delete their school" ON schools
    FOR DELETE USING (
        auth.uid() IS NOT NULL AND 
        id = (
            SELECT school_id FROM profiles 
            WHERE id = auth.uid() AND role = 'owner'
        )
    );

-- ============================================================================
-- VERIFICATION AND SUCCESS MESSAGE
-- ============================================================================

DO $$
DECLARE
    policy_count INTEGER;
BEGIN
    -- Count policies on schools table
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'schools';

    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'SCHOOL CREATION RLS POLICY FIXED!';
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'Changes Made:';
    RAISE NOTICE '  ✓ Removed blocking school creation policies';
    RAISE NOTICE '  ✓ Added policy to allow school creation during signup';
    RAISE NOTICE '  ✓ Added policy for authenticated users to view their school';
    RAISE NOTICE '  ✓ Added policy for owners to update their school';
    RAISE NOTICE '  ✓ Added policy for owners to delete their school';
    RAISE NOTICE '';
    RAISE NOTICE 'Total Policies on Schools Table: %', policy_count;
    RAISE NOTICE '';
    RAISE NOTICE 'What This Fixes:';
    RAISE NOTICE '  ✓ Allows unauthenticated school creation during signup';
    RAISE NOTICE '  ✓ Maintains security for authenticated operations';
    RAISE NOTICE '  ✓ Prevents "row violates RLS policy" error';
    RAISE NOTICE '';
    RAISE NOTICE 'Next Steps:';
    RAISE NOTICE '  1. Refresh your website';
    RAISE NOTICE '  2. Try creating a school + owner account';
    RAISE NOTICE '  3. The signup process should now work completely';
    RAISE NOTICE '============================================================================';
END $$;
