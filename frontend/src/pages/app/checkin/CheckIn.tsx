import { useState } from "react";

import { ROLE_LABELS, useAuth } from "../../../context/AuthContext";

/**
 * F-01 — patient check-in. The front desk's whole screen.
 *
 * One column of cards, no split panel: a receptionist works down
 * today's list, not across a queue into a detail pane.
 *
 * ── What this page is NOT ────────────────────────────────────────────
 *
 * It is not a smaller workbench. Nothing here shows a signal code, a
 * wave number, a criteria score or a persona — a receptionist reading
 * "COVERAGE_BUNDLING_CONFLICT" learns nothing they can act on. Every
 * line below is the plain-English form of a finding, and the figures
 * in it were read from the API on 7 Aug 2026.
 *
 * ── What is real and what is not ─────────────────────────────────────
 *
 * Real: names, plans, procedures, every dollar figure, and which cases
 * need a pre-D. Verified against /decisions/{id} and /patient-summary.
 *
 * NOT real: the appointment times. There is no schedule in dental-os,
 * no appointments table, and no check-in state to persist to — so
 * check-in is remembered in this tab only, and the page says so at the
 * foot rather than implying the practice system was told.
 */

const GREEN = "#0F4D37";
const DOT_AMBER = "#d97706";
const DOT_GREEN = "#16a34a";

type Section = "action" | "ready";

interface Patient {
  id: string;
  name: string;
  dot: string;
  meta: string;
  badge: string;
  finding: string;
  suggest: string;
  basedOn: string;
  queue: string;
  sla: string | null;
  section: Section;
}

/** Ordered by appointment time, and `queue` counts in that same order —
 *  "patient 3 of 5" has to be the third one through the door. */
const PATIENTS: Patient[] = [
  {
    id: "PRED-SIM-DA-A01",
    name: "James Mitchell",
    dot: DOT_AMBER,
    meta: "Delta Dental PPO · Implant + crown · 9:00 AM",
    badge: "NEEDS ACTION",
    finding: "Annual max $25 remaining · D6065 downgrade to D2750",
    suggest:
      "Verify patient understands $1,825 cost before treatment. Annual max nearly exhausted — only $25 remaining after today's case.",
    basedOn: "eligibility response, fee schedule, Delta Dental rules",
    queue: "Patient 1 of 5 · appointment at 9:00 AM",
    sla: "⚠ Pre-D required before treatment",
    section: "action",
  },
  {
    id: "PRED-SIM-DA-D04",
    name: "Linda Taylor",
    dot: DOT_AMBER,
    meta: "Delta Dental PPO · Crown · 9:30 AM",
    badge: "NEEDS ACTION",
    finding: "D2740 crown paid at D2750 rate — patient owes difference",
    suggest:
      "Review the crown downgrade with the patient before seating. Delta pays $570 of the $1,190 allowed, at the D2750 rate.",
    basedOn: "coverage rules, fee schedule",
    queue: "Patient 2 of 5 · appointment at 9:30 AM",
    // D2740 IS pre-D required — the engine says so. Telling the desk
    // for James and not for Linda would be the gap this page exists
    // to close.
    sla: "⚠ Pre-D required before treatment",
    section: "action",
  },
  {
    id: "PRED-SIM-DA-U01",
    name: "Robert Thompson",
    dot: DOT_GREEN,
    meta: "Delta Dental PPO · Cleaning · 10:00 AM",
    badge: "READY",
    finding: "Coverage clean · no issues · patient pays $0",
    suggest: "No action needed. Patient can check in.",
    basedOn: "eligibility response, coverage rules",
    queue: "Patient 3 of 5 · appointment at 10:00 AM",
    sla: null,
    section: "ready",
  },
  {
    id: "PRED-SIM-DA-U02",
    name: "Maria Santos",
    dot: DOT_GREEN,
    meta: "Delta Dental PPO · Bitewings · 10:30 AM",
    badge: "READY",
    finding: "Coverage clean · 100% covered · patient pays $0",
    suggest: "No action needed. Patient can check in.",
    basedOn: "eligibility response, coverage rules",
    queue: "Patient 4 of 5 · appointment at 10:30 AM",
    sla: null,
    section: "ready",
  },
  {
    id: "PRED-SIM-DA-B04",
    name: "Carlos Rivera",
    dot: DOT_AMBER,
    meta: "Delta Dental PPO · Implant + graft · 11:00 AM",
    badge: "NEEDS ACTION",
    finding: "Bundling conflict — narrative needed before submission",
    suggest:
      "Alert Dr. Chinta: D7953 and D6010 are bundled under D.7.4. Patient pays $1,230.",
    basedOn: "coverage rules D.7.4, clinical note",
    queue: "Patient 5 of 5 · appointment at 11:00 AM",
    sla: "⚠ Pre-D required before treatment",
    section: "action",
  },
];

const BADGE_CLS: Record<string, string> = {
  "NEEDS ACTION": "bg-amber-100 text-amber-700",
  READY: "bg-green-100 text-green-700",
  "CHECKED IN": "bg-green-100 text-green-700",
};

function firstNameOf(full: string): string {
  return full.replace(/^(Dr|Mr|Mrs|Ms)\.?\s+/i, "").split(/\s+/)[0] ?? "";
}

function StatCard({
  label,
  value,
  tone,
}: {
  label: string;
  value: number;
  tone: string;
}) {
  return (
    <div className="rounded-xl border border-gray-200 bg-white p-5">
      <p className="text-xs uppercase tracking-wide text-slate-500">{label}</p>
      <p className={`mt-1 text-3xl font-semibold ${tone}`}>{value}</p>
    </div>
  );
}

function PatientCard({
  patient,
  checkedInAt,
  onCheckIn,
}: {
  patient: Patient;
  checkedInAt?: string;
  onCheckIn: () => void;
}) {
  const done = Boolean(checkedInAt);
  const badge = done ? "CHECKED IN" : patient.badge;
  return (
    <article className="mb-3 rounded-xl border border-gray-200 bg-white p-5">
      <div className="flex flex-wrap items-center gap-2">
        <span
          aria-hidden="true"
          className="h-2 w-2 flex-shrink-0 rounded-full"
          style={{ backgroundColor: done ? DOT_GREEN : patient.dot }}
        />
        <span className="text-sm font-medium text-slate-800">
          {patient.name}
        </span>
        <span className="text-sm text-slate-500">· {patient.meta}</span>
        <span
          className={`ml-auto rounded-full px-2.5 py-0.5 text-[11px] font-bold ${BADGE_CLS[badge]}`}
        >
          {badge}
        </span>
      </div>

      <p className="mt-2 pl-4 text-sm text-slate-700">
        <span className="font-medium">Key finding:</span> {patient.finding}
      </p>
      {/* Green and labelled "AI suggests" because it is the one line
          the engine did not produce — it is a reading of the findings,
          not a signal. Keeping it visually distinct is what stops it
          being repeated to a patient as though it were policy. */}
      <p className="mt-1 pl-4 text-sm" style={{ color: GREEN }}>
        <span className="font-medium">AI suggests:</span> &ldquo;
        {patient.suggest}&rdquo;
      </p>
      <p className="mt-1 pl-4 text-sm text-slate-400">
        <span className="font-medium">Based on:</span> {patient.basedOn}
      </p>
      <p className="mt-1 pl-4 text-sm text-amber-600">
        {patient.queue}
        {patient.sla ? ` · ${patient.sla}` : ""}
      </p>

      <div className="mt-3 flex flex-wrap gap-2 pl-4">
        <button
          type="button"
          onClick={onCheckIn}
          disabled={done}
          className="cursor-pointer rounded-lg border-none px-4 py-2 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-60"
          style={{ backgroundColor: GREEN }}
        >
          {done ? `Checked in at ${checkedInAt}` : "Check in patient ✓"}
        </button>
        <button
          type="button"
          onClick={() => window.print()}
          className="cursor-pointer rounded-lg border border-slate-200 bg-white px-4 py-2 text-sm text-slate-600 transition hover:bg-slate-50"
        >
          Print estimate
        </button>
      </div>
    </article>
  );
}

export default function CheckIn() {
  const { effectiveUser, role } = useAuth();

  const [checkedIn, setCheckedIn] = useState<Set<string>>(new Set());
  const [checkedInTime, setCheckedInTime] = useState<Record<string, string>>({});
  const [toast, setToast] = useState<string | null>(null);

  const open = PATIENTS.filter((p) => !checkedIn.has(p.id));
  const action = open.filter((p) => p.section === "action");
  const ready = open.filter((p) => p.section === "ready");
  const seen = PATIENTS.filter((p) => checkedIn.has(p.id));

  function handleCheckIn(id: string, name: string) {
    const time = new Date().toLocaleTimeString([], {
      hour: "2-digit",
      minute: "2-digit",
    });
    setCheckedIn((prev) => new Set([...prev, id]));
    setCheckedInTime((prev) => ({ ...prev, [id]: time }));
    setToast(`${name} checked in ✓`);
    window.setTimeout(() => setToast(null), 3000);
  }

  const firstName = firstNameOf(effectiveUser?.name ?? "");

  return (
    <div className="relative min-h-full pb-16">
      <div className="mx-auto max-w-3xl px-6 py-6">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h1 className="text-[22px] font-semibold text-gray-900">
              Good morning{firstName ? `, ${firstName}` : ""}
            </h1>
            <p className="mt-0.5 text-[13px] text-slate-500">
              {role ? ROLE_LABELS[role] : ""}
              {role && " · "}
              {effectiveUser?.tenant_name ?? "Accord Dental"}
            </p>
          </div>
          <span className="rounded-full bg-amber-50 px-3 py-1 text-[12px] font-semibold text-amber-700">
            {action.length} need action
          </span>
        </div>

        <div className="mt-5 grid grid-cols-3 gap-3">
          <StatCard
            label="Need my action"
            value={action.length}
            tone="text-red-600"
          />
          <StatCard
            label="Checked in"
            value={checkedIn.size}
            tone="text-green-600"
          />
          {/* Zero, and it stays zero: there is no "treatment complete"
              state anywhere in dental-os to count. */}
          <StatCard label="Done" value={0} tone="text-slate-400" />
        </div>

        {action.length > 0 && (
          <section className="mt-6">
            <h2 className="mb-3 text-sm font-semibold text-slate-600">
              NEED MY ACTION ({action.length})
            </h2>
            {action.map((p) => (
              <PatientCard
                key={p.id}
                patient={p}
                onCheckIn={() => handleCheckIn(p.id, p.name)}
              />
            ))}
          </section>
        )}

        {ready.length > 0 && (
          <section className="mt-6">
            <h2 className="mb-3 text-sm font-semibold text-slate-600">
              READY TO CHECK IN ({ready.length})
            </h2>
            {ready.map((p) => (
              <PatientCard
                key={p.id}
                patient={p}
                onCheckIn={() => handleCheckIn(p.id, p.name)}
              />
            ))}
          </section>
        )}

        {/* Checked-in patients stay on screen. Removing the card the
            moment you click is how a receptionist ends up asking "did
            that register?" three seconds after the toast has gone —
            and it is the only place the recorded time is visible. */}
        {seen.length > 0 && (
          <section className="mt-6">
            <h2 className="mb-3 text-sm font-semibold text-slate-600">
              CHECKED IN ({seen.length})
            </h2>
            {seen.map((p) => (
              <PatientCard
                key={p.id}
                patient={p}
                checkedInAt={checkedInTime[p.id]}
                onCheckIn={() => handleCheckIn(p.id, p.name)}
              />
            ))}
          </section>
        )}

        {open.length === 0 && (
          <p className="mt-6 rounded-xl border border-green-200 bg-green-50 p-4 text-[13px] text-green-800">
            Everyone is checked in ✓
          </p>
        )}

        <p className="mt-6 text-[11px] leading-relaxed text-gray-400">
          Five patients, read from the API on 7 Aug 2026. The appointment
          times are illustrative — there is no schedule in dental-os yet, and
          check-in is remembered in this tab only.
        </p>
      </div>

      {/* Anchored to this page rather than the viewport, so it cannot
          land under the mobile tab bar. */}
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
