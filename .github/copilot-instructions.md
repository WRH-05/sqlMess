# Kennedy Management System Database Schema Instructions

## Project Context

This repository contains the database schema files for Kennedy Management System, a multi-tenant school management platform. The system uses:
- Frontend: Next.js/React application
- Backend: Supabase (PostgreSQL + Authentication + Real-time)
- Database: PostgreSQL with Row Level Security for multi-tenant isolation

This repository is an isolated workspace for developing and testing SQL migrations before deploying to the live Supabase database.

## Repository Structure

The database schema consists of 6 sequential files that must be executed in exact order:

1. `01-extensions-and-types.sql` - Database extensions and custom enums
2. `02-authentication-tables.sql` - Schools, profiles, invitations tables  
3. `03-business-tables.sql` - Students, teachers, courses, payments
4. `04-authentication-functions.sql` - Authentication triggers and helper functions
5. `05-row-level-security.sql` - RLS policies for multi-tenant security
6. `06-utility-functions.sql` - Business logic functions and triggers

## Development Workflow

After every significant change:
1. Reset the entire Supabase database (DROP SCHEMA public CASCADE)
2. Re-run all files in sequence (01 through 06)
3. Test changes in the frontend application

This ensures a clean, reproducible database state.

## Code Modification Guidelines

### When Making Changes

For modifications to existing functionality:
- Edit the appropriate existing file (01-06) based on the change type
- Maintain the sequential dependency chain
- Update related files if needed (example: if adding a table, update RLS policies)

For new features:
- Create a new file numbered 07 or higher (example: `07-attendance-improvements.sql`)
- Include purpose and dependencies in the file header
- This numbering indicates the execution order after core files

### Architecture Requirements

Multi-Tenant Security Model:
- Each school is a separate tenant with isolated data
- RLS policies enforce school_id filtering on all business tables
- Authentication flows handle both owner signup (school creation) and invitation-based signup

Key Helper Functions:
- `get_user_school_id()` - Retrieves current user's school ID
- `user_has_role()` and `user_has_any_role()` - Role-based access control
- `handle_new_user()` - Processes user registration (owner vs invited)

Critical Tables:
- `schools` - Tenant organizations (must allow anonymous INSERT for signup)
- `profiles` - User profiles linked to schools (extends auth.users)
- `invitations` - Secure invite system for adding users to schools

## Security Constraints

Always maintain:
- Multi-tenant isolation - users only see data from their school
- RLS security model compliance
- Backward compatibility with existing schema
- Proper permissions for anonymous users during signup flow

Never:
- Modify files out of order
- Break multi-tenant isolation
- Remove existing functionality without explicit permission
- Create circular dependencies between functions and policies

## Performance Requirements

Implement these patterns:
- Cache auth function calls in RLS policies: use `(select auth.uid())` not `auth.uid()`
- Use EXISTS clauses instead of JOINs in RLS policies when possible
- Add strategic indexes on foreign keys and frequently queried columns
- Secure functions with `SET search_path = ''` for SECURITY DEFINER functions

## Troubleshooting Priority

When debugging issues:
1. Check RLS policies first - most issues are permission-related
2. Verify helper functions exist and are accessible to the right roles
3. Ensure proper grants for anonymous users (signup flow) and authenticated users
4. Test the complete user journey from signup to data access

## Testing Requirements

Always verify:
- Authentication flows (signup, login, school creation)
- Multi-tenant data isolation
- Performance implications of RLS policy changes
- Complete user journey from registration to data access
