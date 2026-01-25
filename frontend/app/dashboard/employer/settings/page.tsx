"use client"

import { useSearchParams, useRouter } from "next/navigation"
import { Suspense } from "react"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { PersonalSettingsPanel } from "@/components/employer-settings/personal-settings-panel"
import { CompanySettingsPanel } from "@/components/employer-settings/company-settings-panel"

function SettingsContent() {
  const searchParams = useSearchParams()
  const router = useRouter()

  const currentTab = searchParams.get("tab") || "personal"

  const handleTabChange = (value: string) => {
    if (value === "personal") {
      router.push("/dashboard/employer/settings")
    } else {
      router.push(`/dashboard/employer/settings?tab=${value}`)
    }
  }

  return (
    <div className="container max-w-4xl mx-auto p-6 space-y-8">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Settings</h1>
        <p className="text-muted-foreground mt-2">
          Manage your account settings and company preferences
        </p>
      </div>

      <Tabs value={currentTab} onValueChange={handleTabChange}>
        <TabsList>
          <TabsTrigger value="personal">Your Settings</TabsTrigger>
          <TabsTrigger value="company">Company Settings</TabsTrigger>
        </TabsList>

        <TabsContent value="personal">
          <PersonalSettingsPanel />
        </TabsContent>

        <TabsContent value="company">
          <CompanySettingsPanel />
        </TabsContent>
      </Tabs>
    </div>
  )
}

export default function SettingsPage() {
  return (
    <Suspense
      fallback={
        <div className="flex items-center justify-center min-h-screen">
          <p>Loading...</p>
        </div>
      }
    >
      <SettingsContent />
    </Suspense>
  )
}
