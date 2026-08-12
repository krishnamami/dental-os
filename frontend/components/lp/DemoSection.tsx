import { ArrowRight, Play } from "lucide-react";

import { Container, Eyebrow, H2, Section, Sub } from "./primitives";

const LINKS = [
  { label: "Book a live demo", href: "#demo-cta" },
  { label: "See DA-A01 implant case", href: "/?demo=true" },
  { label: "View all 50 scenarios", href: "#products" },
];

export default function DemoSection() {
  return (
    <Section>
      <Container>
        <div className="mx-auto max-w-2xl text-center">
          <Eyebrow>See it in action</Eyebrow>
          <H2>Watch Accord Dental review a pre-D</H2>
          <Sub className="mt-3">
            From patient check-in to submission-ready in seconds.
          </Sub>
        </div>

        <div className="mx-auto mt-10 flex aspect-video max-h-[380px] w-full max-w-4xl items-center justify-center rounded-xl border border-gray-200 bg-gray-100">
          <div className="text-center">
            <span className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-white text-gray-400 shadow-sm">
              <Play size={22} fill="currentColor" />
            </span>
            <p className="mt-3 text-sm text-gray-500">Demo video coming soon</p>
          </div>
        </div>

        <div className="mt-7 flex flex-col items-center gap-2.5 sm:flex-row sm:flex-wrap sm:justify-center sm:gap-x-7">
          {LINKS.map((l) => (
            <a
              key={l.label}
              href={l.href}
              className="inline-flex items-center gap-1.5 text-[13.5px] font-medium text-accord-green-900 hover:text-accord-green-700"
            >
              {l.label}
              <ArrowRight size={14} />
            </a>
          ))}
        </div>
      </Container>
    </Section>
  );
}
