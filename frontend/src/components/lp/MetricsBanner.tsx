import { Container } from "./primitives";

const STATS = [
  { value: "100%", label: "Signals traceable to source document" },
  { value: "1-click", label: "Appeal packets with ADA citations" },
  { value: "3 layers", label: "ADA · Payer · Tenant overlay" },
  { value: "Zero", label: "Hardcoded thresholds" },
];

export default function MetricsBanner() {
  return (
    <section className="bg-accord-green-900 py-16 text-white sm:py-20">
      <Container>
        <div className="mx-auto max-w-2xl text-center">
          <h2 className="text-[26px] font-semibold leading-[1.2] tracking-[-0.02em] sm:text-[30px]">
            Make faster, cleaner, and fully auditable pre-D submissions.
          </h2>
          <p className="mt-3 text-[15px] text-white/70">
            Built for dental providers. Not payers.
          </p>
        </div>

        <dl className="mx-auto mt-11 grid max-w-4xl grid-cols-2 gap-x-6 gap-y-8 lg:grid-cols-4">
          {STATS.map((s) => (
            <div key={s.label} className="text-center">
              <dt className="sr-only">{s.label}</dt>
              <dd>
                <span className="block text-[26px] font-semibold leading-none">
                  {s.value}
                </span>
                <span className="mt-2 block text-[12.5px] leading-snug text-white/70">
                  {s.label}
                </span>
              </dd>
            </div>
          ))}
        </dl>

        <div className="mt-11 text-center">
          <a
            href="#demo-cta"
            className="inline-flex items-center justify-center rounded-lg bg-white px-6 py-3 text-sm font-semibold text-accord-green-900 transition hover:bg-accord-green-50"
          >
            Request a demo
          </a>
        </div>
      </Container>
    </section>
  );
}
