import { useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import { RefreshCw } from "lucide-react";

import { useHealth, usePortfolio } from "../../../hooks/useApi";
import { useDemoLink } from "../../../hooks/useDemo";
import { formatPercent } from "../../../utils/format";
import UserDirectory from "../../../components/UserDirectory";

/**
 * H-10 — Accord admin.
 *
 * Reads /health and /portfolio/summary. Everything that WRITES —
 * onboarding, catalogue refresh, tenant edit — is disabled and says so:
 * those are dental-simulator seed scripts today
 * (seed_new_tenants.py, seed_coverage_rules_expanded.py), not API
 * endpoints, and a button that appears to create a tenant but does not
 * is worse than no button.
 */
const TABS = [
  { id: "tenants", label: "Tenants", path: "/admin" },
  { id: "onboard", label: "Onboard", path: "/admin/onboard" },
  { id: "catalogue", label: "Catalogue", path: "/admin/catalogue" },
  { id: "health", label: "Health", path: "/admin/health" },
] as const;

type TabId = (typeof TABS)[number]["id"];

function tabFromPath(pathname: string): TabId {
  const match = TABS.filter(
    (t) => t.path !== "/admin" && pathname.startsWith(t.path),
  )[0];
  return match?.id ?? "tenants";
}

/** "Buckhead Dental" -> "buckhead_dental". Matches the tenant_id format
 *  already in the database (suwanee_smiles, tampa_smiles). */
export function toTenantId(name: string): string {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .slice(0, 50);
}

const STATES = ["GA", "FL", "TX", "NC", "SC", "TN", "AL"];
const PAYERS = [
  "delta_dental",
  "cigna",
  "metlife",
  "aetna_dmo",
  "humana_dpo",
  "guardian_dpo",
];

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border border-gray-200 bg-white p-4">
      <p className="text-[11px] uppercase tracking-wide text-gray-500">
        {label}
      </p>
      <p className="mt-1 text-[21px] font-semibold leading-none text-gray-900">
        {value}
      </p>
    </div>
  );
}

function Dot({ ok }: { ok: boolean }) {
  return (
    <span
      className={`inline-block h-2 w-2 flex-shrink-0 rounded-full ${
        ok ? "bg-accord-green-500" : "bg-red-500"
      }`}
    />
  );
}

export default function AdminConsole() {
  const { pathname } = useLocation();
  const navigate = useNavigate();
  const demoLink = useDemoLink();
  const active = tabFromPath(pathname);

  const { data: health, isLoading, refetch, dataUpdatedAt } = useHealth();
  const { data: portfolio } = usePortfolio();

  const [name, setName] = useState("");
  const [notice, setNotice] = useState("");

  const field =
    "w-full rounded-lg border border-gray-300 px-3 py-2 text-[13px] text-gray-900 placeholder-gray-400 focus:border-accord-green-500 focus:outline-none focus:ring-1 focus:ring-accord-green-500";
  const label = "mb-1 block text-[12px] font-medium text-gray-700";

  return (
    <div className="p-4 sm:p-6">
      <div className="flex gap-1.5 overflow-x-auto pb-1">
        {TABS.map((t) => (
          <button
            key={t.id}
            type="button"
            onClick={() => navigate(demoLink(t.path))}
            aria-current={active === t.id ? "page" : undefined}
            className={`flex-shrink-0 rounded-lg px-3 py-1.5 text-[12.5px] font-medium transition ${
              active === t.id
                ? "bg-accord-green-900 text-white"
                : "border border-gray-200 bg-white text-gray-600 hover:bg-gray-50"
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* ── Tenants ────────────────────────────────────────────── */}
      {active === "tenants" && (
        <div className="mt-4 space-y-4">
          <UserDirectory />

          <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
            <Metric label="Active tenants" value={String(health?.tenants ?? "—")} />
            <Metric
              label="Total scenarios"
              value={String(health?.simulator_scenarios ?? "—")}
            />
            <Metric
              label="Payers supported"
              value={String(health?.payers_supported ?? "—")}
            />
            <Metric
              label="Fee-schedule states"
              value={String(health?.states_supported ?? "—")}
            />
          </div>

          <section className="overflow-hidden rounded-xl border border-gray-200 bg-white">
            <header className="border-b border-gray-200 bg-gray-50 px-4 py-3">
              <h2 className="text-[13.5px] font-semibold text-gray-900">
                Tenants
              </h2>
            </header>
            <ul className="divide-y divide-gray-100">
              {(portfolio?.practices ?? []).map((p) => (
                <li
                  key={p.tenant_id}
                  className="flex flex-wrap items-center justify-between gap-3 px-4 py-3"
                >
                  <div className="flex min-w-0 items-start gap-2.5">
                    <span className="mt-1.5">
                      <Dot ok />
                    </span>
                    <div className="min-w-0">
                      <p className="text-[13px] font-medium text-gray-900">
                        {p.practice_name}
                        <span className="ml-2 font-mono text-[11px] font-normal text-gray-400">
                          {p.tenant_id}
                        </span>
                      </p>
                      <p className="mt-0.5 text-[11.5px] text-gray-500">
                        {p.address} · {p.total_pre_ds} pre-Ds ·{" "}
                        {formatPercent(p.approval_rate)} approved
                      </p>
                    </div>
                  </div>
                  <div className="flex flex-shrink-0 gap-1.5">
                    {["View", "Edit"].map((a) => (
                      <button
                        key={a}
                        type="button"
                        onClick={() =>
                          setNotice(
                            "Tenant management is a seed script today (seed_new_tenants.py), not an API.",
                          )
                        }
                        className="rounded-lg border border-gray-300 px-2.5 py-1 text-[12px] font-medium text-gray-600 hover:bg-gray-50"
                      >
                        {a}
                      </button>
                    ))}
                  </div>
                </li>
              ))}
            </ul>
            {notice && (
              <p className="border-t border-gray-100 px-4 py-2.5 text-[12px] text-accord-amber-900">
                {notice}
              </p>
            )}
          </section>
        </div>
      )}

      {/* ── Onboard ────────────────────────────────────────────── */}
      {active === "onboard" && (
        <form
          onSubmit={(e) => {
            e.preventDefault();
            setNotice(
              "Tenant onboarding runs through dental-simulator's seed scripts — there is no create-tenant endpoint yet.",
            );
          }}
          className="mt-4 max-w-xl space-y-3.5 rounded-xl border border-gray-200 bg-white p-5"
        >
          <div>
            <label className={label} htmlFor="practice">
              Practice name *
            </label>
            <input
              id="practice"
              required
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Buckhead Dental"
              className={field}
            />
            <p className="mt-1 text-[11.5px] text-gray-500">
              Tenant ID:{" "}
              <span className="font-mono text-gray-700">
                {toTenantId(name) || "—"}
              </span>
            </p>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className={label} htmlFor="state">
                State
              </label>
              <select id="state" className={field}>
                {STATES.map((s) => (
                  <option key={s}>{s}</option>
                ))}
              </select>
            </div>
            <div>
              <label className={label} htmlFor="payer">
                Primary payer
              </label>
              <select id="payer" className={field}>
                {PAYERS.map((p) => (
                  <option key={p}>{p}</option>
                ))}
              </select>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className={label} htmlFor="npi">
                Provider NPI *
              </label>
              <input id="npi" required placeholder="1134534266" className={field} />
            </div>
            <div>
              <label className={label} htmlFor="phone">
                Practice phone *
              </label>
              <input id="phone" required placeholder="470-291-4593" className={field} />
            </div>
          </div>

          <div>
            <label className={label} htmlFor="address">
              Full address *
            </label>
            <input
              id="address"
              required
              placeholder="3155 Peachtree Pkwy Ste 120, Suwanee GA 30024"
              className={field}
            />
          </div>

          <button
            type="submit"
            className="rounded-lg bg-accord-green-900 px-4 py-2 text-[13px] font-semibold text-white transition hover:bg-accord-green-700"
          >
            Create tenant
          </button>

          {notice && (
            <p className="text-[12px] text-accord-amber-900">{notice}</p>
          )}
          <p className="text-[11px] leading-relaxed text-gray-400">
            A real onboarding also needs an NPPES-verified NPI. The two demo
            practices carry placeholder NPIs and are not verified — see
            seed_new_tenants.py.
          </p>
        </form>
      )}

      {/* ── Catalogue ──────────────────────────────────────────── */}
      {active === "catalogue" && (
        <section className="mt-4 overflow-hidden rounded-xl border border-gray-200 bg-white">
          <header className="flex items-center justify-between gap-3 border-b border-gray-200 bg-gray-50 px-4 py-3">
            <h2 className="text-[13.5px] font-semibold text-gray-900">
              Catalogue status
            </h2>
            <button
              type="button"
              onClick={() =>
                setNotice(
                  "Catalogue refresh runs as a seed script; there is no endpoint for it.",
                )
              }
              className="rounded-lg border border-gray-300 px-2.5 py-1 text-[12px] font-medium text-gray-600 hover:bg-gray-50"
            >
              Refresh catalogue
            </button>
          </header>
          <ul className="divide-y divide-gray-100">
            {[
              {
                name: "coverage_rules",
                detail: "1,086 rows · v2.0 · 181 CDT × 6 payers",
                live: false,
              },
              {
                name: "fee_schedules",
                detail: `1,176 rows · v2.0 · 28 priced codes × 6 payers × ${health?.states_supported ?? 7} states`,
                live: false,
              },
              {
                name: "payers",
                detail: `${health?.payers_supported ?? "—"} active`,
                live: true,
              },
              { name: "ada_guidelines", detail: "10 rows · CDT-2026", live: false },
              { name: "bundling_rules", detail: "20 rows · v1.0", live: false },
              {
                name: "conditions_library",
                detail: "50 rows · v1.0",
                live: false,
              },
            ].map((c) => (
              <li
                key={c.name}
                className="flex flex-wrap items-center justify-between gap-2 px-4 py-2.5"
              >
                <span className="font-mono text-[12px] text-gray-700">
                  {c.name}
                </span>
                <span className="flex items-center gap-2 text-[12px] text-gray-500">
                  {c.detail}
                  <span
                    className={`rounded px-1.5 py-0.5 text-[10px] font-semibold uppercase ${
                      c.live
                        ? "bg-accord-green-50 text-accord-green-700"
                        : "bg-gray-100 text-gray-500"
                    }`}
                  >
                    {c.live ? "live" : "static"}
                  </span>
                </span>
              </li>
            ))}
          </ul>
          <p className="border-t border-gray-100 px-4 py-2.5 text-[11px] text-gray-400">
            Only the payer count comes from /health. Row counts are recorded
            from the last seed run — /health does not expose
            catalogue_versions, which is what would make this table live.
          </p>
          {notice && (
            <p className="border-t border-gray-100 px-4 py-2.5 text-[12px] text-accord-amber-900">
              {notice}
            </p>
          )}
        </section>
      )}

      {/* ── Health ─────────────────────────────────────────────── */}
      {active === "health" && (
        <section className="mt-4 overflow-hidden rounded-xl border border-gray-200 bg-white">
          <header className="flex items-center justify-between gap-3 border-b border-gray-200 bg-gray-50 px-4 py-3">
            <div className="flex items-center gap-2">
              <Dot ok={health?.status === "healthy"} />
              <h2 className="text-[13.5px] font-semibold text-gray-900">
                {health?.status === "healthy" ? "Healthy" : "Degraded"}
              </h2>
              <span className="text-[11.5px] text-gray-500">
                {health?.service} v{health?.version}
              </span>
            </div>
            <button
              type="button"
              onClick={() => refetch()}
              disabled={isLoading}
              className="inline-flex items-center gap-1.5 rounded-lg border border-gray-300 px-2.5 py-1 text-[12px] font-medium text-gray-600 hover:bg-gray-50 disabled:opacity-50"
            >
              <RefreshCw size={12} className={isLoading ? "animate-spin" : ""} />
              Refresh
            </button>
          </header>

          <dl className="grid grid-cols-2 gap-x-4 gap-y-3 px-4 py-4 sm:grid-cols-4">
            {[
              ["Tenants", health?.tenants],
              ["Scenarios", health?.simulator_scenarios],
              ["Decision outputs", health?.decision_outputs],
              ["Persona bundles", health?.persona_bundles],
              ["Payers", health?.payers_supported],
              ["States", health?.states_supported],
            ].map(([k, v]) => (
              <div key={String(k)}>
                <dt className="text-[10.5px] uppercase tracking-wide text-gray-500">
                  {k}
                </dt>
                <dd className="mt-0.5 text-[15px] font-semibold tabular-nums text-gray-900">
                  {v ?? "—"}
                </dd>
              </div>
            ))}
          </dl>

          <ul className="divide-y divide-gray-100 border-t border-gray-100">
            {[
              ["Simulator DB (dental)", health?.simulator_db],
              ["OS DB (dental_os)", health?.os_db],
            ].map(([k, v]) => (
              <li
                key={String(k)}
                className="flex items-center justify-between gap-3 px-4 py-2.5"
              >
                <span className="text-[12.5px] text-gray-700">{k}</span>
                <span className="flex items-center gap-1.5 text-[12px] text-gray-600">
                  <Dot ok={v === "connected"} />
                  {v ?? "unknown"}
                </span>
              </li>
            ))}
          </ul>

          <p className="border-t border-gray-100 px-4 py-2.5 text-[11px] text-gray-400">
            Last checked{" "}
            {dataUpdatedAt
              ? new Date(dataUpdatedAt).toLocaleTimeString()
              : "—"}{" "}
            · polls every 60s
          </p>
        </section>
      )}
    </div>
  );
}
