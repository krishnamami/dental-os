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
  href: string;
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
  href: "/dso?demo=true",
};

function Card({ product, wide = false }: { product: Product; wide?: boolean }) {
  const Icon = product.icon;
  return (
    <a
      href={product.href}
      className={`group flex rounded-xl border border-gray-200 bg-white p-5 transition hover:border-accord-green-500 hover:shadow-sm ${
        wide ? "sm:items-center sm:gap-6" : "flex-col"
      }`}
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
        <span className="mt-3 inline-flex items-center gap-1.5 text-[13px] font-medium text-accord-green-900">
          Launch demo
          <ArrowRight
            size={14}
            className="transition group-hover:translate-x-0.5"
          />
        </span>
      </div>
    </a>
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
