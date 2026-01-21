"use client";

import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Menu, X } from "lucide-react";
import { useState } from "react";

export function Header() {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  return (
    <header className="fixed top-0 left-0 right-0 z-50 bg-background/80 backdrop-blur-md border-b border-border">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          <Link href="/" className="flex items-center gap-2">
            <div className="w-8 h-8 bg-primary rounded-lg flex items-center justify-center">
              <span className="text-primary-foreground font-bold text-sm">SR</span>
            </div>
            <span className="font-semibold text-lg text-foreground">ShiftReady</span>
          </Link>

          <nav className="hidden md:flex items-center gap-8">
            <Link href="#employers" className="text-muted-foreground hover:text-foreground transition-colors text-sm">
              For Employers
            </Link>
            <Link href="#workers" className="text-muted-foreground hover:text-foreground transition-colors text-sm">
              For Workers
            </Link>
            <Link href="#how-it-works" className="text-muted-foreground hover:text-foreground transition-colors text-sm">
              How It Works
            </Link>
          </nav>

          <div className="hidden md:flex items-center gap-3">
            <Button variant="ghost" size="sm" asChild>
              <Link href="/login">Log in</Link>
            </Button>
            <Button size="sm" asChild>
              <Link href="/signup/worker">Get Started</Link>
            </Button>
          </div>

          <button
            type="button"
            className="md:hidden p-2"
            onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
            aria-label="Toggle menu"
          >
            {mobileMenuOpen ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
          </button>
        </div>

        {mobileMenuOpen && (
          <div className="md:hidden py-4 border-t border-border">
            <nav className="flex flex-col gap-4">
              <Link href="#employers" className="text-muted-foreground hover:text-foreground transition-colors text-sm">
                For Employers
              </Link>
              <Link href="#workers" className="text-muted-foreground hover:text-foreground transition-colors text-sm">
                For Workers
              </Link>
              <Link href="#how-it-works" className="text-muted-foreground hover:text-foreground transition-colors text-sm">
                How It Works
              </Link>
              <div className="flex flex-col gap-2 pt-4">
                <Button variant="ghost" size="sm" asChild>
                  <Link href="/login">Log in</Link>
                </Button>
                <Button size="sm" asChild>
                  <Link href="/signup/worker">Get Started</Link>
                </Button>
              </div>
            </nav>
          </div>
        )}
      </div>
    </header>
  );
}
