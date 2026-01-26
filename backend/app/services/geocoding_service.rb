# frozen_string_literal: true

require 'net/http'
require 'json'

# Service for geocoding addresses using the Geocodio API
# Handles API requests, response parsing, and error handling
#
# Note: SSL verification is disabled in development to avoid certificate issues.
# In production, ensure proper SSL certificates are configured.
class GeocodingService
  class GeocodingError < StandardError; end

  BASE_URL = 'https://api.geocod.io/v1.7/geocode'

  # Geocodes a full address string and returns coordinates and normalized address
  #
  # @param address [String] Full address string to geocode
  # @return [Hash, nil] Hash with :latitude, :longitude, and normalized address fields, or nil on failure
  def self.geocode(address)
    return nil if address.blank?

    new.geocode(address)
  end

  def geocode(address)
    response = make_request(address)
    parse_response(response)
  rescue StandardError => e
    Rails.logger.error("Geocoding failed for address '#{address}': #{e.message}")
    nil
  end

  private

  def make_request(address)
    uri = URI(BASE_URL)
    params = {
      q: address,
      api_key: ENV['GEOCODIO_API_KEY']
    }
    uri.query = URI.encode_www_form(params)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 5

    # In development, be more lenient with SSL verification
    # In production, use proper SSL verification
    if Rails.env.development?
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    request = Net::HTTP::Get.new(uri)
    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise GeocodingError, "API returned #{response.code}: #{response.body}"
    end

    JSON.parse(response.body)
  end

  def parse_response(response)
    results = response['results']
    return nil if results.blank?

    # Use the first (best) result
    result = results.first
    location = result['location']
    address_components = result['address_components']

    {
      latitude: location['lat'],
      longitude: location['lng'],
      # Normalized address components from Geocodio
      address_line_1: format_address_line_1(address_components),
      address_line_2: nil, # Geocodio doesn't typically return line 2
      city: address_components['city'],
      state: address_components['state'],
      zip_code: format_zip_code(address_components)
    }
  end

  def format_address_line_1(components)
    parts = []
    parts << components['number'] if components['number'].present?
    parts << components['predirectional'] if components['predirectional'].present?
    parts << components['street'] if components['street'].present?
    parts << components['suffix'] if components['suffix'].present?
    parts << components['postdirectional'] if components['postdirectional'].present?
    parts.join(' ')
  end

  def format_zip_code(components)
    zip = components['zip']
    plus4 = components['plus4']

    if zip.present? && plus4.present?
      "#{zip}-#{plus4}"
    else
      zip
    end
  end
end
