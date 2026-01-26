# ShiftReady Documentation

This directory contains implementation guides and technical documentation for ShiftReady features.

## Onboarding System

The onboarding system guides new users through required setup steps before they can fully use the platform.

### Current Status

- ✅ **Employer Onboarding**: Fully implemented
- 📋 **Worker Onboarding**: Planned (documentation ready)

### Documentation Files

- **[WORKER_ONBOARDING.md](./WORKER_ONBOARDING.md)** - Comprehensive implementation guide for worker onboarding
  - Complete technical specification
  - Backend and frontend patterns
  - Code examples
  - Testing checklist
  - Step-by-step implementation order

- **[WORKER_ONBOARDING_CHECKLIST.md](./WORKER_ONBOARDING_CHECKLIST.md)** - Task checklist for implementing worker onboarding
  - Can be copied into GitHub issue
  - Checkboxes for tracking progress
  - Estimated effort and timeline
  - Dependencies and questions to resolve

### Onboarding Pattern

Both employer and worker onboarding follow the same reusable pattern:

**Backend:**
```ruby
# Model defines what tasks need to be completed
def onboarding_complete?
  task_1_complete? && task_2_complete?
end

# Model provides status breakdown
def onboarding_status
  { task_1_complete: bool, task_2_complete: bool, is_complete: bool }
end

# Controller exposes status via API
GET /api/v1/{role}/me/onboarding_status
```

**Frontend:**
```typescript
// Context provides global state
const { onboardingStatus, refreshOnboardingStatus } = useOnboarding();

// Card displays progress
<OnboardingCard /> // Shows tasks, completion status, action buttons

// Components refresh after completing tasks
await saveData();
await refreshOnboardingStatus(); // Card updates immediately
```

### Key Principles

1. **Reactive Updates** - Card updates immediately when tasks are completed (no page refresh)
2. **Backend Enforcement** - API endpoints validate onboarding completion
3. **Reusable Pattern** - Same code structure works for all user types
4. **Single Source of Truth** - Onboarding status managed in shared context
5. **Clear User Guidance** - Card shows what needs to be done and provides action buttons

### Reference Implementation

For a working example, see the employer onboarding implementation:

**Backend:**
- `app/models/company.rb` - Onboarding status methods
- `app/models/employer_profile.rb` - Profile-level onboarding
- `app/controllers/api/v1/employer_profiles_controller.rb#onboarding_status`

**Frontend:**
- `frontend/contexts/onboarding-context.tsx` - Shared context
- `frontend/components/employer-dashboard/onboarding-card.tsx` - Card component
- `frontend/app/dashboard/employer/layout.tsx` - Provider integration
- `frontend/components/employer-settings/company-billing-section.tsx` - Refresh trigger example
- `frontend/components/employer-settings/work-locations-section.tsx` - Refresh trigger example

### When to Implement Worker Onboarding

Worker onboarding should be implemented before launching the worker-facing features of the platform. Specifically:

- Before workers can browse shifts
- Before workers can accept shift assignments
- Before workers can receive payments

The implementation is estimated to take 6-10 days depending on Stripe integration complexity.

### Questions?

If you have questions about the onboarding system or need clarification on the implementation approach, refer to:

1. The comprehensive guide: `WORKER_ONBOARDING.md`
2. The project instructions: `../CLAUDE.md` (User Onboarding System section)
3. The working employer implementation (files listed above)

## Future Documentation

This directory will grow to include documentation for other major features:

- SMS Messaging System
- Shift Recruiting Algorithm
- Payment Processing & Stripe Integration
- Background Check Integration
- Worker Matching & Recommendations
- Timesheet Approval Workflow
- Analytics & Reporting

---

**Last Updated**: 2026-01-26
