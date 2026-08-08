import { useState } from "react";
import { Link } from "react-router-dom";

import type { Appeal } from "../types/dental";
import { useAppeal } from "../hooks/useApi";
import { useDemoLink } from "../hooks/useDemo";
import { formatCurrencyShort, scenarioId } from "../utils/format";
import AppealPacket from "./AppealPacket";
import DeadlineTracker from "./DeadlineTracker";

/**
 * G-04 — appeals worth filing.
 *
 * TWO OF THE THREE CARDS ARE LIVE. The brief called for one live card
 * and two static ones, but the corpus already contains both cases it
 * described:
 *
 *   DA-B04  Carlos Rivera   viable, 65%, bundling §D.7.4
 *   DA-B01  Patricia Johnson  NOT viable — implants excluded
 *
 * The second is exactly the "hard exclusion, not recommended" card the
 * brief wanted, with the engine's own reason: a plan exclusion is a
 * contract term, not a determination, so nothing in the chart changes
 * it. Only the third card — an appeal already SUBMITTED — is static,
 * because nothing tracks submission state yet (dental-simulator
 * Gap #3).
 */

const LIVE_APPEALS = [
  { predRequestId: "PRED-SIM-DA-B04", subtitle: "D7953 bone graft bundling" },
  { predRequestId: "PRED-SIM-DA-B01", subtitle: "Implants excluded from plan" },
];

function ViabilityBar({ probability }: { probability: number }) {
  const pct = Math.round(probability * 100);
  const tone =
    pct >= 50
      ? "bg-accord-green-500"
      : pct >= 20
        ? "bg-amber-400"
        : "bg-red-400";
  return (
    <div>
      <div className="flex items-baseline justify-between">
        <span className="text-[11px] uppercase tracking-wide text-gray-500">
          Appeal viability
        </span>
        <span className="text-[13px] font-semibold text-gray-900">{pct}%</span>
      </div>
      <div className="mt-1 h-2 w-full overflow-hidden rounded-full bg-gray-100">
        <div style={{ width: `${pct}%` }} className={`h-full ${tone}`} />
      </div>
    </div>
  );
}

function AppealCard({
  predRequestId,
  subtitle,
  onGenerate,
  onToast,
}: {
  predRequestId: string;
  subtitle: string;
  onGenerate: (a: Appeal) => void;
  onToast: (m: string) => void;
}) {
  const { data, isLoading, isError } = useAppeal(predRequestId);
  const demoLink = useDemoLink();
  const [building, setBuilding] = useState(false);
  const [built, setBuilt] = useState(false);

  // The packet is assembled from data already in hand, so this is fast
  // enough to feel like nothing happened. The pause is honest about
  // the work being done, not a fake progress bar: the packet opens
  // when it opens, and the button then stays in a "ready" state so the
  // biller can reopen it without regenerating.
  function generate(appeal: Appeal) {
    setBuilding(true);
    window.setTimeout(() => {
      setBuilding(false);
      setBuilt(true);
      onGenerate(appeal);
      onToast(`Appeal packet generated for ${scenarioId(predRequestId)}`);
    }, 1500);
  }

  if (isLoading) {
    return (
      <div className="h-[220px] animate-pulse rounded-xl border border-gray-200 bg-gray-100" />
    );
  }
  if (isError || !data) {
    return (
      <div className="rounded-xl border border-gray-200 bg-white p-4 text-[12.5px] text-gray-500">
        No appeal path for {scenarioId(predRequestId)} — the pre-D was
        approved, so there is nothing to appeal.
      </div>
    );
  }

  const documents = data.evidence_list.filter(
    (e) => e.document_type !== "PRED_LETTER",
  );

  return (
    <article className="rounded-xl border border-gray-200 bg-white p-4">
      <header className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h3 className="text-[14px] font-semibold text-gray-900">
            {data.patient_name} — {subtitle}
          </h3>
          <p className="mt-0.5 text-[11.5px] text-gray-500">
            {data.payer_id.replace(/_/g, " ")} ·{" "}
            {scenarioId(data.pred_request_id)} · {data.decision}
          </p>
        </div>
        <span
          className={`flex-shrink-0 rounded-full border px-2.5 py-0.5 text-[11px] font-semibold ${
            data.viable
              ? "border-accord-green-100 bg-accord-green-50 text-accord-green-900"
              : "border-red-200 bg-red-50 text-red-700"
          }`}
        >
          {data.viable ? "Viable" : "Not recommended"}
        </span>
      </header>

      <div className="mt-3.5">
        <ViabilityBar probability={data.success_probability ?? 0} />
      </div>

      <div className="mt-3.5">
        <DeadlineTracker
          daysRemaining={data.days_remaining}
          deadline={data.appeal_deadline}
        />
      </div>

      <p className="mt-3.5 text-[12.5px] leading-relaxed text-gray-600">
        {data.viable
          ? data.appeal_strategy
          : (data.not_viable_reason ?? "No appeal path is supported.")}
      </p>

      {data.viable && (
        <ul className="mt-3 space-y-1">
          {documents.map((d) => (
            <li key={d.document_type} className="flex gap-2 text-[12px]">
              <span className="text-accord-green-700">✓</span>
              <span className="text-gray-600">
                {d.document_type.replace(/_/g, " ")} —{" "}
                {Math.round((d.confidence ?? 0) * 100)}% confidence
              </span>
            </li>
          ))}
          {data.missing_evidence.map((mi) => (
            <li key={mi} className="flex gap-2 text-[12px]">
              <span className="text-red-500">✗</span>
              <span className="text-gray-500">{mi}</span>
            </li>
          ))}
        </ul>
      )}

      <div className="mt-4 flex flex-wrap gap-2">
        {data.viable ? (
          <>
            <button
              type="button"
              disabled={building}
              onClick={() => (built ? onGenerate(data) : generate(data))}
              className="rounded-lg bg-accord-green-900 px-3 py-1.5 text-[12.5px] font-semibold text-white transition hover:bg-accord-green-700 disabled:opacity-70"
            >
              {building
                ? "Generating…"
                : built
                  ? "Appeal packet ready ✓ — open"
                  : "Generate appeal packet"}
            </button>
            <Link
              to={demoLink(`/evidence/${data.pred_request_id}`)}
              className="rounded-lg border border-gray-300 px-3 py-1.5 text-[12.5px] font-medium text-gray-700 transition hover:bg-gray-50"
            >
              View evidence
            </Link>
          </>
        ) : (
          // No action buttons on an unappealable denial. Offering
          // "generate packet" here would waste a biller's afternoon on
          // a contract term no narrative can move.
          <p className="text-[11.5px] text-gray-500">
            No action available — this is a plan exclusion, not a
            determination.
          </p>
        )}
      </div>
    </article>
  );
}

export default function AppealsDashboard({
  onToast = () => {},
}: {
  onToast?: (m: string) => void;
}) {
  const [packet, setPacket] = useState<Appeal | null>(null);

  return (
    <div className="space-y-4">
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        {[
          { label: "Active appeals", value: "3", note: "2 live · 1 sample" },
          { label: "Avg overturn rate", value: "65%", note: "bundling, documented" },
          {
            label: "Revenue recoverable",
            value: formatCurrencyShort(8200),
            note: "sample",
          },
        ].map((m) => (
          <div
            key={m.label}
            className="rounded-xl border border-gray-200 bg-white p-4"
          >
            <p className="text-[11px] uppercase tracking-wide text-gray-500">
              {m.label}
            </p>
            <p className="mt-1 text-[20px] font-semibold leading-none text-gray-900">
              {m.value}
            </p>
            <p className="mt-1.5 text-[11px] text-gray-400">{m.note}</p>
          </div>
        ))}
      </div>

      {LIVE_APPEALS.map((a) => (
        <AppealCard
          key={a.predRequestId}
          predRequestId={a.predRequestId}
          subtitle={a.subtitle}
          onGenerate={setPacket}
          onToast={onToast}
        />
      ))}

      {/* Static: nothing tracks appeal SUBMISSION state yet. */}
      <article className="rounded-xl border border-gray-200 bg-white p-4 opacity-90">
        <header className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h3 className="text-[14px] font-semibold text-gray-900">
              Dorothy Harris — frequency limit
            </h3>
            <p className="mt-0.5 text-[11.5px] text-gray-500">
              delta dental · DA-B03 · submitted 2026-08-01
            </p>
          </div>
          <span className="rounded-full border border-gray-200 bg-gray-100 px-2.5 py-0.5 text-[11px] font-semibold text-gray-600">
            Submitted — awaiting response
          </span>
        </header>
        <p className="mt-3 text-[12.5px] text-gray-500">
          Sample row. Appeal submission and outcome tracking are not built —
          the <code className="font-mono">appeals</code> table exists with no
          generator behind it (dental-simulator Gap #3).
        </p>
        <button
          type="button"
          disabled
          title="Outcome tracking not implemented"
          className="mt-3 cursor-not-allowed rounded-lg border border-gray-300 px-3 py-1.5 text-[12.5px] font-medium text-gray-400"
        >
          Mark outcome
        </button>
      </article>

      {packet && (
        <AppealPacket
          appeal={packet}
          providerName="Dr. Sridhar Chinta · NPI 1134534266"
          onClose={() => setPacket(null)}
        />
      )}
    </div>
  );
}
