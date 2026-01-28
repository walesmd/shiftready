# frozen_string_literal: true

module Api
  module V1
    module Admin
      class RecruitingController < BaseController
        before_action :authorize_admin!
        before_action :set_shift, only: [:show]

        # GET /api/v1/admin/recruiting
        # Lists all shifts with recruiting activity, sorted by urgency (paused first)
        def index
          shifts = Shift.includes(:company, :work_location, :created_by_employer,
                                  :recruiting_activity_logs, :shift_assignments)
                        .joins(:recruiting_activity_logs)
                        .distinct

          # Apply filters
          shifts = shifts.where(company_id: params[:company_id]) if params[:company_id].present?
          shifts = apply_status_filter(shifts, params[:status]) if params[:status].present?
          shifts = shifts.where('start_datetime >= ?', params[:start_date]) if params[:start_date].present?
          shifts = shifts.where('start_datetime <= ?', params[:end_date]) if params[:end_date].present?

          page = [params[:page].to_i, 1].max
          per_page = [[params[:per_page].to_i, 1].max, 100].min
          per_page = 25 if per_page < 1

          # Custom sorting: paused shifts first, then by start_datetime
          shifts = shifts.select('shifts.*,
            CASE WHEN shifts.id IN (
              SELECT DISTINCT ral.shift_id FROM recruiting_activity_logs ral
              WHERE ral.action = \'recruiting_paused\'
              AND NOT EXISTS (
                SELECT 1 FROM recruiting_activity_logs ral2
                WHERE ral2.shift_id = ral.shift_id
                AND ral2.action IN (\'recruiting_resumed\', \'recruiting_completed\')
                AND ral2.created_at > ral.created_at
              )
            ) THEN 0 ELSE 1 END as paused_sort_order')
            .order(Arel.sql('paused_sort_order ASC, start_datetime ASC'))
            .offset((page - 1) * per_page)
            .limit(per_page)

          render json: {
            shifts: shifts.map { |shift| shift_summary_response(shift) },
            meta: {
              total: total_count,
              page: page,
              per_page: per_page,
              total_pages: (total_count / per_page.to_f).ceil,
              paused_count: paused_shifts_count
            }
          }
        end

        # GET /api/v1/admin/recruiting/:shift_id
        # Detailed recruiting timeline for a specific shift
        def show
          timeline_entries = @shift.recruiting_activity_logs
                                   .includes(:worker_profile, :shift_assignment)
                                   .chronological

          workers_contacted = @shift.shift_assignments
                                    .includes(:worker_profile)
                                    .where.not(sms_sent_at: nil)
                                    .order(:sms_sent_at)

          render json: {
            shift: shift_detail_response(@shift),
            summary: recruiting_summary(@shift),
            timeline: timeline_entries.map { |log| timeline_entry_response(log) },
            workers_contacted: workers_contacted.map { |assignment| worker_contact_response(assignment) }
          }
        end

        private

        def authorize_admin!
          return if current_user.admin?

          render_error('Only admins can access this resource', :forbidden)
        end

        def set_shift
          @shift = Shift.includes(:company, :work_location, :created_by_employer,
                                  :recruiting_activity_logs, :shift_assignments)
                        .find(params[:shift_id])
        rescue ActiveRecord::RecordNotFound
          render_error('Shift not found', :not_found)
        end

        def apply_status_filter(shifts, status)
          case status
          when 'paused'
            # Shifts that have been paused and not resumed/completed
            shifts.where(id: currently_paused_shift_ids)
          when 'active'
            # Recruiting status and not paused
            shifts.recruiting.where.not(id: currently_paused_shift_ids)
          when 'filled'
            shifts.filled
          when 'completed'
            shifts.completed
          else
            shifts
          end
        end

        def currently_paused_shift_ids
          # Find shifts that have a pause log with no subsequent resume/complete log
          RecruitingActivityLog
            .where(action: 'recruiting_paused')
            .where.not(
              shift_id: RecruitingActivityLog
                .where(action: %w[recruiting_resumed recruiting_completed])
                .where('recruiting_activity_logs.created_at > (
                  SELECT MAX(ral2.created_at)
                  FROM recruiting_activity_logs ral2
                  WHERE ral2.shift_id = recruiting_activity_logs.shift_id
                  AND ral2.action = \'recruiting_paused\'
                )')
                .select(:shift_id)
            )
            .select(:shift_id)
            .distinct
        end

        def paused_shifts_count
          Shift.where(id: currently_paused_shift_ids).count
        end

        def shift_is_paused?(shift)
          last_pause = shift.recruiting_activity_logs.where(action: 'recruiting_paused').order(created_at: :desc).first
          return false unless last_pause

          last_resume_or_complete = shift.recruiting_activity_logs
                                         .where(action: %w[recruiting_resumed recruiting_completed])
                                         .where('created_at > ?', last_pause.created_at)
                                         .exists?
          !last_resume_or_complete
        end

        def recruiting_summary(shift)
          logs = shift.recruiting_activity_logs
          assignments = shift.shift_assignments

          {
            offers_sent: assignments.where.not(sms_sent_at: nil).count,
            offers_accepted: assignments.where(status: %w[accepted confirmed checked_in completed]).count,
            offers_declined: assignments.where(status: 'declined').count,
            offers_timeout: assignments.where(status: 'no_response').count,
            workers_scored: logs.where(action: 'worker_scored').count,
            workers_excluded: logs.where(action: 'worker_excluded').count,
            is_paused: shift_is_paused?(shift),
            pause_reason: last_pause_reason(shift),
            recruiting_started_at: shift.recruiting_started_at,
            last_activity_at: logs.maximum(:created_at)
          }
        end

        def last_pause_reason(shift)
          last_pause = shift.recruiting_activity_logs.where(action: 'recruiting_paused').order(created_at: :desc).first
          return nil unless last_pause && shift_is_paused?(shift)

          last_pause.details&.dig('reason')
        end

        def shift_summary_response(shift)
          logs = shift.recruiting_activity_logs
          assignments = shift.shift_assignments

          {
            id: shift.id,
            tracking_code: shift.tracking_code,
            title: shift.title,
            job_type: shift.job_type,
            company: {
              id: shift.company.id,
              name: shift.company.name
            },
            work_location: {
              id: shift.work_location.id,
              name: shift.work_location.name,
              city: shift.work_location.city,
              state: shift.work_location.state
            },
            schedule: {
              start_datetime: shift.start_datetime,
              end_datetime: shift.end_datetime,
              formatted_range: shift.formatted_datetime_range
            },
            pay: {
              hourly_rate: shift.hourly_rate,
              formatted_rate: shift.formatted_pay_rate
            },
            capacity: {
              slots_total: shift.slots_total,
              slots_filled: shift.slots_filled,
              slots_available: shift.slots_available
            },
            status: shift.status,
            recruiting_status: recruiting_status_for_shift(shift),
            stats: {
              offers_sent: assignments.where.not(sms_sent_at: nil).count,
              offers_accepted: assignments.where(status: %w[accepted confirmed checked_in completed]).count,
              offers_declined: assignments.where(status: 'declined').count,
              offers_timeout: assignments.where(status: 'no_response').count
            },
            last_activity_at: logs.maximum(:created_at)
          }
        end

        def recruiting_status_for_shift(shift)
          if shift_is_paused?(shift)
            'paused'
          elsif shift.fully_filled?
            'filled'
          elsif shift.recruiting?
            'active'
          else
            shift.status
          end
        end

        def shift_detail_response(shift)
          {
            id: shift.id,
            tracking_code: shift.tracking_code,
            title: shift.title,
            description: shift.description,
            job_type: shift.job_type,
            company: {
              id: shift.company.id,
              name: shift.company.name
            },
            work_location: {
              id: shift.work_location.id,
              name: shift.work_location.name,
              address: shift.work_location.full_address,
              city: shift.work_location.city,
              state: shift.work_location.state
            },
            created_by: {
              id: shift.created_by_employer.id,
              name: shift.created_by_employer.full_name
            },
            schedule: {
              start_datetime: shift.start_datetime,
              end_datetime: shift.end_datetime,
              duration_hours: shift.duration_hours,
              formatted_range: shift.formatted_datetime_range
            },
            pay: {
              rate_cents: shift.pay_rate_cents,
              hourly_rate: shift.hourly_rate,
              formatted_rate: shift.formatted_pay_rate,
              estimated_total: shift.estimated_pay
            },
            capacity: {
              slots_total: shift.slots_total,
              slots_filled: shift.slots_filled,
              slots_available: shift.slots_available,
              min_workers_needed: shift.min_workers_needed
            },
            status: shift.status,
            recruiting_status: recruiting_status_for_shift(shift),
            status_timestamps: {
              posted_at: shift.posted_at,
              recruiting_started_at: shift.recruiting_started_at,
              filled_at: shift.filled_at,
              completed_at: shift.completed_at,
              cancelled_at: shift.cancelled_at
            }
          }
        end

        def timeline_entry_response(log)
          response = {
            id: log.id,
            action: log.action,
            source: log.source,
            details: log.details,
            created_at: log.created_at,
            icon: icon_for_action(log.action),
            label: label_for_action(log.action)
          }

          if log.worker_profile
            response[:worker] = {
              id: log.worker_profile.id,
              name: log.worker_profile.full_name
            }
          end

          if log.shift_assignment
            response[:assignment] = {
              id: log.shift_assignment.id,
              status: log.shift_assignment.status,
              algorithm_score: log.shift_assignment.algorithm_score,
              distance_miles: log.shift_assignment.distance_miles
            }
          end

          response
        end

        def worker_contact_response(assignment)
          {
            id: assignment.id,
            worker: {
              id: assignment.worker_profile.id,
              name: assignment.worker_profile.full_name,
              phone: assignment.worker_profile.phone_display
            },
            algorithm_score: assignment.algorithm_score,
            distance_miles: assignment.distance_miles,
            status: assignment.status,
            offer_sent_at: assignment.sms_sent_at,
            response_received_at: assignment.response_received_at,
            response_time_minutes: assignment.response_time_minutes,
            response_method: assignment.response_method,
            decline_reason: assignment.decline_reason,
            outcome: outcome_for_status(assignment.status)
          }
        end

        def icon_for_action(action)
          {
            'recruiting_started' => 'play',
            'recruiting_paused' => 'pause',
            'recruiting_resumed' => 'play',
            'recruiting_completed' => 'check-circle',
            'worker_scored' => 'calculator',
            'worker_excluded' => 'user-x',
            'offer_sent' => 'send',
            'offer_accepted' => 'check',
            'offer_declined' => 'x',
            'offer_timeout' => 'clock',
            'next_worker_selected' => 'arrow-right'
          }[action] || 'circle'
        end

        def label_for_action(action)
          {
            'recruiting_started' => 'Recruiting Started',
            'recruiting_paused' => 'Recruiting Paused',
            'recruiting_resumed' => 'Recruiting Resumed',
            'recruiting_completed' => 'Recruiting Completed',
            'worker_scored' => 'Worker Scored',
            'worker_excluded' => 'Worker Excluded',
            'offer_sent' => 'Offer Sent',
            'offer_accepted' => 'Offer Accepted',
            'offer_declined' => 'Offer Declined',
            'offer_timeout' => 'Offer Timed Out',
            'next_worker_selected' => 'Next Worker Selected'
          }[action] || action.titleize
        end

        def outcome_for_status(status)
          case status
          when 'accepted', 'confirmed', 'checked_in', 'completed'
            'accepted'
          when 'declined'
            'declined'
          when 'no_response'
            'timeout'
          when 'offered'
            'pending'
          when 'cancelled'
            'cancelled'
          else
            status
          end
        end
      end
    end
  end
end
