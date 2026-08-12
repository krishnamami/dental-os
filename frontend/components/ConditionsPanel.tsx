import { useState } from "react";

import { useConditions, useSubmitFeedback } from "../hooks/useApi";
import { canGiveEngineFeedback, NO_ENGINE_FEEDBACK } from "../utils/capabilities";
import { useAuth } from "../context/AuthContext";
import type { Condition } from "../types/dental";

/**
 * D-06 — the open conditions on one pre-D.
 *
 * Reads /decisions/{id}/conditions, which is already a work queue: the
 * API filters to signals that need a signature or name a task, and
 * sorts signature-first then tightest SLA. This component does not
 * re-sort — doing so would quietly disagree with the queue page.
 *
 * "Mark resolved" records feedback_type=accepted against the signal. It
 * does NOT clear the condition: the condition is derived from the
 * persona run, so it clears when the pre-D is re-run with the missing
 * evidence in place. Saying "resolved" without that caveat would
 * promise a state change the product does not make.
 */
const SUBMITTER: Record<string, "front_desk" | "billing" | "dentist" | "dso_manager"> = {
  front_desk: "front_desk",
  revenue_ops: "billing",
  dentist: "dentist",
  dso_owner: "dso_manager",
  accord_admin: "billing",
};

function ConditionRow({
  predRequestId,
  condition,
}: {
  predRequestId: string;
  condition: Condition;
}) {
  const { role } = useAuth();
  const canFeedback = canGiveEngineFeedback(role);
  const mutation = useSubmitFeedback(predRequestId);
  const [done, setDone] = useState(false);

  const blocking = condition.mode === "human_approval";

  return (
    <li className="flex flex-col gap-2 border-b border-gray-100 px-4 py-3 last:border-b-0 sm:flex-row sm:items-start sm:justify-between">
      <div className="min-w-0">
        <div className="flex flex-wrap items-center gap-1.5">
          <span className="font-mono text-[11px] font-semibold text-gray-700">
            {condition.signal_code}
          </span>
          {condition.category && (
            <span className="rounded border border-gray-200 bg-gray-50 px-1.5 py-0.5 text-[10.5px] capitalize text-gray-500">
              {condition.category}
            </span>
          )}
          <span
            className={`rounded px-1.5 py-0.5 text-[10.5px] font-medium ${
              blocking
                ? "bg-accord-amber-50 text-accord-amber-900"
                : "bg-gray-100 text-gray-600"
            }`}
          >
            {blocking ? "Needs signature" : "Task"}
          </span>
        </div>
        <p className="mt-1.5 text-[13px] leading-relaxed text-gray-700">
          {condition.finding}
        </p>
        {(condition.payer_citation ?? condition.citation) && (
          <p className="mt-1 text-[11.5px] italic text-accord-green-700">
            {condition.payer_citation ?? condition.citation}
          </p>
        )}
      </div>

      <div className="flex flex-shrink-0 items-center gap-2 sm:flex-col sm:items-end">
        {condition.sla_hours != null && (
          <span className="rounded-full border border-amber-200 bg-accord-amber-50 px-2 py-0.5 text-[10.5px] font-semibold text-accord-amber-900">
            {condition.sla_hours}h remaining
          </span>
        )}
        {condition.assignee && (
          <span className="rounded border border-gray-200 bg-gray-50 px-1.5 py-0.5 text-[10.5px] font-medium capitalize text-gray-500">
            {condition.assignee.replace(/_/g, " ")}
          </span>
        )}
        {done ? (
          <span className="text-[11.5px] font-medium text-accord-green-700">
            Acknowledged
          </span>
        ) : (
          <button
            type="button"
            disabled={mutation.isPending || !canFeedback}
            title={canFeedback ? undefined : NO_ENGINE_FEEDBACK}
            onClick={() => {
              setDone(true);
              mutation.mutate({
                decision_id: condition.decision_id ?? "pre_d_assessment",
                signal_code: condition.signal_code,
                feedback_type: "accepted",
                submitted_by: SUBMITTER[role ?? "dentist"] ?? "dentist",
                notes: null,
              });
            }}
            className="whitespace-nowrap rounded-lg border border-gray-300 px-2.5 py-1 text-[12px] font-medium text-gray-600 transition hover:bg-gray-50 disabled:opacity-50"
          >
            Mark resolved
          </button>
        )}
      </div>
    </li>
  );
}

export default function ConditionsPanel({
  predRequestId,
}: {
  predRequestId: string;
}) {
  const { data, isLoading, isError } = useConditions(predRequestId);

  return (
    <section className="overflow-hidden rounded-xl border border-gray-200 bg-white">
      <header className="flex items-center justify-between gap-3 border-b border-gray-200 bg-gray-50 px-4 py-3">
        <h2 className="text-[13.5px] font-semibold text-gray-900">
          Open conditions
        </h2>
        {data && (
          <span className="text-[11.5px] text-gray-500">
            {data.blocking_count} need a signature · {data.advisory_count} tasks
          </span>
        )}
      </header>

      {isLoading && (
        <div className="animate-pulse space-y-2 p-4">
          {[0, 1, 2].map((i) => (
            <div key={i} className="h-10 rounded bg-gray-100" />
          ))}
        </div>
      )}

      {isError && (
        <p className="px-4 py-6 text-[13px] text-gray-500">
          Could not load conditions. The dental-os API may not be running.
        </p>
      )}

      {data && (data.conditions ?? []).length === 0 && (
        <p className="px-4 py-6 text-[13px] text-accord-green-700">
          No open conditions — this pre-D is clear to submit.
        </p>
      )}

      {data && (data.conditions ?? []).length > 0 && (
        <ul>
          {(data.conditions ?? []).map((c) => (
            <ConditionRow
              key={c.signal_code}
              predRequestId={predRequestId}
              condition={c}
            />
          ))}
        </ul>
      )}
    </section>
  );
}
