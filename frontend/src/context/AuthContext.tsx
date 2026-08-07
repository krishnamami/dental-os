/**
 * Who is looking, and on behalf of which practice.
 *
 * ⚠ THE ROUTE GUARDS HERE ARE USABILITY, NOT SECURITY.
 *
 * The token is real now — issued by POST /api/auth/login, signed
 * server-side, verified on /auth/me, /auth/impersonate and
 * /auth/users. But the DATA endpoints are still open: anyone can GET
 * /api/decisions/{id} with no token at all. So hiding a nav item stops
 * a front-desk user wandering into the DSO page; it does not stop
 * anyone reading another practice's pre-Ds.
 *
 * Closing that needs a dependency on every data route in dental-os
 * that takes tenant_id from the token's claims instead of trusting the
 * caller. Until then this file decides what the UI OFFERS, not what
 * the API ALLOWS, and the distinction matters the day the corpus stops
 * being synthetic.
 */
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";

import { api } from "../hooks/useApi";
import { useDemo } from "../hooks/useDemo";
import type { AuthUser, ImpersonatedUser, Role } from "../types/dental";

export const ROLES: Role[] = [
  "front_desk",
  "tx_coord",
  "revenue_ops",
  "dentist",
  "dso_owner",
  "accord_admin",
];

export const ROLE_LABELS: Record<Role, string> = {
  front_desk: "Front desk",
  tx_coord: "Treatment coordinator",
  revenue_ops: "Revenue operations",
  dentist: "Dentist",
  // "Practice owner", not "DSO owner": the person signing in owns the
  // practice. DSO is what a group of them is called.
  dso_owner: "Practice owner",
  accord_admin: "Accord admin",
};

const TOKEN_KEY = "accord_dental_token";
const VIEWAS_KEY = "accord_dental_viewas";
const ORIG_KEY = "accord_dental_orig_token";

/**
 * The seven workflows, and who may open each.
 *
 * Named for the JOB, not the page: `patient_financial` is the money
 * conversation, which happens to render at /coverage. When a workflow
 * moves route this table does not change, and a role's permissions
 * cannot silently follow a URL rename.
 *
 * Note what front desk LOST here: `workbench`. Reading a full pre-D —
 * every persona's finding on a patient's clinical case — was never
 * part of checking someone in. Narrowing it is the point of splitting
 * the roles.
 */
const ROLE_PRODUCTS: Record<Role, string[]> = {
  front_desk: ["checkin", "patient_financial"],
  tx_coord: ["checkin", "patient_financial", "workbench"],
  revenue_ops: ["workbench", "revenue_ops", "patient_financial"],
  dentist: [
    "workbench",
    "clinical",
    "patient_financial",
    "revenue_ops",
    "portfolio",
  ],
  dso_owner: ["portfolio", "revenue_ops", "workbench"],
  accord_admin: [
    "checkin",
    "patient_financial",
    "workbench",
    "clinical",
    "revenue_ops",
    "portfolio",
    "admin",
  ],
};

/**
 * Which sidebar entries a role sees, in the order they see them.
 *
 * The gate strings must match WORKFLOW_NAV[].gate in routes.ts exactly.
 * A typo here does not error — it silently removes the entry, which is
 * why both tables name the same seven strings and nothing derives one
 * from the other by string munging.
 */
const ROLE_NAV: Record<Role, string[]> = {
  front_desk: ["Check-In", "Patient Financial"],
  tx_coord: ["Check-In", "Patient Financial", "Pre-D Workbench"],
  revenue_ops: ["Pre-D Workbench", "Revenue Ops", "Patient Financial"],
  dentist: [
    "Pre-D Workbench",
    "Clinical Intelligence",
    "Patient Financial",
    "Revenue Ops",
    "Portfolio",
  ],
  dso_owner: ["Portfolio", "Revenue Ops", "Pre-D Workbench"],
  accord_admin: [
    "Check-In",
    "Patient Financial",
    "Pre-D Workbench",
    "Clinical Intelligence",
    "Revenue Ops",
    "Portfolio",
    "Admin",
  ],
};

/** Where a role lands after signing in. */
export const HOME_FOR_ROLE: Record<Role, string> = {
  front_desk: "/checkin",
  tx_coord: "/coverage",
  revenue_ops: "/revenue-ops",
  dentist: "/workbench",
  dso_owner: "/dso",
  accord_admin: "/admin",
};

export function getToken(): string | null {
  try {
    return window.localStorage.getItem(TOKEN_KEY);
  } catch {
    // Safari private mode throws on localStorage. Signed out beats crashed.
    return null;
  }
}

function setStored(key: string, value: string | null) {
  try {
    if (value === null) window.localStorage.removeItem(key);
    else window.localStorage.setItem(key, value);
  } catch {
    /* see getToken */
  }
}

// The Authorization and X-Demo-Mode headers are attached by the
// interceptor in useApi.ts, not here — it has to be registered whether
// or not this module was imported.

interface LoginPayload {
  token: string;
  user: AuthUser;
}

/** HTTP status from an axios rejection, whatever shape it arrived in.
 *  Callers branch on 401 vs "the network is broken", and those two must
 *  not collapse into the same message. */
export function statusOf(err: unknown): number | undefined {
  const e = err as { status?: number; response?: { status?: number } };
  return e?.response?.status ?? e?.status;
}

/**
 * Reject a token payload that is not one.
 *
 * api.post does not go through useApi's get() helper, so it does not
 * inherit the non-JSON guard there — and production answers an
 * unrouted /api path with index.html at status 200. Without this, a
 * login against a broken route would "succeed" and store the string
 * "undefined" as a bearer token.
 */
function asPayload(data: unknown): LoginPayload {
  const d = data as Partial<LoginPayload>;
  if (!d || typeof d.token !== "string" || !d.user?.role) {
    throw Object.assign(
      new Error("The sign-in service returned something that is not a session."),
      { status: 502 },
    );
  }
  return d as LoginPayload;
}

interface AuthState {
  isAuthenticated: boolean;
  isLoading: boolean;
  isDemo: boolean;
  user: AuthUser | null;
  effectiveUser: AuthUser | null;
  viewAs: ImpersonatedUser | null;
  /** Mirrors of effectiveUser — most callers only ever wanted these. */
  role: Role | null;
  tenantId: string | null;
  /** Resolves with the authenticated user. Callers need it to decide
   *  where to go next: `homeRoute` on the context is still the
   *  signed-out value until React re-renders, so a handler that reads
   *  it after awaiting login sends everyone to the same page. */
  login: (email: string, password: string) => Promise<AuthUser>;
  logout: () => void;
  /** Resolves with the impersonated user, for the same reason. */
  impersonate: (u: ImpersonatedUser) => Promise<AuthUser>;
  stopImpersonating: () => Promise<void>;
  hasProduct: (product: string) => boolean;
  navAllows: (label: string) => boolean;
  /** The role's gates in the order they should appear in the sidebar. */
  navOrder: string[];
  homeRoute: string;
}

const AuthContext = createContext<AuthState | undefined>(undefined);

/** The demo identity. Not a session — no token is issued, and the API
 *  is read anonymously, which is all ?demo=true ever did. */
function demoUser(tenant: string): AuthUser {
  return {
    user_id: "demo-drchinta",
    email: "drchinta@suwaneesmiles.com",
    name: "Dr. Sridhar Chinta",
    role: "dentist",
    tenant_id: tenant,
    tenant_name: "Suwanee Smiles Dental",
    tenant_address: "3155 Peachtree Pkwy Ste 120, Suwanee GA",
  };
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const { isDemo, demoTenant } = useDemo();

  const [user, setUser] = useState<AuthUser | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [viewAs, setViewAs] = useState<ImpersonatedUser | null>(() => {
    try {
      const raw = window.localStorage.getItem(VIEWAS_KEY);
      return raw ? (JSON.parse(raw) as ImpersonatedUser) : null;
    } catch {
      return null;
    }
  });

  /**
   * Session restore.
   *
   * Skipped entirely in demo mode: a visitor following ?demo=true has
   * no token, and firing /auth/me would land a 401 a beat after the
   * demo user was set — overwriting it and bouncing them to /login.
   */
  useEffect(() => {
    if (isDemo) {
      setUser(demoUser(demoTenant ?? "suwanee_smiles"));
      setIsLoading(false);
      return;
    }
    if (!getToken()) {
      setUser(null);
      setIsLoading(false);
      return;
    }
    let cancelled = false;
    api
      .get<LoginPayload>("/auth/me")
      .then((res) => {
        if (cancelled) return;
        // /auth/me reissues, so a role changed in the database takes
        // effect without waiting out the 7-day expiry.
        const data = asPayload(res.data);
        setStored(TOKEN_KEY, data.token);
        setUser(data.user);
      })
      .catch(() => {
        if (cancelled) return;
        // Expired, or signed by a key this deployment no longer holds.
        // All the same to a visitor: signed out.
        setStored(TOKEN_KEY, null);
        setStored(VIEWAS_KEY, null);
        setStored(ORIG_KEY, null);
        setUser(null);
        setViewAs(null);
      })
      .finally(() => {
        if (!cancelled) setIsLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [isDemo, demoTenant]);

  const login = useCallback(async (email: string, password: string) => {
    const res = await api.post<LoginPayload>("/auth/login", {
      email,
      password,
    });
    const data = asPayload(res.data);
    setStored(TOKEN_KEY, data.token);
    setStored(VIEWAS_KEY, null);
    setStored(ORIG_KEY, null);
    setViewAs(null);
    setUser(data.user);
    return data.user;
  }, []);

  const logout = useCallback(() => {
    // Client-side only. The token stays valid at the API until it
    // expires — there is no revocation list, so "sign out" means
    // "forget", not "invalidate".
    setStored(TOKEN_KEY, null);
    setStored(VIEWAS_KEY, null);
    setStored(ORIG_KEY, null);
    setUser(null);
    setViewAs(null);
  }, []);

  const impersonate = useCallback(async (u: ImpersonatedUser) => {
    // Read the admin's own token first, but only commit it once the
    // request succeeds — a failed impersonation must change nothing.
    const orig = getToken();
    const res = await api.post<LoginPayload>("/auth/impersonate", {
      user_id: u.user_id,
    });
    const data = asPayload(res.data);
    if (orig) setStored(ORIG_KEY, orig);
    setStored(TOKEN_KEY, data.token);
    setStored(VIEWAS_KEY, JSON.stringify(u));
    setViewAs(u);
    setUser(data.user);
    return data.user;
  }, []);

  const stopImpersonating = useCallback(async () => {
    const orig = window.localStorage.getItem(ORIG_KEY);
    setStored(TOKEN_KEY, orig);
    setStored(VIEWAS_KEY, null);
    setStored(ORIG_KEY, null);
    setViewAs(null);
    if (!orig) {
      // No way back — the admin token is gone. Sign out rather than
      // leave the UI claiming to be someone it cannot prove.
      setUser(null);
      return;
    }
    try {
      const data = asPayload((await api.get<LoginPayload>("/auth/me")).data);
      setStored(TOKEN_KEY, data.token);
      setUser(data.user);
    } catch {
      setStored(TOKEN_KEY, null);
      setUser(null);
    }
  }, []);

  const value = useMemo<AuthState>(() => {
    // After impersonating, `user` IS the impersonated user — the API
    // returned them. viewAs exists to say so out loud in the banner.
    const effectiveUser = user;
    const role = effectiveUser?.role ?? null;
    return {
      isAuthenticated: isDemo || Boolean(user),
      isLoading,
      isDemo,
      user,
      effectiveUser,
      viewAs,
      role,
      tenantId: effectiveUser?.tenant_id ?? null,
      login,
      logout,
      impersonate,
      stopImpersonating,
      hasProduct: (product: string) =>
        role ? (ROLE_PRODUCTS[role] ?? []).includes(product) : false,
      navAllows: (label: string) =>
        role ? (ROLE_NAV[role] ?? []).includes(label) : false,
      navOrder: role ? (ROLE_NAV[role] ?? []) : [],
      homeRoute: role ? (HOME_FOR_ROLE[role] ?? "/workbench") : "/workbench",
    };
  }, [
    isDemo,
    isLoading,
    user,
    viewAs,
    login,
    logout,
    impersonate,
    stopImpersonating,
  ]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext);
  if (!ctx) {
    throw new Error("useAuth must be used inside <AuthProvider>");
  }
  return ctx;
}
