import { Check, Container, Eyebrow, H2, Section, Sub } from "./primitives";

const TIERS = [
  {
    name: "Starter",
    price: "$15",
    unit: "/pre-D",
    note: "Up to 50 pre-Ds/month",
    features: ["Pre-D workbench", "Coverage intelligence"],
    cta: "Start free trial",
    featured: false,
  },
  {
    name: "Growth",
    price: "$35",
    unit: "/pre-D",
    note: "Unlimited pre-Ds",
    features: [
      "Everything in Starter",
      "Clinical evidence",
      "Appeals generation",
    ],
    cta: "Start free trial",
    featured: false,
  },
  {
    name: "Practice",
    price: "$60",
    unit: "/pre-D",
    note: "For multi-chair practices",
    features: [
      "Everything in Growth",
      "Revenue operations",
      "DSO intelligence",
      "24/7 priority support",
    ],
    cta: "Start free trial",
    featured: true,
  },
  {
    name: "Enterprise",
    price: "Custom",
    unit: "",
    note: "For groups and DSOs",
    features: [
      "Everything in Practice",
      "Multi-location analytics",
      "Custom integrations",
      "Dedicated success manager",
    ],
    cta: "Contact sales",
    featured: false,
  },
];

export default function Pricing() {
  return (
    <Section id="pricing">
      <Container>
        <div className="mx-auto max-w-2xl text-center">
          <Eyebrow>Pricing</Eyebrow>
          <H2>Simple per-pre-D pricing. No hidden fees.</H2>
          <Sub className="mt-3">
            Start with Pre-D Workbench. Add on your pace.
          </Sub>
        </div>

        <div className="mt-10 grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-4">
          {TIERS.map((t) => (
            <div
              key={t.name}
              className={`relative flex flex-col rounded-xl border bg-white p-5 ${
                t.featured
                  ? "border-accord-green-500 shadow-sm ring-1 ring-accord-green-500"
                  : "border-gray-200"
              }`}
            >
              {t.featured && (
                <span className="absolute -top-2.5 left-5 rounded-full bg-accord-green-900 px-2.5 py-0.5 text-[10.5px] font-semibold uppercase tracking-wide text-white">
                  Most popular
                </span>
              )}
              <h3 className="text-[15px] font-semibold text-gray-900">
                {t.name}
              </h3>
              <p className="mt-2.5">
                <span className="text-[26px] font-semibold leading-none text-gray-900">
                  {t.price}
                </span>
                <span className="text-[13px] text-gray-500">{t.unit}</span>
              </p>
              <p className="mt-1.5 text-[12.5px] text-gray-500">{t.note}</p>

              <ul className="mt-5 flex-1 space-y-2.5">
                {t.features.map((f) => (
                  <Check key={f}>{f}</Check>
                ))}
              </ul>

              <a
                href="#demo-cta"
                className={`mt-6 inline-flex w-full items-center justify-center rounded-lg px-4 py-2.5 text-[13.5px] font-semibold transition ${
                  t.featured
                    ? "bg-accord-green-900 text-white hover:bg-accord-green-700"
                    : "border border-gray-300 text-gray-700 hover:bg-gray-50"
                }`}
              >
                {t.cta}
              </a>
            </div>
          ))}
        </div>

        <p className="mt-6 text-center text-[12px] text-gray-400">
          Indicative pricing for the pilot programme. Final terms are agreed per
          practice.
        </p>
      </Container>
    </Section>
  );
}
