/**
 * Route map.
 *
 * `?demo=true` is not a route — it is a query flag that AuthContext
 * reads to grant a dentist-role session at suwanee_smiles. That is why
 * the protected routes below need no demo-specific branch: in demo mode
 * `isAuthenticated` is simply true. See hooks/useDemo.ts.
 */
import { Route, Routes } from "react-router-dom";

import ProtectedRoute from "./components/ProtectedRoute";
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

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<LandingPage />} />
      <Route path="/login" element={<Login />} />

      <Route element={<ProtectedRoute />}>
        <Route path="/workbench" element={<WorkbenchQueue />} />
        <Route path="/workbench/:id" element={<WorkbenchDetail />} />
        <Route path="/coverage" element={<CoverageIntelligence />} />
        <Route path="/evidence/:id" element={<ClinicalEvidence />} />
        <Route path="/revenue-ops" element={<RevenueOps />} />
        <Route path="/dso" element={<DSOIntelligence />} />
      </Route>

      {/* Admin is the one role-gated route. The guard is usability, not
          security — see ProtectedRoute. */}
      <Route element={<ProtectedRoute allow={["accord_admin"]} />}>
        <Route path="/admin" element={<AdminConsole />} />
      </Route>

      <Route path="*" element={<NotFound />} />
    </Routes>
  );
}
