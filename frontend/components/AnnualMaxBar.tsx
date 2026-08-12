import { AlertTriangle } from "lucide-react";

import { formatCurrency } from "../utils/format";

/**
 * E-05 — where the annual maximum goes.
 *
 * The bar spans the benefit STILL AVAILABLE when the patient walks in,
 * split into what this case consumes and what is left afterwards. That
 * gap is the whole point: a patient told "you have $1,800 left" can
 * still walk out with $25, and nobody mentioned it.
 *
 * ── Why there is no "already used" segment ───────────────────────────
 * patient-summary returns `annual_max_remaining_before` and
 * `annual_max_remaining_after`, and NOT the plan's annual maximum.
 * Without the maximum, "used" cannot be computed — only guessed, by
 * assuming a $2,000 PPO. That assumption is wrong for MetLife, Humana
 * and Aetna, all of which cap at $1,500, so it would quietly overstate
 * consumption by $500 for a third of the payers in the catalogue.
 *
 * Pass `planMax` when a caller genuinely knows it (the eligibility
 * profile has it) and the third segment appears. Until then the bar
 * shows only measured numbers.
 */
export default function AnnualMaxBar({
  thisCase,
  remainingAfter,
  planMax,
  exhausted = false,
}: {
  thisCase: number;
  remainingAfter: number;
  /** The plan's annual maximum, when known. Enables the "used" segment. */
  planMax?: number | null;
  exhausted?: boolean;
}) {
  const remainingBefore = thisCase + remainingAfter;
  const used =
    planMax != null && planMax > remainingBefore ? planMax - remainingBefore : 0;
  const total = Math.max(used + remainingBefore, 1);
  const pct = (n: number) => `${Math.max((n / total) * 100, 0)}%`;

  // Amber below $200, red once the plan pays nothing more. The two are
  // different conversations: "budget the next visit" vs "everything
  // from here is yours".
  const nearlyGone = !exhausted && remainingAfter < 200;

  return (
    <section className="rounded-xl border border-gray-200 bg-white p-4">
      <div className="flex items-baseline justify-between gap-3">
        <h2 className="text-[13.5px] font-semibold text-gray-900">
          Annual maximum
        </h2>
        <span className="text-[12px] text-gray-500">
          {planMax != null
            ? `${formatCurrency(planMax)} plan year`
            : `${formatCurrency(remainingBefore)} available`}
        </span>
      </div>

      <div
        className="mt-3 flex h-3 w-full overflow-hidden rounded-full bg-gray-100"
        role="img"
        aria-label={`${formatCurrency(thisCase)} used by this case, ${formatCurrency(
          remainingAfter,
        )} remaining afterwards`}
      >
        {used > 0 && (
          <div style={{ width: pct(used) }} className="bg-gray-400" />
        )}
        <div style={{ width: pct(thisCase) }} className="bg-accord-green-500" />
        <div style={{ width: pct(remainingAfter) }} className="bg-gray-200" />
      </div>

      <dl className="mt-2.5 flex flex-wrap justify-between gap-x-4 gap-y-1 text-[11.5px]">
        {used > 0 && (
          <div className="flex items-center gap-1.5">
            <span className="h-2 w-2 rounded-full bg-gray-400" />
            <dt className="text-gray-500">Used earlier</dt>
            <dd className="font-medium text-gray-900">{formatCurrency(used)}</dd>
          </div>
        )}
        <div className="flex items-center gap-1.5">
          <span className="h-2 w-2 rounded-full bg-accord-green-500" />
          <dt className="text-gray-500">This case</dt>
          <dd className="font-medium text-gray-900">
            {formatCurrency(thisCase)}
          </dd>
        </div>
        <div className="flex items-center gap-1.5">
          <span className="h-2 w-2 rounded-full bg-gray-200" />
          <dt className="text-gray-500">Remaining after</dt>
          <dd className="font-medium text-gray-900">
            {formatCurrency(remainingAfter)}
          </dd>
        </div>
      </dl>

      {exhausted && (
        <p className="mt-3 flex gap-2 rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-[12px] text-red-700">
          <AlertTriangle size={14} className="mt-px flex-shrink-0" />
          <span>
            Annual maximum will be exhausted. The patient is responsible for
            the remaining balance.
          </span>
        </p>
      )}
      {nearlyGone && (
        <p className="mt-3 flex gap-2 rounded-lg border border-amber-200 bg-accord-amber-50 px-3 py-2 text-[12px] text-accord-amber-900">
          <AlertTriangle size={14} className="mt-px flex-shrink-0" />
          <span>
            Annual maximum nearly exhausted after this case —{" "}
            {formatCurrency(remainingAfter)} left for the rest of the benefit
            year.
          </span>
        </p>
      )}
    </section>
  );
}
