import { useEffect, useRef, useState } from "react";
import { Link, useLocation } from "react-router-dom";
import { ChevronDown, Menu, X } from "lucide-react";

import { AccordLogo } from "../AccordLogo";
import { useDemoModal } from "../../hooks/useDemoModal";
import { Container } from "./primitives";

/**
 * The dropdown's two columns.
 *
 * PRODUCTS mirrors Products.tsx one for one — five entries, same names,
 * same order. PLATFORM is what the five run on, so it points at the
 * sections that explain the machinery rather than at demo routes.
 *
 * Every href is an in-page anchor. Someone browsing the menu is still
 * working out what this is; dropping them into a live workbench skips
 * the part where they find out why they want one. The Products section
 * cards are what launch the demos.
 */
const MENU: Array<{
  heading: string;
  items: Array<{ title: string; body: string; href: string }>;
}> = [
  {
    heading: "Products",
    items: [
      {
        title: "Pre-D Workbench",
        body: "Submission readiness before you click submit",
        href: "#products",
      },
      {
        title: "Coverage Intelligence",
        body: "Replace the 15-minute payer phone call",
        href: "#products",
      },
      {
        title: "Clinical Evidence",
        body: "From PA X-ray to ADA citation automatically",
        href: "#products",
      },
      {
        title: "Revenue Operations",
        body: "Submissions, appeals, collections. One view.",
        href: "#products",
      },
      {
        title: "DSO Intelligence",
        body: "Denial patterns across every location",
        href: "#products",
      },
    ],
  },
  {
    heading: "Platform",
    items: [
      {
        title: "Decision Engine",
        body: "Policy rules + ADA guidelines + payer overlay",
        href: "#how-it-works",
      },
      {
        title: "AI Personas",
        body: "9 agents trained on dental pre-D rules",
        href: "#how-it-works",
      },
      {
        title: "Multi-tenant",
        body: "GA, FL, TX — 6 payers, 7 states",
        href: "#see-it",
      },
      {
        title: "Docs",
        body: "Get started in under 30 minutes",
        href: "#faq",
      },
    ],
  },
];

const LINKS = [
  { label: "Pricing", href: "#pricing" },
  { label: "Docs", href: "#faq" },
  { label: "Blog", href: "#faq" },
];

/**
 * Sticky top nav, 52px, dark navy — the accordlend treatment.
 *
 * The mobile sheet closes on navigation. Without that, tapping an
 * anchor scrolls the page underneath a menu that is still covering it,
 * which reads as a broken link rather than a working one.
 */
export default function Nav() {
  const [open, setOpen] = useState(false);
  const [productsOpen, setProductsOpen] = useState(false);
  const headerRef = useRef<HTMLElement>(null);
  const modal = useDemoModal();
  const { pathname } = useLocation();

  // Escape closes the mobile sheet, and body scroll is locked while it
  // is open so the page behind does not slide under the user's thumb.
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

  /**
   * Click-to-open, not hover.
   *
   * A hover menu is unreachable on the touch devices this is designed
   * for, and on a desktop it opens itself when the pointer crosses on
   * the way to "Request a demo". Click means the panel only appears
   * because someone asked for it.
   *
   * The outside-click test is against the whole header, not the panel:
   * the panel is full-width and sits below the bar, so anything
   * "outside" it includes the trigger that opened it — testing the
   * panel alone makes the trigger close and reopen in one click.
   */
  useEffect(() => {
    if (!productsOpen) return;
    const onDown = (e: MouseEvent) => {
      if (!headerRef.current?.contains(e.target as Node)) {
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

  // Route change closes both. A menu that survives navigation hangs
  // over the new page with the old page's options.
  useEffect(() => {
    setProductsOpen(false);
    setOpen(false);
  }, [pathname]);

  const navLink =
    "text-sm font-medium text-white/80 transition hover:text-white";

  return (
    <header
      ref={headerRef}
      className="sticky top-0 z-50 border-b border-white/[0.08] bg-[#0B1220]"
    >
      <Container>
        <div className="flex h-[52px] items-center justify-between">
          <div className="flex items-center">
            {/* Home, not #top. The mark is the way back to the top level
                from anywhere, and an in-page anchor only works on the
                one page that has a #top. */}
            <Link to="/" className="flex items-center" aria-label="Accord home">
              <AccordLogo dark />
            </Link>

            <nav className="ml-8 hidden items-center gap-6 lg:flex">
              <button
                type="button"
                onClick={() => setProductsOpen((v) => !v)}
                aria-expanded={productsOpen}
                aria-haspopup="true"
                className={`flex items-center gap-1 ${navLink}`}
              >
                Products
                <ChevronDown
                  size={14}
                  className={`transition-transform ${
                    productsOpen ? "rotate-180" : ""
                  }`}
                />
              </button>
              {LINKS.map((l) => (
                <a key={l.label} href={l.href} className={navLink}>
                  {l.label}
                </a>
              ))}
            </nav>
          </div>

          <div className="hidden items-center gap-2 lg:flex">
            <Link
              to="/login"
              className="rounded-lg px-3.5 py-2 text-sm font-medium text-white/80 transition hover:bg-white/5 hover:text-white"
            >
              Log in
            </Link>
            <button
              type="button"
              onClick={modal.open}
              className="rounded-lg bg-[#1B5E20] px-4 py-2 text-sm font-semibold text-white transition hover:bg-[#154d19]"
            >
              Request a demo
            </button>
          </div>

          <button
            type="button"
            onClick={() => setOpen((v) => !v)}
            aria-label={open ? "Close menu" : "Open menu"}
            aria-expanded={open}
            className="-mr-2 rounded-lg p-2 text-white transition hover:bg-white/5 lg:hidden"
          >
            {open ? <X size={20} /> : <Menu size={20} />}
          </button>
        </div>
      </Container>

      {/* Products panel — full-width white card below the bar. White on
          the dark nav so it reads as a surface rather than more chrome,
          and full-width because two columns of nine entries do not fit
          a dropdown anchored to one word. */}
      {productsOpen && (
        <div className="absolute inset-x-0 top-[52px] hidden border-b border-gray-200 bg-white shadow-lg lg:block">
          <Container className="grid grid-cols-2 gap-x-10 py-7">
            {MENU.map((col) => (
              <div key={col.heading}>
                <p className="mb-3 px-3 text-[11px] font-bold uppercase tracking-[0.14em] text-gray-400">
                  {col.heading}
                </p>
                {col.items.map((item) => (
                  <a
                    key={item.title}
                    href={item.href}
                    onClick={() => setProductsOpen(false)}
                    className="block rounded-lg px-3 py-2.5 transition hover:bg-gray-50"
                  >
                    <span className="block text-[14px] font-semibold text-slate-900">
                      {item.title}
                    </span>
                    <span className="mt-0.5 block text-[12.5px] leading-snug text-gray-500">
                      {item.body}
                    </span>
                  </a>
                ))}
              </div>
            ))}
          </Container>
        </div>
      )}

      {/* Full-screen overlay rather than a dropdown: a sheet that only
          covers the top third leaves the page scrolling behind it, which
          reads as a stuck menu. inset-0 below the 52px bar. */}
      {open && (
        <div className="fixed inset-x-0 bottom-0 top-[52px] z-40 overflow-y-auto bg-[#0B1220] lg:hidden">
          <Container className="py-4">
            <nav className="flex flex-col gap-1">
              {/* Flattened, not a nested disclosure — a dropdown inside a
                  sheet is two taps to reach one anchor. */}
              {MENU.map((col) => (
                <div key={col.heading} className="mb-2">
                  <p className="px-3 py-2 text-[11px] font-bold uppercase tracking-[0.14em] text-white/40">
                    {col.heading}
                  </p>
                  {col.items.map((item) => (
                    <a
                      key={item.title}
                      href={item.href}
                      onClick={() => setOpen(false)}
                      className="flex min-h-[44px] items-center rounded-lg px-3 text-[15px] font-medium text-white/80 hover:bg-white/5"
                    >
                      {item.title}
                    </a>
                  ))}
                </div>
              ))}

              {LINKS.map((l) => (
                <a
                  key={l.label}
                  href={l.href}
                  onClick={() => setOpen(false)}
                  className="flex min-h-[48px] items-center rounded-lg px-3 text-[15px] font-medium text-white/80 hover:bg-white/5"
                >
                  {l.label}
                </a>
              ))}
              <Link
                to="/login"
                onClick={() => setOpen(false)}
                className="flex min-h-[48px] items-center rounded-lg px-3 text-[15px] font-medium text-white/80 hover:bg-white/5"
              >
                Log in
              </Link>
              <button
                type="button"
                className="mt-3 min-h-[48px] w-full rounded-lg bg-[#1B5E20] px-5 text-[15px] font-semibold text-white transition hover:bg-[#154d19]"
                onClick={() => {
                  setOpen(false);
                  modal.open();
                }}
              >
                Request a demo
              </button>
            </nav>
          </Container>
        </div>
      )}
    </header>
  );
}
