import { Container, Logo } from "./primitives";

const COLUMNS = [
  {
    heading: "Platform",
    links: [
      "Pre-D workbench",
      "Coverage intelligence",
      "Clinical evidence",
      "Revenue operations",
      "DSO intelligence",
    ],
    href: "#products",
  },
  {
    heading: "Solutions",
    links: [
      "Prevent pre-D denials",
      "Reduce revenue leakage",
      "Front office productivity",
      "DSO performance",
      "Patient financial experience",
    ],
    href: "#products",
  },
  {
    heading: "Resources",
    links: ["Docs", "Blog", "Pricing", "Changelog", "Status"],
    href: "#faq",
  },
  {
    heading: "Company",
    links: ["About", "Careers", "Contact us", "Demo"],
    href: "#demo-cta",
  },
];

export default function Footer() {
  return (
    <footer className="border-t border-gray-200 bg-gray-50">
      <Container className="py-12">
        <div className="grid grid-cols-2 gap-8 md:grid-cols-5">
          <div className="col-span-2 md:col-span-1">
            <Logo />
            <p className="mt-3 max-w-[240px] text-[12.5px] leading-relaxed text-gray-500">
              The Dental Decision Intelligence Platform. Evidence assembled.
              Policy applied. Decisions explained.
            </p>
          </div>

          {COLUMNS.map((col) => (
            <div key={col.heading}>
              <h3 className="text-[12px] font-semibold uppercase tracking-wide text-gray-900">
                {col.heading}
              </h3>
              <ul className="mt-3 space-y-2">
                {col.links.map((l) => (
                  <li key={l}>
                    <a
                      href={col.href}
                      className="text-[12.5px] text-gray-500 transition hover:text-accord-green-900"
                    >
                      {l}
                    </a>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
      </Container>

      <div className="border-t border-gray-200">
        <Container className="flex flex-col gap-2 py-5 sm:flex-row sm:items-center sm:justify-between">
          <p className="text-[12px] text-gray-500">
            © 2026 Accord Dental Inc. All rights reserved.
          </p>
          <p className="text-[12px] text-gray-500">
            <a href="#faq" className="hover:text-accord-green-900">Privacy Policy</a>
            <span className="mx-2 text-gray-300">·</span>
            <a href="#faq" className="hover:text-accord-green-900">Terms</a>
            <span className="mx-2 text-gray-300">·</span>
            <a href="#faq" className="hover:text-accord-green-900">Security</a>
          </p>
        </Container>
      </div>
    </footer>
  );
}
