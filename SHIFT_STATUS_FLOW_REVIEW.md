# Shift Status Flow

This document outlines how the backend currently processes a shift through its various statuses as defined by the backend on 1/25/2026. This document was produced by an LLM analyzing the codebase and to be used to inform future progress on developing the asynchronous backend jobs to execute this workload.


## LLM Output

Here’s the shift status workflow based on the current backend code. I’ll call out what’s implemented vs. what looks missing.
Statuses and transitions (as implemented)

1) draft (default on create)
New shifts default to draft because the DB default is status: 0 (draft) and the create endpoint doesn’t permit a status param, so it’s not set via API.
20260120232751_create_shifts.rb
Lines 19-21
      t.integer :status, default: 0, null: false # enum: draft=0, posted=1, recruiting=2, filled=3, in_progress=4, completed=5, cancelled=6      t.datetime :posted_at
shifts_controller.rb
Lines 156-169
      def shift_params        params.require(:shift).permit(          :work_location_id,          :title,          :description,          :job_type,          :start_datetime,          :end_datetime,          :pay_rate_cents,          :slots_total,          :min_workers_needed,          :skills_required,          :physical_requirements        )      end

2) posted (intended next step, but no code path found)
There’s no method or controller endpoint that transitions draft -> posted.
posted_at exists in schema but isn’t set in code. Seed data sets posted_at manually, which is probably why seeded records look correct.
This suggests posting is currently a manual DB change or missing feature.

3) recruiting (explicit transition via endpoint)
Transition: posted -> recruiting
Trigger: POST /api/v1/shifts/:id/start_recruiting calls start_recruiting!
Conditions: shift must be posted, upcoming, and not fully filled.
shifts_controller.rb
Lines 101-107
      def start_recruiting        if @shift.start_recruiting!          render json: shift_response(@shift)        else          render_error('Cannot start recruiting for this shift', :unprocessable_entity)        end      end
shift.rb
Lines 87-106
  def can_start_recruiting?    posted? && !fully_filled? && upcoming?  end  def start_recruiting!    return false unless can_start_recruiting?    update!(      status: :recruiting,      recruiting_started_at: Time.current    )  end

4) filled (auto transition when slots filled)
Transition: recruiting -> filled (also posted -> filled)
Trigger: ShiftAssignment#accept! increments slots_filled; after update, Shift#check_if_filled auto-sets status to filled if status is posted or recruiting.
shift_assignment.rb
Lines 49-61
  def accept!(method: :sms)    return false unless offered?    transaction do      update!(        status: :accepted,        accepted_at: Time.current,        response_received_at: Time.current,        response_method: method,        response_value: :accepted      )      shift.increment!(:slots_filled)    end  end
shift.rb
Lines 108-114
  def mark_as_filled!    return false unless fully_filled?    update!(      status: :filled,      filled_at: Time.current    )  end
shift.rb
Lines 177-180
  def check_if_filled    if slots_filled >= slots_total && (recruiting? || posted?)      mark_as_filled!    end  end

5) in_progress (time-based transition from filled)
Transition: filled -> in_progress
Trigger: Shift#start! (not exposed via API in controller)
Condition: shift must be filled and start_datetime <= now.
shift.rb
Lines 125-129
  def start!    return false unless filled? && start_datetime <= Time.current    update!(status: :in_progress)  end

6) completed (time-based transition from in_progress)
Transition: in_progress -> completed
Trigger: Shift#complete! (not exposed via API in controller)
Condition: shift must be in_progress and end_datetime <= now.
shift.rb
Lines 131-137
  def complete!    return false unless in_progress? && end_datetime <= Time.current    update!(      status: :completed,      completed_at: Time.current    )  end

7) cancelled (terminal, can happen from any state)
Transition: any -> cancelled
Trigger: POST /api/v1/shifts/:id/cancel calls cancel!.
shifts_controller.rb
Lines 110-118
      def cancel        reason = params[:reason]        if @shift.cancel!(reason)          render json: shift_response(@shift)        else          render_error('Cannot cancel this shift', :unprocessable_entity)        end      end
shift.rb
Lines 117-122
  def cancel!(reason = nil)    update!(      status: :cancelled,      cancelled_at: Time.current,      cancellation_reason: reason    )  end

Gaps / notable missing transitions
No draft -> posted implementation in controllers or model; no “post” endpoint and status isn’t permitted in shift_params.
No API endpoints for start! or complete!, so in_progress and completed would only be reachable via background jobs or direct model calls (not present in controller code).