# Worker Onboarding Implementation Guide

## Overview

This document outlines the implementation plan for worker onboarding, following the same reactive, reusable pattern established for employer onboarding. Workers must complete specific tasks before they can accept shifts and receive payments.

## Onboarding Tasks for Workers

Workers must complete the following tasks before their account becomes active:

### 1. Complete Profile Information
- **First Name** (required)
- **Last Name** (required)
- **Phone** (required, E.164 normalized)
- **Home Address** (required for distance calculations)
  - Address Line 1
  - City
  - State
  - ZIP Code
- **Date of Birth** (required for background checks)

**Validation**: All profile fields are filled in and home address is geocoded.

### 2. Accept Terms & Agreements
- **Terms of Service** (`terms_accepted_at` timestamp)
- **Worker Agreement** (`worker_agreement_accepted_at` timestamp)

**Validation**: Both timestamps are not null.

### 3. Add Payment Information
- **Payment Method** (required - ACH or debit card)
- **Bank Account** or **Card Details** (stored via Stripe)

**Validation**: Worker has at least one verified payment method on file.

### 4. Set Availability Preferences (Optional but Recommended)
- **Available Days** (which days of week)
- **Preferred Shift Times** (morning, afternoon, evening, overnight)
- **Maximum Distance** (how far willing to travel)

**Validation**: At least one availability preference is set.

## Backend Implementation

### Step 1: Add Onboarding Methods to WorkerProfile Model

**File**: `backend/app/models/worker_profile.rb`

```ruby
# Add these methods to WorkerProfile model

# Check if profile information is complete
def profile_info_complete?
  first_name.present? &&
    last_name.present? &&
    phone.present? &&
    date_of_birth.present? &&
    address_line_1.present? &&
    city.present? &&
    state.present? &&
    zip_code.present? &&
    latitude.present? &&
    longitude.present?
end

# Check if terms and agreements are accepted
def agreements_accepted?
  terms_accepted_at.present? && worker_agreement_accepted_at.present?
end

# Check if payment information is set up
def payment_info_complete?
  # TODO: Check Stripe for verified payment method
  # This will require integration with Stripe API
  stripe_customer_id.present? && has_verified_payment_method?
end

# Check if availability preferences are set
def availability_set?
  # At least one day of week is selected
  available_days.present? && available_days.any?
end

# Check if all required onboarding tasks are complete
def onboarding_complete?
  profile_info_complete? &&
    agreements_accepted? &&
    payment_info_complete?
  # Note: availability_set? is optional/recommended but not required
end

# Return onboarding status with task breakdown
def onboarding_status
  {
    profile_info_complete: profile_info_complete?,
    agreements_accepted: agreements_accepted?,
    payment_info_complete: payment_info_complete?,
    availability_set: availability_set?,
    is_complete: onboarding_complete?
  }
end

# Callbacks to auto-update onboarding_completed field
after_save :update_onboarding_completed_status, if: :saved_change_to_onboarding_fields?

private

def saved_change_to_onboarding_fields?
  saved_change_to_first_name? ||
    saved_change_to_last_name? ||
    saved_change_to_phone? ||
    saved_change_to_date_of_birth? ||
    saved_change_to_address_line_1? ||
    saved_change_to_city? ||
    saved_change_to_state? ||
    saved_change_to_zip_code? ||
    saved_change_to_terms_accepted_at? ||
    saved_change_to_worker_agreement_accepted_at?
end

def update_onboarding_completed_status
  new_status = onboarding_complete?
  update_column(:onboarding_completed, new_status) if onboarding_completed != new_status
end
```

### Step 2: Add Onboarding Status Controller Action

**File**: `backend/app/controllers/api/v1/worker_profiles_controller.rb`

```ruby
# Add to before_action
before_action :ensure_worker_role, only: [:create, :update, :onboarding_status]
before_action :set_worker_profile, only: [:show, :update, :onboarding_status]

# Add this new action
# GET /api/v1/workers/me/onboarding_status
def onboarding_status
  unless @worker_profile
    return render_error('Worker profile not found', :not_found)
  end

  render json: {
    onboarding_completed: @worker_profile.onboarding_completed,
    tasks: {
      profile_info_complete: @worker_profile.profile_info_complete?,
      agreements_accepted: @worker_profile.agreements_accepted?,
      payment_info_complete: @worker_profile.payment_info_complete?,
      availability_set: @worker_profile.availability_set?
    },
    all_tasks_complete: @worker_profile.onboarding_complete?
  }
end
```

### Step 3: Add Route

**File**: `backend/config/routes.rb`

```ruby
# Worker profiles
resources :workers, controller: 'worker_profiles', only: [:create, :index] do
  collection do
    get 'me', to: 'worker_profiles#show'
    patch 'me', to: 'worker_profiles#update'
    get 'me/onboarding_status', to: 'worker_profiles#onboarding_status'  # ADD THIS LINE
  end
end
```

### Step 4: Protect Shift Assignment Endpoints

**File**: `backend/app/controllers/api/v1/shift_assignments_controller.rb`

Add check to prevent workers from accepting shifts if onboarding is not complete:

```ruby
# POST /api/v1/shift_assignments/:id/accept
def accept
  worker_profile = current_user.worker_profile

  unless worker_profile&.onboarding_completed?
    return render_error('You must complete onboarding before accepting shifts', :forbidden)
  end

  # ... rest of existing code
end
```

## Frontend Implementation

### Step 1: Add Worker Onboarding Type to API Client

**File**: `frontend/lib/api/client.ts`

The `OnboardingStatus` interface already exists and is reusable. Just add the method:

```typescript
async getWorkerOnboardingStatus() {
  return this.request<OnboardingStatus>("/api/v1/workers/me/onboarding_status");
}
```

### Step 2: Update Onboarding Context for Workers

**File**: `frontend/contexts/onboarding-context.tsx`

Already supports workers! Just uncomment the worker section:

```typescript
const refreshOnboardingStatus = useCallback(async () => {
  setIsLoading(true);
  try {
    let response;
    if (userRole === "employer") {
      response = await apiClient.getEmployerOnboardingStatus();
    } else if (userRole === "worker") {
      response = await apiClient.getWorkerOnboardingStatus();  // UNCOMMENT THIS
    } else {
      return;
    }

    if (response.data && !response.error) {
      setOnboardingStatus(response.data);
    }
  } catch (error) {
    console.error("Failed to fetch onboarding status:", error);
  } finally {
    setIsLoading(false);
  }
}, [userRole]);
```

### Step 3: Create Worker Onboarding Card Component

**File**: `frontend/components/worker-dashboard/onboarding-card.tsx`

Create a worker-specific onboarding card (can be based on employer card but with different tasks):

```typescript
"use client";

import { useEffect, useState } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { CheckCircle2, Circle, Loader2, X } from "lucide-react";
import { useRouter } from "next/navigation";
import { useOnboarding } from "@/contexts/onboarding-context";

interface OnboardingTask {
  id: string;
  title: string;
  description: string;
  completed: boolean;
  actionLink: string;
  actionLabel: string;
}

export function WorkerOnboardingCard() {
  const router = useRouter();
  const { onboardingStatus, isLoading, refreshOnboardingStatus } = useOnboarding();
  const [isDismissed, setIsDismissed] = useState(false);

  useEffect(() => {
    refreshOnboardingStatus();
  }, [refreshOnboardingStatus]);

  useEffect(() => {
    if (onboardingStatus?.all_tasks_complete) {
      setIsDismissed(true);
    }
  }, [onboardingStatus]);

  if (isLoading) {
    return (
      <Card className="mb-6 border-amber-200 bg-amber-50">
        <CardContent className="flex items-center justify-center py-8">
          <Loader2 className="h-6 w-6 animate-spin text-amber-600" />
        </CardContent>
      </Card>
    );
  }

  if (isDismissed || !onboardingStatus || onboardingStatus.all_tasks_complete) {
    return null;
  }

  const tasks: OnboardingTask[] = [
    {
      id: "profile_info",
      title: "Complete your profile",
      description: "Add your name, phone, address, and date of birth",
      completed: onboardingStatus.tasks.profile_info_complete,
      actionLink: "/dashboard/worker/settings?tab=profile",
      actionLabel: "Complete Profile",
    },
    {
      id: "agreements",
      title: "Accept terms and agreements",
      description: "Review and accept the terms of service and worker agreement",
      completed: onboardingStatus.tasks.agreements_accepted,
      actionLink: "/dashboard/worker/settings?tab=agreements",
      actionLabel: "Review Terms",
    },
    {
      id: "payment",
      title: "Add payment method",
      description: "Set up your bank account or debit card to receive payments",
      completed: onboardingStatus.tasks.payment_info_complete,
      actionLink: "/dashboard/worker/settings?tab=payment",
      actionLabel: "Add Payment",
    },
  ];

  const completedCount = tasks.filter((task) => task.completed).length;
  const totalCount = tasks.length;

  return (
    <Card className="mb-6 border-amber-200 bg-amber-50">
      <CardHeader className="relative pb-3">
        <div className="flex items-start justify-between">
          <div className="flex-1">
            <div className="flex items-center gap-2">
              <CardTitle className="text-lg">Complete Your Profile</CardTitle>
              <Badge className="bg-amber-100 text-amber-700 hover:bg-amber-100">
                {completedCount} of {totalCount}
              </Badge>
            </div>
            <CardDescription className="mt-1">
              Finish these steps to start accepting shifts and earning money
            </CardDescription>
          </div>
          <Button
            variant="ghost"
            size="icon"
            className="h-8 w-8 text-amber-600 hover:bg-amber-100 hover:text-amber-700"
            onClick={() => setIsDismissed(true)}
          >
            <X className="h-4 w-4" />
          </Button>
        </div>
      </CardHeader>
      <CardContent className="space-y-3 pb-4">
        {tasks.map((task) => (
          <div
            key={task.id}
            className="flex items-start gap-3 rounded-lg bg-white p-3 shadow-sm"
          >
            <div className="mt-0.5">
              {task.completed ? (
                <CheckCircle2 className="h-5 w-5 text-emerald-600" />
              ) : (
                <Circle className="h-5 w-5 text-gray-400" />
              )}
            </div>
            <div className="flex-1 min-w-0">
              <h4 className="font-medium text-sm text-gray-900">{task.title}</h4>
              <p className="text-xs text-gray-600 mt-0.5">{task.description}</p>
            </div>
            {!task.completed && (
              <Button
                size="sm"
                variant="outline"
                className="ml-2 shrink-0 border-amber-300 text-amber-700 hover:bg-amber-100 hover:text-amber-800"
                onClick={() => router.push(task.actionLink)}
              >
                {task.actionLabel}
              </Button>
            )}
          </div>
        ))}
      </CardContent>
    </Card>
  );
}
```

### Step 4: Update Worker Dashboard Layout

**File**: `frontend/app/dashboard/worker/layout.tsx`

Wrap with OnboardingProvider and add WorkerOnboardingCard:

```typescript
import { OnboardingProvider } from "@/contexts/onboarding-context";
import { WorkerOnboardingCard } from "@/components/worker-dashboard/onboarding-card";

export default function WorkerDashboardLayout({ children }: { children: React.ReactNode }) {
  // ... existing code

  return (
    <ProtectedRoute allowedRoles={["worker"]}>
      <OnboardingProvider userRole="worker">
        <div className="min-h-screen bg-background">
          {/* ... header and sidebar code ... */}

          <main className="flex-1 min-h-[calc(100vh-4rem)]">
            <div className="px-4 lg:px-8 pt-6">
              <WorkerOnboardingCard />
            </div>
            {children}
          </main>
        </div>
      </OnboardingProvider>
    </ProtectedRoute>
  );
}
```

### Step 5: Add Refresh Calls to Worker Settings Components

Wherever workers can complete onboarding tasks, call `refreshOnboardingStatus()`:

**Profile Settings Component**:
```typescript
const { refreshOnboardingStatus } = useOnboarding();

const onSubmit = async (data) => {
  // ... save profile data
  await refreshOnboardingStatus(); // Add this
};
```

**Agreements Component**:
```typescript
const handleAcceptTerms = async () => {
  // ... accept terms
  await refreshOnboardingStatus(); // Add this
};
```

**Payment Settings Component**:
```typescript
const handleAddPaymentMethod = async () => {
  // ... add payment method
  await refreshOnboardingStatus(); // Add this
};
```

### Step 6: Protect Shift Browse/Accept Pages

**File**: `frontend/app/dashboard/worker/shifts/page.tsx` (or similar)

Add onboarding check similar to employer shifts:

```typescript
useEffect(() => {
  async function checkOnboardingAndFetchData() {
    try {
      const onboardingResponse = await apiClient.getWorkerOnboardingStatus();

      if (onboardingResponse.data && !onboardingResponse.data.all_tasks_complete) {
        toast.error("Complete your profile first", {
          description: "You must complete all onboarding steps before you can accept shifts.",
          duration: 6000,
        });
        router.push("/dashboard/worker");
        return;
      }

      // Fetch available shifts
      const response = await apiClient.getShifts();
      if (response.data) {
        setShifts(response.data.shifts);
      }
    } catch (err) {
      console.error("Failed to fetch data:", err);
    } finally {
      setIsLoading(false);
    }
  }

  checkOnboardingAndFetchData();
}, [router]);
```

## Database Migrations (If Needed)

If new fields need to be added to `worker_profiles`:

```ruby
class AddOnboardingFieldsToWorkerProfiles < ActiveRecord::Migration[7.2]
  def change
    # If these don't exist already:
    add_column :worker_profiles, :worker_agreement_accepted_at, :datetime
    add_column :worker_profiles, :stripe_customer_id, :string
    add_column :worker_profiles, :available_days, :string, array: true, default: []

    # Add index for stripe_customer_id
    add_index :worker_profiles, :stripe_customer_id
  end
end
```

## Testing Checklist

### Backend Tests
- [ ] Test `profile_info_complete?` returns false when any required field is missing
- [ ] Test `agreements_accepted?` returns false when either timestamp is null
- [ ] Test `payment_info_complete?` checks Stripe for verified payment method
- [ ] Test `onboarding_complete?` returns true only when all required tasks are done
- [ ] Test onboarding status endpoint returns correct task completion status
- [ ] Test shift assignment endpoint rejects workers who haven't completed onboarding

### Frontend Tests
- [ ] OnboardingCard appears when tasks are incomplete
- [ ] OnboardingCard shows correct completion count (e.g., "2 of 3")
- [ ] Clicking action buttons navigates to correct settings pages
- [ ] Card updates immediately when profile is saved
- [ ] Card updates immediately when agreements are accepted
- [ ] Card updates immediately when payment method is added
- [ ] Card auto-dismisses when all tasks are complete
- [ ] Attempting to accept shift shows error if onboarding incomplete
- [ ] Attempting to accept shift succeeds if onboarding complete

## Implementation Order

1. **Backend Foundation** (Day 1)
   - Add methods to WorkerProfile model
   - Add controller action for onboarding status
   - Add route
   - Test with curl/Postman

2. **Frontend Context** (Day 1)
   - Update OnboardingContext to support workers
   - Add API client method
   - Test context in isolation

3. **Worker Onboarding Card** (Day 2)
   - Create WorkerOnboardingCard component
   - Add to worker dashboard layout
   - Test card displays and dismisses correctly

4. **Settings Integration** (Day 2-3)
   - Add refresh calls to profile settings
   - Add agreements acceptance UI if not exists
   - Add payment method UI if not exists
   - Test reactive updates

5. **Protection & Validation** (Day 3)
   - Add onboarding check to shift browse/accept pages
   - Add backend protection to shift assignment endpoints
   - Test error handling

6. **Polish & Testing** (Day 4)
   - Add toast notifications
   - Test full user flow
   - Fix any bugs
   - Update documentation

## Notes & Considerations

### Payment Information
- Workers' payment info will likely be stored in Stripe, not directly in the database
- You'll need to integrate with Stripe API to check for verified payment methods
- Consider creating a `PaymentService` to abstract Stripe interactions
- The `has_verified_payment_method?` method should query Stripe API

### Background Checks
- If background checks are required, add that as another onboarding task
- May require integration with third-party background check service
- Should probably be an async process with status tracking

### Availability Preferences
- Currently listed as "optional but recommended"
- Consider making this required if shift matching depends on it
- Could show a warning if not set rather than blocking

### Data Privacy
- Date of birth is sensitive - ensure proper access controls
- Payment information should never be stored directly in database
- Consider GDPR/CCPA compliance for profile data

### User Experience
- Consider showing a progress indicator on the dashboard
- Send email reminders if onboarding incomplete after X days
- Celebrate when onboarding is complete (confetti animation?)

## Related Files

- **Employer Onboarding Reference**: See employer onboarding implementation as template
- **OnboardingContext**: `frontend/contexts/onboarding-context.tsx`
- **WorkerProfile Model**: `backend/app/models/worker_profile.rb`
- **WorkerProfiles Controller**: `backend/app/controllers/api/v1/worker_profiles_controller.rb`
