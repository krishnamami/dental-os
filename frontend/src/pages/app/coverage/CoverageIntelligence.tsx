import { useEffect, useState } from "react";
import { ArrowLeft, Check, Printer } from "lucide-react";

import AnnualMaxBar from "../../../components/AnnualMaxBar";
import BenefitSummary from "../../../components/BenefitSummary";
import CostTable from "../../../components/CostTable";
import CoverageCard from "../../../components/CoverageCard";
import DowngradeAlert from "../../../components/DowngradeAlert";
import PayerComparison from "../../../components/PayerComparison";
import { useAuth } from "../../../context/AuthContext";
import { usePatientSummary } from "../../../hooks/useApi";
import { useDemo } from "../../../hooks/useDemo";
import { formatCurrency } from "../../../utils/format";

/**
 * E-01 — the front desk's morning, as a split panel.
 *
 * Left: who is coming in. Right: what their plan will actually pay,
 * live from GET /decisions/{id}/patient-summary. `selected` is the only
 * state that matters; everything on the right hangs off it.
 *
 * ── On the queue being static ────────────────────────────────────────
 *
 * There is no patient directory endpoint — dental-os answers per pre-D.
 * The five rows below are a SNAPSHOT read from the live API on
 * 7 Aug 2026, not an invention: names, payers, tooth numbers and the
 * one-line finding all came back from /patient-summary. The panel on
 * the right re-fetches; this list does not.
 */

const BRAND_GREEN = "#1B5E20";
const BRAND_AMBER = "#F57F17";

interface Patient {
  id: string;
  name: string;
  payer: string;
  procedure: string;
  dotColor: string;
  status: "action" | "ready";
  finding: string;
}

const PATIENTS: Patient[] = [
  {
    id: "PRED-SIM-DA-A01",
    name: "James Mitchell",
    payer: "Delta Dental PPO",
    procedure: "Implant + graft + crown · tooth #19",
    dotColor: BRAND_AMBER,
    status: "action",
    finding: "Annual max $25 remaining · D6065 downgrade",
  },
  {
    id: "PRED-SIM-DA-D04",
    name: "Linda Taylor",
    payer: "Delta Dental PPO",
    // Tooth #8, not #14 — the API says so. An upper central incisor is
    // also what a $1,650 all-ceramic crown is usually for.
    procedure: "Crown · tooth #8",
    dotColor: BRAND_AMBER,
    status: "action",
    finding: "D2740 reimbursed at the D2750 rate — verify with patient",
  },
  {
    id: "PRED-SIM-DA-B04",
    name: "Carlos Rivera",
    payer: "Delta Dental PPO",
    procedure: "Implant + bone graft · tooth #19",
    dotColor: BRAND_AMBER,
    status: "action",
    finding: "Bundling conflict — narrative needed · patient pays $1,230",
  },
  {
    id: "PRED-SIM-DA-U01",
    name: "Robert Thompson",
    payer: "Delta Dental PPO",
    procedure: "Prophylaxis · adult cleaning",
    dotColor: BRAND_GREEN,
    status: "ready",
    finding: "Coverage clean · patient pays $0",
  },
  {
    id: "PRED-SIM-DA-U02",
    name: "Maria Santos",
    payer: "Delta Dental PPO",
    procedure: "Bitewings · 4 films",
    dotColor: BRAND_GREEN,
    status: "ready",
    finding: "Coverage clean · patient pays $0",
  },
];

function Skeleton() {
  return (
    <div className="animate-pulse space-y-4">
      <div className="h-20 rounded-xl bg-gray-100" />
      <div className="h-14 rounded-xl bg-gray-100" />
      <div className="h-40 rounded-xl bg-gray-100" />
    </div>
  );
}

function CountCell({
  value,
  label,
  tone,
}: {
  value: number;
  label: string;
  tone: string;
}) {
  return (
    <div>
      <p className="text-[20px] font-semibold leading-none" style={{ color: tone }}>
        {value}
      </p>
      <p className="mt-1 text-[10px] uppercase tracking-wide text-gray-500">
        {label}
      </p>
    </div>
  );
}

function StatCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border border-gray-200 bg-white px-3.5 py-2.5">
      <p className="text-[10px] uppercase tracking-wide text-gray-500">{label}</p>
      <p className="mt-1 truncate text-[15px] font-semibold text-gray-900">
        {value}
      </p>
    </div>
  );
}

function QueueRow({
  patient,
  selected,
  checkedIn,
  onSelect,
  onCheckIn,
  onPrint,
}: {
  patient: Patient;
  selected: boolean;
  checkedIn: boolean;
  onSelect: () => void;
  onCheckIn: () => void;
  onPrint: () => void;
}) {
  return (
    <div
      className="border-b border-gray-100"
      style={{
        backgroundColor: selected ? "#f0f7f2" : undefined,
        borderLeft: selected
          ? `2px solid ${BRAND_GREEN}`
          : "2px solid transparent",
      }}
    >
      <button
        type="button"
        onClick={onSelect}
        aria-current={selected ? "true" : undefined}
        className="block w-full px-3 pt-2.5 text-left"
      >
        <span className="flex items-start gap-2">
          <span
            aria-hidden="true"
            className="mt-[5px] h-2 w-2 flex-shrink-0 rounded-full"
            style={{ backgroundColor: patient.dotColor }}
          />
          <span className="min-w-0 flex-1">
            <span className="flex items-baseline justify-between gap-2">
              <span className="truncate text-[13.5px] font-medium text-gray-900">
                {patient.name}
              </span>
              {checkedIn && (
                <span className="flex-shrink-0 text-[10px] font-semibold text-accord-green-700">
                  Checked in ✓
                </span>
              )}
            </span>
            <span className="mt-0.5 block truncate text-[11.5px] text-gray-500">
              {patient.payer} · {patient.procedure}
            </span>
            <span className="mt-1 block text-[11px] leading-snug text-gray-400">
              {patient.finding}
            </span>
          </span>
        </span>
      </button>

      <div className="flex gap-1.5 px-3 pb-2.5 pl-[22px] pt-1.5">
        <button
          type="button"
          onClick={onCheckIn}
          disabled={checkedIn}
          className="rounded px-2 py-1 text-[11px] font-semibold text-white transition hover:opacity-90 disabled:opacity-40"
          style={{ backgroundColor: BRAND_GREEN }}
        >
          {checkedIn ? "Checked in" : "Check-in"}
        </button>
        <button
          type="button"
          onClick={onPrint}
          className="rounded border border-gray-300 px-2 py-1 text-[11px] font-medium text-gray-600 transition hover:bg-gray-50"
        >
          Print
        </button>
      </div>
    </div>
  );
}

export default function CoverageIntelligence() {
  const { isDemo, demoPredId } = useDemo();
  const { effectiveUser } = useAuth();

  const [selected, setSelected] = useState<string>(
    // Demo mode lands on whichever case the link named; otherwise the
    // reference implant case.
    isDemo && PATIENTS.some((p) => p.id === demoPredId)
      ? demoPredId
      : PATIENTS[0].id,
  );
  const [showDetail, setShowDetail] = useState(false);
  const [checkedIn, setCheckedIn] = useState<Set<string>>(new Set());
  // A row's Print has to select the patient first and print once their
  // coverage has actually arrived — printing the previous patient's
  // sheet is the failure this avoids.
  const [pendingPrint, setPendingPrint] = useState<string | null>(null);

  const { data, isLoading, isError, error, refetch } =
    usePatientSummary(selected);

  useEffect(() => {
    if (pendingPrint && data?.pred_request_id === pendingPrint) {
      setPendingPrint(null);
      window.print();
    }
  }, [pendingPrint, data]);

  const action = PATIENTS.filter((p) => p.status === "action");
  const ready = PATIENTS.filter((p) => p.status === "ready");
  const firstName = (effectiveUser?.name ?? "").replace(/^(Dr|Mr|Mrs|Ms)\.?\s+/i, "").split(" ")[0];
  const tenantName = effectiveUser?.tenant_name ?? "Accord Dental";

  function select(id: string) {
    setSelected(id);
    setShowDetail(true);
  }

  function markCheckedIn(id: string) {
    // Local only. There is no check-in endpoint; saying "checked in"
    // and meaning "this browser tab remembers" is the honest limit.
    setCheckedIn((prev) => new Set(prev).add(id));
  }

  function printRow(id: string) {
    select(id);
    setPendingPrint(id);
  }

  return (
    <div className="md:flex md:h-[calc(100dvh-49px)] md:overflow-hidden">
      {/* ── Left: today's patients ───────────────────────────── */}
      <aside
        className={`border-gray-200 md:w-64 md:flex-shrink-0 md:overflow-y-auto md:border-r xl:w-72 ${
          showDetail ? "hidden md:block" : "block"
        }`}
      >
        <div className="border-b border-gray-200 px-3 py-3.5">
          <p className="text-[14px] font-semibold text-gray-900">
            Good morning{firstName ? `, ${firstName}` : ""}
          </p>
          <p className="mt-0.5 text-[12px] text-gray-500">
            {tenantName} · {PATIENTS.length} patients
          </p>

          <div className="mt-3 grid grid-cols-3 gap-2">
            <CountCell value={action.length} label="Action" tone="#C62828" />
            <CountCell value={ready.length} label="Ready" tone={BRAND_GREEN} />
            {/* Zero because none of the five is waiting on a document.
                Counted from the queue, not asserted. */}
            <CountCell value={0} label="Missing docs" tone={BRAND_AMBER} />
          </div>
        </div>

        <p className="px-3 pb-1 pt-3 text-[10px] font-bold uppercase tracking-[0.12em] text-gray-400">
          Need my action
        </p>
        {action.map((p) => (
          <QueueRow
            key={p.id}
            patient={p}
            selected={p.id === selected}
            checkedIn={checkedIn.has(p.id)}
            onSelect={() => select(p.id)}
            onCheckIn={() => markCheckedIn(p.id)}
            onPrint={() => printRow(p.id)}
          />
        ))}

        <div className="my-2 border-t border-gray-200" />

        <p className="px-3 pb-1 pt-1 text-[10px] font-bold uppercase tracking-[0.12em] text-gray-400">
          Ready to check in
        </p>
        {ready.map((p) => (
          <QueueRow
            key={p.id}
            patient={p}
            selected={p.id === selected}
            checkedIn={checkedIn.has(p.id)}
            onSelect={() => select(p.id)}
            onCheckIn={() => markCheckedIn(p.id)}
            onPrint={() => printRow(p.id)}
          />
        ))}

        <p className="px-3 py-4 text-[11px] leading-relaxed text-gray-400">
          Five patients, read from the API on 7 Aug 2026. There is no patient
          directory endpoint yet, so this list does not refresh — the panel on
          the right does.
        </p>
      </aside>

      {/* ── Right: what the plan pays ────────────────────────── */}
      <section
        className={`min-w-0 flex-1 flex-col md:flex ${
          showDetail ? "flex" : "hidden"
        }`}
      >
        <div className="flex-1 overflow-y-auto px-4 py-4 sm:px-5">
          <button
            type="button"
            onClick={() => setShowDetail(false)}
            className="mb-3 inline-flex min-h-[36px] items-center gap-1.5 text-[12.5px] font-medium text-gray-500 hover:text-gray-900 md:hidden"
          >
            <ArrowLeft size={14} />
            Patients
          </button>

          {isLoading && <Skeleton />}

          {isError && (
            <div className="rounded-xl border border-red-200 bg-red-50 p-5">
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
            <div className="space-y-4">
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div className="min-w-0">
                  <h2 className="text-[19px] font-semibold text-gray-900 sm:text-xl">
                    {data.patient_name}
                  </h2>
                  <p className="mt-0.5 text-[12.5px] text-gray-500">
                    {data.plan_name} · {data.provider_name} · {data.state}
                  </p>
                </div>
                {checkedIn.has(selected) && (
                  <span className="inline-flex items-center gap-1 rounded-full bg-accord-green-50 px-2.5 py-1 text-[11.5px] font-semibold text-accord-green-700">
                    <Check size={12} strokeWidth={3} />
                    Checked in
                  </span>
                )}
              </div>

              {/* Four numbers a front desk is asked for by name. Read
                  from the payload — the deductible is $50 remaining on
                  these plans, not met. */}
              <div className="grid grid-cols-2 gap-2.5 lg:grid-cols-4">
                <StatCard
                  label="Annual max remaining"
                  value={formatCurrency(data.annual_max_remaining_before)}
                />
                <StatCard
                  label="Deductible remaining"
                  value={formatCurrency(data.deductible_remaining_before)}
                />
                <StatCard label="Payer" value={data.plan_name} />
                <StatCard
                  label="After this case"
                  value={formatCurrency(data.summary.annual_max_remaining_after)}
                />
              </div>

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
            </div>
          )}
        </div>

        {/* ── Actions ────────────────────────────────────────── */}
        <footer className="border-t border-gray-200 bg-white px-4 py-2.5 sm:px-5">
          <div className="flex flex-wrap gap-2">
            <button
              type="button"
              onClick={() => window.print()}
              disabled={!data}
              className="inline-flex min-h-[36px] items-center gap-1.5 rounded-lg px-3.5 text-[12.5px] font-semibold text-white transition hover:opacity-90 disabled:opacity-40"
              style={{ backgroundColor: BRAND_GREEN }}
            >
              <Printer size={13} />
              Print patient summary
            </button>
            <button
              type="button"
              disabled={!data}
              title="Demo only — there is no mail path from the browser"
              className="min-h-[36px] rounded-lg border border-gray-300 px-3.5 text-[12.5px] font-medium text-gray-700 transition hover:bg-gray-50 disabled:opacity-40"
            >
              Email to patient
            </button>
            <button
              type="button"
              onClick={() => markCheckedIn(selected)}
              disabled={checkedIn.has(selected)}
              className="min-h-[36px] rounded-lg border border-gray-300 px-3.5 text-[12.5px] font-medium text-gray-700 transition hover:bg-gray-50 disabled:opacity-40"
            >
              {checkedIn.has(selected) ? "Checked in ✓" : "Mark checked in"}
            </button>
            <span className="ml-auto self-center text-[10.5px] text-gray-400">
              Check-in is remembered in this tab only
            </span>
          </div>
        </footer>
      </section>
    </div>
  );
}
