import { AlertTriangle, X } from "lucide-react";

import type { CostSummary, ProcedureCost } from "../types/dental";
import { formatCurrency } from "../utils/format";

/**
 * E-03 — the phone call to Delta Dental, as a table.
 *
 * Four numbers per code that get routinely conflated, in the order the
 * payer actually applies them:
 *
 *   UCR fee          what the practice charges
 *   - discount       the in-network write-off, NOT a bill
 *   = contracted     what the payer allows
 *   - plan pays      coinsurance on the contracted rate, after deductible
 *   = patient pays
 *
 * The discount column is the one patients misread as money they owe, so
 * it is rendered green and parenthesised like a credit, and restated in
 * plain English under the table.
 */

/** Pull the downgrade target out of the engine's note.
 *
 *  The API has no `downgrade_to` field on ProcedureCost — only the
 *  prose note, which names the code. Parsing it is ugly but honest:
 *  the alternative is hardcoding "D2750" here, which would be wrong the
 *  moment a plan downgrades to something else. Returns null when the
 *  note does not name a code, and the cell then just shows the note. */
function downgradeTarget(note?: string | null): string | null {
  if (!note) return null;
  const codes = note.match(/\bD\d{4}\b/g);
  return codes && codes.length > 1 ? codes[1] : (codes?.[0] ?? null);
}

export default function CostTable({
  procedures,
  summary,
}: {
  procedures: ProcedureCost[];
  summary: CostSummary;
}) {
  return (
    <section className="overflow-hidden rounded-xl border border-gray-200 bg-white">
      {/* Columns drop as the viewport narrows rather than the table
          scrolling sideways. A patient reading a cost estimate on a
          phone needs "what do I owe", not a horizontal scrollbar over
          seven columns of payer arithmetic. Description goes first
          (it is the longest), then the intermediate figures; CDT and
          patient-pays survive to 375px. The full breakdown is always
          one rotation or one desktop away, and the printed sheet
          carries it regardless. */}
      <div className="overflow-x-auto">
        <table className="w-full text-left text-[12.5px]">
          <thead className="border-b border-gray-200 bg-gray-50">
            <tr className="text-[10.5px] uppercase tracking-wide text-gray-500">
              <th className="px-3 py-2.5 font-medium">CDT</th>
              <th className="hidden px-3 py-2.5 font-medium lg:table-cell">
                Description
              </th>
              <th className="hidden px-3 py-2.5 font-medium sm:table-cell">
                Tooth
              </th>
              <th className="hidden px-3 py-2.5 text-right font-medium md:table-cell">
                Dr. charges
              </th>
              <th className="hidden px-3 py-2.5 text-right font-medium md:table-cell">
                In-network discount
              </th>
              <th className="hidden px-3 py-2.5 text-right font-medium md:table-cell">
                Contracted
              </th>
              <th className="hidden px-3 py-2.5 text-right font-medium sm:table-cell">
                Plan pays
              </th>
              <th className="px-3 py-2.5 text-right font-medium">
                Patient pays
              </th>
            </tr>
          </thead>

          <tbody className="divide-y divide-gray-100">
            {procedures.map((p) => {
              const target = p.downgrade_applied
                ? downgradeTarget(p.downgrade_note)
                : null;
              return (
                <tr key={`${p.cdt_code}-${p.tooth_number ?? "x"}`}>
                  <td className="px-3 py-3 align-top">
                    <span className="flex items-center gap-1.5">
                      <span
                        className={`font-mono font-semibold ${
                          p.downgrade_applied
                            ? "text-gray-400 line-through"
                            : "text-gray-800"
                        }`}
                      >
                        {p.cdt_code}
                      </span>
                      {p.pre_d_required && (
                        <span
                          title="Pre-determination required before treatment"
                          className="text-accord-amber-900"
                        >
                          <AlertTriangle size={11} />
                        </span>
                      )}
                      {!p.covered && (
                        <span title="Not covered" className="text-red-500">
                          <X size={11} strokeWidth={3} />
                        </span>
                      )}
                    </span>
                    {target && (
                      <span
                        title={p.downgrade_note ?? undefined}
                        className="mt-0.5 block font-mono text-[10.5px] text-accord-amber-900"
                      >
                        → {target}
                      </span>
                    )}
                  </td>

                  <td className="hidden max-w-[240px] px-3 py-3 align-top text-gray-700 lg:table-cell">
                    {p.description ?? "—"}
                    {!p.covered && p.not_covered_reason && (
                      <span className="mt-0.5 block text-[11px] text-red-600">
                        {p.not_covered_reason}
                      </span>
                    )}
                  </td>

                  <td className="hidden px-3 py-3 align-top text-gray-600 sm:table-cell">
                    {p.tooth_number ?? "—"}
                  </td>
                  <td className="hidden px-3 py-3 text-right align-top tabular-nums text-gray-700 md:table-cell">
                    {formatCurrency(p.provider_ucr_fee)}
                  </td>
                  <td className="hidden px-3 py-3 text-right align-top tabular-nums text-accord-green-700 md:table-cell">
                    ({formatCurrency(p.in_network_discount)})
                  </td>
                  <td className="hidden px-3 py-3 text-right align-top tabular-nums text-gray-700 md:table-cell">
                    {formatCurrency(p.contracted_rate)}
                  </td>
                  <td className="hidden px-3 py-3 text-right align-top tabular-nums text-gray-700 sm:table-cell">
                    {formatCurrency(p.insurance_pays)}
                  </td>
                  <td className="px-3 py-3 text-right align-top font-semibold tabular-nums text-gray-900">
                    {formatCurrency(p.patient_pays)}
                  </td>
                </tr>
              );
            })}
          </tbody>

          <tfoot className="border-t border-gray-200 bg-gray-50 font-semibold">
            <tr>
              <td className="px-3 py-3 text-gray-900">Total</td>
              <td className="hidden px-3 py-3 lg:table-cell" />
              <td className="hidden px-3 py-3 sm:table-cell" />
              <td className="hidden px-3 py-3 text-right tabular-nums text-gray-900 md:table-cell">
                {formatCurrency(summary.total_provider_charges)}
              </td>
              <td className="hidden px-3 py-3 text-right tabular-nums text-accord-green-700 md:table-cell">
                ({formatCurrency(summary.total_in_network_savings)})
              </td>
              <td className="hidden px-3 py-3 text-right tabular-nums text-gray-900 md:table-cell">
                {formatCurrency(summary.total_contracted)}
              </td>
              <td className="hidden px-3 py-3 text-right tabular-nums text-gray-900 sm:table-cell">
                {formatCurrency(summary.total_insurance_pays)}
              </td>
              <td className="px-3 py-3 text-right tabular-nums text-gray-900">
                {formatCurrency(summary.total_patient_pays)}
              </td>
            </tr>
          </tfoot>
        </table>
      </div>

      <div className="bg-accord-green-900 px-4 py-3.5 text-white">
        <p className="text-[13px] leading-relaxed">
          Your in-network savings of{" "}
          <span className="font-semibold">
            {formatCurrency(summary.total_in_network_savings)}
          </span>{" "}
          are not your responsibility. You pay{" "}
          <span className="font-semibold">
            {formatCurrency(summary.total_patient_pays)}
          </span>{" "}
          in total.
        </p>
      </div>
    </section>
  );
}
