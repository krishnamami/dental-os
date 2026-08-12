/**
 * D-11 — the workbench as a dentist sees it.
 *
 * ⚠ THE MOCK IT WAS MEANT TO FOLLOW IS NOT IN ANY REPO.
 * DentistWorkbench.jsx has been referenced by three prompts and exists
 * nowhere in accorddental, dental-os or dental-simulator. So the
 * section ORDER, the COPY, the empty states and the blockers warning
 * below are mine, not the mock's — the instruction was to keep them
 * verbatim and there was nothing to keep them from. What IS from the
 * brief and is followed exactly:
 *
 *   amber  = clinician-actionable
 *   slate  = informational
 *   green  = supported
 *
 *   no tabs, no wave bars, no 13/14 counter, no audit view
 *
 * Paste the mock and these strings can be reconciled in one pass; the
 * wiring underneath will not need to change.
 *
 * ── What it reads ────────────────────────────────────────────────────
 *
 *   GET  /decisions/queue?needs_clinician=true   the morning, filtered
 *   GET  /decisions/:id/clinical                 buckets + draft
 *   GET  /decisions/submitted?date=              survives a refresh
 *   POST /decisions/:id/narrative                on blur
 *   POST /decisions/:id/justification            inline editor
 *   POST /decisions/:id/submit                   attested only
 *
 * "Request now" is deliberately local this sprint — it flips a pill and
 * calls nothing, per the brief. POST /document-requests exists and is
 * tested; it is simply not wired here yet.
 */
import { useEffect, useMemo, useRef, useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { ChevronDown } from "lucide-react";

import { DatePickerDropdown } from "../../../components/DatePickerDropdown";
import ActionError from "../../../components/ActionError";
import Toast, { useToast } from "../../../components/Toast";
import { useAuth } from "../../../context/AuthContext";
import { useDatePicker } from "../../../hooks/useDatePicker";
import { useDemo } from "../../../hooks/useDemo";
import {
  api,
  useClinical,
  useAttest,
  useClinicalQueue,
  useDayQueue,
  useMarkHandoffRead,
  useSignedOn,
  useSubmittedOn,
  type ClinicalBucket,
  type ClinicalSignal,
  type ClinicalView,
  type QueueRowLite,
  type SignedRow,
  type SubmissionRow,
} from "../../../hooks/useApi";
import {
  formatCurrency,
  greetingFor,
  scenarioId,
} from "../../../utils/format";
// One label map, shared. The private copy here rendered "Fraud
// upcoding" while the rest of the app was being taught not to.
import { humanCode } from "../../../utils/predDerive";

const GREEN = "#0F4D37";

/**
 * Below this, the queue and the case are two screens rather than one
 * scroll. 900 is the number from the brief, not a Tailwind breakpoint
 * — an iPad in portrait is 768 and lg: would fire at 1024, which is
 * the same device in landscape.
 */
const NARROW_MAX = 899;

/** Tap target floor. 44px is Apple's minimum and the reason the queue
 *  rows and every control below are sized the way they are. */
const TAP = "min-h-[44px]";

function useIsNarrow(): boolean {
  const [narrow, setNarrow] = useState(
    () =>
      typeof window !== "undefined" &&
      window.matchMedia(`(max-width: ${NARROW_MAX}px)`).matches,
  );
  useEffect(() => {
    if (typeof window === "undefined") return;
    const mq = window.matchMedia(`(max-width: ${NARROW_MAX}px)`);
    const onChange = (e: MediaQueryListEvent) => setNarrow(e.matches);
    // matchMedia rather than a resize listener: it fires once on the
    // crossing instead of on every pixel of a drag, and it is what
    // rotating an iPad actually triggers.
    mq.addEventListener("change", onChange);
    setNarrow(mq.matches);
    return () => mq.removeEventListener("change", onChange);
  }, []);
  return narrow;
}

/** amber = clinician-actionable · slate = informational · green =
 *  supported. The three tones the brief named, defined once. */
const TONE = {
  action: {
    bar: "#d97706",
    bg: "#fffbeb",
    border: "border-amber-200",
    text: "text-amber-900",
  },
  info: {
    bar: "#94a3b8",
    bg: "#f8fafc",
    border: "border-slate-200",
    text: "text-slate-700",
  },
  supported: {
    bar: GREEN,
    bg: "#f0fdf4",
    border: "border-green-200",
    text: "text-green-800",
  },
} as const;

type Tone = keyof typeof TONE;

/**
 * Which tone a signal gets.
 *
 * Satisfied is green. Otherwise the split is OWNERSHIP, not severity:
 * a dentist can act on their own bucket, and a payer-friction item is
 * information they need but cannot personally clear. Colouring
 * somebody else's blocker amber makes the whole screen amber and the
 * dentist stops reading it.
 */
function toneOf(s: ClinicalSignal, bucketKey: ClinicalBucket["key"]): Tone {
  if (s.satisfied) return "supported";
  if (bucketKey === "clinical_support" || bucketKey === "documentation_gaps") {
    return "action";
  }
  return "info";
}

/** Signals a dentist can personally close. Drives the blockers count. */
function clinicianActionable(view: ClinicalView | undefined): ClinicalSignal[] {
  if (!view) return [];
  return view.buckets
    .filter(
      (b) => b.key === "clinical_support" || b.key === "documentation_gaps",
    )
    .flatMap((b) => b.signals)
    .filter((s) => !s.satisfied && !s.justification);
}



function SignalRow({
  signal,
  tone,
  requested,
  onRequest,
  onJustify,
  error,
  busy,
}: {
  signal: ClinicalSignal;
  tone: Tone;
  requested: boolean;
  onRequest: () => void;
  /** Resolves true only when the justification really reached the API. */
  onJustify: (text: string) => Promise<boolean>;
  error?: string;
  busy: boolean;
}) {
  const [editing, setEditing] = useState(false);
  const [text, setText] = useState(signal.justification ?? "");
  const t = TONE[tone];

  return (
    <li
      className="mb-2 rounded-lg px-3.5 py-3"
      style={{ background: t.bg, borderLeft: `3px solid ${t.bar}` }}
    >
      <div className="flex flex-wrap items-center gap-2">
        <span aria-hidden="true">
          {signal.satisfied ? "✅" : tone === "action" ? "⚠" : "ℹ"}
        </span>
        <span className={`min-w-0 break-words text-[12.5px] font-semibold ${t.text}`}>
          {humanCode(signal.signal_code)}
        </span>
        {signal.sla_hours != null && !signal.satisfied && (
          <span className="rounded-full border border-amber-200 bg-white px-1.5 py-0.5 text-[10.5px] font-semibold text-amber-900">
            {signal.sla_hours <= 0
              ? `${Math.abs(signal.sla_hours)}h overdue`
              : `${signal.sla_hours}h`}
          </span>
        )}
        {signal.justification && (
          <span className="rounded-full bg-green-100 px-2 py-0.5 text-[10.5px] font-semibold text-green-800">
            Justified
          </span>
        )}
      </div>

      {signal.finding && (
        <p className="mt-1 text-[12.5px] leading-relaxed text-slate-600">
          {signal.finding}
        </p>
      )}

      {(signal.citation || signal.payer_citation) && (
        <p className="mt-1 text-[11px] text-slate-400">
          {[signal.payer_citation, signal.citation && `§${signal.citation}`]
            .filter(Boolean)
            .join(" · ")}
        </p>
      )}

      {!signal.satisfied && (
        <div className="mt-2 flex flex-wrap items-center gap-2">
          {!editing && (
            <button
              type="button"
              onClick={() => setEditing(true)}
              className={`${TAP} cursor-pointer rounded-lg border border-slate-300 bg-white px-3 py-1 text-[11.5px] font-medium text-slate-700 transition hover:bg-slate-50`}
            >
              {signal.justification ? "Edit justification" : "Justify necessity"}
            </button>
          )}
          {tone === "action" && (
            <button
              type="button"
              disabled={requested}
              onClick={onRequest}
              className={`${TAP} cursor-pointer rounded-lg border border-slate-300 bg-white px-3 py-1 text-[11.5px] font-medium text-slate-700 transition hover:bg-slate-50 disabled:cursor-default disabled:opacity-60`}
            >
              {requested ? "Requested ✓" : "Request now"}
            </button>
          )}
        </div>
      )}

      {editing && (
        <div className="mt-2">
          <textarea
            autoFocus
            rows={3}
            value={text}
            onChange={(e) => setText(e.target.value)}
            placeholder="Why is this met despite the engine not confirming it?"
            /* 16px on narrow for the same reason as the narrative:
               under it Safari zooms, and a zoomed page scrolls
               sideways. */
            className="w-full rounded-lg border border-slate-300 px-2.5 py-2 text-[12.5px] leading-relaxed text-slate-900 focus:border-accord-green-500 focus:outline-none focus:ring-1 focus:ring-accord-green-500 max-[899px]:text-[16px]"
          />
          <div className="mt-1.5 flex flex-wrap gap-2">
            <button
              type="button"
              disabled={busy || !text.trim()}
              onClick={() => {
                // Close ONLY on a real save. This used to be an
                // unconditional .then(), so a failed request threw the
                // dentist's wording away and left the row looking as
                // though nothing had been attempted.
                void onJustify(text.trim()).then((ok) => {
                  if (ok) setEditing(false);
                });
              }}
              className={`${TAP} cursor-pointer rounded-lg px-3.5 py-1.5 text-[12px] font-semibold text-white disabled:opacity-60`}
              style={{ backgroundColor: GREEN }}
            >
              {busy ? "Saving…" : "Save justification"}
            </button>
            <button
              type="button"
              onClick={() => {
                setText(signal.justification ?? "");
                setEditing(false);
              }}
              className={`${TAP} cursor-pointer rounded-lg px-3.5 py-1.5 text-[12px] text-slate-500 hover:text-slate-800`}
            >
              Cancel
            </button>
          </div>
        </div>
      )}

      {!editing && signal.justification && (
        <p className="mt-1.5 rounded bg-white/70 px-2 py-1.5 text-[11.5px] italic text-slate-600">
          {signal.justification}
        </p>
      )}

      <ActionError message={error ?? null} />
    </li>
  );
}

/**
 * "Cleared by the engine — n cases", collapsed.
 *
 * Follows the mock: a full-width row that toggles, a chevron that
 * rotates, a plain list underneath. Deliberately quiet — this is
 * reassurance, not a work queue, and anything that looks like a case
 * card invites the dentist to review cases nobody asked him to.
 */
function ClearedBlock({
  cases,
  open,
  onToggle,
}: {
  cases: QueueRowLite[];
  open: boolean;
  onToggle: () => void;
}) {
  if (cases.length === 0) return null;
  return (
    <section className="mt-6">
      <button
        type="button"
        onClick={onToggle}
        aria-expanded={open}
        className={`${TAP} flex w-full items-center justify-between rounded-lg border border-gray-200 bg-white px-3 py-2.5 text-[13px] text-slate-500 transition hover:bg-slate-50`}
      >
        <span>
          Cleared by the engine — {cases.length} case
          {cases.length === 1 ? "" : "s"}
        </span>
        <ChevronDown
          size={16}
          className={`transition-transform ${open ? "rotate-180" : ""}`}
        />
      </button>
      {open && (
        <ul className="mt-2 space-y-1.5">
          {cases.map((c) => (
            <li
              key={c.id}
              className="rounded-lg border border-gray-200 bg-white px-3 py-2 text-[12px]"
            >
              <span className="font-semibold text-slate-700">{c.patient}</span>
              <span className="text-slate-500">
                {" "}
                — {c.finding || scenarioId(c.id)}
              </span>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

export default function WorkbenchClinicalView() {
  const { effectiveUser } = useAuth();
  const { isDemo } = useDemo();
  const { toast, flash } = useToast();
  const qc = useQueryClient();
  const { selectedDate, setSelectedDate, availableDates } = useDatePicker();

  const { data: queueData, isLoading: queueLoading } =
    useClinicalQueue(selectedDate);
  const queue: QueueRowLite[] = Array.isArray(queueData) ? queueData : [];

  // The whole day, so the header can say "4 of 15" and the block below
  // can list the eleven he never had to look at.
  const { data: allData } = useDayQueue(selectedDate);
  const allRows: QueueRowLite[] = Array.isArray(allData) ? allData : [];
  const { data: signedData } = useSignedOn(selectedDate);
  const signed: SignedRow[] = Array.isArray(signedData) ? signedData : [];
  const attest = useAttest();
  const [showCleared, setShowCleared] = useState(false);
  const { data: sentData } = useSubmittedOn(selectedDate);
  const submissions: SubmissionRow[] = Array.isArray(sentData) ? sentData : [];
  const sentIds = new Set(submissions.map((s) => s.pred_request_id));
  // Signed cases leave this queue whether or not Kim has filed them —
  // the dentist is done with them either way, and leaving a case he has
  // already put his name to on a screen headed "needs your review" is
  // how it gets signed twice.
  const signedIds = new Set(signed.map((s) => s.pred_request_id));

  const open = queue.filter((r) => !sentIds.has(r.id) && !signedIds.has(r.id));
  // Cleared = the engine finished with it and never needed him. Signed
  // and submitted cases are NOT cleared-by-the-engine — he did those,
  // and counting his own work as the engine's is the one thing this
  // block must not do.
  const clearedCases = allRows.filter(
    (r) => !r.needs_clinician && !signedIds.has(r.id) && !sentIds.has(r.id),
  );
  const totalToday = allRows.length;
  const [clickedId, setClickedId] = useState<string | null>(null);
  const selectedId =
    clickedId && open.some((r) => r.id === clickedId)
      ? clickedId
      : (open[0]?.id ?? null);

  const { data: view, isLoading: viewLoading } = useClinical(
    selectedId ?? undefined,
  );

  const isNarrow = useIsNarrow();
  // Narrow only. On desktop both panes are always on screen and this
  // is ignored, so the desktop layout cannot be affected by it.
  const [showDetail, setShowDetail] = useState(false);
  const [narrative, setNarrative] = useState("");
  const [attested, setAttested] = useState(false);
  const [requested, setRequested] = useState<Set<string>>(new Set());
  const [busy, setBusy] = useState<string | null>(null);
  // Persistent, per-card. Toasts time out; a failed write must not.
  const [narrativeError, setNarrativeError] = useState<string | null>(null);
  const [signError, setSignError] = useState<string | null>(null);
  const [signalErrors, setSignalErrors] = useState<Record<string, string>>({});
  const narrativeRef = useRef<HTMLTextAreaElement>(null);

  // Reset per case. Carrying one patient's narrative onto the next
  // card is the worst bug this screen could have.
  useEffect(() => {
    setNarrative(view?.narrative.saved ?? view?.narrative.draft ?? "");
    setAttested(false);
    setRequested(new Set());
    setNarrativeError(null);
    setSignError(null);
    setSignalErrors({});
  }, [view?.pred_request_id, view?.narrative.saved, view?.narrative.draft]);

  const blockers = useMemo(() => clinicianActionable(view), [view]);
  const selectedRow = open.find((r) => r.id === selectedId);
  const greeting = greetingFor(effectiveUser?.name);

  /**
   * ⚠ READ STATE IS SET BY A PERSON, NEVER BY A RENDER.
   *
   * This used to be a useEffect on selectedRow. The queue auto-selects
   * open[0] when nothing has been clicked, so the note attached to
   * whichever case sorts first was marked read the instant the
   * workbench painted — before the dentist had looked at anything.
   * needs_clinician stopped counting it, and a case that was in the
   * queue BECAUSE someone flagged it could drop out unseen.
   *
   * Same shape as the read_at filter bug before it: state that means
   * "a human dealt with this" being written by the machinery that
   * displays it. A render is not an act of reading.
   */
  const markRead = useMarkHandoffRead();


  /**
   * Autosave the narrative. Returns whether the text is safely on file.
   *
   * ⚠ THIS ONE BLOCKS SIGNING. The attestation COPIES whatever narrative
   * is on file at the instant it is written, and that copy is immutable
   * afterwards. A blur that failed silently meant the dentist signed the
   * PREVIOUS text — or no text — while the textarea in front of him
   * showed the words he thought he was attesting to. There is no way to
   * correct it after the fact, so a failed save has to stop the
   * signature rather than warn about it.
   *
   * True when there is nothing to save, too: unchanged text is already
   * on file, which is what the caller is asking about.
   */
  async function saveNarrative(): Promise<boolean> {
    if (!selectedId || !view) return true;
    const text = narrative.trim();
    if (!text || text === (view.narrative.saved ?? "")) return true;
    if (isDemo) {
      flash("Sign in to save a narrative — demo mode cannot write");
      return false;
    }
    try {
      await api.post(`/decisions/${selectedId}/narrative`, {
        narrative_text: text,
        source: text === view.narrative.draft ? "draft" : "edited",
      });
      await qc.invalidateQueries({ queryKey: ["clinical", selectedId] });
      setNarrativeError(null);
      flash("Narrative saved ✓");
      return true;
    } catch {
      setNarrativeError(
        "This narrative is NOT saved. Signing is blocked until it is — " +
          "the attestation copies whatever is on file, and that copy " +
          "cannot be changed afterwards.",
      );
      return false;
    }
  }

  /** Returns whether it saved. The editor closes only if it did —
   *  swallowing the error and closing anyway threw the dentist's
   *  wording away and left the row looking untouched. */
  async function justify(signalCode: string, text: string): Promise<boolean> {
    if (!selectedId) return false;
    if (isDemo) {
      flash("Sign in to record a justification");
      return false;
    }
    setBusy(signalCode);
    try {
      await api.post(`/decisions/${selectedId}/justification`, {
        signal_code: signalCode,
        justification: text,
      });
      await qc.invalidateQueries({ queryKey: ["clinical", selectedId] });
      await qc.invalidateQueries({ queryKey: ["clinical-queue"] });
      setSignalErrors((p) => {
        const next = { ...p };
        delete next[signalCode];
        return next;
      });
      flash("Justification recorded ✓");
      return true;
    } catch {
      setSignalErrors((p) => ({
        ...p,
        [signalCode]:
          "Not saved. Your wording is still in the box — press Save " +
          "justification again.",
      }));
      return false;
    } finally {
      setBusy(null);
    }
  }

  /**
   * Sign the pre-D. It does NOT go to the payer from here.
   *
   * ⚠ THIS USED TO POST /submit. Attesting and filing were one button,
   * which made the dentist the person who transmitted to Delta —
   * an administrative act he has no reason to own and no screen to
   * track. They are two acts by two people now: he signs from the
   * chair, Kim files from revenue operations once the packet is ready.
   *
   * /submit still accepts attested:true at the API level. This screen
   * simply stops being where that happens.
   */
  async function sign() {
    if (!selectedId || !selectedRow || !attested) return;
    if (isDemo) {
      flash("Sign in to sign — demo mode cannot write");
      return;
    }
    setBusy("sign");
    setSignError(null);
    // ⚠ FLUSH FIRST, AND ABORT IF IT FAILS. The attestation copies the
    // narrative on file at the moment it is written and the copy is
    // immutable. Signing after a failed save puts the dentist's name on
    // text he did not write, permanently — so a failed flush stops here
    // rather than warning and carrying on, which is what it used to do.
    const saved = await saveNarrative();
    if (!saved) {
      setBusy(null);
      return;
    }
    attest.mutate(selectedId, {
      onSuccess: () => {
        setClickedId(null);
        flash(`${scenarioId(selectedId)} signed — with Kim now ✓`);
        setBusy(null);
      },
      onError: () => {
        setSignError(
          "Not signed. Nothing was recorded — the case is still yours.",
        );
        setBusy(null);
      },
    });
  }

  // overflow-x-hidden below is the backstop, not the fix: every child
  // is already allowed to shrink (min-w-0) or wrap. It is there so one
  // long unbroken string in a finding cannot put the whole page into a
  // sideways scroll on a device with no scrollbar to show for it.
  return (
    <div className="relative mx-auto max-w-4xl overflow-x-hidden px-6 py-6 pb-16 max-[899px]:px-4">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 className="text-[22px] font-semibold text-gray-900">
            {greeting}
          </h1>
          {/* "4 of 15 cases today. The rest cleared without you." The
              second sentence is the point of the line: "4 cases need
              you" states the workload, this states that the engine did
              eleven of them on his behalf — which is the thing he is
              being asked to trust. */}
          <p className="mt-0.5 text-[13px] text-slate-500">
            {open.length === 0
              ? "Nothing needs you today. Everything else is with Kim."
              : totalToday > 0
                ? `${open.length} of ${totalToday} case${totalToday === 1 ? "" : "s"} today. The rest cleared without you.`
                : `${open.length} case${open.length === 1 ? "" : "s"} need you`}
            {effectiveUser?.tenant_name ? ` · ${effectiveUser.tenant_name}` : ""}
          </p>
        </div>
        <DatePickerDropdown
          selectedDate={selectedDate}
          availableDates={availableDates}
          onChange={setSelectedDate}
        />
      </div>

      {/* ── The morning ─────────────────────────────────────────── */}
      {queueLoading && (
        <div className="mt-6 animate-pulse space-y-2">
          {[0, 1].map((i) => (
            <div key={i} className="h-16 rounded-xl bg-gray-100" />
          ))}
        </div>
      )}

      {!queueLoading && open.length === 0 && (
        <p className="mt-6 rounded-xl border border-green-200 bg-green-50 px-5 py-6 text-[13.5px] text-green-800">
          Nothing is waiting on you. Every case on this day is either clear or
          waiting on somebody else.
        </p>
      )}

      {open.length > 0 && (!isNarrow || !showDetail) && (
        // Narrow: full-width rows, one per line, each a 44px target.
        // Wide: the chip row exactly as it was.
        <div className="mt-5 flex flex-wrap gap-2 max-[899px]:flex-col">
          {open.map((r) => {
            const on = r.id === selectedId;
            return (
              <button
                key={r.id}
                type="button"
                onClick={() => {
                  setClickedId(r.id);
                  setShowDetail(true);
                }}
                aria-pressed={on}
                className={`${TAP} cursor-pointer rounded-xl border px-3.5 py-2.5 text-left transition max-[899px]:w-full ${
                  on && !isNarrow
                    ? "border-2 border-accord-green-500 bg-accord-green-50"
                    : "border-gray-200 bg-white hover:bg-slate-50"
                }`}
              >
                <span className="block text-[13px] font-semibold text-slate-800">
                  {r.patient}
                </span>
                <span className="mt-0.5 flex items-center gap-1.5 text-[11px] text-amber-800">
                  <span className="min-w-0 flex-1 truncate">
                    {r.needs_reason ?? scenarioId(r.id)}
                  </span>
                  {isNarrow && (
                    <span aria-hidden="true" className="text-slate-400">
                      ›
                    </span>
                  )}
                </span>
              </button>
            );
          })}
        </div>
      )}

      {isNarrow && showDetail && (
        <button
          type="button"
          onClick={() => setShowDetail(false)}
          className={`${TAP} -ml-1 mt-4 flex items-center gap-1.5 px-1 text-[13px] font-medium text-slate-600`}
        >
          ← Back to queue
        </button>
      )}

      {(!isNarrow || showDetail) && viewLoading && selectedId && (
        <div className="mt-6 animate-pulse space-y-3">
          <div className="h-24 rounded-xl bg-gray-100" />
          <div className="h-40 rounded-xl bg-gray-100" />
        </div>
      )}

      {(!isNarrow || showDetail) && view && !viewLoading && (
        <>
          {/* ── The case ────────────────────────────────────────── */}
          <section className="mt-6 rounded-xl border border-gray-200 bg-white p-5">
            <div className="flex flex-wrap items-baseline gap-2">
              <h2 className="text-[17px] font-semibold text-gray-900">
                {view.patient_name}
              </h2>
              <span className="text-[12.5px] text-slate-500">
                {scenarioId(view.pred_request_id)}
              </span>
            </div>
            <ul className="mt-2.5 space-y-1">
              {view.procedures.map((p) => (
                <li key={p.line_no} className="text-[12.5px] text-slate-700">
                  <span className="font-mono font-semibold">{p.cdt_code}</span>{" "}
                  {p.description}
                  {p.tooth_number ? ` · tooth #${p.tooth_number}` : ""}
                  <span className="text-slate-400"> · {formatCurrency(p.fee)}</span>
                  {p.ada_citation && (
                    <span className="mt-0.5 block text-[11px] text-slate-400">
                      {p.ada_citation.split(";")[0]}
                    </span>
                  )}
                </li>
              ))}
            </ul>

            {selectedRow?.handoff && (
              <div className="mt-3 rounded-lg border border-amber-200 bg-amber-50 px-3 py-2.5">
                <p className="text-[11px] font-bold uppercase tracking-[0.1em] text-amber-900">
                  Handed to you
                  {selectedRow.handoff.read_at ? " · read" : ""}
                </p>
                <p className="mt-1 text-[12.5px] text-amber-900">
                  {selectedRow.handoff.message}
                </p>
                {!selectedRow.handoff.read_at && (
                  <button
                    type="button"
                    disabled={markRead.isPending}
                    onClick={() => markRead.mutate(selectedRow.id)}
                    className={`${TAP} mt-2 cursor-pointer rounded-lg border border-amber-300 bg-white px-3 py-1 text-[12px] font-medium text-amber-900 transition hover:bg-amber-100 disabled:opacity-60`}
                  >
                    {markRead.isPending ? "Marking…" : "Mark as read"}
                  </button>
                )}
              </div>
            )}
          </section>

          {/* ── The buckets ─────────────────────────────────────── */}
          {view.buckets
            .filter((b) => b.signals.length > 0)
            .map((b) => (
              <section key={b.key} className="mt-4">
                <div className="mb-2 flex flex-wrap items-baseline justify-between gap-2">
                  <h3 className="text-[11px] font-bold uppercase tracking-[0.12em] text-slate-500">
                    {b.label}
                  </h3>
                  <span className="text-[11px] text-slate-400">
                    {b.open === 0
                      ? "all supported"
                      : `${b.open} open of ${b.signals.length}`}
                  </span>
                </div>
                <ul>
                  {b.signals.map((s) => (
                    <SignalRow
                      key={s.signal_code}
                      signal={s}
                      tone={toneOf(s, b.key)}
                      requested={
                        requested.has(s.signal_code) || s.document_requested
                      }
                      busy={busy === s.signal_code}
                      onRequest={() => {
                        // Mock-only this sprint, per the brief: flip
                        // local state and call nothing. The endpoint
                        // exists; it is simply not wired here yet.
                        setRequested((p) => new Set(p).add(s.signal_code));
                        flash("Request noted — not sent this sprint");
                      }}
                      onJustify={(text) => justify(s.signal_code, text)}
                      error={signalErrors[s.signal_code]}
                    />
                  ))}
                </ul>
              </section>
            ))}

          {/* ── Narrative ───────────────────────────────────────── */}
          <section className="mt-5 rounded-xl border border-gray-200 bg-white p-5">
            <div className="flex flex-wrap items-baseline justify-between gap-2">
              <h3 className="text-[13px] font-semibold text-gray-900">
                Clinical narrative
              </h3>
              <span className="text-[11px] text-slate-400">
                {view.narrative.saved
                  ? "saved"
                  : view.narrative.draft
                    ? "drafted from the chart — edit before it goes out"
                    : "nothing to draft from"}
              </span>
            </div>

            {view.narrative.draft === null && view.narrative.no_draft_reason && (
              <p className="mt-2 text-[12px] text-slate-500">
                {view.narrative.no_draft_reason}.
              </p>
            )}

            {/* ⚠ iOS KEYBOARD. Safari does not resize the layout
                viewport when the keyboard opens — it scrolls the page
                and leaves the focused field wherever it lands, which
                for a textarea near the bottom of a long document is
                behind the keyboard. scrollIntoView on focus puts it at
                the top of what remains visible. The 16px font size is
                not cosmetic either: Safari zooms the whole page on
                focus for anything under 16px, and a zoomed page then
                scrolls sideways. */}
            <textarea
              ref={narrativeRef}
              rows={5}
              value={narrative}
              onChange={(e) => setNarrative(e.target.value)}
              onFocus={() => {
                window.setTimeout(() => {
                  // center, not start: the header is sticky at 52px,
                  // so scrolling the textarea to the top of the
                  // viewport puts its first line behind it. Centering
                  // in what the keyboard leaves visible clears both.
                  narrativeRef.current?.scrollIntoView({
                    block: "center",
                    behavior: "smooth",
                  });
                }, 250);
              }}
              onBlur={() => void saveNarrative()}
              placeholder="Describe the finding, the measurement and why the treatment is indicated."
              className="mt-2 w-full rounded-lg border border-slate-300 px-3 py-2.5 text-[13px] leading-relaxed text-slate-900 focus:border-accord-green-500 focus:outline-none focus:ring-1 focus:ring-accord-green-500 max-[899px]:text-[16px]"
            />
            <p className="mt-1 text-[11px] text-slate-400">
              Saves when you click away.
            </p>
            <ActionError
              message={narrativeError}
              retrying={busy === "narrative"}
              onRetry={() => {
                setBusy("narrative");
                void saveNarrative().finally(() => setBusy(null));
              }}
            />
          </section>

          {/* ── Sign ────────────────────────────────────────────── */}
          <section className="mt-4 rounded-xl border border-gray-200 bg-white p-5">
            {blockers.length > 0 && (
              <p className="mb-3 rounded-lg border-l-4 border-l-amber-400 bg-amber-50 px-3 py-2.5 text-[12.5px] text-amber-900">
                ⚠ {blockers.length} item
                {blockers.length === 1 ? "" : "s"} still need you:{" "}
                {blockers.map((s) => humanCode(s.signal_code)).join(", ")}. You
                can still sign — you are stating the record supports the
                treatment, not that the engine agrees.
              </p>
            )}

            {/* py-2.5 on the LABEL, not just the box: a 16px checkbox
                is an unusable target on glass, and the whole line is
                clickable anyway. */}
            <label
              className={`${TAP} flex cursor-pointer items-start gap-2.5 py-2.5`}
            >
              <input
                type="checkbox"
                checked={attested}
                onChange={(e) => setAttested(e.target.checked)}
                className="mt-0.5 h-5 w-5 flex-shrink-0 rounded border-gray-300 text-accord-green-900 focus:ring-accord-green-500"
              />
              <span className="text-[12.5px] leading-relaxed text-slate-700">
                I attest that the clinical record supports the procedures
                submitted and that the narrative accompanying this
                pre-determination is accurate to the best of my clinical
                judgement.
              </span>
            </label>

            {view.attestation && (
              <p className="mt-2 text-[11.5px] text-green-700">
                ✅ Attested{" "}
                {view.attestation.attested_at
                  ? new Date(view.attestation.attested_at).toLocaleString()
                  : ""}
              </p>
            )}

            <button
              type="button"
              disabled={!attested || busy === "sign" || Boolean(narrativeError)}
              onClick={() => void sign()}
              title={
                narrativeError
                  ? "Save the narrative before signing"
                  : attested
                    ? undefined
                    : "Tick the attestation before signing"
              }
              className={`${TAP} mt-3 cursor-pointer rounded-lg border-none px-4 py-2 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-50 max-[899px]:w-full`}
              style={{ backgroundColor: GREEN }}
            >
              {busy === "sign" ? "Signing…" : "Sign"}
            </button>
            {/* Where it goes next. A dentist who signs and then cannot
                find the case has to ask someone; this answers it before
                he has to. */}
            <p className="mt-2 text-[12px] text-slate-600">
              Kim submits from revenue operations.
            </p>
            <p className="mt-2 text-[11px] text-slate-400">
              Signing records your attestation against this pre-D. Nothing is
              transmitted to the payer from here.
            </p>
            <ActionError
              message={signError}
              retrying={busy === "sign"}
              onRetry={() => void sign()}
            />
          </section>
        </>
      )}

      {/* ── Signed today ────────────────────────────────────────
          SUBMITTED TODAY was the wrong list for this role the moment
          the dentist stopped being the one who submits. He needs to see
          what he signed; whether Kim has filed it yet is shown as a
          sub-line, not as the heading. */}
      {signed.length > 0 && (
        <section className="mt-6">
          <h3 className="mb-2 text-[11px] font-bold uppercase tracking-[0.12em] text-slate-500">
            Signed today ({signed.length})
          </h3>
          {signed.map((s) => (
            <div
              key={s.attestation_id}
              className="mb-2 flex flex-wrap items-center gap-2.5 rounded-xl border border-green-300 bg-green-50 px-4 py-3"
            >
              <span className="text-[16px]" aria-hidden="true">
                ✅
              </span>
              <div className="min-w-0 flex-1 text-[13px] font-medium text-green-700">
                {scenarioId(s.pred_request_id)}
                <span className="ml-1.5 font-normal text-green-800">
                  {s.submitted_at
                    ? "submitted by billing"
                    : "with Kim — not yet submitted"}
                </span>
              </div>
              <div className="text-[11px] text-slate-500">
                signed{" "}
                {new Date(s.attested_at).toLocaleTimeString([], {
                  hour: "numeric",
                  minute: "2-digit",
                })}
              </div>
            </div>
          ))}
        </section>
      )}

      {/* ── Cleared by the engine ───────────────────────────────── */}
      <ClearedBlock
        cases={clearedCases}
        open={showCleared}
        onToggle={() => setShowCleared((v) => !v)}
      />

      <Toast message={toast} />
    </div>
  );
}
