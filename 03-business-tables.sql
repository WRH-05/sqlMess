-- Kennedy Management System - Business Tables
-- This script creates all business logic tables (students, teachers, courses, etc.)
-- Run this THIRD after 02-authentication-tables.sql

-- ============================================================================
-- CORE BUSINESS ENTITIES
-- ============================================================================

-- Students table - Student information and registration tracking
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
    school TEXT, -- Previous school attended
    registration_date DATE DEFAULT CURRENT_DATE,
    registration_fee_paid BOOLEAN DEFAULT false,
    documents JSONB DEFAULT '{}', -- Store document metadata/URLs
    archived BOOLEAN DEFAULT false,
    archived_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    
    -- Constraints
    CONSTRAINT students_name_not_empty CHECK (trim(name) <> ''),
    CONSTRAINT students_email_format CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' OR email IS NULL),
    CONSTRAINT students_phone_format CHECK (phone ~ '^[\+\d\s\-\(\)]+$' OR phone IS NULL),
    CONSTRAINT students_birth_date_reasonable CHECK (birth_date IS NULL OR birth_date BETWEEN '1900-01-01' AND CURRENT_DATE),
    CONSTRAINT students_archived_date_logic CHECK (archived = false OR archived_date IS NOT NULL)
);

-- Teachers table - Teacher information and statistics
CREATE TABLE IF NOT EXISTS teachers (
    id SERIAL PRIMARY KEY,
    school_id UUID REFERENCES schools(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    address TEXT,
    phone TEXT,
    email TEXT,
    school TEXT, -- Previous school where they taught
    school_years TEXT[], -- Array of school years they can teach
    subjects TEXT[], -- Array of subjects they can teach
    total_students INTEGER DEFAULT 0,
    monthly_earnings DECIMAL(10,2) DEFAULT 0.00,
    join_date DATE DEFAULT CURRENT_DATE,
    archived BOOLEAN DEFAULT false,
    archived_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    
    -- Constraints
    CONSTRAINT teachers_name_not_empty CHECK (trim(name) <> ''),
    CONSTRAINT teachers_email_format CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' OR email IS NULL),
    CONSTRAINT teachers_phone_format CHECK (phone ~ '^[\+\d\s\-\(\)]+$' OR phone IS NULL),
    CONSTRAINT teachers_total_students_positive CHECK (total_students >= 0),
    CONSTRAINT teachers_monthly_earnings_positive CHECK (monthly_earnings >= 0),
    CONSTRAINT teachers_archived_date_logic CHECK (archived = false OR archived_date IS NOT NULL)
);

-- ============================================================================
-- COURSE MANAGEMENT
-- ============================================================================

-- Course templates - Reusable course definitions
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
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    
    -- Constraints
    CONSTRAINT course_templates_subject_not_empty CHECK (trim(subject) <> ''),
    CONSTRAINT course_templates_school_year_not_empty CHECK (trim(school_year) <> ''),
    CONSTRAINT course_templates_duration_positive CHECK (duration_weeks > 0),
    CONSTRAINT course_templates_price_positive CHECK (price_per_student >= 0),
    CONSTRAINT course_templates_max_students_positive CHECK (max_students > 0),
    CONSTRAINT course_templates_archived_date_logic CHECK (archived = false OR archived_date IS NOT NULL),
    CONSTRAINT course_templates_unique_per_school UNIQUE (school_id, subject, school_year)
);

-- Course instances - Actual course sessions with teachers and students
CREATE TABLE IF NOT EXISTS course_instances (
    id SERIAL PRIMARY KEY,
    school_id UUID REFERENCES schools(id) ON DELETE CASCADE NOT NULL,
    template_id INTEGER REFERENCES course_templates(id) ON DELETE SET NULL,
    teacher_id INTEGER REFERENCES teachers(id) ON DELETE CASCADE NOT NULL,
    teacher_name TEXT NOT NULL, -- Denormalized for performance
    subject TEXT NOT NULL,
    school_year TEXT NOT NULL,
    start_date DATE DEFAULT CURRENT_DATE,
    end_date DATE,
    duration_weeks INTEGER DEFAULT 12,
    price_per_student DECIMAL(10,2) DEFAULT 0.00,
    monthly_price DECIMAL(10,2) DEFAULT 0.00, -- Calculated field
    percentage_cut INTEGER DEFAULT 50, -- Teacher's percentage
    student_ids INTEGER[] DEFAULT '{}', -- Array of enrolled student IDs
    enrolled_students INTEGER DEFAULT 0, -- Calculated field
    max_students INTEGER DEFAULT 20,
    payments JSONB DEFAULT '{}', -- { student_id: status } for quick lookup
    attendance JSONB DEFAULT '{}', -- { student_id: { week: boolean } }
    archived BOOLEAN DEFAULT false,
    archived_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    
    -- Constraints
    CONSTRAINT course_instances_subject_not_empty CHECK (trim(subject) <> ''),
    CONSTRAINT course_instances_school_year_not_empty CHECK (trim(school_year) <> ''),
    CONSTRAINT course_instances_teacher_name_not_empty CHECK (trim(teacher_name) <> ''),
    CONSTRAINT course_instances_duration_positive CHECK (duration_weeks > 0),
    CONSTRAINT course_instances_price_positive CHECK (price_per_student >= 0),
    CONSTRAINT course_instances_monthly_price_positive CHECK (monthly_price >= 0),
    CONSTRAINT course_instances_percentage_valid CHECK (percentage_cut >= 0 AND percentage_cut <= 100),
    CONSTRAINT course_instances_enrolled_positive CHECK (enrolled_students >= 0),
    CONSTRAINT course_instances_max_students_positive CHECK (max_students > 0),
    CONSTRAINT course_instances_date_logic CHECK (end_date IS NULL OR end_date >= start_date),
    CONSTRAINT course_instances_archived_date_logic CHECK (archived = false OR archived_date IS NOT NULL)
);

-- ============================================================================
-- FINANCIAL TRACKING
-- ============================================================================

-- Student payments - Individual payment records with full audit trail
CREATE TABLE IF NOT EXISTS student_payments (
    id BIGSERIAL PRIMARY KEY,
    school_id UUID REFERENCES schools(id) ON DELETE CASCADE NOT NULL,
    student_id INTEGER REFERENCES students(id) ON DELETE CASCADE NOT NULL,
    course_id INTEGER REFERENCES course_instances(id) ON DELETE CASCADE,
    amount DECIMAL(10,2) NOT NULL,
    payment_date DATE DEFAULT CURRENT_DATE,
    payment_method TEXT DEFAULT 'cash',
    status payment_status DEFAULT 'pending',
    approved_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    approved_date TIMESTAMP WITH TIME ZONE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    
    -- Constraints
    CONSTRAINT student_payments_amount_positive CHECK (amount > 0),
    CONSTRAINT student_payments_payment_method_valid CHECK (payment_method IN ('cash', 'card', 'transfer', 'check', 'other')),
    CONSTRAINT student_payments_approval_logic CHECK (
        (status IN ('approved', 'paid') AND approved_by IS NOT NULL AND approved_date IS NOT NULL) OR
        (status IN ('pending', 'declined'))
    )
);

-- Teacher payouts - Teacher payment tracking with audit trail
CREATE TABLE IF NOT EXISTS teacher_payouts (
    id BIGSERIAL PRIMARY KEY,
    school_id UUID REFERENCES schools(id) ON DELETE CASCADE NOT NULL,
    teacher_id INTEGER REFERENCES teachers(id) ON DELETE CASCADE NOT NULL,
    course_id INTEGER REFERENCES course_instances(id) ON DELETE CASCADE,
    amount DECIMAL(10,2) NOT NULL,
    percentage_cut INTEGER NOT NULL,
    payment_date DATE DEFAULT CURRENT_DATE,
    status payout_status DEFAULT 'pending',
    approved_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    approved_date TIMESTAMP WITH TIME ZONE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    
    -- Constraints
    CONSTRAINT teacher_payouts_amount_positive CHECK (amount > 0),
    CONSTRAINT teacher_payouts_percentage_valid CHECK (percentage_cut >= 0 AND percentage_cut <= 100),
    CONSTRAINT teacher_payouts_approval_logic CHECK (
        (status IN ('approved', 'paid') AND approved_by IS NOT NULL AND approved_date IS NOT NULL) OR
        (status IN ('pending', 'declined'))
    )
);

-- Revenue tracking - School revenue with categorization
CREATE TABLE IF NOT EXISTS revenue (
    id BIGSERIAL PRIMARY KEY,
    school_id UUID REFERENCES schools(id) ON DELETE CASCADE NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    source TEXT NOT NULL, -- 'student_payment', 'registration_fee', 'other'
    description TEXT,
    date DATE DEFAULT CURRENT_DATE,
    status TEXT DEFAULT 'recorded',
    student_id INTEGER REFERENCES students(id) ON DELETE SET NULL,
    course_id INTEGER REFERENCES course_instances(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    
    -- Constraints
    CONSTRAINT revenue_amount_not_zero CHECK (amount <> 0), -- Allow negative for refunds
    CONSTRAINT revenue_source_not_empty CHECK (trim(source) <> ''),
    CONSTRAINT revenue_status_valid CHECK (status IN ('recorded', 'verified', 'cancelled'))
);

-- ============================================================================
-- OPERATIONAL TRACKING
-- ============================================================================

-- Attendance tracking - Individual attendance records per student/week
CREATE TABLE IF NOT EXISTS attendance (
    id SERIAL PRIMARY KEY,
    school_id UUID REFERENCES schools(id) ON DELETE CASCADE NOT NULL,
    course_id INTEGER REFERENCES course_instances(id) ON DELETE CASCADE NOT NULL,
    student_id INTEGER REFERENCES students(id) ON DELETE CASCADE NOT NULL,
    week INTEGER NOT NULL,
    attended BOOLEAN DEFAULT false,
    date DATE DEFAULT CURRENT_DATE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    
    -- Constraints
    CONSTRAINT attendance_week_positive CHECK (week > 0),
    CONSTRAINT attendance_unique_per_week UNIQUE (course_id, student_id, week) -- Prevent duplicate attendance records
);

-- Archive requests - Soft delete management system
CREATE TABLE IF NOT EXISTS archive_requests (
    id SERIAL PRIMARY KEY,
    school_id UUID REFERENCES schools(id) ON DELETE CASCADE NOT NULL,
    entity_type TEXT NOT NULL, -- 'student', 'teacher', 'course', 'course_template'
    entity_id INTEGER NOT NULL,
    entity_name TEXT NOT NULL, -- For audit trail
    requested_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    requested_date TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    approved_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    approved_date TIMESTAMP WITH TIME ZONE,
    status request_status DEFAULT 'pending',
    reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    
    -- Constraints
    CONSTRAINT archive_requests_entity_type_valid CHECK (entity_type IN ('student', 'teacher', 'course', 'course_template')),
    CONSTRAINT archive_requests_entity_name_not_empty CHECK (trim(entity_name) <> ''),
    CONSTRAINT archive_requests_entity_id_positive CHECK (entity_id > 0),
    CONSTRAINT archive_requests_approval_logic CHECK (
        (status = 'approved' AND approved_by IS NOT NULL AND approved_date IS NOT NULL) OR
        (status IN ('pending', 'declined'))
    ),
    CONSTRAINT archive_requests_unique_pending UNIQUE (entity_type, entity_id, status) -- Prevent duplicate pending requests
);

-- ============================================================================
-- PERFORMANCE INDEXES FOR BUSINESS TABLES
-- ============================================================================

-- Students table indexes
CREATE INDEX IF NOT EXISTS idx_students_school_id ON students(school_id);
CREATE INDEX IF NOT EXISTS idx_students_archived ON students(archived);
CREATE INDEX IF NOT EXISTS idx_students_school_archived ON students(school_id, archived); -- Composite for active students
CREATE INDEX IF NOT EXISTS idx_students_name_search ON students USING gin(to_tsvector('english', name)); -- Full text search
CREATE INDEX IF NOT EXISTS idx_students_school_year ON students(school_year);

-- Teachers table indexes
CREATE INDEX IF NOT EXISTS idx_teachers_school_id ON teachers(school_id);
CREATE INDEX IF NOT EXISTS idx_teachers_archived ON teachers(archived);
CREATE INDEX IF NOT EXISTS idx_teachers_school_archived ON teachers(school_id, archived); -- Composite for active teachers
CREATE INDEX IF NOT EXISTS idx_teachers_subjects ON teachers USING gin(subjects); -- Array search
CREATE INDEX IF NOT EXISTS idx_teachers_school_years ON teachers USING gin(school_years); -- Array search

-- Course templates indexes
CREATE INDEX IF NOT EXISTS idx_course_templates_school_id ON course_templates(school_id);
CREATE INDEX IF NOT EXISTS idx_course_templates_archived ON course_templates(archived);
CREATE INDEX IF NOT EXISTS idx_course_templates_subject_year ON course_templates(subject, school_year);

-- Course instances indexes
CREATE INDEX IF NOT EXISTS idx_course_instances_school_id ON course_instances(school_id);
CREATE INDEX IF NOT EXISTS idx_course_instances_teacher_id ON course_instances(teacher_id);
CREATE INDEX IF NOT EXISTS idx_course_instances_archived ON course_instances(archived);
CREATE INDEX IF NOT EXISTS idx_course_instances_school_archived ON course_instances(school_id, archived);
CREATE INDEX IF NOT EXISTS idx_course_instances_student_ids ON course_instances USING gin(student_ids); -- Array search
CREATE INDEX IF NOT EXISTS idx_course_instances_dates ON course_instances(start_date, end_date);

-- Financial table indexes
CREATE INDEX IF NOT EXISTS idx_student_payments_school_id ON student_payments(school_id);
CREATE INDEX IF NOT EXISTS idx_student_payments_student_id ON student_payments(student_id);
CREATE INDEX IF NOT EXISTS idx_student_payments_course_id ON student_payments(course_id);
CREATE INDEX IF NOT EXISTS idx_student_payments_status ON student_payments(status);
CREATE INDEX IF NOT EXISTS idx_student_payments_date ON student_payments(payment_date);
CREATE INDEX IF NOT EXISTS idx_student_payments_school_status ON student_payments(school_id, status); -- Common query

CREATE INDEX IF NOT EXISTS idx_teacher_payouts_school_id ON teacher_payouts(school_id);
CREATE INDEX IF NOT EXISTS idx_teacher_payouts_teacher_id ON teacher_payouts(teacher_id);
CREATE INDEX IF NOT EXISTS idx_teacher_payouts_course_id ON teacher_payouts(course_id);
CREATE INDEX IF NOT EXISTS idx_teacher_payouts_status ON teacher_payouts(status);
CREATE INDEX IF NOT EXISTS idx_teacher_payouts_date ON teacher_payouts(payment_date);

CREATE INDEX IF NOT EXISTS idx_revenue_school_id ON revenue(school_id);
CREATE INDEX IF NOT EXISTS idx_revenue_date ON revenue(date);
CREATE INDEX IF NOT EXISTS idx_revenue_source ON revenue(source);
CREATE INDEX IF NOT EXISTS idx_revenue_school_date ON revenue(school_id, date); -- Time-series queries

-- Operational table indexes
CREATE INDEX IF NOT EXISTS idx_attendance_school_id ON attendance(school_id);
CREATE INDEX IF NOT EXISTS idx_attendance_course_id ON attendance(course_id);
CREATE INDEX IF NOT EXISTS idx_attendance_student_id ON attendance(student_id);
CREATE INDEX IF NOT EXISTS idx_attendance_week ON attendance(week);
CREATE INDEX IF NOT EXISTS idx_attendance_course_week ON attendance(course_id, week); -- Weekly reports

CREATE INDEX IF NOT EXISTS idx_archive_requests_school_id ON archive_requests(school_id);
CREATE INDEX IF NOT EXISTS idx_archive_requests_entity ON archive_requests(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_archive_requests_status ON archive_requests(status);
CREATE INDEX IF NOT EXISTS idx_archive_requests_requested_by ON archive_requests(requested_by);

-- ============================================================================
-- ENABLE ROW LEVEL SECURITY
-- ============================================================================

-- Enable RLS on all business tables
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
-- SUCCESS MESSAGE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'BUSINESS TABLES CREATED SUCCESSFULLY!';
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'Core Entities:';
    RAISE NOTICE '  ✓ students - Student management with full profile';
    RAISE NOTICE '  ✓ teachers - Teacher management with skills tracking';
    RAISE NOTICE '';
    RAISE NOTICE 'Course Management:';
    RAISE NOTICE '  ✓ course_templates - Reusable course definitions';
    RAISE NOTICE '  ✓ course_instances - Active courses with enrollments';
    RAISE NOTICE '';
    RAISE NOTICE 'Financial Tracking:';
    RAISE NOTICE '  ✓ student_payments - Payment tracking with audit trail';
    RAISE NOTICE '  ✓ teacher_payouts - Teacher compensation tracking';
    RAISE NOTICE '  ✓ revenue - School revenue with categorization';
    RAISE NOTICE '';
    RAISE NOTICE 'Operations:';
    RAISE NOTICE '  ✓ attendance - Individual attendance tracking';
    RAISE NOTICE '  ✓ archive_requests - Soft delete management';
    RAISE NOTICE '';
    RAISE NOTICE 'Performance Features:';
    RAISE NOTICE '  ✓ Strategic indexes for all query patterns';
    RAISE NOTICE '  ✓ GIN indexes for array and text search';
    RAISE NOTICE '  ✓ Composite indexes for complex queries';
    RAISE NOTICE '  ✓ Unique constraints to prevent data corruption';
    RAISE NOTICE '';
    RAISE NOTICE 'Security Features:';
    RAISE NOTICE '  ✓ Row Level Security enabled on all tables';
    RAISE NOTICE '  ✓ Data validation constraints';
    RAISE NOTICE '  ✓ Referential integrity with proper cascades';
    RAISE NOTICE '';
    RAISE NOTICE 'Next Step: Run 04-authentication-functions.sql';
    RAISE NOTICE '============================================================================';
END $$;
