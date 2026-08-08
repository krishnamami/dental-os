/**
 * Which day every persona page is looking at.
 *
 * One hook behind all four screens, so the front desk, the coordinator,
 * the dentist and revenue ops cannot each hold a different idea of
 * "today" — and so the dates dropdown is fetched once and shared out of
 * the React Query cache rather than four times.
 *
 * ⚠ LOCAL TIME, AND IT DOES NOT ALWAYS AGREE WITH THE SERVER. The
 * database runs in UTC and stamps appointments with CURRENT_DATE; both
 * /checkin/today and /decisions/queue default to the SERVER's today.
 * From about 8pm Eastern those are different days. Every caller here
 * therefore sends an EXPLICIT ?date built from the browser's clock, so
 * the server default never applies and the label a receptionist reads
 * matches the day they are living in.
 *
 * `todayIso()` deliberately does not use toISOString(), which returns
 * UTC: that would put the default back on the server's clock and then
 * label the selected day "Aug 8" while every comparison in
 * DatePickerDropdown — which works in local time — declined to call it
 * "Today". The two halves have to share one clock.
 *
 * The real fix is a timezone column on the practice. There isn't one.
 */
import { useEffect, useRef, useState } from "react";
import { useQuery } from "@tanstack/react-query";

import { api } from "./useApi";

/** Today as YYYY-MM-DD in the BROWSER's timezone. */
export function todayIso(): string {
  const d = new Date();
  const m = `${d.getMonth() + 1}`.padStart(2, "0");
  const day = `${d.getDate()}`.padStart(2, "0");
  return `${d.getFullYear()}-${m}-${day}`;
}

export function useDatePicker() {
  const today = todayIso();
  const [selectedDate, setSelectedDate] = useState<string>(today);
  // Once the user picks a day, a later refetch of the dates list must
  // not pull them back off it.
  const chosen = useRef(false);

  const { data: availableDates = [] } = useQuery({
    queryKey: ["checkin", "dates"],
    queryFn: async () => (await api.get<string[]>("/checkin/dates")).data,
    staleTime: 5 * 60_000,
  });

  // A practice with nobody booked today should open on the last day it
  // did have patients, not on an empty screen. availableDates comes
  // back newest-first from the API.
  useEffect(() => {
    if (chosen.current) return;
    if (availableDates.length > 0 && !availableDates.includes(today)) {
      setSelectedDate(availableDates[0]);
    }
  }, [availableDates, today]);

  function choose(iso: string) {
    chosen.current = true;
    setSelectedDate(iso);
  }

  return { selectedDate, setSelectedDate: choose, availableDates, today };
}
