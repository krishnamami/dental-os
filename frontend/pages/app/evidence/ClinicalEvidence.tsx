import { useMemo, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { ArrowRight } from "lucide-react";

import EvidenceDetailPanel from "../../../components/EvidenceDetailPanel";
import EvidenceTimeline, {
  buildTimeline,
  type TimelineNode,
} from "../../../components/EvidenceTimeline";
import MissingDocAlert from "../../../components/MissingDocAlert";
import { useAppeal, useDecision } from "../../../hooks/useApi";
import { useDemo, useDemoLink } from "../../../hooks/useDemo";
import { scenarioId } from "../../../utils/format";

/**
 * F-01 / F-08 — Clinical Evidence.
 *
 * The chain from a radiograph to a clinical verdict, one step at a
 * time, each step citable. This is the page that answers "why did the
 * engine decide that" for a dentist, and it is the page a payer's
 * medical director would be shown.
 *
 * ── Where the per-document confidence comes from ─────────────────────
 * GET /decisions/:id carries the signals but NOT the documents behind
 * them. The only endpoint exposing extraction confidence per document
 * is /appeal, so it is fetched opportunistically here. It 404s for an
 * approved pre-D — react-query is configured not to retry that — and
 * the timeline degrades to omitting the confidence badge rather than
 * inventing a number.
 *
 * Closing that properly means adding clinical_evidence to the decision
 * response, the same shape of gap readiness_flags had.
 */
export default function ClinicalEvidence() {
  const { id } = useParams<{ id: string }>();
  const { isDemo, demoPredId } = useDemo();
  const demoLink = useDemoLink();

  // The sidebar links to a bare /evidence; the workbench links to a
  // specific pre-D. Both have to land somewhere sensible.
  const predRequestId = id ?? (isDemo ? demoPredId : "PRED-SIM-DA-A01");

  const { data, isLoading, isError, error } = useDecision(predRequestId);
  const { data: appeal } = useAppeal(predRequestId);

  const nodes = useMemo(
    () => (data ? buildTimeline(data, appeal?.evidence_list ?? []) : []),
    [data, appeal],
  );

  const [selectedId, setSelectedId] = useState<string | null>(null);

  // Default to the ADA check — the step that carries the argument.
  const selected: TimelineNode | null =
    nodes.find((n) => n.id === selectedId) ??
    nodes.find((n) => n.id === "ada") ??
    nodes.find((n) => n.signal) ??
    null;

  return (
    <div className="p-4 sm:p-6">
      {isLoading && (
        <div className="grid animate-pulse gap-5 lg:grid-cols-[minmax(0,2fr)_minmax(0,3fr)]">
          <div className="space-y-2">
            {[0, 1, 2, 3, 4, 5].map((i) => (
              <div key={i} className="h-[86px] rounded-lg bg-gray-100" />
            ))}
          </div>
          <div className="space-y-3">
            <div className="h-[150px] rounded-xl bg-gray-100" />
            <div className="h-[190px] rounded-xl bg-gray-100" />
          </div>
        </div>
      )}

      {isError && (
        <div className="rounded-xl border border-red-200 bg-red-50 p-5">
          <p className="text-[13.5px] font-medium text-red-700">
            Could not load clinical evidence for {scenarioId(predRequestId)}.
          </p>
          <p className="mt-1 text-[12.5px] text-red-600">
            {error instanceof Error ? error.message : "Unknown error"}
          </p>
          <p className="mt-2 text-[12px] text-red-500">
            Ensure dental-os is running on port 9010.
          </p>
        </div>
      )}

      {data && (
        <>
          <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
            <div>
              <h1 className="text-[17px] font-semibold text-gray-900">
                Clinical evidence — {data.patient_name}
              </h1>
              <p className="mt-0.5 text-[12.5px] text-gray-500">
                {scenarioId(data.pred_request_id)} · {data.plan_name} ·{" "}
                {data.provider_name}
              </p>
            </div>
            <Link
              to={demoLink(`/workbench/${data.pred_request_id}`)}
              className="inline-flex items-center gap-1.5 rounded-lg border border-gray-300 px-3 py-1.5 text-[12.5px] font-medium text-gray-700 transition hover:bg-gray-50"
            >
              View in workbench
              <ArrowRight size={13} />
            </Link>
          </div>

          <div className="mb-4">
            <MissingDocAlert signals={data.all_signals} />
          </div>

          <div className="grid gap-5 lg:grid-cols-[minmax(0,2fr)_minmax(0,3fr)]">
            <section>
              <h2 className="mb-3 text-[13px] font-semibold uppercase tracking-wide text-gray-500">
                Evidence chain
              </h2>
              <EvidenceTimeline
                nodes={nodes}
                selectedId={selected?.id}
                onSelect={(n) => setSelectedId(n.id)}
                predRequestId={predRequestId}
              />
            </section>

            <section>
              <h2 className="mb-3 text-[13px] font-semibold uppercase tracking-wide text-gray-500">
                Signal detail
              </h2>
              <EvidenceDetailPanel
                node={selected}
                documents={appeal?.evidence_list ?? []}
                demoLink={demoLink}
              />
            </section>
          </div>
        </>
      )}
    </div>
  );
}
