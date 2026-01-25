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
  email: z.string().email("Invalid email address"),
  first_name: z.string().min(1, "First name is required"),
  last_name: z.string().min(1, "Last name is required"),
  phone: z.string().min(10, "Phone number must be at least 10 digits"),
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

  // Profile form
  const profileForm = useForm<ProfileFormData>({
    resolver: zodResolver(profileSchema),
    defaultValues: {
      email: "",
      first_name: "",
      last_name: "",
      phone: "",
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
        const response = await apiClient.getEmployerProfile()
        if (response.data && user) {
          profileForm.reset({
            email: user.email,
            first_name: response.data.first_name,
            last_name: response.data.last_name,
            phone: response.data.phone,
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
      // Update email if changed
      if (user && data.email !== user.email) {
        const userResponse = await apiClient.updateCurrentUser(data.email)
        if (userResponse.error) {
          toast.error(userResponse.error)
          setIsSubmittingProfile(false)
          return
        }
      }

      // Update employer profile
      const profileResponse = await apiClient.updateEmployerProfile({
        first_name: data.first_name,
        last_name: data.last_name,
        phone: data.phone,
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
                  {...profileForm.register("email")}
                  className="bg-card"
                />
                {profileForm.formState.errors.email && (
                  <p className="text-sm text-destructive">
                    {profileForm.formState.errors.email.message}
                  </p>
                )}
              </div>

              {/* Phone */}
              <div className="space-y-2">
                <Label htmlFor="phone">Phone Number</Label>
                <Input
                  id="phone"
                  type="tel"
                  {...profileForm.register("phone")}
                  className="bg-card"
                />
                {profileForm.formState.errors.phone && (
                  <p className="text-sm text-destructive">
                    {profileForm.formState.errors.phone.message}
                  </p>
                )}
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
