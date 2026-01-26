"use client"

import { useEffect, useState, useCallback } from "react"
import { toast } from "sonner"
import { MapPin, Plus, Pencil, Trash2, Power } from "lucide-react"
import { apiClient, type WorkLocation } from "@/lib/api/client"
import { useOnboarding } from "@/contexts/onboarding-context"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog"
import { WorkLocationForm, type WorkLocationFormData } from "./work-location-form"

export function WorkLocationsSection() {
  const { refreshOnboardingStatus } = useOnboarding()
  const [locations, setLocations] = useState<WorkLocation[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [showAddForm, setShowAddForm] = useState(false)
  const [editingLocation, setEditingLocation] = useState<WorkLocation | null>(null)
  const [deleteConfirmLocation, setDeleteConfirmLocation] = useState<WorkLocation | null>(null)

  const loadLocations = useCallback(async () => {
    try {
      const response = await apiClient.getWorkLocations({ include_inactive: true })
      if (response.data) {
        setLocations(response.data.work_locations)
      }
    } catch (error) {
      console.error("Failed to load work locations:", error)
      toast.error("Failed to load work locations")
    } finally {
      setIsLoading(false)
    }
  }, [])

  useEffect(() => {
    loadLocations()
  }, [loadLocations])

  const handleAddLocation = async (data: WorkLocationFormData) => {
    setIsSubmitting(true)
    try {
      const response = await apiClient.createWorkLocation({
        name: data.name,
        address_line_1: data.address_line_1,
        address_line_2: data.address_line_2,
        city: data.city,
        state: data.state.toUpperCase(),
        zip_code: data.zip_code,
        arrival_instructions: data.arrival_instructions,
        parking_notes: data.parking_notes,
      })

      if (response.error) {
        toast.error(response.error)
      } else {
        toast.success("Work location added successfully")
        setShowAddForm(false)
        await loadLocations()
        // Refresh onboarding status to update the onboarding card
        await refreshOnboardingStatus()
      }
    } catch (error) {
      console.error("Failed to add location:", error)
      toast.error("Failed to add location")
    } finally {
      setIsSubmitting(false)
    }
  }

  const handleEditLocation = async (data: WorkLocationFormData) => {
    if (!editingLocation) return

    setIsSubmitting(true)
    try {
      const response = await apiClient.updateWorkLocation(editingLocation.id, {
        name: data.name,
        address_line_1: data.address_line_1,
        address_line_2: data.address_line_2,
        city: data.city,
        state: data.state.toUpperCase(),
        zip_code: data.zip_code,
        arrival_instructions: data.arrival_instructions,
        parking_notes: data.parking_notes,
        is_active: data.is_active,
      })

      if (response.error) {
        toast.error(response.error)
      } else {
        toast.success("Work location updated successfully")
        setEditingLocation(null)
        await loadLocations()
      }
    } catch (error) {
      console.error("Failed to update location:", error)
      toast.error("Failed to update location")
    } finally {
      setIsSubmitting(false)
    }
  }

  const handleDeleteLocation = async () => {
    if (!deleteConfirmLocation) return

    setIsSubmitting(true)
    try {
      const response = await apiClient.deleteWorkLocation(deleteConfirmLocation.id)

      if (response.error) {
        toast.error(response.error)
      } else {
        toast.success("Work location deleted successfully")
        await loadLocations()
        // Refresh onboarding status in case this was the last location
        await refreshOnboardingStatus()
      }
    } catch (error) {
      console.error("Failed to delete location:", error)
      toast.error("Failed to delete location")
    } finally {
      setIsSubmitting(false)
      setDeleteConfirmLocation(null)
    }
  }

  const handleToggleActive = async (location: WorkLocation) => {
    setIsSubmitting(true)
    try {
      const newActiveState = !location.is_active
      const response = await apiClient.updateWorkLocation(location.id, {
        is_active: newActiveState,
      })

      if (response.error) {
        toast.error(response.error)
      } else {
        toast.success(
          newActiveState
            ? "Work location activated successfully"
            : "Work location deactivated successfully"
        )
        await loadLocations()
      }
    } catch (error) {
      console.error("Failed to toggle location status:", error)
      toast.error("Failed to update location status")
    } finally {
      setIsSubmitting(false)
    }
  }

  const handleCancelForm = () => {
    setShowAddForm(false)
    setEditingLocation(null)
  }

  if (isLoading) {
    return (
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <MapPin className="h-5 w-5" />
            Work Locations
          </CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-muted-foreground">Loading...</p>
        </CardContent>
      </Card>
    )
  }

  return (
    <>
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <div>
              <CardTitle className="flex items-center gap-2">
                <MapPin className="h-5 w-5" />
                Work Locations
              </CardTitle>
              <CardDescription className="mt-1.5">
                Manage the locations where your workers will report for shifts
              </CardDescription>
            </div>
            {!showAddForm && !editingLocation && (
              <Button onClick={() => setShowAddForm(true)} size="sm">
                <Plus className="h-4 w-4 mr-1" />
                Add Location
              </Button>
            )}
          </div>
        </CardHeader>
        <CardContent>
          {/* Add Form */}
          {showAddForm && (
            <div className="mb-6 p-4 border rounded-lg bg-muted/30">
              <h4 className="font-medium mb-4">Add New Location</h4>
              <WorkLocationForm
                onSubmit={handleAddLocation}
                onCancel={handleCancelForm}
                isSubmitting={isSubmitting}
              />
            </div>
          )}

          {/* Locations List */}
          {locations.length === 0 && !showAddForm ? (
            <div className="text-center py-8">
              <MapPin className="h-12 w-12 mx-auto text-muted-foreground/50 mb-3" />
              <p className="text-muted-foreground mb-4">No work locations yet</p>
              <Button onClick={() => setShowAddForm(true)} variant="outline">
                <Plus className="h-4 w-4 mr-1" />
                Add Your First Location
              </Button>
            </div>
          ) : (
            <>
              {locations.length === 1 && (
                <div className="mb-4 p-3 rounded-lg bg-blue-50 dark:bg-blue-950/20 border border-blue-200 dark:border-blue-800">
                  <p className="text-sm text-blue-900 dark:text-blue-100">
                    <span className="font-medium">Note:</span> This is your only location. Companies
                    must have at least one location, so you cannot delete it until you add another.
                  </p>
                </div>
              )}
              <div className="space-y-4">
              {locations.map((location) => (
                <div key={location.id}>
                  {editingLocation?.id === location.id ? (
                    <div className="p-4 border rounded-lg bg-muted/30">
                      <h4 className="font-medium mb-4">Edit Location</h4>
                      <WorkLocationForm
                        location={location}
                        onSubmit={handleEditLocation}
                        onCancel={handleCancelForm}
                        isSubmitting={isSubmitting}
                      />
                    </div>
                  ) : (
                    <div
                      className={`flex items-start justify-between p-4 border rounded-lg ${
                        !location.is_active ? "opacity-60" : ""
                      }`}
                    >
                      <div className="space-y-1">
                        <div className="flex items-center gap-2">
                          <h4 className="font-medium">{location.name}</h4>
                          {!location.is_active && (
                            <Badge variant="secondary" className="text-xs">
                              Inactive
                            </Badge>
                          )}
                        </div>
                        <p className="text-sm text-muted-foreground">
                          {location.address.full_address}
                        </p>
                        {location.instructions.arrival && (
                          <p className="text-xs text-muted-foreground">
                            <span className="font-medium">Arrival:</span>{" "}
                            {location.instructions.arrival}
                          </p>
                        )}
                        {location.instructions.parking && (
                          <p className="text-xs text-muted-foreground">
                            <span className="font-medium">Parking:</span>{" "}
                            {location.instructions.parking}
                          </p>
                        )}
                      </div>
                      <div className="flex gap-1">
                        <Button
                          variant="ghost"
                          size="icon-sm"
                          onClick={() => handleToggleActive(location)}
                          title={
                            location.is_active
                              ? "Deactivate location"
                              : "Activate location"
                          }
                          disabled={isSubmitting}
                          className={
                            location.is_active
                              ? ""
                              : "text-green-600 hover:text-green-600 hover:bg-green-50 dark:text-green-500 dark:hover:bg-green-950"
                          }
                        >
                          <Power className="h-4 w-4" />
                        </Button>
                        <Button
                          variant="ghost"
                          size="icon-sm"
                          onClick={() => setEditingLocation(location)}
                          title="Edit location"
                          disabled={isSubmitting}
                        >
                          <Pencil className="h-4 w-4" />
                        </Button>
                        {locations.length > 1 && (
                          <Button
                            variant="ghost"
                            size="icon-sm"
                            onClick={() => setDeleteConfirmLocation(location)}
                            title="Delete location"
                            disabled={isSubmitting}
                            className="text-destructive hover:text-destructive hover:bg-destructive/10"
                          >
                            <Trash2 className="h-4 w-4" />
                          </Button>
                        )}
                      </div>
                    </div>
                  )}
                </div>
              ))}
            </div>
            </>
          )}
        </CardContent>
      </Card>

      {/* Delete Confirmation Dialog */}
      <AlertDialog
        open={!!deleteConfirmLocation}
        onOpenChange={(open) => !open && setDeleteConfirmLocation(null)}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete Work Location</AlertDialogTitle>
            <AlertDialogDescription>
              {locations.length <= 1 ? (
                <>
                  You cannot delete your last work location. Companies must have at least one
                  location. Add another location first if you want to delete &quot;
                  {deleteConfirmLocation?.name}&quot;.
                </>
              ) : (
                <>
                  Are you sure you want to delete &quot;{deleteConfirmLocation?.name}&quot;? This
                  action cannot be undone.
                </>
              )}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            {locations.length > 1 && (
              <AlertDialogAction
                onClick={handleDeleteLocation}
                className="bg-destructive text-white hover:bg-destructive/90"
              >
                {isSubmitting ? "Deleting..." : "Delete"}
              </AlertDialogAction>
            )}
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  )
}
