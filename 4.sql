-- Kennedy Management System - Database RLS Policies Only
-- This script is for Supabase Database > Tables section
-- Run this in the main Database section of Supabase Dashboard

-- ============================================================================
-- DATABASE TABLE RLS POLICIES
-- These policies are for business logic tables and should be 
-- configured in Supabase Dashboard > Database > Tables
-- ============================================================================

-- ============================================================================
-- PART 1: DROP EXISTING BUSINESS TABLE POLICIES
-- ============================================================================

-- Drop existing business table policies that might conflict
DROP POLICY IF EXISTS "Users can access students in their school" ON students;
DROP POLICY IF EXISTS "Users can access teachers in their school" ON teachers;
DROP POLICY IF EXISTS "Users can access course templates in their school" ON course_templates;
DROP POLICY IF EXISTS "Users can access courses in their school" ON course_instances;
DROP POLICY IF EXISTS "Users can access student payments in their school" ON student_payments;
DROP POLICY IF EXISTS "Managers and owners can access teacher payouts" ON teacher_payouts;
DROP POLICY IF EXISTS "Managers and owners can access revenue" ON revenue;
DROP POLICY IF EXISTS "Users can access attendance in their school" ON attendance;
DROP POLICY IF EXISTS "Users can access archive requests in their school" ON archive_requests;
DROP POLICY IF EXISTS "Allow all operations on students" ON students;
DROP POLICY IF EXISTS "Allow all operations on teachers" ON teachers;
DROP POLICY IF EXISTS "Allow all operations on course_templates" ON course_templates;
DROP POLICY IF EXISTS "Allow all operations on course_instances" ON course_instances;
DROP POLICY IF EXISTS "Allow all operations on student_payments" ON student_payments;
DROP POLICY IF EXISTS "Allow all operations on teacher_payouts" ON teacher_payouts;
DROP POLICY IF EXISTS "Allow all operations on revenue" ON revenue;
DROP POLICY IF EXISTS "Allow all operations on attendance" ON attendance;
DROP POLICY IF EXISTS "Allow all operations on archive_requests" ON archive_requests;

-- ============================================================================
-- PART 2: STUDENTS TABLE POLICIES
-- ============================================================================

-- Students - All users can manage students in their school
CREATE POLICY "Users can access students in their school" ON students
    FOR ALL USING (
        school_id = (SELECT school_id FROM profiles WHERE id = auth.uid())
    ) WITH CHECK (
        school_id = (SELECT school_id FROM profiles WHERE id = auth.uid())
    );

-- ============================================================================
-- PART 3: TEACHERS TABLE POLICIES
-- ============================================================================

-- Teachers - All users can manage teachers in their school
CREATE POLICY "Users can access teachers in their school" ON teachers
    FOR ALL USING (
        school_id = (SELECT school_id FROM profiles WHERE id = auth.uid())
    ) WITH CHECK (
        school_id = (SELECT school_id FROM profiles WHERE id = auth.uid())
    );

-- ============================================================================
-- PART 4: COURSE TEMPLATES TABLE POLICIES
-- ============================================================================

-- Course templates - All users can manage course templates in their school
CREATE POLICY "Users can access course templates in their school" ON course_templates
    FOR ALL USING (
        school_id = (SELECT school_id FROM profiles WHERE id = auth.uid())
    ) WITH CHECK (
        school_id = (SELECT school_id FROM profiles WHERE id = auth.uid())
    );

-- ============================================================================
-- PART 5: COURSE INSTANCES TABLE POLICIES
-- ============================================================================

-- Course instances - All users can manage courses in their school
CREATE POLICY "Users can access courses in their school" ON course_instances
    FOR ALL USING (
        school_id = (SELECT school_id FROM profiles WHERE id = auth.uid())
    ) WITH CHECK (
        school_id = (SELECT school_id FROM profiles WHERE id = auth.uid())
    );

-- ============================================================================
-- PART 6: STUDENT PAYMENTS TABLE POLICIES
-- ============================================================================

-- Student payments - All users can manage student payments in their school
CREATE POLICY "Users can access student payments in their school" ON student_payments
    FOR ALL USING (
        school_id = (SELECT school_id FROM profiles WHERE id = auth.uid())
    ) WITH CHECK (
        school_id = (SELECT school_id FROM profiles WHERE id = auth.uid())
    );

-- ============================================================================
-- PART 7: TEACHER PAYOUTS TABLE POLICIES (RESTRICTED)
-- ============================================================================

-- Teacher payouts - Only managers and owners can access
CREATE POLICY "Managers and owners can access teacher payouts" ON teacher_payouts
    FOR ALL USING (
        school_id = (
            SELECT school_id FROM profiles 
            WHERE id = auth.uid() AND role IN ('owner', 'manager')
        )
    ) WITH CHECK (
        school_id = (
            SELECT school_id FROM profiles 
            WHERE id = auth.uid() AND role IN ('owner', 'manager')
        )
    );

-- ============================================================================
-- PART 8: REVENUE TABLE POLICIES (RESTRICTED)
-- ============================================================================

-- Revenue - Only managers and owners can access
CREATE POLICY "Managers and owners can access revenue" ON revenue
    FOR ALL USING (
        school_id = (
            SELECT school_id FROM profiles 
            WHERE id = auth.uid() AND role IN ('owner', 'manager')
        )
    ) WITH CHECK (
        school_id = (
            SELECT school_id FROM profiles 
            WHERE id = auth.uid() AND role IN ('owner', 'manager')
        )
    );

-- ============================================================================
-- PART 9: ATTENDANCE TABLE POLICIES
-- ============================================================================

-- Attendance - All users can manage attendance in their school
CREATE POLICY "Users can access attendance in their school" ON attendance
    FOR ALL USING (
        school_id = (SELECT school_id FROM profiles WHERE id = auth.uid())
    ) WITH CHECK (
        school_id = (SELECT school_id FROM profiles WHERE id = auth.uid())
    );

-- ============================================================================
-- PART 10: ARCHIVE REQUESTS TABLE POLICIES
-- ============================================================================

-- Archive requests - All users can manage archive requests in their school
CREATE POLICY "Users can access archive requests in their school" ON archive_requests
    FOR ALL USING (
        school_id = (SELECT school_id FROM profiles WHERE id = auth.uid())
    ) WITH CHECK (
        school_id = (SELECT school_id FROM profiles WHERE id = auth.uid())
    );

-- ============================================================================
-- PART 11: ENABLE RLS ON ALL BUSINESS TABLES
-- ============================================================================

-- Enable RLS on business tables if they exist
DO $$
BEGIN
    -- Only enable RLS if tables exist
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'students') THEN
        ALTER TABLE students ENABLE ROW LEVEL SECURITY;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'teachers') THEN
        ALTER TABLE teachers ENABLE ROW LEVEL SECURITY;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'course_templates') THEN
        ALTER TABLE course_templates ENABLE ROW LEVEL SECURITY;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'course_instances') THEN
        ALTER TABLE course_instances ENABLE ROW LEVEL SECURITY;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'student_payments') THEN
        ALTER TABLE student_payments ENABLE ROW LEVEL SECURITY;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'teacher_payouts') THEN
        ALTER TABLE teacher_payouts ENABLE ROW LEVEL SECURITY;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'revenue') THEN
        ALTER TABLE revenue ENABLE ROW LEVEL SECURITY;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'attendance') THEN
        ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'archive_requests') THEN
        ALTER TABLE archive_requests ENABLE ROW LEVEL SECURITY;
    END IF;
END $$;

-- ============================================================================
-- COMMENTS FOR POLICY UNDERSTANDING
-- ============================================================================

COMMENT ON POLICY "Users can access students in their school" ON students IS 
'Multi-tenant policy: Users can only access students that belong to their school';

COMMENT ON POLICY "Users can access teachers in their school" ON teachers IS 
'Multi-tenant policy: Users can only access teachers that belong to their school';

COMMENT ON POLICY "Managers and owners can access teacher payouts" ON teacher_payouts IS 
'Restricted access: Only users with manager or owner roles can access teacher payout information';

COMMENT ON POLICY "Managers and owners can access revenue" ON revenue IS 
'Restricted access: Only users with manager or owner roles can access revenue information';

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'DATABASE RLS POLICIES CONFIGURED SUCCESSFULLY!';
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'Policies created for Database tables:';
    RAISE NOTICE '  ✓ Students: All users can manage in their school';
    RAISE NOTICE '  ✓ Teachers: All users can manage in their school';
    RAISE NOTICE '  ✓ Course Templates: All users can manage in their school';
    RAISE NOTICE '  ✓ Course Instances: All users can manage in their school';
    RAISE NOTICE '  ✓ Student Payments: All users can manage in their school';
    RAISE NOTICE '  ✓ Teacher Payouts: Only managers/owners can access';
    RAISE NOTICE '  ✓ Revenue: Only managers/owners can access';
    RAISE NOTICE '  ✓ Attendance: All users can manage in their school';
    RAISE NOTICE '  ✓ Archive Requests: All users can manage in their school';
    RAISE NOTICE '';
    RAISE NOTICE 'Security Features:';
    RAISE NOTICE '  ✓ Multi-tenant isolation by school_id';
    RAISE NOTICE '  ✓ Role-based access for financial data';
    RAISE NOTICE '  ✓ Complete data separation between schools';
    RAISE NOTICE '';
    RAISE NOTICE 'All business table RLS policies are now active!';
    RAISE NOTICE '============================================================================';
END $$;
