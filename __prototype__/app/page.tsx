import { Header } from "@/components/header";
import { HeroSection } from "@/components/hero-section";
import { StatsSection } from "@/components/stats-section";
import { EmployersSection } from "@/components/employers-section";
import { WorkersSection } from "@/components/workers-section";
import { HowItWorksSection } from "@/components/how-it-works-section";
import { RegionSection } from "@/components/region-section";
import { FAQSection } from "@/components/faq-section";
import { CTASection } from "@/components/cta-section";
import { Footer } from "@/components/footer";

export default function Home() {
  return (
    <main className="min-h-screen">
      <Header />
      <HeroSection />
      <StatsSection />
      <EmployersSection />
      <WorkersSection />
      <HowItWorksSection />
      <RegionSection />
      <FAQSection />
      <CTASection />
      <Footer />
    </main>
  );
}
