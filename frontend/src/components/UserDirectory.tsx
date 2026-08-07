/**
 * H-12 — the user directory, with "view as".
 *
 * Reads GET /api/auth/users, which is accord_admin-only server-side.
 * That 403 is the real gate; this component only ever renders inside
 * the admin console, so a non-admin should never reach it — but if the
 * route guard is ever loosened, the API still says no.
 *
 * Impersonation swaps the stored token for one the server minted for
 * the target user, stamped with `impersonated_by`. The admin's own
 * token is kept so there is a way back; see AuthContext.
 */
import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Eye } from "lucide-react";

import { api } from "../hooks/useApi";
import { HOME_FOR_ROLE, statusOf, useAuth } from "../context/AuthContext";
import type { ImpersonatedUser, Role } from "../types/dental";

interface DirectoryUser {
  user_id: string;
  email: string;
  name: string;
  role: Role;
  tenant_id: string | null;
}

const TENANT_LABEL: Record<string, string> = {
  suwanee_smiles: "Suwanee Smiles Dental",
  tampa_smiles: "Tampa Bay Smiles",
  dallas_dental: "Dallas Family Dental",
};

const ROLE_BADGE: Record<Role, { label: string; cls: string }> = {
  dentist: { label: "Dentist", cls: "bg-accord-green-50 text-accord-green-700" },
  dso_owner: { label: "DSO owner", cls: "bg-blue-50 text-blue-700" },
  front_desk: { label: "Front desk", cls: "bg-gray-100 text-gray-600" },
  revenue_ops: { label: "Revenue ops", cls: "bg-amber-50 text-amber-700" },
  accord_admin: { label: "Admin", cls: "bg-purple-50 text-purple-700" },
};

function initials(name: string): string {
  const parts = name
    .replace(/^(Dr|Mr|Mrs|Ms)\.?\s+/i, "")
    .split(/\s+/)
    .filter(Boolean);
  if (parts.length === 0) return "?";
  return (parts[0][0] + (parts[1]?.[0] ?? "")).toUpperCase();
}

export default function UserDirectory() {
  const { impersonate, effectiveUser, isDemo } = useAuth();
  const navigate = useNavigate();

  const [users, setUsers] = useState<DirectoryUser[] | null>(null);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState<string | null>(null);

  useEffect(() => {
    if (isDemo) {
      // Demo mode holds no token, so /auth/users would 401. Say so
      // rather than render an empty directory that looks like "no
      // users exist".
      setError("Sign in as an admin to see the user directory.");
      return;
    }
    let cancelled = false;
    api
      .get<DirectoryUser[]>("/auth/users")
      .then(({ data }) => !cancelled && setUsers(data))
      .catch((err) => {
        if (cancelled) return;
        const status = statusOf(err);
        setError(
          status === 403
            ? "Admin only."
            : "Could not load the user directory.",
        );
      });
    return () => {
      cancelled = true;
    };
  }, [isDemo]);

  async function viewAs(u: DirectoryUser) {
    setBusy(u.user_id);
    setError("");
    try {
      const payload: ImpersonatedUser = {
        user_id: u.user_id,
        name: u.name,
        role: u.role,
        tenant_id: u.tenant_id,
      };
      const now = await impersonate(payload);
      navigate(HOME_FOR_ROLE[now.role] ?? "/workbench", { replace: true });
    } catch {
      setError(`Could not view as ${u.name}.`);
      setBusy(null);
    }
  }

  if (error && !users) {
    return (
      <div className="rounded-xl border border-gray-200 bg-white p-5">
        <p className="text-[12.5px] text-gray-500">{error}</p>
      </div>
    );
  }

  if (!users) {
    return (
      <div className="animate-pulse space-y-2 rounded-xl border border-gray-200 bg-white p-5">
        <div className="h-3 w-40 rounded bg-gray-100" />
        <div className="h-3 w-full rounded bg-gray-100" />
        <div className="h-3 w-3/4 rounded bg-gray-100" />
      </div>
    );
  }

  // Grouped in the order the API returned them, so the grouping
  // matches its ORDER BY tenant_id NULLS LAST rather than re-sorting
  // into a second opinion.
  const groups: Array<[string, DirectoryUser[]]> = [];
  for (const u of users) {
    const key = u.tenant_id ?? "";
    const last = groups[groups.length - 1];
    if (last && last[0] === key) last[1].push(u);
    else groups.push([key, [u]]);
  }

  return (
    <div className="overflow-hidden rounded-xl border border-gray-200 bg-white">
      <div className="flex items-baseline justify-between border-b border-gray-200 px-4 py-2.5">
        <h3 className="text-[13px] font-semibold text-gray-900">
          Users ({users.length})
        </h3>
        <p className="text-[11px] text-gray-400">
          &ldquo;View as&rdquo; issues a token stamped with your admin id
        </p>
      </div>

      {error && (
        <p className="border-b border-red-100 bg-red-50 px-4 py-2 text-[12px] text-red-600">
          {error}
        </p>
      )}

      {groups.map(([tenant, list]) => (
        <div key={tenant || "platform"}>
          <p className="border-b border-gray-100 bg-gray-50 px-4 py-1.5 text-[10px] font-bold uppercase tracking-[0.12em] text-gray-500">
            {TENANT_LABEL[tenant] ?? (tenant || "Accord platform")}
          </p>
          <ul className="divide-y divide-gray-100">
            {list.map((u) => {
              const badge = ROLE_BADGE[u.role];
              const self = u.user_id === effectiveUser?.user_id;
              return (
                <li key={u.user_id} className="flex items-center gap-3 px-4 py-2.5">
                  <span className="flex h-7 w-7 flex-shrink-0 items-center justify-center rounded-full bg-gray-100 text-[10px] font-semibold text-gray-600">
                    {initials(u.name)}
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-[13px] font-medium text-gray-900">
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
                  <button
                    type="button"
                    disabled={self || busy !== null}
                    onClick={() => void viewAs(u)}
                    title={
                      self
                        ? "This is you"
                        : `Open the app as ${u.name} would see it`
                    }
                    className="inline-flex flex-shrink-0 items-center gap-1 rounded-lg border border-gray-300 px-2.5 py-1 text-[11.5px] font-medium text-gray-700 transition hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-40"
                  >
                    <Eye size={12} />
                    {busy === u.user_id ? "…" : "View as"}
                  </button>
                </li>
              );
            })}
          </ul>
        </div>
      ))}
    </div>
  );
}
