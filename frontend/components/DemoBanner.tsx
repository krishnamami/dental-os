/**
 * C-04 — demo mode banner.
 *
 * Renders nothing outside demo mode. Its job is to make the state
 * unmistakable: everything below it is one fixed scenario from the
 * simulator corpus, not this visitor's data.
 *
 * "Exit demo" strips the demo params rather than navigating home, so a
 * prospect who wants to sign in properly lands on the same page they
 * were reading — and ProtectedRoute then sends them to /login, which is
 * the honest outcome.
 */
import { Link, useLocation } from "react-router-dom";

import { DEMO_CASES, useDemo } from "../hooks/useDemo";

export default function DemoBanner() {
  const { isDemo, demoPredId, demoTenant } = useDemo();
  const { pathname } = useLocation();

  if (!isDemo) return null;

  const activeCase = DEMO_CASES.find((c) => c.predRequestId === demoPredId);
  const scenario = demoPredId.replace(/^PRED-SIM-/, "");

  return (
    <div className="border-b border-amber-200 bg-accord-amber-50">
      <div className="flex flex-wrap items-center gap-x-2 gap-y-1 px-4 py-2 text-[12.5px] text-accord-amber-900 sm:px-6">
        <span className="font-semibold">Demo mode</span>
        <span className="text-amber-700">—</span>
        <span>
          showing <span className="font-medium">{scenario}</span>
          {activeCase ? ` ${activeCase.label}` : ""}
        </span>
        <span className="text-amber-700">·</span>
        <span>{demoTenant.replace(/_/g, " ")}</span>
        <Link
          to={pathname}
          className="ml-auto rounded border border-amber-300 bg-white/70 px-2 py-0.5 font-medium hover:bg-white"
        >
          Exit demo
        </Link>
      </div>
    </div>
  );
}
