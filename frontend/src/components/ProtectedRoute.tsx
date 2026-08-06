/**
 * Route guard. USABILITY, NOT SECURITY — see AuthContext's header.
 *
 * It keeps a front-desk user from wandering into the admin console. It
 * does not stop anyone determined, because the check runs in the
 * browser. The API is what has to enforce role and tenant once real
 * patient data is served.
 */
import { Navigate, Outlet, useLocation } from "react-router-dom";

import { useAuth } from "../context/AuthContext";
import type { Role } from "../types/dental";

interface Props {
  /** When set, only these roles may enter. Omit to allow any signed-in
   *  user (demo mode included). */
  allow?: Role[];
}

export default function ProtectedRoute({ allow }: Props) {
  const { isAuthenticated, role } = useAuth();
  const location = useLocation();

  if (!isAuthenticated) {
    // Carry the attempted path so login can return the user to it, and
    // carry the query string so ?demo=true survives the round trip.
    return (
      <Navigate
        to="/login"
        replace
        state={{ from: `${location.pathname}${location.search}` }}
      />
    );
  }

  if (allow && role && !allow.includes(role)) {
    return (
      <div className="mx-auto max-w-3xl px-6 py-16">
        <h1 className="text-2xl font-semibold text-slate-900">
          Not available for this role
        </h1>
        <p className="mt-3 text-slate-600">
          This page is limited to {allow.join(", ")}. You are signed in as{" "}
          <span className="font-medium">{role}</span>.
        </p>
      </div>
    );
  }

  return <Outlet />;
}
