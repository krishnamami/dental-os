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
import Placeholder from "./components/Placeholder";
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

          <Route path="/revenue-ops" element={<RevenueOps />} />
          <Route
            path="/revenue-ops/conditions"
            element={
              <Placeholder
                title="Conditions"
                description="Every open condition across the practice, grouped by assignee and SLA."
                endpoint="GET /decisions/{id}/conditions"
                audience="Revenue operations"
              />
            }
          />
          <Route
            path="/revenue-ops/appeals"
            element={
              <Placeholder
                title="Appeals"
                description="Denials worth appealing, with viability, deadline and a draft packet."
                endpoint="GET /decisions/{id}/appeal"
                audience="Revenue operations"
              />
            }
          />

          <Route path="/dso" element={<DSOIntelligence />} />
          <Route
            path="/dso/denials"
            element={
              <Placeholder
                title="Denial patterns"
                description="The conditions driving denials across every practice in the group."
                endpoint="GET /portfolio/summary"
                audience="DSO owner"
              />
            }
          />
          <Route
            path="/dso/revenue"
            element={
              <Placeholder
                title="Revenue"
                description="Contracted, insurance and patient responsibility per location."
                endpoint="GET /portfolio/summary"
                audience="DSO owner"
              />
            }
          />
          <Route
            path="/dso/training"
            element={
              <Placeholder
                title="Training"
                description="Where documentation habits cost the most, by practice."
                endpoint="GET /portfolio/summary"
                audience="DSO owner"
              />
            }
          />
        </Route>
      </Route>

      {/* Admin is the one role-gated branch. The guard is usability, not
          security — see ProtectedRoute. */}
      <Route element={<ProtectedRoute allow={["accord_admin"]} />}>
        <Route element={<AppShell />}>
          <Route path="/admin" element={<AdminConsole />} />
          <Route
            path="/admin/onboard"
            element={
              <Placeholder
                title="Onboard tenant"
                description="Add a practice: payers, providers, fee schedule state and overlay rules."
                audience="Accord admin"
              />
            }
          />
          <Route
            path="/admin/catalogue"
            element={
              <Placeholder
                title="Catalogue"
                description="Catalogue versions and row counts — which rules decided a case, and were they current."
                endpoint="GET /health"
                audience="Accord admin"
              />
            }
          />
          <Route
            path="/admin/health"
            element={
              <Placeholder
                title="System health"
                description="Both databases, tenant count, scenario count, payers and states."
                endpoint="GET /health"
                audience="Accord admin"
              />
            }
          />
        </Route>
      </Route>

      <Route path="*" element={<NotFound />} />
    </Routes>
  );
}
