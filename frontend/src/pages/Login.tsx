/**
 * Role + practice selection.
 *
 * ⚠ NOT AUTHENTICATION. There is no password, no token and no server
 * check — picking a role here writes it to localStorage and the app
 * believes it. That is deliberate for a scaffold: the product pages
 * need a role to render against before an identity provider exists.
 *
 * Replacing this with real auth is a prerequisite for serving any
 * patient data, and the change is not only here — the API has to
 * enforce role and tenant on every request too.
 */
import { useState } from "react";
import { Link, useLocation, useNavigate } from "react-router-dom";

import { ROLES, ROLE_LABELS, useAuth } from "../context/AuthContext";
import { useDemoLink } from "../hooks/useDemo";
import type { Role } from "../types/dental";

const TENANTS = [
  { id: "suwanee_smiles", label: "Suwanee Smiles Dental — GA" },
  { id: "tampa_smiles", label: "Tampa Bay Smiles — FL" },
  { id: "dallas_dental", label: "Dallas Family Dental — TX" },
];

const LANDING_BY_ROLE: Record<Role, string> = {
  front_desk: "/workbench",
  revenue_ops: "/revenue-ops",
  dentist: "/workbench",
  dso_owner: "/dso",
  accord_admin: "/admin",
};

export default function Login() {
  const { signIn } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const demoLink = useDemoLink();

  const [role, setRole] = useState<Role>("dentist");
  const [tenantId, setTenantId] = useState(TENANTS[0].id);

  const from = (location.state as { from?: string } | null)?.from;

  function submit(event: React.FormEvent) {
    event.preventDefault();
    signIn(role, tenantId);
    navigate(from ?? LANDING_BY_ROLE[role], { replace: true });
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-slate-50 px-6">
      <div className="w-full max-w-md">
        <Link
          to={demoLink("/")}
          className="text-sm font-semibold text-accord-green-700"
        >
          Accord Dental
        </Link>
        <h1 className="mt-4 text-2xl font-semibold text-slate-900">Sign in</h1>

        <div className="mt-4 rounded-md border border-accord-amber-50 bg-accord-amber-50/60 p-3 text-xs text-accord-amber-900">
          <strong>Scaffold only.</strong> No password, no identity provider,
          no server-side check. Choosing a role here does not protect
          anything — it selects what the UI renders.
        </div>

        <form
          onSubmit={submit}
          className="mt-6 space-y-5 rounded-lg border border-slate-200 bg-white p-6 shadow-sm"
        >
          <div>
            <label
              htmlFor="role"
              className="block text-sm font-medium text-slate-700"
            >
              Role
            </label>
            <select
              id="role"
              value={role}
              onChange={(e) => setRole(e.target.value as Role)}
              className="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
            >
              {ROLES.map((r) => (
                <option key={r} value={r}>
                  {ROLE_LABELS[r]}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label
              htmlFor="tenant"
              className="block text-sm font-medium text-slate-700"
            >
              Practice
            </label>
            <select
              id="tenant"
              value={tenantId}
              onChange={(e) => setTenantId(e.target.value)}
              className="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
            >
              {TENANTS.map((t) => (
                <option key={t.id} value={t.id}>
                  {t.label}
                </option>
              ))}
            </select>
          </div>

          <button
            type="submit"
            className="w-full rounded-md bg-accord-green-700 px-4 py-2 text-sm font-medium text-white hover:bg-accord-green-900"
          >
            Continue
          </button>
        </form>

        <p className="mt-6 text-center text-sm text-slate-500">
          Just looking?{" "}
          <Link
            to="/?demo=true"
            className="font-medium text-accord-green-700 hover:text-accord-green-900"
          >
            Open the demo
          </Link>
        </p>
      </div>
    </div>
  );
}
