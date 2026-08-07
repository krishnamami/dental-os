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
import { Suspense, lazy, type ReactNode } from "react";
import { Navigate, Outlet, Route, Routes } from "react-router-dom";

import AppShell from "./components/AppShell";
import ProtectedRoute from "./components/ProtectedRoute";
import { useAuth } from "./context/AuthContext";

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
const WorkbenchPipeline = lazy(
  () => import("./pages/app/workbench/WorkbenchPipeline"),
);
const WorkbenchDetail = lazy(
  () => import("./pages/app/workbench/WorkbenchDetail"),
);
const CoverageIntelligence = lazy(
  () => import("./pages/app/coverage/CoverageIntelligence"),
);
const CheckIn = lazy(
  () => import("./pages/app/coverage/CoverageIntelligence"),
);
const CoverageDetail = lazy(
  () => import("./pages/app/coverage/CoverageDetail"),
);
const ClinicalEvidence = lazy(
  () => import("./pages/app/evidence/ClinicalEvidence"),
);
const RevenueOps = lazy(() => import("./pages/app/revenue-ops/RevenueOps"));
const DSOIntelligence = lazy(() => import("./pages/app/dso/DSOIntelligence"));
const AdminConsole = lazy(() => import("./pages/app/admin/AdminConsole"));
const NotFound = lazy(() => import("./pages/NotFound"));

/**
 * Prefetch the workbench so demo mode has no loading flash.
 *
 * Kicked off at module evaluation, which is boot: by the time a visitor
 * clicks through from the landing page the chunk is already in the HTTP
 * cache and <Suspense> never suspends. On a cold /workbench?demo=true
 * it starts in parallel with the route's own import rather than after
 * it, so it costs nothing there either.
 *
 * The catch is not optional. This is a floating promise, and a chunk
 * that 404s — a stale index.html held by a browser mid-deploy is the
 * usual way — would otherwise surface as an unhandled rejection in
 * every visitor's console. There is nothing to do about it here: the
 * lazy() call will retry and fail visibly if the route is ever reached.
 *
 * Cost: 17 KB raw on every landing-page visit, including visitors who
 * never sign in. Worth it while the workbench IS the demo; revisit if
 * the landing page ever has to answer for its own byte budget.
 */
if (typeof window !== "undefined") {
  import("./pages/app/workbench/WorkbenchPipeline").catch(() => {});
}

/** C-02 — send a signed-in user to the page their role starts on. */
function RoleHome() {
  const { homeRoute } = useAuth();
  return <Navigate to={homeRoute} replace />;
}

/**
 * Redirect a role away from a product it does not hold.
 *
 * ⚠ USABILITY, NOT SECURITY. It stops a front-desk user landing on a
 * DSO page they cannot read; it stops nobody from calling the API
 * directly, because the API asks for no token yet. See AuthContext.
 *
 * Demo mode is a dentist, so it passes every gate a dentist holds and
 * needs no special case.
 */
function ProductRoute({
  product,
  children,
}: {
  product: string;
  children?: ReactNode;
}) {
  const { hasProduct, homeRoute } = useAuth();
  if (!hasProduct(product)) return <Navigate to={homeRoute} replace />;
  return <>{children ?? <Outlet />}</>;
}

// fallback={null}, not a spinner: with the prefetch above the workbench
// is already cached, and a placeholder that appears for 40ms on a warm
// CDN reads as jank. The trade is that a genuinely slow first load of
// some OTHER route shows nothing at all rather than a hint that
// something is happening.
export default function App() {
  return (
    <Suspense fallback={null}>
      <Routes>
        <Route path="/" element={<LandingPage />} />
        <Route path="/login" element={<Login />} />

        <Route element={<ProtectedRoute />}>
          <Route element={<AppShell />}>
            <Route path="/app" element={<RoleHome />} />

            <Route element={<ProductRoute product="workbench" />}>
              <Route path="/workbench" element={<WorkbenchPipeline />} />
              <Route path="/workbench/:id" element={<WorkbenchDetail />} />
            </Route>

            {/* /coverage/all is declared before /coverage/:id so the
                literal wins. React Router ranks static segments above
                dynamic ones anyway, but relying on that to keep "all"
                from being read as a pre-D id is a trap for whoever
                reorders these next. */}
            {/* Check-in and patient financial are two workflows over
                one component — the queue, then the money. Separate
                gates because a front desk holds the first and not the
                second half of the second. */}
            <Route element={<ProductRoute product="checkin" />}>
              <Route path="/checkin" element={<CheckIn />} />
            </Route>

            <Route element={<ProductRoute product="patient_financial" />}>
              <Route path="/coverage" element={<CoverageIntelligence />} />
              <Route path="/coverage/all" element={<CoverageIntelligence />} />
              <Route path="/coverage/:id" element={<CoverageDetail />} />
            </Route>

            {/* Both forms exist: the sidebar links to /evidence, and the
              workbench links to a specific pre-D. */}
            <Route element={<ProductRoute product="clinical" />}>
              <Route path="/evidence" element={<ClinicalEvidence />} />
              <Route path="/evidence/:id" element={<ClinicalEvidence />} />
            </Route>

            {/* One page, four tabs, tab chosen by the path — see
              RevenueOps.tabFromPath. */}
            <Route element={<ProductRoute product="revenue_ops" />}>
              <Route path="/revenue-ops" element={<RevenueOps />} />
              <Route path="/revenue-ops/conditions" element={<RevenueOps />} />
              <Route path="/revenue-ops/appeals" element={<RevenueOps />} />
              <Route path="/revenue-ops/analytics" element={<RevenueOps />} />
            </Route>

            {/* One page, four tabs, tab chosen by the path. */}
            <Route element={<ProductRoute product="portfolio" />}>
              <Route path="/dso" element={<DSOIntelligence />} />
              <Route path="/dso/denials" element={<DSOIntelligence />} />
              <Route path="/dso/revenue" element={<DSOIntelligence />} />
              <Route path="/dso/training" element={<DSOIntelligence />} />
            </Route>
          </Route>
        </Route>

        {/* Admin is the one role-gated branch. The guard is usability, not
          security — see ProtectedRoute. */}
        <Route element={<ProtectedRoute allow={["accord_admin"]} />}>
          <Route element={<ProductRoute product="admin" />}>
          <Route element={<AppShell />}>
            <Route path="/admin" element={<AdminConsole />} />
            <Route path="/admin/onboard" element={<AdminConsole />} />
            <Route path="/admin/catalogue" element={<AdminConsole />} />
            <Route path="/admin/health" element={<AdminConsole />} />
          </Route>
          </Route>
        </Route>

        <Route path="*" element={<NotFound />} />
      </Routes>
    </Suspense>
  );
}
