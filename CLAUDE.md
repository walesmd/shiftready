# ShiftReady

## Overview
On-demand staffing platform connecting employers with flexible workers via SMS.
Based in San Antonio, TX with planned expansion across Texas.

## Company Values
See [COMPANY_MANIFESTO.md](../COMPANY_MANIFESTO.md) for our core principles and values.

**Key principles that guide all decisions:**
- Reduce friction between effort and income
- Prioritize speed, clarity, and fairness
- Choose simplicity over scale-at-all-costs
- Respect time on both sides of the marketplace
- No hidden costs, no confusion, no unnecessary complexity

## Tech Stack

### Frontend (Current)
- Next.js 16.0.10 / React 19 / TypeScript 5
- Tailwind CSS 4.1.9 with OKLch color system
- shadcn/ui components (Radix UI primitives)
- React Hook Form + Zod for form validation
- Lucide React for icons

### Backend (Planned)
- Ruby on Rails 7.2+ (API-only mode)
- PostgreSQL database
- Redis for caching/sessions
- Sidekiq for background jobs
- Devise + JWT for authentication

### External Services (Planned)
- Twilio for SMS messaging
- Stripe Connect for marketplace payments
- Render for deployment

## Project Structure
```
shiftready/
├── frontend/           # Next.js application
│   ├── app/            # Next.js App Router pages
│   ├── components/     # React components
│   │   ├── ui/         # shadcn/ui base components
│   │   └── *.tsx       # Page section components
│   ├── lib/            # Utility functions
│   └── public/         # Static assets
└── backend/            # Rails API
    ├── app/
    │   ├── controllers/api/v1/
    │   ├── models/
    │   ├── services/
    │   └── jobs/
    ├── config/
    └── db/
```

## Development Commands

### Frontend
```bash
cd frontend
npm install          # Install dependencies
npm run dev          # Start dev server (localhost:3000)
npm run build        # Production build
npm run lint         # Run ESLint
```

### Backend
```bash
cd backend
bundle install       # Install gems
rails db:setup       # Create and migrate database
rails server         # Start API server (localhost:3001)
rails console        # Interactive console
```

## Code Conventions

### Frontend
- Components use PascalCase (HeroSection.tsx)
- Utility functions in lib/utils.ts
- Use cn() for Tailwind class merging
- Server components by default, "use client" only when needed
- shadcn/ui components in components/ui/

### Backend
- API versioning: /api/v1/
- Service objects for business logic
- Background jobs for async operations
- JSON:API or similar serialization format

## Features

### Automatic Address Geocoding
The platform automatically geocodes addresses using the Geocodio API whenever addresses are created or updated.

**How it works:**
- Models with addresses include the `Geocodable` concern
- When an address is created or updated, it's automatically geocoded
- Latitude and longitude are stored in the database
- No developer action needed - it's automatic

**Models with geocoding:**
- `WorkerProfile`: Geocodes worker home address
- `WorkLocation`: Geocodes work site addresses
- `Company`: Geocodes billing address (with `billing_` prefix)

**Implementation:**
- Service: `app/services/geocoding_service.rb` - Handles Geocodio API calls
- Concern: `app/models/concerns/geocodable.rb` - Provides automatic geocoding
- Configuration: Set `GEOCODIO_API_KEY` in environment variables

**Customization:**
```ruby
class MyModel < ApplicationRecord
  include Geocodable

  # Optional: customize behavior
  geocodable address_fields: %i[address_line_1 city state zip_code],
             use_normalized_address: true,  # Use Geocodio's normalized address
             prefix: 'billing_'              # For billing_address_line_1, etc.
end
```

### Automatic Phone Number Normalization
The platform automatically normalizes phone numbers to E.164 format (e.g., +12105550123) whenever phone numbers are saved.

**How it works:**
- Models with phone numbers include the `PhoneNormalizable` concern
- When a phone number is saved, it's automatically normalized before validation
- Strips punctuation, adds +1 country code if missing
- Stores in consistent E.164 format
- No developer action needed - it's automatic

**Models with phone normalization:**
- `WorkerProfile`: Normalizes worker phone number
- `EmployerProfile`: Normalizes employer phone number
- `Message`: Normalizes from_phone and to_phone for SMS routing

**Implementation:**
- Service: `app/services/phone_normalization_service.rb` - Handles phone number normalization
- Concern: `app/models/concerns/phone_normalizable.rb` - Provides automatic normalization
- Format: E.164 international format (+1XXXXXXXXXX for US numbers)

**Supported input formats:**
- (210) 555-0123
- 210-555-0123
- 210.555.0123
- 2105550123
- 12105550123
- +12105550123

**Customization:**
```ruby
class MyModel < ApplicationRecord
  include PhoneNormalizable

  # Optional: customize which fields to normalize
  normalize_phone_fields :phone, :emergency_contact_phone, :alternate_phone
end
```

**Display formatting:**

All API responses automatically return phone numbers in display format (e.g., "(210) 555-0123") via model methods:

```ruby
# Backend - Model methods
worker.phone          # => "+12105550123" (stored format)
worker.phone_display  # => "(210) 555-0123" (display format)

employer.phone          # => "+12105550123" (stored format)
employer.phone_display  # => "(210) 555-0123" (display format)

message.from_phone_display  # => "(210) 555-0123"
message.to_phone_display    # => "(210) 555-0123"

# Service method (used internally by models)
PhoneNormalizationService.format_display('+12105550123')
# => "(210) 555-0123"
```

Frontend utilities match backend behavior:

```typescript
// Frontend utilities (lib/phone.ts)
import { formatPhoneDisplay, normalizePhoneNumber } from '@/lib/phone'

// Format for display
formatPhoneDisplay('+12105550123')  // => "(210) 555-0123"

// Normalize user input
normalizePhoneNumber('(210) 555-0123')  // => "+12105550123"
```

### User Onboarding System

The platform implements a reactive, reusable onboarding system that tracks task completion and guides users through required setup steps.

**How it works:**
- Onboarding status managed via React Context (`OnboardingContext`)
- Displays progress card at top of dashboard until tasks are complete
- Automatically updates when users complete tasks (no page refresh needed)
- Backend tracks completion status and enforces requirements
- Pattern is reusable across all user types (employer, worker, admin)

**Current Implementation:**

**Employer Onboarding:**
- ✅ Fully implemented
- Tasks: Add billing information, Add work location
- Protection: Cannot post shifts until onboarding complete
- Backend: `GET /api/v1/employers/me/onboarding_status`
- Frontend: `OnboardingCard` component in employer dashboard
- Models: `Company#onboarding_complete?` auto-updates `is_active` field

**Worker Onboarding:**
- 📋 Planned (not yet implemented)
- Documentation: See `backend/docs/WORKER_ONBOARDING.md` for complete implementation guide
- Tasks: Complete profile, Accept agreements, Add payment method
- Protection: Cannot accept shifts until onboarding complete
- Backend: Will use same pattern as employer onboarding
- Frontend: `WorkerOnboardingCard` component (to be created)

**Technical Implementation:**

Backend pattern:
```ruby
# Model methods
def onboarding_complete?
  task_1_complete? && task_2_complete? && task_3_complete?
end

def onboarding_status
  {
    task_1_complete: task_1_complete?,
    task_2_complete: task_2_complete?,
    is_complete: onboarding_complete?
  }
end

# Callbacks to auto-update onboarding_completed field
after_save :update_onboarding_completed_status
```

Frontend pattern:
```typescript
// Context provides global state
const { onboardingStatus, refreshOnboardingStatus } = useOnboarding();

// Components call refresh after completing tasks
await saveData();
await refreshOnboardingStatus(); // Card updates automatically
```

**Key Files:**
- Context: `frontend/contexts/onboarding-context.tsx`
- Employer Card: `frontend/components/employer-dashboard/onboarding-card.tsx`
- Worker Guide: `backend/docs/WORKER_ONBOARDING.md`
- Company Model: `backend/app/models/company.rb`
- EmployerProfile Model: `backend/app/models/employer_profile.rb`

## Domain Model

### Core Entities
- User: Base authentication (email, password, role)
- Worker: Profile, skills, availability, location, payment_info
- Employer: Company name, industry, contact, billing_info
- Shift: Title, description, date, time, location, pay_rate, slots
- ShiftAssignment: Links workers to shifts, tracks status
- Payment: Transaction records, amounts, status
- Message: SMS history, conversation threads

### User Roles
- worker: Can browse/accept shifts, receive payments
- employer: Can post shifts, hire workers, make payments
- admin: Full system access (future)

## Key Files

### Frontend
- app/page.tsx - Landing page composition
- app/layout.tsx - Root layout with fonts/metadata
- app/globals.css - Design tokens and Tailwind config
- components/header.tsx - Navigation header
- components/hero-section.tsx - Main hero with phone mockup
- lib/utils.ts - cn() utility for class merging

### Configuration
- package.json - Dependencies and scripts
- tsconfig.json - TypeScript configuration
- components.json - shadcn/ui settings
- postcss.config.mjs - PostCSS/Tailwind setup

## Environment Variables

### Frontend
```
NEXT_PUBLIC_API_URL=http://localhost:3001
```

### Backend
```
DATABASE_URL=postgresql://...
REDIS_URL=redis://...
JWT_SECRET=...
GEOCODIO_API_KEY=...
TWILIO_ACCOUNT_SID=...
TWILIO_AUTH_TOKEN=...
TWILIO_PHONE_NUMBER=...
STRIPE_SECRET_KEY=...
STRIPE_PUBLISHABLE_KEY=...
```

## Design System

### Colors (OKLch)
- Primary: Black (oklch 0.2 0 0)
- Accent: Teal/Green (oklch 0.55 0.15 145)
- Background: Off-white (oklch 0.97 0.005 85)
- Destructive: Red (oklch 0.577 0.245 27.325)

### Typography
- Font: Geist (Vercel)
- Headings: Bold, tight leading
- Body: Regular weight, comfortable reading

### Components
- Buttons: Multiple variants (default, secondary, outline, ghost)
- Cards: Rounded corners (14px), subtle shadows
- Forms: React Hook Form + Zod validation
