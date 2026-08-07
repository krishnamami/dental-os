import { useState } from "react";
import { Link, useParams } from "react-router-dom";
import { ArrowLeft, Check, Printer } from "lucide-react";

import AnnualMaxBar from "../../../components/AnnualMaxBar";
import BenefitSummary from "../../../components/BenefitSummary";
import CostTable from "../../../components/CostTable";
import CoverageCard from "../../../components/CoverageCard";
import DowngradeAlert from "../../../components/DowngradeAlert";
import PayerComparison from "../../../components/PayerComparison";
import { usePatientSummary } from "../../../hooks/useApi";
import { useDemo, useDemoLink } from "../../../hooks/useDemo";
import { scenarioId } from "../../../utils/format";

const BRAND_GREEN = "#0F4D37";

function Skeleton() {
  return (
    <div className="animate-pulse space-y-4">
      <div className="h-20 rounded-xl bg-gray-100" />
      <div className="h-14 rounded-xl bg-gray-100" />
      <div className="h-40 rounded-xl bg-gray-100" />
    </div>
  );
}

/**
 * E-01b — one patient's coverage, at /coverage/:id.
 *
 * Everything here is live from GET /decisions/{id}/patient-summary.
 *
 * ONE row of stat cards, and it belongs to CoverageCard. An earlier
 * pass added a second row above it with the same four numbers in it —
 * annual max, deductible, payer — which is how a patient ends up being
 * quoted two different figures off one screen. CoverageCard owns them,
 * because it also owns the badges that qualify them.
 */
export default function CoverageDetail() {
  const { id } = useParams<{ id: string }>();
  const { isDemo, demoPredId } = useDemo();
  const demoLink = useDemoLink();
  const [checkedIn, setCheckedIn] = useState(false);

  const predRequestId = id ?? (isDemo ? demoPredId : undefined);
  const { data, isLoading, isError, error, refetch } =
    usePatientSummary(predRequestId);

  return (
    <div className="mx-auto max-w-4xl px-5 py-5 sm:px-6">
      <Link
        to={demoLink("/coverage")}
        className="inline-flex items-center gap-1.5 text-[12.5px] font-medium text-gray-500 hover:text-gray-900"
      >
        <ArrowLeft size={14} />
        My patients today
      </Link>

      {isLoading && (
        <div className="mt-4">
          <Skeleton />
        </div>
      )}

      {isError && (
        <div className="mt-4 rounded-xl border border-red-200 bg-red-50 p-5">
          <p className="text-[13.5px] font-medium text-red-700">
            Could not load coverage data.
          </p>
          <p className="mt-1 text-[12.5px] text-red-600">
            {error instanceof Error ? error.message : "Unknown error"}
          </p>
          <button
            type="button"
            onClick={() => void refetch()}
            className="mt-3 rounded-lg border border-red-300 px-3 py-1.5 text-[12.5px] font-medium text-red-700 transition hover:bg-red-100"
          >
            Retry
          </button>
        </div>
      )}

      {data && (
        <div className="mt-4 space-y-4">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div className="min-w-0">
              <h1 className="text-[20px] font-semibold text-gray-900">
                {data.patient_name}
              </h1>
              <p className="mt-0.5 text-[12.5px] text-gray-500">
                {data.plan_name} · {data.provider_name} · {data.state} ·{" "}
                {scenarioId(data.pred_request_id)}
              </p>
            </div>
            {checkedIn && (
              <span className="inline-flex items-center gap-1 rounded-full bg-accord-green-50 px-2.5 py-1 text-[11.5px] font-semibold text-accord-green-700">
                <Check size={12} strokeWidth={3} />
                Checked in
              </span>
            )}
          </div>

          {/* The one row of stat cards, plus the badges that qualify
              them. Do not add a second row above this. */}
          <CoverageCard summary={data} />

          <DowngradeAlert procedures={data.procedures} />

          <AnnualMaxBar
            thisCase={data.summary.total_insurance_pays}
            remainingAfter={data.summary.annual_max_remaining_after}
            exhausted={data.summary.annual_max_exhausted}
          />

          <CostTable procedures={data.procedures} summary={data.summary} />

          {data.notes.length > 0 && (
            <ul className="space-y-1.5 rounded-xl border border-gray-200 bg-white p-4">
              {data.notes.map((n) => (
                <li key={n} className="text-[12.5px] text-gray-600">
                  {n}
                </li>
              ))}
            </ul>
          )}

          {data.caveats.length > 0 && (
            <ul className="space-y-1 rounded-xl border border-gray-200 bg-gray-50 p-4">
              {data.caveats.map((c) => (
                <li key={c} className="text-[11.5px] text-gray-500">
                  {c}
                </li>
              ))}
            </ul>
          )}

          <BenefitSummary patient={data} />

          <PayerComparison />

          <div className="flex flex-wrap gap-2 border-t border-gray-200 pt-4">
            <button
              type="button"
              onClick={() => window.print()}
              className="inline-flex min-h-[36px] items-center gap-1.5 rounded-lg px-3.5 text-[12.5px] font-semibold text-white transition hover:opacity-90"
              style={{ backgroundColor: BRAND_GREEN }}
            >
              <Printer size={13} />
              Print patient summary
            </button>
            <button
              type="button"
              title="Demo only — there is no mail path from the browser"
              className="min-h-[36px] rounded-lg border border-gray-300 px-3.5 text-[12.5px] font-medium text-gray-700 transition hover:bg-gray-50"
            >
              Email to patient
            </button>
            <button
              type="button"
              onClick={() => setCheckedIn(true)}
              disabled={checkedIn}
              className="min-h-[36px] rounded-lg border border-gray-300 px-3.5 text-[12.5px] font-medium text-gray-700 transition hover:bg-gray-50 disabled:opacity-40"
            >
              {checkedIn ? "Checked in ✓" : "Mark checked in"}
            </button>
            <span className="ml-auto self-center text-[10.5px] text-gray-400">
              Check-in is remembered in this tab only
            </span>
          </div>
        </div>
      )}
    </div>
  );
}
