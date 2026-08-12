import { Check, X } from "lucide-react";

/**
 * E-08 — why the payer changes the answer.
 *
 * Static, and verified against dental-simulator's coverage_rules on
 * 2026-08-06 rather than written from memory:
 *
 *   SELECT payer_id, downgrade_to_cdt FROM coverage_rules
 *   WHERE cdt_code = 'D2740';
 *
 * Delta, MetLife and Guardian downgrade D2740 to D2750. Cigna does not
 * (it negotiated no downgrade). Aetna does not either, for a different
 * reason — a DMO pays a fixed copay per code, so there is no
 * coinsurance percentage to reduce. Same tooth, same code, two
 * different patient bills.
 */
const ROWS = [
  {
    payer: "Delta Dental PPO",
    downgrades: true,
    detail: "Paid at the D2750 PFM rate; patient covers the difference",
  },
  {
    payer: "Cigna DPPO",
    downgrades: false,
    detail: "No downgrade negotiated — D2740 paid at its own rate",
  },
  {
    payer: "MetLife PDP",
    downgrades: true,
    detail: "Paid at the D2750 PFM rate",
  },
  {
    payer: "Guardian DPPO",
    downgrades: true,
    detail: "Paid at the D2750 PFM rate",
  },
  {
    payer: "Humana DPPO",
    downgrades: true,
    detail: "Paid at the D2750 PFM rate",
  },
  {
    payer: "Aetna DMO",
    downgrades: false,
    detail: "Fixed copay per code — no percentage to downgrade",
  },
];

export default function PayerComparison() {
  return (
    <section className="overflow-hidden rounded-xl border border-gray-200 bg-white">
      <header className="border-b border-gray-200 bg-gray-50 px-4 py-3">
        <h2 className="text-[13.5px] font-semibold text-gray-900">
          D2740 all-ceramic crown — by payer
        </h2>
        <p className="mt-0.5 text-[11.5px] text-gray-500">
          The same code, priced five ways. Worth checking before treatment
          planning.
        </p>
      </header>

      <ul className="divide-y divide-gray-100">
        {ROWS.map((r) => (
          <li key={r.payer} className="flex items-start gap-3 px-4 py-2.5">
            <span
              className={`mt-0.5 flex h-4 w-4 flex-shrink-0 items-center justify-center rounded-full ${
                r.downgrades
                  ? "bg-accord-amber-50 text-accord-amber-900"
                  : "bg-accord-green-50 text-accord-green-700"
              }`}
            >
              {r.downgrades ? (
                <X size={10} strokeWidth={3} />
              ) : (
                <Check size={10} strokeWidth={3} />
              )}
            </span>
            <div className="min-w-0">
              <p className="text-[12.5px] font-medium text-gray-900">
                {r.payer}
                <span
                  className={`ml-2 font-normal ${
                    r.downgrades
                      ? "text-accord-amber-900"
                      : "text-accord-green-700"
                  }`}
                >
                  {r.downgrades ? "downgrades" : "no downgrade"}
                </span>
              </p>
              <p className="mt-0.5 text-[11.5px] text-gray-500">{r.detail}</p>
            </div>
          </li>
        ))}
      </ul>
    </section>
  );
}
