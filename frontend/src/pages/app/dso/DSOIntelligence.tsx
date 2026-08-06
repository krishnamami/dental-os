import { useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";

import DenialChart from "../../../components/DenialChart";
import LocationCards from "../../../components/LocationCards";
import PayerPerformance from "../../../components/PayerPerformance";
import RevenueAtRisk from "../../../components/RevenueAtRisk";
import TimeFilter, { type Period } from "../../../components/TimeFilter";
import Training from "../../../components/Training";
import { usePortfolio } from "../../../hooks/useApi";
import { useDemoLink } from "../../../hooks/useDemo";
import { formatCurrencyShort, formatPercent } from "../../../utils/format";

/**
 * H-01 — the group view.
 *
 * The one cross-tenant screen in the product. Aggregates only: approval
 * rates, condition counts and practice totals. No patient and no pre-D
 * id appears here, and /portfolio/summary does not return them — a DSO
 * operator is entitled to know Tampa denies more, not to read a Tampa
 * patient's chart.
 *
 * Tabs are URL-driven for the same reason as RevenueOps: the sidebar
 * links straight to /dso/denials and /dso/training.
 */
const TABS = [
  { id: "portfolio", label: "Portfolio", path: "/dso" },
  { id: "denials", label: "Denial patterns", path: "/dso/denials" },
  { id: "revenue", label: "Revenue", path: "/dso/revenue" },
  { id: "training", label: "Training", path: "/dso/training" },
] as const;

type TabId = (typeof TABS)[number]["id"];

function tabFromPath(pathname: string): TabId {
  const match = TABS.filter(
    (t) => t.path !== "/dso" && pathname.startsWith(t.path),
  )[0];
  return match?.id ?? "portfolio";
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

export default function DSOIntelligence() {
  const { pathname } = useLocation();
  const navigate = useNavigate();
  const demoLink = useDemoLink();
  const [period, setPeriod] = useState<Period>("30 days");
  const active = tabFromPath(pathname);

  const { data, isLoading, isError, error } = usePortfolio();

  if (isLoading) {
    return (
      <div className="animate-pulse space-y-4 p-4 sm:p-6">
        <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
          {[0, 1, 2, 3].map((i) => (
            <div key={i} className="h-[86px] rounded-xl bg-gray-100" />
          ))}
        </div>
        <div className="grid gap-3 lg:grid-cols-3">
          {[0, 1, 2].map((i) => (
            <div key={i} className="h-[230px] rounded-xl bg-gray-100" />
          ))}
        </div>
      </div>
    );
  }

  if (isError || !data) {
    return (
      <div className="p-4 sm:p-6">
        <div className="rounded-xl border border-red-200 bg-red-50 p-5">
          <p className="text-[13.5px] font-medium text-red-700">
            Could not load portfolio.
          </p>
          <p className="mt-1 text-[12.5px] text-red-600">
            {error instanceof Error ? error.message : "Unknown error"}
          </p>
          <p className="mt-2 text-[12px] text-red-500">
            Check that dental-os is running on :9010.
          </p>
        </div>
      </div>
    );
  }

  const s = data.summary;

  return (
    <div className="p-4 sm:p-6">
      <TimeFilter value={period} onChange={setPeriod} />

      <div className="mt-4 grid grid-cols-2 gap-3 lg:grid-cols-4">
        <Metric label="Practices" value={String(s.total_practices)} />
        <Metric label="Total pre-Ds" value={String(s.total_pre_ds)} />
        <Metric
          label="Group approval rate"
          value={formatPercent(s.overall_approval_rate)}
          tone={
            s.overall_approval_rate >= 0.5
              ? "text-accord-green-700"
              : "text-accord-amber-900"
          }
          note={`${s.total_approved} of ${s.total_pre_ds}`}
        />
        <Metric
          label="Patient responsibility"
          value={formatCurrencyShort(s.total_patient_responsibility)}
          note={`${s.total_denied} denied · ${s.total_pended} pended`}
        />
      </div>

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
        {active === "portfolio" && (
          <LocationCards
            practices={data.practices}
            denialReasons={data.top_denial_reasons}
          />
        )}
        {active === "denials" && (
          <div className="space-y-4">
            <DenialChart
              denialReasons={data.top_denial_reasons}
              practices={data.practices}
            />
            <PayerPerformance />
          </div>
        )}
        {active === "revenue" && <RevenueAtRisk portfolio={data} />}
        {active === "training" && <Training portfolio={data} />}
      </div>
    </div>
  );
}
