"use client";

import { useState, type FormEvent } from "react";
import { Button } from "@/components/ui/button";
import { MapPin } from "lucide-react";

type RegionSectionProps = {
  onNotify?: (email: string) => Promise<void> | void;
};

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function RegionSection({ onNotify }: RegionSectionProps) {
  const comingSoon = ["Austin", "Houston", "Dallas", "Fort Worth"];
  const [email, setEmail] = useState("");
  const [errorMessage, setErrorMessage] = useState("");
  const [successMessage, setSuccessMessage] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleNotify = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setErrorMessage("");
    setSuccessMessage("");

    const trimmedEmail = email.trim();
    if (!trimmedEmail) {
      setErrorMessage("Please enter your email address.");
      return;
    }

    if (!emailPattern.test(trimmedEmail)) {
      setErrorMessage("Please enter a valid email address.");
      return;
    }

    setIsSubmitting(true);
    try {
      if (!onNotify) {
        throw new Error("Notification handler not configured");
      }
      await onNotify?.(trimmedEmail);
      setSuccessMessage("Thanks! We'll notify you when we launch in your city.");
      setEmail("");
    } catch (error) {
      console.error("Notify request failed", error);
      setErrorMessage("Something went wrong. Please try again.");
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <section className="py-20 px-4 sm:px-6 lg:px-8 bg-card">
      <div className="max-w-7xl mx-auto text-center">
        <div className="inline-flex items-center gap-2 px-4 py-2 bg-accent/10 rounded-full mb-6">
          <MapPin className="w-4 h-4 text-accent" />
          <span className="text-sm font-medium text-accent">Service Area</span>
        </div>
        
        <h2 className="text-3xl sm:text-4xl font-bold text-foreground mb-4">
          Currently serving San Antonio
        </h2>
        <p className="text-lg text-muted-foreground max-w-2xl mx-auto mb-8">
          We{"'"}re starting local and growing fast. San Antonio is our home base, with expansion across Texas coming soon.
        </p>

        <div className="flex flex-wrap justify-center gap-3 mb-10">
          <div className="px-4 py-2 bg-foreground text-primary-foreground rounded-full font-medium text-sm">
            San Antonio — Live Now
          </div>
          {comingSoon.map((city) => (
            <div key={city} className="px-4 py-2 bg-secondary text-muted-foreground rounded-full text-sm">
              {city} — Coming Soon
            </div>
          ))}
        </div>

        <div className="bg-secondary rounded-2xl p-8 max-w-xl mx-auto">
          <h3 className="font-semibold text-foreground mb-2">Not in our area yet?</h3>
          <p className="text-sm text-muted-foreground mb-4">
            Join our waitlist and be the first to know when we launch in your city.
          </p>
          <form className="flex flex-col sm:flex-row gap-3" onSubmit={handleNotify}>
            <label htmlFor="region-email" className="sr-only">
              Email address
            </label>
            <input
              id="region-email"
              type="email"
              placeholder="Enter your email"
              value={email}
              onChange={(event) => {
                setEmail(event.target.value);
                if (errorMessage) {
                  setErrorMessage("");
                }
              }}
              aria-invalid={Boolean(errorMessage)}
              aria-describedby="region-email-feedback"
              className="flex-1 px-4 py-2 bg-card border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-accent"
            />
            <Button type="submit" disabled={isSubmitting}>
              {isSubmitting ? "Sending..." : "Notify Me"}
            </Button>
          </form>
          <div
            id="region-email-feedback"
            className="mt-3 text-sm"
            role="status"
            aria-live="polite"
          >
            {errorMessage ? (
              <span className="text-destructive">{errorMessage}</span>
            ) : successMessage ? (
              <span className="text-accent">{successMessage}</span>
            ) : null}
          </div>
        </div>
      </div>
    </section>
  );
}
