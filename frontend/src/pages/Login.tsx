/**
 * C-01 — sign in.
 *
 * ⚠ THIS IS NOT AUTHENTICATION. Any email and any non-empty password
 * signs you in as a dentist. There is no identity provider, no token,
 * and no server-side check — the role goes into localStorage and the
 * app believes it.
 *
 * Deliberate for a scaffold, and a hard blocker before real patient
 * data is served. When that changes it is not only this screen: the API
 * has to enforce role AND tenant on every request, and AuthContext
 * becomes a cache of what the server already decided rather than the
 * decision itself.
 *
 * The role selector below is a development affordance, not a product
 * feature — it exists so the five role-specific shells can be built and
 * reviewed before there is anything to authenticate against.
 */
import { useState } from "react";
import { Link, useLocation, useNavigate } from "react-router-dom";

import { ROLES, ROLE_LABELS, useAuth } from "../context/AuthContext";
import { HOME_FOR_ROLE } from "../routes";
import type { Role } from "../types/dental";
import { Logo } from "../components/lp/primitives";

const TENANTS = [
  { id: "suwanee_smiles", label: "Suwanee Smiles Dental — GA" },
  { id: "tampa_smiles", label: "Tampa Bay Smiles — FL" },
  { id: "dallas_dental", label: "Dallas Family Dental — TX" },
];

export default function Login() {
  const { signIn } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [role, setRole] = useState<Role>("dentist");
  const [tenantId, setTenantId] = useState(TENANTS[0].id);
  const [error, setError] = useState("");

  const from = (location.state as { from?: string } | null)?.from;

  function submit(e: React.FormEvent) {
    e.preventDefault();
    // The only failure this can produce is an empty field. There is
    // nothing to authenticate against yet.
    if (!email.trim() || !password.trim()) {
      setError("Invalid email or password");
      return;
    }
    setError("");
    signIn(role, tenantId);
    navigate(from ?? HOME_FOR_ROLE[role], { replace: true });
  }

  const field =
    "w-full rounded-lg border border-gray-300 px-3 py-2.5 text-sm text-gray-900 placeholder-gray-400 focus:border-accord-green-500 focus:outline-none focus:ring-1 focus:ring-accord-green-500";
  const label = "mb-1 block text-[12.5px] font-medium text-gray-700";

  return (
    <div className="flex min-h-screen items-center justify-center bg-gray-50 px-5 py-10">
      <div className="w-full max-w-sm">
        <div className="text-center">
          <Link to="/" className="inline-block">
            <Logo size={34} />
          </Link>
          <h1 className="mt-6 text-[22px] font-semibold tracking-[-0.01em] text-gray-900">
            Sign in to Accord Dental
          </h1>
          <p className="mt-1.5 text-[13.5px] text-gray-500">
            The Dental Decision Intelligence Platform
          </p>
        </div>

        <form
          onSubmit={submit}
          className="mt-7 space-y-3.5 rounded-xl border border-gray-200 bg-white p-6 shadow-sm"
        >
          <div>
            <label className={label} htmlFor="email">
              Email
            </label>
            <input
              id="email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="you@practice.com"
              className={field}
            />
          </div>

          <div>
            <label className={label} htmlFor="password">
              Password
            </label>
            <input
              id="password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
              className={field}
            />
          </div>

          {/* Development affordance — see the header. */}
          <div className="grid grid-cols-2 gap-3 border-t border-gray-100 pt-3.5">
            <div>
              <label className={label} htmlFor="role">
                Sign in as
              </label>
              <select
                id="role"
                value={role}
                onChange={(e) => setRole(e.target.value as Role)}
                className={field}
              >
                {ROLES.map((r) => (
                  <option key={r} value={r}>
                    {ROLE_LABELS[r]}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label className={label} htmlFor="tenant">
                Practice
              </label>
              <select
                id="tenant"
                value={tenantId}
                onChange={(e) => setTenantId(e.target.value)}
                className={field}
              >
                {TENANTS.map((t) => (
                  <option key={t.id} value={t.id}>
                    {t.label.split(" — ")[0]}
                  </option>
                ))}
              </select>
            </div>
          </div>

          {error && (
            <p role="alert" className="text-[12.5px] text-red-600">
              {error}
            </p>
          )}

          <button
            type="submit"
            className="w-full rounded-lg bg-accord-green-900 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-accord-green-700"
          >
            Sign in
          </button>

          <p className="text-center text-[13px] text-gray-500">
            <Link
              to="/workbench?demo=true"
              className="font-medium text-accord-green-900 hover:text-accord-green-700"
            >
              Try demo →
            </Link>
          </p>
        </form>

        <p className="mt-6 text-center text-[12.5px] text-gray-500">
          Request access →{" "}
          <a
            href="mailto:demo@accorddental.io"
            className="font-medium text-accord-green-900 hover:text-accord-green-700"
          >
            demo@accorddental.io
          </a>
        </p>
      </div>
    </div>
  );
}
