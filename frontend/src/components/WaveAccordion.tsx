import { useState } from "react";
import { Link } from "react-router-dom";
import { ArrowRight, ChevronDown } from "lucide-react";

import { useDemoLink } from "../hooks/useDemo";

import type { Decision, Signal } from "../types/dental";
import FeedbackBar from "./FeedbackBar";
import SignalCard, { toneFor } from "./SignalCard";

/**
 * D-04 — the five waves, in the order the engine ran them.
 *
 * Waves 3 and 4 open by default because that is where the action items
 * are: documentation gaps and the submission verdict. Waves 1 and 2
 * usually read "verified", and opening all five buries the two that
 * need a human under thirty lines of confirmation.
 */
const WAVE_TITLES: Record<string, string> = {
  "1": "Wave 1 — Eligibility & Provider",
  "2": "Wave 2 — Coverage & Benefits",
  "3": "Wave 3 — Clinical Evidence",
  "4": "Wave 4 — Documentation & Compliance",
  "5": "Wave 5 — Final Assessment & Appeals",
};

const DEFAULT_OPEN = new Set(["3", "4"]);

/** Signals whose reasoning the evidence chain explains. Only these get
 *  a "view evidence chain" link — offering it on, say, a portfolio
 *  signal would lead to a page with nothing to say about it. */
const HAS_EVIDENCE_CHAIN = new Set([
  "CLINICAL_CRITERIA_MET",
  "CLINICAL_CRITERIA_NOT_MET",
  "CLINICAL_NARRATIVE_MISSING",
  "COVERAGE_BUNDLING_CONFLICT",
  "DOC_NARRATIVE_MISSING",
]);

export default function WaveAccordion({
  waves,
  predRequestId,
}: {
  waves: Decision["waves"];
  predRequestId: string;
}) {
  const [open, setOpen] = useState<Set<string>>(new Set(DEFAULT_OPEN));
  const demoLink = useDemoLink();

  function toggle(key: string) {
    setOpen((prev) => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });
  }

  // Always render 1..5, even when a wave produced nothing — an absent
  // wave 5 means "no appeal was needed", which is worth showing rather
  // than leaving the reader to notice a gap in the numbering.
  const keys = ["1", "2", "3", "4", "5"];

  return (
    <div className="space-y-2">
      {keys.map((key) => {
        const outputs = waves[key] ?? [];
        const signals: Signal[] = outputs.flatMap((o) => o.signals);
        const needsAction = signals.filter((s) => toneFor(s) !== "green").length;
        const expanded = open.has(key);

        return (
          <section
            key={key}
            className="overflow-hidden rounded-xl border border-gray-200 bg-white"
          >
            <button
              type="button"
              onClick={() => toggle(key)}
              aria-expanded={expanded}
              className="flex w-full items-center justify-between gap-3 px-4 py-3 text-left transition hover:bg-gray-50"
            >
              <span className="min-w-0">
                <span className="block truncate text-[13.5px] font-semibold text-gray-900">
                  {WAVE_TITLES[key]}
                </span>
                <span className="mt-0.5 block text-[11.5px] text-gray-500">
                  {outputs.length} decision{outputs.length === 1 ? "" : "s"} ·{" "}
                  {signals.length} signal{signals.length === 1 ? "" : "s"}
                  {needsAction > 0 && ` · ${needsAction} need action`}
                </span>
              </span>
              <span className="flex flex-shrink-0 items-center gap-2">
                {needsAction > 0 && (
                  <span className="rounded-full bg-accord-amber-50 px-2 py-0.5 text-[10.5px] font-semibold text-accord-amber-900">
                    {needsAction}
                  </span>
                )}
                <ChevronDown
                  size={16}
                  className={`text-gray-400 transition-transform ${expanded ? "rotate-180" : ""}`}
                />
              </span>
            </button>

            {expanded && (
              <div className="space-y-2 border-t border-gray-100 bg-gray-50 p-3">
                {signals.length === 0 ? (
                  <p className="px-1 py-2 text-[12.5px] text-gray-500">
                    No decisions ran in this wave for this pre-D.
                  </p>
                ) : (
                  signals.map((s) => (
                    <SignalCard key={`${s.decision_id}-${s.signal_code}`} signal={s}>
                      <div className="flex flex-wrap items-center gap-x-4 gap-y-2">
                        {toneFor(s) !== "green" && (
                          <FeedbackBar
                            predRequestId={predRequestId}
                            signal={s}
                          />
                        )}
                        {HAS_EVIDENCE_CHAIN.has(s.signal_code) && (
                          <Link
                            to={demoLink(`/evidence/${predRequestId}`)}
                            className="inline-flex items-center gap-1 text-[12px] font-medium text-accord-green-900 hover:text-accord-green-700"
                          >
                            View evidence chain
                            <ArrowRight size={12} />
                          </Link>
                        )}
                      </div>
                    </SignalCard>
                  ))
                )}
              </div>
            )}
          </section>
        );
      })}
    </div>
  );
}
