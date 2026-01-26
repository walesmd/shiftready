"use client"

import { useEffect, useState } from "react"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import * as z from "zod"
import { toast } from "sonner"
import { Receipt } from "lucide-react"
import { useAuth } from "@/contexts/auth-context"
import { useOnboarding } from "@/contexts/onboarding-context"
import { apiClient, type Company } from "@/lib/api/client"
import { normalizePhoneNumber, isValidPhoneNumber } from "@/lib/phone"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"

const billingSchema = z.object({
  billing_email: z.string().email("Invalid email address").or(z.literal("")),
  billing_phone: z.string().refine(
    (val) => val === "" || isValidPhoneNumber(val),
    "Invalid phone number"
  ),
  billing_address_line_1: z.string(),
  billing_address_line_2: z.string(),
  billing_city: z.string(),
  billing_state: z.string().regex(/^[A-Za-z]{2}$/, "State must be 2 letters").or(z.literal("")),
  billing_zip_code: z.string().regex(/^\d{5}(-\d{4})?$/, "Invalid ZIP code").or(z.literal("")),
})

type BillingFormData = z.infer<typeof billingSchema>

export function CompanyBillingSection() {
  const { user } = useAuth()
  const { refreshOnboardingStatus } = useOnboarding()
  const [isLoading, setIsLoading] = useState(true)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [company, setCompany] = useState<Company | null>(null)

  const form = useForm<BillingFormData>({
    resolver: zodResolver(billingSchema),
    defaultValues: {
      billing_email: "",
      billing_phone: "",
      billing_address_line_1: "",
      billing_address_line_2: "",
      billing_city: "",
      billing_state: "",
      billing_zip_code: "",
    },
  })

  useEffect(() => {
    if (!user) {
      setIsLoading(false)
      return
    }

    const loadCompanyData = async () => {
      setIsLoading(true)
      try {
        // Get employer profile to get company_id
        const profileResponse = await apiClient.getEmployerProfile()
        if (profileResponse.error || !profileResponse.data?.company_id) {
          toast.error("Failed to load company information")
          setIsLoading(false)
          return
        }

        // Get company details
        const companyResponse = await apiClient.getCompany(profileResponse.data.company_id)
        if (companyResponse.error || !companyResponse.data) {
          toast.error("Failed to load company billing information")
          setIsLoading(false)
          return
        }

        const companyData = companyResponse.data
        setCompany(companyData)

        form.reset({
          billing_email: companyData.billing_info.email || "",
          billing_phone: companyData.billing_info.phone || "",
          billing_address_line_1: companyData.billing_info.address_line_1 || "",
          billing_address_line_2: companyData.billing_info.address_line_2 || "",
          billing_city: companyData.billing_info.city || "",
          billing_state: companyData.billing_info.state || "",
          billing_zip_code: companyData.billing_info.zip_code || "",
        })
      } catch (error) {
        toast.error("Failed to load company billing information")
        console.error(error)
      } finally {
        setIsLoading(false)
      }
    }

    loadCompanyData()
  }, [user, form])

  const onSubmit = async (data: BillingFormData) => {
    if (!company) {
      toast.error("Company information not loaded")
      return
    }

    setIsSubmitting(true)
    try {
      // Normalize phone number before sending
      const normalizedPhone = data.billing_phone
        ? normalizePhoneNumber(data.billing_phone) ?? ""
        : ""

      const response = await apiClient.updateCompany(company.id, {
        billing_email: data.billing_email,
        billing_phone: normalizedPhone,
        billing_address_line_1: data.billing_address_line_1,
        billing_address_line_2: data.billing_address_line_2,
        billing_city: data.billing_city,
        billing_state: data.billing_state ? data.billing_state.toUpperCase() : "",
        billing_zip_code: data.billing_zip_code,
      })

      if (response.error) {
        toast.error(response.error)
      } else {
        toast.success("Billing information updated successfully")
        // Reload company data to get updated geocoded coordinates
        const updatedCompany = await apiClient.getCompany(company.id)
        if (updatedCompany.data) {
          setCompany(updatedCompany.data)
        }
        // Refresh onboarding status to update the onboarding card
        await refreshOnboardingStatus()
      }
    } catch (error) {
      toast.error("Failed to update billing information")
      console.error(error)
    } finally {
      setIsSubmitting(false)
    }
  }

  if (isLoading) {
    return (
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Receipt className="h-5 w-5" />
            Billing Information
          </CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-muted-foreground">Loading...</p>
        </CardContent>
      </Card>
    )
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Receipt className="h-5 w-5" />
          Billing Information
        </CardTitle>
        <CardDescription>
          Manage billing contact details and address for invoices
        </CardDescription>
      </CardHeader>
      <CardContent>
        <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {/* Billing Email */}
            <div className="space-y-2">
              <Label htmlFor="billing_email">Billing Email</Label>
              <Input
                id="billing_email"
                type="email"
                {...form.register("billing_email")}
                placeholder="billing@example.com"
                className="bg-card"
              />
              {form.formState.errors.billing_email && (
                <p className="text-sm text-destructive">
                  {form.formState.errors.billing_email.message}
                </p>
              )}
            </div>

            {/* Billing Phone */}
            <div className="space-y-2">
              <Label htmlFor="billing_phone">Billing Phone</Label>
              <Input
                id="billing_phone"
                type="tel"
                {...form.register("billing_phone")}
                placeholder="(210) 555-0123"
                className="bg-card"
              />
              {form.formState.errors.billing_phone && (
                <p className="text-sm text-destructive">
                  {form.formState.errors.billing_phone.message}
                </p>
              )}
            </div>

            {/* Billing Address Line 1 */}
            <div className="space-y-2 md:col-span-2">
              <Label htmlFor="billing_address_line_1">Address Line 1</Label>
              <Input
                id="billing_address_line_1"
                type="text"
                {...form.register("billing_address_line_1")}
                placeholder="123 Main St"
                className="bg-card"
              />
              {form.formState.errors.billing_address_line_1 && (
                <p className="text-sm text-destructive">
                  {form.formState.errors.billing_address_line_1.message}
                </p>
              )}
            </div>

            {/* Billing Address Line 2 */}
            <div className="space-y-2 md:col-span-2">
              <Label htmlFor="billing_address_line_2">
                Address Line 2 <span className="text-muted-foreground">(optional)</span>
              </Label>
              <Input
                id="billing_address_line_2"
                type="text"
                {...form.register("billing_address_line_2")}
                placeholder="Suite 100"
                className="bg-card"
              />
              {form.formState.errors.billing_address_line_2 && (
                <p className="text-sm text-destructive">
                  {form.formState.errors.billing_address_line_2.message}
                </p>
              )}
            </div>

            {/* Billing City */}
            <div className="space-y-2">
              <Label htmlFor="billing_city">City</Label>
              <Input
                id="billing_city"
                type="text"
                {...form.register("billing_city")}
                placeholder="San Antonio"
                className="bg-card"
              />
              {form.formState.errors.billing_city && (
                <p className="text-sm text-destructive">
                  {form.formState.errors.billing_city.message}
                </p>
              )}
            </div>

            {/* Billing State */}
            <div className="space-y-2">
              <Label htmlFor="billing_state">State</Label>
              <Input
                id="billing_state"
                type="text"
                {...form.register("billing_state")}
                placeholder="TX"
                maxLength={2}
                className="bg-card"
              />
              {form.formState.errors.billing_state && (
                <p className="text-sm text-destructive">
                  {form.formState.errors.billing_state.message}
                </p>
              )}
            </div>

            {/* Billing ZIP Code */}
            <div className="space-y-2">
              <Label htmlFor="billing_zip_code">ZIP Code</Label>
              <Input
                id="billing_zip_code"
                type="text"
                {...form.register("billing_zip_code")}
                placeholder="78201"
                className="bg-card"
              />
              {form.formState.errors.billing_zip_code && (
                <p className="text-sm text-destructive">
                  {form.formState.errors.billing_zip_code.message}
                </p>
              )}
            </div>
          </div>

          <div className="flex justify-end">
            <Button type="submit" disabled={isSubmitting}>
              {isSubmitting ? "Saving..." : "Save Changes"}
            </Button>
          </div>
        </form>
      </CardContent>
    </Card>
  )
}
