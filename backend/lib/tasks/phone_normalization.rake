# frozen_string_literal: true

namespace :phone do
  desc "Normalize all existing phone numbers in the database to E.164 format (+1XXXXXXXXXX)"
  task normalize: :environment do
    puts "Starting phone number normalization..."

    # WorkerProfile phone numbers
    worker_count = 0
    WorkerProfile.find_each do |worker|
      original = worker.phone
      next if original.blank?

      # Skip if already normalized
      next if original.match?(/\A\+1\d{10}\z/)

      normalized = PhoneNormalizationService.normalize(original)
      if normalized.present? && normalized != original
        worker.update_column(:phone, normalized)
        puts "WorkerProfile #{worker.id}: #{original} -> #{normalized}"
        worker_count += 1
      elsif normalized.nil?
        puts "WARNING: WorkerProfile #{worker.id} has invalid phone: #{original}"
      end
    end

    # EmployerProfile phone numbers
    employer_count = 0
    EmployerProfile.find_each do |employer|
      original = employer.phone
      next if original.blank?

      # Skip if already normalized
      next if original.match?(/\A\+1\d{10}\z/)

      normalized = PhoneNormalizationService.normalize(original)
      if normalized.present? && normalized != original
        employer.update_column(:phone, normalized)
        puts "EmployerProfile #{employer.id}: #{original} -> #{normalized}"
        employer_count += 1
      elsif normalized.nil?
        puts "WARNING: EmployerProfile #{employer.id} has invalid phone: #{original}"
      end
    end

    # Message phone numbers
    message_count = 0
    Message.where.not(from_phone: nil).or(Message.where.not(to_phone: nil)).find_each do |message|
      updated = false

      # Normalize from_phone
      if message.from_phone.present? && !message.from_phone.match?(/\A\+1\d{10}\z/)
        normalized_from = PhoneNormalizationService.normalize(message.from_phone)
        if normalized_from.present? && normalized_from != message.from_phone
          message.update_column(:from_phone, normalized_from)
          puts "Message #{message.id} from_phone: #{message.from_phone} -> #{normalized_from}"
          updated = true
        elsif normalized_from.nil?
          puts "WARNING: Message #{message.id} has invalid from_phone: #{message.from_phone}"
        end
      end

      # Normalize to_phone
      if message.to_phone.present? && !message.to_phone.match?(/\A\+1\d{10}\z/)
        normalized_to = PhoneNormalizationService.normalize(message.to_phone)
        if normalized_to.present? && normalized_to != message.to_phone
          message.update_column(:to_phone, normalized_to)
          puts "Message #{message.id} to_phone: #{message.to_phone} -> #{normalized_to}"
          updated = true
        elsif normalized_to.nil?
          puts "WARNING: Message #{message.id} has invalid to_phone: #{message.to_phone}"
        end
      end

      message_count += 1 if updated
    end

    puts "\nNormalization complete!"
    puts "WorkerProfiles updated: #{worker_count}"
    puts "EmployerProfiles updated: #{employer_count}"
    puts "Messages updated: #{message_count}"
  end

  desc "Validate all phone numbers in the database"
  task validate: :environment do
    puts "Validating phone numbers..."

    invalid_workers = WorkerProfile.where.not(phone: nil).reject { |w| w.phone.match?(/\A\+1\d{10}\z/) }
    invalid_employers = EmployerProfile.where.not(phone: nil).reject { |e| e.phone.match?(/\A\+1\d{10}\z/) }
    invalid_messages = Message.where.not(from_phone: nil).or(Message.where.not(to_phone: nil))
                              .select { |m| (m.from_phone.present? && !m.from_phone.match?(/\A\+1\d{10}\z/)) ||
                                           (m.to_phone.present? && !m.to_phone.match?(/\A\+1\d{10}\z/)) }

    puts "\nValidation Results:"
    puts "Invalid WorkerProfile phones: #{invalid_workers.count}"
    invalid_workers.each { |w| puts "  WorkerProfile #{w.id}: #{w.phone}" }

    puts "\nInvalid EmployerProfile phones: #{invalid_employers.count}"
    invalid_employers.each { |e| puts "  EmployerProfile #{e.id}: #{e.phone}" }

    puts "\nInvalid Message phones: #{invalid_messages.count}"
    invalid_messages.each { |m| puts "  Message #{m.id}: from=#{m.from_phone}, to=#{m.to_phone}" }

    total_invalid = invalid_workers.count + invalid_employers.count + invalid_messages.count
    if total_invalid.zero?
      puts "\n✓ All phone numbers are properly normalized!"
    else
      puts "\n✗ Found #{total_invalid} records with invalid phone numbers"
      puts "Run 'rake phone:normalize' to fix them"
    end
  end
end
