import { Check, Container, Eyebrow, Section } from "./primitives";

const COLUMNS = [
  {
    eyebrow: "Pre-D workbench",
    title: "See what matters. Catch denials early.",
    body:
      "Every bundling conflict caught. Every missing document flagged. " +
      "Every policy cited before you click submit.",
    checks: [
      "Bundling conflicts with ADA and payer citations",
      "Document completeness by CDT code",
      "14-flag submission readiness score",
    ],
  },
  {
    eyebrow: "Coverage intelligence",
    title: "No more payer phone calls.",
    body:
      "UCR → contracted → discount → patient in 3 seconds. " +
      "181 CDT codes × 6 payers × 7 states.",
    checks: [
      "Annual max tracking per patient",
      "In-network discount shown before treatment",
      "Printable patient benefit summary",
    ],
  },
  {
    eyebrow: "Revenue operations",
    title: "Submissions, appeals, collections. One view.",
    body:
      "Every pre-D from submission queue to appeal packet to collection. " +
      "65% appeal overturn rate with the right documentation.",
    checks: [
      "One-click appeal packets with ADA citations",
      "Deadline tracking per denial",
      "Payer communication log",
    ],
  },
];

export default function ValueProps() {
  return (
    <div className="border-y border-gray-200 bg-gray-50">
      <Section>
        <Container>
          <div className="grid gap-10 md:grid-cols-3 md:gap-8">
            {COLUMNS.map((c) => (
              <div key={c.eyebrow}>
                <Eyebrow>{c.eyebrow}</Eyebrow>
                <h3 className="text-[19px] font-semibold leading-snug tracking-[-0.01em] text-gray-900">
                  {c.title}
                </h3>
                <p className="mt-3 text-[14px] leading-relaxed text-gray-500">
                  {c.body}
                </p>
                <ul className="mt-5 space-y-2.5">
                  {c.checks.map((t) => (
                    <Check key={t}>{t}</Check>
                  ))}
                </ul>
              </div>
            ))}
          </div>
        </Container>
      </Section>
    </div>
  );
}
