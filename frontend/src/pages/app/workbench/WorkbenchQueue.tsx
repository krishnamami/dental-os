import { useMemo, useState } from "react";
import { Link } from "react-router-dom";

import DecisionBadge from "../../../components/DecisionBadge";
import ReadinessBadge from "../../../components/ReadinessBadge";
import { toneFor } from "../../../components/SignalCard";
import { useDecision } from "../../../hooks/useApi";
import { useDemoLink } from "../../../hooks/useDemo";
import { formatCurrencyShort } from "../../../utils/format";

/**
 * D-01 — the queue.
 *
 * ⚠ ONE ROW IS REAL. DA-A01 is fetched live from dental-os; the other
 * four are static placeholders so the table has shape. They are marked
 * "sample" in the UI rather than left to look like live data — a demo
 * that cannot tell you which numbers are real is worse than one with
 * fewer rows.
 *
 * The metric cards are likewise illustrative. Making them true needs a
 * list endpoint (`GET /decisions?tenant=…`), which dental-os does not
 * have yet: today it answers per pre-D, so a real queue would be N
 * round trips.
 */

interface Row {
  predRequestId: string;
  patient: string;
  detail: string;
  procedures: string[];
  payer: string;
  decision: "approved" | "pended" | "denied";
  signals: number;
  readiness: number;
  live: boolean;
}

const SAMPLE_ROWS: Row[] = [
  {
    predRequestId: "PRED-SIM-DA-A02",
    patient: "Sandra Williams",
    detail: "Tooth #3 · $1,450",
    procedures: ["D2750"],
    payer: "Delta Dental PPO",
    decision: "approved",
    signals: 9,
    readiness: 14,
    live: false,
  },
  {
    predRequestId: "PRED-SIM-DA-C09",
    patient: "Angela Foster",
    detail: "Tooth #19 · $2,800",
    procedures: ["D6010"],
    payer: "Delta Dental PPO",
    decision: "pended",
    signals: 13,
    readiness: 9,
    live: false,
  },
  {
    predRequestId: "PRED-SIM-DA-B01",
    patient: "Daniel Reyes",
    detail: "Tooth #30 · $2,800",
    procedures: ["D6010"],
    payer: "Delta Dental PPO",
    decision: "denied",
    signals: 11,
    readiness: 7,
    live: false,
  },
  {
    predRequestId: "PRED-SIM-DA-U01",
    patient: "Frank Wilson",
    detail: "Prophylaxis · $150",
    procedures: ["D1110"],
    payer: "Delta Dental PPO",
    decision: "approved",
    signals: 12,
    readiness: 14,
    live: false,
  },
];

const TABS = ["All", "Needs action", "Ready", "Approved"] as const;
type Tab = (typeof TABS)[number];

function MetricCard({
  label,
  value,
  tone = "text-gray-900",
  note,
}: {
  label: string;
  value: string;
  tone?: string;
  note?: string;
}) {
  return (
    <div className="rounded-xl border border-gray-200 bg-white p-4">
      <p className="text-[11.5px] uppercase tracking-wide text-gray-500">
        {label}
      </p>
      <p className={`mt-1 text-[22px] font-semibold leading-none ${tone}`}>
        {value}
      </p>
      {note && <p className="mt-1.5 text-[11px] text-gray-400">{note}</p>}
    </div>
  );
}

export default function WorkbenchQueue() {
  const demoLink = useDemoLink();
  const [tab, setTab] = useState<Tab>("All");
  const { data, isLoading } = useDecision("PRED-SIM-DA-A01");

  const liveRow: Row = useMemo(
    () => ({
      predRequestId: "PRED-SIM-DA-A01",
      patient: data?.patient_name ?? "James Mitchell",
      detail: "Tooth #19 · $5,550",
      procedures: ["D6010", "D7953", "D6065"],
      payer: data?.plan_name ?? "Delta Dental PPO",
      decision: (data?.decision as Row["decision"]) ?? "pended",
      signals: data?.all_signals.length ?? 17,
      // From the engine now, not counted off the signal list.
      readiness: data?.readiness_met ?? 13,
      live: Boolean(data),
    }),
    [data],
  );

  const rows = [liveRow, ...SAMPLE_ROWS];

  const filtered = rows.filter((r) => {
    if (tab === "All") return true;
    if (tab === "Approved") return r.decision === "approved";
    if (tab === "Ready") return r.readiness >= 14;
    return r.readiness < 14;
  });

  const openSignals = data
    ? data.all_signals.filter((s) => toneFor(s) !== "green").length
    : 0;

  return (
    <div className="p-4 sm:p-6">
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <MetricCard label="Open pre-Ds" value="12" note="sample" />
        <MetricCard
          label="Submission ready"
          value="9"
          tone="text-accord-green-700"
          note="sample"
        />
        <MetricCard
          label="Needs action"
          value="3"
          tone="text-accord-amber-900"
          note="sample"
        />
        <MetricCard
          label="Revenue at risk"
          value={formatCurrencyShort(47000)}
          note="sample"
        />
      </div>

      <div className="mt-5 flex flex-wrap gap-1.5">
        {TABS.map((t) => (
          <button
            key={t}
            type="button"
            onClick={() => setTab(t)}
            className={`rounded-lg px-3 py-1.5 text-[12.5px] font-medium transition ${
              tab === t
                ? "bg-accord-green-900 text-white"
                : "border border-gray-200 bg-white text-gray-600 hover:bg-gray-50"
            }`}
          >
            {t}
          </button>
        ))}
      </div>

      <div className="mt-4 overflow-hidden rounded-xl border border-gray-200 bg-white">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[820px] text-left">
            <thead className="border-b border-gray-200 bg-gray-50">
              <tr className="text-[11px] uppercase tracking-wide text-gray-500">
                <th className="px-4 py-2.5 font-medium">Patient</th>
                <th className="px-4 py-2.5 font-medium">Procedures</th>
                <th className="px-4 py-2.5 font-medium">Payer</th>
                <th className="px-4 py-2.5 font-medium">Status</th>
                <th className="px-4 py-2.5 font-medium">Signals</th>
                <th className="px-4 py-2.5 font-medium">Readiness</th>
                <th className="px-4 py-2.5" />
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {filtered.map((r) => (
                <tr key={r.predRequestId} className="hover:bg-gray-50">
                  <td className="px-4 py-3">
                    <Link
                      to={demoLink(`/workbench/${r.predRequestId}`)}
                      className="block"
                    >
                      <span className="flex items-center gap-1.5 text-[13.5px] font-medium text-gray-900">
                        {r.patient}
                        {r.live ? (
                          <span className="rounded bg-accord-green-50 px-1.5 py-0.5 text-[9.5px] font-semibold uppercase text-accord-green-700">
                            live
                          </span>
                        ) : (
                          <span className="rounded bg-gray-100 px-1.5 py-0.5 text-[9.5px] font-semibold uppercase text-gray-500">
                            sample
                          </span>
                        )}
                      </span>
                      <span className="mt-0.5 block text-[11.5px] text-gray-500">
                        {r.detail}
                      </span>
                    </Link>
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex flex-wrap gap-1">
                      {r.procedures.map((p) => (
                        <span
                          key={p}
                          className="rounded border border-gray-200 bg-gray-50 px-1.5 py-0.5 font-mono text-[10.5px] text-gray-600"
                        >
                          {p}
                        </span>
                      ))}
                    </div>
                  </td>
                  <td className="px-4 py-3 text-[12.5px] text-gray-600">
                    {r.payer}
                  </td>
                  <td className="px-4 py-3">
                    <DecisionBadge decision={r.decision} />
                  </td>
                  <td className="px-4 py-3">
                    <span className="inline-flex items-center gap-1.5 text-[12.5px] text-gray-700">
                      <span
                        className={`h-2 w-2 rounded-full ${
                          r.readiness >= 14
                            ? "bg-accord-green-500"
                            : r.readiness >= 10
                              ? "bg-amber-400"
                              : "bg-red-500"
                        }`}
                      />
                      {r.live && isLoading ? "…" : r.signals}
                      {r.live && openSignals > 0 && (
                        <span className="text-[11px] text-gray-400">
                          ({openSignals} open)
                        </span>
                      )}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <ReadinessBadge score={r.readiness} />
                  </td>
                  <td className="px-4 py-3 text-right">
                    <Link
                      to={demoLink(`/workbench/${r.predRequestId}`)}
                      className="rounded-lg border border-gray-300 px-2.5 py-1 text-[12px] font-medium text-gray-600 transition hover:bg-gray-50"
                    >
                      Review
                    </Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <p className="mt-3 text-[11.5px] text-gray-400">
        One row is live from dental-os. The rest are sample rows — a queue
        endpoint (<code className="font-mono">GET /decisions</code>) does not
        exist yet, so a real list would be one request per pre-D.
      </p>
    </div>
  );
}
