import { Button } from "@/components/ui/button";
import { MapPin } from "lucide-react";

export function RegionSection() {
  const comingSoon = ["Austin", "Houston", "Dallas", "Fort Worth"];

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
          <div className="flex flex-col sm:flex-row gap-3">
            <input
              type="email"
              placeholder="Enter your email"
              className="flex-1 px-4 py-2 bg-card border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-accent"
            />
            <Button>Notify Me</Button>
          </div>
        </div>
      </div>
    </section>
  );
}
