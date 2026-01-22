"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useAuth } from "@/contexts/auth-context";
import { MessageSquare, ArrowLeft, Eye, EyeOff, Loader2 } from "lucide-react";

export default function LoginPage() {
  const [showPassword, setShowPassword] = useState(false);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const { login, logout } = useAuth();
  const router = useRouter();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setIsSubmitting(true);

    const result = await login(email, password);

    if (result.success) {
      const { role } = result;

      if (!role) {
        await logout();
        setError("Login succeeded, but your role could not be determined.");
        router.replace("/login");
        setIsSubmitting(false);
        return;
      }

      if (role === "worker") {
        router.push("/dashboard/worker");
      } else if (role === "employer") {
        router.push("/dashboard/employer");
      } else if (role === "admin") {
        router.push("/dashboard/admin");
      } else {
        await logout();
        setError("Unsupported account role. Please contact support.");
        router.replace("/login");
        setIsSubmitting(false);
        return;
      }
    } else {
      setError(result.error || "Login failed. Please check your credentials.");
    }

    setIsSubmitting(false);
  };

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
            Welcome back
          </h1>
          <p className="mt-2 text-muted-foreground">
            Sign in to your account to continue
          </p>
        </div>

        <div className="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
          {error && (
            <div className="mb-6 p-3 rounded-lg bg-destructive/10 border border-destructive/20 text-destructive text-sm">
              {error}
            </div>
          )}

          <form className="space-y-6" onSubmit={handleSubmit}>
            <div>
              <Label htmlFor="email">Email</Label>
              <Input
                id="email"
                type="email"
                placeholder="you@example.com"
                className="mt-2 bg-card"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
              />
            </div>

            <div>
              <div className="flex items-center justify-between">
                <Label htmlFor="password">Password</Label>
                <Link
                  href="/forgot-password"
                  className="text-sm text-accent hover:underline"
                >
                  Forgot password?
                </Link>
              </div>
              <div className="relative mt-2">
                <Input
                  id="password"
                  type={showPassword ? "text" : "password"}
                  placeholder="Enter your password"
                  className="bg-card pr-10"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
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

            <Button type="submit" className="w-full" size="lg" disabled={isSubmitting}>
              {isSubmitting ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Signing in...
                </>
              ) : (
                "Sign in"
              )}
            </Button>
          </form>

          <p className="mt-8 text-center text-sm text-muted-foreground">
            Don&apos;t have an account?{" "}
            <Link href="/signup/worker" className="text-accent font-medium hover:underline">
              Sign up as a worker
            </Link>{" "}
            or{" "}
            <Link href="/signup/employer" className="text-accent font-medium hover:underline">
              sign up as an employer
            </Link>
            .
          </p>
        </div>
      </div>

      {/* Right side - Visual */}
      <div className="hidden lg:flex lg:flex-1 bg-foreground text-primary-foreground p-12 flex-col justify-between">
        <div />
        <div>
          <blockquote className="text-2xl font-medium leading-relaxed text-balance">
            &ldquo;ShiftReady changed how I make extra money. I just reply YES to a
            text, show up, and get paid the same day. It&apos;s that simple.&rdquo;
          </blockquote>
          <div className="mt-8">
            <p className="font-semibold">Marcus J.</p>
            <p className="text-primary-foreground/70">
              ShiftReady Worker, San Antonio
            </p>
          </div>
        </div>
        <div className="flex items-center gap-8 text-sm text-primary-foreground/60">
          <div>
            <p className="text-3xl font-bold text-primary-foreground">500+</p>
            <p>Active Workers</p>
          </div>
          <div className="h-12 w-px bg-primary-foreground/20" />
          <div>
            <p className="text-3xl font-bold text-primary-foreground">50+</p>
            <p>Partner Employers</p>
          </div>
          <div className="h-12 w-px bg-primary-foreground/20" />
          <div>
            <p className="text-3xl font-bold text-primary-foreground">$2M+</p>
            <p>Paid to Workers</p>
          </div>
        </div>
      </div>
    </div>
  );
}
