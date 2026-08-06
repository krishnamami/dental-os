/**
 * Who is looking, and at which practice.
 *
 * ⚠ THIS IS NOT AUTHENTICATION. There is no identity provider behind it
 * yet, no token, and no server-side check. It holds a role in React
 * state so the UI can decide what to render, and a determined visitor
 * can set any role they like from the console.
 *
 * That is acceptable for a scaffold and NOT acceptable once real
 * patient data is served. Before that: the API has to enforce the role
 * and the tenant on every request, and this context becomes a cache of
 * what the server already decided rather than the decision itself.
 * Route guards below are a usability feature — they keep a front-desk
 * user out of the admin console — not a security boundary.
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

import { useDemo } from "../hooks/useDemo";
import type { Role } from "../types/dental";

export const ROLES: Role[] = [
  "front_desk",
  "revenue_ops",
  "dentist",
  "dso_owner",
  "accord_admin",
];

export const ROLE_LABELS: Record<Role, string> = {
  front_desk: "Front desk",
  revenue_ops: "Revenue operations",
  dentist: "Dentist",
  dso_owner: "DSO owner",
  accord_admin: "Accord admin",
};

interface AuthState {
  role: Role | null;
  tenantId: string | null;
  isDemo: boolean;
  isAuthenticated: boolean;
  signIn: (role: Role, tenantId: string) => void;
  signOut: () => void;
}

const AuthContext = createContext<AuthState | undefined>(undefined);

const STORAGE_KEY = "accord.session";

interface StoredSession {
  role: Role;
  tenantId: string;
}

function readStored(): StoredSession | null {
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as StoredSession;
    return ROLES.includes(parsed.role) && parsed.tenantId ? parsed : null;
  } catch {
    // A corrupt or unavailable localStorage must not blank the app.
    return null;
  }
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const { isDemo, demoTenant } = useDemo();
  const [session, setSession] = useState<StoredSession | null>(readStored);

  useEffect(() => {
    if (session) {
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(session));
    } else {
      window.localStorage.removeItem(STORAGE_KEY);
    }
  }, [session]);

  const signIn = useCallback((role: Role, tenantId: string) => {
    setSession({ role, tenantId });
  }, []);

  const signOut = useCallback(() => setSession(null), []);

  const value = useMemo<AuthState>(() => {
    // Demo mode wins over any stored session. A prospect following a
    // ?demo=true link must see the demo, not whatever role happened to
    // be left in localStorage from a previous visit.
    if (isDemo) {
      return {
        role: "dentist",
        tenantId: demoTenant,
        isDemo: true,
        isAuthenticated: true,
        signIn,
        signOut,
      };
    }
    return {
      role: session?.role ?? null,
      tenantId: session?.tenantId ?? null,
      isDemo: false,
      isAuthenticated: Boolean(session),
      signIn,
      signOut,
    };
  }, [isDemo, demoTenant, session, signIn, signOut]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext);
  if (!ctx) {
    throw new Error("useAuth must be used inside <AuthProvider>");
  }
  return ctx;
}
