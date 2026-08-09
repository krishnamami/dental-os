import { useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { Link, useNavigate } from "react-router-dom";
import { ChevronDown } from "lucide-react";

import {
  api,
  useConditions,
  useDecision,
  useSubmittedOn,
  type SubmissionRow,
} from "../hooks/useApi";
import { useAuth } from "../context/AuthContext";
import { useDemo, useDemoLink } from "../hooks/useDemo";
import ReadinessBadge from "./ReadinessBadge";
import { scenarioId } from "../utils/format";
import { daysSince, deadlineFrom, queueTone } from "./BillingDetail";
import type { Condition } from "../types/dental";

/**
 * G-02 — what is blocked, what is ready, and what went out today.
 *
 * Both sections are live and scoped to the selected day, from
 * GET /decisions/queue?date=. Each blocked row's conditions are fetched
 * only when it is expanded — five collapsed rows should not fire five
 * requests nobody asked for.
 *
 * ── Submitting is RECORDED now, but still not TRANSMITTED ────────────
 *
 * "Submit pre-D" posts to /decisions/:id/submit, which writes a row to
 * submission_events. "Submitted today" is read back from
 * /decisions/submitted?date= and survives a refresh — it used to be a
 * useState that forgot everything the moment the tab reloaded.
 *
 * It still does not reach a payer. X12 278 and NEA FastAttach are not
 * connected, and the section footer says so. What changed is that a
 * practice can now answer "when did we send it and who sent it", which
 * nothing could answer before.
 *
 * The local `justSent` map is optimism only — it moves the card before
 * the refetch lands. submission_events is the truth.
 */
interface QueueRow {
  id: string;
  patient: string;
  finding: string;
  charges: number;
  payer: string;
  payer_id: string;
  status: string;
  open: number;
  blocking: number;
  submission_ready: boolean;
  /** pred_requests.created_at — when the case entered the queue. */
  created_at?: string | null;
  /** NULL on every row in this corpus: nothing has ever been sent. */
  submitted_at?: string | null;
}

/**
 * How long this has been sitting, and how long the payer window has left.
 *
 * The window runs from created_at, NOT submitted_at. submitted_at is
 * null on every case in this corpus because nothing has ever gone out,
 * so dating a 90-day validity from submission would print the same
 * deadline — 90 days from today — on every card, which is the least
 * useful answer available.
 */
function Ages({ row }: { row: QueueRow }) {
  const days = daysSince(row.created_at);
  const dl = deadlineFrom(row.created_at);
  if (days == null) return null;
  return (
    <div className="mt-1 flex flex-wrap items-center gap-2 text-[11px] text-gray-500">
      <span style={{ color: queueTone(days) }}>
        In queue: {days} {days === 1 ? "day" : "days"}
      </span>
      <span aria-hidden="true">·</span>
      <span style={{ color: dl.tone }}>
        Payer deadline: {dl.label}
        {dl.daysLeft != null && ` (${dl.daysLeft}d)`}
      </span>
    </div>
  );
}

/** Which team owns a condition. Same rule as the billing detail view. */
function ownerOf(assignee?: string): "billing" | "front_desk" | "clinical" {
  const a = assignee ?? "";
  if (a === "billing" || a === "dso_manager") return "billing";
  if (a === "front_desk") return "front_desk";
  return "clinical";
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
  const navigate = useNavigate();
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
          <Ages row={row} />
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
              {conditions.conditions
                .filter((c) => ownerOf(c.assignee) === "billing")
                .map((c) => {
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

          {/* Everyone else's blockers, read-only. Kim needs to SEE them
              — they are why the case is stuck — but resolving a
              narrative she did not write is not hers to do. */}
          {conditions &&
            conditions.conditions.some(
              (c) => ownerOf(c.assignee) !== "billing",
            ) && (
              <>
                <p className="mb-1.5 mt-3 text-[10px] font-bold uppercase tracking-[0.12em] text-gray-400">
                  Not yours
                </p>
                <ul className="space-y-1">
                  {conditions.conditions
                    .filter((c) => ownerOf(c.assignee) !== "billing")
                    .map((c) => (
                      <li
                        key={c.signal_code}
                        className="flex flex-wrap items-baseline gap-1.5 text-[11.5px] text-gray-500"
                      >
                        <span aria-hidden="true">ℹ</span>
                        <span className="capitalize">
                          {(c.assignee ?? "clinical").replace(/_/g, " ")}:
                        </span>
                        <span className="font-mono text-[10.5px]">
                          {c.signal_code}
                        </span>
                        {c.sla_hours != null && <span>({c.sla_hours}h)</span>}
                      </li>
                    ))}
                </ul>
              </>
            )}

          <div className="mt-3 flex flex-wrap gap-2">
            <button
              type="button"
              onClick={() =>
                navigate(demoLink(`/workbench/${row.id}`), {
                  state: {
                    from: "/revenue-ops",
                    fromLabel: "Revenue ops",
                    createdAt: row.created_at,
                  },
                })
              }
              className="rounded-lg border border-gray-300 bg-white px-2.5 py-1 text-[12px] font-medium text-gray-700 hover:bg-gray-50"
            >
              View full pre-D →
            </button>
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
  const navigate = useNavigate();
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
      // POST /decisions/:id/submit now, not the feedback workaround.
      // Feedback was the only write that existed when this button was
      // built; it recorded "a human accepted a signal", which is not
      // the same fact as "this went to Delta Dental on Tuesday". The
      // real event lands in submission_events and SURVIVES A REFRESH.
      if (!isDemo) {
        await api.post(`/decisions/${row.id}/submit`, {
          pred_request_id: row.id,
          patient_name: row.patient,
          payer_id: row.payer_id,
          payer_name: row.payer,
          submission_method: "manual",
          notes: `Submitted from the revenue ops queue by ${
            SUBMITTER[role ?? "revenue_ops"] ?? "billing"
          }`,
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
        <Ages row={row} />
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
        <button
          type="button"
          onClick={() =>
            navigate(demoLink(`/workbench/${row.id}`), {
              state: {
                from: "/revenue-ops",
                fromLabel: "Revenue ops",
                createdAt: row.created_at,
              },
            })
          }
          className="rounded-lg border border-gray-300 px-2.5 py-1 text-[12px] font-medium text-gray-700 hover:bg-gray-50"
        >
          View
        </button>
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
  const qc = useQueryClient();
  // Optimistic only: the row that was just pressed, so the card moves
  // before the refetch lands. The TRUTH is submission_events.
  const [justSent, setJustSent] = useState<Record<string, string>>({});
  const { data: sentToday } = useSubmittedOn(date);
  const submissions: SubmissionRow[] = Array.isArray(sentToday)
    ? sentToday
    : [];
  const sentIds = new Set(submissions.map((s) => s.pred_request_id));

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
  const isSent = (id: string) => sentIds.has(id) || Boolean(justSent[id]);
  const blocked = rows.filter((r) => !r.submission_ready && !isSent(r.id));
  const ready = rows.filter((r) => r.submission_ready && !isSent(r.id));

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
                onSubmitted={(id, at) => {
                  setJustSent((p) => ({ ...p, [id]: at }));
                  // Pull the real row in behind the optimistic one.
                  void qc.invalidateQueries({ queryKey: ["submissions"] });
                }}
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

      {submissions.length > 0 && (
        <section className="overflow-hidden rounded-xl border border-blue-200 bg-white">
          <header className="flex items-center justify-between gap-3 border-b border-blue-200 bg-blue-50 px-4 py-3">
            <h2 className="text-[13.5px] font-semibold text-blue-900">
              Submitted today ({submissions.length})
            </h2>
            <span className="text-[11px] text-blue-700">
              live · submission_events
            </span>
          </header>
          <ul className="divide-y divide-gray-100">
            {submissions.map((s) => (
              <li
                key={s.submission_id}
                className="flex flex-wrap items-center justify-between gap-3 px-4 py-3"
              >
                <div className="min-w-0">
                  <p className="text-[13.5px] font-medium text-gray-900">
                    📤 {s.patient_name}{" "}
                    <span className="font-normal text-gray-500">
                      — {scenarioId(s.pred_request_id)}
                    </span>
                  </p>
                  <p className="mt-0.5 text-[11.5px] text-gray-500">
                    Submitted to {s.payer_name} · expected response:{" "}
                    {s.expected_response_days} business days
                  </p>
                </div>
                <div className="flex flex-shrink-0 items-center gap-2">
                  <span className="text-[12px] font-medium text-blue-700">
                    {new Date(s.submitted_at).toLocaleTimeString([], {
                      hour: "numeric",
                      minute: "2-digit",
                    })}
                  </span>
                  <Link
                    to={demoLink(`/workbench/${s.pred_request_id}`)}
                    className="rounded-lg border border-gray-300 px-2.5 py-1 text-[12px] font-medium text-gray-700 hover:bg-gray-50"
                  >
                    View
                  </Link>
                </div>
              </li>
            ))}
          </ul>
          <p className="border-t border-gray-100 px-4 py-2.5 text-[11px] text-gray-400">
            Recorded in submission_events and survives a refresh. Nothing was
            transmitted to the payer — X12 278 is not connected.
          </p>
        </section>
      )}
    </div>
  );
}
