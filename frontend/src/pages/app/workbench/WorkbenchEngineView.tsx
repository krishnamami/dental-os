import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { ArrowLeft } from "lucide-react";

import { DatePickerDropdown } from "../../../components/DatePickerDropdown";
import PreDDetail from "../../../components/PreDDetail";
import { useDatePicker } from "../../../hooks/useDatePicker";
import { api } from "../../../hooks/useApi";
import { formatCurrencyShort } from "../../../utils/format";

/**
 * D-10 — the workbench as a split panel. THE ENGINE VIEW.
 *
 * Renamed from WorkbenchPipeline when /workbench split by role; the
 * body below is untouched. This is what revenue ops and the Accord
 * admin see. The dentist gets WorkbenchClinicalView — see
 * WorkbenchRoute.
 *
 * Left: the day's queue. Right: everything about the selected pre-D.
 * `selectedId` is the only state that matters — it drives all three
 * queries, and nothing on the right is reachable except through it.
 *
 * ── The queue is live now ────────────────────────────────────────────
 *
 * It used to be a hardcoded snapshot, because dental-os answered per
 * pre-D and a real list would have been eight round trips on mount.
 * GET /decisions/queue?date= replaced that: one request, one join, no
 * persona runs, under a second.
 *
 * It is scoped by APPOINTMENT DATE, which is what puts this screen on
 * the same day as check-in and the coordinator's screen. A consequence
 * worth knowing: the queue is now the day's SCHEDULED pre-Ds, so cases
 * that were in the old hardcoded list but are not booked (C10, B01,
 * U03) no longer appear. A dentist reviewing an unscheduled case
 * reaches it by URL, as before.
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

/** Shape of a /decisions/queue row. `open` is the count of open
 *  conditions; `blocking` is how many of the case's signals carry
 *  mode === "human_approval" — the ones needing a signature. */

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

export default function WorkbenchEngineView() {
  const [clickedId, setClickedId] = useState<string | null>(null);
  // Below md the two panels share the screen one at a time.
  const [showDetail, setShowDetail] = useState(false);
  const { selectedDate, setSelectedDate, availableDates } = useDatePicker();

  const { data, isLoading } = useQuery({
    queryKey: ["decisions", "queue", selectedDate],
    queryFn: async () =>
      (
        await api.get<QueueRow[]>(
          `/decisions/queue?date=${encodeURIComponent(selectedDate)}`,
        )
      ).data,
    staleTime: 60_000,
  });
  const QUEUE: QueueRow[] = Array.isArray(data) ? data : [];

  // Derived, not stored: changing the date replaces the queue, and a
  // selectedId held in state would keep the right-hand panel on a
  // patient who is not on the new day's list.
  const selectedId =
    clickedId && QUEUE.some((r) => r.id === clickedId)
      ? clickedId
      : (QUEUE[0]?.id ?? null);

  const action = QUEUE.filter((r) => r.status !== "approved");
  const ready = QUEUE.filter((r) => r.status === "approved");
  const pended = QUEUE.filter((r) => r.status === "pended");

  function select(id: string) {
    setClickedId(id);
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

          <div className="mt-2">
            <DatePickerDropdown
              selectedDate={selectedDate}
              availableDates={availableDates}
              onChange={setSelectedDate}
            />
          </div>

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

        {isLoading && (
          <div className="animate-pulse space-y-2 px-3 py-3">
            {[0, 1, 2].map((i) => (
              <div key={i} className="h-10 rounded bg-gray-100" />
            ))}
          </div>
        )}

        {!isLoading && QUEUE.length === 0 && (
          <p className="px-3 py-4 text-[11.5px] leading-relaxed text-gray-500">
            Nobody is scheduled on this day. Pick another date above.
          </p>
        )}

        <p className="px-3 py-4 text-[11px] leading-relaxed text-gray-400">
          Live from dental-os — the day's scheduled pre-Ds, their open
          conditions and how many need a signature.
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
        {/* selectedId is null on a day with nobody booked. PreDDetail
            takes a required id, so there is nothing to render. */}
        {selectedId && (
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
        )}
      </section>

    </div>
  );
}
