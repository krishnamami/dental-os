/**
 * H-04 — approval rate per payer, per location.
 *
 * Counted from the corpus on 2026-08-06, not from the brief:
 *
 *   SELECT pr.payer_id, count(*), count(*) FILTER (WHERE decision='approved')
 *   FROM pred_requests pr JOIN pred_states ps USING (pred_request_id)
 *   WHERE pr.tenant_id = $1 GROUP BY 1;
 *
 * The brief's numbers do not match. It puts Aetna DMO at 0% "implants
 * excluded"; Aetna is 1 of 2 — TB-B01 is denied for the implant
 * exclusion and TB-D01 is approved, which is the pair that makes the
 * payer-difference argument. It also gives Delta Suwanee 28%; it is 25%.
 *
 * EVERY CELL SHOWS ITS DENOMINATOR. Most are one or two pre-Ds, where a
 * percentage is arithmetic rather than a performance signal, and a bare
 * "0%" against a single denied case would read as a payer problem.
 */
interface Cell {
  approved: number;
  total: number;
}

const DATA: Array<{ payer: string; cells: Record<string, Cell | null> }> = [
  {
    payer: "Delta Dental PPO",
    cells: {
      suwanee: { approved: 9, total: 36 },
      tampa: null,
      dallas: { approved: 0, total: 1 },
    },
  },
  {
    payer: "Cigna DPPO",
    cells: {
      suwanee: { approved: 2, total: 2 },
      tampa: null,
      dallas: null,
    },
  },
  {
    payer: "MetLife PDP",
    cells: {
      suwanee: { approved: 2, total: 2 },
      tampa: null,
      dallas: null,
    },
  },
  {
    payer: "Humana DPPO",
    cells: {
      suwanee: null,
      tampa: { approved: 2, total: 2 },
      dallas: { approved: 0, total: 1 },
    },
  },
  {
    payer: "Aetna DMO",
    cells: {
      suwanee: null,
      tampa: { approved: 1, total: 2 },
      dallas: null,
    },
  },
  {
    payer: "Guardian DPPO",
    cells: {
      suwanee: null,
      tampa: { approved: 0, total: 1 },
      dallas: { approved: 2, total: 3 },
    },
  },
];

const COLUMNS = [
  { key: "suwanee", label: "Suwanee GA" },
  { key: "tampa", label: "Tampa FL" },
  { key: "dallas", label: "Dallas TX" },
];

/** Thin samples are rendered grey rather than green or red: a rate over
 *  fewer than 5 pre-Ds is not a payer signal. */
function toneFor(cell: Cell): string {
  if (cell.total < 5) return "text-gray-500";
  const rate = cell.approved / cell.total;
  if (rate >= 0.5) return "text-accord-green-700";
  if (rate >= 0.3) return "text-accord-amber-900";
  return "text-red-600";
}

export default function PayerPerformance() {
  return (
    <section className="overflow-hidden rounded-xl border border-gray-200 bg-white">
      <header className="flex items-center justify-between gap-3 border-b border-gray-200 bg-gray-50 px-4 py-3">
        <h2 className="text-[13.5px] font-semibold text-gray-900">
          Payer performance by location
        </h2>
        <span className="text-[11px] text-gray-400">
          counted from the corpus
        </span>
      </header>

      <div className="overflow-x-auto">
        <table className="w-full min-w-[520px] text-left text-[12px]">
          <thead className="border-b border-gray-100">
            <tr className="text-[10.5px] uppercase tracking-wide text-gray-500">
              <th className="px-4 py-2 font-medium">Payer</th>
              {COLUMNS.map((c) => (
                <th key={c.key} className="px-3 py-2 text-right font-medium">
                  {c.label}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-50">
            {DATA.map((row) => (
              <tr key={row.payer}>
                <td className="px-4 py-2 text-gray-700">{row.payer}</td>
                {COLUMNS.map((c) => {
                  const cell = row.cells[c.key];
                  return (
                    <td key={c.key} className="px-3 py-2 text-right">
                      {cell ? (
                        <span className={`font-semibold tabular-nums ${toneFor(cell)}`}>
                          {Math.round((cell.approved / cell.total) * 100)}%
                          <span className="ml-1 font-normal text-gray-400">
                            {cell.approved}/{cell.total}
                          </span>
                        </span>
                      ) : (
                        <span className="text-gray-300">—</span>
                      )}
                    </td>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <p className="border-t border-gray-100 px-4 py-2.5 text-[11px] leading-relaxed text-gray-500">
        Aetna DMO is 1 of 2 at Tampa: TB-B01 denied because the DMO carries no
        implant benefit, TB-D01 approved because a DMO has no ceramic
        downgrade. Same payer, opposite answers — that pair is the argument,
        not the percentage. Rates over fewer than five pre-Ds are shown grey.
      </p>
    </section>
  );
}
