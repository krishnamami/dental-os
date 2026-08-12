/**
 * The day selector, shared by all four persona pages.
 *
 * Labels are computed at LOCAL midnight, matching useDatePicker's
 * todayIso() — see the warning there about the server running in UTC.
 *
 * "Tomorrow" is in here because it is not hypothetical: the seed stamps
 * CURRENT_DATE in UTC, so from about 8pm Eastern the newest available
 * date really is tomorrow. Without the case it would render as a bare
 * "Aug 8, 2026" and read like a data error.
 */
interface Props {
  selectedDate: string;
  availableDates: string[];
  onChange: (date: string) => void;
}

/** "2026-08-07" -> a Date at LOCAL midnight. Parsing the bare string
 *  gives UTC midnight, which is the previous day west of London. */
function localMidnight(iso: string): Date {
  const [y, m, d] = iso.split("-").map(Number);
  return new Date(y, (m ?? 1) - 1, d ?? 1);
}

export function dateLabel(dateStr: string): string {
  const d = localMidnight(dateStr);
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const diffDays = Math.round((today.getTime() - d.getTime()) / 86_400_000);
  const fmt = d.toLocaleDateString("en-US", { month: "short", day: "numeric" });
  if (diffDays === 0) return `Today — ${fmt}`;
  if (diffDays === 1) return `Yesterday — ${fmt}`;
  if (diffDays === -1) return `Tomorrow — ${fmt}`;
  return d.toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

export function DatePickerDropdown({
  selectedDate,
  availableDates,
  onChange,
}: Props) {
  // The selected day is always an option, even when the API has not
  // listed it — a <select> whose value is absent from its own options
  // renders blank in every browser, which is how "today, no patients
  // booked" would look like a broken control.
  const options = availableDates.includes(selectedDate)
    ? availableDates
    : [selectedDate, ...availableDates].sort((a, b) =>
        a < b ? 1 : a > b ? -1 : 0,
      );

  return (
    <label>
      <span className="sr-only">Schedule date</span>
      <select
        value={selectedDate}
        onChange={(e) => onChange(e.target.value)}
        // 44px tall on a tablet, unchanged on desktop. 16px text on
        // narrow as well: under it Safari zooms the page on focus.
        className="cursor-pointer rounded-lg border border-[#e5e7eb] bg-white px-3 py-1.5 text-[13px] text-[#374151] outline-none max-[899px]:min-h-[44px] max-[899px]:text-[16px]"
      >
        {options.map((d) => (
          <option key={d} value={d}>
            {dateLabel(d)}
          </option>
        ))}
      </select>
    </label>
  );
}

export default DatePickerDropdown;
