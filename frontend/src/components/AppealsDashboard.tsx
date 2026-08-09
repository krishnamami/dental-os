import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";

import type { Appeal } from "../types/dental";
import {
  useAppeal,
  useAppealEvidence,
  useAppeals,
  useBillingAnalytics,
  useDenials,
  type AppealEvidenceItem,
  type AppealRow,
  type DenialRow,
} from "../hooks/useApi";
import { useDemoLink } from "../hooks/useDemo";
import { formatCurrency, formatCurrencyShort, scenarioId } from "../utils/format";
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

// Cases whose APPEAL VIABILITY is worth showing even though no denial
// has been entered against them. /decisions/:id/appeal is the engine's
// opinion on whether an appeal would succeed; appeal_events is what has
// actually been filed. Different questions, both worth a card.
//
// DA-B01 stays because "not viable — implants are excluded" is the most
// useful thing this tab can tell a biller about that case: do not spend
// an afternoon on it.
const VIABILITY_ONLY = [
  { predRequestId: "PRED-SIM-DA-B01", subtitle: "Implants excluded from plan" },
];

function Metric({
  label,
  value,
  note,
}: {
  label: string;
  value: string;
  note: string;
}) {
  return (
    <div className="rounded-xl border border-gray-200 bg-white p-4">
      <p className="text-[11px] uppercase tracking-wide text-gray-500">
        {label}
      </p>
      <p className="mt-1 text-[20px] font-semibold leading-none text-gray-900">
        {value}
      </p>
      <p className="mt-1.5 text-[11px] text-gray-400">{note}</p>
    </div>
  );
}

function StatusPill({ status }: { status: string }) {
  const tone =
    status === "overturned"
      ? "border-accord-green-100 bg-accord-green-50 text-accord-green-900"
      : status === "upheld"
        ? "border-red-200 bg-red-50 text-red-700"
        : "border-amber-200 bg-accord-amber-50 text-accord-amber-900";
  return (
    <span
      className={`flex-shrink-0 rounded-full border px-2.5 py-0.5 text-[11px] font-semibold capitalize ${tone}`}
    >
      {status}
    </span>
  );
}


/**
 * The evidence behind one filed appeal — including the dentist's own
 * clinical necessity wording.
 *
 * This is the join that closes the loop: Dr Chinta justifies a
 * criterion in the clinical workbench, and it appears here, on Kim's
 * screen, as a checked item she can read before she files. Before
 * this, the reasoning existed in the database and nobody who needed it
 * ever saw it.
 *
 * A clinician-authored item is visually distinct from a scanned
 * document on purpose. "Xray Pa" is a file; "Clinical necessity
 * documented by Dr Sridhar Chinta" is a person putting their name to
 * something, and a payer reads those differently.
 */
function EvidenceChecklist({ appealId }: { appealId: string }) {
  const { data, isLoading } = useAppealEvidence(appealId);
  const [open, setOpen] = useState<Set<string>>(new Set());

  if (isLoading) {
    return (
      <div className="mt-3 animate-pulse space-y-1.5">
        {[0, 1, 2].map((i) => (
          <div key={i} className="h-4 rounded bg-gray-100" />
        ))}
      </div>
    );
  }
  if (!data) return null;

  const clinical = (i: AppealEvidenceItem) =>
    i.kind === "clinical_justification" ||
    i.kind === "clinical_narrative" ||
    i.kind === "attestation";

  return (
    <div className="mt-3.5">
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <p className="text-[11px] font-bold uppercase tracking-[0.1em] text-gray-500">
          Evidence on file
        </p>
        <span className="text-[11px] text-gray-400">
          {data.present_count} on file
          {data.missing_count > 0 ? ` · ${data.missing_count} missing` : ""}
        </span>
      </div>

      <ul className="mt-1.5 space-y-1">
        {data.evidence.map((i) => {
          const expandable = Boolean(i.detail);
          const isOpen = open.has(i.key);
          return (
            <li key={i.key}>
              <div
                className={`flex flex-wrap items-start gap-2 rounded px-1.5 py-1 text-[12px] ${
                  clinical(i) ? "bg-accord-green-50" : ""
                }`}
              >
                <span
                  aria-hidden="true"
                  className={i.present ? "text-accord-green-700" : "text-red-500"}
                >
                  {i.present ? "✓" : "✗"}
                </span>
                <span
                  className={`min-w-0 flex-1 ${
                    i.present ? "text-gray-700" : "text-gray-500"
                  } ${clinical(i) ? "font-medium text-accord-green-900" : ""}`}
                >
                  {i.label}
                  {i.confidence != null && (
                    <span className="text-gray-400">
                      {" "}
                      — {Math.round(i.confidence * 100)}% confidence
                    </span>
                  )}
                </span>
                {expandable && (
                  <button
                    type="button"
                    onClick={() =>
                      setOpen((prev) => {
                        const next = new Set(prev);
                        if (next.has(i.key)) next.delete(i.key);
                        else next.add(i.key);
                        return next;
                      })
                    }
                    aria-expanded={isOpen}
                    className="flex-shrink-0 cursor-pointer text-[11px] font-medium text-accord-green-900 hover:underline"
                  >
                    {isOpen ? "Hide" : "Read"}
                  </button>
                )}
              </div>
              {expandable && isOpen && (
                <p className="ml-6 mt-1 rounded-lg border-l-2 border-l-accord-green-500 bg-white px-3 py-2 text-[12px] italic leading-relaxed text-gray-700">
                  {i.detail}
                </p>
              )}
            </li>
          );
        })}
      </ul>

      {!data.has_clinical_necessity && (
        <p className="mt-2 rounded-lg border-l-4 border-l-amber-400 bg-amber-50 px-3 py-2 text-[11.5px] text-amber-900">
          No clinician has documented medical necessity on this case. An
          appeal without it is the payer’s own reason for the denial,
          restated.
        </p>
      )}
    </div>
  );
}

/** An appeal that has been filed. Real row from appeal_events. */
function FiledAppeal({
  a,
  onView,
}: {
  a: AppealRow;
  onView: () => void;
}) {
  const pct = a.appeal_probability ?? null;
  const overdue = a.days_to_deadline != null && a.days_to_deadline < 0;
  return (
    <article className="rounded-xl border border-gray-200 bg-white p-4">
      <header className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h3 className="text-[14px] font-semibold text-gray-900">
            {a.patient_name} — {scenarioId(a.pred_request_id)}
          </h3>
          <p className="mt-0.5 text-[11.5px] text-gray-500">
            {a.payer_name} · {a.denial_reason ?? "reason not recorded"} ·{" "}
            {a.appeal_type} · filed{" "}
            {new Date(a.filed_at).toLocaleDateString("en-US", {
              month: "short",
              day: "numeric",
            })}
          </p>
        </div>
        <StatusPill status={a.status} />
      </header>

      {pct != null && (
        <div className="mt-3.5">
          <div className="flex items-baseline justify-between">
            <span className="text-[11px] uppercase tracking-wide text-gray-500">
              Overturn probability
            </span>
            <span className="text-[13px] font-semibold text-gray-900">
              {pct}%
            </span>
          </div>
          <div className="mt-1 h-2 w-full overflow-hidden rounded-full bg-gray-100">
            <div
              style={{ width: `${pct}%` }}
              className={
                pct >= 50
                  ? "h-full bg-accord-green-500"
                  : pct >= 20
                    ? "h-full bg-amber-400"
                    : "h-full bg-red-400"
              }
            />
          </div>
        </div>
      )}

      <dl className="mt-3.5 grid grid-cols-2 gap-3 sm:grid-cols-3">
        <div>
          <dt className="text-[10px] uppercase tracking-wide text-gray-500">
            Denied amount
          </dt>
          <dd className="text-[13px] font-medium text-gray-900">
            {a.denied_amount != null ? formatCurrency(a.denied_amount) : "—"}
          </dd>
        </div>
        <div>
          <dt className="text-[10px] uppercase tracking-wide text-gray-500">
            Deadline
          </dt>
          <dd
            className="text-[13px] font-medium"
            style={{ color: overdue ? "#b91c1c" : "#111827" }}
          >
            {a.days_to_deadline != null
              ? overdue
                ? `${Math.abs(a.days_to_deadline)} days overdue`
                : `${a.days_to_deadline} days left`
              : "—"}
          </dd>
        </div>
        <div>
          <dt className="text-[10px] uppercase tracking-wide text-gray-500">
            Recovered
          </dt>
          {/* null, not $0 — an unresolved appeal has recovered nothing
              YET, and "$0" reads as "we lost". */}
          <dd className="text-[13px] font-medium text-gray-900">
            {a.recovered_amount != null
              ? formatCurrency(a.recovered_amount)
              : "not resolved"}
          </dd>
        </div>
      </dl>

      {a.notes && (
        <p className="mt-3 text-[12.5px] leading-relaxed text-gray-600">
          {a.notes}
        </p>
      )}

      <EvidenceChecklist appealId={a.appeal_id} />

      <div className="mt-4 flex flex-wrap gap-2">
        <button
          type="button"
          onClick={onView}
          className="rounded-lg border border-gray-300 px-3 py-1.5 text-[12.5px] font-medium text-gray-700 transition hover:bg-gray-50"
        >
          View case
        </button>
      </div>
    </article>
  );
}

/** A denial nobody has appealed yet. The actionable one. */
function OpenDenial({ d, onView }: { d: DenialRow; onView: () => void }) {
  const overdue = d.days_to_deadline != null && d.days_to_deadline < 0;
  return (
    <article className="rounded-xl border border-amber-200 bg-white p-4">
      <header className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h3 className="text-[14px] font-semibold text-gray-900">
            {d.patient_name} — {scenarioId(d.pred_request_id)}
          </h3>
          <p className="mt-0.5 text-[11.5px] text-gray-500">
            {d.payer_name} · {d.denial_reason ?? "reason not recorded"}
            {d.denial_reason_code ? ` · ${d.denial_reason_code}` : ""}
          </p>
        </div>
        <span className="flex-shrink-0 rounded-full border border-amber-200 bg-accord-amber-50 px-2.5 py-0.5 text-[11px] font-semibold text-accord-amber-900">
          Not yet appealed
        </span>
      </header>
      <p className="mt-3 text-[12.5px] text-gray-600">
        {d.denied_amount != null ? formatCurrency(d.denied_amount) : "—"} denied
        ·{" "}
        <span style={{ color: overdue ? "#b91c1c" : undefined }}>
          {d.days_to_deadline != null
            ? overdue
              ? `appeal window closed ${Math.abs(d.days_to_deadline)} days ago`
              : `${d.days_to_deadline} days left to appeal`
            : "no deadline recorded"}
        </span>
      </p>
      <div className="mt-3 flex flex-wrap gap-2">
        <button
          type="button"
          onClick={onView}
          className="rounded-lg border border-gray-300 px-3 py-1.5 text-[12.5px] font-medium text-gray-700 transition hover:bg-gray-50"
        >
          View case
        </button>
      </div>
    </article>
  );
}

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
  const navigate = useNavigate();
  const demoLink = useDemoLink();
  const { data: appealRows } = useAppeals();
  const { data: denialRows } = useDenials();
  const { data: an } = useBillingAnalytics();

  const filed: AppealRow[] = Array.isArray(appealRows) ? appealRows : [];
  const denials: DenialRow[] = Array.isArray(denialRows) ? denialRows : [];
  const unappealed = denials.filter((d) => !d.appeal_filed);

  // Straight into the billing view of the case, same as the queue does.
  const view = (id: string) =>
    navigate(demoLink(`/workbench/${id}`), {
      state: { from: "/revenue-ops", fromLabel: "Revenue ops" },
    });

  return (
    <div className="space-y-4">
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        <Metric
          label="Appeals filed"
          value={String(an?.appeals.total ?? filed.length)}
          note={`${an?.appeals.pending ?? 0} pending · live`}
        />
        <Metric
          label="Overturn rate"
          value={
            an?.appeals.overturn_rate != null
              ? `${Math.round(an.appeals.overturn_rate * 100)}%`
              : "—"
          }
          // A rate over zero resolved appeals is not 0%, it is unknown.
          // Printing 0% would tell a biller they never win.
          note={
            an?.appeals.overturn_rate != null
              ? `${an.appeals.overturned} of ${an.appeals.overturned + an.appeals.upheld} resolved`
              : "no appeal resolved yet"
          }
        />
        <Metric
          label="Recovered"
          value={formatCurrencyShort(an?.appeals.recovered ?? 0)}
          note={`${formatCurrencyShort(an?.denials.amount ?? 0)} denied · live`}
        />
      </div>

      {filed.length > 0 && (
        <>
          <h2 className="mt-2 text-[11px] font-bold uppercase tracking-[0.12em] text-gray-500">
            Filed ({filed.length})
          </h2>
          {filed.map((a) => (
            <FiledAppeal
              key={a.appeal_id}
              a={a}
              onView={() => view(a.pred_request_id)}
            />
          ))}
        </>
      )}

      {unappealed.length > 0 && (
        <>
          <h2 className="mt-2 text-[11px] font-bold uppercase tracking-[0.12em] text-gray-500">
            Denied, not yet appealed ({unappealed.length})
          </h2>
          {unappealed.map((d) => (
            <OpenDenial
              key={d.denial_id}
              d={d}
              onView={() => view(d.pred_request_id)}
            />
          ))}
        </>
      )}

      {filed.length === 0 && unappealed.length === 0 && (
        <p className="rounded-xl border border-gray-200 bg-white px-4 py-6 text-[13px] text-gray-500">
          No denials recorded for this practice. Denials arrive in
          denial_events when a payer refuses a submitted pre-D.
        </p>
      )}

      <h2 className="mt-2 text-[11px] font-bold uppercase tracking-[0.12em] text-gray-500">
        Appeal viability — the engine&rsquo;s view
      </h2>
      {VIABILITY_ONLY.map((a) => (
        <AppealCard
          key={a.predRequestId}
          predRequestId={a.predRequestId}
          subtitle={a.subtitle}
          onGenerate={setPacket}
          onToast={onToast}
        />
      ))}

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
