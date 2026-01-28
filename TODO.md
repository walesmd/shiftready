# ShiftReady TODO

## Constants Consolidation

### Completed ✅
- [x] Pay rate constraints (FEDERAL_MINIMUM_WAGE, MAXIMUM_HOURLY_WAGE, PAY_RATE_STEP)
- [x] Service fee rate (SERVICE_FEE_RATE)

### Pending - Magic Numbers to Extract 📋

The following magic numbers are scattered throughout the codebase and should be consolidated into shared constants (accessible from both frontend and backend):

#### Worker/Shift Capacity Constraints
- **MAX_WORKERS_PER_SHIFT**: `50` workers
  - Location: `frontend/app/dashboard/employer/shifts/page.tsx:532`
  - Note: Currently only enforced on frontend, no backend validation

#### Recruiting & Offer Timing
- **OFFER_TIMEOUT_MINUTES**: `15` minutes
  - Locations:
    - `backend/app/jobs/check_offer_timeout_job.rb:6`
    - `backend/app/services/shift_offer_service.rb:115`
  - Purpose: How long workers have to respond to shift offers

- **RESUME_RECRUITING_WINDOW_HOURS**: `24` hours
  - Locations:
    - `backend/app/jobs/resume_recruiting_job.rb:48-50`
    - `backend/app/models/shift.rb:157` (24.hours.from_now)
  - Purpose: Minimum time before shift start to allow recruiting

- **RECRUITING_DISCOVERY_WINDOW_DAYS**: `7` days
  - Location: `backend/app/jobs/shift_recruiting_discovery_job.rb:29`
  - Purpose: How far ahead to look for shifts needing workers
  - Note: Runs every 5 minutes via Solid Queue

#### Worker Scoring/Algorithm
- **RESPONSE_TIME_THRESHOLD_MINUTES**: `30` minutes
  - Location: `backend/app/services/recruiting_algorithm_service.rb:177`
  - Purpose: Threshold for "fast" vs "slow" response in worker quality score

- **QUALITY_SCORE_WEIGHTS**:
  - Attendance: `40%`
  - Rating: `40%`
  - Response Time: `20%`
  - Location: `backend/app/models/worker_profile.rb:62`
  - Note: Used in worker ranking algorithm

### Implementation Strategy

When implementing, consider:

1. **Single Source of Truth**: Backend should be authoritative
2. **Frontend Access**: Create API endpoint (`GET /api/v1/config`) to fetch constants
3. **TypeScript Types**: Generate TypeScript interfaces from backend constants
4. **Runtime vs Build Time**: Some constants may need to be configurable via ENV variables
5. **Fallbacks**: Frontend should have hardcoded fallbacks in case API is unavailable
6. **Documentation**: Update CLAUDE.md with the new constants architecture

### Benefits

- Easier to adjust business rules without hunting through code
- Type safety across frontend/backend boundary
- Single place to change recruiting timing rules
- Better developer experience
- Consistency between client/server validation

---

## Other TODOs

<!-- Add additional TODO items here -->
