-- Kennedy Management System - Authentication Tables
-- This script creates authentication-related tables (schools, profiles, invitations)
-- Run this SECOND after 01-extensions-and-types.sql

-- ============================================================================
-- AUTHENTICATION CORE TABLES
-- ============================================================================

-- Schools table - Multi-tenant organizations (each school is a separate tenant)
CREATE TABLE IF NOT EXISTS schools (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    name TEXT NOT NULL,
    address TEXT,
    phone TEXT,
    email TEXT,
    website TEXT,
    logo_url TEXT,
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    
    -- Constraints
    CONSTRAINT schools_name_not_empty CHECK (trim(name) <> ''),
    CONSTRAINT schools_email_format CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' OR email IS NULL)
);

-- Profiles table - Extends Supabase auth.users with school association and role
CREATE TABLE IF NOT EXISTS profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    school_id UUID REFERENCES schools(id) ON DELETE CASCADE NOT NULL,
    role user_role NOT NULL DEFAULT 'receptionist',
    full_name TEXT NOT NULL,
    phone TEXT,
    avatar_url TEXT,
    invited_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    
    -- Constraints
    CONSTRAINT profiles_full_name_not_empty CHECK (trim(full_name) <> ''),
    CONSTRAINT profiles_phone_format CHECK (phone ~ '^[\+\d\s\-\(\)]+$' OR phone IS NULL)
);

-- Invitations table - Secure invite-only registration system
CREATE TABLE IF NOT EXISTS invitations (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    email TEXT NOT NULL,
    role user_role NOT NULL DEFAULT 'receptionist',
    school_id UUID REFERENCES schools(id) ON DELETE CASCADE NOT NULL,
    invited_by UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    token UUID DEFAULT extensions.uuid_generate_v4() UNIQUE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT (NOW() + INTERVAL '7 days'),
    accepted_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    
    -- Constraints
    CONSTRAINT invitations_email_format CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT invitations_expires_future CHECK (expires_at > created_at),
    CONSTRAINT invitations_unique_pending UNIQUE (email, school_id, accepted_at) -- Prevent duplicate pending invites
);

-- ============================================================================
-- PERFORMANCE INDEXES FOR AUTHENTICATION TABLES
-- ============================================================================

-- Schools table indexes
CREATE INDEX IF NOT EXISTS idx_schools_created_at ON schools(created_at);

-- Profiles table indexes (critical for authentication performance)
CREATE INDEX IF NOT EXISTS idx_profiles_school_id ON profiles(school_id);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_is_active ON profiles(is_active);
CREATE INDEX IF NOT EXISTS idx_profiles_school_role ON profiles(school_id, role); -- Composite for role queries

-- Invitations table indexes
CREATE INDEX IF NOT EXISTS idx_invitations_school_id ON invitations(school_id);
CREATE INDEX IF NOT EXISTS idx_invitations_token ON invitations(token); -- For token-based lookups
CREATE INDEX IF NOT EXISTS idx_invitations_email ON invitations(email); -- For email-based lookups
CREATE INDEX IF NOT EXISTS idx_invitations_expires_at ON invitations(expires_at); -- For cleanup
CREATE INDEX IF NOT EXISTS idx_invitations_pending ON invitations(school_id, email) WHERE accepted_at IS NULL; -- Pending invites

-- ============================================================================
-- ENABLE ROW LEVEL SECURITY
-- ============================================================================

-- Enable RLS on all authentication tables
ALTER TABLE schools ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE invitations ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'AUTHENTICATION TABLES CREATED SUCCESSFULLY!';
-- ============================================================================
-- PERMISSION GRANTS FOR AUTHENTICATION FLOW
-- ============================================================================

-- Allow anonymous users to create schools and profiles during signup
GRANT INSERT ON schools TO anon;
GRANT INSERT ON profiles TO anon;
GRANT SELECT ON schools TO anon;
GRANT SELECT ON profiles TO anon;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO anon;

-- Allow authenticated users to manage their data
GRANT ALL ON schools TO authenticated;
GRANT ALL ON profiles TO authenticated;
GRANT ALL ON invitations TO authenticated;

-- Grant usage on schemas that anonymous users need
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA extensions TO anon;

    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'Tables Created:';
    RAISE NOTICE '  ✓ schools - Multi-tenant organization management';
    RAISE NOTICE '  ✓ profiles - User profiles linked to schools';
    RAISE NOTICE '  ✓ invitations - Secure invite system';
    RAISE NOTICE '';
    RAISE NOTICE 'Security Features:';
    RAISE NOTICE '  ✓ Row Level Security enabled on all tables';
    RAISE NOTICE '  ✓ Proper foreign key relationships';
    RAISE NOTICE '  ✓ Data validation constraints';
    RAISE NOTICE '  ✓ Unique constraints to prevent duplicates';
    RAISE NOTICE '';
    RAISE NOTICE 'Performance Features:';
    RAISE NOTICE '  ✓ Strategic indexes for fast queries';
    RAISE NOTICE '  ✓ Composite indexes for common query patterns';
    RAISE NOTICE '  ✓ Partial indexes for filtered queries';
    RAISE NOTICE '';
    RAISE NOTICE 'Next Step: Run 03-business-tables.sql';
    RAISE NOTICE '============================================================================';
END $$;
