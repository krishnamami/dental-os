/**
 * C-03 — the signed-in chrome.
 *
 * One header bar, full-width content. The left sidebar is gone for
 * every role; a horizontal product bar replaces it.
 *
 * ⚠ DESKTOP HAS NO PRODUCT NAVIGATION UNTIL THAT BAR LANDS. A dentist
 * holds five products and can currently reach four of them only by
 * typing the URL. The mobile tab bar below is kept for exactly that
 * reason — removing it too would leave the app with no way to move
 * between products at all.
 *
 * Wraps every protected route via <Outlet />, which is what keeps the
 * shell from re-mounting (and re-fetching) on every navigation.
 */
import { Link, NavLink, Outlet, useLocation, useNavigate } from "react-router-dom";
import { Eye } from "lucide-react";

import { ROLE_LABELS, useAuth } from "../context/AuthContext";
import { useDemoLink } from "../hooks/useDemo";
import { WORKFLOW_NAV, type NavItem } from "../routes";
import DemoBanner from "./DemoBanner";
import { AccordLogo } from "./AccordLogo";

/** Active when the pathname matches, ignoring any query string —
 *  several nav items differ only by `?filter=`, and comparing the full
 *  string would light up none of them. */
function isActive(item: NavItem, pathname: string) {
  const base = item.to.split("?")[0];
  if (base === "/workbench") return pathname === "/workbench";
  return pathname === base || pathname.startsWith(`${base}/`);
}

/** Initials from a person's name — "Dr. Sridhar Chinta" -> "SC".
 *  Titles are dropped: a row of "DS" tells you nothing. */
function initials(name: string): string {
  const parts = name
    .replace(/^(Dr|Mr|Mrs|Ms)\.?\s+/i, "")
    .split(/\s+/)
    .filter(Boolean);
  if (parts.length === 0) return "?";
  return (parts[0][0] + (parts[1]?.[0] ?? "")).toUpperCase();
}

export default function AppShell() {
  const {
    role,
    isDemo,
    effectiveUser,
    viewAs,
    navOrder,
    stopImpersonating,
    logout,
  } = useAuth();
  const { pathname } = useLocation();
  const navigate = useNavigate();
  const demoLink = useDemoLink();

  // Still the role's own list, still in the role's own order — it just
  // has one place left to render, the mobile tab bar.
  const items: NavItem[] = navOrder
    .map((gate) => WORKFLOW_NAV.find((w) => w.gate === gate))
    .filter((w): w is NavItem => Boolean(w));
  const tenantName = effectiveUser?.tenant_name ?? "Accord Dental";

  function signOutAndLeave() {
    logout();
    navigate("/login", { replace: true });
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <DemoBanner />

      <header className="sticky top-0 z-30 flex min-h-[52px] items-center justify-between gap-3 border-b border-gray-200 bg-white px-4 py-2 sm:px-6">
        <Link to={demoLink("/")} className="flex min-w-0 flex-col">
          <AccordLogo size={24} />
          <span className="mt-0.5 truncate text-[10px] text-slate-400">
            {tenantName}
          </span>
        </Link>

        <div className="flex flex-shrink-0 items-center gap-2">
          <span className="hidden text-sm text-slate-500 sm:inline">
            {effectiveUser?.name}
            {role ? ` · ${ROLE_LABELS[role]}` : ""}
          </span>
          {!isDemo && (
            <button
              type="button"
              onClick={signOutAndLeave}
              className="rounded-lg border border-slate-200 px-3 py-1 text-sm text-slate-500 transition hover:bg-slate-50"
            >
              Sign out
            </button>
          )}
          <span className="flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-full bg-green-100 text-[11px] font-semibold text-green-700">
            {initials(effectiveUser?.name ?? "?")}
          </span>
        </div>
      </header>

      {/* Was in the sidebar. It does NOT go with it — "you are looking
          at someone else's data" is the one banner that must survive a
          layout change, and it is now full-width instead of tucked in
          a corner. */}
      {viewAs && (
        <div className="flex flex-wrap items-center gap-x-2 gap-y-1 border-b border-amber-200 bg-amber-50 px-4 py-2 sm:px-6">
          <p className="flex items-center gap-1.5 text-[12px] font-medium text-amber-900">
            <Eye size={13} />
            Viewing as {viewAs.name}
            {role ? ` · ${ROLE_LABELS[role]}` : ""}
          </p>
          <span className="text-[11px] text-amber-600">{tenantName}</span>
          <button
            type="button"
            onClick={() => void stopImpersonating()}
            className="ml-auto rounded-lg border border-amber-300 px-2.5 py-1 text-[11.5px] font-medium text-amber-800 transition hover:bg-amber-100"
          >
            Stop impersonating
          </button>
        </div>
      )}

      {/* Full width. No sidebar to clear, so no left margin. The bottom
          padding still clears the mobile tab bar plus the iOS home
          indicator, so the last row of a table is never under a thumb. */}
      <main className="pb-[calc(60px+env(safe-area-inset-bottom))] lg:pb-0">
        <Outlet />
      </main>

      {/* ── Bottom tabs (mobile) ──────────────────────────────── */}
      <nav
        aria-label="Primary"
        className="fixed inset-x-0 bottom-0 z-40 border-t border-gray-200 bg-white pb-[env(safe-area-inset-bottom)] lg:hidden"
      >
        <div className="flex">
          {items.slice(0, 5).map((item) => {
            const active = isActive(item, pathname);
            const Icon = item.icon;
            return (
              <NavLink
                key={item.label}
                to={demoLink(item.to)}
                // 60px tall: Apple's 44px minimum plus the label. A tab
                // a thumb misses is worse than no tab.
                className={`flex h-[60px] flex-1 flex-col items-center justify-center gap-1 text-[9px] ${
                  active ? "text-accord-green-900" : "text-gray-500"
                }`}
              >
                <Icon size={20} />
                <span className="max-w-full truncate px-0.5 leading-tight">
                  {item.label.split(" ")[0]}
                </span>
              </NavLink>
            );
          })}
        </div>
      </nav>
    </div>
  );
}
