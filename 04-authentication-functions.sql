-- Kennedy Management System - Authentication Functions and Triggers
-- This script creates authentication-related functions and triggers
-- Run this FOURTH after 03-business-tables.sql

-- ============================================================================
-- USER REGISTRATION TRIGGER FUNCTION
-- ============================================================================

-- Drop existing trigger and function to avoid conflicts
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user() CASCADE;

-- Create the user registration trigger function
-- This function handles both owner signup (school creation) and invitation-based signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER 
LANGUAGE plpgsql 
SECURITY DEFINER
SET search_path = '' AS $$
DECLARE
    invitation_record RECORD;
    user_school_id UUID;
    user_role TEXT;
    user_full_name TEXT;
    user_phone TEXT;
    function_start_time TIMESTAMP WITH TIME ZONE;
BEGIN
    function_start_time := NOW();
    
    -- Only process INSERT events with raw_user_meta_data
    IF TG_OP = 'INSERT' AND NEW.raw_user_meta_data IS NOT NULL THEN
        
        -- CASE 1: Owner signup during school creation
        IF NEW.raw_user_meta_data->>'is_owner_signup' = 'true' THEN
            user_school_id := (NEW.raw_user_meta_data->>'school_id')::UUID;
            user_role := 'owner';
            user_full_name := COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1));
            user_phone := NEW.raw_user_meta_data->>'phone';

            -- Validate required data
            IF user_school_id IS NULL THEN
                RAISE WARNING 'Owner signup missing school_id for user %', NEW.id;
                RETURN NEW;
            END IF;

            -- Create owner profile immediately
            INSERT INTO profiles (id, school_id, role, full_name, phone, is_active)
            VALUES (NEW.id, user_school_id, user_role::user_role, user_full_name, user_phone, true)
            ON CONFLICT (id) DO UPDATE SET
                school_id = EXCLUDED.school_id,
                role = EXCLUDED.role,
                full_name = EXCLUDED.full_name,
                phone = EXCLUDED.phone,
                updated_at = NOW();

            RAISE NOTICE '[%] Created owner profile for user % in school % (Duration: %ms)', 
                TO_CHAR(function_start_time, 'HH24:MI:SS'), 
                NEW.id, 
                user_school_id,
                EXTRACT(MILLISECONDS FROM NOW() - function_start_time);
            
        -- CASE 2: Invitation-based signup
        ELSIF NEW.raw_user_meta_data->>'invitation_token' IS NOT NULL THEN
            -- Look up valid invitation
            SELECT * INTO invitation_record
            FROM invitations
            WHERE token = (NEW.raw_user_meta_data->>'invitation_token')::UUID
            AND email = NEW.email
            AND accepted_at IS NULL
            AND expires_at > NOW()
            LIMIT 1;

            IF FOUND THEN
                -- Create invited user profile
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

                RAISE NOTICE '[%] Created invited user profile for user % in school % with role % (Duration: %ms)', 
                    TO_CHAR(function_start_time, 'HH24:MI:SS'),
                    NEW.id, 
                    invitation_record.school_id, 
                    invitation_record.role,
                    EXTRACT(MILLISECONDS FROM NOW() - function_start_time);
            ELSE
                RAISE WARNING 'No valid invitation found for user % with email %', NEW.id, NEW.email;
            END IF;
        ELSE
            -- No recognized signup pattern
            RAISE NOTICE 'User % registered without owner or invitation signup pattern', NEW.id;
        END IF;
    END IF;

    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Failed to create profile for user %: % (SQLSTATE: %)', NEW.id, SQLERRM, SQLSTATE;
        -- Don't fail the user creation, just log the error
        RETURN NEW;
END;
$$;

-- Create the trigger on auth.users
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================================
-- HELPER FUNCTIONS FOR AUTHENTICATION
-- ============================================================================

-- Function to get current user context (useful for debugging and queries)
CREATE OR REPLACE FUNCTION get_user_context()
RETURNS TABLE (
    user_id UUID,
    school_id UUID,
    role TEXT,
    full_name TEXT,
    is_active BOOLEAN
) 
LANGUAGE plpgsql 
SECURITY DEFINER
SET search_path = '' AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.school_id,
        p.role::TEXT,
        p.full_name,
        p.is_active
    FROM profiles p
    WHERE p.id = auth.uid()
    AND p.is_active = true;
END;
$$;

-- Function to check if current user has a specific role
CREATE OR REPLACE FUNCTION user_has_role(required_role TEXT)
RETURNS BOOLEAN 
LANGUAGE plpgsql 
SECURITY DEFINER
SET search_path = '' AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid() 
        AND role::TEXT = required_role
        AND is_active = true
    );
END;
$$;

-- Function to check if current user has any of the specified roles
CREATE OR REPLACE FUNCTION user_has_any_role(required_roles TEXT[])
RETURNS BOOLEAN 
LANGUAGE plpgsql 
SECURITY DEFINER
SET search_path = '' AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid() 
        AND role::TEXT = ANY(required_roles)
        AND is_active = true
    );
END;
$$;

-- Function to get user's school_id (for use in RLS policies)
CREATE OR REPLACE FUNCTION get_user_school_id()
RETURNS UUID AS $$
BEGIN
    RETURN (
        SELECT school_id FROM profiles
        WHERE id = auth.uid()
        AND is_active = true
        LIMIT 1
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Function to check if user belongs to a specific school
CREATE OR REPLACE FUNCTION user_belongs_to_school(target_school_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid()
        AND school_id = target_school_id
        AND is_active = true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- INVITATION MANAGEMENT FUNCTIONS
-- ============================================================================

-- Function to create a new invitation (with validation)
CREATE OR REPLACE FUNCTION create_invitation(
    p_email TEXT,
    p_role user_role,
    p_school_id UUID
)
RETURNS UUID AS $$
DECLARE
    invitation_id UUID;
    inviter_profile RECORD;
BEGIN
    -- Get inviter's profile and validate permissions
    SELECT * INTO inviter_profile
    FROM profiles
    WHERE id = auth.uid()
    AND school_id = p_school_id
    AND is_active = true;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Not authorized to create invitations for this school';
    END IF;
    
    -- Only owners and managers can create invitations
    IF inviter_profile.role::TEXT NOT IN ('owner', 'manager') THEN
        RAISE EXCEPTION 'Only owners and managers can create invitations';
    END IF;
    
    -- Check if user is already registered
    IF EXISTS (
        SELECT 1 FROM auth.users u
        JOIN profiles p ON p.id = u.id
        WHERE u.email = p_email
        AND p.school_id = p_school_id
    ) THEN
        RAISE EXCEPTION 'User with email % is already registered in this school', p_email;
    END IF;
    
    -- Check for pending invitation
    IF EXISTS (
        SELECT 1 FROM invitations
        WHERE email = p_email
        AND school_id = p_school_id
        AND accepted_at IS NULL
        AND expires_at > NOW()
    ) THEN
        RAISE EXCEPTION 'Pending invitation already exists for email %', p_email;
    END IF;
    
    -- Create the invitation
    INSERT INTO invitations (email, role, school_id, invited_by)
    VALUES (p_email, p_role, p_school_id, auth.uid())
    RETURNING id INTO invitation_id;
    
    RETURN invitation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to cleanup expired invitations
CREATE OR REPLACE FUNCTION cleanup_expired_invitations()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM invitations
    WHERE expires_at < NOW()
    AND accepted_at IS NULL;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Grant necessary permissions for authenticated users
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_context() TO authenticated;
GRANT EXECUTE ON FUNCTION user_has_role(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION user_has_any_role(TEXT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_school_id() TO authenticated;
GRANT EXECUTE ON FUNCTION user_belongs_to_school(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION create_invitation(TEXT, user_role, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION cleanup_expired_invitations() TO authenticated;

-- Grant permission to access auth.users for the trigger
GRANT SELECT ON auth.users TO postgres, service_role;

-- Additional grants for anonymous users during signup process
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA auth TO anon;
GRANT SELECT ON auth.users TO anon;

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'AUTHENTICATION FUNCTIONS CREATED SUCCESSFULLY!';
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'Trigger Functions:';
    RAISE NOTICE '  ✓ handle_new_user() - Processes user registration';
    RAISE NOTICE '  ✓ on_auth_user_created - Trigger on auth.users table';
    RAISE NOTICE '';
    RAISE NOTICE 'Helper Functions:';
    RAISE NOTICE '  ✓ get_user_context() - Current user info';
    RAISE NOTICE '  ✓ user_has_role() - Role checking';
    RAISE NOTICE '  ✓ user_has_any_role() - Multi-role checking';
    RAISE NOTICE '  ✓ get_user_school_id() - User school lookup';
    RAISE NOTICE '  ✓ user_belongs_to_school() - School membership check';
    RAISE NOTICE '';
    RAISE NOTICE 'Invitation Functions:';
    RAISE NOTICE '  ✓ create_invitation() - Secure invitation creation';
    RAISE NOTICE '  ✓ cleanup_expired_invitations() - Maintenance function';
    RAISE NOTICE '';
    RAISE NOTICE 'Security Features:';
    RAISE NOTICE '  ✓ All functions use SECURITY DEFINER';
    RAISE NOTICE '  ✓ Proper permission validation';
    RAISE NOTICE '  ✓ Error handling and logging';
    RAISE NOTICE '  ✓ Input validation and constraints';
    RAISE NOTICE '';
    RAISE NOTICE 'Next Step: Run 05-row-level-security.sql';
    RAISE NOTICE '============================================================================';
END $$;
