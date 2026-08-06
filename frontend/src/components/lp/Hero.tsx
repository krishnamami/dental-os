import { ArrowRight } from "lucide-react";

import { useDemoModal } from "../../hooks/useDemoModal";
import { Container, Eyebrow, GhostButton, PrimaryButton } from "./primitives";
import WorkbenchCard from "./WorkbenchCard";

const TRUST = [
  { icon: "🔒", label: "HIPAA compliant" },
  { icon: "📋", label: "Audit trail built in" },
  { icon: "⚖️", label: "ADA + payer citations" },
  { icon: "🌐", label: "No black boxes" },
];

const STATS = [
  { value: "15 min → 3s", label: "Coverage check speed" },
  { value: "65%", label: "Appeal overturn rate" },
  { value: "3 layers", label: "ADA · Payer · Overlay" },
  { value: "Zero", label: "Surprise patient bills" },
];

export default function Hero() {
  const modal = useDemoModal();
  return (
    <section id="top" className="pb-14 pt-12 sm:pb-20 sm:pt-16">
      <Container>
        <div className="grid items-start gap-10 lg:grid-cols-2 lg:gap-14">
          <div>
            <Eyebrow>Dental decision intelligence</Eyebrow>

            {/* Stacked, one clause per line, with the answer in green.
                The <br> are unconditional: the break IS the sentence
                structure here, not a width accommodation, so it has to
                hold at 375px and at 1440px alike. */}
            <h1 className="max-w-xl text-5xl font-bold leading-[1.05] tracking-tight text-gray-900 md:text-6xl">
              Every pre-D denial.
              <br />
              <span className="text-accord-green-900">Caught.</span>
              <br />
              <span className="text-accord-green-900">
                Before you submit.
              </span>
            </h1>

            <p className="mt-5 max-w-xl text-[15px] leading-relaxed text-gray-500 sm:text-base">
              Accord reads the payer policy, the clinical evidence, and the
              plan's own limits before the claim goes out — then tells you
              exactly what is missing, who fixes it, and by when.
            </p>

            <div className="mt-7 flex flex-col gap-3 sm:flex-row sm:flex-wrap">
              <PrimaryButton
                onClick={modal.open}
                className="min-h-[44px] w-full sm:w-auto"
              >
                Request a demo
              </PrimaryButton>
              <GhostButton href="#how-it-works" className="min-h-[44px] w-full sm:w-auto">
                See how it works
                <ArrowRight size={15} />
              </GhostButton>
            </div>

            {/* Claims about how the product behaves, not certifications.
                "HIPAA compliant" here describes the architecture — there
                is no third-party attestation behind it yet, and it should
                come down or gain a footnote before it faces a buyer's
                security review. */}
            <ul className="mt-6 flex flex-wrap gap-x-5 gap-y-2">
              {TRUST.map((t) => (
                <li
                  key={t.label}
                  className="flex items-center gap-1.5 text-[12.5px] text-gray-500"
                >
                  <span aria-hidden="true">{t.icon}</span>
                  {t.label}
                </li>
              ))}
            </ul>

            <dl className="mt-10 grid grid-cols-2 gap-x-6 gap-y-5 border-t border-gray-200 pt-7 sm:grid-cols-4">
              {STATS.map((s) => (
                <div key={s.label}>
                  <dt className="sr-only">{s.label}</dt>
                  <dd>
                    <span className="block text-[17px] font-semibold leading-tight text-gray-900">
                      {s.value}
                    </span>
                    <span className="mt-1 block text-[12px] leading-snug text-gray-500">
                      {s.label}
                    </span>
                  </dd>
                </div>
              ))}
            </dl>
          </div>

          {/* Card second in the DOM, so a screen reader and a phone both
              get the headline before the demo. */}
          <div className="lg:pt-2">
            <WorkbenchCard />
          </div>
        </div>
      </Container>
    </section>
  );
}
