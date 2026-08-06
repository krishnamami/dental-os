import type { DenialReason, Practice } from "../types/dental";

/**
 * H-03 — what is actually blocking pre-Ds across the group.
 *
 * `top_denial_reasons` arrives PER TENANT — each row is
 * {condition_code, tenant_id, frequency} — so the group chart is an
 * aggregation done here, and the per-location table is real rather
 * than invented. The brief treated the list as global totals and named
 * codes that do not exist: it says DOC_XRAY_MISSING ×9 and
 * DOC_NARRATIVE_MISSING ×7, but the engine emits
 * CLINICAL_XRAY_REQUIRED and CLINICAL_NARRATIVE_REQUIRED. Labels are
 * mapped for reading; the codes are shown on hover so nobody has to
 * trust the mapping.
 *
 * The API returns the top 20 rows for the whole group, so a small
 * practice's conditions can fall below the cut — Tampa's do. The
 * footnote says so rather than letting a blank column read as "Tampa
 * has no problems".
 */
const LABELS: Record<string, string> = {
  COVERAGE_PRED_REQUIRED: "Pre-D required",
  CLINICAL_XRAY_REQUIRED: "X-ray required",
  CLINICAL_NARRATIVE_REQUIRED: "Narrative required",
  CLINICAL_CRITERIA_NOT_MET: "Clinical criteria not met",
  COVERAGE_BUNDLING_CONFLICT: "Bundling conflict",
  CLINICAL_BONE_LOSS_THRESHOLD: "Bone loss below threshold",
  COVERAGE_DOWNGRADE_APPLIED: "Downgrade applied",
  CLINICAL_POCKET_DEPTH: "Pocket depth",
  ELIG_FREQUENCY_LIMIT: "Frequency limit",
  ELIG_WAITING_PERIOD_NOT_MET: "Waiting period not met",
  ELIG_COB_REQUIRED: "Coordination of benefits",
  ADMIN_COB_PRIMARY_FIRST: "Primary payer first",
  COVERAGE_SURFACE_MISMATCH: "Surface mismatch",
  COVERAGE_NOT_MEDICALLY_NECESSARY: "Not medically necessary",
};

export function labelForCondition(code: string): string {
  return (
    LABELS[code] ??
    code
      .replace(/^(COVERAGE|CLINICAL|ELIG|ADMIN|DOC)_/, "")
      .replace(/_/g, " ")
      .toLowerCase()
      .replace(/^./, (c) => c.toUpperCase())
  );
}

export interface AggregatedReason {
  code: string;
  total: number;
  byTenant: Record<string, number>;
}

export function aggregate(reasons: DenialReason[]): AggregatedReason[] {
  const map = new Map<string, AggregatedReason>();
  for (const r of reasons) {
    const entry = map.get(r.condition_code) ?? {
      code: r.condition_code,
      total: 0,
      byTenant: {},
    };
    entry.total += r.frequency;
    entry.byTenant[r.tenant_id] =
      (entry.byTenant[r.tenant_id] ?? 0) + r.frequency;
    map.set(r.condition_code, entry);
  }
  return [...map.values()].sort((a, b) => b.total - a.total);
}

export default function DenialChart({
  denialReasons,
  practices,
  limit = 8,
}: {
  denialReasons: DenialReason[];
  practices: Practice[];
  limit?: number;
}) {
  const rows = aggregate(denialReasons);
  const shown = rows.slice(0, limit);
  const max = Math.max(...shown.map((r) => r.total), 1);
  const ordered = [...practices].sort((a, b) => b.total_pre_ds - a.total_pre_ds);

  return (
    <div className="space-y-4">
      <section className="rounded-xl border border-gray-200 bg-white p-4">
        <div className="flex items-baseline justify-between gap-3">
          <h2 className="text-[13.5px] font-semibold text-gray-900">
            Top open conditions — all practices
          </h2>
          <span className="text-[11px] text-gray-400">live</span>
        </div>

        <ul className="mt-4 space-y-2.5">
          {shown.map((r, i) => (
            <li key={r.code} className="flex items-center gap-3">
              <span
                className="w-[150px] flex-shrink-0 truncate text-[12px] text-gray-600"
                title={r.code}
              >
                {labelForCondition(r.code)}
              </span>
              <span className="h-4 flex-1 overflow-hidden rounded bg-gray-100">
                <span
                  style={{ width: `${(r.total / max) * 100}%` }}
                  className={`block h-full rounded ${
                    i === 0 ? "bg-amber-400" : "bg-accord-green-500"
                  }`}
                />
              </span>
              <span className="w-7 flex-shrink-0 text-right text-[12px] font-semibold tabular-nums text-gray-700">
                {r.total}
              </span>
            </li>
          ))}
        </ul>
      </section>

      <section className="overflow-hidden rounded-xl border border-gray-200 bg-white">
        <header className="border-b border-gray-200 bg-gray-50 px-4 py-3">
          <h2 className="text-[13.5px] font-semibold text-gray-900">
            Breakdown by location
          </h2>
        </header>
        <div className="overflow-x-auto">
          <table className="w-full min-w-[520px] text-left text-[12px]">
            <thead className="border-b border-gray-100">
              <tr className="text-[10.5px] uppercase tracking-wide text-gray-500">
                <th className="px-4 py-2 font-medium">Condition</th>
                {ordered.map((p) => (
                  <th key={p.tenant_id} className="px-3 py-2 text-right font-medium">
                    {p.practice_name.split(" ")[0]}
                  </th>
                ))}
                <th className="px-4 py-2 text-right font-medium">Total</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {shown.map((r) => (
                <tr key={r.code}>
                  <td className="px-4 py-2 text-gray-700" title={r.code}>
                    {labelForCondition(r.code)}
                  </td>
                  {ordered.map((p) => (
                    <td
                      key={p.tenant_id}
                      className="px-3 py-2 text-right tabular-nums text-gray-600"
                    >
                      {r.byTenant[p.tenant_id] ?? (
                        <span className="text-gray-300">—</span>
                      )}
                    </td>
                  ))}
                  <td className="px-4 py-2 text-right font-semibold tabular-nums text-gray-900">
                    {r.total}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p className="border-t border-gray-100 px-4 py-2.5 text-[11px] text-gray-400">
          The API returns the group&rsquo;s top 20 condition rows. A small
          practice&rsquo;s conditions can fall below that cut — a dash means
          &ldquo;not in the top 20&rdquo;, not &ldquo;none&rdquo;.
        </p>
      </section>
    </div>
  );
}
