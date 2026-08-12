import { Link } from "react-router-dom";

import type { EvidenceItem } from "../types/dental";
import type { TimelineNode } from "./EvidenceTimeline";
import ADACitation from "./ADACitation";
import BoneLossBar from "./BoneLossBar";
import ConfidenceBadge from "./ConfidenceBadge";
import { toneFor } from "./SignalCard";

/**
 * F-07 — the full story behind one timeline step.
 *
 * Every field is read off the selected signal. Nothing is written for a
 * specific scenario: the bone-loss bar appears when the signal carries
 * a measurement and a threshold, the citation appears when there is
 * one, the appeal note appears when the bundling rule says the conflict
 * is separable. A pre-D without those simply shows fewer sections.
 */
function num(v: unknown): number | undefined {
  return typeof v === "number" ? v : undefined;
}

function str(v: unknown): string | undefined {
  return typeof v === "string" ? v : undefined;
}

export default function EvidenceDetailPanel({
  node,
  documents = [],
  demoLink,
}: {
  node: TimelineNode | null;
  documents?: EvidenceItem[];
  demoLink: (path: string) => string;
}) {
  if (!node) {
    return (
      <div className="rounded-xl border border-dashed border-gray-300 bg-gray-50 px-5 py-14 text-center">
        <p className="text-[13px] text-gray-500">
          Click a timeline step to see full detail.
        </p>
      </div>
    );
  }

  const signal = node.signal;

  // Node without a signal (the source document and extraction steps).
  if (!signal) {
    const doc = documents.find((d) => d.document_type.startsWith("XRAY"));
    return (
      <div className="space-y-3 rounded-xl border border-gray-200 bg-white p-5">
        <h2 className="text-[15px] font-semibold text-gray-900">
          {node.title}
        </h2>
        <p className="text-[13px] text-gray-600">{node.sub}</p>
        {node.detail && (
          <p className="break-words font-mono text-[11.5px] text-gray-500">
            {node.detail}
          </p>
        )}
        {doc?.confidence != null && (
          <ConfidenceBadge
            confidence={doc.confidence}
            method={doc.description?.match(/\(([^)]+)\)/)?.[1] ?? null}
          />
        )}
      </div>
    );
  }

  const tone = toneFor(signal);
  const boneLoss = num(signal.data.bone_loss_mm);
  const threshold = num(signal.data.threshold);
  const section = str(signal.data.policy_section);
  const separable = signal.data.separable === true;
  const xray = documents.find((d) => d.document_type.startsWith("XRAY"));

  return (
    <div className="space-y-4">
      <header className="rounded-xl border border-gray-200 bg-white p-5">
        <div className="flex flex-wrap items-center gap-2">
          <span
            className={`rounded-full border px-2.5 py-0.5 text-[11px] font-semibold ${
              tone === "green"
                ? "border-accord-green-100 bg-accord-green-50 text-accord-green-900"
                : tone === "red"
                  ? "border-red-200 bg-red-50 text-red-700"
                  : "border-amber-200 bg-accord-amber-50 text-accord-amber-900"
            }`}
          >
            {tone === "green" ? "Criteria met" : "Action needed"}
          </span>
          <span className="font-mono text-[11.5px] font-semibold text-gray-700">
            {signal.signal_code}
          </span>
        </div>
        <p className="mt-1.5 text-[11.5px] text-gray-500">
          Wave {signal.wave} · {signal.decision_id.replace(/_/g, " ")}
        </p>

        <p className="mt-3 text-[13.5px] leading-relaxed text-gray-800">
          {signal.finding}
        </p>

        {(signal.sla_hours != null || signal.assignee) && (
          <p className="mt-3 flex flex-wrap gap-1.5">
            {signal.sla_hours != null && (
              <span className="rounded-full border border-amber-200 bg-accord-amber-50 px-2 py-0.5 text-[10.5px] font-semibold text-accord-amber-900">
                {signal.sla_hours}h SLA
              </span>
            )}
            {signal.assignee && (
              <span className="rounded border border-gray-200 bg-gray-50 px-1.5 py-0.5 text-[10.5px] font-medium capitalize text-gray-500">
                {signal.assignee.replace(/_/g, " ")}
              </span>
            )}
          </p>
        )}
      </header>

      {boneLoss !== undefined && threshold !== undefined && (
        <BoneLossBar measured={boneLoss} threshold={threshold} />
      )}

      <ADACitation
        citation={signal.citation}
        payerCitation={signal.payer_citation}
        section={section}
      />

      {/* Only on the node that actually rests on a measured document. */}
      {boneLoss !== undefined && xray?.confidence != null && (
        <div className="rounded-xl border border-gray-200 bg-white p-4">
          <p className="text-[11px] uppercase tracking-wide text-gray-500">
            Source document confidence
          </p>
          <div className="mt-2">
            <ConfidenceBadge
              confidence={xray.confidence}
              method={xray.description?.match(/\(([^)]+)\)/)?.[1] ?? null}
            />
          </div>
        </div>
      )}

      <div className="rounded-xl border border-gray-200 bg-white p-4">
        <p className="text-[11px] uppercase tracking-wide text-gray-500">
          Recommended action
        </p>
        <p className="mt-1.5 text-[13px] text-gray-700">
          {signal.recommended_action
            ? signal.recommended_action.replace(/_/g, " ")
            : "No action required — this check is confirmed."}
        </p>
        {str(signal.data.separation_criteria) && (
          <p className="mt-2 text-[12px] leading-relaxed text-gray-500">
            {str(signal.data.separation_criteria)}
          </p>
        )}
      </div>

      {separable && (
        <div className="rounded-xl border border-amber-200 bg-accord-amber-50 p-4">
          <p className="text-[12.5px] leading-relaxed text-accord-amber-900">
            If this is denied without the narrative, an appeal is viable —
            roughly 65% of these are overturned when documented.{" "}
            <Link
              to={demoLink("/revenue-ops/appeals")}
              className="font-medium underline"
            >
              See Appeals for packet generation
            </Link>
            .
          </p>
        </div>
      )}
    </div>
  );
}
