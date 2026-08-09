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

import { DatePickerDropdown } from "../../../components/DatePickerDropdown";
import Toast, { useToast } from "../../../components/Toast";
import { useAuth } from "../../../context/AuthContext";
import { useDatePicker } from "../../../hooks/useDatePicker";
import { useDemo } from "../../../hooks/useDemo";
import {
  api,
  useClinical,
  useClinicalQueue,
  useSubmittedOn,
  type ClinicalBucket,
  type ClinicalSignal,
  type ClinicalView,
  type QueueRowLite,
  type SubmissionRow,
} from "../../../hooks/useApi";
import { formatCurrency, scenarioId } from "../../../utils/format";

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

function humanCode(code: string): string {
  return code
    .toLowerCase()
    .replace(/_/g, " ")
    .replace(/^\w/, (c) => c.toUpperCase());
}

function SignalRow({
  signal,
  tone,
  requested,
  onRequest,
  onJustify,
  busy,
}: {
  signal: ClinicalSignal;
  tone: Tone;
  requested: boolean;
  onRequest: () => void;
  onJustify: (text: string) => Promise<void>;
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
                void onJustify(text.trim()).then(() => setEditing(false));
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
    </li>
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

  const { data: sentData } = useSubmittedOn(selectedDate);
  const submissions: SubmissionRow[] = Array.isArray(sentData) ? sentData : [];
  const sentIds = new Set(submissions.map((s) => s.pred_request_id));

  const open = queue.filter((r) => !sentIds.has(r.id));
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
  const narrativeRef = useRef<HTMLTextAreaElement>(null);

  // Reset per case. Carrying one patient's narrative onto the next
  // card is the worst bug this screen could have.
  useEffect(() => {
    setNarrative(view?.narrative.saved ?? view?.narrative.draft ?? "");
    setAttested(false);
    setRequested(new Set());
  }, [view?.pred_request_id, view?.narrative.saved, view?.narrative.draft]);

  const blockers = useMemo(() => clinicianActionable(view), [view]);
  const selectedRow = open.find((r) => r.id === selectedId);
  // "Dr. Sridhar Chinta" -> "Dr. Chinta", matching the engine view's
  // greeting. Surname only: a dentist is addressed by it.
  const greeting = (() => {
    const bare = (effectiveUser?.name ?? "").replace(/^(Dr|Mr|Mrs|Ms)\.?\s+/i, "");
    const surname = bare.split(/\s+/).filter(Boolean).slice(-1)[0];
    return surname ? `Good morning, Dr. ${surname}` : "Good morning";
  })();

  async function saveNarrative() {
    if (!selectedId || !view) return;
    const text = narrative.trim();
    if (!text || text === (view.narrative.saved ?? "")) return;
    if (isDemo) {
      flash("Sign in to save a narrative — demo mode cannot write");
      return;
    }
    try {
      await api.post(`/decisions/${selectedId}/narrative`, {
        narrative_text: text,
        source: text === view.narrative.draft ? "draft" : "edited",
      });
      await qc.invalidateQueries({ queryKey: ["clinical", selectedId] });
      flash("Narrative saved ✓");
    } catch {
      flash("Could not save the narrative");
    }
  }

  async function justify(signalCode: string, text: string) {
    if (!selectedId) return;
    if (isDemo) {
      flash("Sign in to record a justification");
      return;
    }
    setBusy(signalCode);
    try {
      await api.post(`/decisions/${selectedId}/justification`, {
        signal_code: signalCode,
        justification: text,
      });
      await qc.invalidateQueries({ queryKey: ["clinical", selectedId] });
      await qc.invalidateQueries({ queryKey: ["clinical-queue"] });
      flash("Justification recorded ✓");
    } catch {
      flash("Could not record the justification");
    } finally {
      setBusy(null);
    }
  }

  async function submit() {
    if (!selectedId || !selectedRow || !attested) return;
    if (isDemo) {
      flash("Sign in to submit — demo mode cannot write");
      return;
    }
    setBusy("submit");
    try {
      await api.post(`/decisions/${selectedId}/submit`, {
        pred_request_id: selectedId,
        patient_name: selectedRow.patient,
        payer_id: selectedRow.payer_id,
        payer_name: selectedRow.payer,
        submission_method: "manual",
        narrative_text: narrative.trim() || null,
        attested: true,
      });
      await qc.invalidateQueries({ queryKey: ["submissions"] });
      await qc.invalidateQueries({ queryKey: ["clinical-queue"] });
      await qc.invalidateQueries({ queryKey: ["clinical", selectedId] });
      setClickedId(null);
      flash(`${scenarioId(selectedId)} submitted and attested ✓`);
    } catch {
      flash("Could not submit — the attestation was not recorded");
    } finally {
      setBusy(null);
    }
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
          <p className="mt-0.5 text-[13px] text-slate-500">
            {open.length === 0
              ? "Nothing needs you this morning"
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
                </p>
                <p className="mt-1 text-[12.5px] text-amber-900">
                  {selectedRow.handoff.message}
                </p>
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
          </section>

          {/* ── Attest and submit ───────────────────────────────── */}
          <section className="mt-4 rounded-xl border border-gray-200 bg-white p-5">
            {blockers.length > 0 && (
              <p className="mb-3 rounded-lg border-l-4 border-l-amber-400 bg-amber-50 px-3 py-2.5 text-[12.5px] text-amber-900">
                ⚠ {blockers.length} item
                {blockers.length === 1 ? "" : "s"} still need you:{" "}
                {blockers.map((s) => humanCode(s.signal_code)).join(", ")}. You
                can still attest and submit — you are stating the record
                supports the treatment, not that the engine agrees.
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
              disabled={!attested || busy === "submit"}
              onClick={() => void submit()}
              title={
                attested
                  ? undefined
                  : "Tick the attestation before submitting"
              }
              className={`${TAP} mt-3 cursor-pointer rounded-lg border-none px-4 py-2 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-50 max-[899px]:w-full`}
              style={{ backgroundColor: GREEN }}
            >
              {busy === "submit" ? "Submitting…" : "Attest and submit pre-D"}
            </button>
            <p className="mt-2 text-[11px] text-slate-400">
              Nothing is transmitted to the payer — X12 278 is not connected.
              The submission and your attestation are recorded.
            </p>
          </section>
        </>
      )}

      {/* ── Submitted today ─────────────────────────────────────── */}
      {submissions.length > 0 && (
        <section className="mt-6">
          <h3 className="mb-2 text-[11px] font-bold uppercase tracking-[0.12em] text-slate-500">
            Submitted today ({submissions.length})
          </h3>
          {submissions.map((s) => (
            <div
              key={s.submission_id}
              className="mb-2 flex flex-wrap items-center gap-2.5 rounded-xl border border-green-300 bg-green-50 px-4 py-3"
            >
              <span className="text-[16px]" aria-hidden="true">
                ✅
              </span>
              <div className="min-w-0 flex-1 text-[13px] font-medium text-green-700">
                {s.patient_name} — {scenarioId(s.pred_request_id)}
              </div>
              <div className="text-[11px] text-slate-500">
                {s.payer_name} ·{" "}
                {new Date(s.submitted_at).toLocaleTimeString([], {
                  hour: "numeric",
                  minute: "2-digit",
                })}
              </div>
            </div>
          ))}
        </section>
      )}

      <Toast message={toast} />
    </div>
  );
}
