import { Link, useParams } from "react-router-dom";
import { ArrowLeft } from "lucide-react";

import ConditionsPanel from "../../../components/ConditionsPanel";
import DecisionBadge from "../../../components/DecisionBadge";
import ReadinessChecklist, {
  readinessScore,
} from "../../../components/ReadinessChecklist";
import ReadinessBadge from "../../../components/ReadinessBadge";
import WaveAccordion from "../../../components/WaveAccordion";
import { useDecision } from "../../../hooks/useApi";
import { useDemo, useDemoLink } from "../../../hooks/useDemo";
import { scenarioId } from "../../../utils/format";

/**
 * D-03 — one pre-D, all nine personas.
 *
 * Everything on this page is live from GET /decisions/{id}. There is no
 * fallback here, unlike the landing page: a signed-in reviewer looking
 * at a patient's case must never be shown sample data dressed as
 * theirs. If the API is down they get an error and can act on it.
 */
export default function WorkbenchDetail() {
  const { id } = useParams<{ id: string }>();
  const { demoPredId, isDemo } = useDemo();
  const demoLink = useDemoLink();

  // The route param wins; demo mode only supplies a default for a bare
  // /workbench/ visit.
  const predRequestId = id ?? (isDemo ? demoPredId : undefined);

  const { data, isLoading, isError, error } = useDecision(predRequestId);

  if (!predRequestId) {
    return (
      <div className="p-6 text-[13.5px] text-gray-500">
        No pre-D selected.{" "}
        <Link to={demoLink("/workbench")} className="text-accord-green-900 underline">
          Back to the queue
        </Link>
      </div>
    );
  }

  return (
    <div className="p-4 sm:p-6">
      <Link
        to={demoLink("/workbench")}
        className="inline-flex items-center gap-1.5 text-[12.5px] font-medium text-gray-500 hover:text-gray-900"
      >
        <ArrowLeft size={14} />
        Queue
      </Link>

      {isLoading && (
        <div className="mt-4 animate-pulse space-y-3">
          <div className="h-24 rounded-xl bg-gray-100" />
          <div className="h-14 rounded-xl bg-gray-100" />
          <div className="h-14 rounded-xl bg-gray-100" />
        </div>
      )}

      {isError && (
        <div className="mt-4 rounded-xl border border-red-200 bg-red-50 p-5">
          <p className="text-[13.5px] font-medium text-red-700">
            Could not load {scenarioId(predRequestId)}.
          </p>
          <p className="mt-1 text-[12.5px] text-red-600">
            {error instanceof Error ? error.message : "Unknown error"}
          </p>
          <p className="mt-2 text-[12px] text-red-500">
            The dental-os API should be running on :9010.
          </p>
        </div>
      )}

      {data && (
        <>
          {/* ── Patient header ──────────────────────────────── */}
          <header className="mt-4 rounded-xl border border-gray-200 bg-white p-5">
            <div className="flex flex-wrap items-start justify-between gap-4">
              <div className="min-w-0">
                <div className="flex flex-wrap items-center gap-2">
                  <h2 className="text-[19px] font-semibold text-gray-900">
                    {data.patient_name}
                  </h2>
                  <DecisionBadge decision={data.decision} />
                  <ReadinessBadge score={readinessScore(data)} />
                </div>
                <p className="mt-1 text-[13px] text-gray-500">
                  {data.plan_name} · {data.provider_name} · {data.state} ·{" "}
                  {scenarioId(data.pred_request_id)}
                </p>
                <div className="mt-3 flex flex-wrap gap-1.5">
                  {[
                    ...new Set(
                      data.all_signals
                        .flatMap((s) => {
                          const codes = (s.data?.cdt_codes ??
                            s.data?.billed_codes) as string[] | undefined;
                          return codes ?? [];
                        })
                        .filter(Boolean),
                    ),
                  ]
                    .slice(0, 6)
                    .map((code) => (
                      <span
                        key={code}
                        className="rounded border border-gray-200 bg-gray-50 px-2 py-0.5 font-mono text-[11px] text-gray-600"
                      >
                        {code}
                      </span>
                    ))}
                </div>
              </div>

              <dl className="flex gap-6">
                <div>
                  <dt className="text-[11px] uppercase tracking-wide text-gray-500">
                    Criteria score
                  </dt>
                  <dd className="mt-0.5 text-[17px] font-semibold text-gray-900">
                    {data.criteria_score ?? "—"}
                  </dd>
                  <dd className="text-[11.5px] text-gray-500">
                    {data.confidence_label}
                  </dd>
                </div>
                <div>
                  <dt className="text-[11px] uppercase tracking-wide text-gray-500">
                    Signals
                  </dt>
                  <dd className="mt-0.5 text-[17px] font-semibold text-gray-900">
                    {data.all_signals.length}
                  </dd>
                  <dd className="text-[11.5px] text-gray-500">
                    {data.open_conditions.length} open
                  </dd>
                </div>
              </dl>
            </div>
          </header>

          {/* ── Waves + side panels ─────────────────────────── */}
          <div className="mt-4 grid gap-4 lg:grid-cols-3">
            <div className="lg:col-span-2">
              <WaveAccordion
                waves={data.waves}
                predRequestId={data.pred_request_id}
              />
              <div className="mt-4">
                <ConditionsPanel predRequestId={data.pred_request_id} />
              </div>
            </div>

            <div className="lg:col-span-1">
              <ReadinessChecklist decision={data} />
            </div>
          </div>
        </>
      )}
    </div>
  );
}
