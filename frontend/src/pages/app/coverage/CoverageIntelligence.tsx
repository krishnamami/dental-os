import { useMemo, useState } from "react";
import { NavLink, useLocation, useNavigate } from "react-router-dom";
import { Search } from "lucide-react";

import RequestDocsModal from "../../../components/RequestDocsModal";
import { useAuth } from "../../../context/AuthContext";
import { useDemoLink } from "../../../hooks/useDemo";

/**
 * E-01 — the front desk's two views, chosen by the URL.
 *
 *   /coverage      my patients today
 *   /coverage/all  every pre-D at this practice
 *   /coverage/:id  one patient's coverage (CoverageDetail)
 *
 * ── Where the numbers come from ──────────────────────────────────────
 *
 * Everything below was read from the live database on 7 Aug 2026 —
 * patient names from `patients`, decisions from `pred_states`, tooth
 * numbers from `procedure_lines`, and the wave pills computed from the
 * CURRENT persona bundle using the same tone rule the rest of the app
 * uses (SignalCard.toneFor).
 *
 * It is static because there is no list endpoint: dental-os answers per
 * pre-D. Forty rows would be forty requests. When one exists, this
 * table is the thing that should read from it.
 *
 * The counts are SUWANEE'S, not the deployment's. The deployment holds
 * 50 pre-Ds across three practices; a Suwanee front desk can reach 40
 * of them and the API now enforces that. Printing 50 on their screen
 * would advertise records they cannot open.
 */

const BRAND_GREEN = "#0F4D37";
const BRAND_AMBER = "#F57F17";

// ── Tab 1 ────────────────────────────────────────────────────────────

interface QueuePatient {
  id: string;
  name: string;
  dot: string;
  payer: string;
  info: string;
  status: "NEEDS ACTION" | "READY";
  finding: string;
  insight: string;
  basedOn: string;
  queue: string;
}

const ACTION: QueuePatient[] = [
  {
    id: "PRED-SIM-DA-A01",
    name: "James Mitchell",
    dot: BRAND_AMBER,
    payer: "Delta Dental PPO",
    info: "Tooth #19 · Implant + graft + crown",
    status: "NEEDS ACTION",
    finding: "Annual max $25 remaining · D6065 downgrade to D2750",
    insight:
      "Verify patient understands $1,825 cost before treatment. Annual max nearly exhausted after this case.",
    basedOn: "eligibility response, fee schedule, Delta Dental coverage rules",
    queue: "Patient 1 of 5 · tooth #19",
  },
  {
    id: "PRED-SIM-DA-B04",
    name: "Carlos Rivera",
    dot: BRAND_AMBER,
    payer: "Delta Dental PPO",
    info: "Tooth #19 · Implant + bone graft",
    status: "NEEDS ACTION",
    finding: "Bundling conflict — narrative required before submission",
    insight:
      "D7953 and D6010 bundled under D.7.4. Patient pays $1,230. Alert Dr. Chinta before check-in.",
    basedOn: "coverage rules D.7.4, fee schedule, clinical note",
    queue: "Patient 2 of 5 · tooth #19",
  },
  {
    id: "PRED-SIM-DA-D04",
    name: "Linda Taylor",
    dot: BRAND_AMBER,
    payer: "Delta Dental PPO",
    info: "Tooth #8 · Crown",
    status: "NEEDS ACTION",
    finding: "D2740 all-ceramic downgrade to D2750 — verify with patient",
    insight:
      "Plan reimburses at the D2750 rate; the patient owes the difference. An upcoding signal is also open on this case — clear it before seating.",
    basedOn: "Delta Dental coverage policy, fee schedule, fraud integrity check",
    queue: "Patient 3 of 5 · tooth #8",
  },
];

const READY: QueuePatient[] = [
  {
    id: "PRED-SIM-DA-U01",
    name: "Robert Thompson",
    dot: BRAND_GREEN,
    payer: "Delta Dental PPO",
    info: "Adult prophylaxis",
    status: "READY",
    finding: "Coverage clean · no issues · patient pays $0",
    insight: "No action needed. Patient can check in.",
    basedOn: "eligibility response, coverage rules",
    queue: "Patient 4 of 5",
  },
  {
    id: "PRED-SIM-DA-U02",
    name: "Maria Santos",
    dot: BRAND_GREEN,
    payer: "Delta Dental PPO",
    info: "4 bitewing films",
    status: "READY",
    finding: "Coverage clean · 100% covered · patient pays $0",
    insight: "No action needed. Patient can check in.",
    basedOn: "eligibility response, coverage rules",
    queue: "Patient 5 of 5",
  },
];

// ── Tab 2 ────────────────────────────────────────────────────────────

type Pill = "Passed" | "Review" | "Blocked" | "Pending" | "Skipped";
type Status = "Approved" | "Pended" | "Denied";

interface PreDRow {
  id: string;
  name: string;
  tooth: string;
  payer: string;
  status: Status;
  waves: [Pill, Pill, Pill, Pill, Pill];
}

/**
 * Ten pre-Ds, every field measured.
 *
 * Note what the pills say and the brief did not: NO ROW IS CLEAN
 * ACROSS ALL FIVE WAVES, including the approved ones. Almost every
 * case carries ELIG_FREQUENCY_UNVERIFIED — the engine could not
 * confirm frequency limits because no prior treatment date is on file
 * — and that is a recommend-with-an-action, so it reads Review. An
 * "approved" pre-D with five green ticks would be a nicer screenshot
 * and a false one.
 */
const ALL_PREDS: PreDRow[] = [
  { id: "PRED-SIM-DA-A01", name: "James Mitchell", tooth: "#19", payer: "Delta Dental PPO", status: "Pended", waves: ["Review", "Review", "Review", "Review", "Review"] },
  { id: "PRED-SIM-DA-B04", name: "Carlos Rivera", tooth: "#19", payer: "Delta Dental PPO", status: "Pended", waves: ["Review", "Review", "Review", "Review", "Review"] },
  { id: "PRED-SIM-DA-D04", name: "Linda Taylor", tooth: "#8", payer: "Delta Dental PPO", status: "Approved", waves: ["Blocked", "Review", "Passed", "Blocked", "Passed"] },
  { id: "PRED-SIM-DA-U01", name: "Robert Thompson", tooth: "—", payer: "Delta Dental PPO", status: "Approved", waves: ["Review", "Review", "Passed", "Review", "Passed"] },
  { id: "PRED-SIM-DA-U02", name: "Maria Santos", tooth: "—", payer: "Delta Dental PPO", status: "Approved", waves: ["Review", "Review", "Review", "Review", "Passed"] },
  { id: "PRED-SIM-DA-B01", name: "Patricia Johnson", tooth: "#14", payer: "Delta Dental PPO", status: "Denied", waves: ["Blocked", "Review", "Review", "Review", "Review"] },
  { id: "PRED-SIM-DA-C01", name: "Robert Kim", tooth: "#19", payer: "Delta Dental PPO", status: "Pended", waves: ["Review", "Review", "Review", "Review", "Review"] },
  { id: "PRED-SIM-DA-A02", name: "Sandra Williams", tooth: "#3", payer: "Delta Dental PPO", status: "Approved", waves: ["Review", "Passed", "Passed", "Review", "Passed"] },
  { id: "PRED-SIM-DA-U03", name: "Kevin Lee", tooth: "#14", payer: "Cigna DPPO", status: "Approved", waves: ["Passed", "Review", "Review", "Review", "Passed"] },
  { id: "PRED-SIM-DA-A04", name: "Maria Rodriguez", tooth: "—", payer: "Delta Dental PPO", status: "Approved", waves: ["Review", "Review", "Passed", "Review", "Passed"] },
];

/** Suwanee's own totals, from pred_states. The deployment has 50
 *  across three practices; this practice can reach 40. */
const TOTALS = { total: 40, Approved: 13, Pended: 20, Denied: 7 };

const PILL_CLS: Record<Pill, string> = {
  Passed: "bg-green-100 text-green-800",
  Review: "bg-amber-100 text-amber-800",
  Blocked: "bg-red-100 text-red-800",
  Pending: "bg-gray-100 text-gray-400",
  Skipped: "bg-gray-100 text-gray-300",
};

const PILL_TEXT: Record<Pill, string> = {
  Passed: "Passed",
  Review: "Review",
  Blocked: "Blocked",
  Pending: "·",
  Skipped: "—",
};

const STATUS_CLS: Record<Status, string> = {
  Approved: "bg-green-100 text-green-800",
  Pended: "bg-amber-100 text-amber-800",
  Denied: "bg-red-100 text-red-800",
};

// Waves 1-5 as the engine runs them — NOT ...Clinical/Docs/Decision.
// The clinical reviewer is in wave 2; wave 3 is documentation.
const WAVE_COLS = ["Verify", "Coverage", "Documents", "Decision", "Appeal"];

// ── Shared bits ──────────────────────────────────────────────────────

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
  active?: boolean;
  onClick?: () => void;
}) {
  const body = (
    <>
      <p className="text-xs font-medium uppercase tracking-wide text-slate-500">
        {label}
      </p>
      <p className={`mt-1 text-3xl font-semibold ${tone}`}>{value}</p>
    </>
  );
  const cls = `rounded-xl border bg-white p-4 text-left ${
    active ? "border-accord-green-500 ring-1 ring-accord-green-500/30" : "border-gray-200"
  }`;
  return onClick ? (
    <button type="button" onClick={onClick} aria-pressed={active} className={`${cls} transition hover:border-gray-300`}>
      {body}
    </button>
  ) : (
    <div className={cls}>{body}</div>
  );
}

function firstNameOf(full: string): string {
  return full.replace(/^(Dr|Mr|Mrs|Ms)\.?\s+/i, "").split(/\s+/)[0] ?? "";
}

// ── Page ─────────────────────────────────────────────────────────────

export default function CoverageIntelligence() {
  const { pathname } = useLocation();
  const navigate = useNavigate();
  const demoLink = useDemoLink();
  const { effectiveUser, role } = useAuth();

  const isAll = pathname.startsWith("/coverage/all");
  // /checkin is the same "my patients today" list under its own
  // workflow. Front desk holds `checkin` but NOT `patient_financial`'s
  // second tab of every pre-D in the practice, so the tab strip is
  // hidden there rather than rendering a link that would bounce them.
  const isCheckIn = pathname.startsWith("/checkin");

  const [docsFor, setDocsFor] = useState<string | null>(null);
  const [toast, setToast] = useState("");
  const [filter, setFilter] = useState<Status | null>(null);
  const [query, setQuery] = useState("");

  function sendDocs(name: string) {
    setDocsFor(null);
    setToast(`Document request queued for ${name} ✓`);
    window.setTimeout(() => setToast(""), 3000);
  }

  const rows = useMemo(() => {
    const q = query.trim().toLowerCase();
    return ALL_PREDS.filter(
      (r) =>
        (!filter || r.status === filter) &&
        (!q ||
          r.name.toLowerCase().includes(q) ||
          r.id.toLowerCase().includes(q)),
    );
  }, [filter, query]);

  const firstName = firstNameOf(effectiveUser?.name ?? "");
  const tenantName = effectiveUser?.tenant_name ?? "Accord Dental";
  const roleLabel = (role ?? "").replace(/_/g, " ");

  const tabCls = (active: boolean) =>
    `-mb-px border-b-2 px-1 py-2.5 text-[13px] font-medium transition ${
      active
        ? "border-accord-green-900 text-accord-green-900"
        : "border-transparent text-slate-500 hover:text-slate-800"
    }`;

  return (
    <div>
      {/* ── Sub-tabs ───────────────────────────────────────────── */}
      {!isCheckIn && (
      <nav className="flex gap-5 border-b border-slate-200 bg-white px-5 sm:px-6">
        <NavLink to={demoLink("/coverage")} end className={() => tabCls(!isAll)}>
          My patients today
        </NavLink>
        <NavLink to={demoLink("/coverage/all")} className={() => tabCls(isAll)}>
          All pre-Ds
        </NavLink>
      </nav>
      )}

      {!isAll ? (
        /* ── Tab 1 ──────────────────────────────────────────── */
        <div className="mx-auto max-w-4xl px-5 py-6 sm:px-6">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div>
              <h1 className="text-[22px] font-semibold text-gray-900">
                Good morning{firstName ? `, ${firstName}` : ""}
              </h1>
              <p className="mt-0.5 text-[13px] capitalize text-slate-500">
                {roleLabel}
                {roleLabel && " · "}
                <span className="normal-case">{tenantName}</span>
              </p>
            </div>
            <span className="rounded-full bg-amber-50 px-3 py-1 text-[12px] font-semibold text-amber-700">
              {ACTION.length} need action
            </span>
          </div>

          <div className="mt-5 grid grid-cols-3 gap-3">
            <StatCard label="Need my action" value={ACTION.length} tone="text-red-600" />
            <StatCard label="Ready" value={READY.length} tone="text-green-600" />
            {/* Zero because none of the five is waiting on a document —
                counted from the queue, not asserted. */}
            <StatCard label="Missing docs" value={0} tone="text-amber-600" />
          </div>

          <Section title={`Need my action (${ACTION.length})`}>
            {ACTION.map((p) => (
              <PatientCard
                key={p.id}
                patient={p}
                onCheckIn={() => navigate(demoLink(`/coverage/${p.id}`))}
                onRequestDocs={() => setDocsFor(p.name)}
              />
            ))}
          </Section>

          <Section title={`Ready to check in (${READY.length})`}>
            {READY.map((p) => (
              <PatientCard
                key={p.id}
                patient={p}
                onCheckIn={() => navigate(demoLink(`/coverage/${p.id}`))}
                onRequestDocs={() => setDocsFor(p.name)}
              />
            ))}
          </Section>

          <p className="mt-5 text-[11px] leading-relaxed text-gray-400">
            Five patients, read from the API on 7 Aug 2026. There is no patient
            directory endpoint yet, so this list does not refresh — each
            patient&rsquo;s coverage does.
          </p>
        </div>
      ) : (
        /* ── Tab 2 ──────────────────────────────────────────── */
        <div className="mx-auto max-w-7xl px-5 py-6 sm:px-6">
          <h1 className="text-[22px] font-semibold text-gray-900">All pre-Ds</h1>
          <p className="mt-0.5 text-[13px] text-slate-500">
            {TOTALS.total} pre-Ds at {tenantName} across 5 decision waves
          </p>

          <div className="mt-5 grid grid-cols-2 gap-3 lg:grid-cols-4">
            <StatCard
              label="Total"
              value={TOTALS.total}
              tone="text-slate-900"
              active={filter === null}
              onClick={() => setFilter(null)}
            />
            {(["Approved", "Pended", "Denied"] as const).map((s) => (
              <StatCard
                key={s}
                label={s}
                value={TOTALS[s]}
                tone={
                  s === "Approved"
                    ? "text-green-600"
                    : s === "Pended"
                      ? "text-amber-600"
                      : "text-red-600"
                }
                active={filter === s}
                onClick={() => setFilter((f) => (f === s ? null : s))}
              />
            ))}
          </div>

          <div className="relative mt-4">
            <Search
              size={14}
              className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-gray-400"
            />
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search patient name or pre-D ID..."
              aria-label="Search patient name or pre-D ID"
              className="w-full max-w-sm rounded-lg border border-gray-300 py-2 pl-8 pr-3 text-[13px] text-gray-900 placeholder-gray-400 focus:border-accord-green-500 focus:outline-none focus:ring-1 focus:ring-accord-green-500"
            />
          </div>

          <div className="mt-3 flex flex-wrap items-center gap-1.5 text-[11px] text-slate-500">
            <span className="mr-1">Wave key:</span>
            {(["Passed", "Review", "Blocked", "Pending", "Skipped"] as Pill[]).map(
              (p) => (
                <span
                  key={p}
                  className={`rounded-full px-2 py-0.5 text-[10.5px] font-semibold ${PILL_CLS[p]}`}
                >
                  {p}
                </span>
              ),
            )}
          </div>

          <div className="mt-3 overflow-x-auto rounded-xl border border-gray-200 bg-white">
            <table className="w-full min-w-[980px] text-left">
              <thead className="border-b border-gray-200 bg-slate-50">
                <tr className="text-xs font-semibold uppercase tracking-wide text-slate-500">
                  <th className="px-4 py-2.5">Patient</th>
                  <th className="px-2 py-2.5">Tooth</th>
                  <th className="px-2 py-2.5">Payer</th>
                  <th className="px-2 py-2.5">Status</th>
                  {WAVE_COLS.map((c) => (
                    <th key={c} className="px-2 py-2.5">
                      {c}
                    </th>
                  ))}
                  <th className="px-4 py-2.5" />
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {rows.map((r) => (
                  <tr key={r.id} className="hover:bg-accord-green-50/40">
                    <td className="px-4 py-2.5">
                      <span className="block text-[13px] font-medium text-slate-800">
                        {r.name}
                      </span>
                      <span className="block font-mono text-xs text-slate-400">
                        {r.id}
                      </span>
                    </td>
                    <td className="px-2 py-2.5 text-[12.5px] text-slate-600">
                      {r.tooth}
                    </td>
                    <td className="px-2 py-2.5 text-[12.5px] text-slate-600">
                      {r.payer}
                    </td>
                    <td className="px-2 py-2.5">
                      <span
                        className={`rounded-full px-2 py-0.5 text-[11px] font-semibold ${STATUS_CLS[r.status]}`}
                      >
                        {r.status}
                      </span>
                    </td>
                    {r.waves.map((w, i) => (
                      <td key={WAVE_COLS[i]} className="px-2 py-2.5">
                        <span
                          className={`inline-block min-w-[54px] rounded-full px-2 py-0.5 text-center text-[10.5px] font-semibold ${PILL_CLS[w]}`}
                        >
                          {PILL_TEXT[w]}
                        </span>
                      </td>
                    ))}
                    <td className="px-4 py-2.5">
                      <div className="flex justify-end gap-1.5">
                        <button
                          type="button"
                          onClick={() => navigate(demoLink(`/workbench/${r.id}`))}
                          className="rounded-lg border border-gray-300 px-2.5 py-1 text-[11.5px] font-medium text-gray-700 transition hover:bg-gray-50"
                        >
                          Review
                        </button>
                        <button
                          type="button"
                          onClick={() => setDocsFor(r.name)}
                          className="rounded-lg border border-gray-300 px-2.5 py-1 text-[11.5px] font-medium text-gray-700 transition hover:bg-gray-50"
                        >
                          Request docs
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
                {rows.length === 0 && (
                  <tr>
                    <td
                      colSpan={10}
                      className="px-4 py-8 text-center text-[12.5px] text-slate-500"
                    >
                      No pre-D matches that filter.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>

          <p className="mt-3 text-[11px] leading-relaxed text-gray-400">
            Ten of {TOTALS.total} shown — names, decisions, teeth and wave
            states read from the database on 7 Aug 2026. There is no list
            endpoint, so the remaining {TOTALS.total - ALL_PREDS.length} are not
            loaded rather than hidden. The counts above are this
            practice&rsquo;s; the deployment holds 50 across three.
          </p>
        </div>
      )}

      {docsFor && (
        <RequestDocsModal
          patientName={docsFor}
          onClose={() => setDocsFor(null)}
          onSend={() => sendDocs(docsFor)}
        />
      )}

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

function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="mt-6">
      <h2 className="mb-3 text-sm font-semibold capitalize text-slate-700">
        {title}
      </h2>
      {children}
    </section>
  );
}

function PatientCard({
  patient,
  onCheckIn,
  onRequestDocs,
}: {
  patient: QueuePatient;
  onCheckIn: () => void;
  onRequestDocs: () => void;
}) {
  return (
    <article className="mb-3 rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div className="flex items-center gap-2">
          <span
            aria-hidden="true"
            className="h-2 w-2 flex-shrink-0 rounded-full"
            style={{ backgroundColor: patient.dot }}
          />
          <span className="font-medium text-slate-800">{patient.name}</span>
          <span className="text-[12.5px] text-slate-500">
            {patient.payer} · {patient.info}
          </span>
        </div>
        <span
          className={`rounded-full px-2 py-0.5 text-[10.5px] font-bold ${
            patient.status === "READY"
              ? "bg-green-100 text-green-800"
              : "bg-amber-100 text-amber-800"
          }`}
        >
          {patient.status}
        </span>
      </div>

      <p className="mt-2 text-sm text-slate-700">
        <span className="font-medium">Key finding:</span> {patient.finding}
      </p>
      {/* Green, and labelled "AI insight", because it is the one line on
          this card the engine did NOT produce — it is a reading of the
          findings, not a signal. Keeping it visually distinct is what
          stops it being quoted back as policy. */}
      <p className="mt-1 text-sm" style={{ color: BRAND_GREEN }}>
        <span className="font-medium">AI insight:</span> {patient.insight}
      </p>
      <p className="mt-1 text-sm text-slate-500">
        <span className="font-medium">Based on:</span> {patient.basedOn}
      </p>
      <p className="mt-1 text-sm text-slate-400">In queue: {patient.queue}</p>

      <div className="mt-3 flex flex-wrap gap-2">
        <button
          type="button"
          onClick={onCheckIn}
          className="rounded-lg px-4 py-1.5 text-sm font-semibold text-white transition hover:opacity-90"
          style={{ backgroundColor: BRAND_GREEN }}
        >
          Check-in
        </button>
        <button
          type="button"
          onClick={onRequestDocs}
          className="rounded-lg border border-gray-300 px-4 py-1.5 text-sm font-medium text-gray-700 transition hover:bg-gray-50"
        >
          Request docs
        </button>
      </div>
    </article>
  );
}
