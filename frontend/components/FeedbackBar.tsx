import { useRef, useState } from "react";

import ActionError from "./ActionError";
import { Check, RotateCcw, X } from "lucide-react";

import { useSubmitFeedback } from "../hooks/useApi";
import { canGiveEngineFeedback, NO_ENGINE_FEEDBACK } from "../utils/capabilities";
import { useAuth } from "../context/AuthContext";
import type { FeedbackType, Signal } from "../types/dental";

/**
 * D-07 — the human's verdict on one signal.
 *
 * POSTs to /decisions/{id}/feedback. `submitted_by` is a ROLE, never a
 * person: provider_feedback carries a CHECK constraint to four role
 * values, and the table is about which desk overrode the
 * recommendation, not who.
 *
 * The four UI roles do not map 1:1 to the four accepted values —
 * dso_owner and accord_admin are not in the database's list — so they
 * are mapped rather than sent through and rejected at the write.
 */
const OPTIONS: Array<{
  type: FeedbackType;
  label: string;
  icon: typeof Check;
}> = [
  { type: "accepted", label: "Accepted", icon: Check },
  { type: "overridden", label: "Overridden", icon: RotateCcw },
  { type: "false_positive", label: "False positive", icon: X },
];

const SUBMITTER: Record<string, "front_desk" | "billing" | "dentist" | "dso_manager"> = {
  front_desk: "front_desk",
  revenue_ops: "billing",
  dentist: "dentist",
  dso_owner: "dso_manager",
  accord_admin: "billing",
};

export default function FeedbackBar({
  predRequestId,
  signal,
}: {
  predRequestId: string;
  signal: Signal;
}) {
  const { role, isDemo } = useAuth();
  const canFeedback = canGiveEngineFeedback(role);
  const mutation = useSubmitFeedback(predRequestId);
  const [chosen, setChosen] = useState<FeedbackType | null>(null);
  const [error, setError] = useState<string | null>(null);
  // What they last tried, so "Try again" repeats the same verdict
  // rather than guessing one.
  const chosenRef = useRef<FeedbackType | null>(null);

  /**
   * ⚠ setChosen USED TO RUN BEFORE THE MUTATION, and nothing rendered
   * on failure — the success line is gated on isSuccess, so a 403 left
   * the bar exactly as it was. A practice owner clicking any of these
   * seventeen rows got silence and no reason. This capability is
   * revenue_ops and dentist only; every other role is refused, and now
   * told so.
   */
  function submit(type: FeedbackType) {
    setError(null);
    chosenRef.current = type;
    mutation.mutate(
      {
        decision_id: signal.decision_id,
        signal_code: signal.signal_code,
        feedback_type: type,
        submitted_by: SUBMITTER[role ?? "dentist"] ?? "dentist",
        notes: isDemo ? "Submitted from demo mode" : null,
      },
      {
        onSuccess: () => setChosen(type),
        onError: (e: unknown) => {
          const status = (e as { response?: { status?: number } })?.response
            ?.status;
          setError(
            status === 403
              ? "Your role cannot record a verdict on an engine finding. " +
                  "Nothing was saved."
              : "Not recorded. The engine has not been told anything.",
          );
        },
      },
    );
  }

  if (mutation.isSuccess && chosen) {
    return (
      <p className="text-[12px] text-accord-green-700">
        Recorded as <span className="font-medium">{chosen.replace(/_/g, " ")}</span>.
        Thank you — this trains the next similar case.
      </p>
    );
  }

  return (
    <div>
    <div className="flex flex-wrap items-center gap-1.5">
      {OPTIONS.map((o) => {
        const Icon = o.icon;
        return (
          <button
            key={o.type}
            type="button"
            disabled={mutation.isPending || !canFeedback}
            title={canFeedback ? undefined : NO_ENGINE_FEEDBACK}
            onClick={() => submit(o.type)}
            className="inline-flex min-h-[36px] items-center gap-1.5 rounded-lg border border-gray-300 px-3 py-1.5 text-[12px] font-medium text-gray-600 transition hover:border-gray-400 hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50"
          >
            <Icon size={12} />
            {o.label}
          </button>
        );
      })}
    </div>
      {/* Was a 12px inline span reading "Could not record that", tied
          to mutation.isError so it cleared itself on the next attempt
          and said nothing about WHY. A 403 and a network blip are not
          the same problem and the first is not worth retrying. */}
      <ActionError
        message={error}
        onDismiss={() => setError(null)}
        onRetry={chosenRef.current ? () => submit(chosenRef.current!) : undefined}
        retrying={mutation.isPending}
      />
    </div>
  );
}
