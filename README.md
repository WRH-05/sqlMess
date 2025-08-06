# Kennedy Management System - Database Setup Guide

## Overview
This database setup has been completely reorganized from 14 separate patch files into 6 well-structured files following PostgreSQL and Supabase best practices. The new structure eliminates performance issues, infinite recursion problems, and authentication failures while maintaining all original functionality.

## File Structure and Execution Order

### 1. `01-extensions-and-types.sql`
**Purpose**: Database extensions and custom types
- PostgreSQL extensions (uuid-ossp, pg_stat_statements, pg_trgm)
- Custom ENUM types (user_role, payment_status, payout_status, request_status)
- **Run this FIRST**

### 2. `02-authentication-tables.sql`
**Purpose**: Authentication and multi-tenant tables
- `schools` table (tenant isolation)
- `profiles` table (user management)
- `invitations` table (invite system)
- Performance indexes
- Row Level Security enabled
- **Run this SECOND**

### 3. `03-business-tables.sql`
**Purpose**: Core business logic tables
- Student management (`students`)
- Teacher management (`teachers`)
- Course management (`course_templates`, `course_instances`)
- Financial tracking (`student_payments`, `teacher_payouts`, `revenue`)
- Operations (`attendance`, `archive_requests`)
- Comprehensive indexes and constraints
- **Run this THIRD**

### 4. `04-authentication-functions.sql`
**Purpose**: Authentication logic and helper functions
- User registration trigger (`handle_new_user`)
- Authentication helper functions
- Invitation management functions
- Security validation functions
- **Run this FOURTH**

### 5. `05-row-level-security.sql`
**Purpose**: Secure, performant RLS policies
- Non-recursive policies (eliminates infinite loops)
- Multi-tenant isolation by school_id
- Role-based access control
- Optimized for performance
- **Run this FIFTH**

### 6. `06-utility-functions.sql`
**Purpose**: Business logic and utility functions
- Course enrollment management
- Financial calculations
- Attendance tracking
- Archive management
- Maintenance functions
- Automatic timestamp triggers
- **Run this SIXTH**

## Key Improvements Over Original Files

### 1. **Performance Optimizations**
- **Strategic Indexing**: 25+ performance indexes including composite, GIN, and partial indexes
- **Non-recursive RLS**: Eliminated infinite recursion that caused authentication failures
- **Function Optimization**: Used `STABLE` functions where appropriate
- **Query Optimization**: Optimized for common query patterns

### 2. **Security Enhancements**
- **Proper Multi-tenancy**: Complete isolation between schools
- **Role-based Access**: Financial data restricted to owners/managers
- **Input Validation**: Comprehensive constraints and validation
- **Audit Trails**: Full tracking of payments, approvals, and changes

### 3. **Code Organization**
- **Separation of Concerns**: Clear separation between auth, business logic, and utilities
- **Consistent Naming**: Standardized naming conventions
- **Documentation**: Extensive comments and success messages
- **Error Handling**: Proper exception handling throughout

### 4. **Functionality Preservation**
- **All Original Features**: Every feature from the 14-file setup is preserved
- **Enhanced Reliability**: More robust error handling and validation
- **Better UX**: Faster queries and fewer authentication issues

## Installation Instructions

### Step 1: Clean Slate (Recommended)
If you have issues with existing data, consider starting fresh:
```sql
-- Optional: Clean existing data (DESTRUCTIVE - use with caution)
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO public;
```

### Step 2: Execute Files in Order
In Supabase SQL Editor, run each file in the specified order:

1. **01-extensions-and-types.sql** → Set up extensions and types
2. **02-authentication-tables.sql** → Create auth tables
3. **03-business-tables.sql** → Create business tables  
4. **04-authentication-functions.sql** → Create auth functions
5. **05-row-level-security.sql** → Apply RLS policies
6. **06-utility-functions.sql** → Add utility functions

### Step 3: Verify Installation
After running all files, verify the setup:
```sql
-- Check table count
SELECT COUNT(*) as table_count FROM information_schema.tables WHERE table_schema = 'public';

-- Check RLS policies
SELECT schemaname, tablename, COUNT(*) as policy_count 
FROM pg_policies 
WHERE schemaname = 'public' 
GROUP BY schemaname, tablename;

-- Test user context function
SELECT * FROM get_user_context();
```

## Testing the Setup

### Test School Creation
Try creating a school and owner account through your frontend. The process should now work without RLS policy errors.

### Test Authentication Flow
1. Create school + owner account
2. Login with owner account
3. Verify dashboard loads correctly
4. Create invitations for other users

### Test Multi-tenancy
Create multiple schools and verify data isolation between them.

## Performance Features

### Database Indexes (25+ indexes)
- **Authentication**: Fast user/school lookups
- **Business Logic**: Optimized for common queries
- **Financial**: Fast payment and revenue queries
- **Text Search**: Full-text search on names
- **Array Operations**: Optimized for student enrollment arrays

### Query Optimization
- **Composite Indexes**: Multi-column indexes for complex queries
- **Partial Indexes**: Filtered indexes for common conditions
- **GIN Indexes**: Optimized for JSONB and array operations

### Memory Efficiency
- **STABLE Functions**: Cached during query execution
- **Proper Data Types**: Efficient storage types
- **Normalized Design**: Reduced data duplication

## Security Features

### Row Level Security
- **Complete Tenant Isolation**: Users only see their school's data
- **Role-based Access**: Financial data restricted by role
- **Non-recursive Policies**: No circular dependencies

### Data Validation
- **Input Constraints**: Email formats, phone numbers, dates
- **Business Logic**: Enrollment limits, payment validation
- **Referential Integrity**: Proper foreign key relationships

### Audit Trail
- **Payment Tracking**: Full payment approval workflow
- **Archive Management**: Controlled soft delete process
- **User Actions**: Track who approved/created what

## Troubleshooting

### Common Issues and Solutions

1. **Permission Errors**
   - Ensure you're running as `postgres` user or `service_role`
   - Check that RLS policies are applied correctly

2. **Function Not Found**
   - Verify all files were run in order
   - Check for any error messages during execution

3. **Authentication Issues**
   - Verify `handle_new_user` trigger exists
   - Check that profiles are being created correctly

4. **Performance Issues**
   - Run `ANALYZE` on all tables after data import
   - Monitor query performance with `pg_stat_statements`

### Getting Help
- Check the success messages after each file execution
- Use the validation queries provided
- Verify table structures match expectations

## Migration from Old Setup

If you're migrating from the 14-file setup:

1. **Backup Your Data** (essential)
2. **Note Your Current Issues** (for comparison)
3. **Run the New Setup** (preferably on a fresh database)
4. **Test All Functionality** 
5. **Migrate Data** (if needed)

The new setup should resolve:
- ✅ Authentication infinite loops
- ✅ RLS policy recursion errors  
- ✅ School creation failures
- ✅ Profile creation issues
- ✅ Performance problems

## Conclusion

This reorganized database setup provides:
- **Better Performance**: Optimized indexes and non-recursive policies
- **Enhanced Security**: Proper multi-tenancy and role-based access
- **Improved Maintainability**: Clear structure and documentation
- **Full Functionality**: All original features preserved and enhanced

The new structure follows PostgreSQL and Supabase best practices while eliminating the issues that required 14 patch files in the original setup.
