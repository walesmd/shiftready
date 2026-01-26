"use client";

import React from "react"

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useAuth } from "@/contexts/auth-context";
import { ProtectedRoute } from "@/components/protected-route";
import { OnboardingProvider } from "@/contexts/onboarding-context";
import { OnboardingCard } from "@/components/employer-dashboard/onboarding-card";
import {
  Calendar,
  LayoutDashboard,
  Clock,
  Users,
  Settings,
  LogOut,
  Bell,
  ChevronDown,
  Menu,
  X,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { useState } from "react";

const navigation = [
  { name: "Overview", href: "/dashboard/employer", icon: LayoutDashboard },
  { name: "Shifts", href: "/dashboard/employer/shifts", icon: Calendar },
  { name: "Timesheet", href: "/dashboard/employer/timesheet", icon: Clock },
  { name: "Workers", href: "/dashboard/employer/workers", icon: Users },
  { name: "Settings", href: "/dashboard/employer/settings", icon: Settings },
];

export default function EmployerDashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const pathname = usePathname();
  const router = useRouter();
  const { user, logout } = useAuth();
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  const handleLogout = async () => {
    await logout();
    router.push("/login");
  };

  return (
    <ProtectedRoute allowedRoles={["employer"]}>
      <OnboardingProvider userRole="employer">
      <div className="min-h-screen bg-background">
      {/* Top Header */}
      <header className="sticky top-0 z-50 bg-card border-b border-border">
        <div className="flex items-center justify-between px-4 lg:px-6 h-16">
          <div className="flex items-center gap-4">
            <Button
              variant="ghost"
              size="icon"
              className="lg:hidden"
              onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
            >
              {mobileMenuOpen ? (
                <X className="h-5 w-5" />
              ) : (
                <Menu className="h-5 w-5" />
              )}
            </Button>
            <Link href="/dashboard/employer" className="flex items-center gap-2">
              <div className="w-8 h-8 bg-foreground rounded-lg flex items-center justify-center">
                <span className="text-background font-bold text-sm">SR</span>
              </div>
              <span className="font-semibold text-foreground hidden sm:block">
                ShiftReady
              </span>
            </Link>
          </div>

          <div className="flex items-center gap-3">
            <Button variant="ghost" size="icon" className="relative">
              <Bell className="h-5 w-5" />
              <span className="absolute top-1 right-1 w-2 h-2 bg-accent rounded-full" />
            </Button>

            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button variant="ghost" className="flex items-center gap-2">
                  <div className="w-8 h-8 bg-muted rounded-full flex items-center justify-center">
                    <span className="text-sm font-medium">
                      {user?.email?.substring(0, 2).toUpperCase() || "EM"}
                    </span>
                  </div>
                  <div className="hidden sm:block text-left">
                    <p className="text-sm font-medium">{user?.email || "Employer"}</p>
                    <p className="text-xs text-muted-foreground capitalize">{user?.role}</p>
                  </div>
                  <ChevronDown className="h-4 w-4 text-muted-foreground" />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end" className="w-56">
                <DropdownMenuItem asChild>
                  <Link href="/dashboard/employer/settings">
                    <Settings className="mr-2 h-4 w-4" />
                    Account Settings
                  </Link>
                </DropdownMenuItem>
                <DropdownMenuSeparator />
                <DropdownMenuItem
                  className="text-destructive"
                  onClick={handleLogout}
                >
                  <LogOut className="mr-2 h-4 w-4" />
                  Sign out
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        </div>
      </header>

      <div className="flex">
        {/* Sidebar - Desktop */}
        <aside className="hidden lg:flex lg:flex-col lg:w-64 lg:border-r lg:border-border lg:bg-card lg:min-h-[calc(100vh-4rem)]">
          <nav className="flex-1 p-4 space-y-1">
            {navigation.map((item) => {
              const isActive =
                pathname === item.href ||
                (item.href !== "/dashboard/employer" &&
                  pathname.startsWith(item.href));
              return (
                <Link
                  key={item.name}
                  href={item.href}
                  className={`flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors ${
                    isActive
                      ? "bg-foreground text-background"
                      : "text-muted-foreground hover:bg-muted hover:text-foreground"
                  }`}
                >
                  <item.icon className="h-5 w-5" />
                  {item.name}
                </Link>
              );
            })}
          </nav>

          <div className="p-4 border-t border-border">
            <div className="bg-muted rounded-lg p-4">
              <p className="text-sm font-medium text-foreground">
                Need more workers?
              </p>
              <p className="text-xs text-muted-foreground mt-1">
                Post a new shift and we will find workers for you.
              </p>
              <Button size="sm" className="w-full mt-3" asChild>
                <Link href="/dashboard/employer/shifts">Post a Shift</Link>
              </Button>
            </div>
          </div>
        </aside>

        {/* Mobile Menu */}
        {mobileMenuOpen && (
          <div className="fixed inset-0 z-40 lg:hidden">
            <div
              className="fixed inset-0 bg-foreground/20 backdrop-blur-sm"
              onClick={() => setMobileMenuOpen(false)}
            />
            <aside className="fixed inset-y-0 left-0 w-64 bg-card border-r border-border pt-16">
              <nav className="p-4 space-y-1">
                {navigation.map((item) => {
                  const isActive =
                    pathname === item.href ||
                    (item.href !== "/dashboard/employer" &&
                      pathname.startsWith(item.href));
                  return (
                    <Link
                      key={item.name}
                      href={item.href}
                      onClick={() => setMobileMenuOpen(false)}
                      className={`flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors ${
                        isActive
                          ? "bg-foreground text-background"
                          : "text-muted-foreground hover:bg-muted hover:text-foreground"
                      }`}
                    >
                      <item.icon className="h-5 w-5" />
                      {item.name}
                    </Link>
                  );
                })}
              </nav>
            </aside>
          </div>
        )}

        {/* Main Content */}
        <main className="flex-1 min-h-[calc(100vh-4rem)]">
          <div className="px-4 lg:px-8 pt-6">
            <OnboardingCard />
          </div>
          {children}
        </main>
      </div>
    </div>
      </OnboardingProvider>
    </ProtectedRoute>
  );
}
