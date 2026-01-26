/**
 * Phone number utilities for formatting and normalization
 */

/**
 * Normalizes a phone number to E.164 format (+1XXXXXXXXXX)
 * Matches backend PhoneNormalizationService behavior
 *
 * @param phoneNumber - Raw phone number input
 * @returns Normalized phone number in E.164 format, or null if invalid
 */
export function normalizePhoneNumber(phoneNumber: string | null | undefined): string | null {
  if (!phoneNumber) return null

  // Strip all non-digit characters
  const digits = phoneNumber.replace(/\D/g, "")

  // Handle different digit counts
  if (digits.length === 10) {
    // 10 digits: assume US number, add +1
    return `+1${digits}`
  } else if (digits.length === 11 && digits.startsWith("1")) {
    // 11 digits starting with 1: add +
    return `+${digits}`
  }

  // Invalid: not 10 or 11 digits, or 11 digits not starting with 1
  return null
}

/**
 * Formats a normalized phone number for display
 * Converts +12105550123 to (210) 555-0123
 * Matches backend PhoneNormalizationService.format_display behavior
 *
 * @param phoneNumber - Normalized phone number in E.164 format
 * @returns Formatted phone number for display
 */
export function formatPhoneDisplay(phoneNumber: string | null | undefined): string {
  if (!phoneNumber) return ""

  // Strip all non-digit characters
  const digits = phoneNumber.replace(/\D/g, "")

  // Should be 11 digits starting with 1 (US format)
  if (digits.length !== 11 || !digits.startsWith("1")) {
    return phoneNumber
  }

  // Remove country code and format
  const localDigits = digits.substring(1)
  return `(${localDigits.substring(0, 3)}) ${localDigits.substring(3, 6)}-${localDigits.substring(6, 10)}`
}

/**
 * Validates if a phone number can be normalized
 *
 * @param phoneNumber - Raw phone number input
 * @returns true if the phone number can be normalized
 */
export function isValidPhoneNumber(phoneNumber: string | null | undefined): boolean {
  return normalizePhoneNumber(phoneNumber) !== null
}
