export function HowItWorksSection() {
  const employerSteps = [
    { step: "01", title: "Tell us what you need", description: "Job type, number of workers, date and time." },
    { step: "02", title: "We find the workers", description: "Our network of vetted workers gets notified instantly." },
    { step: "03", title: "Workers show up", description: "Confirmed workers arrive ready to work." },
    { step: "04", title: "We handle the rest", description: "Payroll, taxes, insurance—all taken care of." },
  ];

  const workerSteps = [
    { step: "01", title: "Sign up via text", description: "Share your availability and skills." },
    { step: "02", title: "Get matched", description: "Receive job offers that fit your schedule." },
    { step: "03", title: "Reply Yes or No", description: "Accept what works, decline what doesn't." },
    { step: "04", title: "Work & get paid", description: "Complete the shift, money in your account same day." },
  ];

  return (
    <section id="how-it-works" className="py-20 px-4 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto">
        <div className="text-center mb-16">
          <h2 className="text-3xl sm:text-4xl font-bold text-foreground">How It Works</h2>
          <p className="mt-4 text-lg text-muted-foreground">Simple for everyone involved.</p>
        </div>

        <div className="grid lg:grid-cols-2 gap-12 lg:gap-16">
          <div>
            <h3 className="text-xl font-semibold text-foreground mb-8 flex items-center gap-3">
              <span className="w-8 h-8 bg-secondary rounded-full flex items-center justify-center text-sm font-bold">E</span>
              For Employers
            </h3>
            <div className="space-y-6">
              {employerSteps.map((step, index) => (
                <div key={step.step} className="flex gap-4">
                  <div className="flex flex-col items-center">
                    <span className="text-xs font-bold text-muted-foreground">{step.step}</span>
                    {index < employerSteps.length - 1 && (
                      <div className="w-px h-full bg-border mt-2" />
                    )}
                  </div>
                  <div className="pb-6">
                    <h4 className="font-medium text-foreground">{step.title}</h4>
                    <p className="text-sm text-muted-foreground mt-1">{step.description}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div>
            <h3 className="text-xl font-semibold text-foreground mb-8 flex items-center gap-3">
              <span className="w-8 h-8 bg-accent/20 rounded-full flex items-center justify-center text-sm font-bold text-accent">W</span>
              For Workers
            </h3>
            <div className="space-y-6">
              {workerSteps.map((step, index) => (
                <div key={step.step} className="flex gap-4">
                  <div className="flex flex-col items-center">
                    <span className="text-xs font-bold text-muted-foreground">{step.step}</span>
                    {index < workerSteps.length - 1 && (
                      <div className="w-px h-full bg-border mt-2" />
                    )}
                  </div>
                  <div className="pb-6">
                    <h4 className="font-medium text-foreground">{step.title}</h4>
                    <p className="text-sm text-muted-foreground mt-1">{step.description}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
