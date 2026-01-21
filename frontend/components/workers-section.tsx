import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Smartphone, DollarSign, Calendar, MapPin } from "lucide-react";

export function WorkersSection() {
  const benefits = [
    {
      icon: Smartphone,
      title: "Simple as Yes or No",
      description: "Get job offers via text. Reply Yes to accept, No to skip. No apps to download, no complicated systems.",
    },
    {
      icon: DollarSign,
      title: "Get Paid Immediately",
      description: "Finish your shift, get paid. Money hits your account the same day. No waiting for payday.",
    },
    {
      icon: Calendar,
      title: "Work When You Want",
      description: "Only take jobs that fit your schedule. No commitments, no penalties for saying no.",
    },
    {
      icon: MapPin,
      title: "Jobs Near You",
      description: "We match you with opportunities in your area. Less commute, more time for what matters.",
    },
  ];

  return (
    <section id="workers" className="py-20 px-4 sm:px-6 lg:px-8 bg-card">
      <div className="max-w-7xl mx-auto">
        <div className="max-w-2xl mb-12">
          <p className="text-sm font-medium text-accent mb-3">For Workers</p>
          <h2 className="text-3xl sm:text-4xl font-bold text-foreground text-balance">
            Earn extra money on your terms.
          </h2>
          <p className="mt-4 text-lg text-muted-foreground leading-relaxed">
            Looking to supplement your income? Want flexible work around your schedule? We text you opportunities—you decide if they{"'"}re right for you.
          </p>
        </div>

        <div className="grid sm:grid-cols-2 gap-6 mb-12">
          {benefits.map((benefit) => (
            <Card key={benefit.title} className="border-border bg-background">
              <CardContent className="pt-6">
                <div className="flex gap-4">
                  <div className="w-12 h-12 bg-accent/10 rounded-xl flex items-center justify-center flex-shrink-0">
                    <benefit.icon className="w-6 h-6 text-accent" />
                  </div>
                  <div>
                    <h3 className="font-semibold text-foreground mb-2">{benefit.title}</h3>
                    <p className="text-sm text-muted-foreground leading-relaxed">{benefit.description}</p>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>

        <div className="bg-foreground rounded-2xl p-8 sm:p-10 text-center">
          <h3 className="text-2xl font-bold text-primary-foreground mb-3">Ready to start earning?</h3>
          <p className="text-primary-foreground/80 mb-6 max-w-md mx-auto">
            Sign up in 2 minutes. No fees, no catches. We{"'"}ll text you when we have work that matches your profile.
          </p>
          <Button size="lg" variant="secondary" className="bg-primary-foreground text-foreground hover:bg-primary-foreground/90" asChild>
            <Link href="/signup/worker">
              Join ShiftReady
            </Link>
          </Button>
        </div>
      </div>
    </section>
  );
}
