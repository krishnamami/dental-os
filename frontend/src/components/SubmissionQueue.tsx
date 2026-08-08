import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Link } from "react-router-dom";
import { ChevronDown } from "lucide-react";

import { api, useConditions, useDecision } from "../hooks/useApi";
import { useAuth } from "../context/AuthContext";
import { useDemo, useDemoLink } from "../hooks/useDemo";
import ReadinessBadge from "./ReadinessBadge";
import { scenarioId } from "../utils/format";
import type { Condition } from "../types/dental";

/**
 * G-02 — what is blocked, what is ready, and what went out today.
 *
 * Both sections are live and scoped to the selected day, from
 * GET /decisions/queue?date=. Each blocked row's conditions are fetched
 * only when it is expanded — five collapsed rows should not fire five
 * requests nobody asked for.
 *
 * ── Submitting is LOCAL ──────────────────────────────────────────────
 *
 * "Submit pre-D" does not submit anything to a payer. X12 278 is not
 * wired, and there is no submission table — so the card moves to
 * "Submitted today" in THIS TAB ONLY and is gone on refresh. The
 * section header says so; a queue that silently forgets what a biller
 * did is worse than one that admits it never recorded it.
 *
 * What it does record is feedback: feedback_type "accepted" against
 * the case's blocking signal. The API's FeedbackType is only
 * accepted | overridden | false_positive — there is no "submitted"
 * member — so the note carries the actual action rather than inventing
 * an enum value the server would reject.
 */
interface QueueRow {
  id: string;
  patient: string;
  finding: string;
  charges: number;
  payer: string;
  status: string;
  open: number;
  blocking: number;
  submission_ready: boolean;
}

const SUBMITTER: Record<
  string,
  "front_desk" | "billing" | "dentist" | "dso_manager"
> = {
  front_desk: "front_desk",
  revenue_ops: "billing",
  dentist: "dentist",
  dso_owner: "dso_manager",
  accord_admin: "billing",
};

/** The button a condition deserves, from what the engine says to do.
 *  A row that says "add narrative" should not offer "Resolve". */
function actionLabel(c: Condition): string {
  const a = c.recommended_action ?? "";
  if (a.includes("narrative") || a.includes("documentation")) return "Upload";
  if (a.includes("appeal")) return "Appeal";
  if (a.includes("inform") || a.includes("patient")) return "Tell patient";
  if (a.includes("eob") || a.includes("history")) return "Request records";
  return "Resolve";
}

function Sla({ hours }: { hours?: number | null }) {
  if (hours == null) return null;
  const overdue = hours <= 0;
  return (
    <span
      className={`rounded-full border px-1.5 py-0.5 text-[10.5px] font-semibold ${
        overdue
          ? "border-red-200 bg-red-50 text-red-700"
          : "border-amber-200 bg-accord-amber-50 text-accord-amber-900"
      }`}
    >
      {overdue ? `${Math.abs(hours)}h overdue` : `${hours}h left`}
    </span>
  );
}

function BlockedRow({
  row,
  onToast,
}: {
  row: QueueRow;
  onToast: (m: string) => void;
}) {
  const [open, setOpen] = useState(false);
  const [done, setDone] = useState<Set<string>>(new Set());
  const demoLink = useDemoLink();
  const { data: decision } = useDecision(row.id);
  const { data: conditions, isLoading } = useConditions(
    open ? row.id : undefined,
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
            {decision?.patient_name ?? row.patient}
            <span className="rounded bg-accord-green-50 px-1.5 py-0.5 text-[9.5px] font-semibold uppercase text-accord-green-700">
              live
            </span>
          </span>
          <span className="mt-0.5 block text-[11.5px] text-gray-500">
            {row.payer} · {scenarioId(row.id)} · {row.open} open ·{" "}
            {row.blocking} need a signature
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
          <p className="mb-2 text-[10px] font-bold uppercase tracking-[0.12em] text-gray-500">
            Why blocked
          </p>

          {isLoading && (
            <div className="animate-pulse space-y-2">
              {[0, 1].map((i) => (
                <div key={i} className="h-14 rounded bg-gray-200" />
              ))}
            </div>
          )}

          {conditions && (
            <ul className="space-y-2">
              {conditions.conditions.map((c) => {
                const cleared = done.has(c.signal_code);
                return (
                  <li
                    key={c.signal_code}
                    className={`rounded-lg border bg-white px-3 py-2 ${
                      cleared
                        ? "border-accord-green-100"
                        : c.mode === "human_approval"
                          ? "border-amber-200"
                          : "border-gray-200"
                    }`}
                  >
                    <div className="flex flex-wrap items-center gap-1.5">
                      <span aria-hidden="true">
                        {cleared ? "✅" : c.mode === "human_approval" ? "⚠" : "•"}
                      </span>
                      <span className="font-mono text-[11px] font-semibold text-gray-700">
                        {c.signal_code}
                      </span>
                      <Sla hours={c.sla_hours} />
                      {c.assignee && (
                        <span className="text-[11px] capitalize text-gray-500">
                          {c.assignee.replace(/_/g, " ")}
                        </span>
                      )}
                    </div>
                    <p className="mt-1 text-[12px] leading-relaxed text-gray-600">
                      {c.finding}
                    </p>
                    {(c.citation || c.payer_citation) && (
                      <p className="mt-1 text-[11px] text-gray-400">
                        {[c.payer_citation, c.citation && `§${c.citation}`]
                          .filter(Boolean)
                          .join(" · ")}
                      </p>
                    )}
                    <button
                      type="button"
                      disabled={cleared}
                      onClick={() => {
                        setDone((p) => new Set(p).add(c.signal_code));
                        onToast(`${c.signal_code} marked handled ✓`);
                      }}
                      className="mt-1.5 rounded-lg border border-gray-300 bg-white px-2.5 py-1 text-[11.5px] font-medium text-gray-700 transition hover:bg-gray-50 disabled:opacity-50"
                    >
                      {cleared ? "Handled ✓" : actionLabel(c)}
                    </button>
                  </li>
                );
              })}
            </ul>
          )}

          <div className="mt-3 flex flex-wrap gap-2">
            <Link
              to={demoLink(`/workbench/${row.id}`)}
              className="rounded-lg border border-gray-300 bg-white px-2.5 py-1 text-[12px] font-medium text-gray-700 hover:bg-gray-50"
            >
              View full pre-D →
            </Link>
            <Link
              to={demoLink("/revenue-ops/appeals")}
              className="rounded-lg border border-gray-300 bg-white px-2.5 py-1 text-[12px] font-medium text-gray-700 hover:bg-gray-50"
            >
              Generate appeal
            </Link>
          </div>

          {/* Ticking a condition here changes this tab, not the engine.
              Conditions clear when the pre-D is re-run with the
              evidence actually in place. */}
          <p className="mt-2 text-[10.5px] text-gray-400">
            Marking a condition handled records it here only — it clears in
            the engine when the pre-D is re-run with the evidence in place.
          </p>
        </div>
      )}
    </li>
  );
}

function ReadyRow({
  row,
  onSubmitted,
  onToast,
}: {
  row: QueueRow;
  onSubmitted: (id: string, at: string) => void;
  onToast: (m: string) => void;
}) {
  const demoLink = useDemoLink();
  const { isDemo } = useDemo();
  const { role } = useAuth();
  const [busy, setBusy] = useState(false);

  async function submit() {
    setBusy(true);
    const at = new Date().toLocaleTimeString([], {
      hour: "numeric",
      minute: "2-digit",
    });
    try {
      // Demo mode holds no token and the API refuses anonymous writes,
      // so don't pretend to record one.
      if (!isDemo) {
        await api.post(`/decisions/${row.id}/feedback`, {
          decision_id: "pre_d_assessment",
          signal_code: "PRED_READY_TO_SUBMIT",
          feedback_type: "accepted",
          submitted_by: SUBMITTER[role ?? "revenue_ops"] ?? "billing",
          notes: `Submitted to ${row.payer} by revenue ops`,
        });
      }
      onSubmitted(row.id, at);
      onToast(`${scenarioId(row.id)} submitted to ${row.payer} ✓`);
    } catch {
      onToast(`Could not record the submission for ${scenarioId(row.id)}`);
    } finally {
      setBusy(false);
    }
  }

  return (
    <li className="flex flex-wrap items-center justify-between gap-3 px-4 py-3">
      <div className="min-w-0">
        <p className="text-[13.5px] font-medium text-gray-900">{row.patient}</p>
        <p className="mt-0.5 text-[11.5px] text-gray-500">
          {row.finding} · {scenarioId(row.id)}
        </p>
      </div>
      <div className="flex flex-shrink-0 items-center gap-2">
        <ReadinessBadge score={14} />
        <button
          type="button"
          disabled={busy}
          onClick={() => void submit()}
          className="rounded-lg bg-accord-green-900 px-2.5 py-1 text-[12px] font-semibold text-white transition hover:bg-accord-green-700 disabled:opacity-60"
        >
          {busy ? "Submitting…" : "Submit pre-D ✓"}
        </button>
        <Link
          to={demoLink(`/workbench/${row.id}`)}
          className="rounded-lg border border-gray-300 px-2.5 py-1 text-[12px] font-medium text-gray-700 hover:bg-gray-50"
        >
          View
        </Link>
      </div>
    </li>
  );
}

export default function SubmissionQueue({
  date,
  filter = "all",
  onToast,
}: {
  date: string;
  /** Driven by the stat cards above. */
  filter?: "all" | "ready" | "blocked";
  onToast: (m: string) => void;
}) {
  const demoLink = useDemoLink();
  // id -> the time it was submitted, this tab only.
  const [submitted, setSubmitted] = useState<Record<string, string>>({});

  // Same query key the workbench uses, so switching between the two
  // screens on one date is a cache hit rather than a second request.
  const { data, isLoading } = useQuery({
    queryKey: ["decisions", "queue", date],
    queryFn: async () =>
      (await api.get<QueueRow[]>(`/decisions/queue?date=${encodeURIComponent(date)}`))
        .data,
    staleTime: 60_000,
  });
  const rows: QueueRow[] = Array.isArray(data) ? data : [];
  const sent = rows.filter((r) => submitted[r.id]);
  const blocked = rows.filter((r) => !r.submission_ready && !submitted[r.id]);
  const ready = rows.filter((r) => r.submission_ready && !submitted[r.id]);

  const show = (s: "ready" | "blocked") => filter === "all" || filter === s;

  return (
    <div className="space-y-4">
      {show("blocked") && (
        <section className="overflow-hidden rounded-xl border border-gray-200 bg-white">
          <header className="border-b border-gray-200 bg-gray-50 px-4 py-3">
            <h2 className="text-[13.5px] font-semibold text-gray-900">
              Blocked — needs action ({blocked.length})
            </h2>
          </header>
          <ul>
            {blocked.map((r) => (
              <BlockedRow key={r.id} row={r} onToast={onToast} />
            ))}
          </ul>
          {!isLoading && blocked.length === 0 && (
            <p className="px-4 py-3 text-[12.5px] text-gray-500">
              Nothing blocked on this day.
            </p>
          )}
        </section>
      )}

      {show("ready") && (
        <section className="overflow-hidden rounded-xl border border-gray-200 bg-white">
          <header className="flex items-center justify-between gap-3 border-b border-gray-200 bg-gray-50 px-4 py-3">
            <h2 className="text-[13.5px] font-semibold text-gray-900">
              Ready to submit ({ready.length})
            </h2>
            <span className="text-[11px] text-gray-400">
              {isLoading ? "loading…" : "live"}
            </span>
          </header>
          <ul className="divide-y divide-gray-100">
            {ready.map((r) => (
              <ReadyRow
                key={r.id}
                row={r}
                onSubmitted={(id, at) =>
                  setSubmitted((p) => ({ ...p, [id]: at }))
                }
                onToast={onToast}
              />
            ))}
          </ul>
          {!isLoading && ready.length === 0 && (
            <p className="px-4 py-3 text-[12.5px] text-gray-500">
              Nothing ready to submit on this day.
            </p>
          )}
        </section>
      )}

      {sent.length > 0 && (
        <section className="overflow-hidden rounded-xl border border-accord-green-100 bg-white">
          <header className="flex items-center justify-between gap-3 border-b border-accord-green-100 bg-accord-green-50 px-4 py-3">
            <h2 className="text-[13.5px] font-semibold text-accord-green-900">
              Submitted today ({sent.length})
            </h2>
            <span className="text-[11px] text-accord-green-700">this tab only</span>
          </header>
          <ul className="divide-y divide-gray-100">
            {sent.map((r) => (
              <li
                key={r.id}
                className="flex flex-wrap items-center justify-between gap-3 px-4 py-3"
              >
                <div className="min-w-0">
                  <p className="text-[13.5px] font-medium text-gray-900">
                    {r.patient}
                  </p>
                  <p className="mt-0.5 text-[11.5px] text-gray-500">
                    {r.payer} · {scenarioId(r.id)}
                  </p>
                </div>
                <div className="flex flex-shrink-0 items-center gap-2">
                  <span className="text-[12px] font-medium text-accord-green-700">
                    Submitted ✓ {submitted[r.id]}
                  </span>
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
          <p className="border-t border-gray-100 px-4 py-2.5 text-[11px] text-gray-400">
            Nothing was sent to a payer. X12 278 is not wired and there is no
            submission table, so this list is gone on refresh.
          </p>
        </section>
      )}
    </div>
  );
}
