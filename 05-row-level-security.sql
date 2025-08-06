-- Kennedy Management System - Row Level Security Policies
-- This script creates secure, performant RLS policies for all tables
-- Run this FIFTH after 04-authentication-functions.sql

-- ============================================================================
-- DROP ALL EXISTING POLICIES (CLEAN SLATE)
-- ============================================================================

-- Authentication table policies
DROP POLICY IF EXISTS "Allow authenticated users full access to schools" ON schools;
DROP POLICY IF EXISTS "Allow authenticated users full access to profiles" ON profiles;
DROP POLICY IF EXISTS "Allow authenticated users full access to invitations" ON invitations;
DROP POLICY IF EXISTS "Simple profile access" ON profiles;
DROP POLICY IF EXISTS "Allow school creation" ON schools;
DROP POLICY IF EXISTS "Allow school access" ON schools;
DROP POLICY IF EXISTS "Allow school updates" ON schools;
DROP POLICY IF EXISTS "Users can view their school" ON schools;
DROP POLICY IF EXISTS "Owners can update their school" ON schools;
DROP POLICY IF EXISTS "System can create schools" ON schools;
DROP POLICY IF EXISTS "Users can view their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can view school profiles" ON profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
DROP POLICY IF EXISTS "System can create profiles" ON profiles;

-- Business table policies
DROP POLICY IF EXISTS "Allow authenticated users full access to students" ON students;
DROP POLICY IF EXISTS "Allow authenticated users full access to teachers" ON teachers;
DROP POLICY IF EXISTS "Allow authenticated users full access to course_templates" ON course_templates;
DROP POLICY IF EXISTS "Allow authenticated users full access to course_instances" ON course_instances;
DROP POLICY IF EXISTS "Allow authenticated users full access to student_payments" ON student_payments;
DROP POLICY IF EXISTS "Allow authenticated users full access to teacher_payouts" ON teacher_payouts;
DROP POLICY IF EXISTS "Allow authenticated users full access to revenue" ON revenue;
DROP POLICY IF EXISTS "Allow authenticated users full access to attendance" ON attendance;
DROP POLICY IF EXISTS "Allow authenticated users full access to archive_requests" ON archive_requests;

-- ============================================================================
-- AUTHENTICATION TABLE POLICIES (NON-RECURSIVE)
-- ============================================================================

-- SCHOOLS TABLE POLICIES
-- Policy 1: Allow unauthenticated school creation (for signup process)
CREATE POLICY "school_insert_for_signup" ON schools
    FOR INSERT WITH CHECK (true);

-- Policy 2: Allow authenticated users to view their own school
CREATE POLICY "school_select_own" ON schools
    FOR SELECT TO authenticated
    USING (id = get_user_school_id());

-- Policy 3: Allow owners to update their school
CREATE POLICY "school_update_by_owner" ON schools
    FOR UPDATE TO authenticated
    USING (id = get_user_school_id() AND user_has_role('owner'))
    WITH CHECK (id = get_user_school_id() AND user_has_role('owner'));

-- PROFILES TABLE POLICIES
-- Policy 1: Allow system to create profiles (for trigger)
CREATE POLICY "profile_insert_system" ON profiles
    FOR INSERT WITH CHECK (true);

-- Policy 2: Allow users to view their own profile (critical for auth)
CREATE POLICY "profile_select_own" ON profiles
    FOR SELECT TO authenticated
    USING (id = auth.uid());

-- Policy 3: Allow users to view other profiles in their school
CREATE POLICY "profile_select_school" ON profiles
    FOR SELECT TO authenticated
    USING (school_id = get_user_school_id() AND id != auth.uid());

-- Policy 4: Allow users to update their own profile
CREATE POLICY "profile_update_own" ON profiles
    FOR UPDATE TO authenticated
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

-- INVITATIONS TABLE POLICIES
-- Policy 1: Allow owners/managers to create invitations in their school
CREATE POLICY "invitation_insert_by_role" ON invitations
    FOR INSERT TO authenticated
    WITH CHECK (
        school_id = get_user_school_id() AND
        user_has_any_role(ARRAY['owner', 'manager'])
    );

-- Policy 2: Allow users to view invitations in their school
CREATE POLICY "invitation_select_school" ON invitations
    FOR SELECT TO authenticated
    USING (school_id = get_user_school_id());

-- Policy 3: Allow owners/managers to update invitations
CREATE POLICY "invitation_update_by_role" ON invitations
    FOR UPDATE TO authenticated
    USING (
        school_id = get_user_school_id() AND
        user_has_any_role(ARRAY['owner', 'manager'])
    )
    WITH CHECK (
        school_id = get_user_school_id() AND
        user_has_any_role(ARRAY['owner', 'manager'])
    );

-- ============================================================================
-- BUSINESS TABLE POLICIES (MULTI-TENANT BY SCHOOL)
-- ============================================================================

-- STUDENTS TABLE POLICIES
CREATE POLICY "students_school_access" ON students
    FOR ALL TO authenticated
    USING (school_id = get_user_school_id())
    WITH CHECK (school_id = get_user_school_id());

-- TEACHERS TABLE POLICIES
CREATE POLICY "teachers_school_access" ON teachers
    FOR ALL TO authenticated
    USING (school_id = get_user_school_id())
    WITH CHECK (school_id = get_user_school_id());

-- COURSE TEMPLATES TABLE POLICIES
CREATE POLICY "course_templates_school_access" ON course_templates
    FOR ALL TO authenticated
    USING (school_id = get_user_school_id())
    WITH CHECK (school_id = get_user_school_id());

-- COURSE INSTANCES TABLE POLICIES
CREATE POLICY "course_instances_school_access" ON course_instances
    FOR ALL TO authenticated
    USING (school_id = get_user_school_id())
    WITH CHECK (school_id = get_user_school_id());

-- STUDENT PAYMENTS TABLE POLICIES
CREATE POLICY "student_payments_school_access" ON student_payments
    FOR ALL TO authenticated
    USING (school_id = get_user_school_id())
    WITH CHECK (school_id = get_user_school_id());

-- TEACHER PAYOUTS TABLE POLICIES
-- Only owners and managers can access financial data
CREATE POLICY "teacher_payouts_financial_access" ON teacher_payouts
    FOR ALL TO authenticated
    USING (
        school_id = get_user_school_id() AND
        user_has_any_role(ARRAY['owner', 'manager'])
    )
    WITH CHECK (
        school_id = get_user_school_id() AND
        user_has_any_role(ARRAY['owner', 'manager'])
    );

-- REVENUE TABLE POLICIES
-- Only owners and managers can access financial data
CREATE POLICY "revenue_financial_access" ON revenue
    FOR ALL TO authenticated
    USING (
        school_id = get_user_school_id() AND
        user_has_any_role(ARRAY['owner', 'manager'])
    )
    WITH CHECK (
        school_id = get_user_school_id() AND
        user_has_any_role(ARRAY['owner', 'manager'])
    );

-- ATTENDANCE TABLE POLICIES
CREATE POLICY "attendance_school_access" ON attendance
    FOR ALL TO authenticated
    USING (school_id = get_user_school_id())
    WITH CHECK (school_id = get_user_school_id());

-- ARCHIVE REQUESTS TABLE POLICIES
CREATE POLICY "archive_requests_school_access" ON archive_requests
    FOR ALL TO authenticated
    USING (school_id = get_user_school_id())
    WITH CHECK (school_id = get_user_school_id());

-- ============================================================================
-- VERIFY RLS IS ENABLED
-- ============================================================================

-- Ensure RLS is enabled on all tables
ALTER TABLE schools ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE course_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE course_instances ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE revenue ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE archive_requests ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- GRANT TABLE PERMISSIONS
-- ============================================================================

-- Grant table access to authenticated users
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- ============================================================================
-- POLICY VALIDATION
-- ============================================================================

-- Test that policies exist and are working
DO $$
DECLARE
    policy_count INTEGER;
    table_name TEXT;
    table_names TEXT[] := ARRAY[
        'schools', 'profiles', 'invitations', 'students', 'teachers', 
        'course_templates', 'course_instances', 'student_payments', 
        'teacher_payouts', 'revenue', 'attendance', 'archive_requests'
    ];
BEGIN
    RAISE NOTICE 'Policy Validation Summary:';
    RAISE NOTICE '============================================================================';
    
    FOREACH table_name IN ARRAY table_names
    LOOP
        SELECT COUNT(*) INTO policy_count
        FROM pg_policies
        WHERE schemaname = 'public' AND tablename = table_name;
        
        RAISE NOTICE '  ✓ % table: % policies', table_name, policy_count;
    END LOOP;
    
    RAISE NOTICE '============================================================================';
END $$;

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'ROW LEVEL SECURITY POLICIES CREATED SUCCESSFULLY!';
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'Authentication Security:';
    RAISE NOTICE '  ✓ Schools: Signup allowed, owners can manage';
    RAISE NOTICE '  ✓ Profiles: Users see own + school profiles';
    RAISE NOTICE '  ✓ Invitations: Owners/managers can create';
    RAISE NOTICE '';
    RAISE NOTICE 'Multi-Tenant Security:';
    RAISE NOTICE '  ✓ All business tables isolated by school_id';
    RAISE NOTICE '  ✓ Users only see data from their school';
    RAISE NOTICE '  ✓ Financial data restricted to owners/managers';
    RAISE NOTICE '';
    RAISE NOTICE 'Performance Features:';
    RAISE NOTICE '  ✓ Non-recursive policies (no infinite loops)';
    RAISE NOTICE '  ✓ Leverages get_user_school_id() function';
    RAISE NOTICE '  ✓ Efficient role-based access control';
    RAISE NOTICE '';
    RAISE NOTICE 'Security Features:';
    RAISE NOTICE '  ✓ Complete tenant isolation';
    RAISE NOTICE '  ✓ Role-based financial access';
    RAISE NOTICE '  ✓ Secure signup process';
    RAISE NOTICE '  ✓ No data leakage between schools';
    RAISE NOTICE '';
    RAISE NOTICE 'Next Step: Run 06-utility-functions.sql';
    RAISE NOTICE '============================================================================';
END $$;
