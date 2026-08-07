import { useMemo, useState } from "react";
import { ArrowLeft, ArrowRight, Check, Diamond, X } from "lucide-react";

import ConditionsPanel from "../../../components/ConditionsPanel";
import DecisionBadge from "../../../components/DecisionBadge";
import EvidenceTimeline, {
  buildTimeline,
  type TimelineNode,
} from "../../../components/EvidenceTimeline";
import EvidenceDetailPanel from "../../../components/EvidenceDetailPanel";
import ReadinessBadge from "../../../components/ReadinessBadge";
import { toneFor, type SignalTone } from "../../../components/SignalCard";
import { useAppeal, useConditions, useDecision } from "../../../hooks/useApi";
import { useDemoLink } from "../../../hooks/useDemo";
import type { Decision, Signal } from "../../../types/dental";
import { formatCurrencyShort, scenarioId } from "../../../utils/format";

/**
 * D-10 — the workbench as a split panel.
 *
 * Left: the day's queue. Right: everything about the selected pre-D.
 * `selectedId` is the only state that matters — it drives all three
 * queries, and nothing on the right is reachable except through it.
 *
 * ── On the queue being static ────────────────────────────────────────
 *
 * There is still no list endpoint. dental-os answers per pre-D, so a
 * genuinely live queue would be eight round trips on mount — and in
 * production there is no API behind CloudFront at all, so all eight
 * would fail and the fallback is what every visitor actually sees.
 *
 * So the rows below are a SNAPSHOT, not an invention: every name,
 * decision, dollar figure and payer was read from
 * `GET /decisions/{id}` and `/patient-summary` on 2026-08-06 and copied
 * verbatim. When the API is reachable the selected row's header
 * upgrades to live values, and the "live"/"snapshot" chip says which
 * you are looking at. If a snapshot value ever disagrees with the live
 * one, the snapshot is stale and this list is what needs updating.
 */

type Status = "approved" | "pended" | "denied";

interface QueueRow {
  id: string;
  patient: string;
  finding: string;
  charges: number;
  payer: string;
  status: Status;
  /** Open conditions on the case, from the same snapshot. */
  open: number;
  /** Of those, how many need a signature (mode === human_approval). */
  blocking: number;
}

const QUEUE: QueueRow[] = [
  {
    id: "PRED-SIM-DA-A01",
    patient: "James Mitchell",
    finding: "Bundling conflict · D7953 + D6010",
    charges: 5550,
    payer: "Delta Dental PPO",
    status: "pended",
    open: 8,
    blocking: 3,
  },
  {
    id: "PRED-SIM-DA-B04",
    patient: "Carlos Rivera",
    finding: "Appeal viable · 65% success probability",
    charges: 3750,
    payer: "Delta Dental PPO",
    status: "pended",
    open: 7,
    blocking: 3,
  },
  {
    id: "PRED-SIM-DA-C10",
    patient: "John Miller",
    finding: "OIG excluded provider",
    charges: 1190,
    payer: "Delta Dental PPO",
    status: "pended",
    open: 6,
    blocking: 5,
  },
  {
    id: "PRED-SIM-DA-B01",
    patient: "Patricia Johnson",
    finding: "Hard exclusion · implants not covered",
    charges: 4600,
    payer: "Delta Dental PPO",
    status: "denied",
    open: 7,
    blocking: 2,
  },
  {
    id: "PRED-SIM-DA-D04",
    patient: "Linda Taylor",
    finding: "Crown D2740 → D2750 downgrade",
    charges: 1650,
    payer: "Delta Dental PPO",
    status: "approved",
    open: 4,
    blocking: 2,
  },
  {
    id: "PRED-SIM-DA-U01",
    patient: "Robert Thompson",
    finding: "Clean · D1110 prophylaxis",
    charges: 150,
    payer: "Delta Dental PPO",
    status: "approved",
    open: 3,
    blocking: 1,
  },
  {
    id: "PRED-SIM-DA-U02",
    patient: "Maria Santos",
    finding: "Clean · D0274 bitewings",
    charges: 85,
    payer: "Delta Dental PPO",
    status: "approved",
    open: 4,
    blocking: 1,
  },
  {
    id: "PRED-SIM-DA-U03",
    patient: "Kevin Lee",
    finding: "Clean · D2391 composite",
    charges: 175,
    payer: "Cigna DPPO",
    status: "approved",
    open: 3,
    blocking: 1,
  },
];

/**
 * The five waves, labelled from WAVE_CONFIG in dental-os
 * core/cron/runner.py — NOT from what the wave numbers sound like.
 *
 * The mapping is easy to get wrong, and getting it wrong puts
 * documentation findings under a "Clinical" heading in a clinical
 * product. The engine's actual order is:
 *
 *   1  eligibility_analyst · provider_credentialing · fraud_integrity
 *   2  coverage_analyst · clinical_reviewer
 *   3  documentation_reviewer
 *   4  pre_d_assessment
 *   5  appeal_specialist · dso_portfolio_manager
 *
 * Note wave 2 carries the CLINICAL reviewer and wave 3 is documents —
 * not the other way round.
 */
const WAVES: Array<{ wave: number; label: string; tip: string }> = [
  { wave: 1, label: "VERIFY", tip: "Eligibility, provider credentialing, fraud" },
  { wave: 2, label: "COVERAGE", tip: "Payer rules, fee schedules, clinical criteria" },
  { wave: 3, label: "DOCUMENTS", tip: "Completeness and narrative" },
  { wave: 4, label: "DECISION", tip: "Final pre-D assessment" },
  { wave: 5, label: "APPEAL", tip: "Appeal viability and portfolio impact" },
];

type WaveState = "passed" | "review" | "blocked" | "pending";

/**
 * A wave's state is the worst state of its signals.
 *
 * There is no `auto_execute` in this domain — the API only ever sends
 * `recommend` or `human_approval` — so "passed" means every signal came
 * back green under the SAME rule the rest of the app uses (toneFor),
 * not that a mode string matched. One source for tone is the point:
 * a wave cannot read green here and amber three inches lower.
 */
function waveState(signals: Signal[]): WaveState {
  if (signals.length === 0) return "pending";
  const tones = new Set<SignalTone>(signals.map(toneFor));
  if (tones.has("red")) return "blocked";
  if (tones.has("amber")) return "review";
  return "passed";
}

const WAVE_STYLE: Record<WaveState, { box: string; text: string }> = {
  passed: {
    box: "border-accord-green-500 bg-accord-green-50",
    text: "text-accord-green-700",
  },
  review: { box: "border-amber-300 bg-accord-amber-50", text: "text-accord-amber-900" },
  blocked: { box: "border-red-300 bg-red-50", text: "text-red-700" },
  pending: { box: "border-gray-200 bg-gray-50", text: "text-gray-400" },
};

function WaveIcon({ state }: { state: WaveState }) {
  if (state === "passed") return <Check size={14} strokeWidth={3} />;
  if (state === "review") return <Diamond size={12} fill="currentColor" />;
  if (state === "blocked") return <X size={14} strokeWidth={3} />;
  return <span className="text-[15px] leading-none">·</span>;
}

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

const DOT: Record<Status, string> = {
  approved: "bg-accord-green-500",
  pended: "bg-amber-400",
  denied: "bg-red-500",
};

// ── Left panel ───────────────────────────────────────────────────────

function QueueItem({
  row,
  selected,
  onSelect,
}: {
  row: QueueRow;
  selected: boolean;
  onSelect: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onSelect}
      aria-current={selected ? "true" : undefined}
      className={`block w-full border-l-[3px] px-3 py-3 text-left transition ${
        selected
          ? "border-l-accord-green-500 bg-accord-green-50"
          : "border-l-transparent hover:bg-gray-50"
      }`}
    >
      <span className="flex items-start gap-2">
        <span
          aria-hidden="true"
          className={`mt-[5px] h-2 w-2 flex-shrink-0 rounded-full ${DOT[row.status]}`}
        />
        <span className="min-w-0 flex-1">
          <span className="flex items-baseline justify-between gap-2">
            <span className="truncate text-[13.5px] font-medium text-gray-900">
              {row.patient}
            </span>
            <span className="flex-shrink-0 text-[11px] capitalize text-gray-400">
              {row.status}
            </span>
          </span>
          <span className="mt-0.5 block truncate text-[12px] text-gray-500">
            {row.finding}
          </span>
          <span className="mt-1 block text-[11px] text-gray-400">
            {formatCurrencyShort(row.charges)} · {row.payer}
            {row.blocking > 0 && ` · ${row.blocking} need a signature`}
          </span>
        </span>
      </span>
    </button>
  );
}

function CountCell({
  value,
  label,
  tone,
}: {
  value: number;
  label: string;
  tone: string;
}) {
  return (
    <div>
      <p className={`text-[20px] font-semibold leading-none ${tone}`}>{value}</p>
      <p className="mt-1 text-[10px] uppercase tracking-wide text-gray-500">
        {label}
      </p>
    </div>
  );
}

// ── Decision tab ─────────────────────────────────────────────────────

function SignalRow({ signal }: { signal: Signal }) {
  const tone = toneFor(signal);
  const citation = signal.payer_citation ?? signal.citation;
  return (
    <li className="flex gap-2.5 border-b border-gray-100 py-3 last:border-b-0">
      <span className={`mt-0.5 flex-shrink-0 ${TONE_TEXT[tone]}`}>
        <SignalIcon tone={tone} />
      </span>
      <div className="min-w-0">
        <p className="font-mono text-[11px] font-semibold text-gray-500">
          {signal.signal_code}
        </p>
        <p className="mt-0.5 text-[13px] leading-relaxed text-gray-800">
          {signal.finding}
        </p>
        {citation && (
          <p className="mt-1.5 text-[11.5px] italic text-accord-green-700">
            {citation}
          </p>
        )}
        {signal.recommended_action && (
          <p className="mt-1 text-[11.5px] text-gray-500">
            Recommended: {signal.recommended_action.replace(/_/g, " ")}
          </p>
        )}
      </div>
    </li>
  );
}

function DecisionTab({
  decision,
  activeWave,
  onWave,
}: {
  decision: Decision;
  activeWave: number | null;
  onWave: (wave: number | null) => void;
}) {
  const byWave = useMemo(() => {
    const map = new Map<number, Signal[]>();
    for (const w of WAVES) map.set(w.wave, []);
    for (const s of decision?.all_signals ?? []) {
      map.get(s.wave)?.push(s);
    }
    return map;
  }, [decision]);

  const shown = activeWave ? WAVES.filter((w) => w.wave === activeWave) : WAVES;

  return (
    <div>
      <div className="grid grid-cols-5 gap-1.5 sm:gap-2">
        {WAVES.map((w) => {
          const signals = byWave.get(w.wave) ?? [];
          const state = waveState(signals);
          const style = WAVE_STYLE[state];
          const active = activeWave === w.wave;
          return (
            <button
              key={w.wave}
              type="button"
              title={w.tip}
              onClick={() => onWave(active ? null : w.wave)}
              className={`rounded-lg border p-2 text-center transition ${style.box} ${
                active ? "ring-2 ring-accord-green-500 ring-offset-1" : ""
              }`}
            >
              <span
                className={`mx-auto flex h-5 w-5 items-center justify-center ${style.text}`}
              >
                <WaveIcon state={state} />
              </span>
              <span className="mt-1 block text-[9.5px] font-bold tracking-wide text-gray-700 sm:text-[10.5px]">
                {w.label}
              </span>
              <span className="mt-0.5 block text-[10px] text-gray-400">
                {signals.length}
              </span>
            </button>
          );
        })}
      </div>

      <p className="mt-2 text-[11.5px] text-gray-400">
        {activeWave
          ? `Wave ${activeWave} — ${WAVES.find((w) => w.wave === activeWave)?.tip}. Click again for all waves.`
          : "Click a wave to filter. All five shown."}
      </p>

      {shown.map((w) => {
        const signals = byWave.get(w.wave) ?? [];
        if (signals.length === 0) return null;
        return (
          <section key={w.wave} className="mt-5">
            <h3 className="text-[11px] font-bold uppercase tracking-[0.12em] text-gray-400">
              Wave {w.wave} · {w.label}
            </h3>
            <ul className="mt-1">
              {signals.map((s) => (
                <SignalRow key={`${s.decision_id}-${s.signal_code}`} signal={s} />
              ))}
            </ul>
          </section>
        );
      })}
    </div>
  );
}

// ── Audit tab ────────────────────────────────────────────────────────

/**
 * The audit trail, built from the signals the engine actually emitted.
 *
 * ⚠ THE TIMESTAMPS ARE SIMULATED. The API returns one `processed_at`
 * for the whole bundle, not a per-signal time, so the clock below is
 * derived from the wave number — it shows the ORDER the engine ran in,
 * which is real, at times that are not. The header says so; do not
 * quietly drop that caveat, because "immutable audit trail" plus made
 * up times is the one combination a payer dispute cannot survive.
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

function AuditTab({ decision }: { decision: Decision }) {
  const events = useMemo(
    () =>
      [...(decision?.all_signals ?? [])]
        .sort((a, b) => a.wave - b.wave || a.signal_code.localeCompare(b.signal_code))
        .map((s, i) => ({ signal: s, when: auditTime(decision.processed_at, s.wave, i) })),
    [decision],
  );

  return (
    <div>
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <h3 className="text-[11px] font-bold uppercase tracking-[0.12em] text-gray-500">
          Audit trail — append only
        </h3>
        <p className="text-[11px] text-gray-400">
          Order is the engine's. Times are derived from the run timestamp,
          not recorded per signal.
        </p>
      </div>

      <ol className="mt-4">
        {events.map(({ signal, when }, i) => {
          const tone = toneFor(signal);
          return (
            <li key={`${signal.decision_id}-${signal.signal_code}`} className="flex gap-3">
              {/* Rail: dot plus the connector to the next event. */}
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
                    {signal.signal_code}
                  </span>
                </div>
                <p
                  className={`mt-0.5 text-[13px] leading-relaxed ${
                    tone === "green" ? "text-gray-600" : "font-medium text-gray-900"
                  }`}
                >
                  {signal.finding}
                </p>
                <p className="mt-1 text-[11px] text-gray-400">
                  Wave {signal.wave} · mode: {signal.mode} ·{" "}
                  {signal.decision_id.replace(/_/g, " ")}
                </p>
              </div>
            </li>
          );
        })}
      </ol>
    </div>
  );
}

// ── Evidence tab ─────────────────────────────────────────────────────

function EvidenceTab({ decision }: { decision: Decision }) {
  const demoLink = useDemoLink();
  const { data: appeal } = useAppeal(decision.pred_request_id);
  const nodes = useMemo(
    () => buildTimeline(decision, appeal?.evidence_list ?? []),
    [decision, appeal],
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

// ── Page ─────────────────────────────────────────────────────────────

const TABS = [
  { key: "decision", label: "Decision" },
  { key: "evidence", label: "Evidence" },
  { key: "conditions", label: "Conditions" },
  { key: "audit", label: "Audit" },
] as const;

type Tab = (typeof TABS)[number]["key"];

export default function WorkbenchPipeline({
  /** Test seam only — lets a render harness open a tab directly. */
  initialTab = "decision",
}: {
  initialTab?: Tab;
} = {}) {
  const [selectedId, setSelectedId] = useState(QUEUE[0].id);
  const [tab, setTab] = useState<Tab>(initialTab);
  const [activeWave, setActiveWave] = useState<number | null>(null);
  // Below md the two panels share the screen one at a time.
  const [showDetail, setShowDetail] = useState(false);

  const { data: decision, isLoading, isError, error } = useDecision(selectedId);
  const { data: conditions } = useConditions(selectedId);
  const { data: appeal } = useAppeal(selectedId);

  const row = QUEUE.find((r) => r.id === selectedId) ?? QUEUE[0];

  const action = QUEUE.filter((r) => r.status !== "approved");
  const ready = QUEUE.filter((r) => r.status === "approved");
  const pended = QUEUE.filter((r) => r.status === "pended");

  // Live where the API answers, snapshot where it does not. Never a
  // blend that cannot be told apart.
  const live = Boolean(decision);
  const patient = decision?.patient_name ?? row.patient;
  const payer = decision?.plan_name ?? row.payer;
  const status = decision?.decision ?? row.status;
  // `decision?.open_conditions.length` was the crash: the optional chain
  // guards `decision`, then a bare dot reaches straight into a field TS
  // types as always-present. When the SPA fallback hands back HTML
  // dressed as a Decision, that dot throws on mount.
  const openCount = (decision?.open_conditions ?? []).length || row.open;
  const blocking = conditions?.blocking_count ?? row.blocking;

  // Nothing to guard against on the left — the queue is static — but the
  // right panel has no content until the first fetch settles, and a
  // half-drawn header reads as a bug.
  const showSkeleton = !decision && isLoading;

  function select(id: string) {
    setSelectedId(id);
    setActiveWave(null);
    setShowDetail(true);
  }

  return (
    <div className="md:flex md:h-[calc(100dvh-49px)] md:overflow-hidden">
      {/* ── Left: the queue ──────────────────────────────────── */}
      <aside
        className={`border-gray-200 md:w-56 md:flex-shrink-0 md:overflow-y-auto md:border-r xl:w-72 ${
          showDetail ? "hidden md:block" : "block"
        }`}
      >
        <div className="border-b border-gray-200 px-3 py-3.5">
          <p className="text-[14px] font-semibold text-gray-900">
            Good morning, Dr. Chinta
          </p>
          <p className="mt-0.5 text-[12px] text-gray-500">
            Suwanee Smiles · {action.length} need action
          </p>

          <div className="mt-3 grid grid-cols-3 gap-2">
            <CountCell
              value={action.length}
              label="Action"
              tone="text-accord-amber-900"
            />
            <CountCell value={pended.length} label="Pending" tone="text-gray-900" />
            <CountCell
              value={ready.length}
              label="Done"
              tone="text-accord-green-700"
            />
          </div>
        </div>

        <p className="px-3 pb-1 pt-3 text-[10px] font-bold uppercase tracking-[0.12em] text-gray-400">
          Need my action
        </p>
        {action.map((r) => (
          <QueueItem
            key={r.id}
            row={r}
            selected={r.id === selectedId}
            onSelect={() => select(r.id)}
          />
        ))}

        <div className="my-2 border-t border-gray-200" />

        <p className="px-3 pb-1 pt-1 text-[10px] font-bold uppercase tracking-[0.12em] text-gray-400">
          Ready to submit
        </p>
        {ready.map((r) => (
          <QueueItem
            key={r.id}
            row={r}
            selected={r.id === selectedId}
            onSelect={() => select(r.id)}
          />
        ))}

        <p className="px-3 py-4 text-[11px] leading-relaxed text-gray-400">
          Eight cases, read from the API on 6 Aug 2026. There is no list
          endpoint yet, so this list does not refresh — the panel on the
          right does.
        </p>
      </aside>

      {/* ── Right: the selected pre-D ────────────────────────── */}
      <section
        className={`min-w-0 flex-1 flex-col md:flex ${
          showDetail ? "flex" : "hidden"
        }`}
      >
        <header className="border-b border-gray-200 bg-white px-4 py-3 sm:px-5">
          <button
            type="button"
            onClick={() => setShowDetail(false)}
            className="mb-2 inline-flex min-h-[36px] items-center gap-1.5 text-[12.5px] font-medium text-gray-500 hover:text-gray-900 md:hidden"
          >
            <ArrowLeft size={14} />
            Queue
          </button>

          <div className="flex flex-wrap items-start justify-between gap-3">
            <div className="min-w-0">
              <div className="flex flex-wrap items-center gap-2">
                <h2 className="text-[19px] font-semibold text-gray-900 sm:text-xl">
                  {patient}
                </h2>
                <DecisionBadge decision={status} />
                <span
                  className={`rounded px-1.5 py-0.5 text-[9.5px] font-semibold uppercase ${
                    live
                      ? "bg-accord-green-50 text-accord-green-700"
                      : "bg-gray-100 text-gray-500"
                  }`}
                >
                  {live ? "live" : "snapshot"}
                </span>
              </div>
              <p className="mt-0.5 text-[12.5px] text-gray-500">
                {formatCurrencyShort(row.charges)} · {payer} ·{" "}
                {scenarioId(selectedId)}
              </p>
            </div>

            <dl className="flex flex-shrink-0 gap-5">
              <div>
                <dt className="text-[10px] uppercase tracking-wide text-gray-500">
                  Criteria
                </dt>
                <dd className="mt-0.5 text-[17px] font-semibold leading-none text-gray-900">
                  {decision?.criteria_score ?? "—"}
                </dd>
              </div>
              <div>
                <dt className="text-[10px] uppercase tracking-wide text-gray-500">
                  Readiness
                </dt>
                <dd className="mt-0.5">
                  <ReadinessBadge
                    score={decision?.readiness_met ?? 0}
                    total={decision?.readiness_total ?? 14}
                  />
                </dd>
              </div>
            </dl>
          </div>
        </header>

        {/* Tabs */}
        <nav className="flex gap-4 border-b border-gray-200 bg-white px-4 sm:px-5">
          {TABS.map((t) => {
            const on = tab === t.key;
            return (
              <button
                key={t.key}
                type="button"
                onClick={() => setTab(t.key)}
                className={`-mb-px min-h-[40px] border-b-2 text-[13px] font-medium transition ${
                  on
                    ? "border-accord-green-900 text-accord-green-900"
                    : "border-transparent text-gray-500 hover:text-gray-900"
                }`}
              >
                {t.label}
                {t.key === "conditions" && openCount > 0 && (
                  <span className="ml-1.5 rounded-full bg-gray-100 px-1.5 py-0.5 text-[10px] text-gray-600">
                    {openCount}
                  </span>
                )}
              </button>
            );
          })}
        </nav>

        {/* Tab body */}
        <div className="flex-1 overflow-y-auto px-4 py-4 sm:px-5">
          {showSkeleton && (
            <div className="animate-pulse space-y-3">
              <div className="h-16 rounded-lg bg-gray-100" />
              <div className="h-24 rounded-lg bg-gray-100" />
              <div className="h-24 rounded-lg bg-gray-100" />
            </div>
          )}

          {isError && (
            <div className="rounded-xl border border-red-200 bg-red-50 p-5">
              <p className="text-[13.5px] font-medium text-red-700">
                Could not load {scenarioId(selectedId)}.
              </p>
              <p className="mt-1 text-[12.5px] text-red-600">
                {error instanceof Error ? error.message : "Unknown error"}
              </p>
              <p className="mt-2 text-[12px] text-red-500">
                The dental-os API should be running on :9010. The queue on the
                left is a snapshot and stays readable without it.
              </p>
            </div>
          )}

          {decision && tab === "decision" && (
            <DecisionTab
              decision={decision}
              activeWave={activeWave}
              onWave={setActiveWave}
            />
          )}
          {decision && tab === "evidence" && (
            <EvidenceTab key={decision.pred_request_id} decision={decision} />
          )}
          {decision && tab === "conditions" && (
            <ConditionsPanel predRequestId={decision.pred_request_id} />
          )}
          {decision && tab === "audit" && <AuditTab decision={decision} />}
        </div>

        {/* ── Action bar ─────────────────────────────────────── */}
        <footer className="border-t border-gray-200 bg-white px-4 py-2.5 sm:px-5">
          <p className="mb-2 flex flex-wrap items-center gap-x-2 gap-y-1 text-[11.5px] text-gray-500">
            <span
              aria-hidden="true"
              className={`h-2 w-2 rounded-full ${
                decision?.submission_ready ? "bg-accord-green-500" : "bg-amber-400"
              }`}
            />
            {decision?.submission_ready
              ? "Ready to submit"
              : `${blocking} of ${openCount} conditions need a signature`}
            <span className="text-gray-300">·</span>
            {decision?.readiness_met ?? "—"}/{decision?.readiness_total ?? 14} flags
            <span className="text-gray-300">·</span>
            {decision?.criteria_score ?? "—"} criteria
            {decision?.confidence_label && (
              <>
                <span className="text-gray-300">·</span>
                {decision.confidence_label}
              </>
            )}
          </p>

          <div className="flex flex-wrap gap-2">
            <button
              type="button"
              disabled={!decision?.submission_ready}
              title={
                decision?.submission_ready
                  ? "Demo only — submission runs in the product"
                  : "Blocked until every condition is cleared"
              }
              className="min-h-[36px] rounded-lg bg-[#1B5E20] px-3.5 text-[12.5px] font-semibold text-white transition hover:bg-[#154d19] disabled:cursor-not-allowed disabled:opacity-40"
            >
              Submit pre-D
            </button>
            {/* Demo-only, and labelled as such on hover rather than
                silently doing nothing when clicked. Wiring these needs a
                write path the API does not expose yet. */}
            <button
              type="button"
              title="Demo only — narrative capture runs in the product"
              className="min-h-[36px] rounded-lg border border-gray-300 px-3.5 text-[12.5px] font-medium text-gray-700 transition hover:bg-gray-50"
            >
              Add narrative
            </button>
            {appeal?.viable && (
              <button
                type="button"
                title="Demo only — the drafted letter lives on the appeal endpoint"
                className="min-h-[36px] rounded-lg border border-gray-300 px-3.5 text-[12.5px] font-medium text-gray-700 transition hover:bg-gray-50"
              >
                Generate appeal
                <ArrowRight size={12} className="ml-1.5 inline" />
              </button>
            )}
            <button
              type="button"
              title="Demo only — an override is recorded as feedback in the product"
              className="min-h-[36px] rounded-lg border border-red-200 px-3.5 text-[12.5px] font-medium text-red-600 transition hover:bg-red-50"
            >
              Override
            </button>
          </div>
        </footer>
      </section>
    </div>
  );
}
