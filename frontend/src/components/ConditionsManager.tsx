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
 * "Mark resolved" records feedback_type=accepted and fades the row. It
 * does NOT clear the condition in the engine — conditions are derived
 * from the persona run and clear when the pre-D is re-run with the
 * evidence in place. The row says so on hover rather than implying a
 * state change the product does not make.
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

function Row({
  predRequestId,
  patientName,
  condition,
}: {
  predRequestId: string;
  patientName: string;
  condition: Condition;
}) {
  const { role } = useAuth();
  const demoLink = useDemoLink();
  const mutation = useSubmitFeedback(predRequestId);
  const [resolved, setResolved] = useState(false);

  return (
    <li
      className={`flex flex-col gap-2 border-b border-gray-100 px-4 py-3 transition-all duration-500 last:border-b-0 sm:flex-row sm:items-start sm:justify-between ${
        resolved && mutation.isSuccess
          ? "pointer-events-none max-h-0 overflow-hidden py-0 opacity-0"
          : "opacity-100"
      }`}
    >
      <div className="min-w-0">
        <div className="flex flex-wrap items-center gap-1.5">
          <span className="font-mono text-[11px] font-semibold uppercase text-gray-700">
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
        <button
          type="button"
          disabled={mutation.isPending || resolved}
          title="Records feedback. The condition clears when the pre-D is re-run with the evidence in place."
          onClick={() => {
            setResolved(true);
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
          {mutation.isPending ? "Saving…" : "Mark resolved"}
        </button>
        {mutation.isError && (
          <span className="text-[11px] text-red-600">
            Could not mark resolved
          </span>
        )}
      </div>
    </li>
  );
}

export default function ConditionsManager({
  predRequestId = "PRED-SIM-DA-A01",
}: {
  predRequestId?: string;
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
