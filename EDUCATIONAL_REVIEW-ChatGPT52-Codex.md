# Building ShiftReady: An Educational Architecture Review
**A friendly, end-to-end walkthrough of the Rails backend, the Next.js frontend, and the reasoning behind the design**

---

## Table of Contents
1. [Introduction: The Product Vision](#introduction-the-product-vision)
2. [Development History: Why We Built It This Way](#development-history-why-we-built-it-this-way)
3. [Architecture Overview: Big Picture Diagram](#architecture-overview-big-picture-diagram)
4. [Domain Model: Core Records and Relationships](#domain-model-core-records-and-relationships)
5. [How Data Moves Through the System](#how-data-moves-through-the-system)
6. [Key Design Decisions (Pros, Cons, and Trade-offs)](#key-design-decisions-pros-cons-and-trade-offs)
7. [Deep Dives: Geocoding, Phone Normalization, and Recruiting](#deep-dives-geocoding-phone-normalization-and-recruiting)
8. [State Machines: Why Status Fields Matter](#state-machines-why-status-fields-matter)
9. [Testing Strategy: Confidence Without Fear](#testing-strategy-confidence-without-fear)
10. [Next Steps: How You Can Extend This App](#next-steps-how-you-can-extend-this-app)

---

## Introduction: The Product Vision

ShiftReady is an on-demand staffing platform. Employers post shifts, and nearby workers accept them—often by SMS. It is designed for **speed**, **reliability**, and **quality matches**, all while being simple to operate for non-technical users.

This makes ShiftReady a great educational project for Rails:
- It has **real business rules** (matching, scoring, and scheduling).
- It uses **modern Rails architecture** (services, concerns, background jobs).
- It integrates **external APIs** (geocoding now, SMS and payments later).
- It maintains **separation of concerns** (API-only backend, frontend UI).

---

## Development History: Why We Built It This Way

The application evolved in phases. Each phase added **capability** while strengthening the foundation:

1. **Foundation & UX**
   - Landing page and onboarding flow were built early.
   - This validated the user experience before heavy backend work.

2. **Testing Infrastructure**
   - Factories and model tests were added before deep logic.
   - This made it safe to evolve complex algorithms later.

3. **Core Models & CRUD**
   - Shifts, companies, worker profiles, and locations.
   - This established the core domain vocabulary.

4. **Admin Visibility**
   - Dashboards and activity views arrived early.
   - Operational tools help debug data and processes.

5. **Algorithmic Recruiting**
   - Multi-factor scoring turned the system into a real marketplace.
   - Sequential offers protected worker experience.

6. **Infrastructure Services**
   - Geocoding and phone normalization made data reliable.
   - These features solve real-world data messiness.

This order is intentional: **UX > Data Model > Core Logic > Infrastructure**.

---

## Architecture Overview: Big Picture Diagram

ShiftReady uses a **Rails API backend** and a **Next.js frontend**, with background jobs for async work.

```
┌─────────────────────────────────────────────────────────────────┐
│                         CLIENT APPLICATIONS                      │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │  Next.js Web    │  │   Mobile App    │  │   SMS Gateway   │ │
│  │   (React 19)    │  │    (Future)     │  │    (Twilio)     │ │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘ │
└───────────┼────────────────────┼────────────────────┼──────────┘
            │                    │                    │
            └────────────────────┼────────────────────┘
                                 │
                        ┌────────▼────────┐
                        │   Rails API     │
                        │ (Controllers v1)│
                        └────────┬────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
    ┌────▼─────┐          ┌─────▼──────┐         ┌─────▼──────┐
    │Controllers│          │  Services  │         │   Models   │
    │ (API v1) │─────────▶│ ┌────────┐ │◀────────│ ┌────────┐ │
    │          │          │ │Recruiting│         │ │  Shift │ │
    └──────────┘          │ │Algorithm│          │ │ Worker │ │
                          │ └────────┘ │         │ │Company │ │
                          │ ┌────────┐ │         │ └────────┘ │
                          │ │Geocoding│          └─────┬──────┘
                          │ └────────┘ │                │
                          │ ┌────────┐ │                │
                          │ │  Phone  │                │
                          │ │  Norm   │                │
                          │ └────────┘ │                │
                          └─────┬──────┘                │
                                │                       │
         ┌──────────────────────┼───────────────────────┘
         │                      │
    ┌────▼─────┐         ┌─────▼──────┐
    │Background│         │ PostgreSQL │
    │   Jobs   │◀────────│  Database  │
    │ ┌──────┐ │         │            │
    │ │Geocode│ │         └────────────┘
    │ │Recruit│ │
    │ │Timeout│ │
    │ └──────┘ │
    └──────────┘
```

**Key idea:** Controllers stay thin, services handle orchestration, models enforce data integrity.

### Frontend Architecture (Next.js App Router)

The frontend lives in `frontend/` and uses:
- `app/` for route-based UI
- `components/` for reusable UI blocks
- `lib/api/client.ts` for API calls
- `lib/phone.ts` for formatting and normalization

Why this matters:
- The UI is cleanly decoupled from the API.
- Frontend utilities mirror backend behavior (like phone formatting).

### Example: Thin Controller Pattern
```ruby
class ShiftsController < ApplicationController
  def start_recruiting
    shift = Shift.find(params[:id])
    result = ShiftOfferService.create_next_offer(shift)

    if result[:success]
      render json: { assignment: result[:data] }
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end
end
```

This keeps HTTP handling separate from the recruiting workflow.

---

## Domain Model: Core Records and Relationships

At the heart of the system are a few crucial records:

```
User
 ├─ WorkerProfile
 └─ EmployerProfile

EmployerProfile → Company
Company → WorkLocation
Company → Shift

Shift → ShiftAssignment → WorkerProfile

ShiftAssignment → Payment
Shift → RecruitingActivityLog
```

### Visual Relationship Map
```
User
 ├─ WorkerProfile ──┐
 │                 │
 │              ShiftAssignment ── Payment
 │                 │
 └─────────────── Shift
                   │
                   └─ Company ── WorkLocation
```

### Why this structure?
- `User` is authentication only.
- Profiles hold role-specific data.
- Shifts and assignments form the marketplace.

### Example: ShiftAssignment as a junction record

```ruby
class ShiftAssignment < ApplicationRecord
  enum :status, {
    offered: 0,
    accepted: 1,
    declined: 2,
    no_response: 3,
    confirmed: 4,
    checked_in: 5,
    no_show: 6,
    completed: 7,
    cancelled: 8
  }

  validates :shift_id, uniqueness: { scope: :worker_profile_id }
end
```

This model is where **matching becomes a real workflow**, not just a join table.

---

## How Data Moves Through the System

Let's trace a **shift recruiting flow**, end to end:

```
Employer creates shift
        ↓
Shift status becomes "posted"
        ↓
Employer starts recruiting
        ↓
ProcessShiftRecruitingJob runs
        ↓
RecruitingAlgorithmService scores workers
        ↓
ShiftOfferService creates ShiftAssignment (status: offered)
        ↓
CheckOfferTimeoutJob scheduled for 15 minutes
        ↓
Worker responds (accept/decline) OR times out
        ↓
Assignment status updates
        ↓
Shift may become filled
```

Key takeaway: **data flows through services and jobs**, not directly through controllers.

### Typical API Request Lifecycle
```
Browser → Next.js page → API client → Rails controller
       → Service object → Model updates → JSON response
```

**Why it matters:** Every layer has one job. Debugging becomes a matter of finding the right layer.

### Onboarding Data Flows

**Employer onboarding**
```
User signs up (role: employer)
        ↓
EmployerProfile created
        ↓
Company created
        ↓
WorkLocation(s) created
```

**Worker onboarding**
```
User signs up (role: worker)
        ↓
WorkerProfile created
        ↓
Preferred job types saved
        ↓
Availability and location saved
```

### Record Changes and Side Effects

This system is intentionally event-driven: when records change, other parts of the system respond.

**Examples:**

1. **WorkerProfile address updated**
   - `Geocodable` concern triggers background geocoding.
   - Coordinates update later without blocking the request.

2. **Phone numbers saved**
   - `PhoneNormalizable` runs before validation.
   - Uniqueness checks become reliable.

3. **ShiftAssignment status changes**
   - Counters update (e.g., `total_shifts_completed`).
   - Reliability scores are recalculated.
   - Recruiting may resume if a slot opens.

These side effects are why **explicit state and service boundaries** matter.

---

## Key Design Decisions (Pros, Cons, and Trade-offs)

### 1) API-Only Rails + Separate Frontend
**Why:** future mobile app, modern UI development, clean separation.

**Pros**
- Independent scaling of backend/frontend
- UI can evolve quickly
- API reusable for mobile/SMS

**Cons**
- More deployment complexity
- Requires CORS and auth plumbing

### 2) Sequential Recruiting (one offer at a time)
**Why:** avoid spam and double-booking.

**Pros**
- Better worker experience
- More reliable fill tracking

**Cons**
- Slower to fill urgent shifts

### 3) Background Jobs for Geocoding and Recruiting
**Why:** external APIs are slow and unreliable.

**Pros**
- Faster API responses
- Automatic retries

**Cons**
- Eventual consistency (data updates later)

### 4) Normalize Phones Before Validation
**Why:** phone formats are inconsistent.

**Pros**
- Uniqueness checks work
- Data is consistent

**Cons**
- Slightly more code and callbacks

---

## Deep Dives: Geocoding, Phone Normalization, and Recruiting

### Geocoding (Address → Latitude/Longitude)
We use a concern to trigger geocoding **after** save:

```ruby
module Geocodable
  extend ActiveSupport::Concern

  included do
    after_commit :enqueue_geocoding_job, if: :should_geocode?
  end
end
```

**Why after_commit?**
- The record is persisted first (safe).
- External API calls never block the request.

### Phone Normalization
We normalize phone numbers before validation so uniqueness is reliable.

```ruby
module PhoneNormalizable
  extend ActiveSupport::Concern

  included do
    before_validation :normalize_phone_fields
  end
end
```

**Why before_validation?**
- Normalized values participate in uniqueness checks.
- All phone storage is consistent (E.164).

**Simplified normalization logic:**
```ruby
class PhoneNormalizationService
  def self.normalize(phone)
    return nil if phone.blank?
    digits = phone.gsub(/\D/, '')

    case digits.length
    when 10
      "+1#{digits}"
    when 11
      digits.start_with?('1') ? "+#{digits}" : nil
    else
      nil
    end
  end
end
```

### Recruiting Algorithm (Multi-Factor Scoring)
Workers are ranked by distance, reliability, job match, rating, response time, and experience.

```ruby
# Example weights
DISTANCE_MAX_POINTS = 30
RELIABILITY_MAX_POINTS = 25
JOB_TYPE_MAX_POINTS = 20
RATING_MAX_POINTS = 15
RESPONSE_TIME_MAX_POINTS = 10
EXPERIENCE_MAX_POINTS = 10
```

**Why this matters:**
- Faster fills with higher acceptance rates.
- Better matches lead to fewer no-shows.

**Sequential offer workflow (simplified):**
```
Find eligible workers → Rank → Offer to #1
                     ↘ if declined/timeout → Offer to #2
```

This design prioritizes **worker respect** over raw speed.

---

## State Machines: Why Status Fields Matter

Statuses capture **business meaning**, not just progress.

### Shift lifecycle (simplified)
```
draft → posted → recruiting → filled → in_progress → completed
                ↘ cancelled (any time)
```

### ShiftAssignment lifecycle (simplified)
```
offered → accepted → confirmed → checked_in → completed
   │          │
   ├─ decline └─ no_show
   └─ timeout → no_response
```

**Why explicit states?**
- Easier debugging ("why didn't this fill?")
- Better analytics ("how many no-shows last month?")
- Safer transitions (only allow valid steps)

---

## Testing Strategy: Confidence Without Fear

We follow a pyramid:
```
Integration tests (few)
Service tests (some)
Model tests (many)
```

**Why it works:**
- Models are tested for validity and relationships.
- Services are tested for complex workflows.
- Controllers are tested only for API correctness.

---

## Next Steps: How You Can Extend This App

Here are clear, practical expansion paths:

1. **SMS integration**  
   - Implement `SmsService` with Twilio.  
   - Add inbound SMS webhook for accept/decline.

2. **Payments**  
   - Connect Stripe Connect for worker payouts.  
   - Build payment status tracking and retries.

3. **Notifications**  
   - WebSocket updates with ActionCable.  
   - Push notifications for mobile apps.

4. **Admin analytics**  
   - Offer acceptance rate, average fill time, no-show metrics.

5. **Performance & scale**  
   - Add caching for shift searches.  
   - Index heavy queries (status + datetime).

---

## Appendix: Project Structure Cheat Sheet

```
backend/
├── app/
│   ├── controllers/api/v1/   # JSON endpoints
│   ├── models/               # Domain records
│   ├── models/concerns/      # Shared behaviors
│   ├── services/             # Business logic
│   └── jobs/                 # Async workers
├── db/                       # Migrations & schema
└── test/                     # Minitest suites

frontend/
├── app/                      # Next.js App Router pages
├── components/               # UI components
└── lib/                      # API client, helpers
```

## Closing Thoughts

ShiftReady is a real-world Rails app that teaches:
- How to separate concerns with services and concerns
- Why background jobs are essential in production apps
- How to model workflows with state machines
- How to make architectural trade-offs on purpose

If you are new to Rails, this is a fantastic playground: build one feature end-to-end, write tests, and learn why each layer exists.

Happy building!
