import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { CheckCircle2, ArrowRight, Calculator, Users, FileText, Clock } from "lucide-react";

export function EmployersSection() {
  const benefits = [
    {
      icon: Calculator,
      title: "No Payroll Hassles",
      description: "We handle all payroll, taxes, and compliance. Workers are on our books, not yours.",
    },
    {
      icon: Users,
      title: "No Recruiting Needed",
      description: "Tell us what you need, we fill the shift. It's that simple.",
    },
    {
      icon: FileText,
      title: "No HR Paperwork",
      description: "Skip the onboarding paperwork. We manage W-2s, I-9s, and insurance.",
    },
    {
      icon: Clock,
      title: "Flexible Scheduling",
      description: "Need help tomorrow? Next week? Scale up or down as your business demands.",
    },
  ];

  const idealJobs = [
    "Warehouse packing & sorting",
    "Moving & loading help",
    "Event setup & teardown",
    "Vehicle relocation",
    "Light assembly work",
    "General labor support",
  ];

  return (
    <section id="employers" className="py-20 px-4 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto">
        <div className="max-w-2xl mb-12">
          <p className="text-sm font-medium text-accent mb-3">For Employers</p>
          <h2 className="text-3xl sm:text-4xl font-bold text-foreground text-balance">
            Stop worrying about staffing. Start getting work done.
          </h2>
          <p className="mt-4 text-lg text-muted-foreground leading-relaxed">
            If a job can be trained in 10-15 minutes and you don{"'"}t need the same person every day, we{"'"}re your solution.
          </p>
        </div>

        <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-6 mb-12">
          {benefits.map((benefit) => (
            <Card key={benefit.title} className="border-border bg-card">
              <CardContent className="pt-6">
                <div className="w-10 h-10 bg-secondary rounded-lg flex items-center justify-center mb-4">
                  <benefit.icon className="w-5 h-5 text-foreground" />
                </div>
                <h3 className="font-semibold text-foreground mb-2">{benefit.title}</h3>
                <p className="text-sm text-muted-foreground leading-relaxed">{benefit.description}</p>
              </CardContent>
            </Card>
          ))}
        </div>

        <div className="bg-secondary rounded-2xl p-8 sm:p-10">
          <div className="flex flex-col lg:flex-row lg:items-center gap-8">
            <div className="flex-1">
              <h3 className="text-xl font-semibold text-foreground mb-4">Perfect for roles like:</h3>
              <div className="grid sm:grid-cols-2 gap-3">
                {idealJobs.map((job) => (
                  <div key={job} className="flex items-center gap-2">
                    <CheckCircle2 className="w-4 h-4 text-accent flex-shrink-0" />
                    <span className="text-sm text-foreground">{job}</span>
                  </div>
                ))}
              </div>
            </div>
            <div className="lg:text-right">
              <Button size="lg" className="w-full sm:w-auto">
                Request Workers
                <ArrowRight className="ml-2 h-4 w-4" />
              </Button>
              <p className="text-sm text-muted-foreground mt-3">No contracts. Pay only for hours worked.</p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
