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
import { Navigate, Route, Routes } from "react-router-dom";

import AppShell from "./components/AppShell";
import ProtectedRoute from "./components/ProtectedRoute";
import { useAuth } from "./context/AuthContext";
import { HOME_FOR_ROLE } from "./routes";
import AdminConsole from "./pages/app/admin/AdminConsole";
import CoverageIntelligence from "./pages/app/coverage/CoverageIntelligence";
import DSOIntelligence from "./pages/app/dso/DSOIntelligence";
import ClinicalEvidence from "./pages/app/evidence/ClinicalEvidence";
import RevenueOps from "./pages/app/revenue-ops/RevenueOps";
import WorkbenchDetail from "./pages/app/workbench/WorkbenchDetail";
import WorkbenchQueue from "./pages/app/workbench/WorkbenchQueue";
import LandingPage from "./pages/lp/LandingPage";
import Login from "./pages/Login";
import NotFound from "./pages/NotFound";

/** C-02 — send a signed-in user to the page their role starts on. */
function RoleHome() {
  const { role } = useAuth();
  return <Navigate to={role ? HOME_FOR_ROLE[role] : "/workbench"} replace />;
}

export default function App() {
  return (
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
  );
}
