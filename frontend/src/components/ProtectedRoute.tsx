import { Navigate, Outlet, useLocation } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import type { Role } from "../types/dental";

interface Props {
  allow?: Role[];
}

export default function ProtectedRoute({ allow }: Props) {
  const { isAuthenticated, role, isLoading } = useAuth();
  const location = useLocation();

  if (isLoading) return null;

  if (!isAuthenticated) {
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
          This page is limited to {allow.join(", ")}. You are signed in
          as <span className="font-medium">{role}</span>.
        </p>
      </div>
    );
  }

  return <Outlet />;
}
