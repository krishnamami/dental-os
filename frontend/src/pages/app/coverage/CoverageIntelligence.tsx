import { useState } from "react";
import { Search } from "lucide-react";

import AnnualMaxBar from "../../../components/AnnualMaxBar";
import BenefitSummary from "../../../components/BenefitSummary";
import CostTable from "../../../components/CostTable";
import CoverageCard from "../../../components/CoverageCard";
import DowngradeAlert from "../../../components/DowngradeAlert";
import PayerComparison from "../../../components/PayerComparison";
import { usePatientSummary } from "../../../hooks/useApi";
import { useDemo } from "../../../hooks/useDemo";

/**
 * E-01 / E-07 — Coverage Intelligence.
 *
 * The front desk's landing page: what a patient owes, per code, before
 * they sit down.
 *
 * EVERY PATIENT IN THE SELECTOR IS REAL. The task called for five
 * hardcoded rows, but all five names exist in the simulator corpus, so
 * the list is a hardcoded set of pred_request_ids and each click
 * fetches that patient's live coverage. Nothing on the right-hand side
 * is invented — a cost estimate a practice cannot reproduce is the one
 * thing this page must never show.
 *
 * The search box filters the list. It is not a patient lookup: there is
 * no search endpoint, and pretending otherwise would promise a
 * directory the product does not have.
 */

interface PatientRow {
  predRequestId: string;
  name: string;
  payer: string;
  summary: string;
}

const PATIENTS: PatientRow[] = [
  {
    predRequestId: "PRED-SIM-DA-A01",
    name: "James Mitchell",
    payer: "Delta PPO",
    summary: "Implant + graft + crown · tooth #19",
  },
  {
    predRequestId: "PRED-SIM-DA-A02",
    name: "Sandra Williams",
    payer: "Delta PPO",
    summary: "PFM crown · tooth #3",
  },
  {
    predRequestId: "PRED-SIM-DA-B04",
    name: "Carlos Rivera",
    payer: "Delta PPO",
    summary: "Implant + bone graft · tooth #19",
  },
  {
    predRequestId: "PRED-SIM-DA-U01",
    name: "Robert Thompson",
    payer: "Delta PPO",
    // DA-U01 is a prophylaxis, not the "full mouth" case the brief
    // guessed at. Described as it is.
    summary: "Prophylaxis · adult cleaning",
  },
  {
    predRequestId: "PRED-SIM-DA-A04",
    name: "Maria Rodriguez",
    payer: "Delta PPO",
    // Four quadrants of scaling, not one.
    summary: "Scaling & root planing · 4 quadrants",
  },
];

function Skeleton() {
  return (
    <div className="animate-pulse space-y-3">
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        {[0, 1, 2, 3].map((i) => (
          <div key={i} className="h-[74px] rounded-xl bg-gray-100" />
        ))}
      </div>
      <div className="h-[96px] rounded-xl bg-gray-100" />
      <div className="h-[280px] rounded-xl bg-gray-100" />
    </div>
  );
}

export default function CoverageIntelligence() {
  const { isDemo, demoPredId } = useDemo();
  const [query, setQuery] = useState("");
  const [selected, setSelected] = useState<string>(
    // Demo mode lands on whichever case the link named; otherwise the
    // reference implant case.
    isDemo ? demoPredId : PATIENTS[0].predRequestId,
  );

  const { data, isLoading, isError, error } = usePatientSummary(selected);

  const filtered = PATIENTS.filter((p) =>
    p.name.toLowerCase().includes(query.trim().toLowerCase()),
  );

  return (
    <div className="p-4 sm:p-6">
      <div className="grid gap-5 lg:grid-cols-[minmax(0,2fr)_minmax(0,3fr)]">
        {/* ── Patient selector ────────────────────────────────── */}
        <aside>
          <h2 className="text-[14px] font-semibold text-gray-900">
            Patient check-in
          </h2>

          <div className="relative mt-3">
            <Search
              size={14}
              className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-gray-400"
            />
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search patient name..."
              aria-label="Search patient name"
              className="w-full rounded-lg border border-gray-300 py-2 pl-8 pr-3 text-[13px] text-gray-900 placeholder-gray-400 focus:border-accord-green-500 focus:outline-none focus:ring-1 focus:ring-accord-green-500"
            />
          </div>

          {/* Mobile: a select is one tap instead of a scrolling list
              pushing the coverage detail off the screen. */}
          <label className="mt-3 block lg:hidden">
            <span className="sr-only">Patient</span>
            <select
              value={selected}
              onChange={(e) => setSelected(e.target.value)}
              className="w-full rounded-lg border border-gray-300 px-3 py-2 text-[13px] text-gray-900"
            >
              {PATIENTS.map((p) => (
                <option key={p.predRequestId} value={p.predRequestId}>
                  {p.name} — {p.summary}
                </option>
              ))}
            </select>
          </label>

          <ul className="mt-3 hidden space-y-1.5 lg:block">
            {filtered.map((p) => {
              const active = p.predRequestId === selected;
              return (
                <li key={p.predRequestId}>
                  <button
                    type="button"
                    onClick={() => setSelected(p.predRequestId)}
                    aria-pressed={active}
                    className={`w-full rounded-lg border px-3.5 py-2.5 text-left transition ${
                      active
                        ? "border-accord-green-500 bg-accord-green-50"
                        : "border-gray-200 bg-white hover:border-gray-300 hover:bg-gray-50"
                    }`}
                  >
                    <span className="block text-[13px] font-medium text-gray-900">
                      {p.name}
                    </span>
                    <span className="mt-0.5 block text-[11.5px] text-gray-500">
                      {p.payer} · {p.summary}
                    </span>
                  </button>
                </li>
              );
            })}
            {filtered.length === 0 && (
              <li className="px-1 py-3 text-[12.5px] text-gray-500">
                No patient matches “{query}”.
              </li>
            )}
          </ul>

          <p className="mt-3 hidden text-[11px] leading-relaxed text-gray-400 lg:block">
            Five demo patients from the simulator corpus. Each one loads its
            real coverage — there is no patient directory endpoint yet, so the
            search filters this list rather than querying one.
          </p>
        </aside>

        {/* ── Coverage detail ─────────────────────────────────── */}
        <div className="space-y-4">
          {isLoading && <Skeleton />}

          {isError && (
            <div className="rounded-xl border border-red-200 bg-red-50 p-5">
              <p className="text-[13.5px] font-medium text-red-700">
                Could not load coverage data.
              </p>
              <p className="mt-1 text-[12.5px] text-red-600">
                {error instanceof Error ? error.message : "Unknown error"}
              </p>
              <p className="mt-2 text-[12px] text-red-500">
                Check that dental-os is running on :9010.
              </p>
            </div>
          )}

          {data && (
            <>
              <div>
                <h2 className="text-[17px] font-semibold text-gray-900">
                  {data.patient_name}
                </h2>
                <p className="mt-0.5 text-[12.5px] text-gray-500">
                  {data.plan_name} · {data.provider_name} · {data.state}
                </p>
              </div>

              <CoverageCard summary={data} />

              <DowngradeAlert procedures={data.procedures} />

              <AnnualMaxBar
                thisCase={data.summary.total_insurance_pays}
                remainingAfter={data.summary.annual_max_remaining_after}
                exhausted={data.summary.annual_max_exhausted}
              />

              <CostTable
                procedures={data.procedures}
                summary={data.summary}
              />

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
            </>
          )}
        </div>
      </div>
    </div>
  );
}
