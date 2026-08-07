import { useMemo, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { Sparkles } from "lucide-react";

import CostTable from "../../../components/CostTable";
import DetailTopbar from "../../../components/DetailTopbar";
import RequestDocsModal from "../../../components/RequestDocsModal";
import { toneFor, type SignalTone } from "../../../components/SignalCard";
import { useAppeal, useDecision, usePatientSummary } from "../../../hooks/useApi";
import { useDemo, useDemoLink } from "../../../hooks/useDemo";
import type { Decision, PatientSummary, Signal } from "../../../types/dental";
import { formatCurrency } from "../../../utils/format";

/**
 * E-01b — one pre-D, from the front desk's side of it.
 *
 * Two calls: GET /decisions/{id} for the reasoning and
 * /patient-summary for the money. Everything on this page is derived
 * from those two payloads — there is no literal number below.
 *
 * ── Two things the engine's shape forces ─────────────────────────────
 *
 * `mode` is only ever 'recommend' or 'human_approval'. There is no
 * auto_execute, so "this wave passed" cannot be read off a mode
 * string; it comes from toneFor(), the same rule the workbench and the
 * landing page use. One source, or a wave reads green here and amber
 * three inches lower.
 *
 * The waves are NOT verify/coverage/clinical/documents/decision. Per
 * WAVE_CONFIG the clinical reviewer runs in wave 2 beside coverage,
 * wave 3 is documentation and wave 4 is the verdict. Labelling 3
 * "Clinical" files every documentation gap under a clinical heading.
 */

const GREEN = "#0F4D37";

const WAVES: Array<{ n: number; label: string }> = [
  { n: 1, label: "Verify" },
  { n: 2, label: "Coverage" },
  { n: 3, label: "Documents" },
  { n: 4, label: "Decision" },
  { n: 5, label: "Appeal" },
];

type WaveState = "Passed" | "Review" | "Blocked" | "Pending";

const WAVE_CLS: Record<WaveState, string> = {
  Passed: "border-green-200 bg-green-50 text-green-800",
  Review: "border-amber-200 bg-amber-50 text-amber-800",
  Blocked: "border-red-200 bg-red-50 text-red-800",
  Pending: "border-gray-200 bg-gray-50 text-gray-400",
};

function waveState(signals: Signal[]): WaveState {
  if (signals.length === 0) return "Pending";
  const tones = new Set<SignalTone>(signals.map(toneFor));
  if (tones.has("red")) return "Blocked";
  if (tones.has("amber")) return "Review";
  return "Passed";
}

/** Signals that want a human: a signature, or a named next step. */
function openConditions(d: Decision): Signal[] {
  return d.all_signals.filter(
    (s) => s.mode === "human_approval" || Boolean(s.recommended_action),
  );
}

function humanCode(code: string): string {
  return code.replace(/_/g, " ").toLowerCase().replace(/^./, (c) => c.toUpperCase());
}

function num(v: unknown): number | undefined {
  return typeof v === "number" ? v : undefined;
}

/** The headline next step, chosen by what is actually blocking. */
function recommendedAction(d: Decision): { action: string; why: string } {
  const has = (c: string) => d.all_signals.some((s) => s.signal_code === c);
  if (has("DOC_NARRATIVE_MISSING") || has("CLINICAL_NARRATIVE_MISSING")) {
    return {
      action: "Add narrative",
      why: "Upload an independent bone-graft note to unblock D7953 and enable submission",
    };
  }
  if (has("COVERAGE_BUNDLING_CONFLICT")) {
    return {
      action: "Resolve bundling",
      why: "Document the two procedures separately under the payer's own criteria",
    };
  }
  if (has("DOC_XRAY_MISSING")) {
    return { action: "Upload X-ray", why: "The clinical check cannot run without it" };
  }
  if (d.submission_ready) {
    return { action: "Ready to submit", why: "Every readiness flag is satisfied" };
  }
  return {
    action: "Review open conditions",
    why: "Submission is blocked until each one is cleared",
  };
}

/**
 * The analysis paragraph, assembled from signal `data` — never written
 * as prose and never inferred. Each clause appears only if the signal
 * that carries its numbers is present, so this cannot describe a case
 * the engine did not report.
 */
function analysis(d: Decision, ps?: PatientSummary): string[] {
  const by = (c: string) => d.all_signals.find((s) => s.signal_code === c);
  const out: string[] = [];

  const elig = by("ELIGIBILITY_VERIFIED");
  if (elig) {
    const max = num(elig.data.annual_max_remaining);
    out.push(
      `${d.patient_name} is eligible${
        max !== undefined ? `, with ${formatCurrency(max)} of the annual maximum remaining` : ""
      }.`,
    );
  }

  const crit = by("CLINICAL_CRITERIA_MET");
  if (crit) {
    const bl = num(crit.data.bone_loss_mm);
    const th = num(crit.data.threshold);
    if (bl !== undefined && th !== undefined) {
      out.push(`Bone loss of ${bl}mm clears the ${th}mm threshold for the implant.`);
    }
  }

  const bundle = by("COVERAGE_BUNDLING_CONFLICT");
  if (bundle) {
    const primary = bundle.data.primary;
    const bundled = bundle.data.bundled;
    const section = bundle.data.policy_section;
    out.push(
      `Submission is held by a bundling conflict between ${primary} and ${bundled}` +
        (section ? ` under ${d.plan_name} ${section}` : "") +
        `. It is separable with documentation.`,
    );
  }

  const down = by("COVERAGE_DOWNGRADE_APPLIED");
  if (down) {
    const billed = down.data.billed_code;
    const paid = down.data.paid_code;
    const pays = num(down.data.patient_pays);
    out.push(
      `${billed} is reimbursed at the ${paid} rate` +
        (pays !== undefined ? `, leaving ${formatCurrency(pays)} to the patient` : "") +
        `.`,
    );
  }

  if (ps) {
    out.push(
      `Total ${formatCurrency(ps.summary.total_provider_charges)} charged, ` +
        `${formatCurrency(ps.summary.total_patient_pays)} to the patient after ` +
        `${formatCurrency(ps.summary.total_in_network_savings)} of in-network discount.`,
    );
  }

  if (out.length === 0) out.push("No findings on this pre-D.");
  return out;
}

const ASSIGNEE_LABEL: Record<string, string> = {
  front_desk: "Front desk",
  billing: "Billing",
  dentist: "Dentist",
  provider: "Provider",
  dso_manager: "DSO manager",
};

function StatCard({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <div className="rounded-xl border border-gray-200 bg-white p-3.5">
      <p className="text-[10px] font-medium uppercase tracking-wide text-slate-500">
        {label}
      </p>
      <div className="mt-1.5">{children}</div>
    </div>
  );
}

function Skeleton() {
  return (
    <div className="animate-pulse space-y-4 p-6">
      <div className="h-6 w-56 rounded bg-gray-100" />
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        {[0, 1, 2, 3].map((i) => (
          <div key={i} className="h-20 rounded-xl bg-gray-100" />
        ))}
      </div>
      <div className="grid grid-cols-5 gap-2">
        {[0, 1, 2, 3, 4].map((i) => (
          <div key={i} className="h-14 rounded-lg bg-gray-100" />
        ))}
      </div>
      <div className="h-28 rounded-xl bg-gray-100" />
      <div className="h-40 rounded-xl bg-gray-100" />
    </div>
  );
}

export default function CoverageDetail() {
  const { id } = useParams<{ id: string }>();
  const { isDemo, demoPredId } = useDemo();
  const demoLink = useDemoLink();
  const navigate = useNavigate();

  const [docsOpen, setDocsOpen] = useState(false);
  const [toast, setToast] = useState("");

  const predRequestId = id ?? (isDemo ? demoPredId : undefined);
  const decisionQ = useDecision(predRequestId);
  const summaryQ = usePatientSummary(predRequestId);
  const { data: appeal } = useAppeal(predRequestId);

  const d = decisionQ.data;
  const ps = summaryQ.data;

  const byWave = useMemo(() => {
    const map = new Map<number, Signal[]>();
    for (const w of WAVES) map.set(w.n, []);
    for (const s of d?.all_signals ?? []) map.get(s.wave)?.push(s);
    return map;
  }, [d]);

  const conditions = d ? openConditions(d) : [];
  const blocking = conditions.filter((s) => s.mode === "human_approval").length;
  const met = d?.readiness_met ?? 0;
  const total = d?.readiness_total ?? 14;
  const failing = Object.entries(d?.readiness_flags ?? {}).find(([, v]) => !v)?.[0];
  const rec = d ? recommendedAction(d) : null;
  const citations = [
    ...new Set(
      (d?.all_signals ?? [])
        .flatMap((s) => [s.citation, s.payer_citation])
        .filter((c): c is string => Boolean(c)),
    ),
  ];
  const hasNarrativeGap = (d?.all_signals ?? []).some((s) =>
    s.signal_code.endsWith("NARRATIVE_MISSING"),
  );

  const isLoading = decisionQ.isLoading || summaryQ.isLoading;
  const isError = decisionQ.isError || summaryQ.isError;

  function toastFor(msg: string) {
    setToast(msg);
    window.setTimeout(() => setToast(""), 3000);
  }

  return (
    <div className="flex min-h-full flex-col">
      <DetailTopbar
        root="Coverage"
        current={d?.patient_name ?? ps?.patient_name ?? ""}
        actions={[
          {
            label: "Add note",
            onClick: () => toastFor("Note feature coming soon"),
          },
          { label: "Request docs", onClick: () => setDocsOpen(true), disabled: !d },
          { label: "Print summary", onClick: () => window.print(), disabled: !ps },
          {
            label: "View full pre-D",
            onClick: () =>
              predRequestId && navigate(demoLink(`/workbench/${predRequestId}`)),
            disabled: !predRequestId,
          },
        ]}
        primary={{
          label: "Submit pre-D",
          title: d?.submission_ready
            ? "Demo only — submission runs in the product"
            : `${met}/${total} flags${failing ? ` — ${failing.replace(/_/g, " ")} outstanding` : ""}`,
          disabled: !d?.submission_ready,
        }}
      />

      {isLoading && <Skeleton />}

      {isError && !isLoading && (
        <div className="m-6 rounded-xl border border-red-200 bg-red-50 p-5">
          <p className="text-[13.5px] font-medium text-red-700">
            Could not load patient data.
          </p>
          <button
            type="button"
            onClick={() => {
              void decisionQ.refetch();
              void summaryQ.refetch();
            }}
            className="mt-3 rounded-lg border border-red-300 px-3 py-1.5 text-[12.5px] font-medium text-red-700 transition hover:bg-red-100"
          >
            Retry
          </button>
        </div>
      )}

      {d && !isLoading && (
        <div className="flex flex-1 flex-col lg:flex-row">
          {/* ── Main ──────────────────────────────────────────── */}
          <main className="min-w-0 flex-1 overflow-auto px-5 py-5 sm:px-6">
            <h2 className="text-[19px] font-semibold text-gray-900">
              {d.patient_name}
            </h2>
            <p className="mt-0.5 text-[12.5px] text-slate-500">
              {d.plan_name} · {d.provider_name} · {d.state}
              {ps?.procedures.length
                ? ` · ${ps.procedures.map((p) => p.cdt_code).join(", ")}`
                : ""}
              {ps?.procedures.find((p) => p.tooth_number)
                ? ` · tooth #${ps.procedures.find((p) => p.tooth_number)?.tooth_number}`
                : ""}
            </p>

            {/* A. Four numbers */}
            <div className="mt-4 grid grid-cols-2 gap-3 lg:grid-cols-4">
              <StatCard label="Pre-D status">
                <p
                  className={`text-[17px] font-semibold capitalize ${
                    d.decision === "approved"
                      ? "text-green-700"
                      : d.decision === "denied"
                        ? "text-red-700"
                        : "text-amber-700"
                  }`}
                >
                  {d.decision}
                </p>
              </StatCard>
              <StatCard label="Recommended action">
                <p className="text-[14px] font-semibold text-gray-900">
                  {rec?.action}
                </p>
              </StatCard>
              <StatCard label="Submission readiness">
                <p
                  className={`text-[17px] font-semibold ${
                    met === total ? "text-green-700" : "text-amber-700"
                  }`}
                >
                  {met}/{total}
                </p>
              </StatCard>
              <StatCard label="At a glance">
                <p className="text-[12px] text-amber-700">
                  ● {conditions.length} conditions open
                </p>
                <p className="mt-0.5 text-[12px] text-red-700">
                  ● {blocking} need a signature
                </p>
              </StatCard>
            </div>

            {/* B. Five waves */}
            <div className="mt-4 grid grid-cols-5 gap-2">
              {WAVES.map((w) => {
                const signals = byWave.get(w.n) ?? [];
                const state = waveState(signals);
                return (
                  <div
                    key={w.n}
                    className={`rounded-lg border px-2 py-2 text-center ${WAVE_CLS[state]}`}
                  >
                    <p className="text-[9.5px] font-bold uppercase tracking-wide">
                      {w.label}
                    </p>
                    <p className="mt-1 text-[11px] font-semibold">{state}</p>
                    <p className="mt-0.5 text-[9.5px] opacity-70">
                      {signals.length} signals
                    </p>
                  </div>
                );
              })}
            </div>

            {/* C. Accord analysis */}
            <section
              className="mt-4 rounded-xl p-4"
              style={{ background: "#f0f9f4", border: "0.5px solid #86efac" }}
            >
              <div className="flex flex-wrap items-center justify-between gap-2">
                <p
                  className="flex items-center gap-1.5 text-[11px] font-semibold"
                  style={{ color: "#16a34a" }}
                >
                  <Sparkles size={12} />
                  Accord analysis
                </p>
                <p className="text-[11px]" style={{ color: "#16a34a" }}>
                  {d.criteria_score ?? "—"} criteria score ·{" "}
                  {d.all_signals.length} signals ·{" "}
                  {new Set(d.all_signals.map((s) => s.decision_id)).size} personas
                </p>
              </div>
              <p className="mt-2 text-[13px] leading-relaxed text-slate-700">
                {analysis(d, ps).join(" ")}
              </p>
              {citations.length > 0 && (
                <div className="mt-2.5 flex flex-wrap gap-1.5">
                  {citations.map((c) => (
                    <span
                      key={c}
                      className="rounded-full border border-green-200 bg-white px-2 py-0.5 text-[10.5px] font-medium text-green-800"
                    >
                      {c}
                    </span>
                  ))}
                </div>
              )}
            </section>

            {/* D. Conditions */}
            <section className="mt-5">
              <div className="flex flex-wrap items-center gap-2">
                <h3 className="text-[14px] font-semibold text-gray-900">
                  Needs your attention
                </h3>
                <span className="rounded-full bg-red-100 px-2 py-0.5 text-[10.5px] font-semibold text-red-800">
                  {blocking} blocking
                </span>
                <span className="rounded-full bg-amber-100 px-2 py-0.5 text-[10.5px] font-semibold text-amber-800">
                  {conditions.length} open
                </span>
              </div>

              {conditions.length === 0 ? (
                <div className="mt-3 rounded-xl border border-green-200 bg-green-50 p-4 text-[13px] text-green-800">
                  All conditions resolved ✓ — ready to submit
                </div>
              ) : (
                <div className="mt-3 overflow-x-auto rounded-xl border border-gray-200 bg-white">
                  <table className="w-full min-w-[820px] text-left">
                    <thead className="border-b border-gray-200 bg-slate-50">
                      <tr className="text-[10px] font-semibold uppercase tracking-wide text-slate-500">
                        <th className="px-4 py-2">Condition</th>
                        <th className="px-2 py-2">Wave</th>
                        <th className="px-2 py-2">Severity</th>
                        <th className="px-2 py-2">Status</th>
                        <th className="px-2 py-2">Assignee</th>
                        <th className="px-2 py-2">SLA</th>
                        <th className="px-4 py-2" />
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-100">
                      {conditions.map((s) => {
                        const sig = s.mode === "human_approval";
                        return (
                          <tr key={`${s.decision_id}-${s.signal_code}`}>
                            <td className="px-4 py-2.5">
                              <p className="text-[12.5px] font-semibold text-gray-900">
                                {humanCode(s.signal_code)}
                              </p>
                              <p className="mt-0.5 max-w-[420px] text-[11.5px] leading-snug text-slate-500">
                                {s.finding}
                              </p>
                              {(s.payer_citation ?? s.citation) && (
                                <p className="mt-1 text-[11px] italic text-green-700">
                                  {s.payer_citation ?? s.citation}
                                </p>
                              )}
                            </td>
                            <td className="px-2 py-2.5 text-[11.5px] text-slate-600">
                              {WAVES.find((w) => w.n === s.wave)?.label ?? s.wave}
                            </td>
                            <td className="px-2 py-2.5">
                              <span
                                className={`rounded-full px-2 py-0.5 text-[10.5px] font-semibold ${
                                  sig
                                    ? "bg-red-100 text-red-800"
                                    : "bg-amber-100 text-amber-800"
                                }`}
                              >
                                {sig ? "Blocking" : "Needs review"}
                              </span>
                            </td>
                            <td className="px-2 py-2.5">
                              <span className="rounded-full bg-amber-50 px-2 py-0.5 text-[10.5px] font-medium text-amber-700">
                                Open
                              </span>
                            </td>
                            <td className="px-2 py-2.5 text-[11.5px] capitalize text-slate-600">
                              {s.assignee
                                ? (ASSIGNEE_LABEL[s.assignee] ??
                                  s.assignee.replace(/_/g, " "))
                                : "—"}
                            </td>
                            <td className="px-2 py-2.5 text-[11.5px] text-slate-600">
                              {s.sla_hours != null ? `${s.sla_hours}h` : "—"}
                            </td>
                            <td className="px-4 py-2.5 text-right">
                              <button
                                type="button"
                                onClick={() => setDocsOpen(true)}
                                className="rounded-lg border border-gray-300 px-2.5 py-1 text-[11.5px] font-medium text-gray-700 transition hover:bg-gray-50"
                              >
                                {s.signal_code.startsWith("DOC_")
                                  ? "Request"
                                  : "Resolve"}
                              </button>
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              )}
              <p className="mt-2 text-[11px] text-slate-400">
                SLA hours are the engine&rsquo;s target for the condition, not a
                countdown — nothing timestamps when the clock started.
              </p>
            </section>

            {/* E. Cost */}
            {ps && (
              <section className="mt-5">
                <h3 className="mb-3 text-[14px] font-semibold text-gray-900">
                  Cost breakdown
                </h3>
                <CostTable procedures={ps.procedures} summary={ps.summary} />
              </section>
            )}
          </main>

          {/* ── Sidebar ───────────────────────────────────────── */}
          <aside className="flex w-full flex-col gap-2.5 border-t border-gray-200 p-4 lg:w-56 lg:flex-shrink-0 lg:border-l lg:border-t-0">
            {rec && (
              <div className="rounded-xl p-3" style={{ background: GREEN }}>
                <p className="text-[9.5px] font-semibold uppercase tracking-wide text-white/55">
                  Recommended
                </p>
                <p className="mt-0.5 text-[13px] font-medium text-white">
                  {rec.action}
                </p>
                <p className="mt-1 text-[11px] leading-snug text-white/65">
                  {rec.why}
                </p>
              </div>
            )}

            <button
              type="button"
              disabled={!d.submission_ready}
              title={
                d.submission_ready
                  ? "Demo only — submission runs in the product"
                  : `${met}/${total} flags${failing ? ` — ${failing.replace(/_/g, " ")} outstanding` : ""}`
              }
              className="rounded-lg px-3 py-2 text-[12.5px] font-semibold text-white disabled:cursor-not-allowed"
              style={{ background: GREEN, opacity: d.submission_ready ? 1 : 0.35 }}
            >
              Submit pre-D
            </button>

            {hasNarrativeGap && (
              <button
                type="button"
                onClick={() => toastFor("Narrative upload is not wired yet")}
                className="rounded-lg border border-gray-300 px-3 py-2 text-[12.5px] font-medium text-gray-700 transition hover:bg-gray-50"
              >
                Upload narrative
              </button>
            )}

            {appeal?.viable && (
              <button
                type="button"
                onClick={() => navigate(demoLink("/revenue-ops/appeals"))}
                className="rounded-lg border border-gray-300 px-3 py-2 text-[12.5px] font-medium text-gray-700 transition hover:bg-gray-50"
              >
                Generate appeal
              </button>
            )}

            <button
              type="button"
              onClick={() => window.print()}
              className="rounded-lg border border-gray-300 px-3 py-2 text-[12.5px] font-medium text-gray-700 transition hover:bg-gray-50"
            >
              Print summary
            </button>

            <button
              type="button"
              onClick={() => toastFor("Note feature coming soon")}
              className="rounded-lg border border-gray-300 px-3 py-2 text-[12.5px] font-medium text-gray-700 transition hover:bg-gray-50"
            >
              Add note
            </button>

            <hr className="my-1 border-gray-200" />

            <div>
              <p className="text-[9.5px] font-semibold uppercase tracking-wide text-slate-500">
                Submission readiness
              </p>
              <div className="mt-1.5 h-[7px] w-full overflow-hidden rounded bg-gray-200">
                <div
                  className="h-full rounded"
                  style={{
                    width: `${total ? (met / total) * 100 : 0}%`,
                    background: GREEN,
                  }}
                />
              </div>
              <div className="mt-1 flex items-baseline justify-between gap-2">
                <span className="text-[11px] text-slate-600">
                  {met}/{total} flags
                </span>
                {failing && (
                  <span className="truncate text-[10.5px] text-red-600">
                    {failing.replace(/_/g, " ")}
                  </span>
                )}
              </div>
              <p className="mt-1.5 text-[11px] text-amber-700">
                {d.criteria_score ?? "—"} · {d.confidence_label}
              </p>
            </div>

            {ps && (
              <>
                <hr className="my-1 border-gray-200" />
                <div className="space-y-1 text-[11.5px]">
                  <div className="flex justify-between gap-2">
                    <span className="text-slate-500">Provider charges</span>
                    <span className="text-slate-800">
                      {formatCurrency(ps.summary.total_provider_charges)}
                    </span>
                  </div>
                  <div className="flex justify-between gap-2">
                    <span className="text-slate-500">In-network savings</span>
                    <span className="text-green-700">
                      ({formatCurrency(ps.summary.total_in_network_savings)})
                    </span>
                  </div>
                  <div className="flex justify-between gap-2">
                    <span className="text-slate-500">Patient pays</span>
                    <span className="font-semibold text-slate-900">
                      {formatCurrency(ps.summary.total_patient_pays)}
                    </span>
                  </div>
                </div>
              </>
            )}

            {/* Counted from the current bundles on 7 Aug 2026, not
                guessed. Static because there is no "find similar"
                endpoint — the number moves when the corpus does. */}
            {d.all_signals.some(
              (s) => s.signal_code === "COVERAGE_BUNDLING_CONFLICT",
            ) && (
              <p className="mt-1 text-center text-[10.5px] leading-snug text-slate-400">
                5 other pre-Ds at this practice carry the same bundling conflict
              </p>
            )}
          </aside>
        </div>
      )}

      {docsOpen && d && (
        <RequestDocsModal
          patientName={d.patient_name}
          onClose={() => setDocsOpen(false)}
          onSend={() => {
            setDocsOpen(false);
            toastFor(`Document request queued for ${d.patient_name} ✓`);
          }}
        />
      )}

      {toast && (
        <div
          role="status"
          className="fixed bottom-[76px] left-1/2 z-50 -translate-x-1/2 rounded-lg bg-slate-900 px-4 py-2.5 text-[12.5px] font-medium text-white shadow-lg lg:bottom-6"
        >
          {toast}
        </div>
      )}
    </div>
  );
}
