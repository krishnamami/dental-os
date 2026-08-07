import { useState } from "react";
import { ArrowLeft } from "lucide-react";

import PreDDetail from "../../../components/PreDDetail";
import { formatCurrencyShort } from "../../../utils/format";

/**
 * D-10 — the workbench as a split panel.
 *
 * Left: the day's queue. Right: everything about the selected pre-D.
 * `selectedId` is the only state that matters — it drives all three
 * queries, and nothing on the right is reachable except through it.
 *
 * ── On the queue being static ────────────────────────────────────────
 *
 * There is still no list endpoint. dental-os answers per pre-D, so a
 * genuinely live queue would be eight round trips on mount — and in
 * production there is no API behind CloudFront at all, so all eight
 * would fail and the fallback is what every visitor actually sees.
 *
 * So the rows below are a SNAPSHOT, not an invention: every name,
 * decision, dollar figure and payer was read from
 * `GET /decisions/{id}` and `/patient-summary` on 2026-08-06 and copied
 * verbatim. When the API is reachable the selected row's header
 * upgrades to live values, and the "live"/"snapshot" chip says which
 * you are looking at. If a snapshot value ever disagrees with the live
 * one, the snapshot is stale and this list is what needs updating.
 */

type Status = "approved" | "pended" | "denied";

interface QueueRow {
  id: string;
  patient: string;
  finding: string;
  charges: number;
  payer: string;
  status: Status;
  /** Open conditions on the case, from the same snapshot. */
  open: number;
  /** Of those, how many need a signature (mode === human_approval). */
  blocking: number;
}

const QUEUE: QueueRow[] = [
  {
    id: "PRED-SIM-DA-A01",
    patient: "James Mitchell",
    finding: "Bundling conflict · D7953 + D6010",
    charges: 5550,
    payer: "Delta Dental PPO",
    status: "pended",
    open: 8,
    blocking: 3,
  },
  {
    id: "PRED-SIM-DA-B04",
    patient: "Carlos Rivera",
    finding: "Appeal viable · 65% success probability",
    charges: 3750,
    payer: "Delta Dental PPO",
    status: "pended",
    open: 7,
    blocking: 3,
  },
  {
    id: "PRED-SIM-DA-C10",
    patient: "John Miller",
    finding: "OIG excluded provider",
    charges: 1190,
    payer: "Delta Dental PPO",
    status: "pended",
    open: 6,
    blocking: 5,
  },
  {
    id: "PRED-SIM-DA-B01",
    patient: "Patricia Johnson",
    finding: "Hard exclusion · implants not covered",
    charges: 4600,
    payer: "Delta Dental PPO",
    status: "denied",
    open: 7,
    blocking: 2,
  },
  {
    id: "PRED-SIM-DA-D04",
    patient: "Linda Taylor",
    finding: "Crown D2740 → D2750 downgrade",
    charges: 1650,
    payer: "Delta Dental PPO",
    status: "approved",
    open: 4,
    blocking: 2,
  },
  {
    id: "PRED-SIM-DA-U01",
    patient: "Robert Thompson",
    finding: "Clean · D1110 prophylaxis",
    charges: 150,
    payer: "Delta Dental PPO",
    status: "approved",
    open: 3,
    blocking: 1,
  },
  {
    id: "PRED-SIM-DA-U02",
    patient: "Maria Santos",
    finding: "Clean · D0274 bitewings",
    charges: 85,
    payer: "Delta Dental PPO",
    status: "approved",
    open: 4,
    blocking: 1,
  },
  {
    id: "PRED-SIM-DA-U03",
    patient: "Kevin Lee",
    finding: "Clean · D2391 composite",
    charges: 175,
    payer: "Cigna DPPO",
    status: "approved",
    open: 3,
    blocking: 1,
  },
];

const DOT: Record<Status, string> = {
  approved: "bg-accord-green-500",
  pended: "bg-amber-400",
  denied: "bg-red-500",
};


// ── Left panel ───────────────────────────────────────────────────────

function QueueItem({
  row,
  selected,
  onSelect,
}: {
  row: QueueRow;
  selected: boolean;
  onSelect: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onSelect}
      aria-current={selected ? "true" : undefined}
      className={`block w-full border-l-[3px] px-3 py-3 text-left transition ${
        selected
          ? "border-l-accord-green-500 bg-accord-green-50"
          : "border-l-transparent hover:bg-gray-50"
      }`}
    >
      <span className="flex items-start gap-2">
        <span
          aria-hidden="true"
          className={`mt-[5px] h-2 w-2 flex-shrink-0 rounded-full ${DOT[row.status]}`}
        />
        <span className="min-w-0 flex-1">
          <span className="flex items-baseline justify-between gap-2">
            <span className="truncate text-[13.5px] font-medium text-gray-900">
              {row.patient}
            </span>
            <span className="flex-shrink-0 text-[11px] capitalize text-gray-400">
              {row.status}
            </span>
          </span>
          <span className="mt-0.5 block truncate text-[12px] text-gray-500">
            {row.finding}
          </span>
          <span className="mt-1 block text-[11px] text-gray-400">
            {formatCurrencyShort(row.charges)} · {row.payer}
            {row.blocking > 0 && ` · ${row.blocking} need a signature`}
          </span>
        </span>
      </span>
    </button>
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
      <p className={`text-[20px] font-semibold leading-none ${tone}`}>{value}</p>
      <p className="mt-1 text-[10px] uppercase tracking-wide text-gray-500">
        {label}
      </p>
    </div>
  );
}

export default function WorkbenchPipeline() {
  const [selectedId, setSelectedId] = useState(QUEUE[0].id);
  // Below md the two panels share the screen one at a time.
  const [showDetail, setShowDetail] = useState(false);

  // No queries here any more. PreDDetail owns every request the right
  // half makes; this component's only job is which pre-D is selected.
  const action = QUEUE.filter((r) => r.status !== "approved");
  const ready = QUEUE.filter((r) => r.status === "approved");
  const pended = QUEUE.filter((r) => r.status === "pended");

  function select(id: string) {
    setSelectedId(id);
    setShowDetail(true);
  }

  return (
    <div className="md:flex md:h-[calc(100dvh-49px)] md:overflow-hidden">
      {/* ── Left: the queue ──────────────────────────────────── */}
      <aside
        className={`border-gray-200 md:w-56 md:flex-shrink-0 md:overflow-y-auto md:border-r xl:w-72 ${
          showDetail ? "hidden md:block" : "block"
        }`}
      >
        <div className="border-b border-gray-200 px-3 py-3.5">
          <p className="text-[14px] font-semibold text-gray-900">
            Good morning, Dr. Chinta
          </p>
          <p className="mt-0.5 text-[12px] text-gray-500">
            Suwanee Smiles · {action.length} need action
          </p>

          <div className="mt-3 grid grid-cols-3 gap-2">
            <CountCell
              value={action.length}
              label="Action"
              tone="text-accord-amber-900"
            />
            <CountCell value={pended.length} label="Pending" tone="text-gray-900" />
            <CountCell
              value={ready.length}
              label="Done"
              tone="text-accord-green-700"
            />
          </div>
        </div>

        <p className="px-3 pb-1 pt-3 text-[10px] font-bold uppercase tracking-[0.12em] text-gray-400">
          Need my action
        </p>
        {action.map((r) => (
          <QueueItem
            key={r.id}
            row={r}
            selected={r.id === selectedId}
            onSelect={() => select(r.id)}
          />
        ))}

        <div className="my-2 border-t border-gray-200" />

        <p className="px-3 pb-1 pt-1 text-[10px] font-bold uppercase tracking-[0.12em] text-gray-400">
          Ready to submit
        </p>
        {ready.map((r) => (
          <QueueItem
            key={r.id}
            row={r}
            selected={r.id === selectedId}
            onSelect={() => select(r.id)}
          />
        ))}

        <p className="px-3 py-4 text-[11px] leading-relaxed text-gray-400">
          Eight cases, read from the API on 6 Aug 2026. There is no list
          endpoint yet, so this list does not refresh — the panel on the
          right does.
        </p>
      </aside>

      {/* ── Right: the selected pre-D ────────────────────────── */}
      {/* The whole detail view is PreDDetail — the same component
          /workbench/:id renders. Two copies of a 500-line chart view
          is how the same case ends up described two ways. */}
      <section
        className={`min-w-0 flex-1 flex-col overflow-y-auto md:flex ${
          showDetail ? "flex" : "hidden"
        }`}
      >
        <PreDDetail
          predRequestId={selectedId}
          beforeTopbar={
            <button
              type="button"
              onClick={() => setShowDetail(false)}
              className="inline-flex min-h-[36px] items-center gap-1.5 border-b border-gray-200 px-4 text-[12.5px] font-medium text-gray-500 hover:text-gray-900 md:hidden"
            >
              <ArrowLeft size={14} />
              Queue
            </button>
          }
        />
      </section>

    </div>
  );
}
