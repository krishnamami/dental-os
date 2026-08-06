/**
 * Shared building blocks for the landing sections.
 *
 * Mirrors the pattern in decision-os/frontend/src/components/landing —
 * one file of primitives so fourteen sections cannot drift apart on
 * type scale, container width or button shape.
 *
 * Colours come from Tailwind classes (`accord-green-900` etc.) rather
 * than an inline BRAND object, because tailwind.config.js already
 * defines the palette and a second source would be one too many.
 */
import type { ReactNode } from "react";

export function Container({
  children,
  className = "",
}: {
  children: ReactNode;
  className?: string;
}) {
  return (
    <div className={`mx-auto w-full max-w-[1200px] px-5 sm:px-6 ${className}`}>
      {children}
    </div>
  );
}

/** Small caps green label above a section title. */
export function Eyebrow({ children }: { children: ReactNode }) {
  return (
    <div className="mb-3 text-xs font-bold uppercase tracking-[0.14em] text-accord-green-900">
      {children}
    </div>
  );
}

export function H2({
  children,
  className = "",
}: {
  children: ReactNode;
  className?: string;
}) {
  return (
    <h2
      className={`text-[26px] font-semibold leading-[1.2] tracking-[-0.02em] text-gray-900 sm:text-[30px] ${className}`}
    >
      {children}
    </h2>
  );
}

export function Sub({
  children,
  className = "",
}: {
  children: ReactNode;
  className?: string;
}) {
  return (
    <p className={`text-[15px] leading-relaxed text-gray-500 sm:text-base ${className}`}>
      {children}
    </p>
  );
}

const BASE_BTN =
  "inline-flex items-center justify-center gap-2 rounded-lg px-5 py-2.5 text-sm font-semibold transition focus:outline-none focus-visible:ring-2 focus-visible:ring-accord-green-500 focus-visible:ring-offset-2";

export function PrimaryButton({
  children,
  href,
  onClick,
  type = "button",
  disabled,
  className = "",
}: {
  children: ReactNode;
  href?: string;
  onClick?: () => void;
  type?: "button" | "submit";
  disabled?: boolean;
  className?: string;
}) {
  const cls = `${BASE_BTN} bg-accord-green-900 text-white hover:bg-accord-green-700 disabled:cursor-not-allowed disabled:opacity-40 ${className}`;
  if (href) {
    // onClick still fires on the anchor — the mobile nav needs it to
    // close the sheet as the page scrolls to the target.
    return (
      <a href={href} onClick={onClick} className={cls}>
        {children}
      </a>
    );
  }
  return (
    <button type={type} onClick={onClick} disabled={disabled} className={cls}>
      {children}
    </button>
  );
}

export function GhostButton({
  children,
  href,
  onClick,
  className = "",
}: {
  children: ReactNode;
  href?: string;
  onClick?: () => void;
  className?: string;
}) {
  const cls = `${BASE_BTN} border border-accord-green-900 text-accord-green-900 hover:bg-accord-green-50 ${className}`;
  if (href) {
    return (
      <a href={href} className={cls}>
        {children}
      </a>
    );
  }
  return (
    <button type="button" onClick={onClick} className={cls}>
      {children}
    </button>
  );
}

/** Section wrapper — vertical rhythm in one place. */
export function Section({
  id,
  children,
  className = "",
}: {
  id?: string;
  children: ReactNode;
  className?: string;
}) {
  return (
    <section id={id} className={`py-16 sm:py-20 ${className}`}>
      {children}
    </section>
  );
}

export function Check({ children }: { children: ReactNode }) {
  return (
    <li className="flex gap-2.5 text-[13.5px] leading-relaxed text-gray-600">
      <svg
        viewBox="0 0 16 16"
        aria-hidden="true"
        className="mt-[3px] h-3.5 w-3.5 flex-shrink-0 text-accord-green-500"
      >
        <path
          fill="currentColor"
          d="M6.2 11.6 3 8.4l1.1-1.1 2.1 2.1 5.7-5.7L13 4.8z"
        />
      </svg>
      <span>{children}</span>
    </li>
  );
}
