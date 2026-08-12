import { AlertTriangle, Check } from "lucide-react";

import { useDecision } from "../../hooks/useApi";
import type { Decision, Signal } from "../../types/dental";
import { formatCurrencyShort } from "../../utils/format";

const DEMO_PRED_ID = "PRED-SIM-DA-A01";

/** The four signals this card tells its story with, in narrative order:
 *  two things that cleared, then the two that need a human. */
const SHOWN = [
  "ELIGIBILITY_VERIFIED",
  "CLINICAL_CRITERIA_MET",
  "COVERAGE_BUNDLING_CONFLICT",
  "DOC_NARRATIVE_MISSING",
] as const;

const GOOD = new Set<string>(["ELIGIBILITY_VERIFIED", "CLINICAL_CRITERIA_MET"]);

/**
 * Static fallback — a REAL response, trimmed.
 *
 * Copied from a live `GET /decisions/PRED-SIM-DA-A01` rather than
 * written to look good. A visitor must never see an error on the hero,
 * but they must also never see numbers the product cannot reproduce:
 * if the API is up, these exact figures come back from it.
 */
const FALLBACK: {
  patient: string;
  plan: string;
  signals: Array<Pick<Signal, "signal_code" | "finding" | "assignee" | "sla_hours">>;
} = {
  patient: "James Mitchell",
  plan: "Delta Dental PPO",
  signals: [
    {
      signal_code: "ELIGIBILITY_VERIFIED",
      finding:
        "Coverage active. $1,800.00 of the annual maximum remains and the implant waiting period is satisfied.",
      assignee: "front_desk",
      sla_hours: null as unknown as number,
    },
    {
      signal_code: "CLINICAL_CRITERIA_MET",
      finding:
        "Radiographic bone loss measures 4.2mm against a ≥3.0mm requirement for D6010 — margin +1.2mm.",
      assignee: "dentist",
      sla_hours: null as unknown as number,
    },
    {
      signal_code: "COVERAGE_BUNDLING_CONFLICT",
      finding:
        "D6010 and D7953 are bundled under Delta Dental policy D.7.4. Separable with documentation — roughly 65% are overturned when documented.",
      assignee: "billing",
      sla_hours: 24,
    },
    {
      signal_code: "DOC_NARRATIVE_MISSING",
      finding:
        "Clinical narrative required to separate D7953 from D6010 per D.7.4. Without it D7953 is denied as not separately payable.",
      assignee: "front_desk",
      sla_hours: 48,
    },
  ],
};

const PROCEDURES = [
  { code: "D6010", label: "implant" },
  { code: "D7953", label: "bone graft" },
  { code: "D6065", label: "crown" },
];

function pickSignals(data: Decision | undefined) {
  if (!data) return FALLBACK.signals;
  const byCode = new Map(data.all_signals.map((s) => [s.signal_code, s]));
  const picked = SHOWN.map((code) => byCode.get(code)).filter(
    (s): s is Signal => Boolean(s),
  );
  // If the corpus ever changes shape, fall back rather than render a
  // half-empty card.
  return picked.length === SHOWN.length ? picked : FALLBACK.signals;
}

function SignalRow({
  signal,
}: {
  signal: Pick<Signal, "signal_code" | "finding" | "assignee" | "sla_hours">;
}) {
  const good = GOOD.has(signal.signal_code);
  const assignee = signal.assignee?.replace(/_/g, " ");
  return (
    <li className="flex gap-3 px-4 py-3">
      <span
        className={`mt-0.5 flex h-5 w-5 flex-shrink-0 items-center justify-center rounded-full ${
          good
            ? "bg-accord-green-50 text-accord-green-700"
            : "bg-accord-amber-50 text-accord-amber-900"
        }`}
      >
        {good ? <Check size={12} strokeWidth={3} /> : <AlertTriangle size={11} />}
      </span>
      <div className="min-w-0">
        <p
          className={`font-mono text-[11px] font-semibold tracking-tight ${
            good ? "text-accord-green-700" : "text-accord-amber-900"
          }`}
        >
          {signal.signal_code}
        </p>
        <p className="mt-0.5 text-[12.5px] leading-snug text-gray-600">
          {signal.finding}
        </p>
        {!good && assignee && (
          <span className="mt-1.5 inline-block rounded border border-gray-200 bg-gray-50 px-1.5 py-0.5 text-[10.5px] font-medium capitalize text-gray-500">
            {assignee}
            {signal.sla_hours ? ` · ${signal.sla_hours}hr` : ""}
          </span>
        )}
      </div>
    </li>
  );
}

function Skeleton() {
  return (
    <ul className="animate-pulse divide-y divide-gray-100">
      {[0, 1, 2, 3].map((i) => (
        <li key={i} className="flex gap-3 px-4 py-3">
          <span className="mt-0.5 h-5 w-5 flex-shrink-0 rounded-full bg-gray-100" />
          <div className="w-full space-y-2">
            <div className="h-2.5 w-40 rounded bg-gray-100" />
            <div className="h-2 w-full rounded bg-gray-100" />
            <div className="h-2 w-3/4 rounded bg-gray-100" />
          </div>
        </li>
      ))}
    </ul>
  );
}

/**
 * The hero card. Shows Dr. Chinta's implant case with signals from the
 * live dental-os API, falling back to the same values baked in when the
 * API is unreachable — a marketing page must never show a stack trace,
 * and it must never show a number the product cannot produce.
 */
export default function WorkbenchCard() {
  const { data, isLoading, isError } = useDecision(DEMO_PRED_ID);

  const signals = pickSignals(data);
  const patient = data?.patient_name ?? FALLBACK.patient;
  const plan = data?.plan_name ?? FALLBACK.plan;
  const openCount = signals.filter((s) => !GOOD.has(s.signal_code)).length;

  return (
    <div className="overflow-hidden rounded-xl border border-gray-200 bg-white shadow-sm">
      <div className="flex items-center justify-between gap-3 border-b border-gray-200 bg-gray-50 px-4 py-2.5">
        <p className="truncate text-[12px] font-medium text-gray-600">
          Pre-D workbench · {patient}
        </p>
        <span className="flex-shrink-0 rounded-full bg-accord-amber-50 px-2.5 py-1 text-[11px] font-semibold text-accord-amber-900">
          Pended — {openCount} actions
        </span>
      </div>

      <div className="border-b border-gray-100 px-4 py-3.5">
        <p className="text-[13.5px] font-semibold text-gray-900">
          {patient} — {plan}
        </p>
        <p className="mt-0.5 text-[12px] text-gray-500">
          Tooth #19 · $5,550 case · $1,800 annual max remaining
        </p>
        <div className="mt-2.5 flex flex-wrap gap-1.5">
          {PROCEDURES.map((p) => (
            <span
              key={p.code}
              className="rounded border border-gray-200 bg-gray-50 px-2 py-1 text-[11px] text-gray-600"
            >
              <span className="font-mono font-semibold text-gray-700">
                {p.code}
              </span>{" "}
              {p.label}
            </span>
          ))}
        </div>
      </div>

      {isLoading ? (
        <Skeleton />
      ) : (
        <ul className="divide-y divide-gray-100">
          {signals.map((s) => (
            <SignalRow key={s.signal_code} signal={s} />
          ))}
        </ul>
      )}

      <div className="grid grid-cols-3 border-t border-gray-200 bg-gray-50">
        {[
          { label: "Provider charges", value: 5550, tone: "text-gray-900" },
          {
            label: "In-network savings",
            value: 1950,
            tone: "text-accord-green-700",
          },
          { label: "Patient pays", value: 1825, tone: "text-gray-900" },
        ].map((c) => (
          <div key={c.label} className="px-2.5 py-3 sm:px-4">
            <p className="text-[9.5px] uppercase leading-tight tracking-wide text-gray-500 sm:text-[10.5px]">
              {c.label}
            </p>
            <p className={`mt-0.5 text-[13px] font-semibold sm:text-[15px] ${c.tone}`}>
              {formatCurrencyShort(c.value)}
            </p>
          </div>
        ))}
      </div>

      <div className="flex items-center gap-2 border-t border-gray-200 px-4 py-3">
        <button
          type="button"
          className="rounded-lg border border-gray-300 px-3 py-1.5 text-[12.5px] font-medium text-gray-700 transition hover:bg-gray-50"
        >
          Add narrative
        </button>
        <button
          type="button"
          disabled
          title="Demo only — submission runs in the product"
          className="cursor-not-allowed rounded-lg bg-accord-green-900 px-3 py-1.5 text-[12.5px] font-medium text-white opacity-40"
        >
          Submit pre-D
        </button>
        <span className="ml-auto text-[10.5px] text-gray-400">
          {isError || !data ? "sample data" : "live"}
        </span>
      </div>
    </div>
  );
}
