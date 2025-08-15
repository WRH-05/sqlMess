-- Kennedy Management System - Extensions and Custom Types
-- This script sets up database extensions and custom data types
-- Run this FIRST in Supabase Database > SQL Editor

-- ============================================================================
-- DATABASE EXTENSIONS
-- ============================================================================

-- Create extensions in the proper schema for security
CREATE SCHEMA IF NOT EXISTS extensions;

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;

-- Enable additional extensions that might be useful
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "pg_trgm" WITH SCHEMA extensions; -- For text search performance

-- ============================================================================
-- CUSTOM ENUM TYPES
-- ============================================================================

-- User role enum for role-based access control
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('owner', 'manager', 'receptionist');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Payment status tracking
DO $$ BEGIN
    CREATE TYPE payment_status AS ENUM ('pending', 'paid', 'approved', 'declined');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Teacher payout status tracking
DO $$ BEGIN
    CREATE TYPE payout_status AS ENUM ('pending', 'approved', 'paid', 'declined');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- General request status (for archives, etc.)
DO $$ BEGIN
    CREATE TYPE request_status AS ENUM ('pending', 'approved', 'declined');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'EXTENSIONS AND TYPES SETUP COMPLETE!';
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'Extensions Enabled:';
    RAISE NOTICE '  ✓ uuid-ossp (UUID generation)';
    RAISE NOTICE '  ✓ pg_stat_statements (Query performance monitoring)';
    RAISE NOTICE '  ✓ pg_trgm (Text search performance)';
    RAISE NOTICE '';
    RAISE NOTICE 'Custom Types Created:';
    RAISE NOTICE '  ✓ user_role: owner, manager, receptionist';
    RAISE NOTICE '  ✓ payment_status: pending, paid, approved, declined';
    RAISE NOTICE '  ✓ payout_status: pending, approved, paid, declined';
    RAISE NOTICE '  ✓ request_status: pending, approved, declined';
    RAISE NOTICE '';
    RAISE NOTICE 'Next Step: Run 02-authentication-tables.sql';
    RAISE NOTICE '============================================================================';
END $$;
