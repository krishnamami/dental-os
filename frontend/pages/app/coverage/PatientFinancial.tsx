import { useQueries, useQuery } from "@tanstack/react-query";
import { useMemo, useState } from "react";

import { DatePickerDropdown } from "../../../components/DatePickerDropdown";
import { dayParams, useDatePicker } from "../../../hooks/useDatePicker";
import { ROLE_LABELS, useAuth } from "../../../context/AuthContext";
import { api, keys, useCreateHandoff } from "../../../hooks/useApi";
import type { PatientSummary } from "../../../types/dental";
import { formatCurrency } from "../../../utils/format";
import ActionError from "../../../components/ActionError";
import { EmailModal, SmsModal } from "./SendModals";
import { talkingPoints } from "./talkingPoints";
import {
  COORDINATOR_ITEMS,
  generateEmailText,
  generatePrintHTML,
} from "./estimateDoc";

/**
 * G-01 — the money conversation, at /coverage.
 *
 * Jennifer sits with a patient after check-in and explains what the
 * plan pays and what they owe. Everything here is already computed by
 * dental-os; this page presents it and records that the conversation
 * happened.
 *
 * ── Every figure has one source ──────────────────────────────────────
 *
 * The table, the savings line, the benefit pills and the printed sheet
 * all read the SAME /patient-summary payload. Nothing is recomputed in
 * this file and no percentage is typed — the coverage share is derived
 * from the plan-pays and contracted amounts on the very rows shown
 * underneath it. A patient who adds up the column must get the total,
 * and a printed sheet must match the screen it was printed from.
 */

const GREEN = "#0F4D37";

interface Alert {
  type: string;
  title: string;
  detail: string;
}

interface CheckInPatient {
  /** From /checkin/today: a clinical_handoffs row of kind
   *  'consultation_complete' exists for this pre-D. Optional so a
   *  cached payload from before this field shipped reads as not-done
   *  rather than crashing. */
  consultation_complete?: boolean;
  consultation_completed_at?: string | null;
  pred_request_id: string;
  patient_name: string;
  appointment_time: string;
  procedure_summary: string;
  payer_name: string;
  member_id: string | null;
  enrollment_months: number | null;
  provider_name: string;
  provider_npi: string;
  insurance_active: boolean;
  provider_in_network: boolean;
  deductible_met: boolean;
  deductible_total: number | null;
  deductible_remaining: number | null;
  annual_max: number | null;
  annual_max_remaining: number | null;
  annual_max_remaining_after: number | null;
  patient_pays_today: number | null;
  alerts: Alert[];
  status: "heads_up" | "clear" | "checked_in";
  checked_in_at: string | null;
  /** From patients.email / patients.mobile_phone. Either can be null:
   *  a practice that never collected a mobile has none to text. */
  patient_email: string | null;
  patient_phone: string | null;
  /** Who is signed in, resolved server-side from the token's `sub` —
   *  the JWT itself carries neither a name nor an address. */
  sender_name: string;
  sender_email: string;
  practice_email: string;
  practice_phone: string;
}

/**
 * The text a patient gets. One GSM-7 segment if it fits.
 *
 * The cost comes from the same /patient-summary total as the table and
 * the printed sheet, so a patient cannot be told one figure by text
 * and another on paper.
 */
function smsFor(
  p: CheckInPatient,
  ps: PatientSummary | undefined,
  practice: string,
): string {
  const cost = ps ? formatCurrency(ps.summary.total_patient_pays) : null;
  const phone = p.practice_phone || "";
  return (
    `Hi ${firstNameOf(p.patient_name)}, your treatment estimate from ` +
    `${practice} is ready.` +
    (cost ? ` Your estimated cost: ${cost}.` : "") +
    (phone ? ` Questions? Call us at ${phone}.` : "")
  );
}

// One list, shared with the printed document. Two copies would let a
// coordinator tick six boxes on screen and print six different ones.
const CHECKLIST = COORDINATOR_ITEMS;

export type CardTab = "talking" | "treatment" | "checklist";

const TAB_ORDER: CardTab[] = ["talking", "treatment", "checklist"];

const TAB_LABEL: Record<CardTab, string> = {
  talking: "Talking points",
  treatment: "Treatment & cost",
  checklist: "Checklist",
};

/** The three weights a talking point carries. `ok` is the house green,
 *  `warn` the amber the rest of the app uses for a raised finding, and
 *  `info` blue for an offer rather than a fact. */
const TONE: Record<string, { bg: string; bar: string }> = {
  ok: { bg: "#f8fafc", bar: GREEN },
  warn: { bg: "#fffbeb", bar: "#d97706" },
  info: { bg: "#eff6ff", bar: "#3b82f6" },
};

type Bucket = "ready" | "waiting" | "done";

const BUCKET_LABEL: Record<Bucket, string> = {
  ready: "Ready for consultation",
  waiting: "Waiting to arrive",
  done: "✅ Consultation done today",
};

/**
 * Which conversation-checklist item a talking point closes.
 *
 * ⚠ KEYED ON THE POINT, NOT ITS POSITION. talkingPoints() returns
 * between four and eight points depending on what the engine raised —
 * Robert Thompson gets four, James Mitchell eight — so the brief's
 * index map (TP0→CL0 … TP6→CL3) lines up for exactly one patient and
 * silently mis-files the rest. On Robert's card, index 3 is Financing,
 * not Downgrade.
 *
 * The four conditional points map to nothing on purpose. A downgrade,
 * an exhausted annual maximum, a pre-determination and a bundling
 * caveat are warnings to raise, not items on the six-step consent
 * conversation. The brief pointed Downgrade at "Financing options
 * discussed", which would tick a consent step because a crown is
 * reimbursed at a cheaper rate — two unrelated things.
 */
const TP_TO_CHECKLIST: Record<string, number> = {
  plan: 0, // Treatment plan explained
  insurance: 1, // Insurance benefits explained
  cost: 2, // Estimated patient responsibility reviewed
  financing: 3, // Financing options discussed
};

function firstNameOf(full: string): string {
  return full.replace(/^(Dr|Mr|Mrs|Ms)\.?\s+/i, "").split(/\s+/)[0] ?? "";
}

/** Tile in the dark strip — same shape as the check-in screen's. */
function Tile({ ok, title, detail }: { ok: boolean; title: string; detail: string }) {
  return (
    <div
      className="flex gap-2 rounded-lg p-2.5"
      style={
        ok
          ? { background: "rgba(255,255,255,0.10)" }
          : {
              background: "rgba(255,200,0,0.15)",
              border: "1px solid rgba(255,200,0,0.3)",
            }
      }
    >
      <span className="flex-shrink-0 text-[12px]" aria-hidden="true">
        {ok ? "✅" : "⚠"}
      </span>
      <div className="min-w-0">
        <p
          className="text-[12px] font-medium"
          style={{ color: ok ? "#ffffff" : "#fcd34d" }}
        >
          {title}
        </p>
        <p
          className="mt-0.5 text-[11px] leading-snug"
          style={{ color: ok ? "rgba(255,255,255,0.65)" : "rgba(252,211,77,0.8)" }}
        >
          {detail}
        </p>
      </div>
    </div>
  );
}

function Pill({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-gray-200 bg-white px-3 py-2">
      <p className="text-[10px] uppercase tracking-wide text-slate-500">{label}</p>
      <p className="mt-0.5 text-[12.5px] font-semibold text-slate-800">{value}</p>
    </div>
  );
}

/** The coverage share, computed from the same rows the table shows. */
function sharePhrase(ps: PatientSummary): string {
  const parts = ps.procedures
    .filter((p) => p.contracted_rate > 0)
    .map(
      (p) =>
        `${p.cdt_code} ${Math.round((p.insurance_pays / p.contracted_rate) * 100)}%`,
    );
  return parts.join(" · ") || "—";
}

function StatCard({
  label,
  value,
  tone,
  active,
  onClick,
}: {
  label: string;
  value: number;
  tone: string;
  active: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-pressed={active}
      className={`cursor-pointer rounded-xl border p-5 text-left transition ${
        active
          ? "border-2 border-accord-green-500 bg-accord-green-50 ring-2 ring-accord-green-300"
          : "border-gray-200 bg-white hover:bg-slate-50"
      }`}
    >
      <p className="text-xs uppercase tracking-wide text-slate-500">{label}</p>
      <p className={`mt-1 text-3xl font-semibold ${tone}`}>{value}</p>
    </button>
  );
}

/**
 * Someone who has not arrived yet.
 *
 * No tabs and no actions, deliberately. The scripts and the cost table
 * are for a conversation that cannot start until the front desk checks
 * them in, and a coordinator who works ahead on a card here is reading
 * figures that may change before the patient sits down.
 */
function WaitingCard({ p }: { p: CheckInPatient }) {
  return (
    <article
      className="mb-2 flex flex-wrap items-center gap-x-3 gap-y-1 rounded-xl border border-gray-200 bg-white px-5 py-3.5"
      style={{ opacity: 0.75 }}
    >
      <span
        aria-hidden="true"
        className="h-2 w-2 flex-shrink-0 rounded-full"
        style={{ backgroundColor: "#9ca3af" }}
      />
      <div className="min-w-0 flex-1">
        <p className="text-sm">
          <span className="font-semibold text-slate-700">{p.patient_name}</span>
          <span className="text-slate-500">
            {" "}
            · {p.appointment_time} · {p.procedure_summary}
          </span>
        </p>
        <p className="mt-0.5 text-[11.5px] text-slate-500">
          ⏳ Waiting for check-in from front desk
        </p>
      </div>
      <span className="flex-shrink-0 rounded-full bg-slate-100 px-2.5 py-0.5 text-[11px] font-bold text-slate-500">
        WAITING
      </span>
    </article>
  );
}

/** A conversation that has happened. */
function DoneRow({ p, notified }: { p: CheckInPatient; notified: string }) {
  return (
    <div className="mb-2 flex flex-wrap items-center gap-2.5 rounded-xl border border-green-300 bg-green-50 px-4 py-3">
      <span className="text-[16px]" aria-hidden="true">
        ✅
      </span>
      <div className="min-w-0 flex-1 text-[13px] font-medium text-green-700">
        {p.patient_name} — consultation complete
      </div>
      <div className="text-[11px] text-[#6b7280]">{notified} notified</div>
    </div>
  );
}

function TableSkeleton() {
  return (
    <div className="animate-pulse space-y-2 px-5 py-4">
      <div className="h-3 w-44 rounded bg-gray-100" />
      {[0, 1, 2].map((i) => (
        <div key={i} className="h-3 w-full rounded bg-gray-100" />
      ))}
      <div className="h-3 w-2/3 rounded bg-gray-100" />
    </div>
  );
}

function PatientCard({
  p,
  ps,
  loadingSummary,
  practice,
  address,
  checked,
  onToggle,
  done,
  error,
  onComplete,
  onToast,
  tab,
  onTab,
  tpDone,
  onToggleTp,
}: {
  p: CheckInPatient;
  ps?: PatientSummary;
  loadingSummary: boolean;
  practice: string;
  address: string;
  checked: Set<number>;
  error?: string;
  onToggle: (i: number) => void;
  done: boolean;
  onComplete: () => void;
  onToast: (m: string) => void;
  tab: CardTab;
  onTab: (t: CardTab) => void;
  /** Talking-point keys the coordinator has covered. */
  tpDone: Set<string>;
  onToggleTp: (key: string) => void;
}) {
  // No navigate/demoLink here any more. The card no longer routes
  // anywhere — the coordinator's work ends on this screen.
  const heads = p.alerts.length > 0;
  const downgrade = ps?.procedures.find((x) => x.downgrade_applied);
  const progress = checked.size;
  const points = useMemo(() => talkingPoints(p, ps), [p, ps]);
  const [sending, setSending] = useState<"email" | "sms" | null>(null);

  return (
    <article className="mb-3 overflow-hidden rounded-xl border border-gray-200 bg-white">
      <div className="flex flex-wrap items-center gap-2 px-5 pt-4">
        <span
          aria-hidden="true"
          className="h-2 w-2 flex-shrink-0 rounded-full"
          style={{ backgroundColor: heads && !done ? "#d97706" : "#16a34a" }}
        />
        <span className="text-sm font-semibold text-slate-800">
          {p.patient_name}
        </span>
        <span className="text-sm text-slate-500">
          {p.procedure_summary} · {p.appointment_time}
        </span>
        <span
          className={`ml-auto rounded-full px-2.5 py-0.5 text-[11px] font-bold ${
            done
              ? "bg-slate-100 text-slate-600"
              : p.status === "checked_in"
                ? "bg-green-100 text-green-700"
                : "bg-amber-100 text-amber-700"
          }`}
        >
          {done
            ? "CONSULTATION DONE"
            : p.status === "checked_in"
              ? "READY"
              : "WAITING"}
        </span>
      </div>

      <div className="mt-3 px-5 py-3.5" style={{ background: GREEN }}>
        <p className="text-[10px] uppercase tracking-wider text-white/55">
          At a glance
        </p>
        <div className="mt-2 grid gap-2 sm:grid-cols-2">
          <Tile
            ok={p.insurance_active}
            title="Insurance active"
            detail={`${p.payer_name}${p.member_id ? ` · member ${p.member_id}` : ""}${
              p.enrollment_months ? ` · enrolled ${p.enrollment_months} months` : ""
            }`}
          />
          <Tile
            ok={p.provider_in_network}
            title="Provider in-network"
            detail={`${p.provider_name} · NPI ${p.provider_npi} · verified`}
          />
          <Tile
            ok={p.deductible_met}
            title={p.deductible_met ? "Deductible met" : "Deductible outstanding"}
            detail={
              p.deductible_met
                ? "Nothing more owed on the deductible"
                : `${formatCurrency(p.deductible_remaining)} still to meet this year`
            }
          />
          {heads ? (
            <Tile
              ok={false}
              title={`${p.alerts.length} item${p.alerts.length > 1 ? "s" : ""} to raise`}
              detail={p.alerts.map((a) => a.title).join(" · ")}
            />
          ) : (
            <Tile ok title="Nothing to flag" detail="Straightforward conversation" />
          )}
        </div>
      </div>

      {loadingSummary && <TableSkeleton />}

      {ps && (
        <>
          {/* ── Tabs ─────────────────────────────────────────── */}
          <nav
            className="flex border-b border-gray-200 bg-white"
            aria-label={`${p.patient_name} sections`}
          >
            {TAB_ORDER.map((t) => {
              const on = tab === t;
              return (
                <button
                  key={t}
                  type="button"
                  onClick={() => onTab(t)}
                  aria-current={on ? "page" : undefined}
                  className="cursor-pointer border-b-2 px-[18px] py-[11px] text-[12px] transition"
                  style={{
                    borderBottomColor: on ? GREEN : "transparent",
                    color: on ? GREEN : "#6b7280",
                    fontWeight: on ? 600 : 500,
                  }}
                >
                  {TAB_LABEL[t]}
                  {t === "talking" && points.length > 0 && (
                    <span className="ml-1.5 text-[11px] font-normal text-slate-400">
                      {points.filter((x) => tpDone.has(x.key)).length}/
                      {points.length}
                    </span>
                  )}
                  {t === "checklist" && (
                    <span className="ml-1.5 text-[11px] font-normal text-slate-400">
                      {progress}/{CHECKLIST.length}
                    </span>
                  )}
                </button>
              );
            })}
          </nav>

          {/* ── Talking points ───────────────────────────────── */}
          {tab === "talking" && (
            <div className="px-5 pt-4">
              <p className="text-[13px] font-semibold text-slate-800">
                What to cover with {firstNameOf(p.patient_name)}
              </p>
              <div className="mt-2.5">
                {points.map((tp, i) => (
                  <div
                    key={tp.key}
                    className="mb-[7px] flex gap-[10px] rounded-[7px] p-[10px]"
                    style={{
                      background: TONE[tp.tone].bg,
                      borderLeft: `3px solid ${TONE[tp.tone].bar}`,
                    }}
                  >
                    <span
                      aria-hidden="true"
                      className="flex h-5 w-5 flex-shrink-0 items-center justify-center rounded-full text-[10px] font-bold text-white"
                      style={{ background: TONE[tp.tone].bar }}
                    >
                      {i + 1}
                    </span>
                    <div className="min-w-0 flex-1">
                      <p className="mb-[3px] text-[12px] font-semibold text-[#111111]">
                        {tp.label}
                      </p>
                      <p className="text-[12px] italic leading-[1.55] text-[#374151]">
                        {tp.script}
                      </p>

                      {tp.key === "financing" && (
                        <div className="mt-2 flex flex-wrap items-center justify-between gap-2 rounded-lg border border-blue-200 bg-blue-50 px-3.5 py-2.5">
                          <span className="text-[12px] text-blue-800">
                            CareCredit or in-house payment plan available
                          </span>
                          <button
                            type="button"
                            onClick={() =>
                              onToast(
                                "Ask front desk for the CareCredit application form",
                              )
                            }
                            className="cursor-pointer rounded-md border-none bg-blue-500 px-3 py-1.5 text-[11px] font-semibold text-white transition hover:bg-blue-600"
                          >
                            Apply for financing →
                          </button>
                        </div>
                      )}

                      {tp.note && (
                        // Not italic and visually apart, because this is
                        // the one line on the card that must NOT be read
                        // to the patient.
                        <p
                          className="mt-[5px] rounded px-2 py-[5px] text-[11px] not-italic text-[#6b7280]"
                          style={{ background: "rgba(0,0,0,0.04)" }}
                        >
                          {tp.note}
                        </p>
                      )}
                    </div>

                    {/* A real checkbox, not a styled div: it has to be
                        reachable by keyboard and announced as checked.
                        A coordinator working through a script with one
                        hand on the patient's chart uses tab and space. */}
                    <label className="flex flex-shrink-0 cursor-pointer items-start pt-0.5">
                      <span className="sr-only">
                        Covered: {tp.label}
                      </span>
                      <input
                        type="checkbox"
                        checked={tpDone.has(tp.key)}
                        onChange={() => onToggleTp(tp.key)}
                        className="h-[18px] w-[18px] cursor-pointer rounded border-2 border-gray-300 text-accord-green-900 focus:ring-accord-green-500"
                      />
                    </label>
                  </div>
                ))}
              </div>
              <p className="mt-2 text-[10px] italic text-[#9ca3af]">
                ✓ Check each talking point as you cover it — the checklist
                updates automatically.
              </p>
              <p className="mt-1 text-[11px] text-gray-400">
                Derived from this patient&rsquo;s own coverage — the amber
                points appear only when the engine raised them.
              </p>
            </div>
          )}

          {/* ── Treatment & cost ─────────────────────────────── */}
          {tab === "treatment" && (
          <div className="px-5 pt-4">
            <p className="text-[13px] font-semibold text-slate-800">
              Treatment plan · {ps.patient_name}
            </p>
            <p className="text-[11.5px] text-slate-500">
              {ps.plan_name} · {ps.provider_name} · {ps.state}
            </p>

            <div className="mt-2.5 overflow-x-auto rounded-lg border border-gray-200">
              <table className="w-full min-w-[520px] text-left">
                <thead className="border-b border-gray-200 bg-slate-50">
                  <tr className="text-[10px] font-semibold uppercase tracking-wide text-slate-500">
                    <th className="px-3 py-2">Procedure</th>
                    <th className="px-3 py-2">Description</th>
                    <th className="px-3 py-2 text-right">Plan pays</th>
                    <th className="px-3 py-2 text-right">Patient pays</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {ps.procedures.map((x) => (
                    <tr key={x.cdt_code}>
                      <td className="px-3 py-2 font-mono text-[12px] text-slate-700">
                        {x.cdt_code}
                      </td>
                      <td className="px-3 py-2 text-[12.5px] text-slate-600">
                        {x.description ?? "—"}
                        {x.tooth_number ? ` · tooth #${x.tooth_number}` : ""}
                        {x.downgrade_applied ? " (at the lower rate)" : ""}
                      </td>
                      <td className="px-3 py-2 text-right text-[12.5px] tabular-nums text-slate-700">
                        {formatCurrency(x.insurance_pays)}
                      </td>
                      <td className="px-3 py-2 text-right text-[12.5px] font-medium tabular-nums text-slate-900">
                        {formatCurrency(x.patient_pays)}
                      </td>
                    </tr>
                  ))}
                  <tr className="bg-slate-50">
                    <td className="px-3 py-2.5 text-[12.5px] font-semibold" colSpan={2}>
                      Total
                    </td>
                    <td className="px-3 py-2.5 text-right text-[13px] font-bold tabular-nums text-slate-800">
                      {formatCurrency(ps.summary.total_insurance_pays)}
                    </td>
                    <td className="px-3 py-2.5 text-right text-[15px] font-bold tabular-nums text-slate-900">
                      {formatCurrency(ps.summary.total_patient_pays)}
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>

            <p className="mt-2 rounded-lg bg-green-50 px-3 py-2 text-[12.5px] text-green-800">
              Your in-network savings of{" "}
              {formatCurrency(ps.summary.total_in_network_savings)} are not your
              responsibility.
            </p>

            {downgrade && (
              <p className="mt-2 rounded-lg border-l-4 border-l-amber-400 bg-amber-50 px-3 py-2 text-[12.5px] text-amber-900">
                ⚠ {downgrade.downgrade_note ??
                  `${downgrade.cdt_code} is reimbursed at a lower material's rate. The patient is responsible for the difference.`}
              </p>
            )}

            <div className="mt-3 grid grid-cols-2 gap-2 lg:grid-cols-4">
              <Pill
                label="Annual max"
                value={`${formatCurrency(p.annual_max)} · ${formatCurrency(p.annual_max_remaining)} left`}
              />
              <Pill
                label="Deductible"
                value={
                  p.deductible_met
                    ? `${formatCurrency(p.deductible_total)} · met`
                    : `${formatCurrency(p.deductible_remaining)} to meet`
                }
              />
              {/* Percentages derived from the rows above, so the pill
                  cannot contradict the table under it. */}
              <Pill label="Plan pays" value={sharePhrase(ps)} />
              <Pill
                label="After this case"
                value={formatCurrency(p.annual_max_remaining_after)}
              />
            </div>
          </div>
          )}

          {/* The engine's raw alerts stay with the money, not with the
              scripts: the talking points already say these things in
              words a patient hears. */}
          {tab === "treatment" && heads && (
            <div className="px-5 pt-4">
              <p className="text-xs font-bold uppercase tracking-wide text-amber-600">
                Important notes
              </p>
              <div className="mt-2 space-y-2">
                {p.alerts.map((a) => (
                  <div
                    key={a.type}
                    className="rounded border-l-4 border-l-amber-400 bg-amber-50 px-3 py-2"
                  >
                    <p className="text-[13px] font-semibold text-amber-900">
                      {a.title}
                    </p>
                    <p className="mt-0.5 text-sm text-slate-600">{a.detail}</p>
                  </div>
                ))}
              </div>
            </div>
          )}

          {tab === "checklist" && (
          <div className="px-5 pt-4">
            <div className="flex items-baseline justify-between gap-2">
              <p className="text-[13px] font-semibold text-slate-800">
                Conversation checklist
              </p>
              <p className="text-[11.5px] text-slate-500">
                {progress}/{CHECKLIST.length} complete
              </p>
            </div>
            <div className="mt-1.5 h-1.5 w-full overflow-hidden rounded bg-gray-200">
              <div
                className="h-full rounded transition-all"
                style={{
                  width: `${(progress / CHECKLIST.length) * 100}%`,
                  background: GREEN,
                }}
              />
            </div>
            <ul className="mt-2 space-y-0.5">
              {CHECKLIST.map((item, i) => (
                <li key={item}>
                  <label className="flex cursor-pointer items-center gap-2.5 rounded px-1.5 py-1.5 transition hover:bg-slate-50">
                    <input
                      type="checkbox"
                      checked={checked.has(i)}
                      onChange={() => onToggle(i)}
                      className="h-4 w-4 rounded border-gray-300 text-accord-green-900 focus:ring-accord-green-500"
                    />
                    <span className="text-[13px] text-slate-700">
                      {item}
                      {/* The figure is named in the item itself, so a
                          coordinator cannot tick "confirmed" against a
                          number they never said out loud. */}
                      {i === 2 &&
                        ` (${formatCurrency(ps.summary.total_patient_pays)})`}
                    </span>
                  </label>
                </li>
              ))}
            </ul>
          </div>
          )}

          {/* Below the tabs, always. Whichever tab is open, the three
              things the coordinator does at the end of the conversation
              have to be one click away. */}
          <div className="flex flex-wrap gap-2 border-t border-gray-100 px-5 py-4">
            <button
              type="button"
              onClick={onComplete}
              disabled={done}
              className="cursor-pointer rounded-lg border-none px-4 py-2 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-60"
              style={{ backgroundColor: GREEN }}
            >
              {done ? "Consultation complete ✓" : "Mark consultation complete"}
            </button>
            <button
              type="button"
              onClick={() => {
                const w = window.open("", "_blank", "width=900,height=1100");
                if (!w) return onToast("Allow pop-ups to print");
                w.document.write(
                  generatePrintHTML(p, ps, checked, practice, address),
                );
                w.document.close();
              }}
              className="cursor-pointer rounded-lg border border-slate-200 bg-white px-4 py-2 text-sm text-slate-600 transition hover:bg-slate-50"
            >
              Print estimate
            </button>
            <button
              type="button"
              onClick={() => setSending("email")}
              className="cursor-pointer rounded-lg border border-slate-200 bg-white px-4 py-2 text-sm text-slate-600 transition hover:bg-slate-50"
            >
              Email to patient
            </button>
            <button
              type="button"
              onClick={() => setSending("sms")}
              disabled={!p.patient_phone}
              title={
                p.patient_phone
                  ? undefined
                  : "No mobile number on file for this patient"
              }
              className="cursor-pointer rounded-lg border border-slate-200 bg-white px-4 py-2 text-sm text-slate-600 transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-50"
            >
              Text to patient
            </button>
          </div>

          <div className="px-5 pb-4">
            <ActionError message={error ?? null} />
          </div>

          {sending === "email" && (
            <EmailModal
              patientName={p.patient_name}
              patientEmail={p.patient_email}
              senderName={p.sender_name || "Treatment Coordinator"}
              senderEmail={p.sender_email}
              practiceEmail={p.practice_email}
              practice={practice}
              defaultSubject={`Your treatment estimate — ${practice}`}
              // generateEmailText opens with its own "Subject:" line,
              // which the modal already has a field for. Stripped, or
              // the patient gets the subject twice.
              defaultBody={generateEmailText(
                p,
                ps,
                checked,
                practice,
                address,
              ).replace(/^Subject:[^\n]*\n+/, "")}
              onClose={() => setSending(null)}
              onToast={onToast}
            />
          )}

          {sending === "sms" && (
            <SmsModal
              patientName={p.patient_name}
              patientPhone={p.patient_phone}
              defaultMessage={smsFor(p, ps, practice)}
              onClose={() => setSending(null)}
              // Throws on failure so the modal can keep itself open and
              // show the error next to the message the coordinator is
              // about to lose. Closing on a failed send was how a text
              // that never left looked sent.
              onSend={async (message) => {
                await api.post("/communications/sms", {
                  pred_request_id: p.pred_request_id,
                  patient_name: p.patient_name,
                  patient_phone: p.patient_phone ?? "",
                  message,
                });
                onToast(`Text sent to ${firstNameOf(p.patient_name)} ✓`);
                setSending(null);
              }}
            />
          )}
        </>
      )}
    </article>
  );
}

/**
 * What the coordinator hands over.
 *
 * The dentist reads this on a queue card between operatories, so it
 * says who was seen, what was agreed, and what the patient owes —
 * not a checklist dump. `covered` is the set of talking points the
 * coordinator actually ticked, which is the closest thing this screen
 * has to a record of what was discussed.
 */
function noteFor(
  // patient_pays_today, not patient_pays — the latter is not a field on
  // this row, and an optional property that never exists typechecks
  // clean while silently dropping the line.
  p: { patient_name: string; patient_pays_today: number | null },
  covered?: Set<string>,
): string {
  const bits = [`Consultation complete with ${p.patient_name}.`];
  const nCovered = covered?.size ?? 0;
  if (nCovered) {
    bits.push(
      `${nCovered} talking point${nCovered === 1 ? "" : "s"} covered.`,
    );
  }
  if (p.patient_pays_today != null) {
    bits.push(
      `Patient portion ${formatCurrency(p.patient_pays_today)} discussed.`,
    );
  }
  bits.push("Ready for your clinical review.");
  return bits.join(" ");
}

export default function PatientFinancial() {
  const { effectiveUser, role } = useAuth();
  const [toast, setToast] = useState<string | null>(null);
  const [filter, setFilter] = useState<Bucket | "all">("all");
  const [doneIds, setDoneIds] = useState<Set<string>>(new Set());
  const [checks, setChecks] = useState<Record<string, Set<number>>>({});
  // Per patient, so opening the cost table on one card does not move
  // every other card off its scripts.
  const [tabs, setTabs] = useState<Record<string, CardTab>>({});
  // Talking points covered, per patient, keyed on the point's own key
  // rather than its index — see TP_TO_CHECKLIST.
  const [tpChecks, setTpChecks] = useState<Record<string, Set<string>>>({});
  // One hook for every card on the page — see useCreateHandoff.
  const handoff = useCreateHandoff();
  // Per patient card, persistent. Both writes here set their local
  // state inside onSuccess already; a failure only ever flashed.
  const [cardErrors, setCardErrors] = useState<Record<string, string>>({});

  /**
   * Tick a talking point, and the checklist item it closes.
   *
   * Unticking clears the mapped item too. The two are one thing to a
   * coordinator: leaving "Treatment plan explained" ticked after they
   * untick the point that explained it is the checklist telling them
   * something they just said was not true.
   */
  function toggleTp(id: string, key: string) {
    // Read the direction from the CURRENT state, not from a variable
    // assigned inside the updater. React may run an updater later than
    // the line after it — and twice under StrictMode — so a `nowOn`
    // set in there is still false when the checklist sync reads it.
    // That is exactly why ticking a point moved its own badge and left
    // the checklist alone.
    const nowOn = !(tpChecks[id]?.has(key) ?? false);

    setTpChecks((prev) => {
      const next = new Set(prev[id] ?? []);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return { ...prev, [id]: next };
    });

    const item = TP_TO_CHECKLIST[key];
    if (item === undefined) return;
    setChecks((prev) => {
      const next = new Set(prev[id] ?? []);
      if (nowOn) next.add(item);
      else next.delete(item);
      return { ...prev, [id]: next };
    });
  }
  const { selectedDate, setSelectedDate, availableDates } = useDatePicker();

  // Same key shape as the check-in screen, date included: the two pages
  // read the same endpoint, and a key without the date would have one
  // of them serving the other's day out of cache.
  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: ["checkin", "today", selectedDate],
    queryFn: async () =>
      (
        await api.get<CheckInPatient[]>(
          `/checkin/today?${dayParams(selectedDate)}`,
        )
      ).data,
    refetchInterval: 30_000,
  });
  const patients = Array.isArray(data) ? data : [];

  // One query per patient, cached under the SAME key /coverage/:id uses,
  // so opening a patient's full breakdown is instant and cannot show a
  // different number than the card did.
  const summaries = useQueries({
    queries: patients.map((p) => ({
      queryKey: keys.patientSummary(p.pred_request_id),
      queryFn: async () =>
        (
          await api.get<PatientSummary>(
            `/decisions/${p.pred_request_id}/patient-summary`,
          )
        ).data,
      staleTime: 5 * 60_000,
    })),
  });

  function flash(m: string) {
    setToast(m);
    window.setTimeout(() => setToast(null), 3000);
  }

  /**
   * ⚠ THE SERVER DECIDES, NOT THIS TAB. doneIds was the only record
   * that a consultation had finished, so a refresh of /coverage put
   * everyone she had already seen back under "ready for consultation"
   * — and marking one complete a second time sent the dentist a second
   * handoff with nothing to dedupe it.
   *
   * consultation_complete comes off /checkin/today, derived from a
   * clinical_handoffs row of kind 'consultation_complete'. doneIds is
   * kept only as optimism between the click and the refetch.
   */
  const isDone = (p: CheckInPatient) =>
    p.consultation_complete || doneIds.has(p.pred_request_id);

  const bucketOf = (p: CheckInPatient): Bucket =>
    isDone(p)
      ? "done"
      : p.status === "checked_in"
        ? "ready"
        : "waiting";

  const all = { ready: [], waiting: [], done: [] } as Record<Bucket, CheckInPatient[]>;
  patients.forEach((p) => all[bucketOf(p)].push(p));
  const shown = (b: Bucket) => (filter === "all" || filter === b ? all[b] : []);

  const firstName = firstNameOf(effectiveUser?.name ?? "");
  const practice = effectiveUser?.tenant_name ?? "Accord Dental";
  const address = effectiveUser?.tenant_address ?? "";

  function renderSection(b: Bucket) {
    const list = shown(b);
    if (list.length === 0) return null;
    return (
      <section className="mt-6" key={b}>
        <h2 className="mb-3 text-sm font-semibold text-slate-600">
          {BUCKET_LABEL[b].toUpperCase()} ({list.length})
        </h2>
        {list.map((p) => {
          const i = patients.indexOf(p);
          const q = summaries[i];
          // Not arrived: no scripts, no cost table, no actions.
          if (b === "waiting") {
            return <WaitingCard key={p.pred_request_id} p={p} />;
          }
          // Conversation over: one line.
          if (b === "done") {
            return (
              <DoneRow
                key={p.pred_request_id}
                p={p}
                notified={p.provider_name}
              />
            );
          }
          return (
            <PatientCard
              key={p.pred_request_id}
              p={p}
              ps={q?.data}
              loadingSummary={Boolean(q?.isLoading)}
              practice={practice}
              address={address}
              done={isDone(p)}
              checked={checks[p.pred_request_id] ?? new Set<number>()}
              onToggle={(idx) =>
                setChecks((prev) => {
                  const next = new Set(prev[p.pred_request_id] ?? []);
                  if (next.has(idx)) next.delete(idx);
                  else next.add(idx);
                  return { ...prev, [p.pred_request_id]: next };
                })
              }
              error={cardErrors[p.pred_request_id]}
              onComplete={() => {
                // The handoff is the notification. Nothing said "the
                // provider was notified" before except the toast — no
                // request left the browser, and the dentist's queue
                // never heard about it.
                handoff.mutate(
                  {
                    predRequestId: p.pred_request_id,
                    to_role: "dentist",
                    // Not a plain note: this row IS the record that the
                    // consultation finished, and the coverage screen
                    // reads it back as state.
                    kind: "consultation_complete",
                    note: noteFor(p, tpChecks[p.pred_request_id]),
                  },
                  {
                    onSuccess: () => {
                      setDoneIds((prev) =>
                        new Set(prev).add(p.pred_request_id),
                      );
                      setCardErrors((prev) => {
                        const next = { ...prev };
                        delete next[p.pred_request_id];
                        return next;
                      });
                      // p.provider_name, not a hardcoded "Dr. Chinta" —
                      // the same card renders for Tampa, whose clinical
                      // team is Dr. Maria Rodriguez.
                      flash(
                        `${p.patient_name} consultation complete · ${p.provider_name} notified`,
                      );
                    },
                    onError: () =>
                      setCardErrors((prev) => ({
                        ...prev,
                        [p.pred_request_id]:
                          `${p.provider_name} was NOT notified and the ` +
                          "consultation is not marked complete. Nothing " +
                          "reached the clinical queue.",
                      })),
                  },
                );
              }}
              onToast={flash}
              tpDone={tpChecks[p.pred_request_id] ?? new Set<string>()}
              onToggleTp={(key) => toggleTp(p.pred_request_id, key)}
              tab={tabs[p.pred_request_id] ?? "talking"}
              onTab={(t) =>
                setTabs((prev) => ({ ...prev, [p.pred_request_id]: t }))
              }
            />
          );
        })}
      </section>
    );
  }

  // No tab bar. This page is the whole of the coordinator's screen —
  // the "All pre-Ds" tab pointed at /coverage/all, which is the
  // reviewer's queue and is not part of this job. The route still
  // exists for the roles that hold it; it is just not reachable from
  // here.
  return (
    <div className="relative min-h-full pb-16">
      <div className="mx-auto max-w-4xl px-6 py-6">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h1 className="text-[22px] font-semibold text-gray-900">
              Good morning{firstName ? `, ${firstName}` : ""}
            </h1>
            <p className="mt-0.5 text-[13px] text-slate-500">
              {role ? ROLE_LABELS[role] : ""}
              {role && " · "}
              {practice}
            </p>
          </div>
          <DatePickerDropdown
            selectedDate={selectedDate}
            availableDates={availableDates}
            onChange={setSelectedDate}
          />
        </div>

        <div className="mt-5 grid grid-cols-3 gap-3">
          <StatCard
            label="Ready for consultation"
            value={all.ready.length}
            tone="text-green-600"
            active={filter === "ready"}
            onClick={() => setFilter((f) => (f === "ready" ? "all" : "ready"))}
          />
          <StatCard
            label="Waiting"
            value={all.waiting.length}
            tone="text-amber-600"
            active={filter === "waiting"}
            onClick={() => setFilter((f) => (f === "waiting" ? "all" : "waiting"))}
          />
          <StatCard
            label="Consultation done"
            value={all.done.length}
            tone="text-slate-400"
            active={filter === "done"}
            onClick={() => setFilter((f) => (f === "done" ? "all" : "done"))}
          />
        </div>

        {filter !== "all" && (
          <button
            type="button"
            onClick={() => setFilter("all")}
            className="mb-3 mt-4 text-sm text-slate-500 transition hover:text-slate-800"
          >
            ← All patients
          </button>
        )}

        {isLoading && (
          <div className="mt-6 space-y-3">
            {[0, 1, 2].map((i) => (
              <div
                key={i}
                className="animate-pulse rounded-xl border border-gray-200 bg-white p-5"
              >
                <div className="h-3 w-52 rounded bg-gray-100" />
                <div className="mt-3 h-20 rounded-lg bg-gray-100" />
                <div className="mt-3 h-16 rounded bg-gray-100" />
              </div>
            ))}
          </div>
        )}

        {isError && !isLoading && (
          <div className="mt-6 rounded-xl border border-red-200 bg-red-50 p-5">
            <p className="text-[13.5px] font-medium text-red-700">
              Could not load today&rsquo;s patients.
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

        {!isLoading && !isError && patients.length === 0 && (
          <p className="mt-6 rounded-xl border border-gray-200 bg-white p-5 text-[13px] text-slate-500">
            No patients scheduled for today.
          </p>
        )}

        {renderSection("ready")}
        {renderSection("waiting")}
        {renderSection("done")}

        {!isLoading &&
          patients.length > 0 &&
          shown("ready").length + shown("waiting").length + shown("done").length ===
            0 && (
            <p className="mt-6 rounded-xl border border-gray-200 bg-white p-5 text-[13px] text-slate-500">
              No patients in that group right now.
            </p>
          )}

        {patients.length > 0 && (
          <p className="mt-6 text-[11px] leading-relaxed text-gray-400">
            Live from dental-os. &ldquo;Consultation complete&rdquo; is
            recorded against the pre-D and survives a refresh; the
            talking-point ticks are still this tab only.
          </p>
        )}
      </div>

      {toast && (
        <div
          role="status"
          className="pointer-events-none absolute inset-x-0 bottom-4 flex justify-center"
        >
          <span
            className="rounded-lg px-4 py-2.5 text-[13px] font-medium text-white shadow-lg"
            style={{ backgroundColor: GREEN }}
          >
            {toast}
          </span>
        </div>
      )}
    </div>
  );
}
