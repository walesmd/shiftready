# Building ShiftReady: A Deep Dive into On-Demand Staffing Platform Architecture

**An Educational Journey Through Real-World Rails Development**

---

## Table of Contents

1. [Introduction: What We're Building and Why](#introduction)
2. [The Development Journey: From Zero to Production](#development-journey)
3. [Architecture Overview: The Big Picture](#architecture-overview)
4. [The Data Model: Understanding Our Domain](#data-model)
5. [The Recruiting Algorithm: Our Secret Sauce](#recruiting-algorithm)
6. [Smart Infrastructure: Geocoding and Phone Normalization](#smart-infrastructure)
7. [State Machines: Managing Complexity with Elegance](#state-machines)
8. [The Service Layer: Organizing Business Logic](#service-layer)
9. [Background Jobs: Async Processing Done Right](#background-jobs)
10. [Testing Philosophy: Building with Confidence](#testing-philosophy)
11. [Architectural Decisions: Trade-offs and Why We Made Them](#architectural-decisions)
12. [Lessons Learned and Anti-Patterns We Avoided](#lessons-learned)
13. [Next Steps: Where You Can Take This](#next-steps)

---

## Introduction: What We're Building and Why

### The Problem

Imagine you're a restaurant manager in San Antonio. It's Friday morning, and one of your servers just called in sick for tonight's dinner rush. You need someone *now* - someone reliable, nearby, and experienced with restaurant work.

On the flip side, imagine you're a worker with flexible availability. You're free tonight and would love to pick up some extra cash, but you don't know which restaurants need help.

**ShiftReady solves this matching problem.**

### The Solution

ShiftReady is an on-demand staffing marketplace that connects employers with flexible workers via SMS. Think of it as "Uber for shift work" - but with a sophisticated matching algorithm that considers distance, reliability, experience, and worker preferences.

### Why This Project is Great for Learning

This codebase demonstrates:
- **Real-world complexity**: Not a toy app, but production-ready code
- **Modern Rails patterns**: Services, concerns, background jobs, and state machines
- **Sophisticated algorithms**: Multi-factor scoring and ranking
- **External integrations**: Geocoding APIs, SMS (planned), payment processing (planned)
- **Solid engineering practices**: Comprehensive testing, clear abstractions, observability

Let's dive in!

---

## Development Journey: From Zero to Production

Understanding *how* this application was built is just as important as understanding *what* it is. Let's walk through the development timeline:

### Phase 1: Foundation (Weeks 1-2)
**Commits:** `3c1b2ad` → `29ffa8f`

```
✅ Next.js landing page
✅ Worker registration flow
✅ Employer registration flow
✅ Basic authentication with Devise + JWT
```

**Key Decision:** Started with user-facing features first (registration) rather than building the full backend infrastructure. This validates the concept early and provides quick wins.

### Phase 2: Testing Infrastructure (Week 2)
**Commits:** `a2597b6` → `88d8c61`

```
✅ FactoryBot setup for test data
✅ Shoulda Matchers for declarative tests
✅ Comprehensive model tests
✅ Service object tests
```

**Key Decision:** Paused feature development to invest in testing infrastructure. This pays dividends throughout the rest of development - we can refactor with confidence.

### Phase 3: Core Features (Weeks 3-4)
**Commits:** `5d60d02` → `a96289b`

```
✅ Shift posting (backend + frontend)
✅ Shift validation and tracking codes
✅ Work location management
✅ Company profiles
```

**Key Decision:** Built the "supply side" first (employers posting shifts) before the "demand side" (workers finding shifts). This makes sense - you need jobs before workers have anything to apply for.

### Phase 4: Admin Dashboard (Week 5)
**Commits:** `0d28b48` → `81d8e2f`

```
✅ Admin overview dashboard
✅ All shifts view with filtering
✅ Companies dashboard
✅ Workers dashboard
✅ Activity feed
✅ Seed data for development
```

**Key Decision:** Built admin tools early. This is crucial for debugging, monitoring, and understanding how the system works. Many teams build admin tools last (or never), which makes debugging production issues painful.

### Phase 5: User Profiles (Weeks 6-7)
**Commits:** `dad8691` → `28a0d0c`

```
✅ Editable worker profiles
✅ Editable employer profiles
✅ Company settings
✅ Work location management
```

**Key Decision:** Separated "onboarding" (initial registration) from "profile management" (ongoing updates). Different UX needs and validation rules.

### Phase 6: The Recruiting Algorithm (Week 8) 🎯
**Commits:** `126df48` → `ead534a`

This is where it gets interesting. The recruiting algorithm is the heart of ShiftReady - it's what makes the platform actually *work*.

```
✅ Multi-factor scoring system (110 points)
✅ Distance-based filtering (25-mile radius)
✅ Sequential offer workflow (one at a time)
✅ Offer timeout handling (15 minutes)
✅ Background job orchestration
✅ Comprehensive activity logging
✅ 347-line test suite for the algorithm
```

**Key Decision:** Sequential offers (one worker at a time) rather than parallel offers. This prevents double-booking workers and reduces "offer spam". It's slower, but more respectful to workers.

### Phase 7: Geocoding (Week 9) 📍
**Commits:** `c34995b` → `64f48e0`

```
✅ Geocodio API integration
✅ Automatic address geocoding
✅ Geocodable concern (reusable)
✅ Background geocoding jobs
✅ Distance calculations (Haversine formula)
```

**Key Decision:** Async geocoding via background jobs. Addresses are geocoded *after* the record is saved, not during validation. This keeps API responses fast and handles API failures gracefully.

### Phase 8: Phone Normalization (Week 10) 📱
**Commits:** `e91c949` → `e6bda14`

```
✅ E.164 format normalization
✅ PhoneNormalizable concern
✅ Display formatting for UX
✅ Prevents duplicate accounts with different phone formats
```

**Key Decision:** Normalize phone numbers *before* validation, not after. This ensures uniqueness constraints work correctly (otherwise `(210) 555-0123` and `2105550123` would be considered different).

---

## Architecture Overview: The Big Picture

ShiftReady follows a clean, service-oriented architecture. Let's visualize how the pieces fit together:

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLIENT APPLICATIONS                       │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │  Next.js Web    │  │   Mobile App    │  │   SMS Gateway   │ │
│  │   (React 19)    │  │    (Future)     │  │    (Twilio)     │ │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘ │
└───────────┼────────────────────┼────────────────────┼──────────┘
            │                    │                    │
            └────────────────────┼────────────────────┘
                                 │
                        ┌────────▼────────┐
                        │   API Gateway   │
                        │  (Rails Router) │
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
                          │ ┌────────┐ │                │
                          │ │  Shift  │                │
                          │ │  Offer  │                │
                          │ └────────┘ │                │
                          └─────┬──────┘                │
                                │                       │
         ┌──────────────────────┼───────────────────────┘
         │                      │
    ┌────▼─────┐         ┌─────▼──────┐
    │Background│         │ PostgreSQL │
    │   Jobs   │◀────────│  Database  │
    │ ┌──────┐ │         │            │
    │ │Geocode│         │  + PostGIS │
    │ │Recruit│          └────────────┘
    │ │Timeout│
    │ └──────┘ │
    │(Solid    │
    │ Queue)   │
    └──────────┘
         │
         ▼
    ┌──────────┐
    │External  │
    │Services  │
    │┌────────┐│
    ││Geocodio││
    ││ Twilio ││
    ││ Stripe ││
    │└────────┘│
    └──────────┘
```

### Key Architectural Layers

1. **Controllers**: Handle HTTP requests, authenticate users, call services
2. **Services**: Encapsulate business logic (recruiting, geocoding, phone normalization)
3. **Models**: Represent domain entities with validations and relationships
4. **Background Jobs**: Handle async work (geocoding, recruiting, timeouts)
5. **Concerns**: Share behavior across models (DRY principle)

---

## The Data Model: Understanding Our Domain

The domain model is the heart of any application. Let's understand the entities and their relationships:

### Core Entities Relationship Diagram

```
                          ┌──────────┐
                          │   User   │
                          │          │
                          │ email    │
                          │ password │
                          │ role     │
                          └─────┬────┘
                                │
                    ┌───────────┴───────────┐
                    │                       │
            ┌───────▼────────┐      ┌──────▼──────────┐
            │WorkerProfile   │      │EmployerProfile  │
            │                │      │                 │
            │ phone          │      │ phone           │
            │ address        │      │ company_id      │
            │ lat/lng        │      │ permissions     │
            │ reliability    │      └────────┬────────┘
            └───┬────────────┘               │
                │                            │
                │                    ┌───────▼────────┐
                │                    │    Company     │
                │                    │                │
                │                    │ name           │
                │                    │ billing_addr   │
                │                    └───┬────────────┘
                │                        │
                │                ┌───────┴────────────┐
                │                │                    │
                │        ┌───────▼──────┐     ┌──────▼──────┐
                │        │WorkLocation  │     │   Shifts    │
                │        │              │     │             │
                │        │ address      │◀────│ title       │
                │        │ lat/lng      │     │ job_type    │
                │        └──────────────┘     │ start/end   │
                │                             │ pay_rate    │
                │                             │ status      │
                │                             └──┬──────────┘
                │                                │
                │                ┌───────────────┴────────────────┐
                │                │                                │
                │        ┌───────▼──────────┐           ┌────────▼────────┐
                └───────▶│ShiftAssignment   │           │RecruitingActivity│
                         │                  │           │      Log         │
                         │ status           │           │                  │
                         │ algorithm_score  │           │ action           │
                         │ distance_miles   │           │ details (JSONB)  │
                         │ check_in/out     │           └──────────────────┘
                         └────┬─────────────┘
                              │
                      ┌───────▼────────┐
                      │    Payment     │
                      │                │
                      │ amount         │
                      │ status         │
                      │ tax_year       │
                      └────────────────┘
```

### Let's Break Down Each Entity

#### User (Authentication Base)
```ruby
# The foundation of identity
class User < ApplicationRecord
  # Three roles in the system
  enum :role, { worker: 0, employer: 1, admin: 2 }

  # Polymorphic profile relationship
  has_one :worker_profile
  has_one :employer_profile
end
```

**Why this design?**
- Single sign-on: One email/password for the entire platform
- Role-based access: Different UX for workers vs employers
- Profile separation: Workers and employers have very different data needs

#### WorkerProfile (The Supply Side)
```ruby
class WorkerProfile < ApplicationRecord
  include Geocodable           # Auto-geocoding
  include PhoneNormalizable    # Phone formatting

  # Performance metrics (updated automatically)
  # - reliability_score: 0-100 weighted score
  # - average_rating: 1-5 from employers
  # - average_response_time_minutes: How fast they respond to SMS

  # Counters (incremented automatically)
  # - total_shifts_assigned
  # - total_shifts_completed
  # - no_show_count
end
```

**The reliability score is calculated like this:**
```ruby
def calculate_reliability_score
  return 0 if total_shifts_assigned.zero?

  attendance_rate = ((total_shifts_completed - no_show_count).to_f / total_shifts_assigned) * 100
  rating_score = (average_rating || 3.0) / 5.0 * 100
  response_score = calculate_response_time_score # 0-100 based on speed

  # Weighted average
  (attendance_rate * 0.4) + (rating_score * 0.4) + (response_score * 0.2)
end
```

**Why these metrics?**
- **Reliability score**: Predicts future performance
- **Response time**: Fast responders are more likely to accept offers
- **Ratings**: Employer feedback matters

#### Shift (The Job Opportunity)
```ruby
class Shift < ApplicationRecord
  # Lifecycle states
  enum :status, {
    draft: 0,        # Being created
    posted: 1,       # Visible but not recruiting
    recruiting: 2,   # Actively sending offers
    filled: 3,       # All slots taken
    in_progress: 4,  # Currently happening
    completed: 5,    # Finished
    cancelled: 6     # Won't happen
  }

  # Unique tracking code (e.g., "SR-A3F91C")
  validates :tracking_code, format: { with: /\ASR-[A-F0-9]{6}\z/ }
end
```

**Tracking codes are brilliant:**
- Public identifier (safe to share)
- Short enough for SMS
- Easy to type (no lowercase confusion)
- Globally unique

#### ShiftAssignment (The Junction)
This is where the magic happens - connecting workers to shifts.

```ruby
class ShiftAssignment < ApplicationRecord
  # Rich state machine
  enum :status, {
    offered: 0,      # Offer sent, waiting for response
    accepted: 1,     # Worker said yes
    declined: 2,     # Worker said no
    no_response: 3,  # 15 minutes passed, no answer
    confirmed: 4,    # Employer confirmed
    checked_in: 5,   # Worker arrived
    no_show: 6,      # Worker didn't show up
    completed: 7,    # Shift finished successfully
    cancelled: 8     # Assignment cancelled
  }

  # Critical: One worker per shift (prevents double-booking)
  validates :shift_id, uniqueness: { scope: :worker_profile_id }
end
```

**Why so many statuses?**
Each status represents a meaningful business state with different actions and implications:

```
offered ──accept──> accepted ──confirm──> confirmed ──check_in──> checked_in
   │                                                                    │
   ├─decline──> declined                                               │
   │                                                         check_out──┤
   └─timeout──> no_response                                            │
                                                                        ▼
   ┌────────────────────────────────────────────────────────────> completed
   │
   └─no_show──> no_show (penalizes worker)
```

---

## The Recruiting Algorithm: Our Secret Sauce

This is the most sophisticated part of ShiftReady. Let's understand how it works.

### The Problem

When a shift needs workers, we could just pick randomly. But that would be terrible:
- Workers 50 miles away get offers (they'll decline)
- Unreliable workers get offers (they'll no-show)
- Workers without relevant experience get offers (quality suffers)

**We need to rank workers and offer to the best matches first.**

### The Solution: Multi-Factor Scoring

Workers are scored on a **110-point scale** across 6 factors:

```ruby
# Scoring weights (110 points max)
DISTANCE_MAX_POINTS = 30      # Closest workers first
RELIABILITY_MAX_POINTS = 25   # Proven track record
JOB_TYPE_MAX_POINTS = 20      # Experience + preference
RATING_MAX_POINTS = 15        # Employer feedback
RESPONSE_TIME_MAX_POINTS = 10 # Fast responders
EXPERIENCE_MAX_POINTS = 10    # Number of completed shifts
```

### Factor 1: Distance (30 points) 📍

**Why it's weighted highest:**
- Workers are more likely to accept nearby shifts
- Reduces commute time and cost
- Improves worker satisfaction

**Implementation:**
```ruby
DISTANCE_TIERS = {
  (0..5)   => 30,  # Within 5 miles: EXCELLENT
  (5..10)  => 25,  # 5-10 miles: GOOD
  (10..15) => 20,  # 10-15 miles: OK
  (15..20) => 15,  # 15-20 miles: FAR
  (20..25) => 10   # 20-25 miles: VERY FAR
}.freeze

MAX_DISTANCE_MILES = 25  # Hard cutoff - exclude workers beyond this
```

**Distance calculation uses the Haversine formula:**
```ruby
def haversine_distance(lat1, lon1, lat2, lon2)
  rad_per_deg = Math::PI / 180
  earth_radius_miles = 3959.0

  dlat = (lat2 - lat1) * rad_per_deg
  dlon = (lon2 - lon1) * rad_per_deg

  a = Math.sin(dlat / 2)**2 +
      Math.cos(lat1 * rad_per_deg) * Math.cos(lat2 * rad_per_deg) *
      Math.sin(dlon / 2)**2

  c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

  earth_radius_miles * c
end
```

**Why Haversine?**
- Accounts for Earth's curvature (accurate)
- Fast to calculate (no external API)
- Good enough for 25-mile radius (no need for driving directions)

### Factor 2: Reliability (25 points)

**Why it matters:**
- Predicts future behavior
- Reduces no-shows (expensive for employers)
- Rewards good workers

**Implementation:**
```ruby
def score_reliability(worker)
  return 0 unless worker.reliability_score

  # Scale 0-100 reliability score to 0-25 points
  (worker.reliability_score / 100.0 * 25).round(2)
end
```

A worker with 100% reliability gets all 25 points. A worker with 50% reliability gets 12.5 points.

### Factor 3: Job Type Match (20 points)

**Scoring tiers:**
```ruby
if has_preference && completed_this_type
  20  # Perfect match: wants it AND has done it
elsif completed_this_type
  10  # Has experience but not preferred
elsif has_preference
  10  # Wants it but no experience
else
  5   # Neither (still eligible, just lower priority)
end
```

**Why this approach?**
- Preferences matter (worker satisfaction)
- Experience matters (quality)
- But we don't exclude workers completely (flexibility)

### Factor 4: Rating (15 points)

```ruby
def score_rating(worker)
  return 10 unless worker.average_rating  # Default for new workers

  # Scale 1-5 rating to 0-15 points
  ((worker.average_rating - 1) / 4.0 * 15).round(2)
end
```

**Rating scale:**
- 5.0 stars → 15 points
- 4.0 stars → 11.25 points
- 3.0 stars → 7.5 points (average)
- 2.0 stars → 3.75 points
- 1.0 stars → 0 points

**Why default to 10 points for new workers?**
- Gives them a chance (no reviews yet)
- Middle ground (not penalized, not favored)
- Adjusts as they get reviews

### Factor 5: Response Time (10 points)

```ruby
RESPONSE_TIME_TIERS = {
  (0..5)   => 10,  # Under 5 minutes: FAST
  (5..15)  => 8,   # 5-15 minutes: GOOD
  (15..30) => 5    # 15-30 minutes: OK
}.freeze
# >30 minutes = 2 points (SLOW)
```

**Why this matters:**
- Fast responders keep recruiting moving
- Slow responders delay filling shifts
- Incentivizes timely responses

### Factor 6: Experience (10 points)

```ruby
def score_experience(worker)
  completed_shifts = worker.total_shifts_completed || 0
  [completed_shifts * 0.5, 10].min.round(2)
end
```

**Scaling:**
- 0 shifts → 0 points (brand new)
- 10 shifts → 5 points (some experience)
- 20+ shifts → 10 points (veteran, capped)

**Why cap at 20 shifts?**
- Diminishing returns (20 shifts vs 100 shifts doesn't matter much)
- Prevents veterans from dominating completely
- Gives newer workers a chance

### Putting It All Together

Here's what a scored worker looks like:

```ruby
{
  worker: #<WorkerProfile id: 42>,
  score: 87.5,
  distance_miles: 3.2,
  score_breakdown: {
    distance: 30.0,        # Very close!
    reliability: 22.5,     # 90% reliability score
    job_type: 20.0,        # Perfect match
    rating: 11.25,         # 4.0 stars
    response_time: 8.0,    # Usually responds in 7 minutes
    experience: 5.0        # 10 completed shifts
  }
}
```

### The Ranking Process

```ruby
# 1. Start with ALL workers
base_query = WorkerProfile.active.onboarded

# 2. Filter to eligible workers
eligible = base_query
  .with_job_type_preference(shift.job_type)  # Must want this type of work
  .with_coordinates                          # Must have geocoded address
  .not_blocked_by_company(shift.company)     # Not blocked by employer
  .available_at(shift.start_datetime)        # Free at this time
  .select { |w| within_max_distance?(w) }    # Within 25 miles

# 3. Score each eligible worker
scored = eligible.map { |worker| score_worker(worker) }

# 4. Sort by score descending (highest first)
ranked = scored.sort_by { |result| -result[:score] }

# 5. Offer to the top worker
best_worker = ranked.first
```

### Why Sequential Offers?

**We offer to ONE worker at a time, not all at once.**

**Alternative approach (parallel offers):**
```ruby
# DON'T DO THIS
top_10_workers.each do |worker|
  send_offer_sms(worker, shift)  # Send to all 10 simultaneously
end
```

**Problems:**
- Worker might accept multiple offers (double-booked)
- Workers feel like "just another option" (bad UX)
- Lots of wasted offers (9 workers declined for nothing)

**Our approach (sequential offers):**
```ruby
# Offer to #1
if accepted
  fill slot, done!
else
  # Offer to #2
  if accepted
    fill slot, done!
  else
    # Offer to #3
    # ... and so on
  end
end
```

**Benefits:**
- No double-booking
- Workers feel valued (exclusive offer)
- Fewer wasted SMS messages
- Better worker experience

**Trade-off:**
- Slower to fill (sequential vs parallel)
- But worth it for quality and UX

### Timeout Handling

What if a worker doesn't respond?

```ruby
# When offer is sent
ShiftOfferService.create_next_offer(shift)
# → Creates ShiftAssignment with status: offered
# → Sends SMS to worker
# → Schedules CheckOfferTimeoutJob to run in 15 minutes

# 15 minutes later
CheckOfferTimeoutJob.perform(assignment.id)
# → Checks if still in "offered" status
# → If yes: mark as "no_response" and offer to next worker
# → If no: worker already responded, do nothing
```

**Why 15 minutes?**
- Long enough for worker to see/respond
- Short enough to fill shifts quickly
- Can be adjusted based on urgency

---

## Smart Infrastructure: Geocoding and Phone Normalization

Let's talk about two features that seem simple but have significant impact.

### Geocoding: Why and How

**The problem:**
- Users type addresses as freeform text
- "123 Main St" could be anywhere
- We need lat/lng coordinates for distance calculations

**Naive approach:**
```ruby
# DON'T DO THIS
def create
  worker = WorkerProfile.new(params)

  # Geocode during the request (SLOW!)
  response = geocoding_api.geocode(worker.full_address)
  worker.latitude = response[:lat]
  worker.longitude = response[:lng]

  worker.save  # User waits for API call... 😴
end
```

**Problems:**
- API call delays response (bad UX)
- API might fail (breaks the request)
- API might be slow (timeout issues)

**Our approach: Async geocoding**

```ruby
# app/models/concerns/geocodable.rb
module Geocodable
  extend ActiveSupport::Concern

  included do
    # After record is saved to database
    after_commit :enqueue_geocoding_job, if: :should_geocode?
  end

  private

  def should_geocode?
    # Only geocode if:
    # 1. Record is valid (no validation errors)
    # 2. Address changed (not every update)
    saved_change_to_address_line_1? || saved_change_to_city? ||
    saved_change_to_state? || saved_change_to_zip_code?
  end

  def enqueue_geocoding_job
    # Async job, doesn't block the request
    GeocodeAddressJob.perform_later(self.class.name, self.id)
  end
end
```

**The background job:**
```ruby
class GeocodeAddressJob < ApplicationJob
  def perform(model_class, record_id)
    record = model_class.constantize.find_by(id: record_id)
    return unless record  # Handle deleted records gracefully

    # Call the geocoding service
    result = GeocodingService.geocode(record.full_address)

    # Update coordinates
    record.update_columns(
      latitude: result[:latitude],
      longitude: result[:longitude]
      # Use update_columns to skip validations and callbacks
    )
  end
end
```

**Why `update_columns`?**
- Skips validations (we already validated)
- Skips callbacks (prevents infinite loop)
- Directly updates database (fast)

**The geocoding service:**
```ruby
class GeocodingService
  API_URL = 'https://api.geocod.io/v1.7/geocode'

  def self.geocode(address)
    # Call Geocodio API
    response = HTTParty.get(API_URL, query: {
      q: address,
      api_key: ENV['GEOCODIO_API_KEY']
    })

    result = response['results'].first

    {
      latitude: result['location']['lat'],
      longitude: result['location']['lng'],
      # Bonus: get normalized address back
      formatted_address: result['formatted_address']
    }
  end
end
```

**Benefits of this approach:**
- Fast API responses (geocoding happens in background)
- Resilient to failures (retry jobs automatically)
- Clean separation of concerns
- Reusable across models

**Models using geocoding:**
- `WorkerProfile` (home address)
- `WorkLocation` (work site address)
- `Company` (billing address, with `billing_` prefix)

### Phone Normalization: The Hidden Complexity

**The problem:**
Users enter phone numbers in many formats:
```
(210) 555-0123
210-555-0123
210.555.0123
2105550123
12105550123
+12105550123
```

**All of these are the same number!**

**Why this matters:**
1. **Uniqueness constraints**: We want one account per phone number
2. **SMS routing**: Twilio expects E.164 format (`+12105550123`)
3. **Display formatting**: Users expect `(210) 555-0123` format

**Our solution:**

```ruby
# app/models/concerns/phone_normalizable.rb
module PhoneNormalizable
  extend ActiveSupport::Concern

  included do
    # Normalize BEFORE validation
    before_validation :normalize_phone_fields
  end

  private

  def normalize_phone_fields
    # For each phone field (phone, mobile, from_phone, to_phone, etc.)
    self.class.phone_fields_to_normalize.each do |field|
      value = send(field)
      next if value.blank?

      # Normalize using service
      normalized = PhoneNormalizationService.normalize(value)
      send("#{field}=", normalized) if normalized
    end
  end
end
```

**The normalization service:**
```ruby
class PhoneNormalizationService
  def self.normalize(phone)
    return nil if phone.blank?

    # Remove all non-digit characters
    digits = phone.gsub(/\D/, '')

    # Handle different formats
    case digits.length
    when 10
      "+1#{digits}"  # Add US country code
    when 11
      digits.start_with?('1') ? "+#{digits}" : nil
    when 12
      digits.start_with?('1') ? "+#{digits.slice(1..-1)}" : nil
    else
      nil  # Invalid length, return nil (let validation catch it)
    end
  end

  def self.format_display(phone)
    return phone if phone.blank?

    # Convert +12105550123 → (210) 555-0123
    digits = phone.gsub(/\D/, '')
    return phone if digits.length != 11

    "(#{digits[1..3]}) #{digits[4..6]}-#{digits[7..10]}"
  end
end
```

**Using it in models:**
```ruby
class WorkerProfile < ApplicationRecord
  include PhoneNormalizable

  validates :phone, presence: true, uniqueness: true

  # Display method for API responses
  def phone_display
    PhoneNormalizationService.format_display(phone)
  end
end
```

**The flow:**
```
User enters: "(210) 555-0123"
      ↓
before_validation callback fires
      ↓
PhoneNormalizationService.normalize
      ↓
Stored as: "+12105550123"
      ↓
validates :phone, uniqueness: true  ← Works correctly now!
      ↓
API response includes: phone_display
      ↓
User sees: "(210) 555-0123"
```

**Why normalize BEFORE validation?**
```ruby
# If we normalized AFTER validation:
worker1 = WorkerProfile.create!(phone: "(210) 555-0123")
# Stored as: "(210) 555-0123"

worker2 = WorkerProfile.create!(phone: "2105550123")
# Stored as: "2105550123"

# Uniqueness validation doesn't catch it! 😱
# Two accounts with the same phone number!

# With normalization BEFORE validation:
worker1 = WorkerProfile.create!(phone: "(210) 555-0123")
# before_validation: normalizes to "+12105550123"
# validates uniqueness on "+12105550123" ✅

worker2 = WorkerProfile.create!(phone: "2105550123")
# before_validation: normalizes to "+12105550123"
# validates uniqueness on "+12105550123" ❌ Duplicate!
```

---

## State Machines: Managing Complexity with Elegance

State machines are one of the most powerful patterns in Rails. Let's see how we use them.

### The Shift Lifecycle

A shift goes through these states:

```
    ┌──────┐
    │draft │ ← Being created
    └───┬──┘
        │ publish!
        ▼
    ┌──────┐
    │posted│ ← Visible to workers, not actively recruiting
    └───┬──┘
        │ start_recruiting!
        ▼
  ┌──────────┐
  │recruiting│ ◄──┐ Actively sending offers
  └────┬─────┘    │
       │          │ can_resume_recruiting? (if cancelled)
       │ fully_filled?
       ▼          │
   ┌──────┐       │
   │filled│ ──────┘
   └───┬──┘
       │ shift starts
       ▼
┌────────────┐
│in_progress │ ← Shift is happening now
└──────┬─────┘
       │ shift ends
       ▼
  ┌─────────┐
  │completed│ ← All done!
  └─────────┘

  (cancel! at any time)
       ↓
  ┌─────────┐
  │cancelled│
  └─────────┘
```

**Implementation:**
```ruby
class Shift < ApplicationRecord
  enum :status, {
    draft: 0,
    posted: 1,
    recruiting: 2,
    filled: 3,
    in_progress: 4,
    completed: 5,
    cancelled: 6
  }

  # State transition methods
  def start_recruiting!
    return false unless can_start_recruiting?

    update!(
      status: :recruiting,
      recruiting_started_at: Time.current
    )
  end

  def can_start_recruiting?
    posted? && !fully_filled? && upcoming?
  end

  def mark_as_filled!
    return false unless fully_filled?

    update!(
      status: :filled,
      filled_at: Time.current
    )
  end

  # Automatically check if filled after updates
  after_update :check_if_filled

  def check_if_filled
    if slots_filled >= slots_total && (recruiting? || posted?)
      mark_as_filled!
    end
  end
end
```

**Why explicit transition methods?**
- **Clarity**: `shift.start_recruiting!` is clearer than `shift.update(status: :recruiting)`
- **Validation**: Can check preconditions before transitioning
- **Side effects**: Can trigger other actions (logs, jobs, notifications)
- **Immutability**: Can prevent invalid transitions

### The ShiftAssignment Lifecycle

Even more complex - assignments have many states:

```
  ┌───────┐
  │offered│ ← Offer sent to worker
  └───┬───┘
      │
      ├─ accept! ──────────┐
      │                    ▼
      │               ┌────────┐
      │               │accepted│
      │               └───┬────┘
      │                   │ confirm!
      │                   ▼
      │              ┌─────────┐
      │              │confirmed│
      │              └────┬────┘
      │                   │ check_in!
      │                   ▼
      │              ┌──────────┐
      │              │checked_in│
      │              └─────┬────┘
      │                    │ check_out!
      │                    ▼
      │              ┌──────────┐
      │              │ (awaiting│
      │              │ approval)│
      │              └─────┬────┘
      │                    │ mark_complete!
      │                    ▼
      │               ┌─────────┐
      │               │completed│ 🎉
      │               └─────────┘
      │
      ├─ decline! ──> declined
      │
      └─ timeout ──> no_response

      mark_no_show! ──> no_show (penalizes worker)

      cancel! ──> cancelled (any time before completed)
```

**Key transitions:**

```ruby
class ShiftAssignment < ApplicationRecord
  # Accept an offer
  def accept!(method: :sms)
    return false unless offered?

    transaction do
      update!(
        status: :accepted,
        accepted_at: Time.current,
        response_received_at: Time.current,
        response_method: method,
        response_value: :accepted
      )
      # Side effect: increment slot count
      shift.increment!(:slots_filled)
    end
  end

  # Check in to shift
  def check_in!(time = Time.current)
    return false unless can_check_in?

    update!(
      status: :checked_in,
      checked_in_at: time,
      actual_start_time: time
    )
  end

  def can_check_in?
    # Can only check in if accepted/confirmed and shift has started
    (accepted? || confirmed?) && shift.start_datetime <= Time.current
  end

  # Mark as no-show (penalties!)
  def mark_no_show!
    return false unless [offered?, accepted?, confirmed?].any?

    was_accepted_or_confirmed = accepted? || confirmed?

    transaction do
      update!(
        status: :no_show,
        no_show: true,
        completed_successfully: false
      )
      # Side effects:
      worker_profile.increment!(:no_show_count)  # Penalize
      shift.decrement!(:slots_filled) if was_accepted_or_confirmed
    end
  end

  # Automatic worker stats updates
  after_update :update_worker_stats, if: :saved_change_to_status?

  def update_worker_stats
    case status
    when 'completed'
      worker_profile.increment!(:total_shifts_completed)
      worker_profile.update_reliability_score!
    when 'no_show'
      worker_profile.update_reliability_score!  # Recalculate (went down)
    end
  end
end
```

**Why so many statuses?**

Each status has business meaning:
- `offered`: SMS sent, waiting for response
- `accepted`: Worker said yes, slot is reserved
- `confirmed`: Employer verified (optional step)
- `checked_in`: Worker arrived, shift is happening
- `no_show`: Worker didn't show (impacts reliability score)
- `completed`: Successfully finished (increments counters)
- `cancelled`: Someone cancelled (need to know who)

**The benefits:**
- **Clarity**: Status tells you exactly what happened
- **Analytics**: Can query "how many no-shows this month?"
- **Automation**: Different statuses trigger different side effects
- **Auditing**: State changes are tracked in database

---

## The Service Layer: Organizing Business Logic

Rails is opinionated: "fat models, skinny controllers". But sometimes models get TOO fat. Services help.

### When to Use a Service Object

**Use a service when:**
- Logic involves multiple models
- Logic calls external APIs
- Logic is complex and worth testing in isolation
- Logic represents a "business process" rather than a model concern

**Don't use a service for:**
- Simple CRUD operations
- Single-model calculations
- Validations (those belong in models)

### Example: ShiftOfferService

This service orchestrates the entire offer workflow:

```ruby
class ShiftOfferService
  # Create and send the next offer
  def self.create_next_offer(shift)
    # 1. Validate shift state
    return failure("Shift not recruiting") unless shift.recruiting?
    return failure("Shift fully filled") if shift.fully_filled?

    # 2. Check for existing pending offers
    pending = shift.shift_assignments.pending_response
    return failure("Pending offer exists") if pending.exists?

    # 3. Find next best worker
    algorithm = RecruitingAlgorithmService.new(shift)
    best = algorithm.next_best_worker
    return failure("No eligible workers") unless best

    # 4. Create assignment
    assignment = shift.shift_assignments.create!(
      worker_profile: best[:worker],
      status: :offered,
      assigned_by: :algorithm,
      algorithm_score: best[:score],
      distance_miles: best[:distance_miles],
      sms_sent_at: Time.current
    )

    # 5. Schedule timeout check
    CheckOfferTimeoutJob.set(wait: 15.minutes).perform_later(assignment.id)

    # 6. Log activity
    RecruitingActivityLog.log_offer_sent(
      shift: shift,
      worker: best[:worker],
      assignment: assignment,
      score: best[:score]
    )

    # 7. TODO: Send SMS
    # SmsService.send_shift_offer(worker, shift)

    success(assignment)
  end

  # Handle worker acceptance
  def self.handle_acceptance(assignment)
    assignment.accept!

    RecruitingActivityLog.log_offer_accepted(
      shift: assignment.shift,
      worker: assignment.worker_profile,
      assignment: assignment
    )

    # Continue recruiting if not fully filled
    shift = assignment.shift
    if shift.reload.recruiting? && !shift.fully_filled?
      ProcessShiftRecruitingJob.perform_later(shift.id)
    end

    success(assignment)
  end

  # Handle worker decline
  def self.handle_decline(assignment, reason = nil)
    assignment.decline!(reason)

    RecruitingActivityLog.log_offer_declined(
      shift: assignment.shift,
      worker: assignment.worker_profile,
      assignment: assignment,
      reason: reason
    )

    # Immediately offer to next worker
    ProcessShiftRecruitingJob.perform_later(assignment.shift.id)

    success(assignment)
  end

  # Handle timeout (no response)
  def self.handle_timeout(assignment)
    return unless assignment.offered?  # Worker might have responded

    assignment.mark_no_response!

    RecruitingActivityLog.log_offer_timeout(
      shift: assignment.shift,
      worker: assignment.worker_profile,
      assignment: assignment
    )

    # Offer to next worker
    ProcessShiftRecruitingJob.perform_later(assignment.shift.id)

    success(assignment)
  end

  private

  def self.success(data)
    { success: true, data: data }
  end

  def self.failure(message)
    { success: false, error: message }
  end
end
```

**Why this is a service:**
- Involves 4 models (Shift, ShiftAssignment, WorkerProfile, RecruitingActivityLog)
- Calls external service (SMS, commented out)
- Enqueues background job
- Complex orchestration logic
- Returns structured result (success/failure)

**Benefits:**
- **Testable**: Can test offer logic in isolation
- **Reusable**: Controllers and jobs call the same service
- **Organized**: One place for offer logic
- **Readable**: Clear method names express intent

---

## Background Jobs: Async Processing Done Right

Background jobs are crucial for ShiftReady's architecture. Let's see how they work.

### Why Background Jobs?

**Synchronous (bad):**
```ruby
def create_next_offer
  # 1. Query database (100ms)
  # 2. Calculate scores (200ms)
  # 3. Create assignment (50ms)
  # 4. Send SMS via Twilio (500ms) 😱
  # 5. Log activity (50ms)

  # Total: 900ms response time!
end
```

**Asynchronous (good):**
```ruby
def create_next_offer
  # 1. Query database (100ms)
  # 2. Create assignment (50ms)
  # 3. Enqueue job (10ms) ← Returns immediately

  # Total: 160ms response time! 🎉
  # SMS sent in background
end
```

### Rails 8: Solid Queue

ShiftReady uses **Solid Queue**, a new Rails 8 feature:
- Database-backed (no Redis needed)
- Simple deployment (no extra process to manage)
- Persistent (jobs survive server restarts)
- Built-in retries and error handling

### Key Background Jobs

#### 1. GeocodeAddressJob
```ruby
class GeocodeAddressJob < ApplicationJob
  queue_as :default

  def perform(model_class, record_id)
    record = model_class.constantize.find_by(id: record_id)
    return unless record  # Gracefully handle deletions

    # Call geocoding API
    record.send(:geocode_address)
  end
end
```

**When it runs:**
- After worker/location/company created or updated
- Only if address fields changed

**Why async:**
- API calls are slow (300-500ms)
- API might fail (retry automatically)
- Not critical for immediate response

#### 2. ProcessShiftRecruitingJob
```ruby
class ProcessShiftRecruitingJob < ApplicationJob
  queue_as :recruiting

  def perform(shift_id)
    shift = Shift.find_by(id: shift_id)
    return unless shift&.recruiting?

    # Check if filled
    if shift.fully_filled?
      shift.mark_as_filled!
      return
    end

    # Lock the shift to prevent race conditions
    shift.with_lock do
      # Check for pending offers
      pending = shift.shift_assignments.pending_response
      return if pending.exists?

      # Create next offer
      result = ShiftOfferService.create_next_offer(shift)

      # Log result
      if result[:success]
        RecruitingActivityLog.log_offer_sent(...)
      else
        RecruitingActivityLog.log_recruiting_paused(...)
      end
    end
  end
end
```

**When it runs:**
- When shift starts recruiting
- After worker declines offer
- After offer timeout
- After assignment cancelled

**Why async:**
- Might take several seconds (algorithm calculations)
- Can be retried if fails
- Doesn't block user request

**Why database lock (`with_lock`)?**
```ruby
# Without lock (race condition):
Job 1: Check pending offers → none found
Job 2: Check pending offers → none found (happens simultaneously!)
Job 1: Create offer to worker A
Job 2: Create offer to worker B
# Result: Two offers sent simultaneously! 😱

# With lock:
Job 1: Acquire lock, check pending → none found
Job 2: Wait for lock...
Job 1: Create offer to worker A, release lock
Job 2: Acquire lock, check pending → found worker A offer, exit
# Result: Only one offer sent! ✅
```

#### 3. CheckOfferTimeoutJob
```ruby
class CheckOfferTimeoutJob < ApplicationJob
  queue_as :recruiting

  def perform(assignment_id)
    assignment = ShiftAssignment.find_by(id: assignment_id)
    return unless assignment

    # Only process if still in offered status
    # (worker might have responded in the meantime)
    return unless assignment.offered?

    # Handle timeout
    ShiftOfferService.handle_timeout(assignment)
  end
end
```

**When it runs:**
- Scheduled 15 minutes after offer sent

**Why scheduled:**
- Give worker time to respond
- Then automatically move to next worker
- Keeps recruiting moving without manual intervention

**How to schedule:**
```ruby
# When offer is created
CheckOfferTimeoutJob.set(wait: 15.minutes).perform_later(assignment.id)

# Solid Queue handles:
# - Storing the job
# - Waiting 15 minutes
# - Running the job
# - Retrying if it fails
```

---

## Testing Philosophy: Building with Confidence

Let's talk about how we test this application.

### Testing Pyramid

```
         ┌────────────────┐
         │   Integration  │  Few, slow, high-value
         │     Tests      │  (Controller tests)
         └────────────────┘
       ┌──────────────────────┐
       │    Service Tests     │  Some, fast, business logic
       │  (Algorithm, Offer)  │
       └──────────────────────┘
    ┌────────────────────────────┐
    │      Model Tests           │  Many, very fast, comprehensive
    │ (Validations, Associations)│
    └────────────────────────────┘
```

### Example: Testing the Recruiting Algorithm

The algorithm has a **347-line test file**. Let's look at some examples:

#### Testing Distance Scoring
```ruby
test 'scores distance in tiers correctly' do
  shift = create(:shift, :recruiting)

  # Worker 3 miles away
  worker_3mi = create_eligible_worker(shift, distance: 3)
  result = service.score_worker(worker_3mi)
  assert_equal 30, result[:score_breakdown][:distance]  # Max points

  # Worker 7 miles away
  worker_7mi = create_eligible_worker(shift, distance: 7)
  result = service.score_worker(worker_7mi)
  assert_equal 25, result[:score_breakdown][:distance]  # Second tier

  # Worker 30 miles away
  worker_30mi = create_eligible_worker(shift, distance: 30)
  eligible = service.eligible_workers
  refute_includes eligible, worker_30mi  # Excluded!
end
```

#### Testing Eligibility Filtering
```ruby
test 'excludes workers without job type preference' do
  shift = create(:shift, :recruiting, job_type: 'warehouse')

  # Worker with warehouse preference
  warehouse_worker = create(:worker_profile, :onboarded)
  create(:worker_preferred_job_type,
    worker_profile: warehouse_worker,
    job_type: 'warehouse'
  )

  # Worker with retail preference (no warehouse)
  retail_worker = create(:worker_profile, :onboarded)
  create(:worker_preferred_job_type,
    worker_profile: retail_worker,
    job_type: 'retail'
  )

  eligible = service.eligible_workers

  assert_includes eligible, warehouse_worker
  refute_includes eligible, retail_worker
end
```

#### Testing Blocked Workers
```ruby
test 'excludes workers blocked by company' do
  shift = create(:shift, :recruiting)
  worker = create_eligible_worker(shift)

  # Company blocks worker
  create(:block_list,
    blocker: shift.company,
    blocked: worker
  )

  eligible = service.eligible_workers
  refute_includes eligible, worker
end

test 'excludes companies blocked by worker' do
  shift = create(:shift, :recruiting)
  worker = create_eligible_worker(shift)

  # Worker blocks company (bidirectional!)
  create(:block_list,
    blocker: worker,
    blocked: shift.company
  )

  eligible = service.eligible_workers
  refute_includes eligible, worker
end
```

### Example: Testing Phone Normalization

```ruby
test 'normalizes phone on save' do
  worker = WorkerProfile.new(phone: '(210) 555-0123')
  worker.save

  # Stored in E.164 format
  assert_equal '+12105550123', worker.reload.phone
end

test 'prevents duplicate phone numbers with different formats' do
  create(:worker_profile, phone: '(210) 555-0123')

  # Try to create another with same number, different format
  duplicate = WorkerProfile.new(phone: '2105550123')

  refute duplicate.valid?
  assert_includes duplicate.errors[:phone], 'has already been taken'
end

test 'handles various phone formats' do
  formats = [
    '(210) 555-0123',
    '210-555-0123',
    '210.555.0123',
    '2105550123',
    '12105550123',
    '+12105550123'
  ]

  formats.each do |format|
    normalized = PhoneNormalizationService.normalize(format)
    assert_equal '+12105550123', normalized,
      "Failed to normalize #{format}"
  end
end
```

### Testing Best Practices

**1. Use factories, not fixtures**
```ruby
# Good: Flexible, explicit
worker = create(:worker_profile,
  first_name: 'Jane',
  reliability_score: 95.0
)

# Bad: Brittle, implicit
worker = worker_profiles(:jane)  # What are Jane's attributes? 🤷
```

**2. Test one thing per test**
```ruby
# Good: Clear failure message
test 'reliability score affects ranking' do
  high_reliability = create_worker(reliability_score: 90)
  low_reliability = create_worker(reliability_score: 50)

  ranked = service.ranked_eligible_workers

  assert ranked[0][:worker] == high_reliability
end

# Bad: Multiple assertions (which one failed?)
test 'algorithm works' do
  # 50 lines of setup
  # 20 assertions
  # If one fails, good luck debugging!
end
```

**3. Use helper methods to reduce duplication**
```ruby
def create_eligible_worker(shift, **options)
  worker = create(:worker_profile, :onboarded, **options)
  create(:worker_preferred_job_type,
    worker_profile: worker,
    job_type: shift.job_type
  )
  # Set coordinates, availability, etc.
  worker
end

# Now tests are readable:
test 'ranks by distance' do
  close_worker = create_eligible_worker(shift, distance: 5)
  far_worker = create_eligible_worker(shift, distance: 20)

  ranked = service.ranked_eligible_workers
  assert_equal close_worker, ranked[0][:worker]
end
```

---

## Architectural Decisions: Trade-offs and Why We Made Them

Every architectural decision involves trade-offs. Let's discuss the big ones.

### Decision 1: API-Only Rails Backend + Separate Frontend

**What we chose:**
- Rails API-only mode (no views, no asset pipeline)
- Next.js frontend as separate application
- JWT authentication (stateless)

**Alternatives considered:**
- Monolith: Rails with views (traditional)
- GraphQL instead of REST

**Trade-offs:**

✅ **Pros:**
- Frontend team can work independently
- Can build mobile app later (reuse API)
- Modern React development experience
- Easier to scale independently

❌ **Cons:**
- More complex deployment (two apps)
- CORS configuration required
- Can't use Turbo/Hotwire (Rails features)
- More boilerplate (two codebases)

**Why we chose this:**
- Flexibility for future (mobile app planned)
- Easier to hire specialists (Rails devs, React devs)
- Modern UX expectations (SPA)

### Decision 2: Sequential Recruiting Instead of Parallel

**What we chose:**
- Send one offer at a time
- Wait for response or timeout
- Then offer to next worker

**Alternative:**
- Send offers to top 10 workers simultaneously
- First to respond gets the shift

**Trade-offs:**

✅ **Pros:**
- Better worker experience (exclusive offer)
- No double-booking issues
- Fewer wasted SMS messages
- Workers feel valued, not spammed

❌ **Cons:**
- Slower to fill shifts (serial vs parallel)
- If first worker declines, have to wait 15 minutes
- More complex state management

**Why we chose this:**
- Worker satisfaction matters (retention)
- Quality over speed (better matches)
- Can adjust timeout if too slow

### Decision 3: Async Geocoding Instead of Sync

**What we chose:**
- Geocode in background job after record saved
- Records initially have nil lat/lng
- Updated asynchronously (usually <1 second)

**Alternative:**
- Geocode during the request before save
- Record always has lat/lng immediately

**Trade-offs:**

✅ **Pros:**
- Fast API responses (<100ms)
- Resilient to geocoding API failures
- Automatic retries if API is down
- Doesn't block user registration

❌ **Cons:**
- Worker might not appear in search immediately
- Requires handling nil coordinates
- More complex (jobs, callbacks)

**Why we chose this:**
- UX: Fast responses matter more than instant geocoding
- Reliability: API failures don't break registration
- Geocodio is usually fast (<1 second), so delay is minimal

### Decision 4: E.164 Phone Format in Database

**What we chose:**
- Store: `+12105550123` (E.164 format)
- Display: `(210) 555-0123` (formatted)
- Normalize before validation

**Alternative:**
- Store: `(210) 555-0123` (user format)
- Normalize only when sending SMS

**Trade-offs:**

✅ **Pros:**
- Uniqueness constraints work correctly
- Ready for SMS without transformation
- International format (future expansion)
- Consistent data (one source of truth)

❌ **Cons:**
- Extra step on display (format for humans)
- Might confuse developers (stored value ≠ user input)
- Normalization logic required

**Why we chose this:**
- Data integrity (no duplicate accounts)
- SMS integration (Twilio expects E.164)
- Scalability (ready for international)

### Decision 5: Solid Queue Instead of Sidekiq

**What we chose:**
- Solid Queue (database-backed)
- No Redis required
- Rails 8 native feature

**Alternative:**
- Sidekiq (Redis-backed)
- Industry standard, battle-tested

**Trade-offs:**

✅ **Pros:**
- Simpler deployment (one less service)
- Cheaper hosting (no Redis server)
- Persistent by default (survives restarts)
- Native Rails integration

❌ **Cons:**
- Less mature (new in Rails 8)
- Potentially slower (database vs in-memory)
- Fewer ecosystem tools

**Why we chose this:**
- Simplicity (fewer moving parts)
- Cost (bootstrapped startup)
- Good enough for our scale (<1000 jobs/min)
- Can switch to Sidekiq later if needed

### Decision 6: JSONB for RecruitingActivityLog Details

**What we chose:**
- `details` column as JSONB (PostgreSQL)
- Flexible schema, can store any data
- GIN index for fast querying

**Alternative:**
- Separate columns for each attribute
- Strict schema, typed columns

**Trade-offs:**

✅ **Pros:**
- Flexible: Can add new fields without migration
- Convenient: Entire context in one column
- Queryable: GIN index allows JSON queries

❌ **Cons:**
- No validation: Can store invalid data
- No type safety: Everything is JSON
- Harder to query: Need to know JSON structure

**Why we chose this:**
- Activity logs are for debugging/audit (not business logic)
- Different actions need different data (flexible schema)
- PostgreSQL JSONB is powerful and performant

---

## Lessons Learned and Anti-Patterns We Avoided

### What Went Well

#### 1. Test-Driven Development

**We wrote tests BEFORE building features.**

Example: The recruiting algorithm test suite (347 lines) was written alongside the implementation. This caught bugs early:

```ruby
# Bug caught by test:
test 'excludes workers already offered this shift' do
  worker = create_eligible_worker(shift)

  # Offer already sent
  create(:shift_assignment, shift: shift, worker_profile: worker, status: :declined)

  # Should NOT offer again
  next_best = service.next_best_worker
  refute_equal worker, next_best&.[](:worker)
end

# This test FAILED initially - we forgot to filter already-offered workers!
# Fixed before deploying to production.
```

**Lesson:** Tests provide confidence. Refactor fearlessly.

#### 2. Small, Focused Commits

Look at the git history - each commit does ONE thing:
- "Adds phone normalization"
- "Addresses PR feedback"
- "Adds initial async recruiting algorithm"

**Benefits:**
- Easy to review
- Easy to revert if needed
- Easy to understand history

#### 3. Concerns for Shared Behavior

Instead of this (DRY violation):
```ruby
# In WorkerProfile
before_validation :normalize_phone
def normalize_phone
  self.phone = PhoneNormalizationService.normalize(phone)
end

# In EmployerProfile
before_validation :normalize_phone  # Copy-pasted! 😱
def normalize_phone
  self.phone = PhoneNormalizationService.normalize(phone)
end

# In Message
before_validation :normalize_phones  # More copy-paste!
def normalize_phones
  self.from_phone = PhoneNormalizationService.normalize(from_phone)
  self.to_phone = PhoneNormalizationService.normalize(to_phone)
end
```

We extracted a concern:
```ruby
module PhoneNormalizable
  extend ActiveSupport::Concern

  included do
    before_validation :normalize_phone_fields
  end

  # One implementation, many models
end

# Now just:
class WorkerProfile < ApplicationRecord
  include PhoneNormalizable
end

class EmployerProfile < ApplicationRecord
  include PhoneNormalizable
end
```

**Lesson:** If you copy-paste code more than twice, extract it.

### Anti-Patterns We Avoided

#### 1. Fat Controllers

**Don't do this:**
```ruby
class ShiftsController < ApplicationController
  def start_recruiting
    shift = Shift.find(params[:id])

    # 100 lines of business logic in the controller! 😱
    if shift.recruiting? || shift.fully_filled?
      render json: { error: 'Cannot start recruiting' }, status: :unprocessable_entity
      return
    end

    # Calculate eligible workers
    workers = WorkerProfile.active.onboarded.where(...)
    # Score workers
    scored = workers.map { |w| ... }
    # Create assignment
    assignment = ShiftAssignment.create!(...)
    # Send SMS
    # Log activity
    # ...
  end
end
```

**Instead, we did this:**
```ruby
class ShiftsController < ApplicationController
  def start_recruiting
    shift = Shift.find(params[:id])

    # Delegate to service
    result = ShiftOfferService.create_next_offer(shift)

    if result[:success]
      render json: { assignment: result[:data] }
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end
end
```

**Lesson:** Controllers should coordinate, not calculate.

#### 2. God Objects (Models That Do Everything)

We could have put everything in `Shift`:
```ruby
class Shift < ApplicationRecord
  # 1000 lines of code

  def geocode_location
    # Geocoding logic
  end

  def find_eligible_workers
    # Algorithm logic
  end

  def score_worker(worker)
    # Scoring logic
  end

  def send_offer(worker)
    # SMS logic
  end

  # ... 50 more methods
end
```

**Instead, we separated concerns:**
- `Shift` model: Shift-specific logic (state, validations)
- `GeocodingService`: Geocoding logic
- `RecruitingAlgorithmService`: Worker scoring
- `ShiftOfferService`: Offer orchestration
- `SmsService`: SMS sending (not implemented yet)

**Lesson:** Single Responsibility Principle. One class, one job.

#### 3. N+1 Queries

**The problem:**
```ruby
# Controller
shifts = Shift.recruiting.limit(10)

# View/API serialization
shifts.each do |shift|
  shift.company.name           # Query 1
  shift.work_location.address  # Query 2
  shift.workers.count          # Query 3
end

# Total: 1 + (10 × 3) = 31 queries! 😱
```

**Our solution:**
```ruby
# In controller
shifts = Shift.recruiting
             .includes(:company, :work_location, :workers)
             .limit(10)

# Same iteration
shifts.each do |shift|
  shift.company.name           # No query (preloaded)
  shift.work_location.address  # No query (preloaded)
  shift.workers.count          # No query (preloaded)
end

# Total: 4 queries (Shift, Company, WorkLocation, Workers)
```

**Lesson:** Always check your query count. Use `includes` for associations.

#### 4. Callbacks That Do Too Much

**Don't do this:**
```ruby
class ShiftAssignment < ApplicationRecord
  after_save :do_everything

  def do_everything
    # Send email
    # Update 5 different models
    # Call external API
    # Enqueue jobs
    # Log to 3 different places
    # ...
  end
end

# Now every save is slow and fragile! 😱
```

**We kept callbacks focused:**
```ruby
class ShiftAssignment < ApplicationRecord
  # Simple, specific callbacks
  after_update :update_worker_stats, if: :saved_change_to_status?
  after_commit :trigger_resume_recruiting, if: :just_cancelled_and_can_resume_recruiting?

  # Each callback does ONE thing
end
```

**Lesson:** Callbacks should be fast, focused, and have clear conditions.

---

## Next Steps: Where You Can Take This

This codebase is production-ready but not complete. Here are exciting areas to expand:

### 1. SMS Integration (High Priority) 📱

**Current state:** Commented out in code
**Implementation needed:**
```ruby
# app/services/sms_service.rb
class SmsService
  def self.send_shift_offer(worker, shift)
    client = Twilio::REST::Client.new(
      ENV['TWILIO_ACCOUNT_SID'],
      ENV['TWILIO_AUTH_TOKEN']
    )

    message = <<~SMS
      ShiftReady: #{shift.title}
      #{shift.formatted_datetime_range}
      #{shift.formatted_pay_rate}

      Reply YES to accept, NO to decline
      Track: #{shift.tracking_code}
    SMS

    client.messages.create(
      from: ENV['TWILIO_PHONE_NUMBER'],
      to: worker.phone,  # Already in E.164 format!
      body: message
    )
  end

  def self.handle_incoming_sms(from_phone, body)
    # Parse response (YES/NO)
    # Find pending offer
    # Accept or decline
  end
end
```

**Challenges:**
- Twilio webhook handling
- SMS reply parsing (fuzzy matching)
- Rate limiting (avoid spam)
- Cost management

**Learning opportunity:**
- External API integration
- Webhook security
- Async communication

### 2. Payment Processing (High Priority) 💰

**Current state:** Payment model exists, but no Stripe integration

**Implementation needed:**
```ruby
# app/services/payment_processor_service.rb
class PaymentProcessorService
  def self.process_payment(payment)
    # Create Stripe transfer
    transfer = Stripe::Transfer.create(
      amount: payment.amount_cents,
      currency: 'usd',
      destination: payment.worker_profile.stripe_account_id,
      description: "Shift: #{payment.shift_assignment.shift.tracking_code}"
    )

    payment.update!(
      status: :completed,
      processed_at: Time.current,
      external_transaction_id: transfer.id
    )
  end
end
```

**Challenges:**
- Stripe Connect setup (marketplace payments)
- ACH delays (2-3 days)
- Failed payments (insufficient funds)
- Refunds and disputes
- 1099 reporting

**Learning opportunity:**
- Marketplace payments
- Financial compliance
- Error handling at scale

### 3. Real-Time Notifications (Medium Priority) 🔔

**Current state:** No real-time updates

**Implementation ideas:**
- ActionCable for WebSocket connections
- Push notifications (OneSignal, Firebase)
- Email notifications (ActionMailer)

**Use cases:**
- Offer received notification
- Shift reminder (1 hour before)
- Shift cancelled notification
- Payment received notification

**Example:**
```ruby
# app/channels/worker_notifications_channel.rb
class WorkerNotificationsChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user.worker_profile
  end
end

# When offer is sent:
WorkerNotificationsChannel.broadcast_to(
  worker,
  {
    type: 'shift_offer',
    shift: shift.as_json,
    expires_at: 15.minutes.from_now
  }
)
```

### 4. Advanced Recruiting Features

**Ideas to explore:**

**A) Smart Timeout Adjustment**
```ruby
# Adjust timeout based on worker's historical response time
def offer_timeout_minutes(worker)
  avg_response = worker.average_response_time_minutes

  case avg_response
  when 0..3   then 5   # Very fast responder
  when 3..10  then 10  # Fast responder
  when 10..20 then 15  # Normal responder (default)
  else             20  # Slow responder
  end
end
```

**B) Shift Recommendations**
```ruby
# Proactively suggest shifts to workers
class ShiftRecommendationService
  def recommend_for_worker(worker)
    Shift.recruiting
         .for_job_type(worker.preferred_job_types)
         .within_distance(worker.latitude, worker.longitude, 15)
         .starting_within(24.hours)
         .order_by_match_score(worker)
  end
end
```

**C) Dynamic Pricing**
```ruby
# Increase pay rate if shift is hard to fill
def adjust_pay_rate_if_needed(shift)
  return if shift.offers_sent < 10

  # No accepts after 10 offers? Increase pay by 10%
  if shift.shift_assignments.accepted.empty?
    new_rate = (shift.pay_rate_cents * 1.1).to_i
    shift.update!(pay_rate_cents: new_rate)
    RecruitingActivityLog.log_pay_increase(shift, new_rate)
  end
end
```

### 5. Admin Analytics Dashboard

**Current state:** Basic admin views
**Needed:**
- Recruiting funnel analytics
- Offer acceptance rates
- Average time to fill
- Worker performance leaderboards
- Company insights

**Example metrics:**
```ruby
class RecruitingMetrics
  def offer_acceptance_rate(shift)
    total = shift.shift_assignments.count
    accepted = shift.shift_assignments.accepted_assignments.count

    (accepted.to_f / total * 100).round(2)
  end

  def average_offers_to_fill
    Shift.filled.average(:offers_sent_count)
  end

  def worker_leaderboard(limit: 10)
    WorkerProfile.active
                 .order(reliability_score: :desc, total_shifts_completed: :desc)
                 .limit(limit)
  end
end
```

### 6. Mobile Application

**Current state:** API ready, no mobile app

**Technology options:**
- React Native (code sharing with Next.js)
- Flutter (better performance)
- Native (iOS + Android separately)

**Key mobile features:**
- Push notifications (critical for offers)
- GPS check-in (verify worker location)
- Quick accept/decline (swipe gestures)
- Offline support (view accepted shifts)

### 7. Testing Improvements

**Add:**
- System tests (full browser automation)
- Load testing (how many offers/second?)
- Performance monitoring (N+1 query detection)

**Example system test:**
```ruby
# test/system/shift_recruiting_test.rb
test 'employer posts shift and recruiting works end-to-end' do
  sign_in_as employer

  visit new_shift_path
  fill_in 'Title', with: 'Warehouse Assistant'
  fill_in 'Pay Rate', with: '18.50'
  # ... fill form
  click_button 'Post Shift'

  assert_text 'Shift posted successfully'

  click_button 'Start Recruiting'

  # Background jobs run
  perform_enqueued_jobs

  # Check that offer was sent
  assert_emails 1
  assert_equal worker.phone, last_sms_message.to_phone
end
```

### 8. Geographic Expansion

**Current state:** San Antonio, TX only
**Needed for multi-city:**
- Timezone handling (shifts in different zones)
- State-specific labor laws
- Regional payment processing

**Example:**
```ruby
class Shift < ApplicationRecord
  # Store in UTC, display in local timezone
  def local_start_time
    start_datetime.in_time_zone(work_location.timezone)
  end

  def minimum_wage
    # Different minimum wage by state
    MINIMUM_WAGES[work_location.state] || 7.25
  end
end
```

---

## Conclusion: What You've Learned

Congratulations! You've explored a production-ready Rails application from the ground up.

### Key Takeaways

1. **Architecture Matters**: Service objects, concerns, and background jobs create clean, maintainable code

2. **State Machines**: Complex workflows (shift lifecycle, assignment states) become manageable with explicit states and transitions

3. **Async Processing**: Background jobs keep your app responsive and resilient

4. **Testing**: Comprehensive tests enable confident refactoring and catch bugs early

5. **Trade-offs**: Every decision has pros and cons - choose based on your constraints

6. **Simplicity**: Don't over-engineer - build what you need now, refactor later

### The Big Picture

ShiftReady demonstrates that Rails is still a powerful choice for modern web applications:
- API-first architecture (ready for mobile)
- Sophisticated business logic (recruiting algorithm)
- External integrations (geocoding, SMS, payments)
- Production-ready patterns (jobs, services, state machines)
- Comprehensive testing (confidence to ship)

### Your Next Steps

1. **Clone and run** this application locally
2. **Read the tests** - they're the best documentation
3. **Implement one feature** from the "Next Steps" section
4. **Contribute back** - open source thrives on contributions

### Resources for Learning More

**Rails:**
- [Rails Guides](https://guides.rubyonrails.org/) - Official documentation
- [GoRails](https://gorails.com/) - Excellent video tutorials
- [RailsCasts](http://railscasts.com/) - Classic screencasts (older but gold)

**Patterns:**
- [Refactoring Rails](https://www.refactoringrails.io/) - Service objects and beyond
- [Clean Architecture in Ruby](https://blog.cleancoder.com/) - Uncle Bob's wisdom

**Testing:**
- [Everyday Rails Testing with RSpec](https://leanpub.com/everydayrailsrspec) - Great testing intro
- [Minitest Quick Reference](https://www.mattsears.com/articles/2011/12/10/minitest-quick-reference) - Our testing framework

---

## Appendix: Quick Reference

### Project Structure
```
backend/
├── app/
│   ├── controllers/api/v1/  # API endpoints
│   ├── models/               # Domain models
│   │   └── concerns/         # Shared behaviors (Geocodable, PhoneNormalizable)
│   ├── services/             # Business logic (Algorithm, Geocoding, Offer)
│   └── jobs/                 # Background workers (Geocode, Recruiting, Timeout)
├── db/
│   ├── migrate/              # Database migrations
│   └── schema.rb             # Current database structure
└── test/
    ├── factories/            # Test data builders
    ├── models/               # Model tests
    ├── services/             # Service tests
    └── controllers/          # API tests

frontend/
├── app/                      # Next.js pages
├── components/               # React components
└── lib/                      # Utilities (phone formatting, etc.)
```

### Key Models
- **User**: Authentication (email, password, role)
- **WorkerProfile**: Worker data + metrics
- **EmployerProfile**: Employer data + permissions
- **Company**: Client companies
- **Shift**: Job opportunities (state machine)
- **ShiftAssignment**: Worker-shift connection (complex state machine)
- **Payment**: Financial transactions
- **Message**: Communication history
- **RecruitingActivityLog**: Audit trail

### Key Services
- **RecruitingAlgorithmService**: Scores and ranks workers
- **ShiftOfferService**: Orchestrates offer workflow
- **GeocodingService**: Address → lat/lng via Geocodio
- **PhoneNormalizationService**: Phone → E.164 format

### Key Jobs
- **ProcessShiftRecruitingJob**: Main recruiting loop
- **CheckOfferTimeoutJob**: Handle no responses
- **GeocodeAddressJob**: Async address geocoding

### Database Indexes
- Coordinates: `(latitude, longitude)` for distance queries
- Status + datetime: Fast filtering of active shifts
- Uniqueness: Prevent duplicates (phone, email, tracking codes)
- JSONB: GIN index for JSON queries

---

**Built with ❤️ in San Antonio, TX**

*Questions? Open an issue on GitHub or reach out to the maintainers.*

---

*This document was written as an educational resource for developers learning Rails, service-oriented architecture, and modern web development patterns. Feel free to adapt these patterns for your own projects!*
