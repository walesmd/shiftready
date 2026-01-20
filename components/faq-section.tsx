"use client";

import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";

export function FAQSection() {
  const employerFAQs = [
    {
      question: "How quickly can I get workers?",
      answer: "Depending on availability, we can often fill shifts within hours. For best results, give us 24-48 hours notice, but we understand business doesn't always work that way.",
    },
    {
      question: "What does it cost?",
      answer: "You pay an hourly rate that covers the worker's wages, our service fee, payroll taxes, and workers' comp insurance. No hidden fees, no long-term contracts.",
    },
    {
      question: "Are workers vetted?",
      answer: "Yes. All workers complete our verification process including identity verification and background screening. We also track performance across all jobs.",
    },
    {
      question: "What if a worker doesn't show up?",
      answer: "We always over-staff slightly to account for life happening. If there's ever an issue, we work to find a replacement ASAP and you're never charged for no-shows.",
    },
  ];

  const workerFAQs = [
    {
      question: "How do I get paid?",
      answer: "Same-day payment via direct deposit. Finish your shift, payment is processed automatically. No waiting for payday, no paper checks.",
    },
    {
      question: "Do I have to accept every job offer?",
      answer: "Absolutely not. You only work when you want to. Decline any offer that doesn't fit your schedule—there's no penalty, and it won't affect future offers.",
    },
    {
      question: "What jobs are available?",
      answer: "We specialize in roles that can be learned quickly: warehouse work, moving help, event setup, vehicle relocation, general labor. Jobs vary based on local employer needs.",
    },
    {
      question: "Is there a minimum number of hours?",
      answer: "No minimums. Work one shift a month or five shifts a week—it's completely up to you and what opportunities match your availability.",
    },
  ];

  return (
    <section className="py-20 px-4 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto">
        <div className="text-center mb-12">
          <h2 className="text-3xl sm:text-4xl font-bold text-foreground">Frequently Asked Questions</h2>
        </div>

        <div className="grid lg:grid-cols-2 gap-12">
          <div>
            <h3 className="font-semibold text-lg text-foreground mb-6">For Employers</h3>
            <Accordion type="single" collapsible className="w-full">
              {employerFAQs.map((faq, index) => (
                <AccordionItem key={index} value={`employer-${index}`}>
                  <AccordionTrigger className="text-left">{faq.question}</AccordionTrigger>
                  <AccordionContent className="text-muted-foreground">{faq.answer}</AccordionContent>
                </AccordionItem>
              ))}
            </Accordion>
          </div>

          <div>
            <h3 className="font-semibold text-lg text-foreground mb-6">For Workers</h3>
            <Accordion type="single" collapsible className="w-full">
              {workerFAQs.map((faq, index) => (
                <AccordionItem key={index} value={`worker-${index}`}>
                  <AccordionTrigger className="text-left">{faq.question}</AccordionTrigger>
                  <AccordionContent className="text-muted-foreground">{faq.answer}</AccordionContent>
                </AccordionItem>
              ))}
            </Accordion>
          </div>
        </div>
      </div>
    </section>
  );
}
