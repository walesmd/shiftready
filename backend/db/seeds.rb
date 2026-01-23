# frozen_string_literal: true

# =============================================================================
# ShiftReady Seed Data
# =============================================================================
#
# This file creates comprehensive seed data for development and testing.
# It demonstrates all possible states for every entity in the system.
#
# IMPORTANT: This seed data is BLOCKED in production environments.
#
# Run with: rails db:seed
# Reset with: rails db:seed:replant (drops and re-seeds)
# =============================================================================

# -----------------------------------------------------------------------------
# PRODUCTION PROTECTION
# -----------------------------------------------------------------------------
if Rails.env.production?
  raise <<~ERROR
    ╔════════════════════════════════════════════════════════════════════════╗
    ║  SEED DATA IS DISABLED IN PRODUCTION                                   ║
    ║                                                                         ║
    ║  This seed file contains development/test data and should never be     ║
    ║  run in production. If you need to seed production data, create a      ║
    ║  separate migration or rake task with appropriate safeguards.          ║
    ╚════════════════════════════════════════════════════════════════════════╝
  ERROR
end

# -----------------------------------------------------------------------------
# CONFIGURATION
# -----------------------------------------------------------------------------
SEED_PASSWORD = 'password'
SHIFTREADY_PHONE = '+12105551000'

# Use a fixed base date for reproducible seed data
# All dates are relative to this base
SEED_BASE_DATE = Date.new(2026, 1, 20)

def seed_datetime(day_offset:, hour:, minute: 0)
  date = SEED_BASE_DATE + day_offset
  Time.zone.local(date.year, date.month, date.day, hour, minute, 0)
end

def seed_time_of_day(value)
  Time.zone.parse(value)
end

# -----------------------------------------------------------------------------
# HELPER METHODS - Idempotent record creation
# -----------------------------------------------------------------------------

def seed_user!(email:, role:, password: SEED_PASSWORD)
  user = User.find_or_initialize_by(email: email)
  user.role = role
  user.password = password
  user.password_confirmation = password
  user.save!
  user
end

def seed_company!(attributes)
  record = Company.find_or_initialize_by(name: attributes.fetch(:name))
  record.assign_attributes(attributes)
  record.save!
  record
end

def seed_location!(company:, attributes:)
  record = WorkLocation.find_or_initialize_by(company: company, name: attributes.fetch(:name))
  record.assign_attributes(attributes.merge(company: company))
  record.save!
  record
end

def seed_employer_profile!(user:, company:, attributes:)
  record = EmployerProfile.find_or_initialize_by(user: user)
  record.assign_attributes(attributes.merge(company: company, user: user))
  record.save!
  record
end

def seed_worker_profile!(user:, attributes:)
  record = WorkerProfile.find_or_initialize_by(user: user)
  record.assign_attributes(attributes.merge(user: user))
  record.save!
  record
end

def seed_shift!(tracking_code:, attributes:)
  record = Shift.find_or_initialize_by(tracking_code: tracking_code)
  record.assign_attributes(attributes.merge(tracking_code: tracking_code))
  record.save!
  record
end

def seed_assignment!(shift:, worker_profile:, attributes:)
  record = ShiftAssignment.find_or_initialize_by(shift: shift, worker_profile: worker_profile)
  record.assign_attributes(attributes.merge(shift: shift, worker_profile: worker_profile))
  record.save!
  record
end

def seed_payment!(shift_assignment:, worker_profile:, company:, attributes:)
  record = Payment.find_or_initialize_by(shift_assignment: shift_assignment)
  record.assign_attributes(attributes.merge(
    shift_assignment: shift_assignment,
    worker_profile: worker_profile,
    company: company
  ))
  record.save!
  record
end

def seed_message!(messageable:, attributes:)
  # Messages are not idempotent by design - use find_or_create pattern with body
  record = Message.find_or_initialize_by(
    messageable: messageable,
    body: attributes[:body],
    direction: attributes[:direction]
  )
  record.assign_attributes(attributes.merge(messageable: messageable))
  record.save!
  record
end

def seed_availability!(worker_profile:, day_of_week:, start_time:, end_time:, is_active: true)
  record = WorkerAvailability.find_or_initialize_by(
    worker_profile: worker_profile,
    day_of_week: day_of_week,
    start_time: start_time,
    end_time: end_time
  )
  record.is_active = is_active
  record.save!
  record
end

def seed_job_type!(worker_profile:, job_type:)
  WorkerPreferredJobType.find_or_create_by!(
    worker_profile: worker_profile,
    job_type: job_type
  )
end

def seed_block!(blocker:, blocked:, reason: nil)
  BlockList.find_or_create_by!(
    blocker: blocker,
    blocked: blocked
  ) do |record|
    record.reason = reason
  end
end

# -----------------------------------------------------------------------------
# MAIN SEED TRANSACTION
# -----------------------------------------------------------------------------
ActiveRecord::Base.transaction do
  puts '=' * 70
  puts 'Seeding ShiftReady Development Data'
  puts '=' * 70
  puts

  # Disable the automatic profile creation callback during seeding
  User.skip_callback(:create, :after, :create_profile_for_role)

  begin
    # ===========================================================================
    # COMPANIES
    # ===========================================================================
    puts 'Creating companies...'

    companies = {
      northstar: seed_company!(
        name: 'Northstar Logistics',
        industry: 'warehouse',
        billing_address_line_1: '1200 Logistics Way',
        billing_city: 'Dallas',
        billing_state: 'TX',
        billing_zip_code: '75201',
        billing_email: 'billing@northstar-logistics.test',
        billing_phone: '+12145550100',
        workers_needed_per_week: '45',
        typical_roles: 'warehouse, loading, unloading',
        is_active: true
      ),
      lonestar: seed_company!(
        name: 'Lone Star Events',
        industry: 'event_setup',
        billing_address_line_1: '88 Congress Ave',
        billing_city: 'Austin',
        billing_state: 'TX',
        billing_zip_code: '78701',
        billing_email: 'billing@lonestarevents.test',
        billing_phone: '+15125550110',
        workers_needed_per_week: '20',
        typical_roles: 'event_setup, event_teardown, hospitality',
        is_active: true
      ),
      harbor: seed_company!(
        name: 'Harbor Hospitality Group',
        industry: 'hospitality',
        billing_address_line_1: '400 Bay Street',
        billing_city: 'Houston',
        billing_state: 'TX',
        billing_zip_code: '77002',
        billing_email: 'billing@harborhospitality.test',
        billing_phone: '+17135550120',
        workers_needed_per_week: '30',
        typical_roles: 'hospitality, cleaning, retail',
        is_active: true
      ),
      quickbuild: seed_company!(
        name: 'QuickBuild Construction',
        industry: 'construction',
        billing_address_line_1: '500 Builder Blvd',
        billing_city: 'San Antonio',
        billing_state: 'TX',
        billing_zip_code: '78205',
        billing_email: 'billing@quickbuild.test',
        billing_phone: '+12105550130',
        workers_needed_per_week: '25',
        typical_roles: 'construction, assembly, general_labor',
        is_active: true
      ),
      # Inactive company - for admin visibility testing
      defunct: seed_company!(
        name: 'Defunct Distributors',
        industry: 'warehouse',
        billing_address_line_1: '999 Closed Lane',
        billing_city: 'El Paso',
        billing_state: 'TX',
        billing_zip_code: '79901',
        billing_email: 'billing@defunct.test',
        billing_phone: '+19155550199',
        workers_needed_per_week: '0',
        typical_roles: 'warehouse',
        is_active: false
      )
    }

    puts "  Created #{companies.size} companies"

    # ===========================================================================
    # WORK LOCATIONS
    # ===========================================================================
    puts 'Creating work locations...'

    locations = {
      # Northstar locations (Dallas area)
      northstar_dallas: seed_location!(
        company: companies[:northstar],
        attributes: {
          name: 'Dallas Fulfillment Center',
          address_line_1: '1420 Industrial Blvd',
          city: 'Dallas',
          state: 'TX',
          zip_code: '75207',
          arrival_instructions: 'Check in at the main gate with a valid ID.',
          parking_notes: 'Employee parking on the east lot.',
          is_active: true
        }
      ),
      northstar_plano: seed_location!(
        company: companies[:northstar],
        attributes: {
          name: 'Plano Cross Dock',
          address_line_1: '3100 14th Street',
          city: 'Plano',
          state: 'TX',
          zip_code: '75074',
          arrival_instructions: 'Report to dock supervisor in bay 3.',
          parking_notes: 'Visitor parking near the front entrance.',
          is_active: true
        }
      ),
      northstar_irving: seed_location!(
        company: companies[:northstar],
        attributes: {
          name: 'Irving Warehouse (Inactive)',
          address_line_1: '800 Commerce Dr',
          city: 'Irving',
          state: 'TX',
          zip_code: '75062',
          arrival_instructions: 'Location temporarily closed.',
          is_active: false
        }
      ),

      # Lone Star Events locations (Austin area)
      lonestar_austin: seed_location!(
        company: companies[:lonestar],
        attributes: {
          name: 'Austin Convention Center',
          address_line_1: '500 E Cesar Chavez St',
          city: 'Austin',
          state: 'TX',
          zip_code: '78701',
          arrival_instructions: 'Meet at Hall C staging area.',
          parking_notes: 'Parking garage on 2nd street.',
          is_active: true
        }
      ),
      lonestar_roundrock: seed_location!(
        company: companies[:lonestar],
        attributes: {
          name: 'Round Rock Expo Grounds',
          address_line_1: '3701 N I-35 Frontage Rd',
          city: 'Round Rock',
          state: 'TX',
          zip_code: '78664',
          arrival_instructions: 'Check in with the event lead by the south gate.',
          parking_notes: 'Overflow parking available behind the pavilion.',
          is_active: true
        }
      ),

      # Harbor Hospitality locations (Houston/Gulf area)
      harbor_houston: seed_location!(
        company: companies[:harbor],
        attributes: {
          name: 'Harbor Hotel Downtown',
          address_line_1: '1200 Main St',
          city: 'Houston',
          state: 'TX',
          zip_code: '77002',
          arrival_instructions: 'Enter through the service entrance on Milam.',
          parking_notes: 'Validated parking in the south garage.',
          is_active: true
        }
      ),
      harbor_galveston: seed_location!(
        company: companies[:harbor],
        attributes: {
          name: 'Seaside Resort Galveston',
          address_line_1: '901 Seawall Blvd',
          city: 'Galveston',
          state: 'TX',
          zip_code: '77550',
          arrival_instructions: 'Meet housekeeping supervisor in the lobby.',
          parking_notes: 'Staff parking behind the resort.',
          is_active: true
        }
      ),

      # QuickBuild locations (San Antonio area)
      quickbuild_downtown: seed_location!(
        company: companies[:quickbuild],
        attributes: {
          name: 'Downtown Project Site',
          address_line_1: '300 Alamo Plaza',
          city: 'San Antonio',
          state: 'TX',
          zip_code: '78205',
          arrival_instructions: 'Check in at the job trailer on the east side.',
          parking_notes: 'Street parking only. Arrive early.',
          is_active: true
        }
      ),
      quickbuild_medical: seed_location!(
        company: companies[:quickbuild],
        attributes: {
          name: 'Medical Center Expansion',
          address_line_1: '7700 Floyd Curl Dr',
          city: 'San Antonio',
          state: 'TX',
          zip_code: '78229',
          arrival_instructions: 'Report to foreman at the north entrance.',
          parking_notes: 'Temporary lot on Wurzbach.',
          is_active: true
        }
      )
    }

    puts "  Created #{locations.size} work locations"

    # ===========================================================================
    # ADMIN USER
    # ===========================================================================
    puts 'Creating admin user...'

    admin_user = seed_user!(email: 'admin@shiftready.test', role: :admin)
    puts '  Created admin user: admin@shiftready.test'

    # ===========================================================================
    # EMPLOYERS & EMPLOYER PROFILES
    # ===========================================================================
    puts 'Creating employers...'

    employers = {
      # Northstar employers - various permission levels
      ava: seed_employer_profile!(
        user: seed_user!(email: 'ava.employer@shiftready.test', role: :employer),
        company: companies[:northstar],
        attributes: {
          first_name: 'Ava',
          last_name: 'Reed',
          title: 'Operations Manager',
          phone: '+12145551001',
          onboarding_completed: true,
          can_post_shifts: true,
          can_approve_timesheets: true,
          is_billing_contact: true,
          terms_accepted_at: seed_datetime(day_offset: -60, hour: 10),
          msa_accepted_at: seed_datetime(day_offset: -60, hour: 10)
        }
      ),
      noah: seed_employer_profile!(
        user: seed_user!(email: 'noah.employer@shiftready.test', role: :employer),
        company: companies[:northstar],
        attributes: {
          first_name: 'Noah',
          last_name: 'Patel',
          title: 'Shift Supervisor',
          phone: '+12145551002',
          onboarding_completed: true,
          can_post_shifts: false,  # Can't post, only supervise
          can_approve_timesheets: true,
          is_billing_contact: false,
          terms_accepted_at: seed_datetime(day_offset: -45, hour: 14),
          msa_accepted_at: seed_datetime(day_offset: -45, hour: 14)
        }
      ),

      # Lone Star Events employer
      olivia: seed_employer_profile!(
        user: seed_user!(email: 'olivia.employer@shiftready.test', role: :employer),
        company: companies[:lonestar],
        attributes: {
          first_name: 'Olivia',
          last_name: 'Chen',
          title: 'Event Coordinator',
          phone: '+15125551003',
          onboarding_completed: true,
          can_post_shifts: true,
          can_approve_timesheets: true,
          is_billing_contact: true,
          terms_accepted_at: seed_datetime(day_offset: -30, hour: 9),
          msa_accepted_at: seed_datetime(day_offset: -30, hour: 9)
        }
      ),

      # Harbor Hospitality employer
      liam: seed_employer_profile!(
        user: seed_user!(email: 'liam.employer@shiftready.test', role: :employer),
        company: companies[:harbor],
        attributes: {
          first_name: 'Liam',
          last_name: 'Cruz',
          title: 'Hotel Operations Director',
          phone: '+17135551004',
          onboarding_completed: true,
          can_post_shifts: true,
          can_approve_timesheets: true,
          is_billing_contact: true,
          terms_accepted_at: seed_datetime(day_offset: -25, hour: 11),
          msa_accepted_at: seed_datetime(day_offset: -25, hour: 11)
        }
      ),

      # QuickBuild employer
      marcus: seed_employer_profile!(
        user: seed_user!(email: 'marcus.employer@shiftready.test', role: :employer),
        company: companies[:quickbuild],
        attributes: {
          first_name: 'Marcus',
          last_name: 'Thompson',
          title: 'Site Foreman',
          phone: '+12105551005',
          onboarding_completed: true,
          can_post_shifts: true,
          can_approve_timesheets: true,
          is_billing_contact: false,
          terms_accepted_at: seed_datetime(day_offset: -20, hour: 8),
          msa_accepted_at: seed_datetime(day_offset: -20, hour: 8)
        }
      ),

      # Employer still in onboarding
      pending_emma: seed_employer_profile!(
        user: seed_user!(email: 'emma.employer@shiftready.test', role: :employer),
        company: companies[:quickbuild],
        attributes: {
          first_name: 'Emma',
          last_name: 'Wilson',
          title: 'Project Coordinator',
          phone: '+12105551006',
          onboarding_completed: false,
          can_post_shifts: false,
          can_approve_timesheets: false,
          is_billing_contact: false
        }
      ),

      # Employer at inactive company
      defunct_employer: seed_employer_profile!(
        user: seed_user!(email: 'defunct.employer@shiftready.test', role: :employer),
        company: companies[:defunct],
        attributes: {
          first_name: 'Former',
          last_name: 'Employee',
          title: 'Ex-Manager',
          phone: '+19155551099',
          onboarding_completed: true,
          can_post_shifts: true,
          can_approve_timesheets: true,
          is_billing_contact: true,
          terms_accepted_at: seed_datetime(day_offset: -180, hour: 10),
          msa_accepted_at: seed_datetime(day_offset: -180, hour: 10)
        }
      )
    }

    puts "  Created #{employers.size} employers"

    # ===========================================================================
    # WORKERS & WORKER PROFILES
    # ===========================================================================
    puts 'Creating workers...'

    # Note: We set stats to 0 initially and update them after creating assignments
    workers = {
      # Fully onboarded, active, high performer (Dallas area)
      maya: seed_worker_profile!(
        user: seed_user!(email: 'maya.worker@shiftready.test', role: :worker),
        attributes: {
          first_name: 'Maya',
          last_name: 'Brooks',
          phone: '+12145552001',
          address_line_1: '210 Maple St',
          city: 'Dallas',
          state: 'TX',
          zip_code: '75204',
          is_active: true,
          onboarding_completed: true,
          over_18_confirmed: true,
          sms_consent_given_at: seed_datetime(day_offset: -50, hour: 8),
          terms_accepted_at: seed_datetime(day_offset: -50, hour: 8),
          ssn_encrypted: 'enc-maya-1111',
          preferred_payment_method: :direct_deposit,
          bank_account_last_4: '4521',
          # Stats will be calculated from actual assignments
          total_shifts_assigned: 0,
          total_shifts_completed: 0,
          no_show_count: 0
        }
      ),

      # Fully onboarded, active, medium performer (Plano area)
      jordan: seed_worker_profile!(
        user: seed_user!(email: 'jordan.worker@shiftready.test', role: :worker),
        attributes: {
          first_name: 'Jordan',
          last_name: 'Lee',
          phone: '+12145552002',
          address_line_1: '88 Elm Blvd',
          city: 'Plano',
          state: 'TX',
          zip_code: '75024',
          is_active: true,
          onboarding_completed: true,
          over_18_confirmed: true,
          sms_consent_given_at: seed_datetime(day_offset: -40, hour: 14),
          terms_accepted_at: seed_datetime(day_offset: -40, hour: 14),
          ssn_encrypted: 'enc-jordan-2222',
          preferred_payment_method: :check,
          total_shifts_assigned: 0,
          total_shifts_completed: 0,
          no_show_count: 0
        }
      ),

      # Fully onboarded, active (Austin area - for Lone Star Events)
      riley: seed_worker_profile!(
        user: seed_user!(email: 'riley.worker@shiftready.test', role: :worker),
        attributes: {
          first_name: 'Riley',
          last_name: 'Nguyen',
          phone: '+15125552003',
          address_line_1: '430 Oak Ave',
          city: 'Austin',
          state: 'TX',
          zip_code: '78704',
          is_active: true,
          onboarding_completed: true,
          over_18_confirmed: true,
          sms_consent_given_at: seed_datetime(day_offset: -35, hour: 10),
          terms_accepted_at: seed_datetime(day_offset: -35, hour: 10),
          ssn_encrypted: 'enc-riley-3333',
          preferred_payment_method: :direct_deposit,
          bank_account_last_4: '7890',
          total_shifts_assigned: 0,
          total_shifts_completed: 0,
          no_show_count: 0
        }
      ),

      # Fully onboarded, active, excellent performer (Houston area)
      zoe: seed_worker_profile!(
        user: seed_user!(email: 'zoe.worker@shiftready.test', role: :worker),
        attributes: {
          first_name: 'Zoe',
          last_name: 'Martinez',
          phone: '+17135552004',
          address_line_1: '920 Bay St',
          city: 'Houston',
          state: 'TX',
          zip_code: '77003',
          is_active: true,
          onboarding_completed: true,
          over_18_confirmed: true,
          sms_consent_given_at: seed_datetime(day_offset: -45, hour: 12),
          terms_accepted_at: seed_datetime(day_offset: -45, hour: 12),
          ssn_encrypted: 'enc-zoe-4444',
          preferred_payment_method: :direct_deposit,
          bank_account_last_4: '1234',
          total_shifts_assigned: 0,
          total_shifts_completed: 0,
          no_show_count: 0
        }
      ),

      # Fully onboarded but INACTIVE (deactivated account)
      theo: seed_worker_profile!(
        user: seed_user!(email: 'theo.worker@shiftready.test', role: :worker),
        attributes: {
          first_name: 'Theo',
          last_name: 'Johnson',
          phone: '+17135552005',
          address_line_1: '14 River Rd',
          city: 'Galveston',
          state: 'TX',
          zip_code: '77550',
          is_active: false,  # INACTIVE
          onboarding_completed: true,
          over_18_confirmed: true,
          sms_consent_given_at: seed_datetime(day_offset: -60, hour: 9),
          terms_accepted_at: seed_datetime(day_offset: -60, hour: 9),
          ssn_encrypted: 'enc-theo-5555',
          preferred_payment_method: :check,
          total_shifts_assigned: 0,
          total_shifts_completed: 0,
          no_show_count: 0
        }
      ),

      # San Antonio worker (for QuickBuild)
      carlos: seed_worker_profile!(
        user: seed_user!(email: 'carlos.worker@shiftready.test', role: :worker),
        attributes: {
          first_name: 'Carlos',
          last_name: 'Ramirez',
          phone: '+12105552006',
          address_line_1: '555 Mission Rd',
          city: 'San Antonio',
          state: 'TX',
          zip_code: '78210',
          is_active: true,
          onboarding_completed: true,
          over_18_confirmed: true,
          sms_consent_given_at: seed_datetime(day_offset: -30, hour: 7),
          terms_accepted_at: seed_datetime(day_offset: -30, hour: 7),
          ssn_encrypted: 'enc-carlos-6666',
          preferred_payment_method: :direct_deposit,
          bank_account_last_4: '9876',
          total_shifts_assigned: 0,
          total_shifts_completed: 0,
          no_show_count: 0
        }
      ),

      # Partially onboarded (has not provided SSN yet)
      alex: seed_worker_profile!(
        user: seed_user!(email: 'alex.worker@shiftready.test', role: :worker),
        attributes: {
          first_name: 'Alex',
          last_name: 'Turner',
          phone: '+12105552007',
          address_line_1: '789 Broadway',
          city: 'San Antonio',
          state: 'TX',
          zip_code: '78215',
          is_active: true,
          onboarding_completed: false,  # NOT ONBOARDED
          over_18_confirmed: true,
          sms_consent_given_at: seed_datetime(day_offset: -5, hour: 15),
          terms_accepted_at: seed_datetime(day_offset: -5, hour: 15),
          # No SSN yet
          preferred_payment_method: :direct_deposit,
          total_shifts_assigned: 0,
          total_shifts_completed: 0,
          no_show_count: 0
        }
      ),

      # Brand new worker (minimal info)
      new_sam: seed_worker_profile!(
        user: seed_user!(email: 'sam.worker@shiftready.test', role: :worker),
        attributes: {
          first_name: 'Sam',
          last_name: 'Davis',
          phone: '+12145552008',
          address_line_1: '100 New St',
          city: 'Dallas',
          state: 'TX',
          zip_code: '75201',
          is_active: true,
          onboarding_completed: false,
          over_18_confirmed: false,  # Hasn't confirmed yet
          preferred_payment_method: :direct_deposit,
          total_shifts_assigned: 0,
          total_shifts_completed: 0,
          no_show_count: 0
        }
      )
    }

    puts "  Created #{workers.size} workers"

    # ===========================================================================
    # WORKER AVAILABILITIES
    # ===========================================================================
    puts 'Creating worker availabilities...'

    # Maya - Monday and Thursday mornings
    seed_availability!(worker_profile: workers[:maya], day_of_week: 1, start_time: seed_time_of_day('06:00'), end_time: seed_time_of_day('14:00'))
    seed_availability!(worker_profile: workers[:maya], day_of_week: 4, start_time: seed_time_of_day('06:00'), end_time: seed_time_of_day('14:00'))

    # Jordan - Tuesday, Wednesday, Friday
    seed_availability!(worker_profile: workers[:jordan], day_of_week: 2, start_time: seed_time_of_day('07:00'), end_time: seed_time_of_day('15:00'))
    seed_availability!(worker_profile: workers[:jordan], day_of_week: 3, start_time: seed_time_of_day('07:00'), end_time: seed_time_of_day('15:00'))
    seed_availability!(worker_profile: workers[:jordan], day_of_week: 5, start_time: seed_time_of_day('12:00'), end_time: seed_time_of_day('20:00'))

    # Riley - Weekends and Wednesday evenings
    seed_availability!(worker_profile: workers[:riley], day_of_week: 0, start_time: seed_time_of_day('08:00'), end_time: seed_time_of_day('18:00'))
    seed_availability!(worker_profile: workers[:riley], day_of_week: 3, start_time: seed_time_of_day('16:00'), end_time: seed_time_of_day('22:00'))
    seed_availability!(worker_profile: workers[:riley], day_of_week: 6, start_time: seed_time_of_day('08:00'), end_time: seed_time_of_day('18:00'))

    # Zoe - Very flexible, most days
    seed_availability!(worker_profile: workers[:zoe], day_of_week: 1, start_time: seed_time_of_day('06:00'), end_time: seed_time_of_day('18:00'))
    seed_availability!(worker_profile: workers[:zoe], day_of_week: 2, start_time: seed_time_of_day('06:00'), end_time: seed_time_of_day('18:00'))
    seed_availability!(worker_profile: workers[:zoe], day_of_week: 3, start_time: seed_time_of_day('06:00'), end_time: seed_time_of_day('18:00'))
    seed_availability!(worker_profile: workers[:zoe], day_of_week: 4, start_time: seed_time_of_day('06:00'), end_time: seed_time_of_day('18:00'))
    seed_availability!(worker_profile: workers[:zoe], day_of_week: 5, start_time: seed_time_of_day('06:00'), end_time: seed_time_of_day('18:00'))

    # Theo - Has availability but is inactive (for admin view)
    seed_availability!(worker_profile: workers[:theo], day_of_week: 2, start_time: seed_time_of_day('09:00'), end_time: seed_time_of_day('17:00'), is_active: false)

    # Carlos - Mornings, Mon-Fri
    seed_availability!(worker_profile: workers[:carlos], day_of_week: 1, start_time: seed_time_of_day('05:00'), end_time: seed_time_of_day('13:00'))
    seed_availability!(worker_profile: workers[:carlos], day_of_week: 2, start_time: seed_time_of_day('05:00'), end_time: seed_time_of_day('13:00'))
    seed_availability!(worker_profile: workers[:carlos], day_of_week: 3, start_time: seed_time_of_day('05:00'), end_time: seed_time_of_day('13:00'))
    seed_availability!(worker_profile: workers[:carlos], day_of_week: 4, start_time: seed_time_of_day('05:00'), end_time: seed_time_of_day('13:00'))
    seed_availability!(worker_profile: workers[:carlos], day_of_week: 5, start_time: seed_time_of_day('05:00'), end_time: seed_time_of_day('13:00'))

    puts '  Created worker availabilities'

    # ===========================================================================
    # WORKER PREFERRED JOB TYPES
    # ===========================================================================
    puts 'Creating worker job preferences...'

    seed_job_type!(worker_profile: workers[:maya], job_type: 'warehouse')
    seed_job_type!(worker_profile: workers[:maya], job_type: 'loading')
    seed_job_type!(worker_profile: workers[:maya], job_type: 'unloading')

    seed_job_type!(worker_profile: workers[:jordan], job_type: 'warehouse')
    seed_job_type!(worker_profile: workers[:jordan], job_type: 'packing')

    seed_job_type!(worker_profile: workers[:riley], job_type: 'event_setup')
    seed_job_type!(worker_profile: workers[:riley], job_type: 'event_teardown')
    seed_job_type!(worker_profile: workers[:riley], job_type: 'hospitality')

    seed_job_type!(worker_profile: workers[:zoe], job_type: 'hospitality')
    seed_job_type!(worker_profile: workers[:zoe], job_type: 'cleaning')
    seed_job_type!(worker_profile: workers[:zoe], job_type: 'retail')

    seed_job_type!(worker_profile: workers[:theo], job_type: 'cleaning')
    seed_job_type!(worker_profile: workers[:theo], job_type: 'general_labor')

    seed_job_type!(worker_profile: workers[:carlos], job_type: 'construction')
    seed_job_type!(worker_profile: workers[:carlos], job_type: 'assembly')
    seed_job_type!(worker_profile: workers[:carlos], job_type: 'general_labor')

    puts '  Created worker job preferences'

    # ===========================================================================
    # SHIFTS - All statuses represented
    # ===========================================================================
    puts 'Creating shifts...'

    shifts = {
      # -------------------------------------------------------------------------
      # DRAFT shifts (future, not yet posted)
      # -------------------------------------------------------------------------
      draft_warehouse: seed_shift!(
        tracking_code: 'SR-D0F001',
        attributes: {
          title: 'Inventory Prep Crew',
          description: 'Prep inventory for the upcoming shipment run. Count and organize stock.',
          job_type: 'warehouse',
          start_datetime: seed_datetime(day_offset: 10, hour: 8),
          end_datetime: seed_datetime(day_offset: 10, hour: 16),
          pay_rate_cents: 1850,
          status: :draft,
          slots_total: 3,
          slots_filled: 0,
          min_workers_needed: 2,
          company: companies[:northstar],
          work_location: locations[:northstar_dallas],
          created_by_employer: employers[:ava]
        }
      ),

      draft_construction: seed_shift!(
        tracking_code: 'SR-D0F002',
        attributes: {
          title: 'Site Prep Team',
          description: 'Prepare construction site for next phase. General cleanup and organization.',
          job_type: 'construction',
          start_datetime: seed_datetime(day_offset: 12, hour: 6),
          end_datetime: seed_datetime(day_offset: 12, hour: 14),
          pay_rate_cents: 2200,
          status: :draft,
          slots_total: 4,
          slots_filled: 0,
          min_workers_needed: 3,
          company: companies[:quickbuild],
          work_location: locations[:quickbuild_downtown],
          created_by_employer: employers[:marcus]
        }
      ),

      # -------------------------------------------------------------------------
      # POSTED shifts (future, published but not actively recruiting)
      # -------------------------------------------------------------------------
      posted_loading: seed_shift!(
        tracking_code: 'SR-A5D001',
        attributes: {
          title: 'Cross Dock Loaders',
          description: 'Load outbound trailers and stage pallets for shipment.',
          job_type: 'loading',
          start_datetime: seed_datetime(day_offset: 5, hour: 7),
          end_datetime: seed_datetime(day_offset: 5, hour: 15),
          pay_rate_cents: 1950,
          status: :posted,
          posted_at: seed_datetime(day_offset: -1, hour: 9),
          slots_total: 3,
          slots_filled: 0,
          min_workers_needed: 2,
          company: companies[:northstar],
          work_location: locations[:northstar_plano],
          created_by_employer: employers[:ava]
        }
      ),

      # -------------------------------------------------------------------------
      # RECRUITING shifts (actively seeking workers)
      # -------------------------------------------------------------------------
      recruiting_event: seed_shift!(
        tracking_code: 'SR-BEC001',
        attributes: {
          title: 'Tech Expo Setup Team',
          description: 'Setup booths and staging areas for the annual tech expo. Lifting required.',
          job_type: 'event_setup',
          start_datetime: seed_datetime(day_offset: 4, hour: 9),
          end_datetime: seed_datetime(day_offset: 4, hour: 17),
          pay_rate_cents: 2100,
          status: :recruiting,
          posted_at: seed_datetime(day_offset: -3, hour: 10),
          recruiting_started_at: seed_datetime(day_offset: -2, hour: 10),
          slots_total: 5,
          slots_filled: 2,
          min_workers_needed: 3,
          company: companies[:lonestar],
          work_location: locations[:lonestar_austin],
          created_by_employer: employers[:olivia]
        }
      ),

      recruiting_hotel: seed_shift!(
        tracking_code: 'SR-BEC002',
        attributes: {
          title: 'Conference Room Setup',
          description: 'Prepare meeting rooms for corporate conference. Table and chair arrangement.',
          job_type: 'hospitality',
          start_datetime: seed_datetime(day_offset: 3, hour: 6),
          end_datetime: seed_datetime(day_offset: 3, hour: 12),
          pay_rate_cents: 1800,
          status: :recruiting,
          posted_at: seed_datetime(day_offset: -2, hour: 14),
          recruiting_started_at: seed_datetime(day_offset: -1, hour: 8),
          slots_total: 3,
          slots_filled: 1,
          min_workers_needed: 2,
          company: companies[:harbor],
          work_location: locations[:harbor_houston],
          created_by_employer: employers[:liam]
        }
      ),

      # -------------------------------------------------------------------------
      # FILLED shifts (all slots filled, waiting to start)
      # -------------------------------------------------------------------------
      filled_teardown: seed_shift!(
        tracking_code: 'SR-F1A001',
        attributes: {
          title: 'Expo Teardown Crew',
          description: 'Break down event staging and load equipment onto trucks.',
          job_type: 'event_teardown',
          start_datetime: seed_datetime(day_offset: 2, hour: 18),
          end_datetime: seed_datetime(day_offset: 2, hour: 23),
          pay_rate_cents: 2200,
          status: :filled,
          posted_at: seed_datetime(day_offset: -5, hour: 10),
          recruiting_started_at: seed_datetime(day_offset: -4, hour: 10),
          filled_at: seed_datetime(day_offset: -1, hour: 16),
          slots_total: 2,
          slots_filled: 2,
          min_workers_needed: 2,
          company: companies[:lonestar],
          work_location: locations[:lonestar_roundrock],
          created_by_employer: employers[:olivia]
        }
      ),

      filled_construction: seed_shift!(
        tracking_code: 'SR-F1A002',
        attributes: {
          title: 'Framing Assistance',
          description: 'Assist lead carpenters with framing work. Some experience preferred.',
          job_type: 'construction',
          start_datetime: seed_datetime(day_offset: 1, hour: 6),
          end_datetime: seed_datetime(day_offset: 1, hour: 14),
          pay_rate_cents: 2400,
          status: :filled,
          posted_at: seed_datetime(day_offset: -4, hour: 8),
          recruiting_started_at: seed_datetime(day_offset: -3, hour: 8),
          filled_at: seed_datetime(day_offset: -1, hour: 10),
          slots_total: 2,
          slots_filled: 2,
          min_workers_needed: 2,
          company: companies[:quickbuild],
          work_location: locations[:quickbuild_medical],
          created_by_employer: employers[:marcus]
        }
      ),

      # -------------------------------------------------------------------------
      # IN_PROGRESS shifts (currently happening)
      # -------------------------------------------------------------------------
      in_progress_hotel: seed_shift!(
        tracking_code: 'SR-1FA001',
        attributes: {
          title: 'Ballroom Reset',
          description: 'Flip meeting rooms between conference sessions.',
          job_type: 'hospitality',
          start_datetime: seed_datetime(day_offset: 0, hour: 7),
          end_datetime: seed_datetime(day_offset: 0, hour: 15),
          pay_rate_cents: 2050,
          status: :in_progress,
          posted_at: seed_datetime(day_offset: -5, hour: 9),
          recruiting_started_at: seed_datetime(day_offset: -4, hour: 9),
          filled_at: seed_datetime(day_offset: -2, hour: 14),
          slots_total: 2,
          slots_filled: 2,
          min_workers_needed: 1,
          company: companies[:harbor],
          work_location: locations[:harbor_houston],
          created_by_employer: employers[:liam]
        }
      ),

      # -------------------------------------------------------------------------
      # COMPLETED shifts (finished, various scenarios)
      # -------------------------------------------------------------------------
      completed_cleaning_1: seed_shift!(
        tracking_code: 'SR-C0A001',
        attributes: {
          title: 'Housekeeping Deep Clean',
          description: 'Deep clean guest suites after weekend rush.',
          job_type: 'cleaning',
          start_datetime: seed_datetime(day_offset: -3, hour: 8),
          end_datetime: seed_datetime(day_offset: -3, hour: 14),
          pay_rate_cents: 1900,
          status: :completed,
          posted_at: seed_datetime(day_offset: -10, hour: 9),
          recruiting_started_at: seed_datetime(day_offset: -9, hour: 9),
          filled_at: seed_datetime(day_offset: -5, hour: 14),
          completed_at: seed_datetime(day_offset: -3, hour: 14),
          slots_total: 2,
          slots_filled: 2,
          min_workers_needed: 2,
          company: companies[:harbor],
          work_location: locations[:harbor_galveston],
          created_by_employer: employers[:liam]
        }
      ),

      completed_warehouse_1: seed_shift!(
        tracking_code: 'SR-C0A002',
        attributes: {
          title: 'Peak Season Support',
          description: 'Help process high volume of incoming shipments.',
          job_type: 'warehouse',
          start_datetime: seed_datetime(day_offset: -5, hour: 6),
          end_datetime: seed_datetime(day_offset: -5, hour: 14),
          pay_rate_cents: 1850,
          status: :completed,
          posted_at: seed_datetime(day_offset: -12, hour: 10),
          recruiting_started_at: seed_datetime(day_offset: -11, hour: 10),
          filled_at: seed_datetime(day_offset: -7, hour: 16),
          completed_at: seed_datetime(day_offset: -5, hour: 14),
          slots_total: 3,
          slots_filled: 2,  # One worker was a no-show (Theo)
          min_workers_needed: 2,
          company: companies[:northstar],
          work_location: locations[:northstar_dallas],
          created_by_employer: employers[:ava]
        }
      ),

      completed_event_1: seed_shift!(
        tracking_code: 'SR-C0A003',
        attributes: {
          title: 'Wedding Setup',
          description: 'Setup for outdoor wedding ceremony and reception.',
          job_type: 'event_setup',
          start_datetime: seed_datetime(day_offset: -7, hour: 7),
          end_datetime: seed_datetime(day_offset: -7, hour: 15),
          pay_rate_cents: 2000,
          status: :completed,
          posted_at: seed_datetime(day_offset: -14, hour: 11),
          recruiting_started_at: seed_datetime(day_offset: -13, hour: 11),
          filled_at: seed_datetime(day_offset: -9, hour: 10),
          completed_at: seed_datetime(day_offset: -7, hour: 15),
          slots_total: 4,
          slots_filled: 4,
          min_workers_needed: 3,
          company: companies[:lonestar],
          work_location: locations[:lonestar_austin],
          created_by_employer: employers[:olivia]
        }
      ),

      completed_construction_1: seed_shift!(
        tracking_code: 'SR-C0A004',
        attributes: {
          title: 'Demolition Cleanup',
          description: 'Clean up debris from demolition phase.',
          job_type: 'general_labor',
          start_datetime: seed_datetime(day_offset: -10, hour: 7),
          end_datetime: seed_datetime(day_offset: -10, hour: 15),
          pay_rate_cents: 2100,
          status: :completed,
          posted_at: seed_datetime(day_offset: -17, hour: 8),
          recruiting_started_at: seed_datetime(day_offset: -16, hour: 8),
          filled_at: seed_datetime(day_offset: -12, hour: 14),
          completed_at: seed_datetime(day_offset: -10, hour: 15),
          slots_total: 3,
          slots_filled: 3,
          min_workers_needed: 2,
          company: companies[:quickbuild],
          work_location: locations[:quickbuild_downtown],
          created_by_employer: employers[:marcus]
        }
      ),

      # -------------------------------------------------------------------------
      # CANCELLED shifts (various reasons)
      # -------------------------------------------------------------------------
      cancelled_weather: seed_shift!(
        tracking_code: 'SR-CA0001',
        attributes: {
          title: 'Outdoor Event Setup',
          description: 'Festival booth setup - outdoor event.',
          job_type: 'event_setup',
          start_datetime: seed_datetime(day_offset: 3, hour: 8),
          end_datetime: seed_datetime(day_offset: 3, hour: 16),
          pay_rate_cents: 2000,
          status: :cancelled,
          posted_at: seed_datetime(day_offset: -4, hour: 9),
          recruiting_started_at: seed_datetime(day_offset: -3, hour: 9),
          cancelled_at: seed_datetime(day_offset: -1, hour: 7),
          cancellation_reason: 'Severe weather warning - event postponed.',
          slots_total: 4,
          slots_filled: 0,  # All assignments cancelled when shift was cancelled
          min_workers_needed: 3,
          company: companies[:lonestar],
          work_location: locations[:lonestar_roundrock],
          created_by_employer: employers[:olivia]
        }
      ),

      cancelled_client: seed_shift!(
        tracking_code: 'SR-CA0002',
        attributes: {
          title: 'Warehouse Cycle Count',
          description: 'Count and verify inventory locations.',
          job_type: 'warehouse',
          start_datetime: seed_datetime(day_offset: 5, hour: 8),
          end_datetime: seed_datetime(day_offset: 5, hour: 12),
          pay_rate_cents: 1800,
          status: :cancelled,
          posted_at: seed_datetime(day_offset: -3, hour: 10),
          cancelled_at: seed_datetime(day_offset: -1, hour: 9),
          cancellation_reason: 'Client postponed the audit window.',
          slots_total: 3,
          slots_filled: 0,  # All assignments cancelled when shift was cancelled
          min_workers_needed: 2,
          company: companies[:northstar],
          work_location: locations[:northstar_dallas],
          created_by_employer: employers[:ava]
        }
      )
    }

    puts "  Created #{shifts.size} shifts"

    # ===========================================================================
    # SHIFT ASSIGNMENTS - All statuses represented
    # ===========================================================================
    puts 'Creating shift assignments...'

    assignments = {}

    # -------------------------------------------------------------------------
    # RECRUITING SHIFT - Various assignment states
    # -------------------------------------------------------------------------

    # Worker with pending offer (no response yet)
    assignments[:offered_maya_event] = seed_assignment!(
      shift: shifts[:recruiting_event],
      worker_profile: workers[:maya],
      attributes: {
        status: :offered,
        assigned_by: :algorithm,
        assigned_at: seed_datetime(day_offset: -1, hour: 10),
        sms_sent_at: seed_datetime(day_offset: -1, hour: 10),
        sms_delivered_at: seed_datetime(day_offset: -1, hour: 10),
        response_value: :no_response,
        algorithm_score: 87.5
      }
    )

    # Worker who accepted (part of slots_filled)
    assignments[:accepted_riley_event] = seed_assignment!(
      shift: shifts[:recruiting_event],
      worker_profile: workers[:riley],
      attributes: {
        status: :accepted,
        assigned_by: :algorithm,
        assigned_at: seed_datetime(day_offset: -2, hour: 11),
        sms_sent_at: seed_datetime(day_offset: -2, hour: 11),
        sms_delivered_at: seed_datetime(day_offset: -2, hour: 11),
        accepted_at: seed_datetime(day_offset: -2, hour: 12),
        response_method: :sms,
        response_value: :accepted,
        response_received_at: seed_datetime(day_offset: -2, hour: 12),
        algorithm_score: 92.0
      }
    )

    # Worker who declined
    assignments[:declined_jordan_event] = seed_assignment!(
      shift: shifts[:recruiting_event],
      worker_profile: workers[:jordan],
      attributes: {
        status: :declined,
        assigned_by: :algorithm,
        assigned_at: seed_datetime(day_offset: -2, hour: 9),
        sms_sent_at: seed_datetime(day_offset: -2, hour: 9),
        sms_delivered_at: seed_datetime(day_offset: -2, hour: 9),
        response_method: :sms,
        response_value: :declined,
        response_received_at: seed_datetime(day_offset: -2, hour: 10),
        decline_reason: 'Prior commitment that day',
        algorithm_score: 78.0
      }
    )

    # Worker confirmed (part of slots_filled)
    assignments[:confirmed_zoe_event] = seed_assignment!(
      shift: shifts[:recruiting_event],
      worker_profile: workers[:zoe],
      attributes: {
        status: :confirmed,
        assigned_by: :worker_self_select,
        assigned_at: seed_datetime(day_offset: -1, hour: 14),
        accepted_at: seed_datetime(day_offset: -1, hour: 14),
        confirmed_at: seed_datetime(day_offset: -1, hour: 16),
        response_method: :app,
        response_value: :accepted,
        response_received_at: seed_datetime(day_offset: -1, hour: 14)
      }
    )

    # -------------------------------------------------------------------------
    # RECRUITING HOTEL SHIFT
    # -------------------------------------------------------------------------
    assignments[:confirmed_zoe_hotel] = seed_assignment!(
      shift: shifts[:recruiting_hotel],
      worker_profile: workers[:zoe],
      attributes: {
        status: :confirmed,
        assigned_by: :algorithm,
        assigned_at: seed_datetime(day_offset: -1, hour: 9),
        sms_sent_at: seed_datetime(day_offset: -1, hour: 9),
        sms_delivered_at: seed_datetime(day_offset: -1, hour: 9),
        accepted_at: seed_datetime(day_offset: -1, hour: 10),
        confirmed_at: seed_datetime(day_offset: -1, hour: 12),
        response_method: :sms,
        response_value: :accepted,
        response_received_at: seed_datetime(day_offset: -1, hour: 10),
        algorithm_score: 95.0
      }
    )

    # -------------------------------------------------------------------------
    # FILLED TEARDOWN SHIFT
    # -------------------------------------------------------------------------
    assignments[:confirmed_riley_teardown] = seed_assignment!(
      shift: shifts[:filled_teardown],
      worker_profile: workers[:riley],
      attributes: {
        status: :confirmed,
        assigned_by: :manual_admin,
        assigned_at: seed_datetime(day_offset: -3, hour: 10),
        accepted_at: seed_datetime(day_offset: -3, hour: 11),
        confirmed_at: seed_datetime(day_offset: -2, hour: 9),
        response_method: :app,
        response_value: :accepted,
        response_received_at: seed_datetime(day_offset: -3, hour: 11)
      }
    )

    assignments[:confirmed_maya_teardown] = seed_assignment!(
      shift: shifts[:filled_teardown],
      worker_profile: workers[:maya],
      attributes: {
        status: :confirmed,
        assigned_by: :algorithm,
        assigned_at: seed_datetime(day_offset: -3, hour: 9),
        sms_sent_at: seed_datetime(day_offset: -3, hour: 9),
        sms_delivered_at: seed_datetime(day_offset: -3, hour: 9),
        accepted_at: seed_datetime(day_offset: -3, hour: 10),
        confirmed_at: seed_datetime(day_offset: -2, hour: 8),
        response_method: :sms,
        response_value: :accepted,
        response_received_at: seed_datetime(day_offset: -3, hour: 10),
        algorithm_score: 89.0
      }
    )

    # -------------------------------------------------------------------------
    # FILLED CONSTRUCTION SHIFT
    # -------------------------------------------------------------------------
    assignments[:confirmed_carlos_construction] = seed_assignment!(
      shift: shifts[:filled_construction],
      worker_profile: workers[:carlos],
      attributes: {
        status: :confirmed,
        assigned_by: :algorithm,
        assigned_at: seed_datetime(day_offset: -2, hour: 8),
        sms_sent_at: seed_datetime(day_offset: -2, hour: 8),
        sms_delivered_at: seed_datetime(day_offset: -2, hour: 8),
        accepted_at: seed_datetime(day_offset: -2, hour: 9),
        confirmed_at: seed_datetime(day_offset: -1, hour: 7),
        response_method: :sms,
        response_value: :accepted,
        response_received_at: seed_datetime(day_offset: -2, hour: 9),
        algorithm_score: 91.0
      }
    )

    assignments[:confirmed_jordan_construction] = seed_assignment!(
      shift: shifts[:filled_construction],
      worker_profile: workers[:jordan],
      attributes: {
        status: :confirmed,
        assigned_by: :manual_admin,
        assigned_at: seed_datetime(day_offset: -2, hour: 10),
        accepted_at: seed_datetime(day_offset: -2, hour: 11),
        confirmed_at: seed_datetime(day_offset: -1, hour: 9),
        response_method: :app,
        response_value: :accepted,
        response_received_at: seed_datetime(day_offset: -2, hour: 11)
      }
    )

    # -------------------------------------------------------------------------
    # IN PROGRESS SHIFT - Workers checked in
    # -------------------------------------------------------------------------
    assignments[:checked_in_zoe_hotel] = seed_assignment!(
      shift: shifts[:in_progress_hotel],
      worker_profile: workers[:zoe],
      attributes: {
        status: :checked_in,
        assigned_by: :algorithm,
        assigned_at: seed_datetime(day_offset: -3, hour: 10),
        sms_sent_at: seed_datetime(day_offset: -3, hour: 10),
        sms_delivered_at: seed_datetime(day_offset: -3, hour: 10),
        accepted_at: seed_datetime(day_offset: -3, hour: 11),
        confirmed_at: seed_datetime(day_offset: -1, hour: 18),
        checked_in_at: seed_datetime(day_offset: 0, hour: 7),
        actual_start_time: seed_datetime(day_offset: 0, hour: 7),
        response_method: :sms,
        response_value: :accepted,
        response_received_at: seed_datetime(day_offset: -3, hour: 11),
        algorithm_score: 96.0
      }
    )

    assignments[:checked_in_maya_hotel] = seed_assignment!(
      shift: shifts[:in_progress_hotel],
      worker_profile: workers[:maya],
      attributes: {
        status: :checked_in,
        assigned_by: :worker_self_select,
        assigned_at: seed_datetime(day_offset: -2, hour: 14),
        accepted_at: seed_datetime(day_offset: -2, hour: 14),
        confirmed_at: seed_datetime(day_offset: -1, hour: 20),
        checked_in_at: seed_datetime(day_offset: 0, hour: 7),
        actual_start_time: seed_datetime(day_offset: 0, hour: 7),
        response_method: :app,
        response_value: :accepted,
        response_received_at: seed_datetime(day_offset: -2, hour: 14)
      }
    )

    # -------------------------------------------------------------------------
    # COMPLETED SHIFTS - Various completion scenarios
    # -------------------------------------------------------------------------

    # Completed cleaning shift
    assignments[:completed_zoe_cleaning] = seed_assignment!(
      shift: shifts[:completed_cleaning_1],
      worker_profile: workers[:zoe],
      attributes: {
        status: :completed,
        assigned_by: :algorithm,
        assigned_at: seed_datetime(day_offset: -7, hour: 10),
        sms_sent_at: seed_datetime(day_offset: -7, hour: 10),
        sms_delivered_at: seed_datetime(day_offset: -7, hour: 10),
        accepted_at: seed_datetime(day_offset: -7, hour: 11),
        confirmed_at: seed_datetime(day_offset: -4, hour: 18),
        checked_in_at: seed_datetime(day_offset: -3, hour: 8),
        actual_start_time: seed_datetime(day_offset: -3, hour: 8),
        checked_out_at: seed_datetime(day_offset: -3, hour: 14),
        actual_end_time: seed_datetime(day_offset: -3, hour: 14),
        actual_hours_worked: 6.0,
        timesheet_approved_at: seed_datetime(day_offset: -3, hour: 15),
        timesheet_approved_by_employer: employers[:liam],
        completed_successfully: true,
        worker_rating: 5,
        employer_rating: 5,
        worker_feedback: 'Great team environment, organized work.',
        employer_feedback: 'Excellent worker, arrived early and worked hard.',
        response_method: :sms,
        response_value: :accepted,
        response_received_at: seed_datetime(day_offset: -7, hour: 11),
        algorithm_score: 94.0
      }
    )

    assignments[:completed_riley_cleaning] = seed_assignment!(
      shift: shifts[:completed_cleaning_1],
      worker_profile: workers[:riley],
      attributes: {
        status: :completed,
        assigned_by: :manual_admin,
        assigned_at: seed_datetime(day_offset: -6, hour: 14),
        accepted_at: seed_datetime(day_offset: -6, hour: 15),
        confirmed_at: seed_datetime(day_offset: -4, hour: 16),
        checked_in_at: seed_datetime(day_offset: -3, hour: 8),
        actual_start_time: seed_datetime(day_offset: -3, hour: 8),
        checked_out_at: seed_datetime(day_offset: -3, hour: 14),
        actual_end_time: seed_datetime(day_offset: -3, hour: 14),
        actual_hours_worked: 6.0,
        timesheet_approved_at: seed_datetime(day_offset: -3, hour: 15),
        timesheet_approved_by_employer: employers[:liam],
        completed_successfully: true,
        worker_rating: 4,
        employer_rating: 4,
        response_method: :app,
        response_value: :accepted,
        response_received_at: seed_datetime(day_offset: -6, hour: 15)
      }
    )

    # Completed warehouse shift
    assignments[:completed_maya_warehouse] = seed_assignment!(
      shift: shifts[:completed_warehouse_1],
      worker_profile: workers[:maya],
      attributes: {
        status: :completed,
        assigned_by: :algorithm,
        assigned_at: seed_datetime(day_offset: -9, hour: 8),
        sms_sent_at: seed_datetime(day_offset: -9, hour: 8),
        sms_delivered_at: seed_datetime(day_offset: -9, hour: 8),
        accepted_at: seed_datetime(day_offset: -9, hour: 9),
        confirmed_at: seed_datetime(day_offset: -6, hour: 18),
        checked_in_at: seed_datetime(day_offset: -5, hour: 6),
        actual_start_time: seed_datetime(day_offset: -5, hour: 6),
        checked_out_at: seed_datetime(day_offset: -5, hour: 14),
        actual_end_time: seed_datetime(day_offset: -5, hour: 14),
        actual_hours_worked: 8.0,
        timesheet_approved_at: seed_datetime(day_offset: -5, hour: 15),
        timesheet_approved_by_employer: employers[:ava],
        completed_successfully: true,
        worker_rating: 5,
        employer_rating: 5,
        worker_feedback: 'Well organized warehouse.',
        employer_feedback: 'Maya is one of our best workers.',
        response_method: :sms,
        response_value: :accepted,
        response_received_at: seed_datetime(day_offset: -9, hour: 9),
        algorithm_score: 90.0
      }
    )

    assignments[:completed_jordan_warehouse] = seed_assignment!(
      shift: shifts[:completed_warehouse_1],
      worker_profile: workers[:jordan],
      attributes: {
        status: :completed,
        assigned_by: :algorithm,
        assigned_at: seed_datetime(day_offset: -9, hour: 9),
        sms_sent_at: seed_datetime(day_offset: -9, hour: 9),
        sms_delivered_at: seed_datetime(day_offset: -9, hour: 9),
        accepted_at: seed_datetime(day_offset: -9, hour: 10),
        confirmed_at: seed_datetime(day_offset: -6, hour: 19),
        checked_in_at: seed_datetime(day_offset: -5, hour: 6),
        actual_start_time: seed_datetime(day_offset: -5, hour: 6),
        checked_out_at: seed_datetime(day_offset: -5, hour: 14),
        actual_end_time: seed_datetime(day_offset: -5, hour: 14),
        actual_hours_worked: 8.0,
        timesheet_approved_at: seed_datetime(day_offset: -5, hour: 16),
        timesheet_approved_by_employer: employers[:ava],
        completed_successfully: true,
        worker_rating: 4,
        employer_rating: 4,
        response_method: :sms,
        response_value: :accepted,
        response_received_at: seed_datetime(day_offset: -9, hour: 10),
        algorithm_score: 82.0
      }
    )

    # No-show on warehouse shift
    assignments[:no_show_theo_warehouse] = seed_assignment!(
      shift: shifts[:completed_warehouse_1],
      worker_profile: workers[:theo],
      attributes: {
        status: :no_show,
        assigned_by: :algorithm,
        assigned_at: seed_datetime(day_offset: -9, hour: 10),
        sms_sent_at: seed_datetime(day_offset: -9, hour: 10),
        sms_delivered_at: seed_datetime(day_offset: -9, hour: 10),
        accepted_at: seed_datetime(day_offset: -9, hour: 12),
        confirmed_at: seed_datetime(day_offset: -6, hour: 17),
        no_show: true,
        completed_successfully: false,
        response_method: :sms,
        response_value: :accepted,
        response_received_at: seed_datetime(day_offset: -9, hour: 12),
        algorithm_score: 65.0
      }
    )

    # Completed event shift
    assignments[:completed_riley_event] = seed_assignment!(
      shift: shifts[:completed_event_1],
      worker_profile: workers[:riley],
      attributes: {
        status: :completed,
        assigned_by: :algorithm,
        assigned_at: seed_datetime(day_offset: -11, hour: 10),
        sms_sent_at: seed_datetime(day_offset: -11, hour: 10),
        sms_delivered_at: seed_datetime(day_offset: -11, hour: 10),
        accepted_at: seed_datetime(day_offset: -11, hour: 11),
        confirmed_at: seed_datetime(day_offset: -8, hour: 18),
        checked_in_at: seed_datetime(day_offset: -7, hour: 7),
        actual_start_time: seed_datetime(day_offset: -7, hour: 7),
        checked_out_at: seed_datetime(day_offset: -7, hour: 15),
        actual_end_time: seed_datetime(day_offset: -7, hour: 15),
        actual_hours_worked: 8.0,
        timesheet_approved_at: seed_datetime(day_offset: -7, hour: 16),
        timesheet_approved_by_employer: employers[:olivia],
        completed_successfully: true,
        worker_rating: 5,
        employer_rating: 5,
        response_method: :sms,
        response_value: :accepted,
        response_received_at: seed_datetime(day_offset: -11, hour: 11),
        algorithm_score: 88.0
      }
    )

    assignments[:completed_maya_event] = seed_assignment!(
      shift: shifts[:completed_event_1],
      worker_profile: workers[:maya],
      attributes: {
        status: :completed,
        assigned_by: :worker_self_select,
        assigned_at: seed_datetime(day_offset: -10, hour: 14),
        accepted_at: seed_datetime(day_offset: -10, hour: 14),
        confirmed_at: seed_datetime(day_offset: -8, hour: 20),
        checked_in_at: seed_datetime(day_offset: -7, hour: 7),
        actual_start_time: seed_datetime(day_offset: -7, hour: 7),
        checked_out_at: seed_datetime(day_offset: -7, hour: 15),
        actual_end_time: seed_datetime(day_offset: -7, hour: 15),
        actual_hours_worked: 8.0,
        timesheet_approved_at: seed_datetime(day_offset: -7, hour: 16),
        timesheet_approved_by_employer: employers[:olivia],
        completed_successfully: true,
        worker_rating: 5,
        employer_rating: 4,
        response_method: :app,
        response_value: :accepted,
        response_received_at: seed_datetime(day_offset: -10, hour: 14)
      }
    )

    assignments[:completed_zoe_event] = seed_assignment!(
      shift: shifts[:completed_event_1],
      worker_profile: workers[:zoe],
      attributes: {
        status: :completed,
        assigned_by: :algorithm,
        assigned_at: seed_datetime(day_offset: -11, hour: 11),
        sms_sent_at: seed_datetime(day_offset: -11, hour: 11),
        sms_delivered_at: seed_datetime(day_offset: -11, hour: 11),
        accepted_at: seed_datetime(day_offset: -11, hour: 12),
        confirmed_at: seed_datetime(day_offset: -8, hour: 17),
        checked_in_at: seed_datetime(day_offset: -7, hour: 7),
        actual_start_time: seed_datetime(day_offset: -7, hour: 7),
        checked_out_at: seed_datetime(day_offset: -7, hour: 15),
        actual_end_time: seed_datetime(day_offset: -7, hour: 15),
        actual_hours_worked: 8.0,
        timesheet_approved_at: seed_datetime(day_offset: -7, hour: 17),
        timesheet_approved_by_employer: employers[:olivia],
        completed_successfully: true,
        worker_rating: 5,
        employer_rating: 5,
        response_method: :sms,
        response_value: :accepted,
        response_received_at: seed_datetime(day_offset: -11, hour: 12),
        algorithm_score: 93.0
      }
    )

    assignments[:completed_jordan_event] = seed_assignment!(
      shift: shifts[:completed_event_1],
      worker_profile: workers[:jordan],
      attributes: {
        status: :completed,
        assigned_by: :manual_admin,
        assigned_at: seed_datetime(day_offset: -10, hour: 9),
        accepted_at: seed_datetime(day_offset: -10, hour: 10),
        confirmed_at: seed_datetime(day_offset: -8, hour: 19),
        checked_in_at: seed_datetime(day_offset: -7, hour: 7),
        actual_start_time: seed_datetime(day_offset: -7, hour: 7),
        checked_out_at: seed_datetime(day_offset: -7, hour: 15),
        actual_end_time: seed_datetime(day_offset: -7, hour: 15),
        actual_hours_worked: 8.0,
        timesheet_approved_at: seed_datetime(day_offset: -7, hour: 17),
        timesheet_approved_by_employer: employers[:olivia],
        completed_successfully: true,
        worker_rating: 4,
        employer_rating: 3,
        employer_feedback: 'Arrived on time but seemed distracted.',
        response_method: :app,
        response_value: :accepted,
        response_received_at: seed_datetime(day_offset: -10, hour: 10)
      }
    )

    # Completed construction shift
    assignments[:completed_carlos_demolition] = seed_assignment!(
      shift: shifts[:completed_construction_1],
      worker_profile: workers[:carlos],
      attributes: {
        status: :completed,
        assigned_by: :algorithm,
        assigned_at: seed_datetime(day_offset: -14, hour: 7),
        sms_sent_at: seed_datetime(day_offset: -14, hour: 7),
        sms_delivered_at: seed_datetime(day_offset: -14, hour: 7),
        accepted_at: seed_datetime(day_offset: -14, hour: 8),
        confirmed_at: seed_datetime(day_offset: -11, hour: 18),
        checked_in_at: seed_datetime(day_offset: -10, hour: 7),
        actual_start_time: seed_datetime(day_offset: -10, hour: 7),
        checked_out_at: seed_datetime(day_offset: -10, hour: 15),
        actual_end_time: seed_datetime(day_offset: -10, hour: 15),
        actual_hours_worked: 8.0,
        timesheet_approved_at: seed_datetime(day_offset: -10, hour: 16),
        timesheet_approved_by_employer: employers[:marcus],
        completed_successfully: true,
        worker_rating: 5,
        employer_rating: 5,
        worker_feedback: 'Good site, safety equipment provided.',
        employer_feedback: 'Carlos worked hard and followed all safety protocols.',
        response_method: :sms,
        response_value: :accepted,
        response_received_at: seed_datetime(day_offset: -14, hour: 8),
        algorithm_score: 91.0
      }
    )

    assignments[:completed_maya_demolition] = seed_assignment!(
      shift: shifts[:completed_construction_1],
      worker_profile: workers[:maya],
      attributes: {
        status: :completed,
        assigned_by: :algorithm,
        assigned_at: seed_datetime(day_offset: -14, hour: 8),
        sms_sent_at: seed_datetime(day_offset: -14, hour: 8),
        sms_delivered_at: seed_datetime(day_offset: -14, hour: 8),
        accepted_at: seed_datetime(day_offset: -14, hour: 9),
        confirmed_at: seed_datetime(day_offset: -11, hour: 19),
        checked_in_at: seed_datetime(day_offset: -10, hour: 7),
        actual_start_time: seed_datetime(day_offset: -10, hour: 7),
        checked_out_at: seed_datetime(day_offset: -10, hour: 15),
        actual_end_time: seed_datetime(day_offset: -10, hour: 15),
        actual_hours_worked: 8.0,
        timesheet_approved_at: seed_datetime(day_offset: -10, hour: 16),
        timesheet_approved_by_employer: employers[:marcus],
        completed_successfully: true,
        worker_rating: 4,
        employer_rating: 5,
        response_method: :sms,
        response_value: :accepted,
        response_received_at: seed_datetime(day_offset: -14, hour: 9),
        algorithm_score: 85.0
      }
    )

    assignments[:completed_jordan_demolition] = seed_assignment!(
      shift: shifts[:completed_construction_1],
      worker_profile: workers[:jordan],
      attributes: {
        status: :completed,
        assigned_by: :manual_admin,
        assigned_at: seed_datetime(day_offset: -13, hour: 10),
        accepted_at: seed_datetime(day_offset: -13, hour: 11),
        confirmed_at: seed_datetime(day_offset: -11, hour: 17),
        checked_in_at: seed_datetime(day_offset: -10, hour: 7),
        actual_start_time: seed_datetime(day_offset: -10, hour: 7),
        checked_out_at: seed_datetime(day_offset: -10, hour: 15),
        actual_end_time: seed_datetime(day_offset: -10, hour: 15),
        actual_hours_worked: 8.0,
        timesheet_approved_at: seed_datetime(day_offset: -10, hour: 17),
        timesheet_approved_by_employer: employers[:marcus],
        completed_successfully: true,
        worker_rating: 4,
        employer_rating: 4,
        response_method: :app,
        response_value: :accepted,
        response_received_at: seed_datetime(day_offset: -13, hour: 11)
      }
    )

    # -------------------------------------------------------------------------
    # CANCELLED SHIFT ASSIGNMENTS
    # -------------------------------------------------------------------------

    # Cancelled by employer (shift was cancelled)
    assignments[:cancelled_by_employer] = seed_assignment!(
      shift: shifts[:cancelled_weather],
      worker_profile: workers[:riley],
      attributes: {
        status: :cancelled,
        assigned_by: :algorithm,
        assigned_at: seed_datetime(day_offset: -2, hour: 10),
        sms_sent_at: seed_datetime(day_offset: -2, hour: 10),
        sms_delivered_at: seed_datetime(day_offset: -2, hour: 10),
        accepted_at: seed_datetime(day_offset: -2, hour: 11),
        cancelled_at: seed_datetime(day_offset: -1, hour: 7),
        cancelled_by: :employer,
        cancellation_reason: 'Shift cancelled due to weather.',
        response_method: :sms,
        response_value: :accepted,
        response_received_at: seed_datetime(day_offset: -2, hour: 11),
        algorithm_score: 87.0
      }
    )

    assignments[:cancelled_by_employer_2] = seed_assignment!(
      shift: shifts[:cancelled_weather],
      worker_profile: workers[:zoe],
      attributes: {
        status: :cancelled,
        assigned_by: :worker_self_select,
        assigned_at: seed_datetime(day_offset: -2, hour: 14),
        accepted_at: seed_datetime(day_offset: -2, hour: 14),
        cancelled_at: seed_datetime(day_offset: -1, hour: 7),
        cancelled_by: :employer,
        cancellation_reason: 'Shift cancelled due to weather.',
        response_method: :app,
        response_value: :accepted,
        response_received_at: seed_datetime(day_offset: -2, hour: 14)
      }
    )

    # Cancelled by worker
    assignments[:cancelled_by_worker] = seed_assignment!(
      shift: shifts[:cancelled_client],
      worker_profile: workers[:maya],
      attributes: {
        status: :cancelled,
        assigned_by: :algorithm,
        assigned_at: seed_datetime(day_offset: -2, hour: 9),
        sms_sent_at: seed_datetime(day_offset: -2, hour: 9),
        sms_delivered_at: seed_datetime(day_offset: -2, hour: 9),
        accepted_at: seed_datetime(day_offset: -2, hour: 10),
        cancelled_at: seed_datetime(day_offset: -1, hour: 14),
        cancelled_by: :worker,
        cancellation_reason: 'Family emergency.',
        response_method: :sms,
        response_value: :accepted,
        response_received_at: seed_datetime(day_offset: -2, hour: 10),
        algorithm_score: 88.0
      }
    )

    # No-response on posted shift
    assignments[:no_response_posted] = seed_assignment!(
      shift: shifts[:posted_loading],
      worker_profile: workers[:jordan],
      attributes: {
        status: :no_response,
        assigned_by: :algorithm,
        assigned_at: seed_datetime(day_offset: -1, hour: 10),
        sms_sent_at: seed_datetime(day_offset: -1, hour: 10),
        sms_delivered_at: seed_datetime(day_offset: -1, hour: 10),
        response_value: :no_response,
        algorithm_score: 75.0
      }
    )

    puts "  Created #{assignments.size} shift assignments"

    # ===========================================================================
    # UPDATE WORKER STATS FROM ACTUAL ASSIGNMENTS
    # ===========================================================================
    puts 'Calculating worker statistics from assignments...'

    workers.each do |key, worker|
      # Count actual assignments
      total_assigned = ShiftAssignment.where(worker_profile: worker).count
      total_completed = ShiftAssignment.where(worker_profile: worker, status: :completed).count
      no_shows = ShiftAssignment.where(worker_profile: worker, no_show: true).count

      # Calculate average rating from employer ratings
      ratings = ShiftAssignment.where(worker_profile: worker)
                               .where.not(employer_rating: nil)
                               .pluck(:employer_rating)
      avg_rating = ratings.any? ? (ratings.sum.to_f / ratings.size).round(1) : nil

      # Calculate average response time
      response_times = ShiftAssignment.where(worker_profile: worker)
                                      .where.not(sms_sent_at: nil)
                                      .where.not(response_received_at: nil)
                                      .pluck(:sms_sent_at, :response_received_at)
                                      .map { |sent, received| ((received - sent) / 60).round }
      avg_response = response_times.any? ? (response_times.sum / response_times.size) : nil

      worker.update!(
        total_shifts_assigned: total_assigned,
        total_shifts_completed: total_completed,
        no_show_count: no_shows,
        average_rating: avg_rating,
        average_response_time_minutes: avg_response
      )

      # Recalculate reliability score
      worker.update_reliability_score! if total_assigned.positive?
    end

    puts '  Updated worker statistics'

    # ===========================================================================
    # PAYMENTS - All statuses represented
    # ===========================================================================
    puts 'Creating payments...'

    # Completed payment
    seed_payment!(
      shift_assignment: assignments[:completed_zoe_cleaning],
      worker_profile: workers[:zoe],
      company: companies[:harbor],
      attributes: {
        amount_cents: 11400,  # 6 hours * $19/hr
        currency: 'USD',
        status: :completed,
        payment_method: :direct_deposit,
        processed_at: seed_datetime(day_offset: -2, hour: 12),
        external_transaction_id: 'txn_seed_0001',
        tax_year: 2026
      }
    )

    seed_payment!(
      shift_assignment: assignments[:completed_riley_cleaning],
      worker_profile: workers[:riley],
      company: companies[:harbor],
      attributes: {
        amount_cents: 11400,
        currency: 'USD',
        status: :completed,
        payment_method: :direct_deposit,
        processed_at: seed_datetime(day_offset: -2, hour: 12),
        external_transaction_id: 'txn_seed_0002',
        tax_year: 2026
      }
    )

    seed_payment!(
      shift_assignment: assignments[:completed_maya_warehouse],
      worker_profile: workers[:maya],
      company: companies[:northstar],
      attributes: {
        amount_cents: 14800,  # 8 hours * $18.50/hr
        currency: 'USD',
        status: :completed,
        payment_method: :direct_deposit,
        processed_at: seed_datetime(day_offset: -4, hour: 10),
        external_transaction_id: 'txn_seed_0003',
        tax_year: 2026
      }
    )

    seed_payment!(
      shift_assignment: assignments[:completed_jordan_warehouse],
      worker_profile: workers[:jordan],
      company: companies[:northstar],
      attributes: {
        amount_cents: 14800,
        currency: 'USD',
        status: :completed,
        payment_method: :check,
        processed_at: seed_datetime(day_offset: -4, hour: 10),
        external_transaction_id: 'txn_seed_0004',
        tax_year: 2026
      }
    )

    # Pending payment
    seed_payment!(
      shift_assignment: assignments[:completed_riley_event],
      worker_profile: workers[:riley],
      company: companies[:lonestar],
      attributes: {
        amount_cents: 16000,  # 8 hours * $20/hr
        currency: 'USD',
        status: :pending,
        payment_method: :direct_deposit,
        tax_year: 2026
      }
    )

    # Processing payment
    seed_payment!(
      shift_assignment: assignments[:completed_maya_event],
      worker_profile: workers[:maya],
      company: companies[:lonestar],
      attributes: {
        amount_cents: 16000,
        currency: 'USD',
        status: :processing,
        payment_method: :direct_deposit,
        processed_at: seed_datetime(day_offset: -1, hour: 9),
        tax_year: 2026
      }
    )

    # Failed payment
    seed_payment!(
      shift_assignment: assignments[:completed_zoe_event],
      worker_profile: workers[:zoe],
      company: companies[:lonestar],
      attributes: {
        amount_cents: 16000,
        currency: 'USD',
        status: :failed,
        payment_method: :direct_deposit,
        processed_at: seed_datetime(day_offset: -2, hour: 10),
        failed_at: seed_datetime(day_offset: -2, hour: 10),
        failure_reason: 'Bank account verification failed. Please update payment details.',
        tax_year: 2026
      }
    )

    # Refunded payment
    seed_payment!(
      shift_assignment: assignments[:completed_jordan_event],
      worker_profile: workers[:jordan],
      company: companies[:lonestar],
      attributes: {
        amount_cents: 16000,
        currency: 'USD',
        status: :refunded,
        payment_method: :check,
        processed_at: seed_datetime(day_offset: -5, hour: 11),
        refunded_at: seed_datetime(day_offset: -4, hour: 14),
        refund_reason: 'Duplicate payment - originally paid by cash on site.',
        external_transaction_id: 'txn_seed_0005',
        tax_year: 2026
      }
    )

    # Disputed payment
    seed_payment!(
      shift_assignment: assignments[:completed_carlos_demolition],
      worker_profile: workers[:carlos],
      company: companies[:quickbuild],
      attributes: {
        amount_cents: 16800,  # 8 hours * $21/hr
        currency: 'USD',
        status: :disputed,
        payment_method: :direct_deposit,
        processed_at: seed_datetime(day_offset: -9, hour: 10),
        disputed_at: seed_datetime(day_offset: -8, hour: 11),
        dispute_reason: 'Worker claims 9 hours worked, not 8. Reviewing time records.',
        external_transaction_id: 'txn_seed_0006',
        tax_year: 2026
      }
    )

    # More completed payments
    seed_payment!(
      shift_assignment: assignments[:completed_maya_demolition],
      worker_profile: workers[:maya],
      company: companies[:quickbuild],
      attributes: {
        amount_cents: 16800,
        currency: 'USD',
        status: :completed,
        payment_method: :direct_deposit,
        processed_at: seed_datetime(day_offset: -9, hour: 10),
        external_transaction_id: 'txn_seed_0007',
        tax_year: 2026
      }
    )

    seed_payment!(
      shift_assignment: assignments[:completed_jordan_demolition],
      worker_profile: workers[:jordan],
      company: companies[:quickbuild],
      attributes: {
        amount_cents: 16800,
        currency: 'USD',
        status: :completed,
        payment_method: :check,
        processed_at: seed_datetime(day_offset: -9, hour: 11),
        external_transaction_id: 'txn_seed_0008',
        tax_year: 2026
      }
    )

    puts '  Created payments in all statuses'

    # ===========================================================================
    # MESSAGES - All types and channels
    # ===========================================================================
    puts 'Creating messages...'

    # --- Shift Offer Messages (Outbound SMS) ---
    seed_message!(
      messageable: workers[:maya],
      attributes: {
        direction: :outbound,
        channel: :sms,
        message_type: :shift_offer,
        body: "Hi Maya! New shift available: Tech Expo Setup on Jan 24 at Austin Convention Center. $21/hr for 8 hours. Reply YES to accept or NO to decline.",
        from_phone: SHIFTREADY_PHONE,
        to_phone: workers[:maya].phone,
        shift: shifts[:recruiting_event],
        shift_assignment: assignments[:offered_maya_event],
        sms_status: :delivered,
        sent_at: seed_datetime(day_offset: -1, hour: 10),
        delivered_at: seed_datetime(day_offset: -1, hour: 10)
      }
    )

    seed_message!(
      messageable: workers[:riley],
      attributes: {
        direction: :outbound,
        channel: :sms,
        message_type: :shift_offer,
        body: "Hi Riley! New shift available: Tech Expo Setup on Jan 24 at Austin Convention Center. $21/hr for 8 hours. Reply YES to accept or NO to decline.",
        from_phone: SHIFTREADY_PHONE,
        to_phone: workers[:riley].phone,
        shift: shifts[:recruiting_event],
        shift_assignment: assignments[:accepted_riley_event],
        sms_status: :delivered,
        sent_at: seed_datetime(day_offset: -2, hour: 11),
        delivered_at: seed_datetime(day_offset: -2, hour: 11)
      }
    )

    # Worker response (Inbound SMS)
    seed_message!(
      messageable: workers[:riley],
      attributes: {
        direction: :inbound,
        channel: :sms,
        message_type: :general,
        body: "YES",
        from_phone: workers[:riley].phone,
        to_phone: SHIFTREADY_PHONE,
        shift: shifts[:recruiting_event],
        shift_assignment: assignments[:accepted_riley_event],
        sms_status: :delivered,
        sent_at: seed_datetime(day_offset: -2, hour: 12),
        delivered_at: seed_datetime(day_offset: -2, hour: 12)
      }
    )

    # Decline message
    seed_message!(
      messageable: workers[:jordan],
      attributes: {
        direction: :outbound,
        channel: :sms,
        message_type: :shift_offer,
        body: "Hi Jordan! New shift available: Tech Expo Setup on Jan 24 at Austin Convention Center. $21/hr for 8 hours. Reply YES to accept or NO to decline.",
        from_phone: SHIFTREADY_PHONE,
        to_phone: workers[:jordan].phone,
        shift: shifts[:recruiting_event],
        shift_assignment: assignments[:declined_jordan_event],
        sms_status: :delivered,
        sent_at: seed_datetime(day_offset: -2, hour: 9),
        delivered_at: seed_datetime(day_offset: -2, hour: 9)
      }
    )

    seed_message!(
      messageable: workers[:jordan],
      attributes: {
        direction: :inbound,
        channel: :sms,
        message_type: :general,
        body: "NO - I have a prior commitment that day, sorry!",
        from_phone: workers[:jordan].phone,
        to_phone: SHIFTREADY_PHONE,
        shift: shifts[:recruiting_event],
        shift_assignment: assignments[:declined_jordan_event],
        sms_status: :delivered,
        sent_at: seed_datetime(day_offset: -2, hour: 10),
        delivered_at: seed_datetime(day_offset: -2, hour: 10)
      }
    )

    # --- Confirmation Messages ---
    seed_message!(
      messageable: workers[:zoe],
      attributes: {
        direction: :outbound,
        channel: :sms,
        message_type: :confirmation,
        body: "Confirmed! You're all set for Conference Room Setup on Jan 23 at Harbor Hotel Downtown, 6AM-12PM. Reply HELP for arrival instructions.",
        from_phone: SHIFTREADY_PHONE,
        to_phone: workers[:zoe].phone,
        shift: shifts[:recruiting_hotel],
        shift_assignment: assignments[:confirmed_zoe_hotel],
        sms_status: :delivered,
        sent_at: seed_datetime(day_offset: -1, hour: 12),
        delivered_at: seed_datetime(day_offset: -1, hour: 12)
      }
    )

    # --- Reminder Messages ---
    seed_message!(
      messageable: workers[:zoe],
      attributes: {
        direction: :outbound,
        channel: :sms,
        message_type: :reminder,
        body: "Reminder: Your shift at Harbor Hotel Downtown starts tomorrow at 7:00 AM. Don't forget to check in when you arrive!",
        from_phone: SHIFTREADY_PHONE,
        to_phone: workers[:zoe].phone,
        shift: shifts[:in_progress_hotel],
        shift_assignment: assignments[:checked_in_zoe_hotel],
        sms_status: :delivered,
        sent_at: seed_datetime(day_offset: -1, hour: 18),
        delivered_at: seed_datetime(day_offset: -1, hour: 18)
      }
    )

    # --- Status Update Messages ---
    seed_message!(
      messageable: workers[:riley],
      attributes: {
        direction: :outbound,
        channel: :sms,
        message_type: :status_update,
        body: "Unfortunately, the Outdoor Event Setup shift on Jan 23 has been cancelled due to weather. You will still receive 2 hours pay for the inconvenience.",
        from_phone: SHIFTREADY_PHONE,
        to_phone: workers[:riley].phone,
        shift: shifts[:cancelled_weather],
        shift_assignment: assignments[:cancelled_by_employer],
        sms_status: :delivered,
        sent_at: seed_datetime(day_offset: -1, hour: 7),
        delivered_at: seed_datetime(day_offset: -1, hour: 7)
      }
    )

    # --- Failed SMS ---
    seed_message!(
      messageable: workers[:theo],
      attributes: {
        direction: :outbound,
        channel: :sms,
        message_type: :shift_offer,
        body: "Hi Theo! New shift available: Peak Season Support on Jan 15 at Dallas Fulfillment Center. Reply YES to accept.",
        from_phone: SHIFTREADY_PHONE,
        to_phone: workers[:theo].phone,
        shift: shifts[:completed_warehouse_1],
        sms_status: :failed,
        sent_at: seed_datetime(day_offset: -9, hour: 10),
        failed_at: seed_datetime(day_offset: -9, hour: 10),
        sms_error_code: '30003',
        sms_error_message: 'Unreachable destination handset'
      }
    )

    # --- Email Messages ---
    seed_message!(
      messageable: employers[:ava],
      attributes: {
        direction: :outbound,
        channel: :email,
        message_type: :status_update,
        subject: 'Shift Filled: Cross Dock Loaders',
        body: "Good news! Your shift 'Cross Dock Loaders' scheduled for Jan 22 has been fully staffed. All 3 workers have confirmed their attendance.\n\nWorkers assigned:\n- Maya Brooks\n- Jordan Lee\n- Riley Nguyen\n\nYou can view shift details in your dashboard.",
        sent_at: seed_datetime(day_offset: -2, hour: 16),
        delivered_at: seed_datetime(day_offset: -2, hour: 16)
      }
    )

    # --- In-App Messages ---
    seed_message!(
      messageable: workers[:maya],
      attributes: {
        direction: :outbound,
        channel: :in_app,
        message_type: :general,
        body: "Welcome to ShiftReady! Your account is now fully set up. You can start browsing available shifts in your area.",
        sent_at: seed_datetime(day_offset: -50, hour: 9),
        delivered_at: seed_datetime(day_offset: -50, hour: 9),
        read_at: seed_datetime(day_offset: -50, hour: 9)
      }
    )

    seed_message!(
      messageable: workers[:carlos],
      attributes: {
        direction: :outbound,
        channel: :in_app,
        message_type: :status_update,
        body: "Great job on the Demolition Cleanup shift! You earned a 5-star rating from QuickBuild Construction.",
        shift: shifts[:completed_construction_1],
        shift_assignment: assignments[:completed_carlos_demolition],
        sent_at: seed_datetime(day_offset: -10, hour: 17),
        delivered_at: seed_datetime(day_offset: -10, hour: 17),
        read_at: seed_datetime(day_offset: -10, hour: 18)
      }
    )

    # Unread in-app notification
    seed_message!(
      messageable: workers[:zoe],
      attributes: {
        direction: :outbound,
        channel: :in_app,
        message_type: :general,
        body: "You have a payment issue. Your last payment failed due to bank verification. Please update your payment details.",
        sent_at: seed_datetime(day_offset: -2, hour: 11),
        delivered_at: seed_datetime(day_offset: -2, hour: 11)
        # No read_at - unread
      }
    )

    puts '  Created messages in all types and channels'

    # ===========================================================================
    # BLOCK LIST
    # ===========================================================================
    puts 'Creating block list entries...'

    # Company blocked a worker (due to no-show)
    seed_block!(
      blocker: companies[:northstar],
      blocked: workers[:theo],
      reason: 'Multiple no-shows. Not eligible for future shifts with this company.'
    )

    # Worker blocked a company
    seed_block!(
      blocker: workers[:jordan],
      blocked: companies[:defunct],
      reason: 'Bad experience with management. Do not want to work with this company again.'
    )

    puts '  Created block list entries'

    # ===========================================================================
    # SUMMARY
    # ===========================================================================
    puts
    puts '=' * 70
    puts 'Seed Data Summary'
    puts '=' * 70
    puts
    puts "Companies:           #{Company.count} (#{Company.active.count} active)"
    puts "Work Locations:      #{WorkLocation.count} (#{WorkLocation.active.count} active)"
    puts "Users:               #{User.count}"
    puts "  - Admins:          #{User.admin.count}"
    puts "  - Employers:       #{User.employer.count}"
    puts "  - Workers:         #{User.worker.count}"
    puts "Employer Profiles:   #{EmployerProfile.count} (#{EmployerProfile.onboarded.count} onboarded)"
    puts "Worker Profiles:     #{WorkerProfile.count} (#{WorkerProfile.active.onboarded.count} active & onboarded)"
    puts "Shifts:              #{Shift.count}"
    puts "  - Draft:           #{Shift.draft.count}"
    puts "  - Posted:          #{Shift.posted.count}"
    puts "  - Recruiting:      #{Shift.recruiting.count}"
    puts "  - Filled:          #{Shift.filled.count}"
    puts "  - In Progress:     #{Shift.in_progress.count}"
    puts "  - Completed:       #{Shift.completed.count}"
    puts "  - Cancelled:       #{Shift.cancelled.count}"
    puts "Shift Assignments:   #{ShiftAssignment.count}"
    puts "  - Offered:         #{ShiftAssignment.offered.count}"
    puts "  - Accepted:        #{ShiftAssignment.accepted.count}"
    puts "  - Declined:        #{ShiftAssignment.declined.count}"
    puts "  - No Response:     #{ShiftAssignment.no_response.count}"
    puts "  - Confirmed:       #{ShiftAssignment.confirmed.count}"
    puts "  - Checked In:      #{ShiftAssignment.checked_in.count}"
    puts "  - No Show:         #{ShiftAssignment.no_show.count}"
    puts "  - Completed:       #{ShiftAssignment.completed.count}"
    puts "  - Cancelled:       #{ShiftAssignment.cancelled.count}"
    puts "Payments:            #{Payment.count}"
    puts "  - Pending:         #{Payment.pending.count}"
    puts "  - Processing:      #{Payment.processing.count}"
    puts "  - Completed:       #{Payment.completed.count}"
    puts "  - Failed:          #{Payment.failed.count}"
    puts "  - Refunded:        #{Payment.refunded.count}"
    puts "  - Disputed:        #{Payment.disputed.count}"
    puts "Messages:            #{Message.count}"
    puts "Block List:          #{BlockList.count}"
    puts
    puts 'Login Credentials (all use password: "password"):'
    puts '-' * 50
    puts 'Admin:     admin@shiftready.test'
    puts 'Employers: ava.employer@shiftready.test (Northstar, full access)'
    puts '           noah.employer@shiftready.test (Northstar, approve only)'
    puts '           olivia.employer@shiftready.test (Lone Star Events)'
    puts '           liam.employer@shiftready.test (Harbor Hospitality)'
    puts '           marcus.employer@shiftready.test (QuickBuild)'
    puts '           emma.employer@shiftready.test (not onboarded)'
    puts 'Workers:   maya.worker@shiftready.test (Dallas, high performer)'
    puts '           jordan.worker@shiftready.test (Plano, medium)'
    puts '           riley.worker@shiftready.test (Austin)'
    puts '           zoe.worker@shiftready.test (Houston, excellent)'
    puts '           theo.worker@shiftready.test (inactive)'
    puts '           carlos.worker@shiftready.test (San Antonio)'
    puts '           alex.worker@shiftready.test (not onboarded)'
    puts '           sam.worker@shiftready.test (brand new)'
    puts
    puts '=' * 70
    puts 'Seed data loaded successfully!'
    puts '=' * 70

  ensure
    # Re-enable the callback
    User.set_callback(:create, :after, :create_profile_for_role)
  end
end
