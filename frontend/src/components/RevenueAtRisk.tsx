import type { DenialReason, Portfolio, Practice } from "../types/dental";
import { formatCurrency, formatCurrencyShort } from "../utils/format";
import { aggregate, labelForCondition } from "./DenialChart";

/**
 * H-05 — where the money sits.
 *
 * ⚠ ONE NAMING CORRECTION, and it matters on a page a DSO owner reads.
 * The API's `total_patient_revenue_at_risk` currently equals
 * `total_patient_responsibility` — every practice has at least one
 * denied or pended pre-D, so the "at risk" filter selects all of them.
 * $60,785 is therefore TOTAL PATIENT RESPONSIBILITY across the group,
 * not money in jeopardy. Labelling it "at risk" would overstate the
 * problem by roughly a factor of three.
 *
 * What is genuinely at risk is the share sitting on pre-Ds that did not
 * approve, which is estimated here from each practice's denied+pended
 * proportion and labelled as an estimate. Making it exact needs
 * per-pre-D cost totals the portfolio endpoint does not return.
 */
export default function RevenueAtRisk({
  portfolio,
}: {
  portfolio: Portfolio;
}) {
  const ordered = [...portfolio.practices].sort(
    (a, b) => b.total_patient_pays - a.total_patient_pays,
  );
  const max = Math.max(...ordered.map((p) => p.total_patient_pays), 1);

  const unresolvedShare = (p: Practice) =>
    p.total_pre_ds > 0 ? (p.denied + p.pended) / p.total_pre_ds : 0;

  const estimatedAtRisk = ordered.reduce(
    (sum, p) => sum + p.total_patient_pays * unresolvedShare(p),
    0,
  );

  const byTenant = new Map(ordered.map((p) => [p.tenant_id, p]));
  const topPerTenant = new Map<string, DenialReason>();
  for (const r of portfolio.top_denial_reasons) {
    const cur = topPerTenant.get(r.tenant_id);
    if (!cur || r.frequency > cur.frequency) topPerTenant.set(r.tenant_id, r);
  }

  const groupTop = aggregate(portfolio.top_denial_reasons)[0];

  return (
    <div className="space-y-4">
      <section className="rounded-xl border border-gray-200 bg-white p-5">
        <p className="text-[11px] uppercase tracking-wide text-gray-500">
          Total patient responsibility
        </p>
        <p className="mt-1 text-[26px] font-semibold leading-none text-gray-900">
          {formatCurrency(portfolio.summary.total_patient_responsibility)}
        </p>
        <p className="mt-1.5 text-[12px] text-gray-500">
          Across {portfolio.summary.total_practices} practices ·{" "}
          {portfolio.summary.total_pre_ds} pre-Ds
        </p>
        <p className="mt-3 border-t border-gray-100 pt-3 text-[12px] text-accord-amber-900">
          Estimated {formatCurrency(estimatedAtRisk)} sits on pre-Ds that have
          not approved — {portfolio.summary.total_denied} denied and{" "}
          {portfolio.summary.total_pended} pended. Estimated from each
          practice&rsquo;s unresolved share; exact figures need per-pre-D
          totals the portfolio endpoint does not return.
        </p>
      </section>

      <section className="rounded-xl border border-gray-200 bg-white p-4">
        <h2 className="text-[13.5px] font-semibold text-gray-900">
          Patient responsibility by location
        </h2>
        <ul className="mt-3 space-y-2.5">
          {ordered.map((p) => (
            <li key={p.tenant_id} className="flex items-center gap-3">
              <span className="w-[120px] flex-shrink-0 truncate text-[12px] text-gray-600">
                {p.practice_name}
              </span>
              <span className="h-4 flex-1 overflow-hidden rounded bg-gray-100">
                <span
                  style={{ width: `${(p.total_patient_pays / max) * 100}%` }}
                  className="block h-full rounded bg-accord-green-500"
                />
              </span>
              <span className="w-20 flex-shrink-0 text-right text-[12px] font-semibold tabular-nums text-gray-700">
                {formatCurrencyShort(p.total_patient_pays)}
              </span>
            </li>
          ))}
        </ul>
      </section>

      <section className="overflow-hidden rounded-xl border border-gray-200 bg-white">
        <header className="border-b border-gray-200 bg-gray-50 px-4 py-3">
          <h2 className="text-[13.5px] font-semibold text-gray-900">
            Unresolved pre-Ds by practice
          </h2>
        </header>
        <ul className="divide-y divide-gray-100">
          {ordered.map((p) => {
            const top = topPerTenant.get(p.tenant_id);
            return (
              <li key={p.tenant_id} className="px-4 py-3">
                <p className="text-[13px] font-medium text-gray-900">
                  {p.practice_name}
                </p>
                <p className="mt-0.5 text-[12px] text-gray-600">
                  {p.pended} pended + {p.denied} denied ={" "}
                  <span className="font-medium">{p.pended + p.denied}</span> not
                  yet approved
                </p>
                <p className="mt-1 text-[11.5px] text-gray-500">
                  {top
                    ? `Top condition: ${labelForCondition(top.condition_code)} ×${top.frequency}`
                    : "No conditions in the group's top 20 — too few pre-Ds to rank."}
                </p>
              </li>
            );
          })}
        </ul>
      </section>

      {groupTop && (
        <section className="rounded-xl border border-accord-green-100 bg-accord-green-50 p-4">
          <h2 className="text-[13px] font-semibold text-accord-green-900">
            Biggest single lever
          </h2>
          <p className="mt-1.5 text-[12.5px] leading-relaxed text-accord-green-900/90">
            <span className="font-medium">
              {labelForCondition(groupTop.code)}
            </span>{" "}
            accounts for {groupTop.total} open conditions across the group —
            more than the next two combined. It is concentrated at{" "}
            {byTenant.get(
              Object.entries(groupTop.byTenant).sort(
                (a, b) => b[1] - a[1],
              )[0]?.[0] ?? "",
            )?.practice_name ?? "one practice"}
            .
          </p>
          <p className="mt-2 text-[11px] text-accord-green-900/70">
            Revenue impact is not estimated here. Turning a condition count
            into a dollar figure needs the case value behind each one, which
            the portfolio endpoint does not return — see the Training tab for
            the workflow change itself.
          </p>
        </section>
      )}
    </div>
  );
}
