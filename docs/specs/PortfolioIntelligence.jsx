import { useState } from "react";
import { AlertTriangle, ArrowRight, Building2, Info, TrendingDown } from "lucide-react";

const C = {
  green: "#0F4D37",
  greenSoft: "#E7F0EC",
  greenLine: "#B9D3C8",
  navy: "#0B1220",
  amber: "#8A5A0B",
  amberSoft: "#FDF3DF",
  amberLine: "#EBD5A6",
  ink: "#0F172A",
  muted: "#64748B",
  faint: "#94A3B8",
  line: "#E2E8F0",
  page: "#F7F8FA",
  slateSoft: "#F1F5F9",
};

const FONT = "'Plus Jakarta Sans', system-ui, -apple-system, sans-serif";

// Shape mirrors GET /api/portfolio/summary
const DATA = {
  summary: {
    total_practices: 2,
    total_pre_ds: 45,
    total_approved: 16,
    total_denied: 8,
    total_pended: 21,
    overall_approval_rate: 0.356,
    total_patient_responsibility: 55650.31,
  },
  practices: [
    {
      tenant_id: "suwanee_smiles",
      practice_name: "Suwanee Smiles Dental",
      address: "3155 Peachtree Pkwy Ste 120, Suwanee GA 30024",
      total_pre_ds: 40,
      approved: 13,
      denied: 7,
      pended: 20,
      approval_rate: 0.325,
      avg_criteria_score: 0.846,
      total_contracted: 82124.37,
      total_insurance_pays: 29536.96,
      total_patient_pays: 52587.42,
    },
    {
      tenant_id: "tampa_smiles",
      practice_name: "Tampa Bay Smiles",
      address: "4321 Bay Shore Blvd Ste 200, Tampa FL 33611",
      total_pre_ds: 5,
      approved: 3,
      denied: 1,
      pended: 1,
      approval_rate: 0.6,
      avg_criteria_score: 0.792,
      total_contracted: 9840.0,
      total_insurance_pays: 3777.0,
      total_patient_pays: 3062.89,
    },
  ],
  top_denial_reasons: [
    { condition_code: "COVERAGE_PRED_REQUIRED", tenant_id: "suwanee_smiles", frequency: 21 },
    { condition_code: "CLINICAL_XRAY_REQUIRED", tenant_id: "suwanee_smiles", frequency: 14 },
    { condition_code: "CLINICAL_NARRATIVE_REQUIRED", tenant_id: "suwanee_smiles", frequency: 11 },
    { condition_code: "COVERAGE_BUNDLING_CONFLICT", tenant_id: "suwanee_smiles", frequency: 6 },
    { condition_code: "CLINICAL_XRAY_REQUIRED", tenant_id: "tampa_smiles", frequency: 3 },
    { condition_code: "COVERAGE_PRED_REQUIRED", tenant_id: "tampa_smiles", frequency: 2 },
  ],
  payer_performance: [
    { tenant_id: "suwanee_smiles", payer_name: "Delta Dental PPO", total: 36, approved: 9, denied: 7 },
    { tenant_id: "suwanee_smiles", payer_name: "Guardian DPO", total: 4, approved: 4, denied: 0 },
    { tenant_id: "tampa_smiles", payer_name: "Humana DPPO", total: 2, approved: 2, denied: 0 },
    { tenant_id: "tampa_smiles", payer_name: "Delta Dental PPO", total: 3, approved: 1, denied: 1 },
  ],
};

// Plain-English framing for signal codes. An owner reads causes, not codes.
const CAUSE = {
  COVERAGE_PRED_REQUIRED: {
    label: "Pre-authorization not filed before treatment",
    owner: "Front desk and billing",
    fix: "Payer requires a pre-D on these codes. Cases sit until someone files.",
  },
  CLINICAL_XRAY_REQUIRED: {
    label: "Radiograph missing from the record",
    owner: "Clinical",
    fix: "Capturable chairside. Once the patient leaves it costs a second visit.",
  },
  CLINICAL_NARRATIVE_REQUIRED: {
    label: "No clinical narrative on file",
    owner: "Clinical",
    fix: "The dentist has to write it. Cases can't be submitted without one.",
  },
  COVERAGE_BUNDLING_CONFLICT: {
    label: "Payer bundles codes billed separately",
    owner: "Billing",
    fix: "Appealable with a separation narrative, but it delays payment.",
  },
};

const MIN_N = 10; // below this, a rate is noise

const money = (n) =>
  "$" + Math.round(n).toLocaleString("en-US");

function RateCell({ approved, total }) {
  const thin = total < MIN_N;
  const pct = Math.round((approved / total) * 100);
  return (
    <div>
      <span style={{ fontWeight: 600, color: thin ? C.faint : C.ink }}>
        {thin ? "—" : `${pct}%`}
      </span>
      <span className="text-xs ml-1.5" style={{ color: C.muted }}>
        {approved}/{total}
      </span>
    </div>
  );
}

export default function PortfolioIntelligence() {
  const [tab, setTab] = useState("compare");
  const { summary, practices, top_denial_reasons, payer_performance } = DATA;

  const thinPractices = practices.filter((p) => p.total_pre_ds < MIN_N);

  // Biggest single cause across the group, by frequency
  const byCause = {};
  top_denial_reasons.forEach((r) => {
    byCause[r.condition_code] = byCause[r.condition_code] || { total: 0, rows: [] };
    byCause[r.condition_code].total += r.frequency;
    byCause[r.condition_code].rows.push(r);
  });
  const causes = Object.entries(byCause).sort((a, b) => b[1].total - a[1].total);
  const nameOf = (tid) => practices.find((p) => p.tenant_id === tid)?.practice_name || tid;
  const shortOf = (tid) => nameOf(tid).split(" ")[0];

  return (
    <div style={{ fontFamily: FONT, background: C.page, minHeight: "100vh", color: C.ink }}>
      <div style={{ background: C.navy }} className="px-4 md:px-8 py-3">
        <div className="flex items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <div
              className="flex items-center justify-center rounded"
              style={{ background: C.green, width: 28, height: 28, color: "white", fontWeight: 700 }}
            >
              A
            </div>
            <span style={{ color: "white", fontWeight: 600 }}>accord</span>
            <span
              className="hidden sm:inline text-xs px-2 py-1 rounded"
              style={{ color: "rgba(255,255,255,0.75)", background: "rgba(255,255,255,0.12)" }}
            >
              Portfolio
            </span>
          </div>
          <span className="text-sm" style={{ color: "white" }}>
            Dr. Patel
          </span>
        </div>
      </div>

      <div className="px-4 md:px-8 py-6 max-w-6xl mx-auto">
        <div className="mb-5">
          <h1 className="text-2xl" style={{ fontWeight: 700 }}>
            Good morning, Dr. Patel
          </h1>
          <p className="text-sm mt-1" style={{ color: C.muted }}>
            {summary.total_practices} practices · {summary.total_pre_ds} pre-Ds in flight
          </p>
        </div>

        {/* The money question first */}
        <div className="rounded-xl p-5 mb-5" style={{ background: "white", border: `1px solid ${C.line}` }}>
          <div className="flex items-start gap-4 flex-wrap">
            <div className="flex-1" style={{ minWidth: 220 }}>
              <div className="text-xs" style={{ color: C.muted, letterSpacing: "0.04em" }}>
                SITTING WITH PAYERS
              </div>
              <div className="text-3xl mt-1" style={{ fontWeight: 700, color: C.amber }}>
                {money(summary.total_patient_responsibility)}
              </div>
              <div className="text-sm mt-1" style={{ color: C.muted }}>
                {summary.total_pended} pended · {summary.total_denied} denied · across {summary.total_practices} practices
              </div>
            </div>
            <div style={{ width: 1, background: C.line, alignSelf: "stretch" }} className="hidden md:block" />
            <div className="flex-1" style={{ minWidth: 220 }}>
              <div className="text-xs" style={{ color: C.muted, letterSpacing: "0.04em" }}>
                CLEARED WITHOUT INTERVENTION
              </div>
              <div className="text-3xl mt-1" style={{ fontWeight: 700, color: C.green }}>
                {summary.total_approved}
                <span className="text-lg" style={{ color: C.muted, fontWeight: 500 }}>
                  {" "}
                  of {summary.total_pre_ds}
                </span>
              </div>
              <div className="text-sm mt-1" style={{ color: C.muted }}>
                The rest needed a person, or are still waiting on one
              </div>
            </div>
          </div>
        </div>

        {/* Tabs */}
        <div className="flex gap-2 mb-5 flex-wrap">
          {[
            ["compare", "Compare practices"],
            ["causes", "What's holding cases up"],
            ["payers", "By payer"],
          ].map(([k, label]) => (
            <button
              key={k}
              onClick={() => setTab(k)}
              className="px-3 py-2 rounded-lg text-sm"
              style={{
                background: tab === k ? C.green : "white",
                color: tab === k ? "white" : C.ink,
                border: `1px solid ${tab === k ? C.green : C.line}`,
                fontWeight: tab === k ? 600 : 500,
              }}
            >
              {label}
            </button>
          ))}
        </div>

        {/* Tab 1 — comparison, not cards */}
        {tab === "compare" && (
          <div className="rounded-xl overflow-hidden" style={{ background: "white", border: `1px solid ${C.line}` }}>
            <div className="overflow-x-auto">
              <table className="w-full text-sm" style={{ minWidth: 620 }}>
                <thead>
                  <tr style={{ background: C.slateSoft }}>
                    <th className="text-left px-4 py-3" style={{ fontWeight: 600 }}>
                      Practice
                    </th>
                    <th className="text-right px-4 py-3" style={{ fontWeight: 600 }}>
                      Pre-Ds
                    </th>
                    <th className="text-right px-4 py-3" style={{ fontWeight: 600 }}>
                      Cleared
                    </th>
                    <th className="text-right px-4 py-3" style={{ fontWeight: 600 }}>
                      Waiting
                    </th>
                    <th className="text-right px-4 py-3" style={{ fontWeight: 600 }}>
                      Patient owes
                    </th>
                    <th className="text-right px-4 py-3" style={{ fontWeight: 600 }}>
                      Evidence quality
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {practices.map((p) => (
                    <tr key={p.tenant_id} style={{ borderTop: `1px solid ${C.line}` }}>
                      <td className="px-4 py-3.5">
                        <div className="flex items-start gap-2">
                          <Building2 size={15} style={{ color: C.muted, marginTop: 2, flexShrink: 0 }} />
                          <div>
                            <div style={{ fontWeight: 600 }}>{p.practice_name}</div>
                            <div className="text-xs mt-0.5" style={{ color: C.muted }}>
                              {p.address.split(",").slice(-1)[0].trim()}
                            </div>
                          </div>
                        </div>
                      </td>
                      <td className="text-right px-4 py-3.5">{p.total_pre_ds}</td>
                      <td className="text-right px-4 py-3.5">
                        <RateCell approved={p.approved} total={p.total_pre_ds} />
                      </td>
                      <td className="text-right px-4 py-3.5">{p.pended + p.denied}</td>
                      <td className="text-right px-4 py-3.5">{money(p.total_patient_pays)}</td>
                      <td className="text-right px-4 py-3.5">
                        {p.total_pre_ds < MIN_N ? (
                          <span style={{ color: C.faint }}>—</span>
                        ) : (
                          Math.round(p.avg_criteria_score * 100) + "%"
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {thinPractices.length > 0 && (
              <div
                className="px-4 py-3 flex gap-2.5 text-sm"
                style={{ background: C.slateSoft, borderTop: `1px solid ${C.line}`, color: C.muted }}
              >
                <Info size={15} style={{ flexShrink: 0, marginTop: 2 }} />
                <span>
                  {thinPractices.map((p) => p.practice_name).join(" and ")} shows no rate — fewer than {MIN_N} pre-Ds.
                  A percentage off {thinPractices[0].total_pre_ds} cases moves 20 points on one decision, so it would
                  compare badly against a practice with {practices[0].total_pre_ds}.
                </span>
              </div>
            )}
          </div>
        )}

        {/* Tab 2 — causes, not codes */}
        {tab === "causes" && (
          <div className="space-y-3">
            {causes.map(([code, { total, rows }]) => {
              const meta = CAUSE[code] || { label: code, owner: "—", fix: "" };
              const concentrated = rows.length === 1 || rows[0].frequency / total > 0.75;
              return (
                <div key={code} className="rounded-xl p-5" style={{ background: "white", border: `1px solid ${C.line}` }}>
                  <div className="flex items-start justify-between gap-4 flex-wrap">
                    <div style={{ maxWidth: 460 }}>
                      <div style={{ fontWeight: 600 }}>{meta.label}</div>
                      <p className="text-sm mt-1" style={{ color: C.muted }}>
                        {meta.fix}
                      </p>
                      <div className="text-xs mt-2" style={{ color: C.muted }}>
                        Owned by {meta.owner}
                      </div>
                    </div>
                    <div className="text-right">
                      <div className="text-2xl" style={{ fontWeight: 700 }}>
                        {total}
                      </div>
                      <div className="text-xs" style={{ color: C.muted }}>
                        cases affected
                      </div>
                    </div>
                  </div>

                  <div className="mt-4 space-y-2">
                    {rows
                      .sort((a, b) => b.frequency - a.frequency)
                      .map((r) => (
                        <div key={r.tenant_id} className="flex items-center gap-3">
                          <span className="text-xs" style={{ color: C.muted, width: 72 }}>
                            {shortOf(r.tenant_id)}
                          </span>
                          <div style={{ flex: 1, height: 8, background: C.slateSoft, borderRadius: 99 }}>
                            <div
                              style={{
                                width: `${(r.frequency / total) * 100}%`,
                                height: "100%",
                                background: C.green,
                                borderRadius: 99,
                              }}
                            />
                          </div>
                          <span className="text-xs" style={{ color: C.muted, width: 24, textAlign: "right" }}>
                            {r.frequency}
                          </span>
                        </div>
                      ))}
                  </div>

                  {concentrated && rows.length > 0 && (
                    <div
                      className="mt-4 rounded-lg p-3 flex gap-2.5 text-sm"
                      style={{ background: C.amberSoft, border: `1px solid ${C.amberLine}`, color: C.amber }}
                    >
                      <TrendingDown size={15} style={{ flexShrink: 0, marginTop: 2 }} />
                      <span>
                        Concentrated at {nameOf(rows[0].tenant_id)}. A pattern in one location is usually a habit, not a
                        payer rule — worth asking the team there rather than changing policy everywhere.
                      </span>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}

        {/* Tab 3 — payer performance, counts not rates */}
        {tab === "payers" && (
          <div className="rounded-xl overflow-hidden" style={{ background: "white", border: `1px solid ${C.line}` }}>
            <div className="overflow-x-auto">
              <table className="w-full text-sm" style={{ minWidth: 560 }}>
                <thead>
                  <tr style={{ background: C.slateSoft }}>
                    <th className="text-left px-4 py-3" style={{ fontWeight: 600 }}>
                      Payer
                    </th>
                    <th className="text-left px-4 py-3" style={{ fontWeight: 600 }}>
                      Practice
                    </th>
                    <th className="text-right px-4 py-3" style={{ fontWeight: 600 }}>
                      Pre-Ds
                    </th>
                    <th className="text-right px-4 py-3" style={{ fontWeight: 600 }}>
                      Approved
                    </th>
                    <th className="text-right px-4 py-3" style={{ fontWeight: 600 }}>
                      Denied
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {payer_performance
                    .slice()
                    .sort((a, b) => b.total - a.total)
                    .map((r, i) => (
                      <tr key={i} style={{ borderTop: `1px solid ${C.line}` }}>
                        <td className="px-4 py-3" style={{ fontWeight: 500 }}>
                          {r.payer_name}
                        </td>
                        <td className="px-4 py-3" style={{ color: C.muted }}>
                          {shortOf(r.tenant_id)}
                        </td>
                        <td className="text-right px-4 py-3">{r.total}</td>
                        <td className="text-right px-4 py-3">{r.approved}</td>
                        <td className="text-right px-4 py-3" style={{ color: r.denied > 0 ? C.amber : C.muted }}>
                          {r.denied}
                        </td>
                      </tr>
                    ))}
                </tbody>
              </table>
            </div>
            <div
              className="px-4 py-3 flex gap-2.5 text-sm"
              style={{ background: C.slateSoft, borderTop: `1px solid ${C.line}`, color: C.muted }}
            >
              <Info size={15} style={{ flexShrink: 0, marginTop: 2 }} />
              <span>
                Counts, not rates. Most cells here are a handful of cases — a percentage would look authoritative and
                mean very little.
              </span>
            </div>
          </div>
        )}

        {/* What he can't do, said plainly */}
        <div
          className="mt-5 rounded-xl p-4 flex gap-3"
          style={{ background: C.greenSoft, border: `1px solid ${C.greenLine}` }}
        >
          <AlertTriangle size={16} style={{ color: C.green, flexShrink: 0, marginTop: 2 }} />
          <div className="text-sm" style={{ color: C.green }}>
            <span style={{ fontWeight: 600 }}>This view is read-only.</span> Individual patient records stay with the
            team treating them. To act on anything here, ask the practice — the conditions above name who owns each one.
          </div>
        </div>
      </div>
    </div>
  );
}
