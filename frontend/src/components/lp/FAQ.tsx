import { useState } from "react";
import { ChevronDown } from "lucide-react";

import { Container, Eyebrow, H2, Section } from "./primitives";

const FAQS = [
  {
    q: "How long does setup take?",
    a: "Under 30 minutes. Connect your practice management system, add your payers, and your first pre-D runs through the platform.",
  },
  {
    q: "Does Accord replace my PMS (Dentrix, Eaglesoft)?",
    a: "No. Accord sits alongside your PMS. It reads treatment plans and adds decision intelligence on top. No rip-and-replace.",
  },
  {
    q: "How does the AI make decisions?",
    a: "It doesn't. The policy engine decides based on ADA guidelines, payer rules, and your overlay settings. The AI surfaces evidence. You decide.",
  },
  {
    q: "What if a signal is wrong?",
    a: "Every signal has an override button. Your feedback trains the system. Override audit trail is maintained for compliance.",
  },
  {
    q: "Is my patient data secure?",
    a: "Yes. HIPAA compliant. Data encrypted at rest and in transit. Tenant-isolated — your data is never shared with other practices.",
  },
  {
    q: "Which payers are supported?",
    a: "Delta Dental, Cigna, MetLife, Aetna DMO, Humana, Guardian. More being added quarterly.",
  },
  {
    q: "Can I connect Accord to my own tools?",
    a: "Yes. REST API available on Practice and Enterprise plans. Webhooks for real-time signal delivery.",
  },
  {
    q: "Can I run Accord in my own environment?",
    a: "Enterprise plan includes on-premise deployment option. Contact sales for details.",
  },
];

export default function FAQ() {
  const [open, setOpen] = useState<number | null>(0);

  return (
    <Section id="faq" className="border-t border-gray-200">
      <Container>
        <div className="mx-auto max-w-[700px]">
          <div className="text-center">
            <Eyebrow>FAQ</Eyebrow>
            <H2>Common questions</H2>
          </div>

          <dl className="mt-9 divide-y divide-gray-200 border-y border-gray-200">
            {FAQS.map((f, i) => {
              const expanded = open === i;
              return (
                <div key={f.q}>
                  <dt>
                    <button
                      type="button"
                      onClick={() => setOpen(expanded ? null : i)}
                      aria-expanded={expanded}
                      className="flex w-full items-center justify-between gap-4 py-4 text-left"
                    >
                      <span className="text-[14.5px] font-medium text-gray-900">
                        {f.q}
                      </span>
                      <ChevronDown
                        size={17}
                        className={`flex-shrink-0 text-gray-400 transition-transform ${
                          expanded ? "rotate-180" : ""
                        }`}
                      />
                    </button>
                  </dt>
                  {expanded && (
                    <dd className="pb-4 pr-8 text-[13.5px] leading-relaxed text-gray-500">
                      {f.a}
                    </dd>
                  )}
                </div>
              );
            })}
          </dl>
        </div>
      </Container>
    </Section>
  );
}
