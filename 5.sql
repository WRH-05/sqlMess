-- Kennedy Management System - Database Tables and Functions Only (CLEAN VERSION)
-- This script creates the core database structure without RLS policies
-- Run this in Supabase Database > SQL Editor

-- ============================================================================
-- DATABASE STRUCTURE SETUP
-- This file contains only table creation, functions, and triggers
-- RLS policies are handled separately in fix-auth-rls-only.sql and fix-database-rls-only.sql
-- ============================================================================

-- ============================================================================
-- PART 1: EXTENSIONS AND ENUMS
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create user role enum if it doesn't exist
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('owner', 'manager', 'receptionist');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Create payment status enums if they don't exist
DO $$ BEGIN
    CREATE TYPE payment_status AS ENUM ('pending', 'paid', 'approved', 'declined');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE payout_status AS ENUM ('pending', 'approved', 'paid', 'declined');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE request_status AS ENUM ('pending', 'approved', 'declined');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ============================================================================
-- PART 2: AUTHENTICATION TABLES
-- ============================================================================

-- Schools table - Multi-tenant organizations
CREATE TABLE IF NOT EXISTS schools (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    address TEXT,
    phone TEXT,
    email TEXT,
    website TEXT,
    logo_url TEXT,
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL
);

-- Profiles table - Extends Supabase auth.users with school association
CREATE TABLE IF NOT EXISTS profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    school_id UUID REFERENCES schools(id) ON DELETE CASCADE NOT NULL,
    role user_role NOT NULL DEFAULT 'receptionist',
    full_name TEXT NOT NULL,
    phone TEXT,
    avatar_url TEXT,
    invited_by UUID REFERENCES profiles(id),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL
);

-- Invitations table - Invite-only registration system
CREATE TABLE IF NOT EXISTS invitations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT NOT NULL,
    role user_role NOT NULL DEFAULT 'receptionist',
    school_id UUID REFERENCES schools(id) ON DELETE CASCADE NOT NULL,
    invited_by UUID REFERENCES profiles(id) ON DELETE CASCADE,
    token UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT (NOW() + INTERVAL '7 days'),
    accepted_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL
);

-- ============================================================================
-- PART 3: ADD SCHOOL_ID TO EXISTING BUSINESS TABLES (SAFE)
-- ============================================================================

-- Add school_id to existing tables if the column doesn't exist
DO $$
BEGIN
    -- Add school_id to students table if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'students' AND column_name = 'school_id') THEN
        ALTER TABLE students ADD COLUMN school_id UUID REFERENCES schools(id) ON DELETE CASCADE;
    END IF;
    
    -- Add school_id to teachers table if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'teachers' AND column_name = 'school_id') THEN
        ALTER TABLE teachers ADD COLUMN school_id UUID REFERENCES schools(id) ON DELETE CASCADE;
    END IF;
    
    -- Add school_id to course_instances table if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'course_instances' AND column_name = 'school_id') THEN
        ALTER TABLE course_instances ADD COLUMN school_id UUID REFERENCES schools(id) ON DELETE CASCADE;
    END IF;
    
    -- Add school_id to student_payments table if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'student_payments' AND column_name = 'school_id') THEN
        ALTER TABLE student_payments ADD COLUMN school_id UUID REFERENCES schools(id) ON DELETE CASCADE;
    END IF;
    
    -- Add school_id to teacher_payouts table if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'teacher_payouts' AND column_name = 'school_id') THEN
        ALTER TABLE teacher_payouts ADD COLUMN school_id UUID REFERENCES schools(id) ON DELETE CASCADE;
    END IF;
    
    -- Add school_id to revenue table if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'revenue' AND column_name = 'school_id') THEN
        ALTER TABLE revenue ADD COLUMN school_id UUID REFERENCES schools(id) ON DELETE CASCADE;
    END IF;
    
    -- Add school_id to attendance table if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'attendance' AND column_name = 'school_id') THEN
        ALTER TABLE attendance ADD COLUMN school_id UUID REFERENCES schools(id) ON DELETE CASCADE;
    END IF;
    
    -- Add school_id to archive_requests table if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'archive_requests' AND column_name = 'school_id') THEN
        ALTER TABLE archive_requests ADD COLUMN school_id UUID REFERENCES schools(id) ON DELETE CASCADE;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        -- Tables might not exist yet, which is fine
        NULL;
END $$;

-- ============================================================================
-- PART 4: ENABLE RLS ON AUTHENTICATION TABLES
-- ============================================================================

-- Enable RLS on authentication tables
ALTER TABLE schools ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE invitations ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- PART 5: AUTHENTICATION TRIGGER FUNCTION (CRITICAL)
-- ============================================================================

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user() CASCADE;

-- Create the corrected user creation function
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    invitation_record RECORD;
    user_school_id UUID;
    user_role TEXT;
    user_full_name TEXT;
    user_phone TEXT;
BEGIN
    -- Only process INSERT events with raw_user_meta_data
    IF TG_OP = 'INSERT' AND NEW.raw_user_meta_data IS NOT NULL THEN
        
        -- Check if this is an owner signup during school creation
        IF NEW.raw_user_meta_data->>'is_owner_signup' = 'true' THEN
            user_school_id := (NEW.raw_user_meta_data->>'school_id')::UUID;
            user_role := 'owner';
            user_full_name := COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1));
            user_phone := NEW.raw_user_meta_data->>'phone';

            -- Create profile immediately for owner
            INSERT INTO profiles (id, school_id, role, full_name, phone, is_active)
            VALUES (NEW.id, user_school_id, user_role::user_role, user_full_name, user_phone, true)
            ON CONFLICT (id) DO UPDATE SET
                school_id = EXCLUDED.school_id,
                role = EXCLUDED.role,
                full_name = EXCLUDED.full_name,
                phone = EXCLUDED.phone,
                updated_at = NOW();

            RAISE NOTICE 'Created owner profile for user % in school %', NEW.id, user_school_id;
            
        ELSIF NEW.raw_user_meta_data->>'invitation_token' IS NOT NULL THEN
            -- This is an invitation-based signup
            SELECT * INTO invitation_record
            FROM invitations
            WHERE token = (NEW.raw_user_meta_data->>'invitation_token')::UUID
            AND email = NEW.email
            AND accepted_at IS NULL
            AND expires_at > NOW()
            LIMIT 1;

            IF FOUND THEN
                INSERT INTO profiles (id, school_id, role, full_name, invited_by, is_active)
                VALUES (
                    NEW.id,
                    invitation_record.school_id,
                    invitation_record.role,
                    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
                    invitation_record.invited_by,
                    true
                )
                ON CONFLICT (id) DO UPDATE SET
                    school_id = EXCLUDED.school_id,
                    role = EXCLUDED.role,
                    full_name = EXCLUDED.full_name,
                    invited_by = EXCLUDED.invited_by,
                    updated_at = NOW();

                -- Mark invitation as accepted
                UPDATE invitations
                SET accepted_at = NOW()
                WHERE id = invitation_record.id;

                RAISE NOTICE 'Created invited user profile for user % in school %', NEW.id, invitation_record.school_id;
            ELSE
                RAISE WARNING 'No valid invitation found for user %', NEW.email;
            END IF;
        END IF;
    END IF;

    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Failed to create profile for user %: %', NEW.id, SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================================
-- PART 6: CORE BUSINESS TABLES
-- ============================================================================

-- Students table with complete field set
CREATE TABLE IF NOT EXISTS students (
    id SERIAL PRIMARY KEY,
    school_id UUID REFERENCES schools(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    school_year TEXT,
    specialty TEXT,
    address TEXT,
    birth_date DATE,
    phone TEXT,
    email TEXT,
    school TEXT,
    registration_date DATE DEFAULT CURRENT_DATE,
    registration_fee_paid BOOLEAN DEFAULT false,
    documents JSONB DEFAULT '{}',
    archived BOOLEAN DEFAULT false,
    archived_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL
);

-- Teachers table with complete field set
CREATE TABLE IF NOT EXISTS teachers (
    id SERIAL PRIMARY KEY,
    school_id UUID REFERENCES schools(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    address TEXT,
    phone TEXT,
    email TEXT,
    school TEXT,
    school_years TEXT[],
    subjects TEXT[],
    total_students INTEGER DEFAULT 0,
    monthly_earnings DECIMAL(10,2) DEFAULT 0.00,
    join_date DATE DEFAULT CURRENT_DATE,
    archived BOOLEAN DEFAULT false,
    archived_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL
);

-- Course templates for reusable course definitions
CREATE TABLE IF NOT EXISTS course_templates (
    id SERIAL PRIMARY KEY,
    school_id UUID REFERENCES schools(id) ON DELETE CASCADE NOT NULL,
    subject TEXT NOT NULL,
    school_year TEXT NOT NULL,
    description TEXT,
    duration_weeks INTEGER DEFAULT 12,
    price_per_student DECIMAL(10,2) DEFAULT 0.00,
    max_students INTEGER DEFAULT 20,
    archived BOOLEAN DEFAULT false,
    archived_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL
);

-- Course instances - actual course sessions
CREATE TABLE IF NOT EXISTS course_instances (
    id SERIAL PRIMARY KEY,
    school_id UUID REFERENCES schools(id) ON DELETE CASCADE NOT NULL,
    template_id INTEGER REFERENCES course_templates(id) ON DELETE SET NULL,
    teacher_id INTEGER REFERENCES teachers(id) ON DELETE CASCADE NOT NULL,
    teacher_name TEXT NOT NULL, -- Denormalized for easier queries
    subject TEXT NOT NULL,
    school_year TEXT NOT NULL,
    start_date DATE DEFAULT CURRENT_DATE,
    end_date DATE,
    duration_weeks INTEGER DEFAULT 12,
    price_per_student DECIMAL(10,2) DEFAULT 0.00,
    monthly_price DECIMAL(10,2) DEFAULT 0.00,
    percentage_cut INTEGER DEFAULT 50,
    student_ids INTEGER[] DEFAULT '{}',
    enrolled_students INTEGER DEFAULT 0,
    max_students INTEGER DEFAULT 20,
    payments JSONB DEFAULT '{}', -- { studentId: 'paid'/'pending' }
    attendance JSONB DEFAULT '{}', -- { studentId: { week1: true, week2: false } }
    archived BOOLEAN DEFAULT false,
    archived_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL
);

-- ============================================================================
-- PART 7: FINANCIAL TRACKING TABLES
-- ============================================================================

-- Student payments - Individual payment records
CREATE TABLE IF NOT EXISTS student_payments (
    id BIGSERIAL PRIMARY KEY,
    school_id UUID REFERENCES schools(id) ON DELETE CASCADE NOT NULL,
    student_id INTEGER REFERENCES students(id) ON DELETE CASCADE NOT NULL,
    course_id INTEGER REFERENCES course_instances(id) ON DELETE CASCADE,
    amount DECIMAL(10,2) NOT NULL,
    payment_date DATE DEFAULT CURRENT_DATE,
    payment_method TEXT DEFAULT 'cash',
    status payment_status DEFAULT 'pending',
    approved_by UUID REFERENCES profiles(id),
    approved_date TIMESTAMP WITH TIME ZONE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL
);

-- Teacher payouts - Teacher payment tracking
CREATE TABLE IF NOT EXISTS teacher_payouts (
    id BIGSERIAL PRIMARY KEY,
    school_id UUID REFERENCES schools(id) ON DELETE CASCADE NOT NULL,
    teacher_id INTEGER REFERENCES teachers(id) ON DELETE CASCADE NOT NULL,
    course_id INTEGER REFERENCES course_instances(id) ON DELETE CASCADE,
    amount DECIMAL(10,2) NOT NULL,
    percentage_cut INTEGER NOT NULL,
    payment_date DATE DEFAULT CURRENT_DATE,
    status payout_status DEFAULT 'pending',
    approved_by UUID REFERENCES profiles(id),
    approved_date TIMESTAMP WITH TIME ZONE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL
);

-- Revenue tracking table
CREATE TABLE IF NOT EXISTS revenue (
    id BIGSERIAL PRIMARY KEY,
    school_id UUID REFERENCES schools(id) ON DELETE CASCADE NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    source TEXT,
    description TEXT,
    date DATE DEFAULT CURRENT_DATE,
    status TEXT DEFAULT 'recorded',
    student_id INTEGER REFERENCES students(id),
    course_id INTEGER REFERENCES course_instances(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL
);

-- ============================================================================
-- PART 8: OPERATIONAL TABLES
-- ============================================================================

-- Attendance tracking - Individual records per student/week
CREATE TABLE IF NOT EXISTS attendance (
    id SERIAL PRIMARY KEY,
    school_id UUID REFERENCES schools(id) ON DELETE CASCADE NOT NULL,
    course_id INTEGER REFERENCES course_instances(id) ON DELETE CASCADE NOT NULL,
    student_id INTEGER REFERENCES students(id) ON DELETE CASCADE NOT NULL,
    week INTEGER NOT NULL,
    attended BOOLEAN DEFAULT false,
    date DATE DEFAULT CURRENT_DATE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL
);

-- Archive requests - Soft delete management
CREATE TABLE IF NOT EXISTS archive_requests (
    id SERIAL PRIMARY KEY,
    school_id UUID REFERENCES schools(id) ON DELETE CASCADE NOT NULL,
    entity_type TEXT NOT NULL, -- 'student', 'teacher', 'course'
    entity_id INTEGER NOT NULL,
    entity_name TEXT,
    requested_by UUID REFERENCES profiles(id),
    requested_date TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    approved_by UUID REFERENCES profiles(id),
    approved_date TIMESTAMP WITH TIME ZONE,
    status request_status DEFAULT 'pending',
    reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL
);

-- ============================================================================
-- PART 9: HELPER FUNCTIONS
-- ============================================================================

-- Function to get user context (for debugging)
CREATE OR REPLACE FUNCTION get_user_context()
RETURNS TABLE (
    user_id UUID,
    school_id UUID,
    role TEXT,
    full_name TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.school_id,
        p.role::TEXT,
        p.full_name
    FROM profiles p
    WHERE p.id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user has role
CREATE OR REPLACE FUNCTION user_has_role(required_role TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid() AND role::TEXT = required_role
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- PART 10: GRANT PERMISSIONS
-- ============================================================================

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Auth schema permissions for trigger functions
GRANT SELECT ON auth.users TO authenticated;

-- ============================================================================
-- PART 11: CREATE PERFORMANCE INDEXES
-- ============================================================================

-- Create indexes for authentication tables
CREATE INDEX IF NOT EXISTS idx_profiles_school_id ON profiles(school_id);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);
CREATE INDEX IF NOT EXISTS idx_invitations_school_id ON invitations(school_id);
CREATE INDEX IF NOT EXISTS idx_invitations_token ON invitations(token);
CREATE INDEX IF NOT EXISTS idx_invitations_email ON invitations(email);

-- Create indexes for business tables
CREATE INDEX IF NOT EXISTS idx_students_school_id ON students(school_id);
CREATE INDEX IF NOT EXISTS idx_students_archived ON students(archived);
CREATE INDEX IF NOT EXISTS idx_teachers_school_id ON teachers(school_id);
CREATE INDEX IF NOT EXISTS idx_teachers_archived ON teachers(archived);
CREATE INDEX IF NOT EXISTS idx_course_templates_school_id ON course_templates(school_id);
CREATE INDEX IF NOT EXISTS idx_course_instances_school_id ON course_instances(school_id);
CREATE INDEX IF NOT EXISTS idx_course_instances_teacher_id ON course_instances(teacher_id);
CREATE INDEX IF NOT EXISTS idx_course_instances_archived ON course_instances(archived);
CREATE INDEX IF NOT EXISTS idx_student_payments_school_id ON student_payments(school_id);
CREATE INDEX IF NOT EXISTS idx_student_payments_student_id ON student_payments(student_id);
CREATE INDEX IF NOT EXISTS idx_student_payments_status ON student_payments(status);
CREATE INDEX IF NOT EXISTS idx_teacher_payouts_school_id ON teacher_payouts(school_id);
CREATE INDEX IF NOT EXISTS idx_teacher_payouts_teacher_id ON teacher_payouts(teacher_id);
CREATE INDEX IF NOT EXISTS idx_teacher_payouts_status ON teacher_payouts(status);
CREATE INDEX IF NOT EXISTS idx_revenue_school_id ON revenue(school_id);
CREATE INDEX IF NOT EXISTS idx_attendance_school_id ON attendance(school_id);
CREATE INDEX IF NOT EXISTS idx_attendance_course_id ON attendance(course_id);
CREATE INDEX IF NOT EXISTS idx_attendance_student_id ON attendance(student_id);
CREATE INDEX IF NOT EXISTS idx_archive_requests_school_id ON archive_requests(school_id);

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'DATABASE STRUCTURE CREATED SUCCESSFULLY!';
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'Tables Created:';
    RAISE NOTICE '  ✓ Authentication: schools, profiles, invitations';
    RAISE NOTICE '  ✓ Business: students, teachers, course_templates, course_instances';
    RAISE NOTICE '  ✓ Financial: student_payments, teacher_payouts, revenue';
    RAISE NOTICE '  ✓ Operational: attendance, archive_requests';
    RAISE NOTICE '';
    RAISE NOTICE 'Functions & Triggers:';
    RAISE NOTICE '  ✓ User registration trigger (handle_new_user)';
    RAISE NOTICE '  ✓ Helper functions (get_user_context, user_has_role)';
    RAISE NOTICE '';
    RAISE NOTICE 'Performance Features:';
    RAISE NOTICE '  ✓ Indexes for optimal multi-tenant queries';
    RAISE NOTICE '  ✓ Proper foreign key relationships';
    RAISE NOTICE '  ✓ JSONB fields for flexible data storage';
    RAISE NOTICE '';
    RAISE NOTICE 'Next Steps:';
    RAISE NOTICE '  1. Run enable-email-confirmation.sql (if using email confirmation)';
    RAISE NOTICE '  2. Run fix-auth-rls-only.sql (Authentication policies)';
    RAISE NOTICE '  3. Run fix-database-rls-only.sql (Business table policies)';
    RAISE NOTICE '============================================================================';
END $$;
