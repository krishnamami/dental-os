import { useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { Link, useNavigate } from "react-router-dom";
import { ChevronDown } from "lucide-react";

import {
  api,
  useConditions,
  useCreateHandoff,
  useDecision,
  useSubmittedOn,
  type SubmissionRow,
} from "../hooks/useApi";
import { useAuth } from "../context/AuthContext";
import { useDemo, useDemoLink } from "../hooks/useDemo";
import ActionError from "./ActionError";
import ReadinessBadge from "./ReadinessBadge";
import { dayParams } from "../hooks/useDatePicker";
import { scenarioId } from "../utils/format";
import { humanCode } from "../utils/predDerive";
import {
  HANDOFF_TO,
  NOTIFY,
  daysSince,
  deadlineFrom,
  queueTone,
} from "./BillingDetail";
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
  /** The ENGINE's verdict: every open condition cleared. It says
   *  nothing about whether a human signed. */
  submission_ready: boolean;
  /** Whether a clinician has attested. Absent on a stale cached
   *  payload, which must read as "not signed" rather than as ready. */
  attested?: boolean;
  attested_at?: string | null;
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

/**
 * Ready means the engine cleared it AND a clinician signed it.
 *
 * Exported because the stat cards on the Revenue Ops page count the
 * same rows from their own copy of the array — two filters that drifted
 * apart would show "3 ready" above a list containing one.
 *
 * The attestation half is deliberately NOT folded into the API's
 * `submission_ready`: the dentist's queue and the needs_clinician
 * filter both read that field and neither of them means "signed".
 */
export function isReadyToSubmit(r: {
  submission_ready: boolean;
  attested?: boolean;
}): boolean {
  return r.submission_ready && r.attested === true;
}

/** Engine-clear but unsigned — the case that USED to sit in Ready and
 *  now sits in Blocked. It keeps its submit button, because the point
 *  is to show Kim the gap, not to take the work away from her. */
function blockedOnAttestationOnly(r: QueueRow): boolean {
  return r.submission_ready && r.attested !== true;
}

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

/**
 * ⚠ "{n}h left" WAS A COUNTDOWN AGAINST NO CLOCK.
 *
 * conditions_library.sla_hours takes exactly three values across all
 * 50 rows — 24, 48, 72 — and codes missing from the library fall back
 * to a 48 constant in rule_loader. It is a triage bucket, not time
 * remaining: nothing records when the condition opened and nothing
 * decrements. It read as a deadline and it is a priority.
 *
 * The overdue branch was unreachable for the same reason — hours is
 * never <= 0 — so it is gone rather than left as decoration.
 */
function Sla({ hours }: { hours?: number | null }) {
  if (hours == null) return null;
  return (
    <span
      title="Triage priority from the conditions library, not a countdown — nothing records when this opened."
      className="rounded-full border border-amber-200 bg-accord-amber-50 px-1.5 py-0.5 text-[10.5px] font-semibold text-accord-amber-900"
    >
      {hours}h target
    </span>
  );
}

function BlockedRow({
  row,
  onSubmitted,
  onToast,
}: {
  row: QueueRow;
  onSubmitted: (id: string, at: string) => void;
  onToast: (m: string) => void;
}) {
  const [open, setOpen] = useState(false);
  const [done, setDone] = useState<Set<string>>(new Set());
  const [busy, setBusy] = useState(false);
  // Persistent. The submit path already ordered its state correctly —
  // onSubmitted only runs after the await — but the ONLY report of a
  // failure was a toast that timed out.
  const [error, setError] = useState<string | null>(null);
  const [notifyErrors, setNotifyErrors] = useState<Record<string, string>>({});
  const demoLink = useDemoLink();
  const navigate = useNavigate();
  const { isDemo } = useDemo();
  const { role } = useAuth();
  const handoff = useCreateHandoff();
  const { data: decision } = useDecision(row.id);
  const { data: conditions, isLoading } = useConditions(
    open ? row.id : undefined,
  );

  /**
   * Submit a case the engine cleared but no clinician signed.
   *
   * The override is LOGGED FIRST and the submission only goes if that
   * write succeeded. The other order would leave the pre-D at the payer
   * with nothing on record saying who decided to send it unsigned,
   * which is the one fact this whole screen exists to preserve.
   */
  async function submitAnyway() {
    setBusy(true);
    const at = new Date().toLocaleTimeString([], {
      hour: "numeric",
      minute: "2-digit",
    });
    try {
      if (!isDemo) {
        await api.post(`/decisions/${row.id}/feedback`, {
          // Matches the decision_id dental-os stamps on the synthetic
          // condition. There is no engine decision behind attestation,
          // so it is namespaced rather than borrowed from a real one.
          decision_id: `attestation:${row.id}`,
          signal_code: "CLINICAL_ATTESTATION_MISSING",
          feedback_type: "overridden",
          notes: "Submitted from the revenue ops queue without a clinician attestation",
          submitted_by: SUBMITTER[role ?? "revenue_ops"] ?? "billing",
        });
        await api.post(`/decisions/${row.id}/submit`, {
          pred_request_id: row.id,
          patient_name: row.patient,
          payer_id: row.payer_id,
          payer_name: row.payer,
          submission_method: "manual",
          notes: "Submitted unattested from the revenue ops queue",
        });
      }
      onSubmitted(row.id, at);
      setError(null);
      onToast(`${scenarioId(row.id)} submitted unattested — override logged`);
    } catch {
      // The card stays where it is. Two writes happen here and the
      // override is first, so a failure may mean the override landed
      // and the submission did not — say so rather than implying
      // nothing happened.
      setError(
        "Not submitted. If the override was recorded it will show in the " +
          "feedback log; the pre-D was not sent.",
      );
    } finally {
      setBusy(false);
    }
  }

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
          {/* Both numbers now count what GET /conditions returns, so
              the card and the list behind it agree. "open" is every
              actionable condition; "need a signature" is the subset a
              human must sign off. */}
          <span className="mt-0.5 block text-[11.5px] text-gray-500">
            {row.payer} · {scenarioId(row.id)} · {row.open} condition
            {row.open === 1 ? "" : "s"} open · {row.blocking} need a signature
          </span>
          <Ages row={row} />
        </span>
        <span className="flex flex-shrink-0 items-center gap-2">
          {decision && (
            <span
              className="flex items-center gap-1"
              title="Evidence on file, from the engine's readiness checks. Separate from the conditions below, which are sign-offs."
            >
              <span className="text-[10px] uppercase tracking-wide text-gray-400">
                evidence
              </span>
              <ReadinessBadge
                score={decision.readiness_met ?? 0}
                total={decision.readiness_total ?? 14}
              />
            </span>
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
                      <span className="text-[11.5px] font-semibold text-gray-700">
                        {humanCode(c.signal_code)}
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
                {/* Read-only, but no longer a bare one-line list. These
                    carry the same finding text and the same Notify
                    button as the billing conditions above, because
                    "Awaiting clinician attestation" is useless to Kim
                    as a signal code with no way to chase it. */}
                <ul className="space-y-2">
                  {conditions.conditions
                    .filter((c) => ownerOf(c.assignee) !== "billing")
                    .map((c) => {
                      const owner = ownerOf(c.assignee);
                      const told = done.has(c.signal_code);
                      return (
                        <li
                          key={c.signal_code}
                          className="rounded-lg border border-gray-200 bg-white px-3 py-2"
                        >
                          <div className="flex flex-wrap items-center gap-1.5">
                            <span aria-hidden="true">ℹ</span>
                            <span className="text-[11.5px] font-semibold text-gray-700">
                              {humanCode(c.signal_code)}
                            </span>
                            <Sla hours={c.sla_hours} />
                            <span className="text-[11px] capitalize text-gray-500">
                              {(c.assignee ?? "clinical").replace(/_/g, " ")}
                            </span>
                          </div>
                          <p className="mt-1 text-[12px] leading-relaxed text-gray-600">
                            {c.finding}
                          </p>
                          <button
                            type="button"
                            disabled={told}
                            onClick={() => {
                              // A real handoff, addressed to whoever
                              // owns the condition. The note carries
                              // the finding itself: a signal code with
                              // no context is not a request anyone can
                              // act on.
                              handoff.mutate(
                                {
                                  predRequestId: row.id,
                                  to_role: HANDOFF_TO[owner],
                                  note: `${row.patient}: ${c.finding}`,
                                },
                                {
                                  onSuccess: () => {
                                    setDone((prev) =>
                                      new Set(prev).add(c.signal_code),
                                    );
                                    setNotifyErrors((p) => {
                                      const next = { ...p };
                                      delete next[c.signal_code];
                                      return next;
                                    });
                                    onToast(`${NOTIFY[owner]} ✓`);
                                  },
                                  onError: () =>
                                    setNotifyErrors((p) => ({
                                      ...p,
                                      [c.signal_code]:
                                        "Note not sent — nobody has been told.",
                                    })),
                                },
                              );
                            }}
                            className="mt-1.5 rounded-lg border border-gray-300 bg-white px-2.5 py-1 text-[11.5px] font-medium text-gray-700 transition hover:bg-gray-50 disabled:opacity-50"
                          >
                            {told ? "Notified ✓" : NOTIFY[owner]}
                          </button>
                          <ActionError
                            message={notifyErrors[c.signal_code] ?? null}
                          />
                        </li>
                      );
                    })}
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
            {/* Only where the attestation is the ONLY thing missing.
                A case with open engine conditions never had a submit
                button here and does not gain one. */}
            {blockedOnAttestationOnly(row) && (
              <button
                type="button"
                disabled={busy}
                onClick={() => void submitAnyway()}
                className="rounded-lg border border-accord-amber-300 bg-accord-amber-50 px-2.5 py-1 text-[12px] font-semibold text-accord-amber-900 transition hover:bg-accord-amber-100 disabled:opacity-60"
              >
                {busy ? "Submitting…" : "Submit anyway ⚠"}
              </button>
            )}
          </div>

          <ActionError
            message={error}
            retrying={busy}
            onRetry={() => void submitAnyway()}
            onDismiss={() => setError(null)}
          />

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
  // THE ORIGINAL FALSE PASS. The card moving to "Submitted today" was
  // never the bug — onSubmitted already ran after the await. The bug
  // was that the only sign of a 422 was a toast that had vanished by
  // the time anyone looked, leaving a queue that appeared to have been
  // worked. This stays on the row until it succeeds or is dismissed.
  const [error, setError] = useState<string | null>(null);

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
      setError(null);
      onToast(`${scenarioId(row.id)} submitted to ${row.payer} ✓`);
    } catch {
      setError(
        `Not submitted to ${row.payer}. The pre-D is still in this queue.`,
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <li className="px-4 py-3">
      <div className="flex flex-wrap items-center justify-between gap-3">
      <div className="min-w-0">
        <p className="text-[13.5px] font-medium text-gray-900">{row.patient}</p>
        <p className="mt-0.5 text-[11.5px] text-gray-500">
          {row.finding} · {scenarioId(row.id)}
        </p>
        <Ages row={row} />
      </div>
      <div className="flex flex-shrink-0 items-center gap-2">
        {/* The badge here read a hardcoded 14 with no query behind it —
            it said "14/14" whatever the engine thought. A row only
            reaches this section when the engine cleared it AND a
            clinician signed, so the honest thing is to say that
            rather than to print a score nobody computed. */}
        <span className="rounded-full border border-accord-green-200 bg-accord-green-50 px-2 py-0.5 text-[10.5px] font-semibold text-accord-green-800">
          cleared · signed
        </span>
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
      </div>

      <ActionError
        message={error}
        retrying={busy}
        onRetry={() => void submit()}
        onDismiss={() => setError(null)}
      />
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
      (await api.get<QueueRow[]>(`/decisions/queue?${dayParams(date)}`))
        .data,
    staleTime: 60_000,
  });
  const rows: QueueRow[] = Array.isArray(data) ? data : [];
  const isSent = (id: string) => sentIds.has(id) || Boolean(justSent[id]);
  const blocked = rows.filter((r) => !isReadyToSubmit(r) && !isSent(r.id));
  const ready = rows.filter((r) => isReadyToSubmit(r) && !isSent(r.id));

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
              <BlockedRow
                key={r.id}
                row={r}
                onSubmitted={(id, at) => {
                  setJustSent((p) => ({ ...p, [id]: at }));
                  void qc.invalidateQueries({ queryKey: ["submissions"] });
                }}
                onToast={onToast}
              />
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
