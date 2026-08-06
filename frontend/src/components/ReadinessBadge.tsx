/**
 * D-02 — submission readiness at a glance.
 *
 * 14/14 green, 10-13 amber, below 10 red. The thresholds live here
 * rather than at each call site so a table row and a detail header can
 * never disagree about what "ready" looks like.
 */
export default function ReadinessBadge({
  score,
  total = 14,
  className = "",
}: {
  score: number;
  total?: number;
  className?: string;
}) {
  const tone =
    score >= total
      ? "border-accord-green-100 bg-accord-green-50 text-accord-green-900"
      : score >= 10
        ? "border-amber-200 bg-accord-amber-50 text-accord-amber-900"
        : "border-red-200 bg-red-50 text-red-700";

  return (
    <span
      title={`${score} of ${total} readiness flags satisfied`}
      className={`inline-flex items-center rounded-full border px-2 py-0.5 text-[11.5px] font-semibold tabular-nums ${tone} ${className}`}
    >
      {score}/{total}
    </span>
  );
}
