# frozen_string_literal: true

namespace :geocode do
  desc 'Backfill missing coordinates for all address records'
  task backfill: :environment do
    puts 'Starting geocoding backfill...'
    puts ''

    # Backfill WorkerProfiles
    worker_profiles = WorkerProfile.where('latitude IS NULL OR longitude IS NULL')
                                   .where.not(address_line_1: nil)
                                   .where.not(city: nil)
                                   .where.not(state: nil)
                                   .where.not(zip_code: nil)
    puts "Found #{worker_profiles.count} worker profiles without coordinates"

    worker_profiles.find_each do |profile|
      print "  Geocoding worker profile #{profile.id}... "
      begin
        result = GeocodingService.geocode(profile.full_address)

        if result
          profile.update_columns(
            latitude: result[:latitude],
            longitude: result[:longitude]
          )
          puts "✓ (#{result[:latitude]}, #{result[:longitude]})"
        else
          puts "✗ Failed"
        end
      rescue StandardError => e
        puts "✗ Error: #{e.message}"
      end

      sleep 0.1 # Rate limiting
    end

    puts ''

    # Backfill WorkLocations
    work_locations = WorkLocation.where('latitude IS NULL OR longitude IS NULL')
                                 .where.not(address_line_1: nil)
                                 .where.not(city: nil)
                                 .where.not(state: nil)
                                 .where.not(zip_code: nil)
    puts "Found #{work_locations.count} work locations without coordinates"

    work_locations.find_each do |location|
      print "  Geocoding work location #{location.id}... "
      begin
        result = GeocodingService.geocode(location.full_address)

        if result
          location.update_columns(
            latitude: result[:latitude],
            longitude: result[:longitude]
          )
          puts "✓ (#{result[:latitude]}, #{result[:longitude]})"
        else
          puts "✗ Failed"
        end
      rescue StandardError => e
        puts "✗ Error: #{e.message}"
      end

      sleep 0.1 # Rate limiting
    end

    puts ''

    # Backfill Companies (billing addresses)
    companies = Company.where('billing_latitude IS NULL OR billing_longitude IS NULL')
                       .where.not(billing_address_line_1: nil)
                       .where.not(billing_city: nil)
                       .where.not(billing_state: nil)
                       .where.not(billing_zip_code: nil)
    puts "Found #{companies.count} companies without billing coordinates"

    companies.find_each do |company|
      print "  Geocoding company #{company.id}... "
      begin
        result = GeocodingService.geocode(company.full_billing_address)

        if result
          company.update_columns(
            billing_latitude: result[:latitude],
            billing_longitude: result[:longitude]
          )
          puts "✓ (#{result[:latitude]}, #{result[:longitude]})"
        else
          puts "✗ Failed"
        end
      rescue StandardError => e
        puts "✗ Error: #{e.message}"
      end

      sleep 0.1 # Rate limiting
    end

    puts ''
    puts 'Geocoding backfill complete!'
  end

  desc 'Test geocoding for a specific address'
  task :test, [:address] => :environment do |_t, args|
    address = args[:address] || '100 Montana St, San Antonio, TX 78203'
    puts "Testing geocoding for: #{address}"
    puts ''

    result = GeocodingService.geocode(address)

    if result
      puts 'Success!'
      puts "  Latitude:  #{result[:latitude]}"
      puts "  Longitude: #{result[:longitude]}"
      puts "  Normalized: #{result[:address_line_1]}, #{result[:city]}, #{result[:state]} #{result[:zip_code]}"
    else
      puts 'Geocoding failed'
    end
  end
end
