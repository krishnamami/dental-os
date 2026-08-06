import type { DenialReason, Practice } from "../types/dental";
import { formatCurrency, formatPercent } from "../utils/format";
import { labelForCondition } from "./DenialChart";

/**
 * H-02 — one card per practice, from GET /portfolio/summary.
 *
 * Approval-rate colour: >=50% green, 30-50% amber, <30% red. The bands
 * are about where a DSO operator would start asking questions, not
 * about statistical significance — Tampa's 60% is three of five, and
 * the card shows the counts so the rate can be read for what it is.
 */
const STATE_FROM_ADDRESS = /,\s*[^,]*?\b([A-Z]{2})\b\s*\d{5}/;

function stateOf(address: string): string {
  return address.match(STATE_FROM_ADDRESS)?.[1] ?? "—";
}

function rateTone(rate: number): string {
  if (rate >= 0.5) return "text-accord-green-700";
  if (rate >= 0.3) return "text-accord-amber-900";
  return "text-red-600";
}

function barTone(rate: number): string {
  if (rate >= 0.5) return "bg-accord-green-500";
  if (rate >= 0.3) return "bg-amber-400";
  return "bg-red-400";
}

export default function LocationCards({
  practices,
  denialReasons,
}: {
  practices: Practice[];
  denialReasons: DenialReason[];
}) {
  // Largest first — a DSO operator reads the biggest practice first.
  const ordered = [...practices].sort((a, b) => b.total_pre_ds - a.total_pre_ds);

  return (
    <div className="space-y-4">
      <div className="grid gap-3 lg:grid-cols-3">
        {ordered.map((p) => {
          const top = denialReasons
            .filter((r) => r.tenant_id === p.tenant_id)
            .sort((a, b) => b.frequency - a.frequency)[0];
          return (
            <article
              key={p.tenant_id}
              className="rounded-xl border border-gray-200 bg-white p-4"
            >
              <header className="flex items-start justify-between gap-2">
                <div className="min-w-0">
                  <h3 className="truncate text-[14px] font-semibold text-gray-900">
                    {p.practice_name}
                  </h3>
                  <p className="mt-0.5 truncate text-[11px] text-gray-500">
                    {p.address}
                  </p>
                </div>
                <span className="flex-shrink-0 rounded border border-gray-200 bg-gray-50 px-1.5 py-0.5 text-[10.5px] font-semibold text-gray-600">
                  {stateOf(p.address)}
                </span>
              </header>

              <dl className="mt-3.5 grid grid-cols-3 gap-y-3">
                {[
                  { k: "Pre-Ds", v: String(p.total_pre_ds) },
                  {
                    k: "Approval",
                    v: formatPercent(p.approval_rate),
                    tone: rateTone(p.approval_rate),
                  },
                  { k: "Approved", v: String(p.approved) },
                  { k: "Denied", v: String(p.denied) },
                  { k: "Pended", v: String(p.pended) },
                  {
                    k: "Patient rev.",
                    v: formatCurrency(p.total_patient_pays),
                  },
                ].map((s) => (
                  <div key={s.k}>
                    <dt className="text-[10.5px] uppercase tracking-wide text-gray-500">
                      {s.k}
                    </dt>
                    <dd
                      className={`mt-0.5 text-[13.5px] font-semibold ${s.tone ?? "text-gray-900"}`}
                    >
                      {s.v}
                    </dd>
                  </div>
                ))}
              </dl>

              <footer className="mt-3.5 border-t border-gray-100 pt-2.5">
                <p className="text-[11.5px] text-gray-500">
                  {top ? (
                    <>
                      Top condition:{" "}
                      <span className="font-medium text-gray-700">
                        {labelForCondition(top.condition_code)}
                      </span>{" "}
                      ×{top.frequency}
                    </>
                  ) : (
                    "No open conditions in the group's top 20."
                  )}
                </p>
              </footer>
            </article>
          );
        })}
      </div>

      <section className="rounded-xl border border-gray-200 bg-white p-4">
        <h3 className="text-[13px] font-semibold text-gray-900">
          Approval rate by location
        </h3>
        <ul className="mt-3 space-y-2.5">
          {ordered.map((p) => (
            <li key={p.tenant_id} className="flex items-center gap-3">
              <span className="w-[120px] flex-shrink-0 truncate text-[12px] text-gray-600">
                {p.practice_name}
              </span>
              <span className="h-4 flex-1 overflow-hidden rounded bg-gray-100">
                <span
                  style={{ width: `${p.approval_rate * 100}%` }}
                  className={`block h-full rounded ${barTone(p.approval_rate)}`}
                />
              </span>
              <span
                className={`w-24 flex-shrink-0 text-right text-[12px] font-semibold tabular-nums ${rateTone(p.approval_rate)}`}
              >
                {formatPercent(p.approval_rate)}
                <span className="ml-1 font-normal text-gray-400">
                  {p.approved}/{p.total_pre_ds}
                </span>
              </span>
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}
