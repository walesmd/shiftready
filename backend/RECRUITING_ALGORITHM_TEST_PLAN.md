# Recruiting Algorithm Manual Test Plan

This document provides step-by-step instructions to manually verify the recruiting algorithm is running and operating correctly.

## Prerequisites

1. Rails console access: `rails console`
2. Database with seed data or ability to create test records
3. Solid Queue running (for background jobs)

---

## 1. Verify Background Job Infrastructure

### 1.1 Check Solid Queue is Running

```bash
# In a separate terminal, start Solid Queue
bin/jobs

# Or check if it's already running
ps aux | grep solid_queue
```

### 1.2 Verify Recurring Job Configuration

```ruby
# In rails console
puts File.read(Rails.root.join('config/recurring.yml'))

# Should show shift_recruiting_discovery job scheduled every 5 minutes
```

---

## 2. Create Test Data

### 2.1 Create a Company with Work Location

```ruby
# In rails console
company = Company.create!(
  name: "Test Recruiting Company",
  industry: "warehousing",
  is_active: true
)

work_location = WorkLocation.create!(
  company: company,
  name: "Test Warehouse",
  address_line_1: "123 Test St",
  city: "San Antonio",
  state: "TX",
  zip_code: "78201",
  latitude: 29.4241,
  longitude: -98.4936
)

# Create employer
user = User.create!(
  email: "test-employer-#{Time.now.to_i}@example.com",
  password: "password123",
  role: :employer
)

employer = EmployerProfile.create!(
  user: user,
  company: company,
  first_name: "Test",
  last_name: "Employer",
  phone: "+12105550001",
  onboarding_completed: true,
  can_post_shifts: true
)

puts "Company ID: #{company.id}"
puts "Work Location ID: #{work_location.id}"
puts "Employer ID: #{employer.id}"
```

### 2.2 Create Eligible Workers

```ruby
# Create 3 workers with varying scores
workers = []

# Worker 1: High score (close, reliable, experienced)
user1 = User.create!(email: "worker1-#{Time.now.to_i}@example.com", password: "password123", role: :worker)
worker1 = WorkerProfile.create!(
  user: user1,
  first_name: "Alice",
  last_name: "TopWorker",
  phone: "+12105551001",
  address_line_1: "100 Close St",
  city: "San Antonio",
  state: "TX",
  zip_code: "78201",
  latitude: 29.4261,      # Very close to work location (~0.5 miles)
  longitude: -98.4956,
  is_active: true,
  onboarding_completed: true,
  ssn_encrypted: "encrypted123",
  reliability_score: 95.0,
  average_rating: 4.8,
  average_response_time_minutes: 3,
  total_shifts_completed: 25,
  terms_accepted_at: Time.current,
  sms_consent_given_at: Time.current
)
WorkerPreferredJobType.create!(worker_profile: worker1, job_type: "warehouse")
# Add availability for next 7 days
(0..6).each do |day|
  WorkerAvailability.create!(worker_profile: worker1, day_of_week: day, start_time: "06:00", end_time: "22:00")
end
workers << worker1

# Worker 2: Medium score
user2 = User.create!(email: "worker2-#{Time.now.to_i}@example.com", password: "password123", role: :worker)
worker2 = WorkerProfile.create!(
  user: user2,
  first_name: "Bob",
  last_name: "MidWorker",
  phone: "+12105551002",
  address_line_1: "200 Mid St",
  city: "San Antonio",
  state: "TX",
  zip_code: "78205",
  latitude: 29.4541,      # ~5 miles away
  longitude: -98.4936,
  is_active: true,
  onboarding_completed: true,
  ssn_encrypted: "encrypted123",
  reliability_score: 70.0,
  average_rating: 4.0,
  average_response_time_minutes: 12,
  total_shifts_completed: 8,
  terms_accepted_at: Time.current,
  sms_consent_given_at: Time.current
)
WorkerPreferredJobType.create!(worker_profile: worker2, job_type: "warehouse")
(0..6).each do |day|
  WorkerAvailability.create!(worker_profile: worker2, day_of_week: day, start_time: "06:00", end_time: "22:00")
end
workers << worker2

# Worker 3: Lower score
user3 = User.create!(email: "worker3-#{Time.now.to_i}@example.com", password: "password123", role: :worker)
worker3 = WorkerProfile.create!(
  user: user3,
  first_name: "Carol",
  last_name: "NewWorker",
  phone: "+12105551003",
  address_line_1: "300 Far St",
  city: "San Antonio",
  state: "TX",
  zip_code: "78210",
  latitude: 29.3841,      # ~10 miles away
  longitude: -98.4936,
  is_active: true,
  onboarding_completed: true,
  ssn_encrypted: "encrypted123",
  reliability_score: 50.0,
  average_rating: 3.5,
  average_response_time_minutes: 25,
  total_shifts_completed: 2,
  terms_accepted_at: Time.current,
  sms_consent_given_at: Time.current
)
WorkerPreferredJobType.create!(worker_profile: worker3, job_type: "warehouse")
(0..6).each do |day|
  WorkerAvailability.create!(worker_profile: worker3, day_of_week: day, start_time: "06:00", end_time: "22:00")
end
workers << worker3

puts "Created workers: #{workers.map { |w| "#{w.full_name} (ID: #{w.id})" }.join(', ')}"
```

---

## 3. Test Shift Creation (Status = Posted)

### 3.1 Create a Shift via API or Console

```ruby
# Via console - simulating what the controller does
shift = Shift.new(
  company: company,
  work_location: work_location,
  created_by_employer: employer,
  title: "Test Warehouse Shift",
  description: "Testing the recruiting algorithm",
  job_type: "warehouse",
  start_datetime: 3.days.from_now.change(hour: 8),
  end_datetime: 3.days.from_now.change(hour: 16),
  pay_rate_cents: 1800,
  slots_total: 2,
  slots_filled: 0,
  status: :posted,
  posted_at: Time.current
)
shift.save!

puts "Shift created: #{shift.tracking_code} (ID: #{shift.id})"
puts "Status: #{shift.status}"
puts "Posted at: #{shift.posted_at}"
```

### 3.2 Verify Shift Status

```ruby
shift.reload
puts "Status: #{shift.status}"           # Should be "posted"
puts "Posted at: #{shift.posted_at}"     # Should have timestamp
```

---

## 4. Test Discovery Job

### 4.1 Run Discovery Job Manually

```ruby
# Run the discovery job
ShiftRecruitingDiscoveryJob.perform_now

# Check if shift transitioned to recruiting
shift.reload
puts "Status after discovery: #{shift.status}"  # Should be "recruiting"
puts "Recruiting started at: #{shift.recruiting_started_at}"
```

### 4.2 Verify Activity Log

```ruby
logs = RecruitingActivityLog.where(shift: shift).order(:created_at)
logs.each do |log|
  puts "[#{log.created_at.strftime('%H:%M:%S')}] #{log.action}: #{log.details}"
end

# Should see:
# - recruiting_started with slots_total, slots_filled, start_datetime
```

---

## 5. Test Worker Scoring

### 5.1 View Ranked Workers

```ruby
service = RecruitingAlgorithmService.new(shift)
ranked = service.ranked_eligible_workers

ranked.each_with_index do |result, index|
  puts "\n##{index + 1}: #{result[:worker].full_name}"
  puts "  Total Score: #{result[:score]}"
  puts "  Distance: #{result[:distance_miles].round(2)} miles"
  puts "  Breakdown:"
  result[:score_breakdown].each do |factor, points|
    puts "    #{factor}: #{points}"
  end
end
```

### 5.2 Verify Scoring Logic

Expected output should show:
- Worker 1 (Alice) has highest score (~95+ points)
- Worker 2 (Bob) has medium score (~70+ points)
- Worker 3 (Carol) has lower score (~55+ points)

Score breakdown (110 max):
| Factor | Max | Description |
|--------|-----|-------------|
| Distance | 30 | 0-5mi=30, 5-10=25, 10-15=20, 15-20=15, 20-25=10 |
| Reliability | 25 | reliability_score scaled 0-25 |
| Job Type | 20 | exact match + history=20, preference only=10 |
| Rating | 15 | rating scaled (new workers=10) |
| Response Time | 10 | <5min=10, 5-15=8, 15-30=5, >30=2 |
| Experience | 10 | 0.5 per completed shift, capped |

---

## 6. Test Offer Creation

### 6.1 Run Process Job Manually

```ruby
ProcessShiftRecruitingJob.perform_now(shift.id)

# Check assignment created
assignment = shift.shift_assignments.last
puts "Assignment created for: #{assignment.worker_profile.full_name}"
puts "Status: #{assignment.status}"
puts "Algorithm score: #{assignment.algorithm_score}"
puts "Distance: #{assignment.distance_miles} miles"
puts "SMS sent at: #{assignment.sms_sent_at}"
```

### 6.2 Verify Activity Logs

```ruby
logs = RecruitingActivityLog.where(shift: shift).order(:created_at)
logs.each do |log|
  worker_name = log.worker_profile&.full_name || "N/A"
  puts "[#{log.created_at.strftime('%H:%M:%S')}] #{log.action} - Worker: #{worker_name}"
  puts "  Details: #{log.details}"
end

# Should see:
# - next_worker_selected (highest scored worker)
# - offer_sent with rank, algorithm_score, distance_miles
```

---

## 7. Test Offer Responses

### 7.1 Test Acceptance

```ruby
assignment = shift.shift_assignments.pending_response.first
service = ShiftOfferService.new(shift)
service.handle_acceptance(assignment)

assignment.reload
puts "Status after acceptance: #{assignment.status}"  # Should be "accepted"
puts "Shift slots filled: #{shift.reload.slots_filled}"  # Should increment

# Check logs
log = RecruitingActivityLog.find_by(shift: shift, action: "offer_accepted")
puts "Acceptance logged: #{log.present?}"
```

### 7.2 Test Decline

```ruby
# First, create another offer
ProcessShiftRecruitingJob.perform_now(shift.id)
assignment = shift.shift_assignments.pending_response.first

service = ShiftOfferService.new(shift)
service.handle_decline(assignment, reason: "schedule_conflict")

assignment.reload
puts "Status after decline: #{assignment.status}"  # Should be "declined"

# Check logs
log = RecruitingActivityLog.find_by(shift: shift, action: "offer_declined")
puts "Decline logged: #{log.present?}"
puts "Reason: #{log.details['reason']}"
```

### 7.3 Test Timeout

```ruby
# Create a new shift for timeout testing
shift2 = Shift.create!(
  company: company,
  work_location: work_location,
  created_by_employer: employer,
  title: "Timeout Test Shift",
  description: "Testing timeout",
  job_type: "warehouse",
  start_datetime: 4.days.from_now.change(hour: 8),
  end_datetime: 4.days.from_now.change(hour: 16),
  pay_rate_cents: 1800,
  slots_total: 1,
  status: :recruiting,
  recruiting_started_at: Time.current
)

# Create offer
ProcessShiftRecruitingJob.perform_now(shift2.id)
assignment = shift2.shift_assignments.pending_response.first

# Simulate timeout (normally scheduled 15 min later)
CheckOfferTimeoutJob.perform_now(assignment.id)

assignment.reload
puts "Status after timeout: #{assignment.status}"  # Should be "no_response"

# Check logs
log = RecruitingActivityLog.find_by(shift: shift2, action: "offer_timeout")
puts "Timeout logged: #{log.present?}"
```

---

## 8. Test Auto-Resume on Cancellation

### 8.1 Setup: Create Filled Shift

```ruby
# Create a shift that's been filled
shift3 = Shift.create!(
  company: company,
  work_location: work_location,
  created_by_employer: employer,
  title: "Resume Test Shift",
  description: "Testing auto-resume",
  job_type: "warehouse",
  start_datetime: 5.days.from_now.change(hour: 8),
  end_datetime: 5.days.from_now.change(hour: 16),
  pay_rate_cents: 1800,
  slots_total: 2,
  slots_filled: 2,
  status: :filled,
  filled_at: Time.current
)

# Create accepted assignments
assignment1 = ShiftAssignment.create!(
  shift: shift3,
  worker_profile: workers[0],
  status: :accepted,
  assigned_at: 1.hour.ago,
  accepted_at: Time.current
)
assignment2 = ShiftAssignment.create!(
  shift: shift3,
  worker_profile: workers[1],
  status: :accepted,
  assigned_at: 1.hour.ago,
  accepted_at: Time.current
)

puts "Shift status: #{shift3.status}"
puts "Slots filled: #{shift3.slots_filled}"
```

### 8.2 Cancel an Assignment

```ruby
# Cancel one assignment
assignment1.cancel!(by: :worker, reason: "Personal emergency")

# The callback should have enqueued ResumeRecruitingJob
# Run it manually to see immediate results
ResumeRecruitingJob.perform_now(shift3.id)

shift3.reload
puts "Shift status after cancel: #{shift3.status}"  # Should be "recruiting"
puts "Slots filled: #{shift3.slots_filled}"  # Should be 1

# Check logs
log = RecruitingActivityLog.find_by(shift: shift3, action: "recruiting_resumed")
puts "Resume logged: #{log.present?}"
```

### 8.3 Verify 24-Hour Restriction

```ruby
# Create a shift starting within 24 hours
shift4 = Shift.create!(
  company: company,
  work_location: work_location,
  created_by_employer: employer,
  title: "Soon Shift",
  description: "Starting soon",
  job_type: "warehouse",
  start_datetime: 12.hours.from_now,
  end_datetime: 20.hours.from_now,
  pay_rate_cents: 1800,
  slots_total: 2,
  slots_filled: 2,
  status: :filled,
  filled_at: Time.current
)

assignment = ShiftAssignment.create!(
  shift: shift4,
  worker_profile: workers[2],
  status: :accepted,
  assigned_at: 1.hour.ago,
  accepted_at: Time.current
)

# Cancel and try to resume
assignment.cancel!(by: :worker, reason: "Emergency")
ResumeRecruitingJob.perform_now(shift4.id)

shift4.reload
puts "Shift status (should stay filled): #{shift4.status}"  # Should still be "filled"
```

---

## 9. Test Eligibility Filters

### 9.1 Test Distance Exclusion (>25 miles)

```ruby
# Create worker too far away
user_far = User.create!(email: "far-worker-#{Time.now.to_i}@example.com", password: "password123", role: :worker)
worker_far = WorkerProfile.create!(
  user: user_far,
  first_name: "Far",
  last_name: "Away",
  phone: "+12105551099",
  address_line_1: "999 Distant Rd",
  city: "Austin",
  state: "TX",
  zip_code: "78701",
  latitude: 30.2672,      # Austin - ~80 miles away
  longitude: -97.7431,
  is_active: true,
  onboarding_completed: true,
  ssn_encrypted: "encrypted123",
  terms_accepted_at: Time.current,
  sms_consent_given_at: Time.current
)
WorkerPreferredJobType.create!(worker_profile: worker_far, job_type: "warehouse")
(0..6).each { |day| WorkerAvailability.create!(worker_profile: worker_far, day_of_week: day, start_time: "06:00", end_time: "22:00") }

# Check eligibility
service = RecruitingAlgorithmService.new(shift)
eligible = service.eligible_workers
puts "Far worker eligible: #{eligible.include?(worker_far)}"  # Should be false
```

### 9.2 Test Block List Exclusion

```ruby
# Block worker from company
BlockList.create!(blocker: company, blocked: workers[2])

service = RecruitingAlgorithmService.new(shift)
eligible = service.eligible_workers
puts "Blocked worker eligible: #{eligible.include?(workers[2])}"  # Should be false

# Cleanup
BlockList.where(blocker: company, blocked: workers[2]).destroy_all
```

### 9.3 Test Already-Offered Exclusion

```ruby
# Check that already-offered workers are excluded from next_best_worker
offered_worker_ids = shift.shift_assignments.pluck(:worker_profile_id)
service = RecruitingAlgorithmService.new(shift)
next_worker = service.next_best_worker

if next_worker
  puts "Next worker ID: #{next_worker[:worker].id}"
  puts "Already offered: #{offered_worker_ids.include?(next_worker[:worker].id)}"  # Should be false
else
  puts "No more eligible workers"
end
```

---

## 10. Verify Observability API

### 10.1 Test API Endpoint

```bash
# Get JWT token first (replace with valid credentials)
TOKEN=$(curl -s -X POST http://localhost:3001/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"test-employer@example.com","password":"password123"}}' \
  | jq -r '.token')

# Fetch recruiting activity logs
curl -s http://localhost:3001/api/v1/shifts/SHIFT_ID/recruiting_activity_logs \
  -H "Authorization: Bearer $TOKEN" | jq
```

### 10.2 Verify via Console

```ruby
# Check API response structure
shift_id = shift.id
logs = RecruitingActivityLog.where(shift_id: shift_id).includes(:worker_profile, :shift_assignment).chronological

logs.map do |log|
  {
    id: log.id,
    action: log.action,
    source: log.source,
    details: log.details,
    worker: log.worker_profile&.full_name,
    assignment_id: log.shift_assignment_id,
    created_at: log.created_at
  }
end
```

---

## 11. Monitor Recurring Job

### 11.1 Check Job Execution

```ruby
# Check Solid Queue for scheduled/completed jobs
SolidQueue::Job.where("class_name LIKE ?", "%Recruiting%").order(created_at: :desc).limit(10).each do |job|
  puts "#{job.class_name} - Status: #{job.finished_at ? 'finished' : 'pending'} - Created: #{job.created_at}"
end
```

### 11.2 Check for Errors

```ruby
# Check for failed jobs
SolidQueue::FailedExecution.includes(:job).where("solid_queue_jobs.class_name LIKE ?", "%Recruiting%").each do |failure|
  puts "Failed: #{failure.job.class_name}"
  puts "Error: #{failure.error}"
end
```

---

## 12. Complete Workflow Test

Run this complete test to verify the entire workflow:

```ruby
# 1. Create fresh shift
test_shift = Shift.create!(
  company: company,
  work_location: work_location,
  created_by_employer: employer,
  title: "Full Workflow Test #{Time.now.to_i}",
  description: "Complete workflow verification",
  job_type: "warehouse",
  start_datetime: 3.days.from_now.change(hour: 9),
  end_datetime: 3.days.from_now.change(hour: 17),
  pay_rate_cents: 2000,
  slots_total: 2,
  status: :posted,
  posted_at: Time.current
)
puts "1. Created shift #{test_shift.tracking_code} with status: #{test_shift.status}"

# 2. Discovery
ShiftRecruitingDiscoveryJob.perform_now
test_shift.reload
puts "2. After discovery, status: #{test_shift.status}"

# 3. First offer
ProcessShiftRecruitingJob.perform_now(test_shift.id)
first_assignment = test_shift.shift_assignments.last
puts "3. First offer to: #{first_assignment.worker_profile.full_name} (score: #{first_assignment.algorithm_score})"

# 4. Decline first offer
ShiftOfferService.new(test_shift).handle_decline(first_assignment, reason: "busy")
puts "4. Declined first offer"

# 5. Second offer (auto-queued, run manually)
ProcessShiftRecruitingJob.perform_now(test_shift.id)
second_assignment = test_shift.shift_assignments.pending_response.first
puts "5. Second offer to: #{second_assignment.worker_profile.full_name} (score: #{second_assignment.algorithm_score})"

# 6. Accept second offer
ShiftOfferService.new(test_shift).handle_acceptance(second_assignment)
test_shift.reload
puts "6. Accepted. Slots filled: #{test_shift.slots_filled}/#{test_shift.slots_total}"

# 7. Third offer (auto-queued for remaining slot)
ProcessShiftRecruitingJob.perform_now(test_shift.id)
third_assignment = test_shift.shift_assignments.pending_response.first
if third_assignment
  puts "7. Third offer to: #{third_assignment.worker_profile.full_name}"

  # 8. Accept to fill shift
  ShiftOfferService.new(test_shift).handle_acceptance(third_assignment)
  test_shift.reload
  puts "8. Final status: #{test_shift.status}, slots: #{test_shift.slots_filled}/#{test_shift.slots_total}"
else
  puts "7. No more eligible workers available"
end

# 9. Show all activity logs
puts "\n--- Activity Log ---"
RecruitingActivityLog.where(shift: test_shift).chronological.each do |log|
  worker = log.worker_profile&.full_name || "N/A"
  puts "[#{log.created_at.strftime('%H:%M:%S')}] #{log.action.ljust(25)} | Worker: #{worker.ljust(20)} | #{log.details.slice('score', 'rank', 'reason', 'slots_filled')}"
end
```

---

## Troubleshooting

### No Workers Being Discovered

Check eligibility requirements:
```ruby
service = RecruitingAlgorithmService.new(shift)

# Check base query
puts "Active & onboarded: #{WorkerProfile.active.onboarded.count}"
puts "Available at shift time: #{WorkerProfile.active.onboarded.available_at(shift.start_datetime).count}"
puts "With job type preference: #{WorkerProfile.active.onboarded.with_job_type_preference(shift.job_type).count}"
puts "With coordinates: #{WorkerProfile.active.onboarded.with_coordinates.count}"
```

### Jobs Not Running

```ruby
# Check Solid Queue status
puts "Pending jobs: #{SolidQueue::Job.where(finished_at: nil).count}"
puts "Ready jobs: #{SolidQueue::ReadyExecution.count}"

# Manually process queue
SolidQueue::Dispatcher.new.start
```

### Distance Calculation Issues

```ruby
# Verify coordinates
puts "Work location: #{shift.work_location.latitude}, #{shift.work_location.longitude}"
workers.each do |w|
  service = RecruitingAlgorithmService.new(shift)
  distance = service.send(:calculate_distance, w)
  puts "#{w.full_name}: #{w.latitude}, #{w.longitude} -> #{distance.round(2)} miles"
end
```
