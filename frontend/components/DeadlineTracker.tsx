import { AlertTriangle } from "lucide-react";

import { formatDate } from "../utils/format";

/**
 * G-06 — how long is left to file.
 *
 * ⚠ RENDERS AN EXPLICIT "NO DEADLINE" STATE, and that state is common.
 * `payer_responses.appeal_deadline` is populated for the 7 DENIED
 * scenarios and NULL for the other 33 — a pended pre-D has no appeal
 * clock because the payer has not denied it yet. Inventing "60 days"
 * for those would put a countdown on screen that no payer agreed to,
 * which is the one number a biller would act on without checking.
 *
 * Bands: >30 days green, 14-30 amber, <14 red. The window itself comes
 * from the payer (Delta runs 60-180 days from denial), so the bar is
 * scaled to the days remaining rather than a fixed axis.
 */
export default function DeadlineTracker({
  daysRemaining,
  deadline,
  totalWindowDays = 60,
}: {
  daysRemaining?: number | null;
  deadline?: string | null;
  /** The payer's filing window, for the "elapsed" portion of the bar. */
  totalWindowDays?: number;
}) {
  if (daysRemaining == null) {
    return (
      <div className="rounded-lg border border-gray-200 bg-gray-50 px-3 py-2">
        <p className="text-[11.5px] text-gray-500">
          No appeal deadline on file — the payer has not issued a denial, so
          the filing clock has not started.
        </p>
      </div>
    );
  }

  const urgent = daysRemaining < 14;
  const soon = !urgent && daysRemaining <= 30;
  const tone = urgent
    ? { bar: "bg-red-500", text: "text-red-700", track: "bg-red-100" }
    : soon
      ? {
          bar: "bg-amber-400",
          text: "text-accord-amber-900",
          track: "bg-amber-100",
        }
      : {
          bar: "bg-accord-green-500",
          text: "text-accord-green-900",
          track: "bg-accord-green-50",
        };

  const remainingPct = Math.min(
    Math.max((daysRemaining / totalWindowDays) * 100, 2),
    100,
  );

  return (
    <div>
      <div className={`flex h-2 w-full overflow-hidden rounded-full ${tone.track}`}>
        {/* Elapsed sits left, remaining right — the bar drains toward
            the deadline as the days pass. */}
        <div
          style={{ width: `${100 - remainingPct}%` }}
          className="bg-gray-300"
        />
        <div style={{ width: `${remainingPct}%` }} className={tone.bar} />
      </div>

      <p
        className={`mt-1.5 flex items-center gap-1.5 text-[11.5px] font-medium ${tone.text}`}
      >
        {(urgent || soon) && <AlertTriangle size={12} />}
        {daysRemaining <= 3
          ? `Appeal deadline in ${daysRemaining} day${daysRemaining === 1 ? "" : "s"}`
          : urgent
            ? `${daysRemaining} days remaining — urgent`
            : `${daysRemaining} days remaining`}
        {deadline && (
          <span className="font-normal text-gray-500">
            · deadline {formatDate(deadline)}
          </span>
        )}
      </p>
    </div>
  );
}
