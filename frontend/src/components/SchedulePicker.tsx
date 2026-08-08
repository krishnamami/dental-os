/**
 * Which day's schedule you are looking at.
 *
 * One component for both the check-in queue and the coordinator's
 * screen, so the two cannot disagree about what "today" means or label
 * the same date differently.
 *
 * ⚠ LOCAL TIME, DELIBERATELY, AND IT DOES NOT ALWAYS AGREE WITH THE
 * SERVER. The database runs in UTC and stamps appointments with
 * CURRENT_DATE, and /checkin/today defaults to the SERVER's today. From
 * about 8pm Eastern those are different days. This picker resolves it
 * by always sending an explicit ?date computed from the browser's
 * clock, so the server's own default never applies and the label a
 * receptionist reads matches the day they are living in.
 *
 * The real fix is a timezone on the practice — there is no column for
 * one — after which both sides can agree on a calendar day. Until then
 * a practice seeded at 9pm ET gets its rows dated tomorrow, and the
 * dropdown is what makes that visible rather than mysterious.
 *
 * Note `todayIso()` does NOT use toISOString(): that returns UTC, which
 * would put the default back on the server's clock and label the
 * current day "Aug 8" while the wall clock says the 7th.
 */
import { useQuery } from "@tanstack/react-query";

import { api } from "../hooks/useApi";

/** Today as YYYY-MM-DD in the BROWSER's timezone. */
export function todayIso(): string {
  const d = new Date();
  const m = `${d.getMonth() + 1}`.padStart(2, "0");
  const day = `${d.getDate()}`.padStart(2, "0");
  return `${d.getFullYear()}-${m}-${day}`;
}

/** "2026-08-07" -> a Date at LOCAL midnight. Parsing the bare string
 *  would give UTC midnight, which is the previous day west of London. */
function localMidnight(iso: string): Date {
  const [y, m, d] = iso.split("-").map(Number);
  return new Date(y, (m ?? 1) - 1, d ?? 1);
}

export function dateLabel(iso: string): string {
  const d = localMidnight(iso);
  const today = localMidnight(todayIso());
  const diffDays = Math.round((today.getTime() - d.getTime()) / 86_400_000);
  const short = d.toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
  });
  if (diffDays === 0) return `Today — ${short}`;
  if (diffDays === 1) return `Yesterday — ${short}`;
  if (diffDays === -1) return `Tomorrow — ${short}`;
  return d.toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

/**
 * The days this practice has a schedule for, newest first.
 *
 * Today is merged in whether or not the API listed it. A practice with
 * nobody booked today still has a today, and a dropdown whose value is
 * not among its own options renders blank in every browser.
 */
export function useScheduleDates(selected: string): string[] {
  const { data } = useQuery({
    queryKey: ["checkin", "dates"],
    queryFn: async () => (await api.get<string[]>("/checkin/dates")).data,
    staleTime: 5 * 60_000,
  });
  const from = Array.isArray(data) ? data : [];
  return Array.from(new Set([todayIso(), selected, ...from])).sort((a, b) =>
    a < b ? 1 : a > b ? -1 : 0,
  );
}

export default function SchedulePicker({
  value,
  onChange,
  dates,
}: {
  value: string;
  onChange: (iso: string) => void;
  dates: string[];
}) {
  return (
    <label className="flex items-center gap-2">
      <span className="sr-only">Schedule date</span>
      <select
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="cursor-pointer rounded-lg border border-[#e5e7eb] bg-white px-3 py-1.5 text-[13px] text-[#374151]"
      >
        {dates.map((d) => (
          <option key={d} value={d}>
            {dateLabel(d)}
          </option>
        ))}
      </select>
    </label>
  );
}
