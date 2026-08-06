/**
 * C-03 — the signed-in chrome.
 *
 * Sidebar on desktop, bottom tab bar on mobile, 48px top bar on both.
 * Nav items come from NAV_FOR_ROLE, so a dentist and a DSO owner get
 * genuinely different products rather than the same page with things
 * hidden.
 *
 * Wraps every protected route via <Outlet />, which is what keeps the
 * shell from re-mounting (and re-fetching) on every navigation.
 */
import { Link, NavLink, Outlet, useLocation } from "react-router-dom";
import { LogOut } from "lucide-react";

import { ROLE_LABELS, useAuth } from "../context/AuthContext";
import { useDemoLink } from "../hooks/useDemo";
import { NAV_FOR_ROLE, titleForPath, type NavItem } from "../routes";
import DemoBanner from "./DemoBanner";
import { Logo } from "./lp/primitives";

/** Active when the pathname matches, ignoring any query string —
 *  several nav items differ only by `?filter=`, and comparing the full
 *  string would light up none of them. */
function isActive(item: NavItem, pathname: string) {
  const base = item.to.split("?")[0];
  if (base === "/workbench") return pathname === "/workbench";
  return pathname === base || pathname.startsWith(`${base}/`);
}

function initials(role: string, tenant: string) {
  const a = role.charAt(0).toUpperCase();
  const b = tenant.charAt(0).toUpperCase();
  return `${a}${b}`;
}

export default function AppShell() {
  const { role, tenantId, isDemo, signOut } = useAuth();
  const { pathname } = useLocation();
  const demoLink = useDemoLink();

  const items = role ? NAV_FOR_ROLE[role] : [];
  const title = titleForPath(pathname);

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="flex">
        {/* ── Sidebar (desktop) ───────────────────────────────── */}
        <aside className="fixed inset-y-0 left-0 hidden w-[200px] flex-col border-r border-gray-200 bg-white lg:flex">
          <div className="flex h-[52px] items-center border-b border-gray-200 px-4">
            <Link to={demoLink("/")}>
              <Logo />
            </Link>
          </div>

          <nav className="flex-1 space-y-0.5 overflow-y-auto p-3">
            {items.map((item) => {
              const active = isActive(item, pathname);
              const Icon = item.icon;
              return (
                <NavLink
                  key={item.label}
                  to={demoLink(item.to)}
                  className={`flex items-center gap-2.5 rounded-lg px-2.5 py-2 text-[13px] transition ${
                    active
                      ? "bg-accord-green-50 font-medium text-accord-green-900"
                      : "text-gray-600 hover:bg-gray-50 hover:text-gray-900"
                  }`}
                >
                  <Icon size={16} className="flex-shrink-0" />
                  <span className="truncate">{item.label}</span>
                </NavLink>
              );
            })}
          </nav>

          <div className="border-t border-gray-200 p-3">
            <div className="flex items-center gap-2.5">
              <span className="flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-full bg-accord-green-900 text-[11px] font-semibold text-white">
                {initials(role ?? "?", tenantId ?? "?")}
              </span>
              <div className="min-w-0 flex-1">
                <p className="truncate text-[12.5px] font-medium text-gray-900">
                  {role ? ROLE_LABELS[role] : "Signed out"}
                </p>
                <p className="truncate text-[11px] text-gray-500">
                  {(tenantId ?? "").replace(/_/g, " ")}
                </p>
              </div>
              {!isDemo && (
                <button
                  type="button"
                  onClick={signOut}
                  aria-label="Sign out"
                  className="rounded p-1 text-gray-400 hover:bg-gray-100 hover:text-gray-600"
                >
                  <LogOut size={14} />
                </button>
              )}
            </div>
          </div>
        </aside>

        {/* ── Content ─────────────────────────────────────────── */}
        <div className="min-w-0 flex-1 lg:ml-[200px]">
          <DemoBanner />

          <header className="sticky top-0 z-30 flex min-h-[48px] items-center justify-between gap-3 border-b border-gray-200 bg-white px-4 py-2 sm:px-6">
            <h1 className="truncate text-[14px] font-semibold text-gray-900">
              {title}
            </h1>
            <div className="flex items-center gap-2">
              <span className="hidden rounded-full border border-gray-200 bg-gray-50 px-2.5 py-1 text-[11px] font-medium text-gray-600 sm:inline">
                {(tenantId ?? "").replace(/_/g, " ")}
              </span>
              <Link
                to={demoLink("/workbench")}
                className="rounded-lg bg-accord-green-900 px-3 py-1.5 text-[12.5px] font-medium text-white transition hover:bg-accord-green-700"
              >
                New pre-D
              </Link>
            </div>
          </header>

          {/* Clears the 60px tab bar plus the iOS home indicator, so
              the last row of a table is never under the user's thumb. */}
          <main className="pb-[calc(60px+env(safe-area-inset-bottom))] lg:pb-0">
            <Outlet />
          </main>
        </div>
      </div>

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
