# frozen_string_literal: true

class GeocodeAddressJob < ApplicationJob
  queue_as :default

  def perform(model_class_name, record_id)
    model_class = model_class_name.safe_constantize

    unless model_class
      Rails.logger.warn "[GeocodeAddressJob] Unknown model class #{model_class_name}, skipping"
      return
    end

    record = model_class.find_by(id: record_id)

    unless record
      Rails.logger.warn "[GeocodeAddressJob] #{model_class_name} #{record_id} not found, skipping"
      return
    end

    record.send(:geocode_address)
  end
end
