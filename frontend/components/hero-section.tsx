import Link from "next/link";
import { Button } from "@/components/ui/button";
import { ArrowRight, MessageSquare } from "lucide-react";

export function HeroSection() {
  return (
    <section className="pt-32 pb-20 px-4 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto">
        <div className="flex flex-col lg:flex-row items-center gap-12 lg:gap-16">
          <div className="flex-1 text-center lg:text-left">
            <div className="inline-flex items-center gap-2 px-3 py-1.5 bg-accent/10 text-accent rounded-full text-sm mb-6">
              <span className="w-2 h-2 bg-accent rounded-full animate-pulse" />
              Now serving San Antonio, TX
            </div>
            
            <h1 className="text-4xl sm:text-5xl lg:text-6xl font-bold text-foreground leading-tight tracking-tight text-balance">
              Staffing made as simple as a text message
            </h1>
            
            <p className="mt-6 text-lg text-muted-foreground max-w-xl mx-auto lg:mx-0 leading-relaxed">
              Connect employers with ready-to-work talent instantly. Workers get flexible opportunities. Employers get reliable help. Everyone wins.
            </p>
            
            <div className="mt-8 flex flex-col sm:flex-row gap-4 justify-center lg:justify-start">
              <Button size="lg" className="text-base px-6" asChild>
                <Link href="#employers">
                  I Need Workers
                  <ArrowRight className="ml-2 h-4 w-4" />
                </Link>
              </Button>
              <Button size="lg" variant="outline" className="text-base px-6 bg-transparent" asChild>
                <Link href="#workers">
                  I Want to Work
                </Link>
              </Button>
            </div>
          </div>

          <div className="flex-1 w-full max-w-md">
            <PhoneMockup />
          </div>
        </div>
      </div>
    </section>
  );
}

function PhoneMockup() {
  return (
    <div className="relative mx-auto w-72 sm:w-80">
      <div className="bg-foreground rounded-[2.5rem] p-3 shadow-2xl">
        <div className="bg-card rounded-[2rem] overflow-hidden">
          <div className="bg-muted px-4 py-3 flex items-center gap-3">
            <div className="w-10 h-10 bg-primary rounded-full flex items-center justify-center">
              <span className="text-primary-foreground text-xs font-bold">SR</span>
            </div>
            <div>
              <p className="font-medium text-sm text-foreground">ShiftReady</p>
              <p className="text-xs text-muted-foreground">Text Message</p>
            </div>
          </div>
          
          <div className="p-4 space-y-3 min-h-[320px] bg-card">
            <div className="flex justify-start">
              <div className="bg-muted rounded-2xl rounded-tl-sm px-4 py-2.5 max-w-[85%]">
                <p className="text-sm text-foreground">
                  Hi Maria! Warehouse help needed tomorrow 8am-2pm at Downtown Logistics. $18/hr. Interested?
                </p>
                <p className="text-xs text-muted-foreground mt-1">9:15 AM</p>
              </div>
            </div>
            
            <div className="flex justify-end">
              <div className="bg-accent text-accent-foreground rounded-2xl rounded-tr-sm px-4 py-2.5 max-w-[85%]">
                <p className="text-sm">Yes</p>
                <p className="text-xs opacity-80 mt-1">9:16 AM</p>
              </div>
            </div>
            
            <div className="flex justify-start">
              <div className="bg-muted rounded-2xl rounded-tl-sm px-4 py-2.5 max-w-[85%]">
                <p className="text-sm text-foreground">
                  You{"'"}re confirmed! Address: 123 Commerce St. Ask for Mike at the loading dock. Payment hits your account when shift ends.
                </p>
                <p className="text-xs text-muted-foreground mt-1">9:16 AM</p>
              </div>
            </div>

            <div className="flex justify-end">
              <div className="bg-accent text-accent-foreground rounded-2xl rounded-tr-sm px-4 py-2.5 max-w-[85%]">
                <p className="text-sm">Thanks!</p>
                <p className="text-xs opacity-80 mt-1">9:17 AM</p>
              </div>
            </div>
          </div>
          
          <div className="bg-muted px-4 py-3 flex items-center gap-2">
            <div className="flex-1 bg-card rounded-full px-4 py-2">
              <span className="text-muted-foreground text-sm">iMessage</span>
            </div>
            <div className="w-8 h-8 bg-accent rounded-full flex items-center justify-center">
              <MessageSquare className="w-4 h-4 text-accent-foreground" />
            </div>
          </div>
        </div>
      </div>
      
      <div className="absolute -bottom-4 left-1/2 -translate-x-1/2 w-32 h-1 bg-foreground/20 rounded-full" />
    </div>
  );
}
