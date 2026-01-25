"use client"

import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import * as z from "zod"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { Checkbox } from "@/components/ui/checkbox"
import type { WorkLocation } from "@/lib/api/client"

const workLocationSchema = z.object({
  name: z.string().min(1, "Location name is required"),
  address_line_1: z.string().min(1, "Street address is required"),
  address_line_2: z.string().optional(),
  city: z.string().min(1, "City is required"),
  state: z.string().min(2, "State is required").max(2, "Use 2-letter state code"),
  zip_code: z.string().min(5, "Valid ZIP code required").max(10, "Valid ZIP code required"),
  arrival_instructions: z.string().optional(),
  parking_notes: z.string().optional(),
  is_active: z.boolean().optional(),
})

export type WorkLocationFormData = z.infer<typeof workLocationSchema>

interface WorkLocationFormProps {
  location?: WorkLocation
  onSubmit: (data: WorkLocationFormData) => Promise<void>
  onCancel: () => void
  isSubmitting: boolean
}

export function WorkLocationForm({
  location,
  onSubmit,
  onCancel,
  isSubmitting,
}: WorkLocationFormProps) {
  const isEditMode = !!location

  const form = useForm<WorkLocationFormData>({
    resolver: zodResolver(workLocationSchema),
    defaultValues: {
      name: location?.name || "",
      address_line_1: location?.address.line_1 || "",
      address_line_2: location?.address.line_2 || "",
      city: location?.address.city || "",
      state: location?.address.state || "",
      zip_code: location?.address.zip_code || "",
      arrival_instructions: location?.instructions.arrival || "",
      parking_notes: location?.instructions.parking || "",
      is_active: location?.is_active ?? true,
    },
  })

  const handleSubmit = form.handleSubmit(async (data) => {
    await onSubmit(data)
  })

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {/* Location Name */}
        <div className="space-y-2 md:col-span-2">
          <Label htmlFor="name">Location Name</Label>
          <Input
            id="name"
            placeholder="e.g., Main Office, Downtown Branch"
            {...form.register("name")}
            className="bg-card"
          />
          {form.formState.errors.name && (
            <p className="text-sm text-destructive">
              {form.formState.errors.name.message}
            </p>
          )}
        </div>

        {/* Street Address */}
        <div className="space-y-2 md:col-span-2">
          <Label htmlFor="address_line_1">Street Address</Label>
          <Input
            id="address_line_1"
            placeholder="123 Main Street"
            {...form.register("address_line_1")}
            className="bg-card"
          />
          {form.formState.errors.address_line_1 && (
            <p className="text-sm text-destructive">
              {form.formState.errors.address_line_1.message}
            </p>
          )}
        </div>

        {/* Address Line 2 */}
        <div className="space-y-2 md:col-span-2">
          <Label htmlFor="address_line_2">Suite / Unit (optional)</Label>
          <Input
            id="address_line_2"
            placeholder="Suite 100"
            {...form.register("address_line_2")}
            className="bg-card"
          />
        </div>

        {/* City */}
        <div className="space-y-2">
          <Label htmlFor="city">City</Label>
          <Input
            id="city"
            placeholder="San Antonio"
            {...form.register("city")}
            className="bg-card"
          />
          {form.formState.errors.city && (
            <p className="text-sm text-destructive">
              {form.formState.errors.city.message}
            </p>
          )}
        </div>

        {/* State and ZIP */}
        <div className="grid grid-cols-2 gap-4">
          <div className="space-y-2">
            <Label htmlFor="state">State</Label>
            <Input
              id="state"
              placeholder="TX"
              maxLength={2}
              {...form.register("state")}
              className="bg-card uppercase"
            />
            {form.formState.errors.state && (
              <p className="text-sm text-destructive">
                {form.formState.errors.state.message}
              </p>
            )}
          </div>
          <div className="space-y-2">
            <Label htmlFor="zip_code">ZIP Code</Label>
            <Input
              id="zip_code"
              placeholder="78201"
              {...form.register("zip_code")}
              className="bg-card"
            />
            {form.formState.errors.zip_code && (
              <p className="text-sm text-destructive">
                {form.formState.errors.zip_code.message}
              </p>
            )}
          </div>
        </div>

        {/* Arrival Instructions */}
        <div className="space-y-2 md:col-span-2">
          <Label htmlFor="arrival_instructions">Arrival Instructions (optional)</Label>
          <Textarea
            id="arrival_instructions"
            placeholder="Enter through the side entrance, check in at the front desk..."
            {...form.register("arrival_instructions")}
            className="bg-card"
            rows={2}
          />
        </div>

        {/* Parking Notes */}
        <div className="space-y-2 md:col-span-2">
          <Label htmlFor="parking_notes">Parking Notes (optional)</Label>
          <Textarea
            id="parking_notes"
            placeholder="Free parking available in the north lot, street parking on Main St..."
            {...form.register("parking_notes")}
            className="bg-card"
            rows={2}
          />
        </div>

        {/* Active Status (edit mode only) */}
        {isEditMode && (
          <div className="flex items-center space-x-2 md:col-span-2">
            <Checkbox
              id="is_active"
              checked={form.watch("is_active")}
              onCheckedChange={(checked) =>
                form.setValue("is_active", checked === true)
              }
            />
            <Label htmlFor="is_active" className="font-normal cursor-pointer">
              Location is active and can be used for new shifts
            </Label>
          </div>
        )}
      </div>

      <div className="flex justify-end gap-2 pt-4">
        <Button type="button" variant="outline" onClick={onCancel}>
          Cancel
        </Button>
        <Button type="submit" disabled={isSubmitting}>
          {isSubmitting
            ? isEditMode
              ? "Saving..."
              : "Adding..."
            : isEditMode
            ? "Save Changes"
            : "Add Location"}
        </Button>
      </div>
    </form>
  )
}
