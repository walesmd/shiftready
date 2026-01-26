"use client"

import { CompanyBillingSection } from "./company-billing-section"
import { WorkLocationsSection } from "./work-locations-section"

export function CompanySettingsPanel() {
  return (
    <div className="space-y-8">
      <CompanyBillingSection />
      <WorkLocationsSection />
    </div>
  )
}
