import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { Menu, X } from "lucide-react";

import { useDemoModal } from "../../hooks/useDemoModal";
import { Container, Logo, PrimaryButton } from "./primitives";

const LINKS = [
  { label: "Products", href: "#products" },
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
  const modal = useDemoModal();

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
          <a href="#top" className="flex items-center">
            <Logo />
          </a>

          <nav className="hidden items-center gap-7 md:flex">
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

          <div className="hidden items-center gap-2 md:flex">
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
            className="-mr-2 rounded-lg p-2 text-gray-600 hover:bg-gray-50 md:hidden"
          >
            {open ? <X size={20} /> : <Menu size={20} />}
          </button>
        </div>
      </Container>

      {open && (
        <div className="border-t border-gray-200 bg-white md:hidden">
          <Container className="py-3">
            <nav className="flex flex-col">
              {LINKS.map((l) => (
                <a
                  key={l.label}
                  href={l.href}
                  onClick={() => setOpen(false)}
                  className="rounded-lg px-2 py-2.5 text-sm font-medium text-gray-700 hover:bg-gray-50"
                >
                  {l.label}
                </a>
              ))}
              <Link
                to="/login"
                onClick={() => setOpen(false)}
                className="rounded-lg px-2 py-2.5 text-sm font-medium text-gray-700 hover:bg-gray-50"
              >
                Log in
              </Link>
              <PrimaryButton
                className="mt-2 w-full"
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
