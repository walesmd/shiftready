# frozen_string_literal: true

module Api
  module V1
    class ActivitiesController < BaseController

      # GET /api/v1/activities
      # Returns recent activity for the current user based on their role
      def index
        activities = case current_user.role
                     when 'worker'
                       worker_activities
                     when 'employer'
                       employer_activities
                     when 'admin'
                       admin_activities
                     else
                       []
                     end

        render json: {
          activities: activities,
          meta: { total: activities.size }
        }
      end

      private

      def worker_activities
        worker_profile = current_user.worker_profile
        return [] unless worker_profile

        activities = []
        limit = (params[:limit] || 20).to_i

        # Get recent shift assignments with their shifts
        assignments = worker_profile.shift_assignments
                                    .includes(:shift)
                                    .order(updated_at: :desc)
                                    .limit(limit * 2)

        assignments.each do |assignment|
          activities.concat(assignment_activities_for_worker(assignment))
        end

        # Get recent payments
        payments = worker_profile.payments
                                 .includes(shift_assignment: :shift)
                                 .order(updated_at: :desc)
                                 .limit(limit)

        payments.each do |payment|
          activities.concat(payment_activities_for_worker(payment))
        end

        # Sort by timestamp and limit
        activities.sort_by { |a| a[:timestamp] }.reverse.take(limit)
      end

      def employer_activities
        employer_profile = current_user.employer_profile
        return [] unless employer_profile

        activities = []
        limit = (params[:limit] || 20).to_i
        company = employer_profile.company

        # Get recent shift assignments for company shifts
        assignments = ShiftAssignment
                      .joins(:shift)
                      .includes(:shift, :worker_profile)
                      .where(shifts: { company_id: company.id })
                      .order(updated_at: :desc)
                      .limit(limit * 2)

        assignments.each do |assignment|
          activities.concat(assignment_activities_for_employer(assignment))
        end

        # Get recent shifts created/updated
        shifts = company.shifts
                        .order(updated_at: :desc)
                        .limit(limit)

        shifts.each do |shift|
          activities.concat(shift_activities_for_employer(shift))
        end

        # Sort by timestamp and limit
        activities.sort_by { |a| a[:timestamp] }.reverse.take(limit)
      end

      def admin_activities
        # For now, return a mix of recent system-wide activity
        activities = []
        limit = (params[:limit] || 20).to_i

        # Recent shift assignments
        ShiftAssignment.includes(:shift, :worker_profile)
                       .order(updated_at: :desc)
                       .limit(limit)
                       .each do |assignment|
          activities.concat(assignment_activities_for_admin(assignment))
        end

        activities.sort_by { |a| a[:timestamp] }.reverse.take(limit)
      end

      # Worker activity helpers
      def assignment_activities_for_worker(assignment)
        activities = []
        shift = assignment.shift

        case assignment.status
        when 'offered'
          activities << {
            id: "assignment-#{assignment.id}-offered",
            type: 'shift_offer',
            icon: 'briefcase',
            title: 'Shift offer received',
            description: "#{shift.title} at #{shift.work_location.name}",
            timestamp: assignment.assigned_at&.iso8601,
            status: 'pending',
            metadata: {
              shift_id: shift.id,
              assignment_id: assignment.id,
              pay_rate: shift.formatted_pay_rate
            }
          }
        when 'accepted'
          activities << {
            id: "assignment-#{assignment.id}-accepted",
            type: 'shift_accepted',
            icon: 'check-circle',
            title: 'Shift accepted',
            description: shift.title,
            timestamp: assignment.accepted_at&.iso8601,
            status: 'success',
            metadata: { shift_id: shift.id, assignment_id: assignment.id }
          }
        when 'confirmed'
          activities << {
            id: "assignment-#{assignment.id}-confirmed",
            type: 'shift_confirmed',
            icon: 'calendar-check',
            title: 'Shift confirmed',
            description: "#{shift.title} on #{shift.start_datetime.strftime('%b %d')}",
            timestamp: assignment.confirmed_at&.iso8601,
            status: 'success',
            metadata: { shift_id: shift.id, assignment_id: assignment.id }
          }
        when 'checked_in'
          activities << {
            id: "assignment-#{assignment.id}-checked-in",
            type: 'checked_in',
            icon: 'log-in',
            title: 'Checked in',
            description: shift.title,
            timestamp: assignment.checked_in_at&.iso8601,
            status: 'info',
            metadata: { shift_id: shift.id, assignment_id: assignment.id }
          }
        when 'completed'
          activities << {
            id: "assignment-#{assignment.id}-completed",
            type: 'shift_completed',
            icon: 'check-circle',
            title: 'Shift completed',
            description: "#{shift.title} - #{assignment.formatted_calculated_pay}",
            timestamp: assignment.checked_out_at&.iso8601 || assignment.updated_at&.iso8601,
            status: 'success',
            metadata: {
              shift_id: shift.id,
              assignment_id: assignment.id,
              hours_worked: assignment.actual_hours_worked,
              pay: assignment.calculated_pay_cents
            }
          }
        when 'cancelled'
          activities << {
            id: "assignment-#{assignment.id}-cancelled",
            type: 'shift_cancelled',
            icon: 'x-circle',
            title: 'Shift cancelled',
            description: "#{shift.title}#{assignment.cancellation_reason.present? ? " - #{assignment.cancellation_reason}" : ''}",
            timestamp: assignment.cancelled_at&.iso8601,
            status: 'error',
            metadata: {
              shift_id: shift.id,
              assignment_id: assignment.id,
              cancelled_by: assignment.cancelled_by
            }
          }
        when 'declined'
          activities << {
            id: "assignment-#{assignment.id}-declined",
            type: 'shift_declined',
            icon: 'x-circle',
            title: 'Shift declined',
            description: shift.title,
            timestamp: assignment.response_received_at&.iso8601 || assignment.updated_at&.iso8601,
            status: 'neutral',
            metadata: { shift_id: shift.id, assignment_id: assignment.id }
          }
        when 'no_show'
          activities << {
            id: "assignment-#{assignment.id}-no-show",
            type: 'no_show',
            icon: 'alert-circle',
            title: 'Marked as no-show',
            description: shift.title,
            timestamp: assignment.updated_at&.iso8601,
            status: 'error',
            metadata: { shift_id: shift.id, assignment_id: assignment.id }
          }
        end

        activities.compact
      end

      def payment_activities_for_worker(payment)
        activities = []
        shift_title = payment.shift_assignment&.shift&.title || 'Unknown shift'

        case payment.status
        when 'pending'
          activities << {
            id: "payment-#{payment.id}-pending",
            type: 'payment_pending',
            icon: 'clock',
            title: 'Payment pending',
            description: "#{payment.formatted_amount} for #{shift_title}",
            timestamp: payment.created_at&.iso8601,
            status: 'pending',
            metadata: { payment_id: payment.id, amount_cents: payment.amount_cents }
          }
        when 'processing'
          activities << {
            id: "payment-#{payment.id}-processing",
            type: 'payment_processing',
            icon: 'loader',
            title: 'Payment processing',
            description: "#{payment.formatted_amount} for #{shift_title}",
            timestamp: payment.processed_at&.iso8601,
            status: 'info',
            metadata: { payment_id: payment.id, amount_cents: payment.amount_cents }
          }
        when 'completed'
          activities << {
            id: "payment-#{payment.id}-completed",
            type: 'payment_received',
            icon: 'dollar-sign',
            title: 'Payment received',
            description: "#{payment.formatted_amount} for #{shift_title}",
            timestamp: payment.processed_at&.iso8601,
            status: 'success',
            metadata: { payment_id: payment.id, amount_cents: payment.amount_cents }
          }
        when 'failed'
          activities << {
            id: "payment-#{payment.id}-failed",
            type: 'payment_failed',
            icon: 'alert-triangle',
            title: 'Payment failed',
            description: "#{payment.formatted_amount} - #{payment.failure_reason || 'Please update payment details'}",
            timestamp: payment.failed_at&.iso8601,
            status: 'error',
            metadata: { payment_id: payment.id, amount_cents: payment.amount_cents }
          }
        end

        activities.compact
      end

      # Employer activity helpers
      def assignment_activities_for_employer(assignment)
        activities = []
        shift = assignment.shift
        worker_name = assignment.worker_profile&.full_name || 'Unknown worker'

        case assignment.status
        when 'accepted'
          activities << {
            id: "assignment-#{assignment.id}-accepted",
            type: 'worker_accepted',
            icon: 'user-check',
            title: 'Worker accepted shift',
            description: "#{worker_name} accepted #{shift.title}",
            timestamp: assignment.accepted_at&.iso8601,
            status: 'success',
            metadata: {
              shift_id: shift.id,
              assignment_id: assignment.id,
              worker_id: assignment.worker_profile_id
            }
          }
        when 'declined'
          activities << {
            id: "assignment-#{assignment.id}-declined",
            type: 'worker_declined',
            icon: 'user-x',
            title: 'Worker declined shift',
            description: "#{worker_name} declined #{shift.title}",
            timestamp: assignment.response_received_at&.iso8601 || assignment.updated_at&.iso8601,
            status: 'neutral',
            metadata: {
              shift_id: shift.id,
              assignment_id: assignment.id,
              reason: assignment.decline_reason
            }
          }
        when 'confirmed'
          activities << {
            id: "assignment-#{assignment.id}-confirmed",
            type: 'worker_confirmed',
            icon: 'calendar-check',
            title: 'Worker confirmed',
            description: "#{worker_name} confirmed for #{shift.title}",
            timestamp: assignment.confirmed_at&.iso8601,
            status: 'success',
            metadata: { shift_id: shift.id, assignment_id: assignment.id }
          }
        when 'checked_in'
          activities << {
            id: "assignment-#{assignment.id}-checked-in",
            type: 'worker_checked_in',
            icon: 'log-in',
            title: 'Worker checked in',
            description: "#{worker_name} checked in to #{shift.title}",
            timestamp: assignment.checked_in_at&.iso8601,
            status: 'info',
            metadata: { shift_id: shift.id, assignment_id: assignment.id }
          }
        when 'completed'
          if assignment.timesheet_approved_at.nil? && assignment.checked_out_at.present?
            activities << {
              id: "assignment-#{assignment.id}-needs-approval",
              type: 'timesheet_pending',
              icon: 'clipboard',
              title: 'Timesheet needs approval',
              description: "#{worker_name} - #{shift.title} (#{assignment.actual_hours_worked}h)",
              timestamp: assignment.checked_out_at&.iso8601,
              status: 'pending',
              metadata: { shift_id: shift.id, assignment_id: assignment.id }
            }
          else
            activities << {
              id: "assignment-#{assignment.id}-completed",
              type: 'shift_completed',
              icon: 'check-circle',
              title: 'Shift completed',
              description: "#{worker_name} completed #{shift.title}",
              timestamp: assignment.timesheet_approved_at&.iso8601 || assignment.updated_at&.iso8601,
              status: 'success',
              metadata: { shift_id: shift.id, assignment_id: assignment.id }
            }
          end
        when 'no_show'
          activities << {
            id: "assignment-#{assignment.id}-no-show",
            type: 'worker_no_show',
            icon: 'alert-circle',
            title: 'Worker no-show',
            description: "#{worker_name} did not show up for #{shift.title}",
            timestamp: assignment.updated_at&.iso8601,
            status: 'error',
            metadata: { shift_id: shift.id, assignment_id: assignment.id }
          }
        when 'cancelled'
          activities << {
            id: "assignment-#{assignment.id}-cancelled",
            type: 'assignment_cancelled',
            icon: 'x-circle',
            title: 'Assignment cancelled',
            description: "#{worker_name} - #{shift.title}",
            timestamp: assignment.cancelled_at&.iso8601,
            status: 'error',
            metadata: {
              shift_id: shift.id,
              assignment_id: assignment.id,
              cancelled_by: assignment.cancelled_by
            }
          }
        end

        activities.compact
      end

      def shift_activities_for_employer(shift)
        activities = []

        # Only show significant shift status changes
        case shift.status
        when 'filled'
          activities << {
            id: "shift-#{shift.id}-filled",
            type: 'shift_filled',
            icon: 'users',
            title: 'Shift fully staffed',
            description: "#{shift.title} - #{shift.slots_filled}/#{shift.slots_total} workers",
            timestamp: shift.filled_at&.iso8601,
            status: 'success',
            metadata: { shift_id: shift.id }
          }
        when 'completed'
          activities << {
            id: "shift-#{shift.id}-completed",
            type: 'shift_completed',
            icon: 'check-circle',
            title: 'Shift completed',
            description: shift.title,
            timestamp: shift.completed_at&.iso8601,
            status: 'success',
            metadata: { shift_id: shift.id }
          }
        when 'cancelled'
          activities << {
            id: "shift-#{shift.id}-cancelled",
            type: 'shift_cancelled',
            icon: 'x-circle',
            title: 'Shift cancelled',
            description: "#{shift.title}#{shift.cancellation_reason.present? ? " - #{shift.cancellation_reason}" : ''}",
            timestamp: shift.cancelled_at&.iso8601,
            status: 'error',
            metadata: { shift_id: shift.id }
          }
        end

        activities.compact
      end

      def assignment_activities_for_admin(assignment)
        # For admin, show all activities with full context
        activities = []
        shift = assignment.shift
        worker_name = assignment.worker_profile&.full_name || 'Unknown'
        company_name = shift.company&.name || 'Unknown'

        activities << {
          id: "assignment-#{assignment.id}-#{assignment.status}",
          type: "assignment_#{assignment.status}",
          icon: status_icon(assignment.status),
          title: "#{worker_name} - #{assignment.status.titleize}",
          description: "#{shift.title} at #{company_name}",
          timestamp: assignment.updated_at&.iso8601,
          status: status_type(assignment.status),
          metadata: {
            shift_id: shift.id,
            assignment_id: assignment.id,
            worker_id: assignment.worker_profile_id,
            company_id: shift.company_id
          }
        }

        activities
      end

      def status_icon(status)
        case status
        when 'offered' then 'briefcase'
        when 'accepted', 'confirmed', 'completed' then 'check-circle'
        when 'declined', 'cancelled' then 'x-circle'
        when 'checked_in' then 'log-in'
        when 'no_show' then 'alert-circle'
        else 'circle'
        end
      end

      def status_type(status)
        case status
        when 'offered' then 'pending'
        when 'accepted', 'confirmed', 'completed' then 'success'
        when 'declined' then 'neutral'
        when 'cancelled', 'no_show' then 'error'
        when 'checked_in' then 'info'
        else 'neutral'
        end
      end
    end
  end
end
