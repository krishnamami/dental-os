import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { AlertTriangle, ArrowLeft, Check, Printer, X } from "lucide-react";

import DetailTopbar from "../../../components/DetailTopbar";
import { useAuth } from "../../../context/AuthContext";
import { useDecision, usePatientSummary } from "../../../hooks/useApi";
import { useDemoLink } from "../../../hooks/useDemo";
import type { Decision, PatientSummary, Signal } from "../../../types/dental";
import { formatCurrency } from "../../../utils/format";

/**
 * F-01 — patient check-in. The front desk's whole screen.
 *
 * ── What this page is NOT ────────────────────────────────────────────
 *
 * It is not a smaller workbench. A front desk has about ten seconds
 * per patient and no authority over a clinical decision, so nothing
 * here shows a signal code, a wave number, a criteria score or a
 * persona. Those live one role along, and a receptionist reading
 * "COVERAGE_BUNDLING_CONFLICT" learns nothing they can act on.
 *
 * Every sentence below is translated from a real signal at the point
 * of use, and each translation names the signal it came from so the
 * two cannot drift silently.
 *
 * ── Where the list comes from ────────────────────────────────────────
 *
 * Names, plans, member and group numbers were read from the database
 * on 7 Aug 2026. APPOINTMENT TIMES ARE NOT REAL — there is no
 * schedule in dental-os, no appointments table and no check-in state
 * to persist to. The times are a plausible morning so the queue has
 * shape, and the page says so at the foot of the list.
 */

const GREEN = "#0F4D37";
const AMBER = "#F57F17";

type Status = "waiting" | "checked-in" | "done";

interface Appointment {
  id: string;
  name: string;
  time: string;
  procedure: string;
  dot: string;
  status: Status;
  alert: string | null;
  member: string;
  group: string;
}

const APPOINTMENTS: Appointment[] = [
  {
    id: "PRED-SIM-DA-A01",
    name: "James Mitchell",
    time: "9:00 AM",
    procedure: "Implant + crown",
    dot: AMBER,
    status: "waiting",
    alert: "Pre-D required",
    member: "SS-DA-A01-0001",
    group: "GRP-44821",
  },
  {
    id: "PRED-SIM-DA-D04",
    name: "Linda Taylor",
    time: "9:30 AM",
    procedure: "Crown",
    dot: AMBER,
    status: "waiting",
    alert: "Downgrade noted",
    member: "SS-DA-D04-0001",
    group: "GRP-77103",
  },
  {
    id: "PRED-SIM-DA-U01",
    name: "Robert Thompson",
    time: "10:00 AM",
    procedure: "Cleaning",
    dot: GREEN,
    status: "checked-in",
    alert: null,
    member: "SS-DA-U01-0001",
    group: "GRP-44821",
  },
  {
    id: "PRED-SIM-DA-U02",
    name: "Maria Santos",
    time: "10:30 AM",
    procedure: "Bitewings",
    dot: GREEN,
    status: "checked-in",
    alert: null,
    member: "SS-DA-U02-0001",
    group: "GRP-44821",
  },
  {
    id: "PRED-SIM-DA-B04",
    name: "Carlos Rivera",
    time: "11:00 AM",
    procedure: "Implant consult",
    dot: AMBER,
    status: "waiting",
    alert: "Bundling conflict",
    member: "SS-DA-B04-0001",
    group: "GRP-44821",
  },
];

const STATUS_LABEL: Record<Status, string> = {
  waiting: "WAITING",
  "checked-in": "CHECKED IN",
  done: "DONE",
};

const STATUS_CLS: Record<Status, string> = {
  waiting: "bg-amber-100 text-amber-800",
  "checked-in": "bg-green-100 text-green-800",
  done: "bg-gray-100 text-gray-500",
};

/** The seven steps a case moves through, front desk's view of it. */
const JOURNEY = [
  "Treatment planned",
  "Insurance verified",
  "Patient informed",
  "Pre-D submitted",
  "Approved",
  "Treatment completed",
  "Claim paid",
];

/**
 * Where this case actually is, read off the bundle.
 *
 * Insurance is verified when the engine says so. "Patient informed" is
 * the step the person at this desk is standing on — the product cannot
 * know whether that conversation happened, so it is shown as CURRENT,
 * never as done. Nothing past submission can be known at all: there is
 * no submission, approval or claim state in dental-os yet, so those
 * four stay grey rather than being guessed from `decision`.
 */
function journeyIndex(d: Decision | undefined): number {
  if (!d) return 1;
  const verified = d.all_signals.some(
    (s) => s.signal_code === "ELIGIBILITY_VERIFIED",
  );
  return verified ? 2 : 1;
}

type CheckTone = "ok" | "warn" | "bad";

interface StatusCheck {
  tone: CheckTone;
  title: string;
  detail: string;
}

const CHECK_STYLE: Record<CheckTone, { border: string; text: string }> = {
  ok: { border: "border-l-green-600", text: "text-green-700" },
  warn: { border: "border-l-amber-500", text: "text-amber-700" },
  bad: { border: "border-l-red-600", text: "text-red-700" },
};

/**
 * The four things a front desk is actually asked at the window,
 * each translated from the signal that answers it.
 *
 *   Insurance active      <- ELIGIBILITY_VERIFIED
 *   Visit covered         <- the per-procedure split in patient-summary
 *   Provider in-network   <- PROVIDER_VERIFIED
 *   Pre-D required        <- COVERAGE_PRED_REQUIRED / pre_d_required
 *
 * A check appears ONLY when its signal does. An absent signal is not
 * a pass — it is a question the engine did not answer, and quietly
 * rendering a green tick for it would be the worst thing this page
 * could do.
 */
function statusChecks(
  d: Decision | undefined,
  ps: PatientSummary | undefined,
): StatusCheck[] {
  if (!d) return [];
  const by = (c: string): Signal | undefined =>
    d.all_signals.find((s) => s.signal_code === c);
  const out: StatusCheck[] = [];

  const elig = by("ELIGIBILITY_VERIFIED");
  if (elig) {
    const months = elig.data.months_enrolled;
    out.push({
      tone: "ok",
      title: "Insurance active",
      detail:
        `${d.plan_name}` +
        (typeof months === "number" ? ` · enrolled ${months} months` : "") +
        (typeof elig.data.annual_max_remaining === "number"
          ? ` · ${formatCurrency(elig.data.annual_max_remaining as number)} annual max left`
          : ""),
    });
  } else if (by("ELIG_COVERAGE_INACTIVE")) {
    out.push({
      tone: "bad",
      title: "Insurance NOT active",
      detail: "Do not begin treatment. The plan shows no active coverage.",
    });
  }

  if (ps && ps.procedures.length > 0) {
    const notCovered = ps.procedures.filter((p) => !p.covered);
    if (notCovered.length > 0) {
      out.push({
        tone: "bad",
        title: "Part of today's visit is not covered",
        detail: `${notCovered
          .map((p) => p.cdt_code)
          .join(", ")} — the patient pays these in full.`,
      });
    } else {
      // The share, computed — not a "50%" anyone typed. The deductible
      // comes off first, which is why the implant looks like 49%.
      const ded = ps.summary.total_deductible_applied;
      out.push({
        tone: "ok",
        title: "Today's visit covered",
        detail:
          `Plan pays ${formatCurrency(ps.summary.total_insurance_pays)} of ` +
          `${formatCurrency(ps.summary.total_contracted)} allowed` +
          (ded > 0 ? `, after ${formatCurrency(ded)} deductible` : "") +
          ".",
      });
    }
  }

  const prov = by("PROVIDER_VERIFIED");
  if (prov) {
    out.push({
      tone: "ok",
      title: "Provider in-network",
      detail:
        `${d.provider_name}` +
        (prov.data.provider_npi ? ` · NPI ${prov.data.provider_npi}` : "") +
        (prov.data.nppes_verified ? " · verified with NPPES" : ""),
    });
  } else if (by("PROVIDER_OIG_EXCLUDED")) {
    out.push({
      tone: "bad",
      title: "Provider is on the OIG exclusion list",
      detail: "Do not schedule. Escalate to the practice owner.",
    });
  }

  const preD =
    by("COVERAGE_PRED_REQUIRED") ??
    (ps?.procedures.some((p) => p.pre_d_required) ? ({} as Signal) : undefined);
  if (preD) {
    out.push({
      tone: "warn",
      title: "Pre-D required before treatment",
      detail:
        "Must be submitted and approved by the plan before the appointment goes ahead.",
    });
  }

  return out;
}

/**
 * The things to say out loud, in the words a receptionist would use.
 *
 * Same rule as the checks: one entry per signal that is present, and
 * the signal is named in the comment so a wording change here can be
 * traced back to the finding it paraphrases.
 */
function plainAlerts(
  d: Decision | undefined,
  ps: PatientSummary | undefined,
): string[] {
  if (!d) return [];
  const has = (c: string) => d.all_signals.some((s) => s.signal_code === c);
  const out: string[] = [];

  // COVERAGE_PRED_REQUIRED
  const preDCodes = (ps?.procedures ?? [])
    .filter((p) => p.pre_d_required)
    .map((p) => p.cdt_code);
  if (preDCodes.length > 0) {
    out.push(
      `Pre-determination required for ${preDCodes.join(", ")}. It must be ` +
        `submitted to ${d.plan_name} and approved before treatment begins.`,
    );
  }

  // annual_max_remaining_after on the cost summary
  const after = ps?.summary.annual_max_remaining_after;
  if (after !== undefined && after < 500) {
    out.push(
      `Annual maximum nearly exhausted — ${formatCurrency(after)} left after ` +
        `today's case. Let the patient know before treatment.`,
    );
  }

  // COVERAGE_DOWNGRADE_APPLIED
  const down = (ps?.procedures ?? []).find((p) => p.downgrade_applied);
  if (down) {
    out.push(
      `The plan pays for ${down.cdt_code} at a cheaper material's rate. ` +
        `The patient owes the difference — ${formatCurrency(down.patient_pays)} ` +
        `on that item.`,
    );
  }

  // COVERAGE_BUNDLING_CONFLICT
  if (has("COVERAGE_BUNDLING_CONFLICT")) {
    out.push(
      "Two of today's procedures are billed together by this plan. Billing " +
        "is documenting them separately — do not quote a final figure yet.",
    );
  }

  // Any DOC_* gap the front desk can actually close.
  if (has("DOC_NARRATIVE_MISSING") || has("CLINICAL_NARRATIVE_MISSING")) {
    out.push(
      "A written note from the dentist is still outstanding on this case.",
    );
  }

  return out;
}

function CountPill({
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
      <p className="text-[20px] font-semibold leading-none" style={{ color: tone }}>
        {value}
      </p>
      <p className="mt-1 text-[10px] uppercase tracking-wide text-gray-500">
        {label}
      </p>
    </div>
  );
}

export default function CheckIn() {
  const navigate = useNavigate();
  const demoLink = useDemoLink();
  const { effectiveUser } = useAuth();

  const [selectedId, setSelectedId] = useState(APPOINTMENTS[0].id);
  const [showDetail, setShowDetail] = useState(false);
  const [toast, setToast] = useState("");
  // Check-in is remembered in this tab only. There is no check-in
  // endpoint and no appointment record to write to; the page says so
  // rather than implying the practice management system was told.
  const [checkedIn, setCheckedIn] = useState<Record<string, string>>({});

  const { data: d, isLoading, isError, refetch } = useDecision(selectedId);
  const { data: ps } = usePatientSummary(selectedId);

  const row = APPOINTMENTS.find((a) => a.id === selectedId) ?? APPOINTMENTS[0];
  const statusOf = (a: Appointment): Status =>
    checkedIn[a.id] ? "checked-in" : a.status;

  const waiting = APPOINTMENTS.filter((a) => statusOf(a) === "waiting").length;
  const inHouse = APPOINTMENTS.filter((a) => statusOf(a) === "checked-in").length;
  const done = APPOINTMENTS.filter((a) => statusOf(a) === "done").length;

  const checks = statusChecks(d, ps);
  const alerts = plainAlerts(d, ps);
  const step = journeyIndex(d);
  const firstName = (effectiveUser?.name ?? "")
    .replace(/^(Dr|Mr|Mrs|Ms)\.?\s+/i, "")
    .split(/\s+/)[0];
  const today = new Date().toLocaleDateString(undefined, {
    weekday: "long",
    month: "short",
    day: "numeric",
  });

  function toastFor(msg: string) {
    setToast(msg);
    window.setTimeout(() => setToast(""), 3000);
  }

  function checkIn() {
    const at = new Date().toLocaleTimeString([], {
      hour: "numeric",
      minute: "2-digit",
    });
    setCheckedIn((prev) => ({ ...prev, [row.id]: at }));
    toastFor(`${row.name} checked in ✓`);
  }

  return (
    <div className="lg:flex lg:h-[calc(100dvh-49px)] lg:overflow-hidden">
      {/* ── Left: today ──────────────────────────────────────── */}
      <aside
        className={`border-gray-200 lg:w-72 lg:flex-shrink-0 lg:overflow-y-auto lg:border-r ${
          showDetail ? "hidden lg:block" : "block"
        }`}
      >
        <div className="border-b border-gray-200 px-3 py-3.5">
          <p className="text-[14px] font-semibold text-gray-900">
            Good morning{firstName ? `, ${firstName}` : ""}
          </p>
          <p className="mt-0.5 text-[12px] text-gray-500">
            {effectiveUser?.tenant_name ?? "Accord Dental"} · {today}
          </p>
          <div className="mt-3 grid grid-cols-3 gap-2">
            <CountPill value={waiting} label="Waiting" tone={AMBER} />
            <CountPill value={inHouse} label="Checked in" tone={GREEN} />
            <CountPill value={done} label="Done" tone="#64748b" />
          </div>
        </div>

        <p className="px-3 pb-1 pt-3 text-[10px] font-bold uppercase tracking-[0.12em] text-gray-400">
          Today&rsquo;s appointments
        </p>

        {APPOINTMENTS.map((a) => {
          const st = statusOf(a);
          const selected = a.id === selectedId;
          return (
            <button
              key={a.id}
              type="button"
              onClick={() => {
                setSelectedId(a.id);
                setShowDetail(true);
              }}
              aria-current={selected ? "true" : undefined}
              className="block w-full border-b border-gray-100 px-3 py-2.5 text-left transition hover:bg-gray-50"
              style={{
                backgroundColor: selected ? "#f0f7f2" : undefined,
                borderLeft: selected
                  ? `2px solid ${GREEN}`
                  : "2px solid transparent",
              }}
            >
              <span className="flex items-start gap-2">
                <span
                  aria-hidden="true"
                  className="mt-[5px] h-2 w-2 flex-shrink-0 rounded-full"
                  style={{ backgroundColor: st === "checked-in" ? GREEN : a.dot }}
                />
                <span className="min-w-0 flex-1">
                  <span className="flex items-baseline justify-between gap-2">
                    <span className="truncate text-[13.5px] font-medium text-gray-900">
                      {a.name}
                    </span>
                    <span
                      className={`flex-shrink-0 rounded-full px-1.5 py-0.5 text-[9px] font-bold ${STATUS_CLS[st]}`}
                    >
                      {STATUS_LABEL[st]}
                    </span>
                  </span>
                  <span className="mt-0.5 block text-[11.5px] text-gray-500">
                    {a.time} · {a.procedure}
                  </span>
                  {a.alert && (
                    <span className="mt-1 inline-block rounded bg-amber-50 px-1.5 py-0.5 text-[10px] font-medium text-amber-700">
                      {a.alert}
                    </span>
                  )}
                  {checkedIn[a.id] && (
                    <span className="mt-1 block text-[10px] text-green-700">
                      Checked in at {checkedIn[a.id]}
                    </span>
                  )}
                </span>
              </span>
            </button>
          );
        })}

        <p className="px-3 py-4 text-[11px] leading-relaxed text-gray-400">
          Five patients, read from the database on 7 Aug 2026. The appointment
          times are illustrative — there is no schedule in dental-os yet, and
          check-in is remembered in this tab only.
        </p>
      </aside>

      {/* ── Right: this patient ──────────────────────────────── */}
      <section
        className={`min-w-0 flex-1 flex-col overflow-y-auto lg:flex ${
          showDetail ? "flex" : "hidden lg:flex"
        }`}
      >
        <button
          type="button"
          onClick={() => setShowDetail(false)}
          className="inline-flex min-h-[36px] items-center gap-1.5 border-b border-gray-200 px-4 text-[12.5px] font-medium text-gray-500 hover:text-gray-900 lg:hidden"
        >
          <ArrowLeft size={14} />
          Today
        </button>

        {/* No Submit pre-D here. Submitting is not this desk's call. */}
        <DetailTopbar
          root="Check-in"
          current={d?.patient_name ?? row.name}
          actions={[
            {
              label: "Print estimate",
              onClick: () => window.print(),
              disabled: !ps,
            },
            {
              label: "Notify clinical",
              onClick: () => toastFor("Clinical team notified ✓"),
            },
          ]}
        />

        <div className="flex-1 px-5 py-5 sm:px-6">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div>
              <h1 className="text-[22px] font-semibold text-gray-900">
                {d?.patient_name ?? row.name}
              </h1>
              <p className="mt-0.5 text-[13px] text-gray-500">
                {row.time} · {row.procedure} · member {row.member} · group{" "}
                {row.group}
              </p>
            </div>
            <span
              className={`rounded-full px-2.5 py-1 text-[11px] font-bold ${STATUS_CLS[statusOf(row)]}`}
            >
              {STATUS_LABEL[statusOf(row)]}
            </span>
          </div>

          {isLoading && (
            <div className="mt-4 animate-pulse space-y-2">
              {[0, 1, 2, 3].map((i) => (
                <div key={i} className="h-14 rounded-lg bg-gray-100" />
              ))}
            </div>
          )}

          {isError && !isLoading && (
            <div className="mt-4 rounded-xl border border-red-200 bg-red-50 p-4">
              <p className="text-[13px] font-medium text-red-700">
                Could not load this patient&rsquo;s benefits.
              </p>
              <button
                type="button"
                onClick={() => void refetch()}
                className="mt-2 rounded-lg border border-red-300 px-3 py-1.5 text-[12.5px] font-medium text-red-700 transition hover:bg-red-100"
              >
                Retry
              </button>
            </div>
          )}

          {d && !isLoading && (
            <>
              {/* Traffic lights */}
              <div className="mt-4 space-y-2">
                {checks.map((c) => {
                  const st = CHECK_STYLE[c.tone];
                  return (
                    <div
                      key={c.title}
                      className={`flex gap-2.5 rounded-lg border border-y-gray-200 border-r-gray-200 border-l-4 bg-white px-4 py-3 ${st.border}`}
                    >
                      <span className={`mt-0.5 flex-shrink-0 ${st.text}`}>
                        {c.tone === "ok" ? (
                          <Check size={15} strokeWidth={3} />
                        ) : c.tone === "warn" ? (
                          <AlertTriangle size={14} />
                        ) : (
                          <X size={15} strokeWidth={3} />
                        )}
                      </span>
                      <div>
                        <p className={`text-[13.5px] font-semibold ${st.text}`}>
                          {c.title}
                        </p>
                        <p className="mt-0.5 text-[12px] text-gray-600">
                          {c.detail}
                        </p>
                      </div>
                    </div>
                  );
                })}
              </div>

              {/* Say this out loud */}
              {alerts.length > 0 && (
                <div className="mt-4 rounded-xl border border-amber-200 bg-amber-50 p-4">
                  <p className="flex items-center gap-1.5 text-[13px] font-semibold text-amber-900">
                    <AlertTriangle size={14} />
                    Before check-in:
                  </p>
                  <ul className="mt-2 space-y-1.5">
                    {alerts.map((a) => (
                      <li
                        key={a}
                        className="text-[12.5px] leading-relaxed text-amber-900"
                      >
                        • {a}
                      </li>
                    ))}
                  </ul>
                </div>
              )}

              {/* The number the patient will ask for */}
              {ps && (
                <div className="mt-4 overflow-hidden rounded-xl border border-gray-200 bg-white">
                  <p className="border-b border-gray-200 bg-slate-50 px-4 py-2 text-[12px] font-semibold text-gray-700">
                    Today&rsquo;s estimated patient cost
                  </p>
                  <table className="w-full text-left">
                    <tbody className="divide-y divide-gray-100">
                      {ps.procedures.map((p) => (
                        <tr key={p.cdt_code}>
                          <td className="px-4 py-2 text-[12.5px] text-gray-700">
                            {p.description ?? p.cdt_code}{" "}
                            <span className="font-mono text-[11px] text-gray-400">
                              ({p.cdt_code})
                            </span>
                          </td>
                          <td className="px-4 py-2 text-right text-[12.5px] tabular-nums text-gray-900">
                            {formatCurrency(p.patient_pays)}
                          </td>
                        </tr>
                      ))}
                      <tr className="bg-slate-50">
                        <td className="px-4 py-2.5 text-[12.5px] font-semibold text-gray-900">
                          Total
                        </td>
                        <td className="px-4 py-2.5 text-right text-[15px] font-bold tabular-nums text-gray-900">
                          {formatCurrency(ps.summary.total_patient_pays)}
                        </td>
                      </tr>
                    </tbody>
                  </table>
                  <p className="border-t border-gray-100 px-4 py-2 text-[11px] text-gray-400">
                    Estimate based on current benefits — the final amount may
                    vary.
                    {ps.caveats.length > 0 && ` ${ps.caveats[0]}.`}
                  </p>
                </div>
              )}

              {/* Where we are */}
              <div className="mt-5">
                <p className="text-[12px] font-semibold text-gray-700">
                  Where we are
                </p>
                <ol className="mt-3 flex items-start gap-0 overflow-x-auto pb-1">
                  {JOURNEY.map((label, i) => {
                    const past = i < step;
                    const now = i === step;
                    return (
                      <li
                        key={label}
                        className="flex min-w-[92px] flex-1 flex-col items-center"
                      >
                        <div className="flex w-full items-center">
                          <span
                            className={`h-px flex-1 ${i === 0 ? "bg-transparent" : past || now ? "bg-green-500" : "bg-gray-200"}`}
                          />
                          <span
                            className="flex h-3.5 w-3.5 flex-shrink-0 items-center justify-center rounded-full border-2"
                            style={{
                              background: past ? GREEN : "white",
                              borderColor: past || now ? GREEN : "#d1d5db",
                            }}
                          />
                          <span
                            className={`h-px flex-1 ${i === JOURNEY.length - 1 ? "bg-transparent" : past ? "bg-green-500" : "bg-gray-200"}`}
                          />
                        </div>
                        <span
                          className={`mt-1.5 px-1 text-center text-[10.5px] leading-tight ${
                            now
                              ? "font-semibold text-green-700"
                              : past
                                ? "text-gray-500"
                                : "text-gray-400"
                          }`}
                        >
                          {label}
                        </span>
                      </li>
                    );
                  })}
                </ol>
                <p className="mt-2 text-[11px] text-gray-400">
                  The first two steps come from the pre-D. Everything from
                  submission onward has no state in dental-os yet, so it is
                  shown as still to come rather than guessed.
                </p>
              </div>
            </>
          )}
        </div>

        {/* ── Actions ────────────────────────────────────────── */}
        <footer className="sticky bottom-0 border-t border-gray-200 bg-white px-5 py-3 sm:px-6">
          <div className="flex flex-wrap items-center gap-2.5">
            <button
              type="button"
              onClick={checkIn}
              disabled={Boolean(checkedIn[row.id])}
              className="min-h-[42px] rounded-lg px-5 text-[14px] font-semibold text-white transition hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-45"
              style={{ backgroundColor: GREEN }}
            >
              {checkedIn[row.id]
                ? `Checked in at ${checkedIn[row.id]}`
                : "Check in patient ✓"}
            </button>
            <button
              type="button"
              onClick={() => toastFor("Clinical team notified ✓")}
              className="min-h-[42px] rounded-lg border border-gray-300 px-4 text-[13px] font-medium text-gray-700 transition hover:bg-gray-50"
            >
              Notify clinical team
            </button>
            <button
              type="button"
              onClick={() => navigate(demoLink(`/coverage/${row.id}`))}
              className="text-[13px] font-medium text-accord-green-900 underline-offset-2 hover:underline"
            >
              See full estimate →
            </button>
            <span className="ml-auto text-[10.5px] text-gray-400">
              <Printer size={11} className="mr-1 inline" />
              Check-in is remembered in this tab only
            </span>
          </div>
        </footer>
      </section>

      {toast && (
        <div
          role="status"
          className="fixed bottom-[76px] left-1/2 z-50 -translate-x-1/2 rounded-lg bg-slate-900 px-4 py-2.5 text-[12.5px] font-medium text-white shadow-lg lg:bottom-6"
        >
          {toast}
        </div>
      )}
    </div>
  );
}
