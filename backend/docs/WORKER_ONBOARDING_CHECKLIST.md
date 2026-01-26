# Worker Onboarding - Implementation Checklist

Quick checklist for implementing worker onboarding following the established employer onboarding pattern.

**Reference**: See `WORKER_ONBOARDING.md` for detailed implementation guide.

## Backend Tasks

### Models & Business Logic
- [ ] Add `profile_info_complete?` method to `WorkerProfile` model
- [ ] Add `agreements_accepted?` method to `WorkerProfile` model
- [ ] Add `payment_info_complete?` method to `WorkerProfile` model (integrate with Stripe)
- [ ] Add `availability_set?` method to `WorkerProfile` model
- [ ] Add `onboarding_complete?` method to `WorkerProfile` model
- [ ] Add `onboarding_status` method to `WorkerProfile` model
- [ ] Add `after_save` callback to auto-update `onboarding_completed` field
- [ ] Test all model methods with RSpec

### Database
- [ ] Add migration for new fields (if needed):
  - `worker_agreement_accepted_at` (datetime)
  - `stripe_customer_id` (string)
  - `available_days` (array of strings)
- [ ] Run migration: `rails db:migrate`

### Controllers & Routes
- [ ] Add `onboarding_status` action to `WorkerProfilesController`
- [ ] Add route: `GET /api/v1/workers/me/onboarding_status`
- [ ] Test endpoint returns correct JSON structure
- [ ] Add onboarding check to `ShiftAssignmentsController#accept`
- [ ] Test backend returns 403 if onboarding not complete

### API Response Format
Ensure endpoint returns:
```json
{
  "onboarding_completed": boolean,
  "tasks": {
    "profile_info_complete": boolean,
    "agreements_accepted": boolean,
    "payment_info_complete": boolean,
    "availability_set": boolean
  },
  "all_tasks_complete": boolean
}
```

## Frontend Tasks

### API Client
- [ ] Add `getWorkerOnboardingStatus()` method to `apiClient`
- [ ] Test API client method returns correct type

### Context
- [ ] Update `OnboardingContext` to handle worker role
- [ ] Uncomment worker section in `refreshOnboardingStatus()`
- [ ] Test context switches between employer/worker correctly

### Components
- [ ] Create `WorkerOnboardingCard` component at `frontend/components/worker-dashboard/onboarding-card.tsx`
- [ ] Define worker-specific tasks (profile, agreements, payment)
- [ ] Add action links to settings pages
- [ ] Test card displays and dismisses correctly

### Layout Integration
- [ ] Wrap worker dashboard with `<OnboardingProvider userRole="worker">`
- [ ] Add `<WorkerOnboardingCard />` to worker dashboard layout
- [ ] Test card appears on all worker dashboard pages

### Settings Pages
- [ ] Add `useOnboarding()` hook to profile settings component
- [ ] Call `refreshOnboardingStatus()` after saving profile
- [ ] Add `useOnboarding()` hook to agreements component (create if doesn't exist)
- [ ] Call `refreshOnboardingStatus()` after accepting agreements
- [ ] Add `useOnboarding()` hook to payment settings component (create if doesn't exist)
- [ ] Call `refreshOnboardingStatus()` after adding payment method

### Shift Browse/Accept Protection
- [ ] Add onboarding check to shift browse page
- [ ] Show toast error if onboarding incomplete
- [ ] Redirect to dashboard if onboarding incomplete
- [ ] Test shift acceptance flow end-to-end

## Settings Pages to Create (if they don't exist)

### Profile Settings Tab
- [ ] Form fields: first_name, last_name, phone, date_of_birth
- [ ] Address fields: address_line_1, city, state, zip_code
- [ ] Validation with Zod
- [ ] Save handler with API call
- [ ] Toast notifications

### Agreements Tab
- [ ] Display Terms of Service (full text or link)
- [ ] Display Worker Agreement (full text or link)
- [ ] Checkboxes for acceptance
- [ ] "Accept All" button
- [ ] API call to save acceptance timestamps
- [ ] Toast notifications

### Payment Settings Tab
- [ ] Stripe Elements integration for bank account
- [ ] Stripe Elements integration for debit card
- [ ] Display existing payment methods
- [ ] Add new payment method flow
- [ ] Remove payment method option
- [ ] Toast notifications

## Testing

### Backend Tests
- [ ] Unit tests for all `WorkerProfile` onboarding methods
- [ ] Controller test for `onboarding_status` endpoint
- [ ] Request spec for 403 when trying to accept shift without onboarding
- [ ] Test automatic update of `onboarding_completed` field

### Frontend Tests (if applicable)
- [ ] Test `WorkerOnboardingCard` renders with correct tasks
- [ ] Test card updates when task completed
- [ ] Test card dismisses when all tasks complete
- [ ] Test redirect when accessing shifts without onboarding
- [ ] Test settings pages call `refreshOnboardingStatus()`

### Integration Tests
- [ ] Test full worker onboarding flow:
  1. Register new worker account
  2. See onboarding card with 0 of 3 tasks complete
  3. Complete profile → card shows 1 of 3
  4. Accept agreements → card shows 2 of 3
  5. Add payment method → card shows 3 of 3 and auto-dismisses
  6. Can now browse and accept shifts

## Documentation

- [ ] Update API documentation with new endpoint
- [ ] Add comments to complex onboarding logic
- [ ] Update README if needed
- [ ] Document Stripe integration patterns

## Stripe Integration (Payment Task)

- [ ] Set up Stripe customer creation flow
- [ ] Implement bank account tokenization
- [ ] Implement card tokenization
- [ ] Store `stripe_customer_id` in worker profile
- [ ] Create `has_verified_payment_method?` method that queries Stripe
- [ ] Handle Stripe webhook for payment method updates
- [ ] Test Stripe test mode thoroughly

## Optional Enhancements

- [ ] Add progress percentage indicator
- [ ] Add confetti animation when onboarding complete
- [ ] Send email reminder after 3 days if onboarding incomplete
- [ ] Add "Skip for now" option for optional tasks
- [ ] Show estimated time to complete each task
- [ ] Add onboarding analytics tracking

## Definition of Done

- [ ] All backend tests passing
- [ ] All frontend functionality working
- [ ] Card updates immediately when tasks completed (no page refresh)
- [ ] Workers cannot accept shifts until onboarding complete
- [ ] Code reviewed and approved
- [ ] Deployed to staging and tested
- [ ] Documentation updated
- [ ] Ready for production deploy

## Estimated Effort

- Backend: 1-2 days
- Frontend Components: 2-3 days
- Stripe Integration: 2-3 days
- Testing & Polish: 1-2 days
- **Total: 6-10 days** (depending on Stripe complexity)

## Dependencies

- Stripe account configured
- Worker dashboard pages exist
- Worker settings pages exist (or need to be created)
- Terms of Service and Worker Agreement documents ready

## Questions to Resolve

- [ ] Do we need background check as an onboarding task?
- [ ] Should availability preferences be required or optional?
- [ ] What Stripe product to use for worker payouts? (Connect, Direct Charges, etc.)
- [ ] Do we need ID verification as part of onboarding?
- [ ] What happens if worker's payment method becomes invalid later?
