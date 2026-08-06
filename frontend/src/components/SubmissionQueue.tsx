import { useState } from "react";
import { Link } from "react-router-dom";
import { ChevronDown } from "lucide-react";

import { useConditions, useDecision } from "../hooks/useApi";
import { useDemoLink } from "../hooks/useDemo";
import ReadinessBadge from "./ReadinessBadge";
import { scenarioId } from "../utils/format";

/**
 * G-02 — what is blocked and what is ready.
 *
 * DA-A01 is live in the blocked section, its conditions fetched on
 * expand rather than up front — five collapsed rows should not fire
 * five requests nobody asked for.
 *
 * The ready rows are DA-U01..U05, Group U, which the corpus builds as
 * uncontested single-code approvals. They are labelled "sample"
 * because there is no queue endpoint: dental-os answers per pre-D, so
 * a real list would be one request each. Their names and procedures
 * are real; their readiness is not fetched.
 */
const READY_ROWS = [
  { id: "PRED-SIM-DA-U01", patient: "Robert Thompson", proc: "D1110 prophylaxis" },
  { id: "PRED-SIM-DA-U02", patient: "Angela Brooks", proc: "D0274 bitewings" },
  { id: "PRED-SIM-DA-U03", patient: "Kevin Lee", proc: "D2391 composite" },
  { id: "PRED-SIM-DA-U04", patient: "Dorothy Chen", proc: "D7140 extraction" },
  { id: "PRED-SIM-DA-U05", patient: "Frank Wilson", proc: "D4910 perio maint." },
];

function BlockedRow({ predRequestId }: { predRequestId: string }) {
  const [open, setOpen] = useState(false);
  const demoLink = useDemoLink();
  const { data: decision } = useDecision(predRequestId);
  // Only fetched once the row is open.
  const { data: conditions, isLoading } = useConditions(
    open ? predRequestId : undefined,
  );

  return (
    <li className="border-b border-gray-100 last:border-b-0">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        aria-expanded={open}
        className="flex w-full items-center justify-between gap-3 px-4 py-3 text-left transition hover:bg-gray-50"
      >
        <span className="min-w-0">
          <span className="flex items-center gap-1.5 text-[13.5px] font-medium text-gray-900">
            {decision?.patient_name ?? scenarioId(predRequestId)}
            <span className="rounded bg-accord-green-50 px-1.5 py-0.5 text-[9.5px] font-semibold uppercase text-accord-green-700">
              live
            </span>
          </span>
          <span className="mt-0.5 block text-[11.5px] text-gray-500">
            {decision?.plan_name} · {scenarioId(predRequestId)} ·{" "}
            {decision?.open_conditions.length ?? "—"} open
          </span>
        </span>
        <span className="flex flex-shrink-0 items-center gap-2">
          {decision && (
            <ReadinessBadge
              score={decision.readiness_met ?? 0}
              total={decision.readiness_total ?? 14}
            />
          )}
          <ChevronDown
            size={16}
            className={`text-gray-400 transition-transform ${open ? "rotate-180" : ""}`}
          />
        </span>
      </button>

      {open && (
        <div className="border-t border-gray-100 bg-gray-50 px-4 py-3">
          {isLoading && (
            <div className="animate-pulse space-y-2">
              {[0, 1].map((i) => (
                <div key={i} className="h-8 rounded bg-gray-200" />
              ))}
            </div>
          )}
          {conditions && (
            <ul className="space-y-1.5">
              {conditions.conditions.map((c) => (
                <li
                  key={c.signal_code}
                  className="flex flex-wrap items-center gap-x-2 gap-y-1 text-[12px]"
                >
                  <span className="font-mono font-semibold text-gray-700">
                    {c.signal_code}
                  </span>
                  {c.sla_hours != null && (
                    <span className="rounded-full border border-amber-200 bg-accord-amber-50 px-1.5 py-0.5 text-[10.5px] font-semibold text-accord-amber-900">
                      {c.sla_hours}h
                    </span>
                  )}
                  {c.assignee && (
                    <span className="text-[11px] capitalize text-gray-500">
                      {c.assignee.replace(/_/g, " ")}
                    </span>
                  )}
                </li>
              ))}
            </ul>
          )}
          <div className="mt-3 flex flex-wrap gap-2">
            <Link
              to={demoLink(`/workbench/${predRequestId}`)}
              className="rounded-lg border border-gray-300 bg-white px-2.5 py-1 text-[12px] font-medium text-gray-700 hover:bg-gray-50"
            >
              Resolve in workbench
            </Link>
            <Link
              to={demoLink("/revenue-ops/appeals")}
              className="rounded-lg border border-gray-300 bg-white px-2.5 py-1 text-[12px] font-medium text-gray-700 hover:bg-gray-50"
            >
              Generate appeal
            </Link>
          </div>
        </div>
      )}
    </li>
  );
}

export default function SubmissionQueue() {
  const demoLink = useDemoLink();
  const [notice, setNotice] = useState("");

  return (
    <div className="space-y-4">
      <section className="overflow-hidden rounded-xl border border-gray-200 bg-white">
        <header className="border-b border-gray-200 bg-gray-50 px-4 py-3">
          <h2 className="text-[13.5px] font-semibold text-gray-900">
            Blocked — needs action
          </h2>
        </header>
        <ul>
          <BlockedRow predRequestId="PRED-SIM-DA-A01" />
          <BlockedRow predRequestId="PRED-SIM-DA-C01" />
        </ul>
      </section>

      <section className="overflow-hidden rounded-xl border border-gray-200 bg-white">
        <header className="flex items-center justify-between gap-3 border-b border-gray-200 bg-gray-50 px-4 py-3">
          <h2 className="text-[13.5px] font-semibold text-gray-900">
            Ready to submit
          </h2>
          <span className="text-[11px] text-gray-400">sample rows</span>
        </header>
        <ul className="divide-y divide-gray-100">
          {READY_ROWS.map((r) => (
            <li
              key={r.id}
              className="flex flex-wrap items-center justify-between gap-3 px-4 py-3"
            >
              <div className="min-w-0">
                <p className="text-[13.5px] font-medium text-gray-900">
                  {r.patient}
                </p>
                <p className="mt-0.5 text-[11.5px] text-gray-500">
                  {r.proc} · {scenarioId(r.id)}
                </p>
              </div>
              <div className="flex flex-shrink-0 items-center gap-2">
                <ReadinessBadge score={14} />
                <button
                  type="button"
                  onClick={() =>
                    setNotice("Submission flow coming soon — X12 278 is not wired yet.")
                  }
                  className="rounded-lg bg-accord-green-900 px-2.5 py-1 text-[12px] font-semibold text-white transition hover:bg-accord-green-700"
                >
                  Submit pre-D
                </button>
                <Link
                  to={demoLink(`/workbench/${r.id}`)}
                  className="rounded-lg border border-gray-300 px-2.5 py-1 text-[12px] font-medium text-gray-700 hover:bg-gray-50"
                >
                  View
                </Link>
              </div>
            </li>
          ))}
        </ul>
        {notice && (
          <p className="border-t border-gray-100 px-4 py-2.5 text-[12px] text-accord-amber-900">
            {notice}
          </p>
        )}
      </section>
    </div>
  );
}
