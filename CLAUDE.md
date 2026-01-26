# ShiftReady

## Overview
On-demand staffing platform connecting employers with flexible workers via SMS.
Based in San Antonio, TX with planned expansion across Texas.

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
