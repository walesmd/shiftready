# frozen_string_literal: true

# Application-wide constants
module AppConstants
  # Pay rate constraints (in dollars)
  FEDERAL_MINIMUM_WAGE = 7.25
  MAXIMUM_HOURLY_WAGE = 100.0

  # Pay rate constraints (in cents)
  FEDERAL_MINIMUM_WAGE_CENTS = (FEDERAL_MINIMUM_WAGE * 100).to_i
  MAXIMUM_HOURLY_WAGE_CENTS = (MAXIMUM_HOURLY_WAGE * 100).to_i

  # Service fees
  SERVICE_FEE_RATE = 0.2 # 20%
end
