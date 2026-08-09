import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { useLocation, useNavigate } from "react-router-dom";

import AppealsDashboard from "../../../components/AppealsDashboard";
import { DatePickerDropdown } from "../../../components/DatePickerDropdown";
import ConditionsManager from "../../../components/ConditionsManager";
import RevOpsAnalytics from "../../../components/RevOpsAnalytics";
import SubmissionQueue from "../../../components/SubmissionQueue";
import Toast, { useToast } from "../../../components/Toast";
import { api, useBillingAnalytics } from "../../../hooks/useApi";
import { useDatePicker } from "../../../hooks/useDatePicker";
import { useDemoLink } from "../../../hooks/useDemo";
import { formatCurrencyShort } from "../../../utils/format";

/**
 * G-01 — Revenue operations.
 *
 * Four tabs, and the tab is driven by the URL rather than local state:
 * the sidebar links straight to /revenue-ops/conditions and
 * /revenue-ops/appeals, and a tab held in useState would leave those
 * links landing on the queue. It also makes a tab shareable, which is
 * what a biller sending "look at this appeal" actually needs.
 */
const TABS = [
  { id: "queue", label: "Submission queue", path: "/revenue-ops" },
  { id: "conditions", label: "Conditions", path: "/revenue-ops/conditions" },
  { id: "appeals", label: "Appeals", path: "/revenue-ops/appeals" },
  { id: "analytics", label: "Analytics", path: "/revenue-ops/analytics" },
] as const;

type TabId = (typeof TABS)[number]["id"];

function tabFromPath(pathname: string): TabId {
  const match = TABS.filter(
    (t) => t.path !== "/revenue-ops" && pathname.startsWith(t.path),
  )[0];
  return match?.id ?? "queue";
}

/** Every metric is a control now, so each one is a button — a div with
 *  an onClick is unreachable by keyboard and invisible to a screen
 *  reader, and this row is the primary filter for the page. */
function Metric({
  label,
  value,
  tone = "text-gray-900",
  note,
  active = false,
  onClick,
}: {
  label: string;
  value: string;
  tone?: string;
  note?: string;
  active?: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-pressed={active}
      className={`cursor-pointer rounded-xl border p-4 text-left transition ${
        active
          ? "border-2 border-accord-green-500 bg-accord-green-50 ring-2 ring-accord-green-300"
          : "border-gray-200 bg-white hover:bg-gray-50"
      }`}
    >
      <p className="text-[11px] uppercase tracking-wide text-gray-500">
        {label}
      </p>
      <p className={`mt-1 text-[21px] font-semibold leading-none ${tone}`}>
        {value}
      </p>
      {note && <p className="mt-1.5 text-[11px] text-gray-400">{note}</p>}
    </button>
  );
}

interface QueueRow {
  id: string;
  charges: number;
  submission_ready: boolean;
}

export default function RevenueOps() {
  const { pathname } = useLocation();
  const navigate = useNavigate();
  const demoLink = useDemoLink();
  const active = tabFromPath(pathname);
  const { selectedDate, setSelectedDate, availableDates } = useDatePicker();
  const [filter, setFilter] = useState<"all" | "ready" | "blocked">("all");
  const { toast, flash } = useToast();
  const { data: an } = useBillingAnalytics();

  // Same key SubmissionQueue uses — this is a cache read, not a second
  // request. It exists so the metrics can COUNT the queue instead of
  // asserting 9 / 3 / $47k with "sample" under them.
  const { data } = useQuery({
    queryKey: ["decisions", "queue", selectedDate],
    queryFn: async () =>
      (
        await api.get<QueueRow[]>(
          `/decisions/queue?date=${encodeURIComponent(selectedDate)}`,
        )
      ).data,
    staleTime: 60_000,
  });
  const rows: QueueRow[] = Array.isArray(data) ? data : [];
  const readyCount = rows.filter((r) => r.submission_ready).length;
  const blockedRows = rows.filter((r) => !r.submission_ready);
  // Money sitting behind an open condition, not a guess.
  const atRisk = blockedRows.reduce((sum, r) => sum + (r.charges ?? 0), 0);

  function toggle(next: "ready" | "blocked") {
    setFilter((f) => (f === next ? "all" : next));
    if (active !== "queue") navigate(demoLink("/revenue-ops"));
  }

  return (
    <div className="p-4 sm:p-6">
      {/* The picker drives the submission queue only. The four metrics
          above and the other three tabs are not day-scoped — appeals
          and conditions span weeks — so moving the date does not touch
          them, and they do not claim to change. */}
      <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
        <p className="text-[13px] font-semibold text-gray-900">
          Revenue operations
        </p>
        <DatePickerDropdown
          selectedDate={selectedDate}
          availableDates={availableDates}
          onChange={setSelectedDate}
        />
      </div>

      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <Metric
          label="Ready to submit"
          value={String(readyCount)}
          tone="text-accord-green-700"
          note="on this date"
          active={active === "queue" && filter === "ready"}
          onClick={() => toggle("ready")}
        />
        <Metric
          label="Blocked"
          value={String(blockedRows.length)}
          tone="text-accord-amber-900"
          note="on this date"
          active={active === "queue" && filter === "blocked"}
          onClick={() => toggle("blocked")}
        />
        {/* From /analytics/billing, not a literal. It read "3 · 2 live
            · 1 sample" while the Appeals tab underneath counted 1 —
            the header and the list it links to have to agree. */}
        <Metric
          label="Appeals active"
          value={String(an?.appeals.pending ?? "—")}
          note={`${an?.appeals.total ?? 0} filed · live`}
          active={active === "appeals"}
          onClick={() => navigate(demoLink("/revenue-ops/appeals"))}
        />
        <Metric
          label="Revenue at risk"
          value={formatCurrencyShort(atRisk)}
          tone="text-accord-amber-900"
          note="blocked charges"
          active={active === "analytics"}
          onClick={() => navigate(demoLink("/revenue-ops/analytics"))}
        />
      </div>

      {/* Scrolls rather than wraps on a phone — four wrapped tabs read
          as a list of links, not a tab bar. */}
      <div className="mt-5 flex gap-1.5 overflow-x-auto pb-1">
        {TABS.map((t) => (
          <button
            key={t.id}
            type="button"
            onClick={() => navigate(demoLink(t.path))}
            aria-current={active === t.id ? "page" : undefined}
            className={`flex-shrink-0 rounded-lg px-3 py-1.5 text-[12.5px] font-medium transition ${
              active === t.id
                ? "bg-accord-green-900 text-white"
                : "border border-gray-200 bg-white text-gray-600 hover:bg-gray-50"
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      <div className="mt-4">
        {active === "queue" && (
          <SubmissionQueue
            date={selectedDate}
            filter={filter}
            onToast={flash}
          />
        )}
        {active === "conditions" && <ConditionsManager onToast={flash} />}
        {active === "appeals" && <AppealsDashboard onToast={flash} />}
        {active === "analytics" && <RevOpsAnalytics />}
      </div>

      <Toast message={toast} />
    </div>
  );
}
