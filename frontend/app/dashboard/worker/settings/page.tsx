"use client"

import { useEffect, useState } from "react"
import { useRouter } from "next/navigation"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import * as z from "zod"
import { toast } from "sonner"
import { useAuth } from "@/contexts/auth-context"
import { apiClient } from "@/lib/api/client"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"

// Validation schemas
const profileSchema = z.object({
  first_name: z.string().min(1, "First name is required"),
  last_name: z.string().min(1, "Last name is required"),
  address_line_1: z.string().min(1, "Address is required"),
  address_line_2: z.string().optional(),
  city: z.string().min(1, "City is required"),
  state: z.string().length(2, "State must be 2 characters (e.g., TX)"),
  zip_code: z.string().min(5, "ZIP code must be at least 5 digits"),
})

const passwordSchema = z.object({
  current_password: z.string().min(1, "Current password is required"),
  password: z.string().min(6, "Password must be at least 6 characters"),
  password_confirmation: z.string().min(1, "Please confirm your password"),
}).refine((data) => data.password === data.password_confirmation, {
  message: "Passwords do not match",
  path: ["password_confirmation"],
})

type ProfileFormData = z.infer<typeof profileSchema>
type PasswordFormData = z.infer<typeof passwordSchema>

export default function SettingsPage() {
  const router = useRouter()
  const { user, refreshUser, logout } = useAuth()
  const [isLoadingProfile, setIsLoadingProfile] = useState(true)
  const [isSubmittingProfile, setIsSubmittingProfile] = useState(false)
  const [isSubmittingPassword, setIsSubmittingPassword] = useState(false)
  const [profileDisplay, setProfileDisplay] = useState({
    email: "",
    phone: "",
  })

  // Profile form
  const profileForm = useForm<ProfileFormData>({
    resolver: zodResolver(profileSchema),
    defaultValues: {
      first_name: "",
      last_name: "",
      address_line_1: "",
      address_line_2: "",
      city: "",
      state: "",
      zip_code: "",
    },
  })

  // Password form
  const passwordForm = useForm<PasswordFormData>({
    resolver: zodResolver(passwordSchema),
    defaultValues: {
      current_password: "",
      password: "",
      password_confirmation: "",
    },
  })

  // Load user profile data
  useEffect(() => {
    const loadProfile = async () => {
      setIsLoadingProfile(true)
      try {
        const response = await apiClient.getWorkerProfile()
        if (response.data && user) {
          const address = response.data.address ?? {
            line_1: "",
            line_2: "",
            city: "",
            state: "",
            zip_code: "",
          }

          setProfileDisplay({
            email: user.email,
            phone: response.data.phone || "",
          })

          profileForm.reset({
            first_name: response.data.first_name,
            last_name: response.data.last_name,
            address_line_1: address.line_1,
            address_line_2: address.line_2 || "",
            city: address.city,
            state: address.state,
            zip_code: address.zip_code,
          })
        }
      } catch (error) {
        toast.error("Failed to load profile")
        console.error(error)
      } finally {
        setIsLoadingProfile(false)
      }
    }

    if (user) {
      loadProfile()
    }
  }, [user, profileForm])

  // Handle profile form submission
  const onSubmitProfile = async (data: ProfileFormData) => {
    setIsSubmittingProfile(true)
    try {
      // Update worker profile
      const profileResponse = await apiClient.updateWorkerProfile({
        first_name: data.first_name,
        last_name: data.last_name,
        address_line_1: data.address_line_1,
        address_line_2: data.address_line_2 || undefined,
        city: data.city,
        state: data.state,
        zip_code: data.zip_code,
      })

      if (profileResponse.error) {
        toast.error(profileResponse.error)
      } else {
        toast.success("Profile updated successfully")
        // Refresh user data in auth context
        await refreshUser()
      }
    } catch (error) {
      toast.error("Failed to update profile")
      console.error(error)
    } finally {
      setIsSubmittingProfile(false)
    }
  }

  // Handle password form submission
  const onSubmitPassword = async (data: PasswordFormData) => {
    setIsSubmittingPassword(true)
    try {
      const response = await apiClient.updatePassword(
        data.current_password,
        data.password,
        data.password_confirmation
      )

      if (response.error) {
        toast.error(response.error)
        setIsSubmittingPassword(false)
      } else {
        toast.success("Password updated successfully. Please log in with your new password.")

        // Log out the user (token is now invalid due to JTI regeneration)
        await logout()

        // Redirect to login page
        router.push("/login")
      }
    } catch (error) {
      toast.error("Failed to update password")
      console.error(error)
      setIsSubmittingPassword(false)
    }
  }

  if (isLoadingProfile) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <p>Loading...</p>
      </div>
    )
  }

  return (
    <div className="container max-w-4xl mx-auto p-6 space-y-8">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Settings</h1>
        <p className="text-muted-foreground mt-2">
          Manage your account settings and preferences
        </p>
      </div>

      {/* Profile Information Section */}
      <Card>
        <CardHeader>
          <CardTitle>Profile Information</CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={profileForm.handleSubmit(onSubmitProfile)} className="space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {/* Email */}
              <div className="space-y-2">
                <Label htmlFor="email">Email Address</Label>
                <Input
                  id="email"
                  type="email"
                  value={profileDisplay.email}
                  disabled
                  className="bg-card"
                />
              </div>

              {/* Phone */}
              <div className="space-y-2">
                <Label htmlFor="phone">Phone Number</Label>
                <Input
                  id="phone"
                  type="tel"
                  value={profileDisplay.phone}
                  disabled
                  className="bg-card"
                />
              </div>

              {/* First Name */}
              <div className="space-y-2">
                <Label htmlFor="first_name">First Name</Label>
                <Input
                  id="first_name"
                  type="text"
                  {...profileForm.register("first_name")}
                  className="bg-card"
                />
                {profileForm.formState.errors.first_name && (
                  <p className="text-sm text-destructive">
                    {profileForm.formState.errors.first_name.message}
                  </p>
                )}
              </div>

              {/* Last Name */}
              <div className="space-y-2">
                <Label htmlFor="last_name">Last Name</Label>
                <Input
                  id="last_name"
                  type="text"
                  {...profileForm.register("last_name")}
                  className="bg-card"
                />
                {profileForm.formState.errors.last_name && (
                  <p className="text-sm text-destructive">
                    {profileForm.formState.errors.last_name.message}
                  </p>
                )}
              </div>
            </div>

            {/* Address */}
            <div className="space-y-2">
              <Label htmlFor="address_line_1">Address</Label>
              <Input
                id="address_line_1"
                type="text"
                {...profileForm.register("address_line_1")}
                className="bg-card"
              />
              {profileForm.formState.errors.address_line_1 && (
                <p className="text-sm text-destructive">
                  {profileForm.formState.errors.address_line_1.message}
                </p>
              )}
            </div>

            {/* Address Line 2 (Optional) */}
            <div className="space-y-2">
              <Label htmlFor="address_line_2">Address Line 2 (Optional)</Label>
              <Input
                id="address_line_2"
                type="text"
                {...profileForm.register("address_line_2")}
                className="bg-card"
              />
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              {/* City */}
              <div className="space-y-2">
                <Label htmlFor="city">City</Label>
                <Input
                  id="city"
                  type="text"
                  {...profileForm.register("city")}
                  className="bg-card"
                />
                {profileForm.formState.errors.city && (
                  <p className="text-sm text-destructive">
                    {profileForm.formState.errors.city.message}
                  </p>
                )}
              </div>

              {/* State */}
              <div className="space-y-2">
                <Label htmlFor="state">State</Label>
                <Input
                  id="state"
                  type="text"
                  maxLength={2}
                  placeholder="TX"
                  {...profileForm.register("state")}
                  className="bg-card"
                />
                {profileForm.formState.errors.state && (
                  <p className="text-sm text-destructive">
                    {profileForm.formState.errors.state.message}
                  </p>
                )}
              </div>

              {/* ZIP Code */}
              <div className="space-y-2">
                <Label htmlFor="zip_code">ZIP Code</Label>
                <Input
                  id="zip_code"
                  type="text"
                  {...profileForm.register("zip_code")}
                  className="bg-card"
                />
                {profileForm.formState.errors.zip_code && (
                  <p className="text-sm text-destructive">
                    {profileForm.formState.errors.zip_code.message}
                  </p>
                )}
              </div>
            </div>

            <div className="flex justify-end">
              <Button type="submit" disabled={isSubmittingProfile}>
                {isSubmittingProfile ? "Saving..." : "Save Changes"}
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>

      {/* Password Section */}
      <Card>
        <CardHeader>
          <CardTitle>Change Password</CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={passwordForm.handleSubmit(onSubmitPassword)} className="space-y-6">
            {/* Current Password */}
            <div className="space-y-2">
              <Label htmlFor="current_password">Current Password</Label>
              <Input
                id="current_password"
                type="password"
                {...passwordForm.register("current_password")}
                className="bg-card"
              />
              {passwordForm.formState.errors.current_password && (
                <p className="text-sm text-destructive">
                  {passwordForm.formState.errors.current_password.message}
                </p>
              )}
            </div>

            {/* New Password */}
            <div className="space-y-2">
              <Label htmlFor="password">New Password</Label>
              <Input
                id="password"
                type="password"
                {...passwordForm.register("password")}
                className="bg-card"
              />
              {passwordForm.formState.errors.password && (
                <p className="text-sm text-destructive">
                  {passwordForm.formState.errors.password.message}
                </p>
              )}
            </div>

            {/* Confirm New Password */}
            <div className="space-y-2">
              <Label htmlFor="password_confirmation">Confirm New Password</Label>
              <Input
                id="password_confirmation"
                type="password"
                {...passwordForm.register("password_confirmation")}
                className="bg-card"
              />
              {passwordForm.formState.errors.password_confirmation && (
                <p className="text-sm text-destructive">
                  {passwordForm.formState.errors.password_confirmation.message}
                </p>
              )}
            </div>

            <div className="flex justify-end">
              <Button type="submit" disabled={isSubmittingPassword}>
                {isSubmittingPassword ? "Updating..." : "Update Password"}
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  )
}
