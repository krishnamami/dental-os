import { useState } from "react";
import { Link } from "react-router-dom";

import { useConditions, useSubmitFeedback } from "../hooks/useApi";
import { useAuth } from "../context/AuthContext";
import { useDemoLink } from "../hooks/useDemo";
import type { Condition } from "../types/dental";
import { scenarioId } from "../utils/format";

/**
 * G-03 — every open condition, tightest SLA first.
 *
 * The API already returns them in that order (signature-required
 * first, then ascending SLA), so this does not re-sort. Sorting again
 * here would quietly disagree with the workbench, which shows the same
 * list.
 *
 * "Resolve" records feedback_type=accepted and ticks the row green. It
 * does NOT clear the condition in the engine — conditions are derived
 * from the persona run and clear when the pre-D is re-run with the
 * evidence in place.
 *
 * The row used to collapse to zero height on success, which read as
 * "this is gone now". It stays, greyed with a checkmark: a biller needs
 * to see what they have already dealt with, and the difference between
 * "handled" and "no longer exists" is the whole point.
 *
 * "View rule" shows the citation the engine actually attached —
 * payer_citation and citation off the condition itself. Nothing is
 * written here: where a condition carries no citation the modal says
 * so rather than quoting a policy section that was never returned.
 */
const SUBMITTER: Record<
  string,
  "front_desk" | "billing" | "dentist" | "dso_manager"
> = {
  front_desk: "front_desk",
  revenue_ops: "billing",
  dentist: "dentist",
  dso_owner: "dso_manager",
  accord_admin: "billing",
};

const FILTERS = ["All", "Billing", "Front desk", "Dentist"] as const;
type Filter = (typeof FILTERS)[number];

const FILTER_ASSIGNEE: Record<Filter, string | null> = {
  All: null,
  Billing: "billing",
  "Front desk": "front_desk",
  Dentist: "dentist",
};

function SlaBadge({ hours }: { hours?: number | null }) {
  if (hours == null) {
    return (
      <span className="rounded border border-gray-200 bg-gray-50 px-1.5 py-0.5 text-[10.5px] text-gray-500">
        no SLA
      </span>
    );
  }
  const tone =
    hours > 24
      ? "border-accord-green-100 bg-accord-green-50 text-accord-green-900"
      : hours > 0
        ? "border-amber-200 bg-accord-amber-50 text-accord-amber-900"
        : "border-red-200 bg-red-50 text-red-700";
  return (
    <span
      className={`rounded-full border px-2 py-0.5 text-[10.5px] font-semibold ${tone}`}
    >
      {hours > 0 ? `${hours}h remaining` : `${Math.abs(hours)}h overdue`}
    </span>
  );
}

/** The rule behind a condition, as the engine cited it. */
function RuleModal({
  condition,
  onClose,
}: {
  condition: Condition;
  onClose: () => void;
}) {
  const cited = condition.payer_citation || condition.citation;
  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
      role="dialog"
      aria-modal="true"
      aria-label="Rule detail"
      onClick={onClose}
    >
      <div
        className="max-h-[80vh] w-full max-w-md overflow-y-auto rounded-xl bg-white p-5 shadow-xl"
        onClick={(e) => e.stopPropagation()}
      >
        <p className="font-mono text-[11px] font-semibold uppercase text-gray-500">
          {condition.signal_code}
        </p>
        <h3 className="mt-1 text-[15px] font-semibold text-gray-900">
          {cited
            ? [
                condition.citation ? `Rule §${condition.citation}` : "Rule",
                condition.payer_citation,
              ]
                .filter(Boolean)
                .join(" · ")
            : "No rule citation on this condition"}
        </h3>
        <p className="mt-2.5 text-[12.5px] leading-relaxed text-gray-700">
          {condition.finding}
        </p>
        {condition.recommended_action && (
          <p className="mt-2.5 text-[12px] text-gray-600">
            <span className="font-semibold">Recommended action: </span>
            {condition.recommended_action.replace(/_/g, " ")}
          </p>
        )}
        <p className="mt-3 border-t border-gray-100 pt-2.5 text-[11.5px] text-gray-500">
          {cited
            ? `Citation: ${[
                condition.payer_citation,
                condition.citation ? `policy §${condition.citation}` : null,
              ]
                .filter(Boolean)
                .join(" · ")}`
            : "The engine returned no citation for this signal, so none is shown."}
        </p>
        <button
          type="button"
          onClick={onClose}
          className="mt-4 rounded-lg border border-gray-300 px-3 py-1.5 text-[12.5px] font-medium text-gray-700 transition hover:bg-gray-50"
        >
          Close
        </button>
      </div>
    </div>
  );
}

function Row({
  predRequestId,
  patientName,
  condition,
  onToast,
}: {
  predRequestId: string;
  patientName: string;
  condition: Condition;
  onToast: (m: string) => void;
}) {
  const { role } = useAuth();
  const demoLink = useDemoLink();
  const mutation = useSubmitFeedback(predRequestId);
  const [resolved, setResolved] = useState(false);
  const [showRule, setShowRule] = useState(false);

  return (
    <li
      className={`flex flex-col gap-2 border-b border-gray-100 px-4 py-3 last:border-b-0 sm:flex-row sm:items-start sm:justify-between ${
        resolved ? "bg-accord-green-50/40" : ""
      }`}
    >
      {showRule && (
        <RuleModal condition={condition} onClose={() => setShowRule(false)} />
      )}
      <div className="min-w-0">
        <div className="flex flex-wrap items-center gap-1.5">
          {resolved && (
            <span className="text-accord-green-700" aria-label="resolved">
              ✅
            </span>
          )}
          <span
            className={`font-mono text-[11px] font-semibold uppercase ${
              resolved ? "text-gray-400 line-through" : "text-gray-700"
            }`}
          >
            {condition.signal_code}
          </span>
          {condition.category && (
            <span className="rounded border border-gray-200 bg-gray-50 px-1.5 py-0.5 text-[10.5px] capitalize text-gray-500">
              {condition.category}
            </span>
          )}
        </div>
        <p className="mt-1 text-[12.5px] leading-relaxed text-gray-700">
          {condition.finding}
        </p>
        <p className="mt-1 text-[11.5px] text-gray-500">
          <Link
            to={demoLink(`/workbench/${predRequestId}`)}
            className="font-medium text-accord-green-900 hover:underline"
          >
            {patientName}
          </Link>{" "}
          · {scenarioId(predRequestId)}
        </p>
      </div>

      <div className="flex flex-shrink-0 flex-wrap items-center gap-2 sm:flex-col sm:items-end">
        <SlaBadge hours={condition.sla_hours} />
        {condition.assignee && (
          <span className="rounded border border-gray-200 bg-gray-50 px-1.5 py-0.5 text-[10.5px] font-medium capitalize text-gray-500">
            {condition.assignee.replace(/_/g, " ")}
          </span>
        )}
        <div className="flex flex-wrap gap-1.5">
          <button
            type="button"
            disabled={mutation.isPending || resolved}
            title="Records feedback. The condition clears when the pre-D is re-run with the evidence in place."
            onClick={() => {
              setResolved(true);
              onToast("Condition marked resolved ✓");
              mutation.mutate({
                decision_id: condition.decision_id ?? "pre_d_assessment",
                signal_code: condition.signal_code,
                feedback_type: "accepted",
                submitted_by: SUBMITTER[role ?? "revenue_ops"] ?? "billing",
                notes: "Resolved by revenue ops",
              });
            }}
            className="whitespace-nowrap rounded-lg border border-gray-300 px-2.5 py-1 text-[12px] font-medium text-gray-600 transition hover:bg-gray-50 disabled:opacity-50"
          >
            {mutation.isPending
              ? "Saving…"
              : resolved
                ? "Resolved ✓"
                : "Resolve"}
          </button>
          <button
            type="button"
            onClick={() => setShowRule(true)}
            className="whitespace-nowrap rounded-lg border border-gray-300 px-2.5 py-1 text-[12px] font-medium text-gray-600 transition hover:bg-gray-50"
          >
            View rule
          </button>
        </div>
        {mutation.isError && (
          <span className="text-[11px] text-red-600">
            Not recorded — the row stays ticked here only
          </span>
        )}
      </div>
    </li>
  );
}

export default function ConditionsManager({
  predRequestId = "PRED-SIM-DA-A01",
  onToast = () => {},
}: {
  predRequestId?: string;
  onToast?: (m: string) => void;
}) {
  const [filter, setFilter] = useState<Filter>("All");
  const { data, isLoading, isError } = useConditions(predRequestId);

  const wanted = FILTER_ASSIGNEE[filter];
  const rows = (data?.conditions ?? []).filter(
    (c) => !wanted || c.assignee === wanted,
  );

  return (
    <section className="overflow-hidden rounded-xl border border-gray-200 bg-white">
      <header className="flex flex-wrap items-center justify-between gap-3 border-b border-gray-200 bg-gray-50 px-4 py-3">
        <div className="flex flex-wrap gap-1.5">
          {FILTERS.map((f) => (
            <button
              key={f}
              type="button"
              onClick={() => setFilter(f)}
              className={`rounded-lg px-2.5 py-1 text-[12px] font-medium transition ${
                filter === f
                  ? "bg-accord-green-900 text-white"
                  : "border border-gray-200 bg-white text-gray-600 hover:bg-gray-50"
              }`}
            >
              {f}
            </button>
          ))}
        </div>
        <span className="text-[11.5px] text-gray-500">
          Sorted by SLA — soonest first
        </span>
      </header>

      {isLoading && (
        <div className="animate-pulse space-y-2 p-4">
          {[0, 1, 2].map((i) => (
            <div key={i} className="h-12 rounded bg-gray-100" />
          ))}
        </div>
      )}

      {isError && (
        <p className="px-4 py-6 text-[13px] text-gray-500">
          Could not load conditions. Check that dental-os is running on :9010.
        </p>
      )}

      {data && rows.length === 0 && (
        <p className="px-4 py-8 text-center text-[13px] text-accord-green-700">
          {filter === "All"
            ? "All conditions resolved — nothing is blocking submission."
            : `No conditions assigned to ${filter.toLowerCase()}.`}
        </p>
      )}

      {data && rows.length > 0 && (
        <ul>
          {rows.map((c) => (
            <Row
              key={c.signal_code}
              predRequestId={predRequestId}
              patientName={data.patient_name}
              condition={c}
              onToast={onToast}
            />
          ))}
        </ul>
      )}

      <footer className="border-t border-gray-100 px-4 py-2.5">
        <p className="text-[11px] text-gray-400">
          Live conditions for {scenarioId(predRequestId)}. A cross-practice
          queue needs a list endpoint dental-os does not have yet — today it
          answers per pre-D.
        </p>
      </footer>
    </section>
  );
}
