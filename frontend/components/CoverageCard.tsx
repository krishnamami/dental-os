import type { PatientSummary } from "../types/dental";
import { formatCurrency } from "../utils/format";

/**
 * E-02 — plan-level facts, above the per-code detail.
 *
 * Deductible shows what REMAINS BEFORE this case, from
 * `deductible_remaining_before`, not the amount this case consumes.
 * Those differ ($50 remaining vs $50 applied on DA-A01 only because the
 * case happens to use all of it), and a front desk quoting "deductible"
 * means the former.
 */
function Stat({
  label,
  value,
  tone = "text-gray-900",
  note,
}: {
  label: string;
  value: string;
  tone?: string;
  note?: string;
}) {
  return (
    <div className="rounded-xl border border-gray-200 bg-white p-3.5">
      <p className="text-[11px] uppercase tracking-wide text-gray-500">
        {label}
      </p>
      <p className={`mt-1 text-[18px] font-semibold leading-none ${tone}`}>
        {value}
      </p>
      {note && <p className="mt-1.5 text-[11px] text-gray-500">{note}</p>}
    </div>
  );
}

function Badge({
  children,
  tone,
}: {
  children: React.ReactNode;
  tone: "green" | "amber" | "gray";
}) {
  const cls = {
    green: "border-accord-green-100 bg-accord-green-50 text-accord-green-900",
    amber: "border-amber-200 bg-accord-amber-50 text-accord-amber-900",
    gray: "border-gray-200 bg-gray-50 text-gray-600",
  }[tone];
  return (
    <span
      className={`inline-flex items-center rounded-full border px-2.5 py-0.5 text-[11.5px] font-medium ${cls}`}
    >
      {children}
    </span>
  );
}

export default function CoverageCard({ summary }: { summary: PatientSummary }) {
  const maxAfter = summary.summary.annual_max_remaining_after;
  const preDCodes = summary.procedures
    .filter((p) => p.pre_d_required)
    .map((p) => p.cdt_code);
  const anyEstimated = summary.procedures.some((p) => p.rate_is_estimated);

  return (
    <section>
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <Stat
          label="Annual max remaining"
          value={formatCurrency(summary.annual_max_remaining_before)}
          note={`${formatCurrency(maxAfter)} after this case`}
          tone={maxAfter < 500 ? "text-accord-amber-900" : "text-gray-900"}
        />
        <Stat
          label="Deductible remaining"
          value={formatCurrency(summary.deductible_remaining_before)}
          note={
            summary.summary.total_deductible_applied > 0
              ? `${formatCurrency(summary.summary.total_deductible_applied)} applied here`
              : "none applied to this case"
          }
        />
        <Stat
          label="Payer"
          value={summary.plan_name}
          note={summary.payer_id.replace(/_/g, " ")}
        />
        <Stat label="Network status" value="In-network" note={summary.state} />
      </div>

      <div className="mt-3 flex flex-wrap gap-1.5">
        <Badge tone="green">{summary.plan_name}</Badge>
        <Badge tone="green">In-network</Badge>
        {preDCodes.length > 0 && (
          <Badge tone="amber">
            Pre-D required · {preDCodes.join(", ")}
          </Badge>
        )}
        {anyEstimated && (
          <Badge tone="gray">Rates estimated</Badge>
        )}
      </div>
    </section>
  );
}
