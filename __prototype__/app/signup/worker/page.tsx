"use client";

import { useState } from "react";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Checkbox } from "@/components/ui/checkbox";
import {
  MessageSquare,
  ArrowLeft,
  Eye,
  EyeOff,
  Check,
  Smartphone,
  DollarSign,
  Clock,
  MapPin,
} from "lucide-react";

export default function WorkerSignupPage() {
  const [showPassword, setShowPassword] = useState(false);
  const [step, setStep] = useState(1);

  const benefits = [
    {
      icon: Smartphone,
      title: "Text-based jobs",
      description: "Get job offers via text. Reply YES or NO.",
    },
    {
      icon: DollarSign,
      title: "Same-day pay",
      description: "Get paid immediately after completing a shift.",
    },
    {
      icon: Clock,
      title: "Your schedule",
      description: "Only work when it fits your life.",
    },
    {
      icon: MapPin,
      title: "Local jobs",
      description: "Find work close to where you are.",
    },
  ];

  return (
    <div className="min-h-screen bg-background flex">
      {/* Left side - Form */}
      <div className="flex-1 flex flex-col justify-center px-6 py-12 lg:px-8">
        <div className="sm:mx-auto sm:w-full sm:max-w-md">
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
            Start earning today
          </h1>
          <p className="mt-2 text-muted-foreground">
            Create your worker account in just a few steps
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

        <div className="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
          {step === 1 && (
            <form
              className="space-y-5"
              onSubmit={(e) => {
                e.preventDefault();
                setStep(2);
              }}
            >
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <Label htmlFor="firstName">First name</Label>
                  <Input
                    id="firstName"
                    placeholder="John"
                    className="mt-2 bg-card"
                    required
                  />
                </div>
                <div>
                  <Label htmlFor="lastName">Last name</Label>
                  <Input
                    id="lastName"
                    placeholder="Doe"
                    className="mt-2 bg-card"
                    required
                  />
                </div>
              </div>

              <div>
                <Label htmlFor="phone">Phone number</Label>
                <Input
                  id="phone"
                  type="tel"
                  placeholder="(210) 555-0123"
                  className="mt-2 bg-card"
                  required
                />
                <p className="text-xs text-muted-foreground mt-1.5">
                  We'll send job offers to this number via text
                </p>
              </div>

              <div>
                <Label htmlFor="email">Email</Label>
                <Input
                  id="email"
                  type="email"
                  placeholder="john@example.com"
                  className="mt-2 bg-card"
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
                    required
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
                setStep(3);
              }}
            >
              <div>
                <Label htmlFor="zip">ZIP code</Label>
                <Input
                  id="zip"
                  placeholder="78201"
                  className="mt-2 bg-card"
                  required
                />
                <p className="text-xs text-muted-foreground mt-1.5">
                  We'll match you with jobs near you
                </p>
              </div>

              <div>
                <Label>What type of work interests you?</Label>
                <div className="grid grid-cols-2 gap-3 mt-3">
                  {[
                    "Moving & lifting",
                    "Warehouse work",
                    "Driving",
                    "Event staffing",
                    "Cleaning",
                    "General labor",
                  ].map((type) => (
                    <label
                      key={type}
                      className="flex items-center gap-3 p-3 rounded-lg border border-border bg-card hover:border-accent/50 cursor-pointer transition-colors"
                    >
                      <Checkbox id={type} />
                      <span className="text-sm">{type}</span>
                    </label>
                  ))}
                </div>
              </div>

              <div>
                <Label>When are you typically available?</Label>
                <div className="grid grid-cols-2 gap-3 mt-3">
                  {[
                    "Weekday mornings",
                    "Weekday afternoons",
                    "Weekday evenings",
                    "Weekends anytime",
                  ].map((time) => (
                    <label
                      key={time}
                      className="flex items-center gap-3 p-3 rounded-lg border border-border bg-card hover:border-accent/50 cursor-pointer transition-colors"
                    >
                      <Checkbox id={time} />
                      <span className="text-sm">{time}</span>
                    </label>
                  ))}
                </div>
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
            <form
              className="space-y-5"
              onSubmit={(e) => {
                e.preventDefault();
              }}
            >
              <div className="p-4 rounded-lg bg-accent/10 border border-accent/20">
                <h3 className="font-medium text-foreground mb-2">
                  Almost there!
                </h3>
                <p className="text-sm text-muted-foreground">
                  Review and agree to our terms to start receiving job offers.
                </p>
              </div>

              <div className="space-y-4">
                <label className="flex items-start gap-3 cursor-pointer">
                  <Checkbox id="terms" className="mt-0.5" required />
                  <span className="text-sm text-muted-foreground">
                    I agree to the{" "}
                    <Link href="/terms" className="text-accent hover:underline">
                      Terms of Service
                    </Link>{" "}
                    and{" "}
                    <Link
                      href="/privacy"
                      className="text-accent hover:underline"
                    >
                      Privacy Policy
                    </Link>
                  </span>
                </label>

                <label className="flex items-start gap-3 cursor-pointer">
                  <Checkbox id="sms" className="mt-0.5" required />
                  <span className="text-sm text-muted-foreground">
                    I consent to receive job offers and updates via SMS. Message
                    & data rates may apply. Reply STOP to opt out anytime.
                  </span>
                </label>

                <label className="flex items-start gap-3 cursor-pointer">
                  <Checkbox id="age" className="mt-0.5" required />
                  <span className="text-sm text-muted-foreground">
                    I confirm I am at least 18 years old and legally authorized
                    to work in the United States.
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
                >
                  Back
                </Button>
                <Button type="submit" className="flex-1" size="lg">
                  Create account
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
          <h2 className="text-2xl font-bold mb-2">Why workers love us</h2>
          <p className="text-primary-foreground/70 mb-10">
            Join hundreds of workers in San Antonio already earning with
            ShiftReady
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
            <div className="flex items-center gap-3 mb-3">
              <div className="flex -space-x-2">
                {[1, 2, 3].map((i) => (
                  <div
                    key={i}
                    className="h-8 w-8 rounded-full bg-primary-foreground/20 border-2 border-foreground flex items-center justify-center text-xs font-medium"
                  >
                    {["MJ", "KR", "TS"][i - 1]}
                  </div>
                ))}
              </div>
              <div className="flex items-center gap-1">
                {[1, 2, 3, 4, 5].map((i) => (
                  <Check
                    key={i}
                    className="h-4 w-4 text-accent fill-accent stroke-foreground"
                  />
                ))}
              </div>
            </div>
            <p className="text-sm text-primary-foreground/70">
              "I made $400 last week just picking up shifts when my kids were at
              school. The flexibility is unmatched."
            </p>
            <p className="text-sm font-medium mt-2">
              Sarah T. - San Antonio Worker
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
