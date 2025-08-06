-- Kennedy Management System - Authentication RLS Policies Only
-- This script is for Supabase Authentication > Policies section
-- Run this in the Authentication section of Supabase Dashboard

-- ============================================================================
-- AUTHENTICATION RLS POLICIES
-- These policies are specific to authentication tables and should be 
-- configured in Supabase Dashboard > Authentication > Policies
-- ============================================================================

-- ============================================================================
-- PART 1: DROP EXISTING AUTH-RELATED POLICIES
-- ============================================================================

-- Drop existing authentication policies that might conflict
DROP POLICY IF EXISTS "Users can view their own school" ON schools;
DROP POLICY IF EXISTS "Owners can update their school" ON schools;
DROP POLICY IF EXISTS "System can create schools" ON schools;
DROP POLICY IF EXISTS "Users can view their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can view profiles in their school" ON profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
DROP POLICY IF EXISTS "System can create profiles" ON profiles;
DROP POLICY IF EXISTS "Users can always view their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can view school profiles" ON profiles;
DROP POLICY IF EXISTS "Users can view invitations for their school" ON invitations;
DROP POLICY IF EXISTS "Owners and managers can create invitations" ON invitations;
DROP POLICY IF EXISTS "Allow all operations on schools" ON schools;
DROP POLICY IF EXISTS "Allow all operations on profiles" ON profiles;
DROP POLICY IF EXISTS "Allow all operations on invitations" ON invitations;

-- ============================================================================
-- PART 2: SCHOOLS TABLE POLICIES (Authentication Context)
-- ============================================================================

-- Schools - Basic access for multi-tenant architecture
CREATE POLICY "Users can view their school" ON schools
    FOR SELECT USING (
        id = (SELECT school_id FROM profiles WHERE id = auth.uid())
    );

CREATE POLICY "Owners can update their school" ON schools
    FOR UPDATE USING (
        id = (SELECT school_id FROM profiles WHERE id = auth.uid() AND role = 'owner')
    );

CREATE POLICY "System can create schools" ON schools
    FOR INSERT WITH CHECK (true);

-- ============================================================================
-- PART 3: PROFILES TABLE POLICIES (Core Authentication)
-- ============================================================================

-- Primary policy: Users MUST be able to view their own profile (critical for login)
CREATE POLICY "Users can view their own profile" ON profiles
    FOR SELECT USING (id = auth.uid());

-- Secondary policy: Users can view other profiles in their school
CREATE POLICY "Users can view school profiles" ON profiles
    FOR SELECT USING (
        school_id = (
            SELECT school_id FROM profiles 
            WHERE id = auth.uid()
            LIMIT 1
        )
    );

-- Users can update their own profile
CREATE POLICY "Users can update their own profile" ON profiles
    FOR UPDATE USING (id = auth.uid());

-- System can create profiles (for user registration trigger)
CREATE POLICY "System can create profiles" ON profiles
    FOR INSERT WITH CHECK (true);

-- ============================================================================
-- PART 4: INVITATIONS TABLE POLICIES (Authentication Context)
-- ============================================================================

-- Users can view invitations for their school
CREATE POLICY "Users can view invitations for their school" ON invitations
    FOR SELECT USING (
        school_id = (SELECT school_id FROM profiles WHERE id = auth.uid())
    );

-- Owners and managers can create invitations
CREATE POLICY "Owners and managers can create invitations" ON invitations
    FOR INSERT WITH CHECK (
        school_id = (
            SELECT school_id FROM profiles 
            WHERE id = auth.uid() AND role IN ('owner', 'manager')
        )
    );

-- Owners and managers can update invitations
CREATE POLICY "Owners and managers can update invitations" ON invitations
    FOR UPDATE USING (
        school_id = (
            SELECT school_id FROM profiles 
            WHERE id = auth.uid() AND role IN ('owner', 'manager')
        )
    );

-- ============================================================================
-- COMMENTS FOR POLICY UNDERSTANDING
-- ============================================================================

COMMENT ON POLICY "Users can view their own profile" ON profiles IS 
'CRITICAL: This policy must work for login to succeed. Users need to access their own profile data during authentication.';

COMMENT ON POLICY "Users can view school profiles" ON profiles IS 
'Secondary policy for viewing other users in the same school. Depends on the primary profile policy working.';

COMMENT ON POLICY "Users can view their school" ON schools IS 
'Allows users to access their school information based on their profile school_id.';

COMMENT ON POLICY "System can create profiles" ON profiles IS 
'Allows the database trigger to create profiles during user registration without RLS restrictions.';

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'AUTHENTICATION RLS POLICIES CONFIGURED SUCCESSFULLY!';
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'Policies created for Authentication section:';
    RAISE NOTICE '  ✓ Schools: view own school, owners can update';
    RAISE NOTICE '  ✓ Profiles: view own profile (CRITICAL), view school profiles, update own';
    RAISE NOTICE '  ✓ Invitations: view school invitations, owners/managers can manage';
    RAISE NOTICE '';
    RAISE NOTICE 'These policies handle:';
    RAISE NOTICE '  ✓ User login authentication';
    RAISE NOTICE '  ✓ Multi-tenant school isolation';
    RAISE NOTICE '  ✓ Role-based invitation management';
    RAISE NOTICE '  ✓ Profile access and updates';
    RAISE NOTICE '';
    RAISE NOTICE 'Next: Run fix-database-rls-only.sql for business table policies';
    RAISE NOTICE '============================================================================';
END $$;
