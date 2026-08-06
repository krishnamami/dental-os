/**
 * H-07 — period selector.
 *
 * The buttons change nothing today and the note says so. The corpus has
 * no time series: every pre-D carries a single computed_at from one
 * pipeline run, so "last 30 days" and "YTD" would return identical
 * rows. Rendering a filter that silently does nothing is worse than
 * saying it is not wired.
 */
const PERIODS = ["30 days", "60 days", "90 days", "YTD"] as const;
export type Period = (typeof PERIODS)[number];

export default function TimeFilter({
  value,
  onChange,
}: {
  value: Period;
  onChange: (p: Period) => void;
}) {
  return (
    <div className="flex flex-wrap items-center gap-2">
      <div className="flex gap-1.5 overflow-x-auto">
        {PERIODS.map((p) => (
          <button
            key={p}
            type="button"
            onClick={() => onChange(p)}
            aria-pressed={p === value}
            className={`flex-shrink-0 rounded-lg px-2.5 py-1 text-[12px] font-medium transition ${
              p === value
                ? "bg-gray-900 text-white"
                : "border border-gray-200 bg-white text-gray-600 hover:bg-gray-50"
            }`}
          >
            {p}
          </button>
        ))}
      </div>
      <span className="text-[11px] text-gray-400">
        Showing all available data — time filtering needs a time series the
        corpus does not have.
      </span>
    </div>
  );
}
