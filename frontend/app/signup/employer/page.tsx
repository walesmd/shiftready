"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Checkbox } from "@/components/ui/checkbox";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { useAuth } from "@/contexts/auth-context";
import {
  MessageSquare,
  ArrowLeft,
  Eye,
  EyeOff,
  Check,
  FileText,
  Users,
  Clock,
  Shield,
  Loader2,
} from "lucide-react";

export default function EmployerSignupPage() {
  const [showPassword, setShowPassword] = useState(false);
  const [step, setStep] = useState(1);
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Form data
  const [formData, setFormData] = useState({
    companyName: "",
    firstName: "",
    lastName: "",
    title: "",
    email: "",
    phone: "",
    password: "",
    industry: "",
    address: "",
    city: "",
    zip: "",
    workersNeeded: "",
    roles: "",
    termsAccepted: false,
    authorized: false,
  });

  const { register } = useAuth();
  const router = useRouter();

  const updateFormData = (field: string, value: string | boolean) => {
    setFormData((prev) => ({ ...prev, [field]: value }));
    if (field === "industry" && value) {
      setError(null);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setIsSubmitting(true);

    // Prepare registration data with all form fields
    const registrationData = {
      email: formData.email,
      password: formData.password,
      password_confirmation: formData.password,
      role: "employer" as const,
      company_attributes: {
        name: formData.companyName,
        industry: formData.industry,
        billing_address_line_1: formData.address,
        billing_city: formData.city,
        billing_state: "TX",
        billing_zip_code: formData.zip,
        workers_needed_per_week: formData.workersNeeded,
        typical_roles: formData.roles,
      },
      employer_profile_attributes: {
        first_name: formData.firstName,
        last_name: formData.lastName,
        title: formData.title,
        phone: formData.phone,
        terms_accepted_at: formData.termsAccepted ? new Date().toISOString() : null,
        msa_accepted_at: formData.termsAccepted ? new Date().toISOString() : null,
      },
    };

    try {
      const result = await register(
        registrationData.email,
        registrationData.password,
        registrationData.password_confirmation,
        registrationData.role,
        registrationData.company_attributes,
        registrationData.employer_profile_attributes
      );

      if (result.success) {
        router.push("/dashboard/employer");
      } else {
        setError(result.error || "Registration failed. Please try again.");
      }
    } catch (error) {
      const message =
        error instanceof Error
          ? error.message
          : "Registration failed due to an unexpected error. Please try again.";
      setError(message);
    } finally {
      setIsSubmitting(false);
    }
  };

  const benefits = [
    {
      icon: FileText,
      title: "Zero payroll headaches",
      description: "We handle all W-2s, taxes, and compliance.",
    },
    {
      icon: Users,
      title: "Pre-vetted workers",
      description: "Background-checked and ready to work.",
    },
    {
      icon: Clock,
      title: "Fill shifts fast",
      description: "Most shifts filled within 2 hours.",
    },
    {
      icon: Shield,
      title: "Fully insured",
      description: "Workers comp and liability covered.",
    },
  ];

  return (
    <div className="min-h-screen bg-background flex">
      {/* Left side - Form */}
      <div className="flex-1 flex flex-col justify-center px-6 py-12 lg:px-8 overflow-y-auto">
        <div className="sm:mx-auto sm:w-full sm:max-w-lg">
          <Link
            href="/"
            className="inline-flex items-center gap-2 text-muted-foreground hover:text-foreground transition-colors mb-8"
          >
            <ArrowLeft className="h-4 w-4" />
            Back to home
          </Link>

          <div className="flex items-center gap-2 mb-2">
            <div className="h-9 w-9 rounded-lg bg-foreground flex items-center justify-center">
              <MessageSquare className="h-5 w-5 text-primary-foreground" />
            </div>
            <span className="text-xl font-semibold tracking-tight">
              ShiftReady
            </span>
          </div>

          <h1 className="mt-8 text-3xl font-bold tracking-tight text-foreground">
            Get started for your business
          </h1>
          <p className="mt-2 text-muted-foreground">
            Create your employer account to start filling shifts
          </p>

          {/* Progress indicator */}
          <div className="flex items-center gap-2 mt-6">
            <div
              className={`h-1.5 flex-1 rounded-full ${step >= 1 ? "bg-accent" : "bg-muted"}`}
            />
            <div
              className={`h-1.5 flex-1 rounded-full ${step >= 2 ? "bg-accent" : "bg-muted"}`}
            />
            <div
              className={`h-1.5 flex-1 rounded-full ${step >= 3 ? "bg-accent" : "bg-muted"}`}
            />
          </div>
          <p className="text-sm text-muted-foreground mt-2">Step {step} of 3</p>
        </div>

        <div className="mt-8 sm:mx-auto sm:w-full sm:max-w-lg">
          {error && (
            <div className="mb-6 p-3 rounded-lg bg-destructive/10 border border-destructive/20 text-destructive text-sm">
              {error}
            </div>
          )}

          {step === 1 && (
            <form
              className="space-y-5"
              onSubmit={(e) => {
                e.preventDefault();
                setStep(2);
              }}
            >
              <div>
                <Label htmlFor="companyName">Company name</Label>
                <Input
                  id="companyName"
                  placeholder="Acme Moving Co."
                  className="mt-2 bg-card"
                  value={formData.companyName}
                  onChange={(e) => updateFormData("companyName", e.target.value)}
                  required
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <Label htmlFor="firstName">Your first name</Label>
                  <Input
                    id="firstName"
                    placeholder="Jane"
                    className="mt-2 bg-card"
                    value={formData.firstName}
                    onChange={(e) => updateFormData("firstName", e.target.value)}
                    required
                  />
                </div>
                <div>
                  <Label htmlFor="lastName">Your last name</Label>
                  <Input
                    id="lastName"
                    placeholder="Smith"
                    className="mt-2 bg-card"
                    value={formData.lastName}
                    onChange={(e) => updateFormData("lastName", e.target.value)}
                    required
                  />
                </div>
              </div>

              <div>
                <Label htmlFor="title">Your title</Label>
                <Input
                  id="title"
                  placeholder="Operations Manager"
                  className="mt-2 bg-card"
                  value={formData.title}
                  onChange={(e) => updateFormData("title", e.target.value)}
                  required
                />
              </div>

              <div>
                <Label htmlFor="email">Work email</Label>
                <Input
                  id="email"
                  type="email"
                  placeholder="jane@acmemoving.com"
                  className="mt-2 bg-card"
                  value={formData.email}
                  onChange={(e) => updateFormData("email", e.target.value)}
                  required
                />
              </div>

              <div>
                <Label htmlFor="phone">Phone number</Label>
                <Input
                  id="phone"
                  type="tel"
                  placeholder="(210) 555-0123"
                  className="mt-2 bg-card"
                  value={formData.phone}
                  onChange={(e) => updateFormData("phone", e.target.value)}
                  required
                />
              </div>

              <div>
                <Label htmlFor="password">Password</Label>
                <div className="relative mt-2">
                  <Input
                    id="password"
                    type={showPassword ? "text" : "password"}
                    placeholder="Create a password"
                    className="bg-card pr-10"
                    value={formData.password}
                    onChange={(e) => updateFormData("password", e.target.value)}
                    required
                    minLength={6}
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
                  >
                    {showPassword ? (
                      <EyeOff className="h-4 w-4" />
                    ) : (
                      <Eye className="h-4 w-4" />
                    )}
                  </button>
                </div>
              </div>

              <Button type="submit" className="w-full" size="lg">
                Continue
              </Button>
            </form>
          )}

          {step === 2 && (
            <form
              className="space-y-5"
              onSubmit={(e) => {
                e.preventDefault();
                if (!formData.industry) {
                  setError("Please select your industry.");
                  return;
                }
                if (!formData.workersNeeded) {
                  setError(
                    "Please select how many workers you typically need per week."
                  );
                  return;
                }
                setError(null);
                setStep(3);
              }}
            >
              <div>
                <Label htmlFor="industry">
                  Industry <span className="text-destructive">*</span>
                </Label>
                <Select
                  value={formData.industry}
                  onValueChange={(value) => updateFormData("industry", value)}
                >
                  <SelectTrigger className="mt-2 bg-card">
                    <SelectValue placeholder="Select your industry" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="moving">Moving & Logistics</SelectItem>
                    <SelectItem value="warehouse">
                      Warehouse & Distribution
                    </SelectItem>
                    <SelectItem value="automotive">Automotive</SelectItem>
                    <SelectItem value="events">Events & Hospitality</SelectItem>
                    <SelectItem value="retail">Retail</SelectItem>
                    <SelectItem value="manufacturing">Manufacturing</SelectItem>
                    <SelectItem value="other">Other</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div>
                <Label htmlFor="address">Business address</Label>
                <Input
                  id="address"
                  placeholder="123 Main Street"
                  className="mt-2 bg-card"
                  value={formData.address}
                  onChange={(e) => updateFormData("address", e.target.value)}
                  required
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <Label htmlFor="city">City</Label>
                  <Input
                    id="city"
                    placeholder="San Antonio"
                    className="mt-2 bg-card"
                    value={formData.city}
                    onChange={(e) => updateFormData("city", e.target.value)}
                    required
                  />
                </div>
                <div>
                  <Label htmlFor="zip">ZIP code</Label>
                  <Input
                    id="zip"
                    placeholder="78201"
                    className="mt-2 bg-card"
                    value={formData.zip}
                    onChange={(e) => updateFormData("zip", e.target.value)}
                    required
                  />
                </div>
              </div>

              <div>
                <Label htmlFor="workers">
                  How many workers do you typically need per week?{" "}
                  <span className="text-destructive">*</span>
                </Label>
                <Select
                  value={formData.workersNeeded}
                  onValueChange={(value) => {
                    updateFormData("workersNeeded", value);
                    if (value) {
                      setError(null);
                    }
                  }}
                >
                  <SelectTrigger className="mt-2 bg-card">
                    <SelectValue placeholder="Select range" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="1-5">1-5 workers</SelectItem>
                    <SelectItem value="6-15">6-15 workers</SelectItem>
                    <SelectItem value="16-30">16-30 workers</SelectItem>
                    <SelectItem value="31-50">31-50 workers</SelectItem>
                    <SelectItem value="50+">50+ workers</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div>
                <Label htmlFor="roles">
                  What types of roles do you need filled?
                </Label>
                <Textarea
                  id="roles"
                  placeholder="e.g., Moving helpers, car drivers, box packers..."
                  className="mt-2 bg-card min-h-[100px]"
                  value={formData.roles}
                  onChange={(e) => updateFormData("roles", e.target.value)}
                />
              </div>

              <div className="flex gap-3">
                <Button
                  type="button"
                  variant="outline"
                  className="flex-1 bg-transparent"
                  size="lg"
                  onClick={() => setStep(1)}
                >
                  Back
                </Button>
                <Button type="submit" className="flex-1" size="lg">
                  Continue
                </Button>
              </div>
            </form>
          )}

          {step === 3 && (
            <form className="space-y-5" onSubmit={handleSubmit}>
              <div className="p-4 rounded-lg bg-accent/10 border border-accent/20">
                <h3 className="font-medium text-foreground mb-2">
                  You&apos;re almost ready!
                </h3>
                <p className="text-sm text-muted-foreground">
                  After creating your account, a member of our team will reach
                  out within 24 hours to complete your onboarding.
                </p>
              </div>

              <div className="p-4 rounded-lg bg-card border border-border">
                <h4 className="font-medium mb-3">What&apos;s included:</h4>
                <ul className="space-y-2">
                  {[
                    "Dedicated account manager",
                    "Custom shift scheduling dashboard",
                    "Real-time worker tracking",
                    "Consolidated weekly invoicing",
                    "24/7 support hotline",
                  ].map((item) => (
                    <li
                      key={item}
                      className="flex items-center gap-2 text-sm text-muted-foreground"
                    >
                      <Check className="h-4 w-4 text-accent" />
                      {item}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="space-y-4">
                <label className="flex items-start gap-3 cursor-pointer">
                  <Checkbox
                    id="terms"
                    className="mt-0.5"
                    checked={formData.termsAccepted}
                    onCheckedChange={(checked) =>
                      updateFormData("termsAccepted", checked === true)
                    }
                    required
                  />
                  <span className="text-sm text-muted-foreground">
                    I agree to the{" "}
                    <Link href="/terms" className="text-accent hover:underline">
                      Terms of Service
                    </Link>
                    ,{" "}
                    <Link
                      href="/privacy"
                      className="text-accent hover:underline"
                    >
                      Privacy Policy
                    </Link>
                    , and{" "}
                    <Link href="/msa" className="text-accent hover:underline">
                      Master Service Agreement
                    </Link>
                  </span>
                </label>

                <label className="flex items-start gap-3 cursor-pointer">
                  <Checkbox
                    id="authorized"
                    className="mt-0.5"
                    checked={formData.authorized}
                    onCheckedChange={(checked) =>
                      updateFormData("authorized", checked === true)
                    }
                    required
                  />
                  <span className="text-sm text-muted-foreground">
                    I confirm I am authorized to enter into agreements on behalf
                    of my company.
                  </span>
                </label>
              </div>

              <div className="flex gap-3">
                <Button
                  type="button"
                  variant="outline"
                  className="flex-1 bg-transparent"
                  size="lg"
                  onClick={() => setStep(2)}
                  disabled={isSubmitting}
                >
                  Back
                </Button>
                <Button
                  type="submit"
                  className="flex-1"
                  size="lg"
                  disabled={
                    isSubmitting || !formData.termsAccepted || !formData.authorized
                  }
                >
                  {isSubmitting ? (
                    <>
                      <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                      Creating account...
                    </>
                  ) : (
                    "Create account"
                  )}
                </Button>
              </div>
            </form>
          )}

          <p className="mt-8 text-center text-sm text-muted-foreground">
            Already have an account?{" "}
            <Link
              href="/login"
              className="text-accent font-medium hover:underline"
            >
              Sign in
            </Link>
          </p>
        </div>
      </div>

      {/* Right side - Benefits */}
      <div className="hidden lg:flex lg:flex-1 bg-foreground text-primary-foreground p-12 flex-col justify-center">
        <div className="max-w-md">
          <h2 className="text-2xl font-bold mb-2">Why businesses choose us</h2>
          <p className="text-primary-foreground/70 mb-10">
            Join 50+ San Antonio businesses who simplified their staffing
          </p>

          <div className="space-y-6">
            {benefits.map((benefit) => (
              <div key={benefit.title} className="flex items-start gap-4">
                <div className="h-10 w-10 rounded-lg bg-accent/20 flex items-center justify-center shrink-0">
                  <benefit.icon className="h-5 w-5 text-accent" />
                </div>
                <div>
                  <h3 className="font-semibold">{benefit.title}</h3>
                  <p className="text-sm text-primary-foreground/70">
                    {benefit.description}
                  </p>
                </div>
              </div>
            ))}
          </div>

          <div className="mt-12 p-6 rounded-xl bg-primary-foreground/5 border border-primary-foreground/10">
            <div className="flex items-center gap-4 mb-4">
              <div className="h-12 w-12 rounded-full bg-primary-foreground/20 flex items-center justify-center text-sm font-medium">
                RM
              </div>
              <div>
                <p className="font-semibold">Robert Martinez</p>
                <p className="text-sm text-primary-foreground/70">
                  Operations Director, SA Airport Parking
                </p>
              </div>
            </div>
            <p className="text-sm text-primary-foreground/70">
              &ldquo;We went from spending 15 hours a week on staffing to zero.
              ShiftReady handles everything. We just tell them how many drivers
              we need and they show up ready to work.&rdquo;
            </p>
            <div className="flex items-center gap-4 mt-4 pt-4 border-t border-primary-foreground/10">
              <div>
                <p className="text-2xl font-bold">60%</p>
                <p className="text-xs text-primary-foreground/60">
                  Time saved on staffing
                </p>
              </div>
              <div className="h-8 w-px bg-primary-foreground/20" />
              <div>
                <p className="text-2xl font-bold">98%</p>
                <p className="text-xs text-primary-foreground/60">
                  Shift fill rate
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
