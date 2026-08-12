import { Container, Eyebrow, H2, Section, Sub } from "./primitives";

const STEPS = [
  {
    title: "Eligibility checked",
    body:
      "Patient checks in. Coverage, annual max, deductible, waiting periods — " +
      "all returned in 3 seconds.",
  },
  {
    title: "Documents analysed",
    body:
      "PA X-rays, perio charts, and clinical notes processed. Bone loss " +
      "extracted. ADA criteria evaluated.",
  },
  {
    title: "Recommend pre-submit",
    body:
      "9 AI personas run across 5 waves. Every bundling conflict and missing " +
      "document surfaced with citations.",
  },
  {
    title: "Provider decides",
    body:
      "AI surfaces rules. You decide. Every signal has a citation. " +
      "No black boxes. Human always in control.",
  },
];

export default function Steps() {
  return (
    <Section id="how-it-works">
      <Container>
        <div className="mx-auto max-w-2xl text-center">
          <Eyebrow>How it works</Eyebrow>
          <H2>From patient check-in to decision in four steps</H2>
          <Sub className="mt-3">
            Every step traces back to evidence. Every signal is citeable.
            Every decision is defensible.
          </Sub>
        </div>

        <ol className="mt-11 grid grid-cols-2 gap-3 sm:gap-6 lg:grid-cols-4">
          {STEPS.map((s, i) => (
            <li
              key={s.title}
              className="rounded-xl border border-gray-200 bg-white p-5"
            >
              <span className="flex h-8 w-8 items-center justify-center rounded-full bg-accord-green-900 text-[13px] font-semibold text-white">
                {i + 1}
              </span>
              <h3 className="mt-3.5 text-[15px] font-semibold text-gray-900">
                {s.title}
              </h3>
              <p className="mt-2 text-[13.5px] leading-relaxed text-gray-500">
                {s.body}
              </p>
            </li>
          ))}
        </ol>
      </Container>
    </Section>
  );
}
