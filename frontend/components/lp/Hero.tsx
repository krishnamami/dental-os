import { useEffect, useRef, useState } from "react";
import { Play } from "lucide-react";

import { useDemoModal } from "../../hooks/useDemoModal";
import { Eyebrow } from "./primitives";

/**
 * The hero: three real pre-Ds cycling through a miniature workbench.
 *
 * ── Where these numbers come from ────────────────────────────────────
 *
 * Every figure below was read from the live API on 6 Aug 2026 —
 * GET /decisions/{id}, /patient-summary and /appeal — and copied
 * verbatim. Findings are the engine's own prose, not a paraphrase.
 *
 * That matters more here than anywhere else in the product: this is the
 * first thing a dentist sees, and a demo that quotes a number the
 * product cannot reproduce is worse than no demo. The panel is labelled
 * "sample data" because it does not re-fetch, NOT because it is
 * invented. If a value here ever disagrees with the API, this file is
 * stale and is the thing to fix.
 *
 * Deliberately static rather than live: three cases × three endpoints
 * is nine requests to render a marketing panel that nobody interacts
 * with. WorkbenchCard (still in the tree, now unused by this page) is
 * the live version if that trade ever flips.
 */

const BRAND = {
  dark: "#0F4D37", // buttons, active tabs, cleared signals
  nearblack: "#0B1220", // headline
  amber: "#ba7517", // needs a human
  red: "#C62828", // hard block
} as const;

interface Signal {
  icon: string;
  color: string;
  code: string;
  text: string;
  tag?: string;
}

interface Pred {
  id: string;
  patient: string;
  sub: string;
  status: string;
  statusCls: string;
  dotColor: string;
  summary: string;
  decision: Signal[];
  evidence: Array<{ doc: string; sub: string; pct: string }>;
  conditions: Array<{ code: string; sla: string }>;
  audit: Array<{ time: string; event: string; mode: string }>;
  charges: string;
  savings: string;
  /** NOT `patient` — that key already holds the person's name, and a
   *  second one silently overwrote it with a dollar amount. */
  patientPays: string;
}

const PREDS: Pred[] = [
  {
    id: "DA-A01",
    patient: "James Mitchell",
    sub: "$5,550 · Delta Dental PPO",
    status: "Pended",
    statusCls: "bg-amber-50 text-amber-700",
    dotColor: BRAND.amber,
    summary: "Bundling conflict · D.7.4",
    decision: [
      {
        icon: "✓",
        color: BRAND.dark,
        code: "ELIGIBILITY_VERIFIED",
        text: "Coverage active. $1,800.00 of the annual maximum remains and the implant waiting period is satisfied.",
      },
      {
        icon: "✓",
        color: BRAND.dark,
        code: "CLINICAL_CRITERIA_MET",
        text: "Radiographic bone loss measures 4.2mm against a ≥3.0mm requirement for D6010 — margin +1.2mm. Criteria score 0.85 (High confidence).",
      },
      {
        icon: "⚑",
        color: BRAND.amber,
        code: "COVERAGE_BUNDLING_CONFLICT",
        text: "D6010 and D7953 are bundled under delta_dental policy D.7.4. This is SEPARABLE with documentation — submit as-is and D7953 will be denied as not separately payable.",
        tag: "Billing · 24hr",
      },
      {
        icon: "⚑",
        color: BRAND.amber,
        code: "DOC_NARRATIVE_MISSING",
        text: "Clinical narrative required to separate D7953 from D6010 per D.7.4. Without it D7953 is denied as not separately payable — with it, roughly 65% are overturned.",
        tag: "Front desk · 48hr",
      },
    ],
    evidence: [
      { doc: "PA X-ray — tooth #19", sub: "bone_loss_mm = 4.2 · confidence 100%", pct: "100%" },
      { doc: "Clinical note", sub: "narrative present · not independent", pct: "95%" },
      { doc: "Eligibility — X12 271", sub: "$1,800 remaining · deductible met", pct: "100%" },
    ],
    conditions: [
      { code: "COVERAGE_BUNDLING_CONFLICT", sla: "Billing · 24h" },
      { code: "DOC_NARRATIVE_MISSING", sla: "Front desk · 48h" },
    ],
    audit: [
      { time: "10/15 · 9:00 AM", event: "Pre-D received · 3 procedures · DA-A01", mode: "wave 1 started" },
      { time: "10/15 · 9:01 AM", event: "Eligibility verified · $1,800 remaining", mode: "recommend · eligibility_analyst" },
      { time: "10/15 · 9:01 AM", event: "Clinical criteria met · 4.2mm ≥ 3.0mm", mode: "recommend · clinical_reviewer" },
      { time: "10/15 · 9:02 AM", event: "Bundling conflict detected · D.7.4", mode: "recommend · coverage_analyst" },
      { time: "10/15 · 9:03 AM", event: "Pre-D pended · 2 conditions open", mode: "human_approval · pre_d_assessment" },
    ],
    charges: "$5,550",
    savings: "$1,950",
    patientPays: "$1,825",
  },
  {
    id: "DA-B04",
    patient: "Carlos Rivera",
    sub: "$3,750 · Delta Dental PPO",
    status: "Pended",
    statusCls: "bg-amber-50 text-amber-700",
    dotColor: BRAND.amber,
    summary: "Appeal viable · 65% overturn",
    decision: [
      {
        icon: "✓",
        color: BRAND.dark,
        code: "ELIGIBILITY_VERIFIED",
        text: "Coverage active. $1,800.00 of the annual maximum remains and the implant waiting period is satisfied.",
      },
      {
        icon: "⚑",
        color: BRAND.amber,
        code: "COVERAGE_BUNDLING_CONFLICT",
        text: "D6010 and D7953 are bundled under delta_dental policy D.7.4. Separable with documentation — without it D7953 is denied as not separately payable.",
      },
      {
        icon: "⚑",
        color: BRAND.amber,
        code: "APPEAL_VIABLE",
        text: "Appeal is viable — roughly 65% of these are overturned when properly documented. Unbundle under the payer's own separation criteria.",
        tag: "Rev ops · needs a signature",
      },
    ],
    evidence: [
      { doc: "PA X-ray — tooth #19", sub: "bone_loss_mm = 4.2 · confidence 100%", pct: "100%" },
      { doc: "Clinical note", sub: "narrative present on file", pct: "92%" },
    ],
    conditions: [{ code: "APPEAL_VIABLE", sla: "Rev ops · signature" }],
    audit: [
      { time: "10/16 · 10:00 AM", event: "Pre-D received · 2 procedures", mode: "wave 1 started" },
      { time: "10/16 · 10:01 AM", event: "Bundling conflict — D.7.4", mode: "recommend · coverage_analyst" },
      { time: "10/16 · 10:02 AM", event: "Appeal viable · 65% overturn rate", mode: "human_approval · appeal_specialist" },
    ],
    charges: "$3,750",
    savings: "$1,340",
    patientPays: "$1,230",
  },
  {
    id: "TB-B01",
    patient: "Robert Martinez",
    sub: "$2,800 · Aetna DMO · Tampa FL",
    status: "Denied",
    statusCls: "bg-red-50 text-red-700",
    dotColor: BRAND.red,
    summary: "Hard exclusion · implants",
    decision: [
      {
        icon: "✓",
        color: BRAND.dark,
        code: "CLINICAL_CRITERIA_MET",
        text: "Radiographic bone loss measures 4.2mm against a ≥3.0mm requirement for D6010 — margin +1.2mm. Criteria score 0.9 (High confidence).",
      },
      {
        icon: "✗",
        color: BRAND.red,
        code: "ELIG_IMPLANTS_NOT_COVERED",
        text: "This plan excludes implant services. D6010 will not be paid and the patient is responsible for the full amount. A hard plan exclusion is a contract term, not a coverage dispute — there is nothing to appeal.",
        tag: "Front desk · needs a signature",
      },
    ],
    evidence: [
      { doc: "Eligibility — X12 271", sub: "implants excluded · plan document confirmed", pct: "100%" },
      { doc: "Aetna DMO benefit schedule", sub: "D6010 not covered", pct: "100%" },
    ],
    conditions: [{ code: "ELIG_IMPLANTS_NOT_COVERED", sla: "Front desk · signature" }],
    audit: [
      { time: "10/17 · 11:00 AM", event: "Pre-D received · D6010 implant", mode: "wave 1 started" },
      { time: "10/17 · 11:01 AM", event: "Implants excluded — hard plan denial", mode: "human_approval · eligibility_analyst" },
      { time: "10/17 · 11:02 AM", event: "Not appealable · plan exclusion", mode: "recommend · appeal_specialist" },
    ],
    charges: "$2,800",
    savings: "$924",
    patientPays: "$1,876",
  },
];

const TABS = ["Decision", "Evidence", "Conditions", "Audit"] as const;

const TRUST = [
  { icon: "✓", label: "Bundling conflicts caught before submission" },
  { icon: "✓", label: "Appeal letters in 90 seconds" },
  { icon: "✓", label: "Patient cost calculated exactly" },
  { icon: "✓", label: "Every decision traceable to policy" },
];

const STATS = [
  { value: "Automated", label: "Overnight eligibility check" },
  { value: "65%", label: "Appeal overturn rate with documentation" },
  { value: "45%", label: "Industry bone graft denial rate" },
  { value: "14 flags", label: "Submission readiness score per pre-D" },
];

export default function Hero() {
  const modal = useDemoModal();
  const [activePred, setActivePred] = useState(0);
  const [activeTab, setActiveTab] = useState(0);
  const [seeActive, setSeeActive] = useState(false);
  const tabTimer = useRef<ReturnType<typeof setInterval> | null>(null);
  const predTimer = useRef<ReturnType<typeof setInterval> | null>(null);
  const pred = PREDS[activePred];

  /**
   * Both timers restart on click rather than running free.
   *
   * Without the reset, choosing a case can be undone a hundred
   * milliseconds later by a tick that was already in flight — the
   * panel jumps away from what the visitor just asked to see, which
   * reads as broken rather than as an animation.
   */
  function resetTabTimer(start: number) {
    if (tabTimer.current) clearInterval(tabTimer.current);
    let cur = start;
    tabTimer.current = setInterval(() => {
      cur = (cur + 1) % TABS.length;
      setActiveTab(cur);
    }, 4500);
  }

  function resetPredTimer(start: number) {
    if (predTimer.current) clearInterval(predTimer.current);
    let cur = start;
    predTimer.current = setInterval(() => {
      cur = (cur + 1) % PREDS.length;
      setActivePred(cur);
      setActiveTab(0);
    }, 16000);
  }

  function pickPred(n: number) {
    setActivePred(n);
    setActiveTab(0);
    resetPredTimer(n);
    resetTabTimer(0);
  }

  function pickTab(n: number) {
    setActiveTab(n);
    resetTabTimer(n);
  }

  useEffect(() => {
    resetTabTimer(0);
    resetPredTimer(0);
    return () => {
      if (tabTimer.current) clearInterval(tabTimer.current);
      if (predTimer.current) clearInterval(predTimer.current);
    };
    // Mount only — the timers own their own cursors from here.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <section id="top">
      <div className="mx-auto grid max-w-[1200px] items-center gap-12 px-6 pb-12 pt-16 lg:grid-cols-[52fr_48fr]">
        {/* ── Left: the pitch ──────────────────────────────── */}
        <div>
          <Eyebrow>Dental decision intelligence</Eyebrow>

          <h1
            className="mb-5 text-[38px] font-bold leading-[1.08] tracking-[-0.03em] sm:text-[48px] lg:text-[52px]"
            style={{ color: BRAND.nearblack }}
          >
            Every pre-D denial.
            <br />
            <span style={{ color: BRAND.dark }}>
              Caught.
              <br />
              Before you submit.
            </span>
          </h1>

          <p className="mt-5 max-w-lg text-lg leading-relaxed text-slate-500">
            AccordDental reads your payer rules, checks your
            clinical docs, and flags every bundling conflict
            before the pre-D leaves your practice.
          </p>

          <div className="mt-7 flex flex-col gap-3 sm:flex-row sm:flex-wrap">
            <button
              type="button"
              onClick={modal.open}
              className="min-h-[44px] rounded-lg px-5 py-2.5 text-sm font-semibold text-white transition hover:opacity-90"
              style={{ backgroundColor: BRAND.dark }}
            >
              Request a demo
            </button>
            {/* Toggles its own state AND goes somewhere. A button whose
                only effect is to recolour itself is a dead control. */}
            <a
              href="#what-if"
              onClick={() => setSeeActive(true)}
              className="inline-flex min-h-[44px] items-center justify-center gap-2 rounded-lg border px-5 py-2.5 text-sm font-semibold transition"
              style={{
                borderColor: seeActive ? BRAND.dark : "#e2e8f0",
                backgroundColor: seeActive ? BRAND.dark : "white",
                color: seeActive ? "white" : "#334155",
              }}
            >
              <Play size={13} fill="currentColor" />
              See it in action
            </a>
          </div>

          {/* Benefit statements, not compliance claims — each one is
              something the product demonstrably does on this page. */}
          <ul className="mt-6 flex flex-wrap gap-x-6 gap-y-2 text-sm text-slate-400">
            {TRUST.map((t) => (
              <li key={t.label} className="flex items-center gap-1.5">
                <span aria-hidden="true">{t.icon}</span>
                {t.label}
              </li>
            ))}
          </ul>

          <dl className="mt-10 grid grid-cols-2 gap-x-6 gap-y-5 border-t border-gray-200 pt-7 sm:grid-cols-4">
            {STATS.map((s) => (
              <div key={s.label}>
                <dt className="sr-only">{s.label}</dt>
                <dd>
                  <span className="block text-[17px] font-semibold leading-tight text-gray-900">
                    {s.value}
                  </span>
                  <span className="mt-1 block text-[12px] leading-snug text-gray-500">
                    {s.label}
                  </span>
                </dd>
              </div>
            ))}
          </dl>
        </div>

        {/* ── Right: the workbench ─────────────────────────── */}
        <div
          className="overflow-hidden rounded-xl border text-left"
          style={{ borderColor: "rgba(0,0,0,0.1)" }}
        >
          {/* Title bar */}
          <div
            className="flex items-center gap-1.5 border-b px-3 py-2"
            style={{ backgroundColor: "#0c1710", borderColor: "#1e3020" }}
          >
            <span className="h-2.5 w-2.5 rounded-full bg-red-400" />
            <span className="h-2.5 w-2.5 rounded-full bg-amber-400" />
            <span className="h-2.5 w-2.5 rounded-full bg-green-400" />
            <span
              className="ml-1.5 text-[11px] font-semibold"
              style={{ color: "#5aa87a", letterSpacing: "0.04em" }}
            >
              accord · pre-D workbench
            </span>
            <span className="ml-auto text-[10px]" style={{ color: "#3d6b4f" }}>
              Suwanee Smiles
            </span>
          </div>

          <div
            className="grid bg-white"
            style={{ gridTemplateColumns: "175px 1fr" }}
          >
            {/* Queue rail */}
            <div className="flex flex-col border-r border-slate-100">
              <div className="border-b border-slate-100 px-2.5 py-2">
                <p className="mb-0.5 text-[11px] font-semibold text-slate-700">
                  Good morning, Dr. Chinta
                </p>
                <p className="text-[9px] text-slate-400">
                  Suwanee Smiles · 3 need action
                </p>
              </div>

              <div className="flex border-b border-slate-100">
                {[
                  ["3", "Action", "#e24b4a"],
                  ["5", "Pending", BRAND.amber],
                  ["9", "Done", "#3b6d11"],
                ].map(([n, l, c]) => (
                  <div
                    key={l}
                    className="flex-1 border-r border-slate-100 px-2 py-1.5 last:border-r-0"
                  >
                    <div className="text-sm font-semibold" style={{ color: c }}>
                      {n}
                    </div>
                    <div className="text-[8px] uppercase tracking-wide text-slate-400">
                      {l}
                    </div>
                  </div>
                ))}
              </div>

              <div className="px-2.5 pb-1 pt-2 text-[8px] font-semibold uppercase tracking-widest text-slate-400">
                Need my action
              </div>

              {PREDS.map((p, i) => (
                <button
                  key={p.id}
                  type="button"
                  onClick={() => pickPred(i)}
                  aria-current={activePred === i ? "true" : undefined}
                  className="block w-full border-b border-slate-100 px-2.5 py-2 text-left"
                  style={{
                    backgroundColor: activePred === i ? "#f0f7f2" : undefined,
                    borderLeft:
                      activePred === i
                        ? `2px solid ${BRAND.dark}`
                        : "2px solid transparent",
                  }}
                >
                  <span className="mb-0.5 flex items-center gap-1">
                    <span
                      className="h-1.5 w-1.5 flex-shrink-0 rounded-full"
                      style={{ backgroundColor: p.dotColor }}
                    />
                    <span className="text-[11px] font-semibold text-slate-700">
                      {p.patient}
                    </span>
                    <span
                      className={`ml-auto rounded-full px-1.5 py-0.5 text-[8px] font-bold ${p.statusCls}`}
                    >
                      {p.status}
                    </span>
                  </span>
                  <span className="ml-2.5 block text-[9px] leading-snug text-slate-500">
                    {p.summary}
                  </span>
                  <span className="ml-2.5 mt-0.5 block text-[9px] text-slate-400">
                    {p.sub}
                  </span>
                </button>
              ))}
            </div>

            {/* Detail */}
            <div className="flex flex-col">
              <div className="flex items-center justify-between border-b border-slate-100 px-3 py-2">
                <div>
                  <p className="text-[12px] font-semibold text-slate-800">
                    {pred.patient}
                  </p>
                  <p className="text-[9px] text-slate-400">{pred.sub}</p>
                </div>
                <span
                  className={`rounded-full px-2 py-0.5 text-[9px] font-bold ${pred.statusCls}`}
                >
                  {pred.status}
                </span>
              </div>

              <div className="flex border-b border-slate-100">
                {TABS.map((tab, i) => (
                  <button
                    key={tab}
                    type="button"
                    onClick={() => pickTab(i)}
                    className="mr-0.5 border-b-2 px-2 py-1.5 text-[10px] transition-colors"
                    style={{
                      borderColor: activeTab === i ? BRAND.dark : "transparent",
                      color: activeTab === i ? BRAND.dark : "#94a3b8",
                      fontWeight: activeTab === i ? 600 : 400,
                    }}
                  >
                    {tab}
                  </button>
                ))}
              </div>

              {/* key remounts the panel, which is what replays the fade. */}
              <div
                className="max-h-[300px] flex-1 animate-fade-in overflow-y-auto p-3"
                key={`${activePred}-${activeTab}`}
              >
                {activeTab === 0 && (
                  <div className="space-y-2">
                    {pred.decision.map((s) => (
                      <div key={s.code} className="flex gap-2">
                        <span
                          className="mt-0.5 flex-shrink-0 text-[11px]"
                          style={{ color: s.color }}
                        >
                          {s.icon}
                        </span>
                        <div>
                          <p
                            className="text-[9px] font-bold uppercase tracking-wide"
                            style={{ color: s.color }}
                          >
                            {s.code}
                          </p>
                          <p className="mt-0.5 text-[10px] leading-snug text-slate-600">
                            {s.text}
                          </p>
                          {s.tag && (
                            <span className="mt-1 inline-block rounded bg-slate-100 px-1.5 py-0.5 text-[8px] text-slate-500">
                              {s.tag}
                            </span>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                )}

                {activeTab === 1 && (
                  <div>
                    <p className="mb-2 text-[8px] font-semibold uppercase tracking-widest text-slate-400">
                      Source documents
                    </p>
                    {pred.evidence.map((e) => (
                      <div
                        key={e.doc}
                        className="flex items-center justify-between border-b border-slate-100 py-1.5 last:border-0"
                      >
                        <div>
                          <p className="text-[10px] font-medium text-slate-700">
                            {e.doc}
                          </p>
                          <p className="text-[9px] text-slate-400">{e.sub}</p>
                        </div>
                        <span
                          className="text-[10px] font-bold"
                          style={{ color: BRAND.dark }}
                        >
                          {e.pct}
                        </span>
                      </div>
                    ))}
                    <p className="mt-2 text-[8px] text-slate-400">
                      Every extracted value carries its source and confidence.
                    </p>
                  </div>
                )}

                {activeTab === 2 && (
                  <div>
                    {pred.conditions.length === 0 ? (
                      <p className="py-4 text-center text-[10px] text-slate-400">
                        ✓ No open conditions
                      </p>
                    ) : (
                      pred.conditions.map((c) => (
                        <div
                          key={c.code}
                          className="flex items-center justify-between border-b border-slate-100 py-1.5 last:border-0"
                        >
                          <div>
                            <p className="text-[9px] font-bold uppercase text-amber-700">
                              {c.code.replace(/_/g, " ")}
                            </p>
                            <p className="text-[9px] text-slate-400">{c.sla}</p>
                          </div>
                          <span className="rounded bg-amber-50 px-1.5 py-0.5 text-[8px] text-amber-700">
                            Open
                          </span>
                        </div>
                      ))
                    )}
                  </div>
                )}

                {activeTab === 3 && (
                  <div>
                    <p className="mb-2 text-[8px] font-semibold uppercase tracking-widest text-slate-400">
                      Audit trail — append only
                    </p>
                    {pred.audit.map((a) => (
                      <div key={a.event} className="mb-2 flex gap-2">
                        <p className="w-24 flex-shrink-0 pt-0.5 text-[8px] text-slate-400">
                          {a.time}
                        </p>
                        <div>
                          <p className="text-[10px] font-medium text-slate-700">
                            {a.event}
                          </p>
                          <p className="text-[9px] text-slate-400">
                            Mode: {a.mode}
                          </p>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              <div
                className="grid grid-cols-3 border-t border-slate-100 px-3 py-2"
                style={{ backgroundColor: "#F5F7FA" }}
              >
                {[
                  ["Provider charges", pred.charges, undefined],
                  ["In-network savings", pred.savings, BRAND.dark],
                  ["Patient pays", pred.patientPays, undefined],
                ].map(([label, val, color]) => (
                  <div key={String(label)}>
                    <p className="text-[7px] uppercase tracking-wide text-slate-400">
                      {label}
                    </p>
                    <p
                      className="text-[11px] font-bold"
                      style={{ color: color ?? "#1e293b" }}
                    >
                      {val}
                    </p>
                  </div>
                ))}
              </div>

              <div className="flex gap-2 border-t border-slate-100 px-3 py-2">
                <button
                  type="button"
                  className="rounded px-2 py-1 text-[9px] font-semibold text-white"
                  style={{ backgroundColor: BRAND.dark }}
                >
                  Submit pre-D
                </button>
                <button
                  type="button"
                  className="rounded border border-slate-200 px-2 py-1 text-[9px] text-slate-600"
                >
                  Add narrative
                </button>
                <button
                  type="button"
                  className="rounded border border-slate-200 px-2 py-1 text-[9px] text-slate-600"
                >
                  Appeal
                </button>
                <span className="ml-auto self-center text-[8px] text-slate-300">
                  sample data
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
