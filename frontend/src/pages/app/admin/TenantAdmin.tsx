/**
 * Practice administration — a practice owner's view of their own shop.
 *
 * ⚠ NOT the Accord console. /admin/* is the platform admin's area and
 * is gated on accord_admin; this page lives at /admin/tenant only
 * because the path reads well. Its gate is `tenant_admin`, held by
 * dso_owner, and the API enforces the same boundary independently:
 * GET /auth/users, /admin/practice and /admin/overlays all depend on
 * require_practice_admin, which IGNORES the tenant_id in the query
 * string for a non-Accord caller and answers about their own practice.
 * So an owner who edits the URL learns nothing about another tenant.
 *
 * Nothing on this page is typed in. The practice name and address come
 * off the token, the staff list, providers, payer mix and overlay rules
 * come from the API — which matters because Dr. Shyam owns TWO
 * practices (suwanee_smiles and tampa_smiles) under two logins, and a
 * page with "Suwanee Smiles Dental" hardcoded would show him the wrong
 * NPI half the time.
 *
 * Two sections are read-only on purpose. There is no write endpoint for
 * practice settings or for deactivating a user, so those buttons say so
 * rather than pretending; a button that silently does nothing is worse
 * than one that admits it is not built.
 */
import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Building2, Eye, ShieldAlert, Users } from "lucide-react";

import { api } from "../../../hooks/useApi";
import {
  HOME_FOR_ROLE,
  ROLE_LABELS,
  statusOf,
  useAuth,
} from "../../../context/AuthContext";
import type { ImpersonatedUser, Role } from "../../../types/dental";

const GREEN = "#0F4D37";

interface StaffUser {
  user_id: string;
  email: string;
  name: string;
  role: Role;
  tenant_id: string | null;
}

interface Provider {
  provider_npi: string;
  name: string;
  credential: string;
  network_status: string;
  oig_excluded: boolean;
}

interface PayerMix {
  payer_id: string;
  payer_name: string;
  patients: number;
}

interface Practice {
  tenant_id: string;
  providers: Provider[];
  payers: PayerMix[];
}

interface Overlay {
  payer_id: string;
  payer_name: string;
  cdt_code: string;
  procedure: string;
  rule_overrides: Record<string, unknown>;
  reason: string | null;
  active: boolean;
  effective_from: string | null;
  effective_to: string | null;
}

/** A rule override rendered as a sentence rather than as JSON. The
 *  owner of the practice wrote the policy; they should not have to read
 *  their own policy back as `{"clinical_criteria_required":true}`. */
function describeOverride(key: string, value: unknown): string {
  if (key === "clinical_criteria_required" && value === true) {
    return "Clinical criteria required before submission";
  }
  if (key === "bundling_note") return String(value);
  if (typeof value === "boolean") {
    return `${key.replace(/_/g, " ")}: ${value ? "yes" : "no"}`;
  }
  return `${key.replace(/_/g, " ")}: ${String(value)}`;
}

function Section({
  icon: Icon,
  title,
  subtitle,
  right,
  children,
}: {
  icon: typeof Users;
  title: string;
  subtitle: string;
  right?: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <section className="mb-4 overflow-hidden rounded-xl border border-gray-200 bg-white">
      <div className="flex flex-wrap items-center gap-2 border-b border-gray-200 px-5 py-3">
        <Icon size={15} className="flex-shrink-0" style={{ color: GREEN }} />
        <div className="min-w-0 flex-1">
          <h2 className="text-[13.5px] font-semibold text-gray-900">{title}</h2>
          <p className="text-[11.5px] text-gray-500">{subtitle}</p>
        </div>
        {right}
      </div>
      {children}
    </section>
  );
}

export default function TenantAdmin() {
  const { effectiveUser, role, impersonate, isDemo } = useAuth();
  const navigate = useNavigate();

  const [toast, setToast] = useState<string | null>(null);
  const [users, setUsers] = useState<StaffUser[] | null>(null);
  const [practice, setPractice] = useState<Practice | null>(null);
  const [overlays, setOverlays] = useState<Overlay[] | null>(null);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState<string | null>(null);

  const tenantId = effectiveUser?.tenant_id ?? null;
  const tenantName = effectiveUser?.tenant_name ?? "Your practice";
  const tenantAddress = effectiveUser?.tenant_address ?? "—";
  // Only Accord staff may sign in as someone else. A practice owner
  // reading their coordinator's screen is a different decision with a
  // different audit trail, and /auth/impersonate refuses it anyway.
  const canViewAs = role === "accord_admin";

  useEffect(() => {
    if (!toast) return;
    const t = window.setTimeout(() => setToast(null), 2600);
    return () => window.clearTimeout(t);
  }, [toast]);

  useEffect(() => {
    if (isDemo) {
      setError("Sign in to administer a practice — demo mode holds no session.");
      return;
    }
    let cancelled = false;
    // tenant_id is sent for the Accord admin's benefit; for an owner the
    // API overrides it with their own. See require_practice_admin.
    const q = tenantId ? `?tenant_id=${encodeURIComponent(tenantId)}` : "";
    Promise.all([
      api.get<StaffUser[]>(`/auth/users${q}`),
      api.get<Practice>(`/admin/practice${q}`),
      api.get<Overlay[]>(`/admin/overlays${q}`),
    ])
      .then(([u, p, o]) => {
        if (cancelled) return;
        setUsers(u.data);
        setPractice(p.data);
        setOverlays(o.data);
      })
      .catch((err) => {
        if (cancelled) return;
        setError(
          statusOf(err) === 403
            ? "Practice owners only."
            : "Could not load practice administration.",
        );
      });
    return () => {
      cancelled = true;
    };
  }, [isDemo, tenantId]);

  async function viewAs(u: StaffUser) {
    setBusy(u.user_id);
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
      setToast(`Could not view as ${u.name}`);
      setBusy(null);
    }
  }

  const primaryPayer = practice?.payers[0];

  return (
    <div className="mx-auto max-w-5xl px-4 py-5 sm:px-6">
      <header className="mb-4">
        <h1 className="text-[19px] font-semibold text-gray-900">
          Practice administration
        </h1>
        <p className="text-[13px] text-gray-500">{tenantName}</p>
      </header>

      {error && (
        <p className="mb-4 rounded-xl border border-red-100 bg-red-50 px-4 py-3 text-[12.5px] text-red-700">
          {error}
        </p>
      )}

      {/* ── Staff ─────────────────────────────────────────────── */}
      <Section
        icon={Users}
        title="Users"
        subtitle={
          users
            ? `${users.length} active at ${tenantName}`
            : "Loading your staff…"
        }
      >
        {users && users.length > 0 && (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[620px] border-collapse text-left">
              <thead>
                <tr className="border-b border-gray-200 bg-gray-50">
                  {["Name", "Email", "Role", "Status", ""].map((h) => (
                    <th
                      key={h}
                      className="px-5 py-2 text-[10px] font-bold uppercase tracking-[0.1em] text-gray-500"
                    >
                      {h}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {users.map((u) => {
                  const self = u.user_id === effectiveUser?.user_id;
                  return (
                    <tr key={u.user_id} className="border-b border-gray-100">
                      <td className="px-5 py-2.5 text-[13px] font-medium text-gray-900">
                        {u.name}
                        {self && (
                          <span className="ml-1.5 text-[11px] font-normal text-gray-400">
                            (you)
                          </span>
                        )}
                      </td>
                      <td className="px-5 py-2.5 font-mono text-[11.5px] text-gray-500">
                        {u.email}
                      </td>
                      <td className="px-5 py-2.5 text-[12.5px] text-gray-700">
                        {ROLE_LABELS[u.role] ?? u.role}
                      </td>
                      <td className="px-5 py-2.5">
                        {/* Always "Active" — the API lists active users
                            only, so a deactivated account is absent
                            rather than shown greyed out. */}
                        <span className="inline-flex items-center gap-1.5 text-[12px] text-gray-700">
                          <span
                            aria-hidden="true"
                            className="h-1.5 w-1.5 rounded-full"
                            style={{ backgroundColor: "#16a34a" }}
                          />
                          Active
                        </span>
                      </td>
                      <td className="px-5 py-2.5">
                        <div className="flex flex-wrap justify-end gap-1.5">
                          {canViewAs && (
                            <button
                              type="button"
                              disabled={self || busy !== null}
                              onClick={() => void viewAs(u)}
                              className="inline-flex cursor-pointer items-center gap-1 rounded-lg border border-gray-300 bg-white px-2.5 py-1 text-[11.5px] font-medium text-gray-700 transition hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-40"
                            >
                              <Eye size={12} />
                              {busy === u.user_id ? "…" : "View as"}
                            </button>
                          )}
                          <button
                            type="button"
                            disabled={self}
                            onClick={() =>
                              setToast(
                                "Deactivating a user is not built yet — ask Accord support",
                              )
                            }
                            className="cursor-pointer rounded-lg border border-gray-300 bg-white px-2.5 py-1 text-[11.5px] font-medium text-gray-700 transition hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-40"
                          >
                            Deactivate
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
        {users && users.length === 0 && (
          <p className="px-5 py-6 text-[12.5px] text-gray-500">
            No active users at this practice.
          </p>
        )}
        {!users && !error && (
          <div className="animate-pulse space-y-2 px-5 py-5">
            <div className="h-3 w-1/3 rounded bg-gray-100" />
            <div className="h-3 w-2/3 rounded bg-gray-100" />
          </div>
        )}
      </Section>

      {/* ── Settings ──────────────────────────────────────────── */}
      <Section
        icon={Building2}
        title="Practice settings"
        subtitle="Read-only — editing is not built yet"
        right={
          <button
            type="button"
            onClick={() =>
              setToast("Editing practice settings is not built yet")
            }
            className="cursor-pointer rounded-lg border border-gray-300 bg-white px-3 py-1 text-[12px] font-medium text-gray-700 transition hover:bg-gray-50"
          >
            Edit
          </button>
        }
      >
        <dl className="grid gap-x-6 gap-y-3 px-5 py-4 sm:grid-cols-2">
          {[
            ["Practice name", tenantName],
            ["Address", tenantAddress],
            [
              "Primary payer",
              primaryPayer
                ? `${primaryPayer.payer_name} · ${primaryPayer.patients} cases`
                : "—",
            ],
            [
              "Providers",
              practice ? `${practice.providers.length} on file` : "—",
            ],
          ].map(([k, v]) => (
            <div key={k}>
              <dt className="text-[10px] font-bold uppercase tracking-[0.1em] text-gray-500">
                {k}
              </dt>
              <dd className="text-[13px] text-gray-900">{v}</dd>
            </div>
          ))}
        </dl>

        {practice && practice.providers.length > 0 && (
          <ul className="border-t border-gray-100 px-5 py-3">
            {practice.providers.map((p) => (
              <li
                key={p.provider_npi}
                className="flex flex-wrap items-center gap-2 py-1.5"
              >
                <span className="text-[13px] text-gray-900">
                  {p.name}
                  {p.credential ? `, ${p.credential}` : ""}
                </span>
                <span className="font-mono text-[11.5px] text-gray-500">
                  NPI {p.provider_npi}
                </span>
                <span className="rounded-full bg-gray-100 px-2 py-0.5 text-[10px] font-semibold text-gray-600">
                  {p.network_status.replace(/_/g, "-")}
                </span>
                {/* The one thing on this page worth a red badge: a
                    provider on the OIG exclusion list cannot bill
                    federal programmes, and every claim under that NPI
                    is recoverable. */}
                {p.oig_excluded && (
                  <span className="inline-flex items-center gap-1 rounded-full bg-red-50 px-2 py-0.5 text-[10px] font-semibold text-red-700">
                    <ShieldAlert size={11} />
                    OIG excluded
                  </span>
                )}
              </li>
            ))}
          </ul>
        )}
      </Section>

      {/* ── Overlay rules ─────────────────────────────────────── */}
      <Section
        icon={Building2}
        title="Custom coverage rules"
        subtitle="Rules specific to your practice — these override the payer's"
      >
        {overlays && overlays.length > 0 && (
          <ul className="divide-y divide-gray-100">
            {overlays.map((o, i) => (
              <li key={`${o.payer_id}-${o.cdt_code}-${i}`} className="px-5 py-3">
                <div className="flex flex-wrap items-center gap-2">
                  <span className="rounded bg-gray-100 px-1.5 py-0.5 font-mono text-[11px] font-semibold text-gray-700">
                    {o.cdt_code}
                  </span>
                  <span className="text-[13px] font-medium text-gray-900">
                    {o.procedure}
                  </span>
                  <span className="text-[12px] text-gray-500">
                    {o.payer_name}
                  </span>
                  {!o.active && (
                    <span className="rounded-full bg-gray-100 px-2 py-0.5 text-[10px] font-semibold text-gray-500">
                      Inactive
                    </span>
                  )}
                  <span className="ml-auto text-[11px] text-gray-400">
                    from {o.effective_from ?? "—"}
                    {o.effective_to ? ` to ${o.effective_to}` : ""}
                  </span>
                </div>
                <ul className="mt-1.5 space-y-0.5">
                  {Object.entries(o.rule_overrides).map(([k, v]) => (
                    <li key={k} className="text-[12.5px] text-gray-700">
                      • {describeOverride(k, v)}
                    </li>
                  ))}
                </ul>
                {o.reason && (
                  <p className="mt-1 text-[11.5px] italic text-gray-500">
                    {o.reason}
                  </p>
                )}
              </li>
            ))}
          </ul>
        )}
        {overlays && overlays.length === 0 && (
          <p className="px-5 py-6 text-[12.5px] text-gray-500">
            No custom rules configured. Your practice follows each
            payer&rsquo;s own policy.
          </p>
        )}
        {!overlays && !error && (
          <div className="animate-pulse px-5 py-5">
            <div className="h-3 w-1/2 rounded bg-gray-100" />
          </div>
        )}
      </Section>

      {toast && (
        <div
          role="status"
          className="fixed bottom-[76px] left-1/2 z-50 -translate-x-1/2 rounded-lg px-4 py-2 text-[12.5px] font-medium text-white shadow-lg lg:bottom-6"
          style={{ backgroundColor: "#111827" }}
        >
          {toast}
        </div>
      )}
    </div>
  );
}
