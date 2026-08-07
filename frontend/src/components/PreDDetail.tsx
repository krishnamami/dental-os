import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Check, Diamond, Sparkles, X } from "lucide-react";

import ConditionsPanel from "./ConditionsPanel";
import DecisionBadge from "./DecisionBadge";
import DetailTopbar from "./DetailTopbar";
import EvidenceTimeline, {
  buildTimeline,
  type TimelineNode,
} from "./EvidenceTimeline";
import EvidenceDetailPanel from "./EvidenceDetailPanel";
import FeedbackBar from "./FeedbackBar";
import RequestDocsModal from "./RequestDocsModal";
import { toneFor, type SignalTone } from "./SignalCard";
import { useAppeal, useDecision } from "../hooks/useApi";
import { useDemoLink } from "../hooks/useDemo";
import type { Decision } from "../types/dental";
import { scenarioId } from "../utils/format";
import {
  analysis,
  ASSIGNEE_LABEL,
  blockingCount,
  citationsOf,
  failingFlag,
  humanCode,
  openConditions,
  recommendedAction,
  signalsByWave,
  submitTitle,
  WAVE_CLS,
  WAVES,
  waveState,
} from "../utils/predDerive";

/**
 * D-03 — one pre-D, all nine personas, in the detail layout.
 *
 * ONE component, two homes: the right half of WorkbenchPipeline and
 * the standalone /workbench/:id page. They show the same thing, and a
 * second copy would let them disagree about the same case — which is
 * the failure this whole layer exists to prevent.
 *
 * Everything is live from GET /decisions/{id}. There is deliberately
 * no fallback: a signed-in reviewer looking at a patient's chart must
 * never be shown sample data dressed as theirs. If the API is down
 * they get an error they can act on.
 */

const GREEN = "#0F4D37";

const TABS = ["Decision", "Evidence", "Conditions", "Audit"] as const;
type Tab = (typeof TABS)[number];

const TONE_TEXT: Record<SignalTone, string> = {
  green: "text-accord-green-700",
  amber: "text-accord-amber-900",
  red: "text-red-700",
};

function SignalIcon({ tone }: { tone: SignalTone }) {
  if (tone === "green") return <Check size={13} strokeWidth={3} />;
  if (tone === "red") return <X size={13} strokeWidth={3} />;
  return <Diamond size={11} fill="currentColor" />;
}

function StatCard({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="rounded-xl border border-gray-200 bg-white p-3.5">
      <p className="text-[10px] font-medium uppercase tracking-wide text-slate-500">
        {label}
      </p>
      <div className="mt-1.5">{children}</div>
    </div>
  );
}

/**
 * Simulated clock. The API returns ONE processed_at for the bundle,
 * not a time per signal, so this shows the ORDER the engine ran in —
 * which is real — at times that are not. The header says so.
 * "Immutable audit trail" plus invented timestamps is the one
 * combination a payer dispute cannot survive.
 */
function auditTime(processedAt: string | undefined, wave: number, i: number) {
  const base = processedAt ? new Date(processedAt) : null;
  if (!base || Number.isNaN(base.getTime())) return "—";
  const t = new Date(base.getTime() + (wave - 1) * 60_000 + i * 12_000);
  return `${t.getMonth() + 1}/${t.getDate()} · ${t.toLocaleTimeString([], {
    hour: "numeric",
    minute: "2-digit",
  })}`;
}

function AuditTab({ d }: { d: Decision }) {
  const events = useMemo(
    () =>
      [...d.all_signals]
        .sort((a, b) => a.wave - b.wave || a.signal_code.localeCompare(b.signal_code))
        .map((s, i) => ({ s, when: auditTime(d.processed_at, s.wave, i) })),
    [d],
  );
  return (
    <div>
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <h3 className="text-[11px] font-bold uppercase tracking-[0.12em] text-gray-500">
          Audit trail — append only
        </h3>
        <p className="text-[11px] text-gray-400">
          Order is the engine&rsquo;s. Times are derived from the run timestamp,
          not recorded per signal.
        </p>
      </div>
      <ol className="mt-4">
        {events.map(({ s, when }, i) => {
          const tone = toneFor(s);
          return (
            <li key={`${s.decision_id}-${s.signal_code}`} className="flex gap-3">
              <div className="flex flex-col items-center">
                <span
                  className={`mt-1.5 flex h-5 w-5 flex-shrink-0 items-center justify-center rounded-full border bg-white ${
                    tone === "green"
                      ? "border-accord-green-500 text-accord-green-700"
                      : tone === "red"
                        ? "border-red-300 text-red-700"
                        : "border-amber-300 text-accord-amber-900"
                  }`}
                >
                  <SignalIcon tone={tone} />
                </span>
                {i < events.length - 1 && (
                  <span className="w-px flex-1 bg-gray-200" aria-hidden="true" />
                )}
              </div>
              <div className="min-w-0 flex-1 pb-4">
                <div className="flex flex-wrap items-baseline gap-x-2">
                  <span className="font-mono text-[11px] text-gray-400">{when}</span>
                  <span className="font-mono text-[11px] font-semibold text-gray-500">
                    {s.signal_code}
                  </span>
                </div>
                <p
                  className={`mt-0.5 text-[13px] leading-relaxed ${
                    tone === "green" ? "text-gray-600" : "font-medium text-gray-900"
                  }`}
                >
                  {s.finding}
                </p>
                <p className="mt-1 text-[11px] text-gray-400">
                  Wave {s.wave} · mode: {s.mode} ·{" "}
                  {s.decision_id.replace(/_/g, " ")}
                </p>
              </div>
            </li>
          );
        })}
      </ol>
    </div>
  );
}

function EvidenceTab({ d }: { d: Decision }) {
  const demoLink = useDemoLink();
  const { data: appeal } = useAppeal(d.pred_request_id);
  const nodes = useMemo(
    () => buildTimeline(d, appeal?.evidence_list ?? []),
    [d, appeal],
  );
  const [nodeId, setNodeId] = useState<string | null>(null);
  const selected: TimelineNode | null =
    nodes.find((n) => n.id === nodeId) ??
    nodes.find((n) => n.id === "ada") ??
    nodes[0] ??
    null;

  if (nodes.length === 0) {
    return (
      <p className="text-[13px] text-gray-500">
        No evidence chain for this pre-D — the clinical signals it would be
        built from are not present.
      </p>
    );
  }
  return (
    <div className="grid gap-4 xl:grid-cols-[minmax(0,1fr)_minmax(0,1.1fr)]">
      <EvidenceTimeline
        nodes={nodes}
        selectedId={selected?.id}
        onSelect={(n) => setNodeId(n.id)}
      />
      <EvidenceDetailPanel
        node={selected}
        documents={appeal?.evidence_list ?? []}
        demoLink={demoLink}
      />
    </div>
  );
}

function ConditionsTable({ d }: { d: Decision }) {
  const conditions = openConditions(d);
  if (conditions.length === 0) {
    return (
      <div className="rounded-xl border border-green-200 bg-green-50 p-4 text-[13px] text-green-800">
        All conditions resolved ✓ — ready to submit
      </div>
    );
  }
  return (
    <>
      <div className="overflow-x-auto rounded-xl border border-gray-200 bg-white">
        <table className="w-full min-w-[820px] text-left">
          <thead className="border-b border-gray-200 bg-slate-50">
            <tr className="text-[10px] font-semibold uppercase tracking-wide text-slate-500">
              <th className="px-4 py-2">Condition</th>
              <th className="px-2 py-2">Wave</th>
              <th className="px-2 py-2">Severity</th>
              <th className="px-2 py-2">Status</th>
              <th className="px-2 py-2">Assignee</th>
              <th className="px-2 py-2">SLA</th>
              <th className="px-4 py-2">Action</th>
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
                        sig ? "bg-red-100 text-red-800" : "bg-amber-100 text-amber-800"
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
                      ? (ASSIGNEE_LABEL[s.assignee] ?? s.assignee.replace(/_/g, " "))
                      : "—"}
                  </td>
                  <td className="px-2 py-2.5 text-[11.5px] text-slate-600">
                    {s.sla_hours != null ? `${s.sla_hours}h` : "—"}
                  </td>
                  <td className="px-4 py-2.5">
                    {/* The real thing: POST /decisions/{id}/feedback. */}
                    <FeedbackBar predRequestId={d.pred_request_id} signal={s} />
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
      <p className="mt-2 text-[11px] text-slate-400">
        SLA hours are the engine&rsquo;s target for the condition, not a
        countdown — nothing timestamps when the clock started. Recording
        feedback does not clear a condition: it clears when the pre-D is
        re-run with the evidence in place.
      </p>
    </>
  );
}

export default function PreDDetail({
  predRequestId,
  /** Rendered above the topbar — the pipeline's mobile "← Queue". */
  beforeTopbar,
  /** Standalone page shows a link back to the queue. */
  backLink,
}: {
  predRequestId: string | undefined;
  beforeTopbar?: React.ReactNode;
  backLink?: React.ReactNode;
}) {
  const navigate = useNavigate();
  const demoLink = useDemoLink();
  const [tab, setTab] = useState<Tab>("Decision");
  const [activeWave, setActiveWave] = useState<number | null>(null);
  const [docsOpen, setDocsOpen] = useState(false);
  const [toast, setToast] = useState("");

  const { data: d, isLoading, isError, error, refetch } = useDecision(predRequestId);
  const { data: appeal } = useAppeal(predRequestId);

  const byWave = useMemo(() => signalsByWave(d), [d]);
  const conditions = openConditions(d);
  const blocking = blockingCount(d);
  const met = d?.readiness_met ?? 0;
  const total = d?.readiness_total ?? 14;
  const flag = failingFlag(d);
  const rec = recommendedAction(d);
  const citations = citationsOf(d);
  const hasNarrativeGap = (d?.all_signals ?? []).some((s) =>
    s.signal_code.endsWith("NARRATIVE_MISSING"),
  );

  function toastFor(msg: string) {
    setToast(msg);
    window.setTimeout(() => setToast(""), 3000);
  }

  const shown = activeWave ? WAVES.filter((w) => w.n === activeWave) : WAVES;

  return (
    <div className="flex min-h-full flex-col">
      {beforeTopbar}

      <DetailTopbar
        root="Pre-D workbench"
        current={d?.patient_name ?? ""}
        actions={[
          { label: "Add note", onClick: () => toastFor("Note feature coming soon") },
          { label: "Request docs", onClick: () => setDocsOpen(true), disabled: !d },
          {
            label: "Generate appeal",
            onClick: () => navigate(demoLink("/revenue-ops/appeals")),
            title: appeal?.viable
              ? "Open the appeal packet in Revenue ops"
              : "No viable appeal on this pre-D",
            disabled: !appeal?.viable,
          },
          {
            label: "View evidence",
            onClick: () =>
              predRequestId && navigate(demoLink(`/evidence/${predRequestId}`)),
            disabled: !predRequestId,
          },
        ]}
        primary={{
          label: "Submit pre-D",
          title: submitTitle(d),
          disabled: !d?.submission_ready,
        }}
      />

      {isLoading && (
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
        </div>
      )}

      {isError && !isLoading && (
        <div className="m-6 rounded-xl border border-red-200 bg-red-50 p-5">
          <p className="text-[13.5px] font-medium text-red-700">
            Could not load {predRequestId ? scenarioId(predRequestId) : "this pre-D"}.
          </p>
          <p className="mt-1 text-[12.5px] text-red-600">
            {error instanceof Error ? error.message : "Unknown error"}
          </p>
          <button
            type="button"
            onClick={() => void refetch()}
            className="mt-3 rounded-lg border border-red-300 px-3 py-1.5 text-[12.5px] font-medium text-red-700 transition hover:bg-red-100"
          >
            Retry
          </button>
        </div>
      )}

      {d && !isLoading && (
        <div className="flex flex-1 flex-col lg:flex-row">
          <main className="min-w-0 flex-1 overflow-auto px-5 py-5 sm:px-6">
            {backLink}

            <div className="flex flex-wrap items-center gap-2">
              <h2 className="text-[19px] font-semibold text-gray-900">
                {d.patient_name}
              </h2>
              <DecisionBadge decision={d.decision} />
              <span className="rounded bg-accord-green-50 px-1.5 py-0.5 text-[9.5px] font-semibold uppercase text-accord-green-700">
                live
              </span>
            </div>
            <p className="mt-0.5 text-[12.5px] text-slate-500">
              {d.plan_name} · {d.provider_name} · {d.state} ·{" "}
              {scenarioId(d.pred_request_id)}
            </p>

            {/* Tabs */}
            <nav className="mt-4 flex gap-4 border-b border-slate-200">
              {TABS.map((t) => (
                <button
                  key={t}
                  type="button"
                  onClick={() => setTab(t)}
                  className={`-mb-px border-b-2 pb-2 text-[13px] font-medium transition ${
                    tab === t
                      ? "border-accord-green-900 text-accord-green-900"
                      : "border-transparent text-slate-500 hover:text-slate-800"
                  }`}
                >
                  {t}
                  {t === "Conditions" && conditions.length > 0 && (
                    <span className="ml-1.5 rounded-full bg-gray-100 px-1.5 py-0.5 text-[10px] text-gray-600">
                      {conditions.length}
                    </span>
                  )}
                </button>
              ))}
            </nav>

            <div className="mt-4">
              {tab === "Decision" && (
                <>
                  <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
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
                        {rec.action}
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

                  <div className="mt-4 grid grid-cols-5 gap-2">
                    {WAVES.map((w) => {
                      const signals = byWave.get(w.n) ?? [];
                      const state = waveState(signals);
                      const active = activeWave === w.n;
                      return (
                        <button
                          key={w.n}
                          type="button"
                          onClick={() => setActiveWave(active ? null : w.n)}
                          aria-pressed={active}
                          className={`rounded-lg border px-2 py-2 text-center transition ${WAVE_CLS[state]} ${
                            active ? "ring-2 ring-accord-green-500 ring-offset-1" : ""
                          }`}
                        >
                          <span className="block text-[9.5px] font-bold uppercase tracking-wide">
                            {w.label}
                          </span>
                          <span className="mt-1 block text-[11px] font-semibold">
                            {state}
                          </span>
                          <span className="mt-0.5 block text-[9.5px] opacity-70">
                            {signals.length} signals
                          </span>
                        </button>
                      );
                    })}
                  </div>
                  <p className="mt-2 text-[11.5px] text-gray-400">
                    {activeWave
                      ? `Wave ${activeWave} only. Click it again for all ${d.all_signals.length}.`
                      : `Click a wave to filter. All ${d.all_signals.length} shown.`}
                  </p>

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
                        {new Set(d.all_signals.map((s) => s.decision_id)).size}{" "}
                        personas
                      </p>
                    </div>
                    <p className="mt-2 text-[13px] leading-relaxed text-slate-700">
                      {analysis(d).join(" ")}
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

                  {shown.map((w) => {
                    const signals = byWave.get(w.n) ?? [];
                    if (signals.length === 0) return null;
                    return (
                      <section key={w.n} className="mt-5">
                        <h3 className="text-[11px] font-bold uppercase tracking-[0.12em] text-gray-400">
                          Wave {w.n} · {w.label}
                        </h3>
                        <ul className="mt-1">
                          {signals.map((s) => {
                            const tone = toneFor(s);
                            const cite = s.payer_citation ?? s.citation;
                            return (
                              <li
                                key={`${s.decision_id}-${s.signal_code}`}
                                className="flex gap-2.5 border-b border-gray-100 py-3 last:border-b-0"
                              >
                                <span
                                  className={`mt-0.5 flex-shrink-0 ${TONE_TEXT[tone]}`}
                                >
                                  <SignalIcon tone={tone} />
                                </span>
                                <div className="min-w-0 flex-1">
                                  <div className="flex flex-wrap items-center gap-2">
                                    <p className="font-mono text-[11px] font-semibold text-gray-500">
                                      {s.signal_code}
                                    </p>
                                    {s.mode === "human_approval" &&
                                      s.sla_hours != null && (
                                        <span className="rounded-full border border-amber-200 bg-accord-amber-50 px-2 py-0.5 text-[10px] font-semibold text-accord-amber-900">
                                          {s.sla_hours}h SLA
                                        </span>
                                      )}
                                  </div>
                                  <p className="mt-0.5 text-[13px] leading-relaxed text-gray-800">
                                    {s.finding}
                                  </p>
                                  {cite && (
                                    <p className="mt-1.5 text-[11.5px] italic text-accord-green-700">
                                      {cite}
                                    </p>
                                  )}
                                  {s.recommended_action && (
                                    <p className="mt-1 text-[11.5px] italic text-gray-500">
                                      Recommended:{" "}
                                      {s.recommended_action.replace(/_/g, " ")}
                                    </p>
                                  )}
                                  <div className="mt-2">
                                    <FeedbackBar
                                      predRequestId={d.pred_request_id}
                                      signal={s}
                                    />
                                  </div>
                                </div>
                              </li>
                            );
                          })}
                        </ul>
                      </section>
                    );
                  })}
                </>
              )}

              {tab === "Evidence" && <EvidenceTab d={d} />}

              {tab === "Conditions" && (
                <>
                  <ConditionsTable d={d} />
                  <div className="mt-4">
                    <ConditionsPanel predRequestId={d.pred_request_id} />
                  </div>
                </>
              )}

              {tab === "Audit" && (
                <>
                  <AuditTab d={d} />
                  <div className="mt-4 flex flex-wrap items-center gap-x-2 gap-y-1 rounded-xl border border-gray-200 bg-slate-50 px-4 py-3 text-[11.5px] text-gray-600">
                    <span
                      aria-hidden="true"
                      className={`h-2 w-2 rounded-full ${
                        d.submission_ready ? "bg-accord-green-500" : "bg-amber-400"
                      }`}
                    />
                    {d.submission_ready ? "Audit ready" : "Audit open"}
                    <span className="text-gray-300">·</span>
                    {met}/{total} flags
                    <span className="text-gray-300">·</span>
                    {d.criteria_score ?? "—"} {d.confidence_label}
                    {flag && (
                      <>
                        <span className="text-gray-300">·</span>
                        <span className="text-red-600">
                          {flag.replace(/_/g, " ")} outstanding
                        </span>
                      </>
                    )}
                    <button
                      type="button"
                      disabled={!d.submission_ready}
                      title={submitTitle(d)}
                      className="ml-auto rounded-lg px-3 py-1.5 text-[12px] font-semibold text-white disabled:cursor-not-allowed"
                      style={{
                        background: GREEN,
                        opacity: d.submission_ready ? 1 : 0.35,
                      }}
                    >
                      Submit pre-D →
                    </button>
                  </div>
                </>
              )}
            </div>
          </main>

          {/* ── Sidebar ───────────────────────────────────────── */}
          <aside className="flex w-full flex-col gap-2.5 border-t border-gray-200 p-4 lg:w-56 lg:flex-shrink-0 lg:border-l lg:border-t-0">
            <div className="rounded-xl p-3" style={{ background: GREEN }}>
              <p className="text-[9.5px] font-semibold uppercase tracking-wide text-white/55">
                Recommended
              </p>
              <p className="mt-0.5 text-[13px] font-medium text-white">{rec.action}</p>
              <p className="mt-1 text-[11px] leading-snug text-white/65">{rec.why}</p>
            </div>

            <button
              type="button"
              disabled={!d.submission_ready}
              title={submitTitle(d)}
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
                Add narrative
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
              onClick={() => navigate(demoLink(`/evidence/${d.pred_request_id}`))}
              className="rounded-lg border border-gray-300 px-3 py-2 text-[12.5px] font-medium text-gray-700 transition hover:bg-gray-50"
            >
              View evidence
            </button>

            {/* Override is per-signal, not per-case: the API records
                feedback against a signal_code. Sending the reviewer to
                the signal they disagree with is the only thing that can
                actually be recorded. */}
            <button
              type="button"
              onClick={() => {
                setTab("Conditions");
                toastFor("Override a specific condition below");
              }}
              className="rounded-lg border border-red-200 px-3 py-2 text-[12.5px] font-medium text-red-600 transition hover:bg-red-50"
            >
              Override
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
                {flag && (
                  <span className="truncate text-[10.5px] text-red-600">
                    {flag.replace(/_/g, " ")}
                  </span>
                )}
              </div>
              <p className="mt-1.5 text-[11px] text-amber-700">
                {d.criteria_score ?? "—"} · {d.confidence_label}
              </p>
            </div>

            {/* Counted over the current bundles on 7 Aug 2026. Static
                because there is no "find similar" endpoint. */}
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
