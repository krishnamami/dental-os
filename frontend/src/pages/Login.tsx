/**
 * C-01 — sign in.
 *
 * Real now: POST /api/auth/login, bcrypt-verified server-side, JWT
 * back. The role in the token is the server's answer, not this
 * screen's suggestion — the old role picker is gone with it.
 *
 * ⚠ THE DEMO PANEL PUBLISHES ELEVEN WORKING CREDENTIALS, one of them
 * an accord_admin that can impersonate every other user, on a page
 * anyone on the internet can reach. That is a deliberate trade while
 * the corpus is synthetic and the whole point is a self-serve demo.
 * It has to come out before a real patient exists in that database —
 * along with the accounts themselves.
 */
import { useRef, useState } from "react";
import { Link, useLocation, useNavigate } from "react-router-dom";

import { AccordLogo } from "../components/AccordLogo";
import { HOME_FOR_ROLE, statusOf, useAuth } from "../context/AuthContext";
import type { Role } from "../types/dental";

const ROLE_BADGE: Record<Role, { label: string; cls: string }> = {
  dentist: { label: "Dentist", cls: "bg-accord-green-50 text-accord-green-700" },
  dso_owner: { label: "DSO owner", cls: "bg-blue-50 text-blue-700" },
  front_desk: { label: "Front desk", cls: "bg-gray-100 text-gray-600" },
  revenue_ops: { label: "Revenue ops", cls: "bg-amber-50 text-amber-700" },
  accord_admin: { label: "Admin", cls: "bg-purple-50 text-purple-700" },
};

const DEMO_GROUPS: Array<{
  tenant: string;
  users: Array<{ name: string; email: string; role: Role }>;
}> = [
  {
    tenant: "Suwanee Smiles Dental",
    users: [
      { name: "Dr. Sridhar Chinta", email: "drchinta@suwaneesmiles.com", role: "dentist" },
      { name: "Dr. Shyam Patel", email: "drshyam@suwaneesmiles.com", role: "dso_owner" },
      { name: "Sarah R.", email: "sarah@suwaneesmiles.com", role: "front_desk" },
      { name: "Kim B.", email: "billing@suwaneesmiles.com", role: "revenue_ops" },
    ],
  },
  {
    tenant: "Tampa Bay Smiles",
    users: [
      { name: "Dr. Maria Rodriguez", email: "drrodriguez@tampabaysmiles.com", role: "dentist" },
      { name: "Dr. Shyam Patel", email: "drshyam@tampabaysmiles.com", role: "dso_owner" },
      { name: "Sarah T.", email: "sarah@tampabaysmiles.com", role: "front_desk" },
      { name: "Kim T.", email: "billing@tampabaysmiles.com", role: "revenue_ops" },
    ],
  },
  {
    tenant: "Dallas Family Dental",
    users: [
      { name: "Dr. James Wilson", email: "drwilson@dallasfamilydental.com", role: "dentist" },
      { name: "Kim D.", email: "billing@dallasfamilydental.com", role: "revenue_ops" },
    ],
  },
  {
    tenant: "Accord platform",
    users: [
      { name: "Accord Admin", email: "admin@accorddental.io", role: "accord_admin" },
    ],
  },
];

export default function Login() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const passwordRef = useRef<HTMLInputElement>(null);

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  // Collapsed on load. Eleven working credentials — one of them an
  // admin that can impersonate anyone — should not be the first thing
  // on the page. Someone who needs them knows to look.
  const [showDemo, setShowDemo] = useState(false);

  const from = (location.state as { from?: string } | null)?.from;

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (busy) return;
    setError("");
    setBusy(true);
    try {
      // The route comes from the RESPONSE, not from the context's
      // homeRoute. This closure captured homeRoute during the
      // signed-out render, where role is null and it reads
      // "/workbench" — navigating there would put front desk, DSO
      // owner and admin on the workbench, and because all three hold
      // the `workbench` product ProductRoute would not even bounce
      // them. Wrong page, no error.
      const user = await login(email, password);
      navigate(from ?? HOME_FOR_ROLE[user.role] ?? "/workbench", {
        replace: true,
      });
    } catch (err) {
      // Never echo the server's wording for a bad credential. The API
      // deliberately says the same thing for a wrong password and an
      // unknown email; repeating anything more specific here would
      // undo that.
      const status = statusOf(err);
      setError(
        status === 401 || status === undefined
          ? "Invalid email or password"
          : "Could not reach the sign-in service. Try again.",
      );
    } finally {
      setBusy(false);
    }
  }

  function fill(addr: string) {
    setEmail(addr);
    setError("");
    passwordRef.current?.focus();
  }

  const field =
    "w-full rounded-lg border border-gray-300 px-3 py-2.5 text-sm text-gray-900 placeholder-gray-400 focus:border-accord-green-500 focus:outline-none focus:ring-1 focus:ring-accord-green-500";
  const label = "mb-1 block text-[12.5px] font-medium text-gray-700";

  return (
    <div className="flex min-h-screen items-start justify-center bg-gray-50 px-5 py-10">
      <div className="w-full max-w-md">
        <div className="text-center">
          <Link to="/" className="inline-flex justify-center">
            <AccordLogo size={30} />
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
              Work email
            </label>
            <input
              id="email"
              type="email"
              autoComplete="username"
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
              ref={passwordRef}
              type="password"
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
              className={field}
            />
          </div>

          {error && (
            <p role="alert" className="text-[12.5px] text-red-600">
              {error}
            </p>
          )}

          <button
            type="submit"
            disabled={busy}
            className="min-h-[44px] w-full rounded-lg px-4 py-2.5 text-sm font-semibold text-white transition hover:opacity-90 disabled:opacity-60"
            style={{ backgroundColor: "#0F4D37" }}
          >
            {busy ? "Signing in…" : "Sign in"}
          </button>

          <p className="text-center text-[13px] text-gray-500">
            <Link
              to="/workbench?demo=true"
              className="font-medium text-accord-green-900 hover:text-accord-green-700"
            >
              Try the demo without signing in →
            </Link>
          </p>
        </form>

        {/* ── Demo accounts ─────────────────────────────────────── */}
        <div className="mt-6 rounded-xl border border-gray-200 bg-white p-4">
          <button
            type="button"
            onClick={() => setShowDemo((v) => !v)}
            aria-expanded={showDemo}
            aria-controls="demo-accounts"
            className="flex items-center gap-1 text-sm text-slate-500 transition hover:text-slate-700"
          >
            <span aria-hidden="true">{showDemo ? "▾" : "▸"}</span>
            Demo accounts · password: demo2026
          </button>

          {showDemo && (
            <div id="demo-accounts">
              <p className="mt-2 text-[11px] text-gray-400">
                Click a name to fill the email. Every account reads the same
                synthetic corpus.
              </p>

              {DEMO_GROUPS.map((g) => (
                <div key={g.tenant} className="mt-3.5">
                  <p className="mb-1 text-[9.5px] font-bold uppercase tracking-[0.12em] text-gray-400">
                    {g.tenant}
                  </p>
                  <ul className="divide-y divide-gray-100">
                    {g.users.map((u) => {
                      const badge = ROLE_BADGE[u.role];
                      return (
                        <li key={u.email}>
                          <button
                            type="button"
                            onClick={() => fill(u.email)}
                            className="flex w-full items-center gap-2 rounded px-1.5 py-2 text-left transition hover:bg-gray-50"
                          >
                            <span className="min-w-0 flex-1">
                              <span className="block truncate text-[12.5px] font-medium text-gray-800">
                                {u.name}
                              </span>
                              <span className="block truncate font-mono text-[10.5px] text-gray-400">
                                {u.email}
                              </span>
                            </span>
                            <span
                              className={`flex-shrink-0 rounded-full px-2 py-0.5 text-[9.5px] font-semibold ${badge.cls}`}
                            >
                              {badge.label}
                            </span>
                          </button>
                        </li>
                      );
                    })}
                      </ul>
                    </div>
              ))}
            </div>
          )}
        </div>

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
