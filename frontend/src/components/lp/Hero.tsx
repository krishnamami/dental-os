import { ArrowRight } from "lucide-react";

import { useDemoModal } from "../../hooks/useDemoModal";
import { Container, Eyebrow, GhostButton, PrimaryButton } from "./primitives";
import WorkbenchCard from "./WorkbenchCard";

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

            <h1 className="max-w-xl text-[32px] font-medium leading-[1.12] tracking-[-0.02em] text-gray-900 sm:text-[40px]">
              The Dental Decision
              <br className="hidden sm:block" /> Intelligence Platform
            </h1>

            <p className="mt-5 max-w-xl text-[15px] leading-relaxed text-gray-500 sm:text-base">
              Supporting every stage of the pre-determination lifecycle — from
              patient check-in and eligibility verification to clinical review,
              revenue operations, appeals, and DSO performance.
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
