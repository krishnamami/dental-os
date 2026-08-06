import { useLocation, useNavigate } from "react-router-dom";

import AppealsDashboard from "../../../components/AppealsDashboard";
import ConditionsManager from "../../../components/ConditionsManager";
import RevOpsAnalytics from "../../../components/RevOpsAnalytics";
import SubmissionQueue from "../../../components/SubmissionQueue";
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

function Metric({
  label,
  value,
  tone = "text-gray-900",
  note,
}: {
  label: string;
  value: string;
  tone?: string;
  note?: string;
}) {
  return (
    <div className="rounded-xl border border-gray-200 bg-white p-4">
      <p className="text-[11px] uppercase tracking-wide text-gray-500">
        {label}
      </p>
      <p className={`mt-1 text-[21px] font-semibold leading-none ${tone}`}>
        {value}
      </p>
      {note && <p className="mt-1.5 text-[11px] text-gray-400">{note}</p>}
    </div>
  );
}

export default function RevenueOps() {
  const { pathname } = useLocation();
  const navigate = useNavigate();
  const demoLink = useDemoLink();
  const active = tabFromPath(pathname);

  return (
    <div className="p-4 sm:p-6">
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <Metric
          label="Ready to submit"
          value="9"
          tone="text-accord-green-700"
          note="sample"
        />
        <Metric
          label="Blocked"
          value="3"
          tone="text-accord-amber-900"
          note="sample"
        />
        <Metric label="Appeals active" value="3" note="2 live · 1 sample" />
        <Metric
          label="Revenue at risk"
          value={formatCurrencyShort(47000)}
          tone="text-accord-amber-900"
          note="sample"
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
        {active === "queue" && <SubmissionQueue />}
        {active === "conditions" && <ConditionsManager />}
        {active === "appeals" && <AppealsDashboard />}
        {active === "analytics" && <RevOpsAnalytics />}
      </div>
    </div>
  );
}
