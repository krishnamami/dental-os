import { AccordLogo } from "../AccordLogo";
import { Container } from "./primitives";

type ColLink = { label: string; href: string };
type Col = {
  heading: string;
  links: string[];
  href: string;
  /** Set when a column's entries point at different destinations. */
  customLinks?: ColLink[];
};

const COLUMNS: Col[] = [
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
    links: ["Docs", "Blog", "Pricing"],
    href: "#faq",
  },
  {
    heading: "Company",
    links: [],
    href: "",
    customLinks: [
      { label: "About", href: "#what-if" },
      {
        label: "Contact us",
        href: "https://docs.google.com/forms/d/e/1FAIpQLScQ0iD1sH_oIC7AT14O_ZQPNL_nylxv2BUPrFM1J2f0-KkhOA/viewform",
      },
      { label: "Demo", href: "#demo" },
    ],
  },
];

export default function Footer() {
  return (
    <footer className="border-t border-gray-200 bg-gray-50">
      <Container className="py-12">
        <div className="grid grid-cols-2 gap-8 md:grid-cols-5">
          <div className="col-span-2 md:col-span-1">
            <div className="mb-3">
              <AccordLogo size={24} />
            </div>
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
                {(
                  col.customLinks ??
                  col.links.map((l) => ({ label: l, href: col.href }))
                ).map((link) => (
                  <li key={link.label}>
                    {/* External destinations open in a new tab, with
                        rel="noopener" so the opened page cannot reach
                        back through window.opener. In-page anchors stay
                        in the same tab. */}
                    <a
                      href={link.href}
                      target={link.href.startsWith("http") ? "_blank" : undefined}
                      rel={
                        link.href.startsWith("http")
                          ? "noopener noreferrer"
                          : undefined
                      }
                      className="text-[12.5px] text-gray-500 transition hover:text-accord-green-900"
                    >
                      {link.label}
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
