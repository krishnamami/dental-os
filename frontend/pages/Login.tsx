/**
 * C-01 — sign in.
 *
 * Real now: POST /api/auth/login, bcrypt-verified server-side, JWT
 * back. The role in the token is the server's answer, not this
 * screen's suggestion — the old role picker is gone with it.
 *
 * ⚠ THE DEMO CREDENTIAL PANEL IS GONE from this screen, but THE
 * ACCOUNTS ARE NOT GONE from the database. Eleven users still
 * authenticate with the shared demo password, one of them an
 * accord_admin that can impersonate every other user. Removing the
 * panel stops PUBLISHING them; it does not revoke them. They have to
 * be rotated or deleted in seed_users.py before a real patient
 * exists in that database.
 */
import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";

import { AccordLogo } from "../components/AccordLogo";
import { HOME_FOR_ROLE, statusOf, useAuth } from "../context/AuthContext";
import type { Role } from "../types/dental";

/**
 * What to tell the visitor, by what actually came back.
 *
 * These cases must stay separate. `undefined` means NO RESPONSE
 * ARRIVED — the API is down, DNS failed, or the browser blocked it.
 * This used to share the 401 wording, which told someone their
 * password was wrong while the service was off: they retype it, then
 * reset it, and the outage never gets reported. statusOf's docstring
 * said these two must not collapse; the caller collapsed them anyway.
 *
 * 401 stays deliberately vague. The API answers a wrong password and
 * an unknown email identically so the form cannot be used to discover
 * which addresses exist, and echoing anything sharper here would undo
 * that. Everything else is an OUR-FAULT status and says so, with the
 * code, because "try again" is useless advice for a 502 and the number
 * is what makes a support message actionable.
 */
function messageFor(status: number | undefined): string {
  if (status === 401) return "Invalid email or password";
  if (status === undefined) {
    return "Can't reach the sign-in service. Check your connection and try again.";
  }
  // asPayload() stamps 502 on a 200 whose body was not a session — in
  // production, index.html from the SPA fallback, i.e. /api is not
  // routed to dental-os at all. Retrying cannot fix that.
  if (status === 502) {
    return "Sign-in is misconfigured on this deployment — the service did not return a session. Please report this.";
  }
  // Two sources, same answer to the visitor: _pool() raises 503 when
  // auth never got a database at startup, and the ALB returns its own
  // 503 when the dental-os target group has no healthy task at all.
  // The second is an nginx-style HTML page, not FastAPI JSON — which
  // is how you tell them apart in a curl.
  if (status === 503) {
    return "Sign-in is temporarily unavailable. Please try again in a few minutes.";
  }
  return `Sign-in failed (error ${status}). Please try again, and report this if it persists.`;
}

export default function Login() {
  const { login } = useAuth();
  const navigate = useNavigate();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

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
      //
      // `location.state.from` is deliberately IGNORED. ProtectedRoute
      // records where a signed-out visitor was heading, and honouring
      // it sent Jennifer to /checkin — a page she holds but does not
      // start on — because that was the last URL in the bar. Worse,
      // `from` survives a sign-out, so signing in as someone else
      // landed the new user on the previous user's page. The role's
      // home is the right landing every time.
      const user = await login(email, password);
      navigate(HOME_FOR_ROLE[user.role as Role] ?? "/workbench", {
        replace: true,
      });
    } catch (err) {
      // The real error never reaches the visitor — messageFor() is
      // deliberately vague about credentials. Log it so a failing
      // deployment is diagnosable from the console instead of from
      // four words on a red line.
      console.error("sign-in failed", err);
      setError(messageFor(statusOf(err)));
    } finally {
      setBusy(false);
    }
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
