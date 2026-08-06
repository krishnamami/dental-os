/**
 * Route map.
 *
 * `?demo=true` is not a route — it is a query flag AuthContext reads to
 * grant a dentist session at suwanee_smiles, which is why the protected
 * routes need no demo-specific branch: in demo mode `isAuthenticated`
 * is simply true. See hooks/useDemo.ts.
 *
 * Every signed-in route renders inside <AppShell />, so the sidebar and
 * top bar do not remount (or refetch) on navigation.
 */
import { Suspense, lazy } from "react";
import { Navigate, Route, Routes } from "react-router-dom";

import AppShell from "./components/AppShell";
import ProtectedRoute from "./components/ProtectedRoute";
import { useAuth } from "./context/AuthContext";
import { HOME_FOR_ROLE } from "./routes";

/**
 * Every page is lazy, INCLUDING the landing page.
 *
 * Splitting only the app routes would still ship the landing page to a
 * signed-in user who never sees it. Splitting both means each visitor
 * downloads the framework, this route table, and the one page they
 * asked for.
 *
 * AppShell and ProtectedRoute stay eager on purpose: they ARE the route
 * tree. Lazying a layout puts a second network round trip in front of
 * every child route rather than loading the two in parallel.
 */
const LandingPage = lazy(() => import("./pages/lp/LandingPage"));
const Login = lazy(() => import("./pages/Login"));
const WorkbenchQueue = lazy(
  () => import("./pages/app/workbench/WorkbenchQueue"),
);
const WorkbenchDetail = lazy(
  () => import("./pages/app/workbench/WorkbenchDetail"),
);
const CoverageIntelligence = lazy(
  () => import("./pages/app/coverage/CoverageIntelligence"),
);
const ClinicalEvidence = lazy(
  () => import("./pages/app/evidence/ClinicalEvidence"),
);
const RevenueOps = lazy(() => import("./pages/app/revenue-ops/RevenueOps"));
const DSOIntelligence = lazy(() => import("./pages/app/dso/DSOIntelligence"));
const AdminConsole = lazy(() => import("./pages/app/admin/AdminConsole"));
const NotFound = lazy(() => import("./pages/NotFound"));

/** Shown while a route chunk is in flight. Deliberately quiet — a
 *  spinner that appears for 40ms on a warm CDN reads as jank. */
function RouteFallback() {
  return (
    <div className="flex h-[200px] items-center justify-center text-[13px] text-gray-500">
      Loading…
    </div>
  );
}

/** C-02 — send a signed-in user to the page their role starts on. */
function RoleHome() {
  const { role } = useAuth();
  return <Navigate to={role ? HOME_FOR_ROLE[role] : "/workbench"} replace />;
}

export default function App() {
  return (
    <Suspense fallback={<RouteFallback />}>
      <Routes>
        <Route path="/" element={<LandingPage />} />
        <Route path="/login" element={<Login />} />

        <Route element={<ProtectedRoute />}>
          <Route element={<AppShell />}>
            <Route path="/app" element={<RoleHome />} />

            <Route path="/workbench" element={<WorkbenchQueue />} />
            <Route path="/workbench/:id" element={<WorkbenchDetail />} />

            <Route path="/coverage" element={<CoverageIntelligence />} />

            {/* Both forms exist: the sidebar links to /evidence, and the
              workbench links to a specific pre-D. */}
            <Route path="/evidence" element={<ClinicalEvidence />} />
            <Route path="/evidence/:id" element={<ClinicalEvidence />} />

            {/* One page, four tabs, tab chosen by the path — see
              RevenueOps.tabFromPath. */}
            <Route path="/revenue-ops" element={<RevenueOps />} />
            <Route path="/revenue-ops/conditions" element={<RevenueOps />} />
            <Route path="/revenue-ops/appeals" element={<RevenueOps />} />
            <Route path="/revenue-ops/analytics" element={<RevenueOps />} />

            {/* One page, four tabs, tab chosen by the path. */}
            <Route path="/dso" element={<DSOIntelligence />} />
            <Route path="/dso/denials" element={<DSOIntelligence />} />
            <Route path="/dso/revenue" element={<DSOIntelligence />} />
            <Route path="/dso/training" element={<DSOIntelligence />} />
          </Route>
        </Route>

        {/* Admin is the one role-gated branch. The guard is usability, not
          security — see ProtectedRoute. */}
        <Route element={<ProtectedRoute allow={["accord_admin"]} />}>
          <Route element={<AppShell />}>
            <Route path="/admin" element={<AdminConsole />} />
            <Route path="/admin/onboard" element={<AdminConsole />} />
            <Route path="/admin/catalogue" element={<AdminConsole />} />
            <Route path="/admin/health" element={<AdminConsole />} />
          </Route>
        </Route>

        <Route path="*" element={<NotFound />} />
      </Routes>
    </Suspense>
  );
}
