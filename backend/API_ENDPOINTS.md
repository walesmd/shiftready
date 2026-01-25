# ShiftReady API Endpoints

Base URL: `http://localhost:3001/api/v1`

All endpoints require authentication via JWT token in the `Authorization` header (except auth endpoints).

## Authentication

### Register
```
POST /api/v1/auth/register
Body: { email, password, password_confirmation, role }
```

### Login
```
POST /api/v1/auth/login
Body: { email, password }
Returns: { token, user }
```

### Logout
```
DELETE /api/v1/auth/logout
```

### Current User
```
GET /api/v1/auth/me
Returns: Current user profile
```

### Update Current User
```
PATCH /api/v1/auth/me
Body: { user: { email } }
Returns: Updated user profile
```

### Change Password
```
PATCH /api/v1/auth/me
Body: {
  user: {
    current_password,
    password,
    password_confirmation
  }
}
Returns: Success message
Note: Regenerates JTI to invalidate old tokens
```

---

## Worker Profiles

### Create Worker Profile
```
POST /api/v1/workers
Body: {
  worker_profile: {
    first_name, last_name, phone,
    address_line_1, address_line_2, city, state, zip_code,
    over_18_confirmed, terms_accepted_at, sms_consent_given_at,
    preferred_payment_method, ssn_encrypted, bank_account_last_4
  }
}
Requires: Worker role
```

### Get My Worker Profile
```
GET /api/v1/workers/me
Requires: Worker role
```

### Update My Worker Profile
```
PATCH /api/v1/workers/me
Body: { worker_profile: {...} }
Requires: Worker role
```

---

## Employer Profiles

### Create Employer Profile
```
POST /api/v1/employers
Body: {
  employer_profile: {
    company_id, first_name, last_name, title, phone,
    terms_accepted_at, msa_accepted_at,
    can_post_shifts, can_approve_timesheets, is_billing_contact
  }
}
Requires: Employer role
```

### Get My Employer Profile
```
GET /api/v1/employers/me
Requires: Employer role
```

### Update My Employer Profile
```
PATCH /api/v1/employers/me
Body: { employer_profile: {...} }
Requires: Employer role
```

---

## Companies

### List Companies
```
GET /api/v1/companies
Query params: None
Returns: List of companies (filtered by user role)
```

### Get Company
```
GET /api/v1/companies/:id
```

### Create Company
```
POST /api/v1/companies
Body: {
  company: {
    name, industry,
    billing_email, billing_phone,
    billing_address_line_1, billing_city, billing_state, billing_zip_code,
    tax_id, payment_terms
  }
}
Requires: Employer or Admin role
```

### Update Company
```
PATCH /api/v1/companies/:id
Body: { company: {...} }
Requires: Company member or Admin
```

---

## Work Locations

### List Work Locations
```
GET /api/v1/work_locations
Query params: company_id (optional)
Returns: List of work locations (filtered by user role)
```

### Get Work Location
```
GET /api/v1/work_locations/:id
```

### Create Work Location
```
POST /api/v1/work_locations
Body: {
  work_location: {
    name, address_line_1, address_line_2, city, state, zip_code,
    latitude, longitude,
    arrival_instructions, parking_notes
  }
}
Requires: Employer role
```

### Update Work Location
```
PATCH /api/v1/work_locations/:id
Body: { work_location: {...} }
Requires: Company member
```

### Delete Work Location
```
DELETE /api/v1/work_locations/:id
Requires: Company member
Note: Cannot delete if location has shifts
```

---

## Shifts

### List Shifts
```
GET /api/v1/shifts
Query params:
  - status: draft, posted, recruiting, filled, in_progress, completed, cancelled
  - job_type: warehouse, moving, event_setup, etc.
  - company_id: filter by company
  - start_date: filter by start date (ISO 8601)
  - end_date: filter by end date (ISO 8601)

Returns: List of shifts (filtered by user role)
- Workers see: posted, recruiting shifts only
- Employers see: their company's shifts only
```

### Get Shift
```
GET /api/v1/shifts/:id
```

### Create Shift
```
POST /api/v1/shifts
Body: {
  shift: {
    work_location_id, title, description, job_type,
    start_datetime, end_datetime,
    pay_rate_cents, slots_total, min_workers_needed,
    skills_required, physical_requirements
  }
}
Requires: Employer role with can_post_shifts permission
```

### Update Shift
```
PATCH /api/v1/shifts/:id
Body: { shift: {...} }
Requires: Shift owner (company member)
```

### Delete Shift
```
DELETE /api/v1/shifts/:id
Requires: Shift owner
Note: Can only delete draft shifts or shifts with no accepted assignments
```

### Start Recruiting
```
POST /api/v1/shifts/:id/start_recruiting
Requires: Shift owner
Transitions: posted → recruiting
```

### Cancel Shift
```
POST /api/v1/shifts/:id/cancel
Body: { reason: "Cancellation reason" }
Requires: Shift owner
```

---

## Shift Assignments

### List Shift Assignments
```
GET /api/v1/shift_assignments
Query params:
  - status: offered, accepted, declined, no_response, confirmed, checked_in, no_show, completed, cancelled
  - shift_id: filter by shift

Returns: List of assignments (filtered by user role)
- Workers see: their own assignments only
- Employers see: their company's shift assignments
```

### Get Shift Assignment
```
GET /api/v1/shift_assignments/:id
```

### Accept Assignment
```
POST /api/v1/shift_assignments/:id/accept
Body: { method: "app" } (optional, defaults to "app")
Requires: Worker role, assignment owner
```

### Decline Assignment
```
POST /api/v1/shift_assignments/:id/decline
Body: {
  reason: "Reason for declining",
  method: "app" (optional)
}
Requires: Worker role, assignment owner
```

### Check In
```
POST /api/v1/shift_assignments/:id/check_in
Requires: Worker role, assignment owner
Note: Shift must have started
```

### Check Out
```
POST /api/v1/shift_assignments/:id/check_out
Requires: Worker role, assignment owner
Note: Must have checked in first
```

### Cancel Assignment
```
POST /api/v1/shift_assignments/:id/cancel
Body: { reason: "Cancellation reason" }
Requires: Worker or Employer role
```

### Approve Timesheet
```
POST /api/v1/shift_assignments/:id/approve_timesheet
Requires: Employer role with can_approve_timesheets permission
Note: Worker must have checked out first
```

---

## Response Formats

### Success Response
```json
{
  "id": 1,
  "attribute": "value",
  ...
}
```

### Error Response
```json
{
  "error": "Error message"
}
```

### Validation Errors
```json
{
  "errors": [
    "Field can't be blank",
    "Field is invalid"
  ]
}
```

---

## Authorization Rules

### Worker Role
- Can create/update worker profile
- Can view posted/recruiting shifts
- Can accept/decline their own assignments
- Can check in/out of their assignments

### Employer Role
- Can create/update employer profile
- Can create/update company (their own)
- Can create/update/delete work locations (their company's)
- Can create/update/delete shifts (their company's)
- Can approve timesheets (if has permission)
- Can view their company's shift assignments

### Admin Role
- Full access to all resources (future implementation)

---

## Notes

1. All datetime fields use ISO 8601 format
2. Money amounts are in cents (e.g., pay_rate_cents: 1500 = $15.00/hr)
3. Coordinates use decimal degrees (latitude/longitude)
4. Phone numbers should be in E.164 format (e.g., +14155551234)
5. JWT tokens expire based on Devise configuration
6. Rate limiting not yet implemented (future enhancement)
