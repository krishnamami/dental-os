import {
  ArrowRight,
  BarChart3,
  ClipboardCheck,
  FileText,
  Receipt,
  ShieldCheck,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";

import { Container, Eyebrow, H2, Section, Sub } from "./primitives";

interface Product {
  icon: LucideIcon;
  tone: string;
  title: string;
  body: string;
  /** Omitted when there is no anonymous demo — see DSO below. */
  href?: string;
}

const PRODUCTS: Product[] = [
  {
    icon: ClipboardCheck,
    tone: "bg-accord-green-50 text-accord-green-700",
    title: "Pre-D Workbench",
    body:
      "Submission readiness in one view. Every condition flagged with " +
      "assignee, SLA, and citation.",
    href: "/workbench?demo=true",
  },
  {
    icon: ShieldCheck,
    tone: "bg-blue-50 text-blue-700",
    title: "Coverage Intelligence",
    body:
      "181 CDT codes × 6 payers × 7 states. UCR → patient pays — shown " +
      "before the patient sits down.",
    href: "/coverage?demo=true",
  },
  {
    icon: FileText,
    tone: "bg-purple-50 text-purple-700",
    title: "Clinical Evidence",
    body:
      "From PA X-ray to ADA citation automatically. Bone loss, pocket " +
      "depth, confidence scores.",
    href: "/evidence/PRED-SIM-DA-A01?demo=true",
  },
  {
    icon: Receipt,
    tone: "bg-orange-50 text-orange-700",
    title: "Revenue Operations",
    body:
      "Submissions, conditions, appeals, collections. One view for " +
      "billing and revenue cycle teams.",
    href: "/revenue-ops?demo=true",
  },
];

const DSO: Product = {
  icon: BarChart3,
  tone: "bg-accord-green-50 text-accord-green-700",
  title: "DSO Intelligence",
  body:
    "Denial patterns, payer performance, and training recommendations " +
    "across every location in your group.",
  // ⚠ NO href, DELIBERATELY. This used to be /dso?demo=true.
  //
  // /portfolio/summary is now behind require_practice_admin, because
  // it had been readable by every signed-in role AND by an anonymous
  // X-Demo-Mode request — a credential-free path to a practice's
  // revenue. The tour would 403 and render the error card, which is a
  // worse advertisement than no link.
  //
  // A DSO demo needs a signed-in dso_owner. When there is one to send
  // people to, put the href back.
};

function Card({ product, wide = false }: { product: Product; wide?: boolean }) {
  const Icon = product.icon;
  // A card with no demo behind it is a <div>, not a dead <a>. Keeping
  // the anchor and dropping the href leaves a focusable element that
  // announces itself as a link and goes nowhere.
  const Tag = product.href ? "a" : "div";
  return (
    <Tag
      href={product.href}
      className={`group flex rounded-xl border border-gray-200 bg-white p-5 transition ${
        product.href
          ? "hover:border-accord-green-500 hover:shadow-sm"
          : "border-dashed"
      } ${wide ? "sm:items-center sm:gap-6" : "flex-col"}`}
    >
      <span
        className={`flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-xl ${product.tone}`}
      >
        <Icon size={19} />
      </span>
      <div className={wide ? "mt-4 sm:mt-0" : "mt-4"}>
        <h3 className="text-[15.5px] font-semibold text-gray-900">
          {product.title}
        </h3>
        <p className="mt-1.5 text-[13.5px] leading-relaxed text-gray-500">
          {product.body}
        </p>
        {product.href ? (
          <span className="mt-3 inline-flex items-center gap-1.5 text-[13px] font-medium text-accord-green-900">
            Launch demo
            <ArrowRight
              size={14}
              className="transition group-hover:translate-x-0.5"
            />
          </span>
        ) : (
          <span className="mt-3 inline-flex text-[13px] font-medium text-gray-400">
            Available to signed-in group owners
          </span>
        )}
      </div>
    </Tag>
  );
}

export default function Products() {
  return (
    <Section id="products">
      <Container>
        <div className="mx-auto max-w-2xl text-center">
          <Eyebrow>The platform</Eyebrow>
          <H2>Five products. One platform.</H2>
          <Sub className="mt-3">
            Start with Pre-D Workbench. Add on your pace.
          </Sub>
        </div>

        <div className="mt-10 grid gap-4 md:grid-cols-2">
          {PRODUCTS.map((p) => (
            <Card key={p.title} product={p} />
          ))}
        </div>
        <div className="mt-4">
          <Card product={DSO} wide />
        </div>
      </Container>
    </Section>
  );
}
