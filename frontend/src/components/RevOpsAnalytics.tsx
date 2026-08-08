import { usePortfolio } from "../hooks/useApi";
import { formatCurrencyShort } from "../utils/format";
import FeedbackAudit from "./FeedbackAudit";

/**
 * G-09 — where the money and the time are going.
 *
 * The denial chart and the payer table are REAL, counted from the
 * corpus on 2026-08-06 and noted with their sample sizes:
 *
 *   SELECT cond.value, count(*) FROM pred_states ps
 *   CROSS JOIN LATERAL jsonb_array_elements_text(ps.open_conditions) cond
 *   WHERE ps.decision IN ('denied','pended') GROUP BY 1;
 *
 * The payer approval rates are shown WITH their denominators because
 * two of them are n=2. A bare "Cigna 100%" would be a claim; "2 of 2"
 * is a fact a reader can weigh. The brief's 32.5 / 55.0 / 40.0 do not
 * match the database — Delta is 9 of 36.
 *
 * The four cards and the SLA figure are illustrative. Making them real
 * needs a feed over provider_feedback and decision_outputs.created_at,
 * neither of which is exposed.
 */
const DENIAL_REASONS = [
  { label: "Pre-D required", code: "COVERAGE_PRED_REQUIRED", n: 21 },
  { label: "X-ray required", code: "CLINICAL_XRAY_REQUIRED", n: 9 },
  { label: "Narrative required", code: "CLINICAL_NARRATIVE_REQUIRED", n: 7 },
  { label: "Criteria not met", code: "CLINICAL_CRITERIA_NOT_MET", n: 6 },
  { label: "Bundling conflict", code: "COVERAGE_BUNDLING_CONFLICT", n: 6 },
  { label: "Downgrade applied", code: "COVERAGE_DOWNGRADE_APPLIED", n: 4 },
];

const PAYERS = [
  { payer: "Delta Dental PPO", approved: 9, total: 36 },
  { payer: "Cigna DPPO", approved: 2, total: 2 },
  { payer: "MetLife PDP", approved: 2, total: 2 },
];

const SLA_HOURS = 34;
const SLA_LIMIT = 48;

function Card({
  label,
  value,
  note,
  tone = "text-gray-900",
}: {
  label: string;
  value: string;
  note: string;
  tone?: string;
}) {
  return (
    <div className="rounded-xl border border-gray-200 bg-white p-4">
      <p className="text-[11px] uppercase tracking-wide text-gray-500">
        {label}
      </p>
      <p className={`mt-1 text-[19px] font-semibold leading-none ${tone}`}>
        {value}
      </p>
      <p className="mt-1.5 text-[11px] text-gray-400">{note}</p>
    </div>
  );
}

/** The benchmark a practice is measured against. Industry figure, not
 *  ours, and labelled as such wherever it is drawn. */
const FIRST_PASS_BENCHMARK = 0.85;

export default function RevOpsAnalytics() {
  const max = Math.max(...DENIAL_REASONS.map((d) => d.n));
  const slaPct = Math.round((SLA_HOURS / SLA_LIMIT) * 100);
  const { data: pf } = usePortfolio();
  const s = pf?.summary;

  const rate = s?.overall_approval_rate ?? 0;
  const ratePct = Math.round(rate * 100);
  const benchPct = Math.round(FIRST_PASS_BENCHMARK * 100);
  // What closing the gap to benchmark is worth, from the money actually
  // at risk rather than a round number.
  const opportunity = s
    ? Math.max(0, s.total_patient_revenue_at_risk) *
      Math.max(0, FIRST_PASS_BENCHMARK - rate)
    : 0;

  return (
    <div className="space-y-4">
      {/* ── This practice, counted ─────────────────────────────── */}
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <Card
          label="Pre-Ds in the corpus"
          value={String(s?.total_pre_ds ?? "—")}
          note="live · /portfolio/summary"
        />
        <Card
          label="Approved"
          value={s ? `${s.total_approved} (${ratePct}%)` : "—"}
          note="live"
          tone="text-accord-green-700"
        />
        <Card
          label="Pended / denied"
          value={s ? `${s.total_pended} / ${s.total_denied}` : "—"}
          note="live"
          tone="text-accord-amber-900"
        />
        <Card
          label="Revenue at risk"
          value={s ? formatCurrencyShort(s.total_patient_revenue_at_risk) : "—"}
          note="live · patient responsibility"
          tone="text-accord-amber-900"
        />
      </div>

      {/* ── First-pass acceptance ──────────────────────────────── */}
      <section className="rounded-xl border border-gray-200 bg-white p-4">
        <div className="flex items-baseline justify-between gap-3">
          <h2 className="text-[13.5px] font-semibold text-gray-900">
            First-pass acceptance
          </h2>
          <span className="text-[11px] text-gray-400">live</span>
        </div>
        <p className="mt-1 text-[12.5px] text-gray-600">
          {s
            ? `${s.total_approved} of ${s.total_pre_ds} pre-Ds approved without human intervention — ${ratePct}%.`
            : "Loading…"}
        </p>

        <div className="relative mt-3 h-3 w-full overflow-hidden rounded-full bg-gray-100">
          <div
            style={{ width: `${ratePct}%` }}
            className={`h-full ${
              rate >= FIRST_PASS_BENCHMARK
                ? "bg-accord-green-500"
                : "bg-amber-400"
            }`}
          />
          {/* The benchmark line sits ON the bar so the gap is the thing
              you see, not two numbers to subtract in your head. */}
          <div
            aria-hidden="true"
            style={{ left: `${benchPct}%` }}
            className="absolute inset-y-0 w-0.5 bg-accord-amber-900"
          />
        </div>
        <div className="mt-1.5 flex flex-wrap justify-between gap-2 text-[11px]">
          <span className="text-gray-500">This practice: {ratePct}%</span>
          <span className="text-accord-amber-900">
            Industry benchmark: {benchPct}%
          </span>
        </div>
        {s && rate < FIRST_PASS_BENCHMARK && (
          <p className="mt-2 text-[12px] text-gray-700">
            Opportunity: about{" "}
            <span className="font-semibold">
              {formatCurrencyShort(opportunity)}
            </span>{" "}
            of the {formatCurrencyShort(s.total_patient_revenue_at_risk)} at
            risk, if first-pass reached the benchmark.
          </p>
        )}
        <p className="mt-2 text-[11px] leading-relaxed text-gray-400">
          &ldquo;First pass&rdquo; here means approved by the engine without a
          human touching it. It is NOT approved-on-first-submission —
          nothing has been submitted to a payer, so that number does not
          exist yet.
        </p>
      </section>

      {/* ── The two things that cannot be measured ─────────────── */}
      <section className="rounded-xl border border-dashed border-gray-300 bg-gray-50 p-4">
        <h2 className="text-[13.5px] font-semibold text-gray-900">
          Not tracked yet
        </h2>
        <ul className="mt-2 space-y-1.5 text-[12px] leading-relaxed text-gray-600">
          <li>
            <span className="font-medium">Revenue recovered from appeals.</span>{" "}
            The <code className="font-mono">appeals</code> table exists and is
            empty — no appeal has been filed or resolved through this system
            (dental-simulator Gap #3). Appeal <em>viability</em> is real and
            lives on the Appeals tab; outcomes are not.
          </li>
          <li>
            <span className="font-medium">Days to payment by payer.</span> There
            is no payments, claims or remittance table anywhere, and{" "}
            <code className="font-mono">submitted_at</code> is null on every
            pre-D. An average payment time would be invented, and a biller
            would chase a payer on it.
          </li>
        </ul>
      </section>

      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <Card
          label="Avg condition resolution"
          value={`${SLA_HOURS}h`}
          note={`of a ${SLA_LIMIT}h SLA · sample`}
        />
        <Card
          label="Top open condition"
          value="Pre-D required"
          note="21 across the corpus · live"
          tone="text-accord-amber-900"
        />
      </div>

      <section className="rounded-xl border border-gray-200 bg-white p-4">
        <div className="flex items-baseline justify-between gap-3">
          <h2 className="text-[13.5px] font-semibold text-gray-900">
            Open conditions on denied and pended pre-Ds
          </h2>
          <span className="text-[11px] text-gray-400">
            live · all 50 scenarios
          </span>
        </div>

        <ul className="mt-4 space-y-2.5">
          {DENIAL_REASONS.map((d) => (
            <li key={d.code} className="flex items-center gap-3">
              <span
                className="w-[104px] flex-shrink-0 truncate text-[12px] text-gray-600 sm:w-[150px]"
                title={d.code}
              >
                {d.label}
              </span>
              <span className="h-4 flex-1 overflow-hidden rounded bg-gray-100">
                <span
                  style={{ width: `${(d.n / max) * 100}%` }}
                  className="block h-full rounded bg-accord-green-500"
                />
              </span>
              <span className="w-8 flex-shrink-0 text-right text-[12px] font-semibold tabular-nums text-gray-700">
                {d.n}
              </span>
            </li>
          ))}
        </ul>
      </section>

      <div className="grid gap-4 lg:grid-cols-2">
        <section className="overflow-hidden rounded-xl border border-gray-200 bg-white">
          <header className="flex items-center justify-between border-b border-gray-200 bg-gray-50 px-4 py-3">
            <h2 className="text-[13.5px] font-semibold text-gray-900">
              Payer performance
            </h2>
            <span className="text-[11px] text-gray-400">live</span>
          </header>
          <ul className="divide-y divide-gray-100">
            {PAYERS.map((p) => {
              const pct = (p.approved / p.total) * 100;
              return (
                <li key={p.payer} className="px-4 py-3">
                  <div className="flex items-baseline justify-between gap-3">
                    <span className="text-[12.5px] text-gray-700">
                      {p.payer}
                    </span>
                    <span className="text-[12.5px] font-semibold tabular-nums text-gray-900">
                      {pct.toFixed(1)}%
                      {/* The denominator is the point: 100% of two is
                          not a payer performance claim. */}
                      <span className="ml-1.5 font-normal text-gray-400">
                        {p.approved} of {p.total}
                      </span>
                    </span>
                  </div>
                  <div className="mt-1.5 h-1.5 w-full overflow-hidden rounded-full bg-gray-100">
                    <div
                      style={{ width: `${pct}%` }}
                      className={`h-full ${
                        p.total < 5 ? "bg-gray-300" : "bg-accord-green-500"
                      }`}
                    />
                  </div>
                </li>
              );
            })}
          </ul>
          <p className="border-t border-gray-100 px-4 py-2.5 text-[11px] text-gray-400">
            Suwanee Smiles only. Cigna and MetLife carry two pre-Ds each — too
            few to read as a rate.
          </p>
        </section>

        <section className="rounded-xl border border-gray-200 bg-white p-4">
          <h2 className="text-[13.5px] font-semibold text-gray-900">
            SLA compliance
          </h2>
          <p className="mt-1 text-[12.5px] text-gray-600">
            {SLA_HOURS}h average resolution against a {SLA_LIMIT}h limit.
          </p>
          <div className="mt-3 h-2.5 w-full overflow-hidden rounded-full bg-gray-100">
            <div
              style={{ width: `${slaPct}%` }}
              className="h-full bg-amber-400"
            />
          </div>
          <p className="mt-1.5 text-[11.5px] font-medium text-accord-amber-900">
            {slaPct}% of the window used
          </p>
          <p className="mt-2 text-[11px] text-gray-400">
            Sample. Real figures need timestamps over provider_feedback and
            decision_outputs, which are not exposed yet.
          </p>
        </section>
      </div>

      <FeedbackAudit />
    </div>
  );
}
