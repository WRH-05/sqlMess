-- Enable Email Confirmation for Kennedy Management System
-- This script updates the authentication trigger to work WITH email confirmation
-- Execute this in Supabase SQL Editor after running the main database structure files

-- ============================================================================
-- UPDATED AUTHENTICATION TRIGGER WITH EMAIL CONFIRMATION SUPPORT
-- ============================================================================

-- Drop and recreate the user registration trigger to handle email confirmation properly
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user() CASCADE;

-- Create the corrected user creation function with email confirmation support
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    invitation_record RECORD;
    user_school_id UUID;
    user_role TEXT;
    user_full_name TEXT;
    user_phone TEXT;
BEGIN
    -- Process both INSERT and UPDATE events (UPDATE happens when email is confirmed)
    IF NEW.raw_user_meta_data IS NOT NULL THEN
        
        -- Check if this is an owner signup during school creation
        IF NEW.raw_user_meta_data->>'is_owner_signup' = 'true' THEN
            user_school_id := (NEW.raw_user_meta_data->>'school_id')::UUID;
            user_role := 'owner';
            user_full_name := COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1));
            user_phone := NEW.raw_user_meta_data->>'phone';

            -- For owner signup: Create profile immediately regardless of email confirmation
            -- (Owners need immediate access to set up their school)
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
            -- For invitation-based signup: Only create profile AFTER email confirmation
            IF NEW.email_confirmed_at IS NOT NULL THEN
                -- Email is confirmed, create the profile
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

                    RAISE NOTICE 'Created invited user profile for user % in school % after email confirmation', NEW.id, invitation_record.school_id;
                ELSE
                    RAISE WARNING 'No valid invitation found for confirmed user %', NEW.email;
                END IF;
            ELSE
                RAISE NOTICE 'User % signed up but email not yet confirmed, waiting for confirmation', NEW.email;
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

-- Create the trigger for both INSERT and UPDATE (email confirmation triggers UPDATE)
CREATE TRIGGER on_auth_user_created
    AFTER INSERT OR UPDATE ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'EMAIL CONFIRMATION ENABLED SUCCESSFULLY!';
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'Authentication Flow Updated:';
    RAISE NOTICE '  ✓ School owners: Get immediate profile creation (no email confirmation required)';
    RAISE NOTICE '  ✓ Invited users: Must confirm email before profile is created';
    RAISE NOTICE '  ✓ Trigger handles both INSERT (signup) and UPDATE (email confirmation)';
    RAISE NOTICE '';
    RAISE NOTICE 'Next Steps:';
    RAISE NOTICE '  1. Update your frontend code to handle email confirmation flow';
    RAISE NOTICE '  2. Enable email confirmation in Supabase Auth settings';
    RAISE NOTICE '  3. Test the complete flow with email confirmation';
    RAISE NOTICE '============================================================================';
END $$;
