import { useEffect, useRef, useState } from "react";
import { Link } from "react-router-dom";
import {
  BarChart3,
  ChevronDown,
  ClipboardCheck,
  FileText,
  Menu,
  Receipt,
  ShieldCheck,
  X,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";

import { useDemoModal } from "../../hooks/useDemoModal";
import { Container, Logo, PrimaryButton } from "./primitives";

/**
 * The five products, matching Products.tsx one for one.
 *
 * Every entry points at `#products` rather than its own demo route: the
 * nav is on the marketing page, and someone browsing the menu is still
 * deciding what this is. Dropping them straight into a live workbench
 * skips the part where they find out why they want one. The section
 * cards are what launch the demos.
 */
const PRODUCTS: Array<{ icon: LucideIcon; title: string; body: string }> = [
  {
    icon: ClipboardCheck,
    title: "Pre-D Workbench",
    body: "Submission readiness in one view",
  },
  {
    icon: ShieldCheck,
    title: "Coverage Intelligence",
    body: "181 CDT codes × 6 payers × 7 states",
  },
  {
    icon: FileText,
    title: "Clinical Evidence",
    body: "PA X-ray to ADA citation, automatically",
  },
  {
    icon: Receipt,
    title: "Revenue Operations",
    body: "Conditions, appeals, collections",
  },
  {
    icon: BarChart3,
    title: "DSO Intelligence",
    body: "Denial patterns across every location",
  },
];

const LINKS = [
  { label: "Pricing", href: "#pricing" },
  { label: "Docs", href: "#faq" },
  { label: "Blog", href: "#faq" },
];

/**
 * Sticky top nav, 52px.
 *
 * The mobile sheet closes on navigation. Without that, tapping an
 * anchor scrolls the page underneath a menu that is still covering it,
 * which reads as a broken link rather than a working one.
 */
export default function Nav() {
  const [open, setOpen] = useState(false);
  const [productsOpen, setProductsOpen] = useState(false);
  const productsRef = useRef<HTMLDivElement>(null);
  const modal = useDemoModal();

  /**
   * Click-to-open, not hover.
   *
   * A hover menu is unreachable on the touch devices this is designed
   * for, and on a desktop it opens itself when the pointer crosses on
   * the way to "Request a demo". Click means the menu only ever appears
   * because someone asked for it.
   *
   * `mousedown` rather than `click` so the menu is gone before the
   * underlying element reacts; the ref check keeps a click INSIDE the
   * panel from closing it on the way to a link.
   */
  useEffect(() => {
    if (!productsOpen) return;
    const onDown = (e: MouseEvent) => {
      if (!productsRef.current?.contains(e.target as Node)) {
        setProductsOpen(false);
      }
    };
    const onKey = (e: KeyboardEvent) =>
      e.key === "Escape" && setProductsOpen(false);
    document.addEventListener("mousedown", onDown);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onDown);
      document.removeEventListener("keydown", onKey);
    };
  }, [productsOpen]);

  // Escape closes, and body scroll is locked while the sheet is open so
  // the page behind does not slide under the user's thumb.
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setOpen(false);
    document.addEventListener("keydown", onKey);
    const previous = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = previous;
    };
  }, [open]);

  return (
    <header className="sticky top-0 z-50 border-b border-gray-200 bg-white/95 backdrop-blur">
      <Container>
        <div className="flex h-[52px] items-center justify-between">
          {/* Home, not #top. The mark is the way back to accorddental.io
              from anywhere, and an in-page anchor only works on the one
              page that has a #top. */}
          <Link to="/" className="flex items-center" aria-label="Accord home">
            <Logo size={32} />
          </Link>

          <nav className="hidden items-center gap-7 lg:flex">
            <div className="relative" ref={productsRef}>
              <button
                type="button"
                onClick={() => setProductsOpen((v) => !v)}
                aria-expanded={productsOpen}
                aria-haspopup="true"
                className="flex items-center gap-1 text-[13.5px] font-medium text-gray-600 transition hover:text-gray-900"
              >
                Products
                <ChevronDown
                  size={14}
                  className={`transition-transform ${
                    productsOpen ? "rotate-180" : ""
                  }`}
                />
              </button>

              {productsOpen && (
                <div className="absolute left-0 top-full z-50 mt-2 w-[340px] overflow-hidden rounded-xl border border-gray-200 bg-white p-1.5 shadow-lg">
                  {PRODUCTS.map((p) => {
                    const Icon = p.icon;
                    return (
                      <a
                        key={p.title}
                        href="#products"
                        onClick={() => setProductsOpen(false)}
                        className="flex gap-3 rounded-lg px-3 py-2.5 transition hover:bg-gray-50"
                      >
                        <span className="mt-0.5 flex h-7 w-7 flex-shrink-0 items-center justify-center rounded-lg bg-accord-green-50 text-accord-green-700">
                          <Icon size={15} />
                        </span>
                        <span>
                          <span className="block text-[13.5px] font-semibold text-gray-900">
                            {p.title}
                          </span>
                          <span className="mt-0.5 block text-[12px] leading-snug text-gray-500">
                            {p.body}
                          </span>
                        </span>
                      </a>
                    );
                  })}
                </div>
              )}
            </div>

            {LINKS.map((l) => (
              <a
                key={l.label}
                href={l.href}
                className="text-[13.5px] font-medium text-gray-600 transition hover:text-gray-900"
              >
                {l.label}
              </a>
            ))}
          </nav>

          <div className="hidden items-center gap-2 lg:flex">
            <Link
              to="/login"
              className="rounded-lg px-3.5 py-2 text-[13.5px] font-medium text-gray-600 transition hover:bg-gray-50 hover:text-gray-900"
            >
              Log in
            </Link>
            <PrimaryButton
              onClick={modal.open}
              className="px-4 py-2 text-[13.5px]"
            >
              Request a demo
            </PrimaryButton>
          </div>

          <button
            type="button"
            onClick={() => setOpen((v) => !v)}
            aria-label={open ? "Close menu" : "Open menu"}
            aria-expanded={open}
            className="-mr-2 rounded-lg p-2 text-gray-600 hover:bg-gray-50 lg:hidden"
          >
            {open ? <X size={20} /> : <Menu size={20} />}
          </button>
        </div>
      </Container>

      {/* Full-screen overlay rather than a dropdown: a sheet that only
          covers the top third leaves the page scrolling behind it, which
          reads as a stuck menu. inset-0 below the 52px bar. */}
      {open && (
        <div className="fixed inset-x-0 bottom-0 top-[52px] z-40 overflow-y-auto bg-white lg:hidden">
          <Container className="py-4">
            <nav className="flex flex-col gap-1">
              {/* Flattened, not a nested dropdown — a disclosure inside a
                  sheet is two taps to reach one anchor. */}
              <a
                href="#products"
                onClick={() => setOpen(false)}
                className="flex min-h-[48px] items-center rounded-lg px-3 text-[15px] font-medium text-gray-700 hover:bg-gray-50"
              >
                Products
              </a>
              {PRODUCTS.map((p) => (
                <a
                  key={p.title}
                  href="#products"
                  onClick={() => setOpen(false)}
                  className="flex min-h-[44px] items-center rounded-lg pl-6 pr-3 text-[13.5px] text-gray-500 hover:bg-gray-50"
                >
                  {p.title}
                </a>
              ))}
              {LINKS.map((l) => (
                <a
                  key={l.label}
                  href={l.href}
                  onClick={() => setOpen(false)}
                  className="flex min-h-[48px] items-center rounded-lg px-3 text-[15px] font-medium text-gray-700 hover:bg-gray-50"
                >
                  {l.label}
                </a>
              ))}
              <Link
                to="/login"
                onClick={() => setOpen(false)}
                className="flex min-h-[48px] items-center rounded-lg px-3 text-[15px] font-medium text-gray-700 hover:bg-gray-50"
              >
                Log in
              </Link>
              <PrimaryButton
                className="mt-3 min-h-[48px] w-full text-[15px]"
                onClick={() => {
                  setOpen(false);
                  modal.open();
                }}
              >
                Request a demo
              </PrimaryButton>
            </nav>
          </Container>
        </div>
      )}
    </header>
  );
}
