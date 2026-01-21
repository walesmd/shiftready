# Architecture (to be reviewed)

## Overview

This document outlines high-level concepts on how this application should be architected and function. The author has experience developing this sort of application in the past, but is open to feedback and collaborative thinking on how to improve this functionality.

This document will only cover high-level operational concepts - they should be interpreted and reconsidered based upon the tech stack that is being used in this iteration of the product.

This iteration of the product is intended to combat some of the downsides of the previous iteration, which was successful but needed to be shuttered due to COVID. Some of the problems with the previous iteration:

1. A larger team to maintain and manage the company than is probably necessary these days. Previous iteration had about 20 people, 10 on the Engineering and Product side and 10 on the Operational side. We believe we can operate this company much more lean this time around.
2. The previous iteration was funded by a Fortune 500. We're going to bootstrap this iteration.
3. The previous iteration utilized W-2 employees. This time we will likely make all employees 1099 employees.

## Key Data Points

### Users

Initially, we need 3 types of users:

1. Workers: These are the users that will be accepting and fulfilling shifts on the platform. Workers must provide a functional phone number and/or email address which is unique to them. When a job opportunity is posted, a recruiting algorithm (the algorithm) will find the best candidate for the job (based on a variety of data points) and send text messages to these users asking them if they want the job. These are the users that will get paid by the company when they have finished their work.

2. Employers: These are the users that are putting job opportunities into the platform. An employer has a company and that company is a client of our who pays our company directly for providing workers to them. Employers can enter job opportunities into their dashboard, the algorithm will start recruiting against them, and let them know when a worker has been found and the details of that workers profile. Employers should be able to see the status of our recruiting efforts and their job fulfillment at all times.

3. Administrators: These are employees of our company and should have visibility into everything on the platform. Their main goal is to ensure the platform is running appropriately, address any customer satisfaction issues, and take action on the platform on behalf of any other user if they need to do so.

All users must have:
- A unique phone number
- A unique email address
- A first name and last name

Worker type users must have an address that we geolocate into a latitude and longitude, as well as work preferences.

### Companies

An employer belongs to a company.

### Work Locations

A work location belongs to an employer. It has an address which we have geolocated. It may also have unique arrival instructions or notes to help workers arrive at the correct place.

### Shifts / Job Opportunities

A shift belongs to a company and is assigned to a specific work location. It has a starting date time, and ending date time, a rate (per hour), and a description of what the job entails.

## The Algorithm

This is the most important part of the whole system. The goal of the system is to find the PERFECT employee for any given job opportunity - based upon their past work performance, the likelihood they are a good fit for the job, their availability, and their distance from the work location. In a perfect world, the system would send one text per open position and that position would get filled because the algorithm is so good at identifying the right person. This will not happen from the beginning but should be a key target area for future iteration and improvement.

## Temporal Data

This is an automated recruiting platform, so observability into what the algorithm is doing is CRITICAL to the success of this platform. Any action - like identifying a candidate, sending a text to a candidate, getting a response, them filling a shift, us paying them for their shift, we want timestamps and a unique transaction record such that we can trace the in-system lifecycle of any engagement from beginning to end.

## Shift Assignment Lifecycle States

A shift assignment moves through these states:

1. **offered** - Worker has been identified by algorithm and sent SMS offer
2. **accepted** - Worker replied YES to SMS offer
3. **declined** - Worker replied NO to SMS offer
4. **no_response** - Worker didn't respond within timeout period (15 min default)
5. **confirmed** - Employer confirms worker is still expected (day before shift)
6. **checked_in** - Worker has arrived and clocked in
7. **no_show** - Worker didn't show up for confirmed shift
8. **completed** - Shift finished, worker clocked out
9. **cancelled** - Shift cancelled by worker, employer, or admin

A shift itself has states:
- **draft** - Being created, not yet posted
- **posted** - Visible but recruiting hasn't started
- **recruiting** - Algorithm actively finding workers
- **filled** - All slots filled with accepted workers
- **in_progress** - Shift is currently happening
- **completed** - Shift finished
- **cancelled** - Shift cancelled before completion

## Worker Performance Metrics

The algorithm relies heavily on past performance data. We track:

1. **Reliability Score** (0-100): Composite metric calculated from:
   - Attendance rate: (completed shifts / accepted shifts) * 100
   - No-show penalty: -20 points per no-show in last 30 days
   - Cancellation penalty: -10 points per worker cancellation in last 30 days

2. **Average Rating** (1.0-5.0): Mean of employer ratings after shift completion

3. **Completion Rate**: (completed shifts / total shifts assigned) * 100

4. **Response Time**: Average minutes from SMS sent to response received

5. **Total Shifts Completed**: Lifetime counter (experience proxy)

## Communication & Notification Strategy

### SMS (Primary - Time-Sensitive)
- Shift offers with YES/NO response
- Shift confirmations with address/instructions
- Day-before reminders ("Tomorrow at 8am - Reply READY to confirm")
- Payment confirmations ("$144.00 deposited to your account")

### Email (Secondary - Less Urgent)
- Weekly shift summary for workers ("You completed 3 shifts this week, earned $432")
- Monthly statements for 1099 workers
- Company invoices for employers
- Account/password management

### In-App Notifications (For Logged-In Users)
- Real-time recruiting status for employers
- Shift status updates
- Message history

### Push Notifications (Future Enhancement)
- Real-time shift offers as alternative to SMS
- Check-in reminders

## Payment Flow & Timing

### Worker Payment (Same-Day ACH)
1. Worker clocks out at shift end
2. Timesheet auto-submitted or requires employer approval (configurable per company)
3. If approval required: employer has 24 hours to approve/dispute
4. If no approval required OR approved: payment immediately queued
5. Stripe/ACH processes payment (same-day ACH goal, may take 1-2 business days in practice)
6. Worker receives SMS confirmation when funds deposited

### Payment Timing Rules
- **Auto-approved companies**: Workers paid within hours of shift end
- **Approval-required companies**: Workers paid within 24-48 hours
- **Disputed timesheets**: On hold until resolution
- **Landing page promise**: "Get paid the same day" = same-day ACH initiated (not necessarily in bank same day)

### Employer Billing
- Net 30 payment terms (configurable per company)
- Weekly or monthly invoices
- Line items: worker hours, our markup/fee, total amount
- Payment via ACH, credit card, or check

## The Algorithm - Scoring Factors

Workers are scored on a 0-100 scale for each shift based on:

### Distance (30 points max)
- Within 5 miles: 30 points
- 5-10 miles: 25 points
- 10-15 miles: 20 points
- 15-20 miles: 15 points
- 20-25 miles: 10 points
- 25+ miles: 0 points (excluded from consideration)

### Reliability Score (25 points max)
- Worker's current reliability score (0-100) scaled to 0-25 points
- Recent no-shows heavily penalize this score

### Job Type Match (20 points max)
- Exact match to worker's preferred job types: 20 points
- No match but worker has completed similar work: 10 points
- No history: 5 points (give new workers a chance)

### Average Rating (15 points max)
- Worker's average employer rating (1-5 stars) scaled to 0-15 points
- New workers with no ratings get 10 points (benefit of doubt)

### Response Time History (10 points max)
- Average < 5 min: 10 points
- Average 5-15 min: 8 points
- Average 15-30 min: 5 points
- Average > 30 min: 2 points

### Experience Bonus (10 points max)
- Total completed shifts scaled: 0.5 points per shift, capped at 10

**Total possible: 110 points** (allows for some margin above 100 for exceptional workers)

The algorithm sends offers in priority order (highest score first), waiting for response before moving to next candidate.

## Privacy, Compliance & Legal

### Worker PII & Tax Compliance
- **SSN Collection**: Required for 1099-NEC filing (workers earning $600+/year)
- **Encryption**: All SSNs encrypted at rest using Rails encrypted attributes
- **Access Control**: Only admin users can view full SSN (last 4 visible to worker)
- **1099-NEC Forms**: Auto-generated in January for previous tax year
- **W-9 Collection**: Digital W-9 form during worker onboarding

### Background Checks
- **Phase 1**: No background checks (trust-based system, low-risk roles)
- **Future**: If required by certain clients, integrate with Checkr or similar
- **Client Requirements**: Some companies may require checks; we'd handle per-client

### SMS Compliance (TCPA)
- **Opt-In Required**: Workers explicitly consent to SMS during signup
- **Opt-Out Support**: Workers can text STOP to unsubscribe
- **Message Types**: Transactional (shift offers) + promotional (marketing)
- **Consent Tracking**: Timestamp of SMS consent stored in worker_profiles
- **Twilio Integration**: Handles delivery, opt-out management

### Texas Labor Law Compliance
- **Minimum Wage**: Currently $7.25/hr federal (Texas has no state minimum)
- **Overtime**: Not applicable (1099 contractors, not W-2 employees)
- **Payment Timing**: Texas Payday Law requires timely payment (we exceed this)
- **Workers' Comp**: Not required for 1099 contractors
- **Employment Classification**: Must properly classify as 1099 (workers control when they work, no exclusivity)

### Data Protection
- **User Data**: Email, phone, address, location, SSN, payment info
- **Retention Policy**: Active user data retained indefinitely; deleted accounts purged after 7 years (tax record retention)
- **GDPR/CCPA**: Not currently applicable (Texas-only, US-based), but design for future expansion
- **Data Breach Protocol**: Incident response plan TBD

## Open Questions & Future Considerations

1. **Multi-state Expansion**: When we expand beyond Texas, need to consider:
   - State-specific labor laws
   - Multi-state tax compliance
   - Varying minimum wage laws

2. **Worker Insurance**: Should we offer optional workers' comp or accident insurance?

3. **Peak Demand**: How do we handle high-demand periods (holidays, events)?
   - Surge pricing for employers?
   - Bonuses for workers?

4. **Worker Exclusivity**: Do we prohibit workers from using competitor platforms?
   - Current: No restrictions
   - Risk: Workers may be unavailable if committed elsewhere

5. **Employer Preferences**: Should employers be able to:
   - Request specific workers they've worked with before?
   - Block workers who didn't perform well?
   - Set their own approval workflows?

6. **Rating System Fairness**: Prevent employers from unfairly rating workers low
   - Require written feedback for ratings below 3 stars?
   - Flag employers with unusually low average ratings?

7. **Geographic Expansion Strategy**:
   - San Antonio → Austin → Houston → Dallas-Fort Worth?
   - Or focus on San Antonio density first?