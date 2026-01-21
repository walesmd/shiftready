export function StatsSection() {
  const stats = [
    { value: "< 30 sec", label: "Average response time" },
    { value: "Same day", label: "Payment processing" },
    { value: "95%", label: "Worker satisfaction" },
    { value: "Zero", label: "Payroll headaches" },
  ];

  return (
    <section className="py-16 px-4 sm:px-6 lg:px-8 border-y border-border bg-card">
      <div className="max-w-7xl mx-auto">
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-8">
          {stats.map((stat) => (
            <div key={stat.label} className="text-center">
              <p className="text-3xl sm:text-4xl font-bold text-foreground">{stat.value}</p>
              <p className="mt-2 text-sm text-muted-foreground">{stat.label}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
