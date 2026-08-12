import { useState } from "react";
import { denialReasonLabel } from "../utils/predDerive";
import { Link, useNavigate } from "react-router-dom";

import DocumentLink from "./DocumentLink";
import type { Appeal } from "../types/dental";
import {
  useAppeal,
  useAppealEvidence,
  useAppeals,
  useFileAppeal,
  useBillingAnalytics,
  useDenials,
  type AppealEvidenceItem,
  type AppealRow,
  type DenialRow,
} from "../hooks/useApi";
import { useAuth } from "../context/AuthContext";
import { useDemoLink } from "../hooks/useDemo";
import ActionError from "./ActionError";
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

/**
 * The engine's advice is only advice until a payer has ruled.
 *
 * DA-B01 was in the list above AND, since the timeline seed, carries an
 * appeal that was OVERTURNED for $1,800. The tab rendered "not
 * recommended · 0% · no action available" directly beneath the record
 * of that case being won. Whatever the engine thinks about a case a
 * payer has already decided, it is not a recommendation any more.
 *
 * Filtered by pre-D rather than by hardcoded id, so this cannot drift
 * back the next time a case is appealed.
 */
function stillAdvisory(
  entries: { predRequestId: string; subtitle: string }[],
  filedPredIds: Set<string>,
) {
  return entries.filter((e) => !filedPredIds.has(e.predRequestId));
}

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
function EvidenceChecklist({
  appealId,
  resolved = false,
}: {
  appealId: string;
  /** Hides the medical-necessity warning: see below. */
  resolved?: boolean;
}) {
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
                  {/* The checklist named documents nobody could open —
                      160 PDFs sat in S3 unreachable. A filename with no
                      link is worse than no filename. */}
                  {i.has_document && (
                    <DocumentLink
                      predRequestId={data.pred_request_id}
                      evidenceId={i.evidence_id}
                      className="ml-2"
                    />
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

      {/* ⚠ NOT ON A SETTLED APPEAL. The warning is accurate —
          clinical_justifications is empty on all three — but on an
          appeal the payer already OVERTURNED it warns about something
          that evidently did not matter. Same principle as the deadline
          countdown and the probability bar: advice stops being advice
          once the answer is in. */}
      {!resolved && !data.has_clinical_necessity && (
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
  // RESOLVED is the pivot. Once a payer has ruled, a prediction about
  // what they might do and a countdown to a deadline they already
  // beat are both noise — and worse than noise, because they were
  // rendered in red on an appeal that was WON.
  const resolved = a.status === "overturned" || a.status === "upheld";
  const overdue =
    !resolved && a.days_to_deadline != null && a.days_to_deadline < 0;
  return (
    <article className="rounded-xl border border-gray-200 bg-white p-4">
      <header className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h3 className="text-[14px] font-semibold text-gray-900">
            {a.patient_name} — {scenarioId(a.pred_request_id)}
          </h3>
          <p className="mt-0.5 text-[11.5px] text-gray-500">
            {a.payer_name} · {denialReasonLabel(a.denial_reason)} ·{" "}
            {a.appeal_type} · filed{" "}
            {new Date(a.filed_at).toLocaleDateString("en-US", {
              month: "short",
              day: "numeric",
            })}
          </p>
        </div>
        <StatusPill status={a.status} />
      </header>

      {/* ⚠ THE PER-ROW PROBABILITY BAR IS GONE.
          It rendered denial_events.appeal_probability, which was 65 on
          every row whatever the denial was — a frequency denial and a
          waiting-period denial both showing the bundling constant. It
          is not varied by denial type because there is nothing real to
          vary it by: three resolved appeals cannot support per-type
          rates. The aggregate overturn rate at the top of this tab IS
          measured, from those three, and is the honest version.

          What replaces it on a settled appeal is the comparison — what
          the engine expected against what the payer did. That is worth
          keeping precisely when the engine was wrong, and it is the
          first row of calibration data this product has. */}
      {resolved && (
        <p className="mt-3 rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-[12px] text-gray-700">
          {/* From appeal_events.predicted_*, snapshotted by POST
              /appeals at the moment of filing — not recomputed. The
              resolver short-circuits once a deadline passes, so asking
              it today what it thought in May returns the wrong answer.
              NULL reads as "no prediction on record" rather than a
              number nobody wrote down. */}
          <span className="text-gray-500">Engine expected</span>{" "}
          <span className="font-medium">
            {a.predicted_viable == null
              ? "no prediction on record"
              : a.predicted_viable
                ? `viable${a.predicted_probability != null ? `, ${a.predicted_probability}%` : ""}`
                : "not viable"}
          </span>{" "}
          <span className="text-gray-500">· payer</span>{" "}
          <span
            className={
              a.status === "overturned"
                ? "font-semibold text-accord-green-700"
                : "font-semibold text-red-700"
            }
          >
            {a.status}
          </span>
          {a.status === "overturned" && a.recovered_amount != null
            ? `, ${formatCurrency(a.recovered_amount)} recovered`
            : ""}
          {a.predicted_viable != null &&
            a.predicted_viable !== (a.status === "overturned") && (
              <span className="ml-1.5 rounded bg-amber-100 px-1.5 py-0.5 text-[11px] font-medium text-amber-900">
                engine was wrong
              </span>
            )}
        </p>
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
            {resolved ? "Resolved" : "Deadline"}
          </dt>
          <dd
            className="text-[13px] font-medium"
            style={{ color: overdue ? "#b91c1c" : "#111827" }}
          >
            {/* A deadline stops mattering the moment a payer rules.
                Patricia read "18 days overdue" in red on an appeal she
                WON four weeks inside the window. */}
            {resolved
              ? a.resolved_at
                ? new Date(a.resolved_at).toLocaleDateString("en-US", {
                    month: "short",
                    day: "numeric",
                  })
                : "—"
              : a.days_to_deadline != null
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

      <EvidenceChecklist appealId={a.appeal_id} resolved={resolved} />

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
function OpenDenial({
  d,
  onView,
  onToast,
}: {
  d: DenialRow;
  onView: () => void;
  onToast: (m: string) => void;
}) {
  const overdue = d.days_to_deadline != null && d.days_to_deadline < 0;
  const { role } = useAuth();
  const fileAppeal = useFileAppeal();
  const [error, setError] = useState<string | null>(null);
  // Mirrors require_billing. Offering a button that always 403s is the
  // dentist/SMS mistake; this screen is Kim's, but a dso_owner holds
  // Revenue Ops too and is refused.
  const canFile = role === "revenue_ops" || role === "accord_admin";

  function file() {
    setError(null);
    fileAppeal.mutate(
      {
        pred_request_id: d.pred_request_id,
        patient_name: d.patient_name,
        payer_id: d.payer_id,
        denial_id: d.denial_id,
        notes: `Filed from revenue ops against ${d.denial_reason ?? "the denial"}.`,
      },
      {
        onSuccess: (r) =>
          onToast(
            r.already_filed
              ? "An appeal was already on file for this pre-D"
              : `Appeal filed for ${d.patient_name} ✓`,
          ),
        onError: (e: unknown) => {
          const status = (e as { response?: { status?: number } })?.response
            ?.status;
          setError(
            status === 403
              ? "Your role cannot file a payer appeal. Nothing was recorded."
              : "Not filed. The denial is still unappealed.",
          );
        },
      },
    );
  }

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
          disabled={!canFile || fileAppeal.isPending}
          title={
            canFile ? undefined : "Only billing can act on a payer appeal"
          }
          onClick={file}
          className="rounded-lg bg-accord-green-900 px-3 py-1.5 text-[12.5px] font-semibold text-white transition hover:bg-accord-green-700 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {fileAppeal.isPending ? "Filing…" : "File appeal"}
        </button>
        <button
          type="button"
          onClick={onView}
          className="rounded-lg border border-gray-300 px-3 py-1.5 text-[12.5px] font-medium text-gray-700 transition hover:bg-gray-50"
        >
          View case
        </button>
      </div>

      <ActionError
        message={error}
        retrying={fileAppeal.isPending}
        onRetry={file}
        onDismiss={() => setError(null)}
      />
    </article>
  );
}

/** Same constant as above — see the note on "Overturn probability". */
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
          Appeal viability{" "}
          <span className="normal-case tracking-normal text-gray-400">
            (assumption)
          </span>
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
  const advisory = stillAdvisory(
    VIABILITY_ONLY,
    new Set(filed.map((a) => a.pred_request_id)),
  );

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
              onToast={onToast}
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

      {advisory.length > 0 && (
        <>
          <h2 className="mt-2 text-[11px] font-bold uppercase tracking-[0.12em] text-gray-500">
            Appeal viability — the engine&rsquo;s view
          </h2>
          <p className="-mt-1 text-[11.5px] text-gray-500">
            Cases with no appeal filed yet. Once a payer rules, the outcome
            replaces the advice on the card above.
          </p>
          {advisory.map((a) => (
            <AppealCard
              key={a.predRequestId}
              predRequestId={a.predRequestId}
              subtitle={a.subtitle}
              onGenerate={setPacket}
              onToast={onToast}
            />
          ))}
        </>
      )}

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
