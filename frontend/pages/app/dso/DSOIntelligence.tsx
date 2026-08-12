import { AlertTriangle, Building2, Info, TrendingDown } from "lucide-react";
import { useMemo } from "react";
import { useLocation, useNavigate } from "react-router-dom";

import { usePortfolio } from "../../../hooks/useApi";
import { useDemoLink } from "../../../hooks/useDemo";
import type { DenialReason, Portfolio } from "../../../types/dental";
import { formatCurrency, formatCurrencyShort } from "../../../utils/format";
import {
  MIN_RATE_DENOMINATOR,
  causeFor,
  rateIsMeaningful,
} from "../../../utils/portfolioCauses";

/**
 * H-01 — the group view, for an owner.
 *
 * ── WHAT CHANGED AND WHY ──────────────────────────────────────────────
 * This screen used to answer "how are my practices doing", which nobody
 * acts on. It answers the version with a verb now: which practice is
 * losing the most money, to what, and who to talk to.
 *
 * Concretely, four things went:
 *   · location CARDS became one comparison TABLE — cards invite reading
 *     each practice alone, a table is what makes one row look wrong
 *   · a hand-counted payer table (PayerPerformance.tsx, counted on
 *     2026-08-06 and shown to every user regardless of tenant) became
 *     the live payer_performance rows
 *   · signal codes became causes with an owning team
 *   · the Revenue and Training tabs went. Revenue restated the header,
 *     and Training invented a recommendation from a single snapshot.
 *
 * ── SCOPE IS THE SERVER'S JOB ─────────────────────────────────────────
 * /portfolio/summary is scoped by tenant_ownership. This file renders
 * whatever practices come back and never filters by tenant itself: an
 * owner of two gets two rows, an owner of one gets one row, and the
 * empty case is a real answer rather than an error. There is no
 * branch here on how many practices there are.
 *
 * ── READ-ONLY, SAID OUT LOUD ──────────────────────────────────────────
 * dso_owner is denied all four write capabilities in the API. The
 * banner at the bottom says so in words rather than leaving the owner
 * to discover it by clicking something that fails.
 */

const TABS = [
  { id: "compare", label: "Compare practices", path: "/dso" },
  { id: "causes", label: "What's holding cases up", path: "/dso/causes" },
  { id: "payers", label: "By payer", path: "/dso/payers" },
] as const;

type TabId = (typeof TABS)[number]["id"];

function tabFromPath(pathname: string): TabId {
  // Longest-match first so /dso/causes does not resolve to /dso.
  const hit = TABS.filter(
    (t) => t.path !== "/dso" && pathname.startsWith(t.path),
  )[0];
  if (hit) return hit.id;
  // The old tab paths, still linked from bookmarks and the last
  // deploy's sidebar. /dso/denials was this same content.
  if (pathname.startsWith("/dso/denials")) return "causes";
  if (pathname.startsWith("/dso/revenue")) return "compare";
  if (pathname.startsWith("/dso/training")) return "causes";
  return "compare";
}

const stateOf = (address: string) =>
  address.match(/,\s*[^,]*?\b([A-Z]{2})\b\s*\d{5}/)?.[1] ?? "";

/**
 * A rate, or a dash and the raw count.
 *
 * The dash is not a missing value — it is the honest answer. See
 * MIN_RATE_DENOMINATOR for the argument. The count is always shown, so
 * the row still carries information when the percentage cannot.
 */
function Rate({ n, of }: { n: number; of: number }) {
  const meaningful = rateIsMeaningful(of);
  return (
    <span className="whitespace-nowrap">
      <span
        className={
          meaningful
            ? "font-semibold text-gray-900"
            : "font-semibold text-gray-400"
        }
      >
        {meaningful && of > 0 ? `${Math.round((n / of) * 100)}%` : "—"}
      </span>
      <span className="ml-1.5 text-[11.5px] text-gray-500">
        {n}/{of}
      </span>
    </span>
  );
}

function Footnote({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex gap-2.5 border-t border-gray-200 bg-gray-50 px-4 py-3 text-[12.5px] text-gray-600">
      <Info size={15} className="mt-0.5 flex-shrink-0" />
      <span>{children}</span>
    </div>
  );
}

// ── Tab 1 ─────────────────────────────────────────────────────────────

function ComparePractices({ data }: { data: Portfolio }) {
  const practices = [...data.practices].sort(
    (a, b) => b.total_pre_ds - a.total_pre_ds,
  );
  const thin = practices.filter((p) => !rateIsMeaningful(p.total_pre_ds));
  const biggest = practices[0];

  return (
    <div className="overflow-hidden rounded-xl border border-gray-200 bg-white">
      <div className="overflow-x-auto">
        <table className="w-full min-w-[640px] text-[13px]">
          <thead>
            <tr className="bg-gray-50 text-gray-700">
              <th className="px-4 py-3 text-left font-semibold">Practice</th>
              <th className="px-4 py-3 text-right font-semibold">Pre-Ds</th>
              <th className="px-4 py-3 text-right font-semibold">Cleared</th>
              <th className="px-4 py-3 text-right font-semibold">Waiting</th>
              <th className="px-4 py-3 text-right font-semibold">
                Patient owes
              </th>
              <th className="px-4 py-3 text-right font-semibold">
                Evidence quality
              </th>
            </tr>
          </thead>
          <tbody>
            {practices.map((p) => (
              <tr key={p.tenant_id} className="border-t border-gray-200">
                <td className="px-4 py-3.5">
                  <div className="flex items-start gap-2">
                    <Building2
                      size={15}
                      className="mt-0.5 flex-shrink-0 text-gray-400"
                    />
                    <div className="min-w-0">
                      <div className="font-semibold text-gray-900">
                        {p.practice_name}
                      </div>
                      <div className="mt-0.5 text-[11.5px] text-gray-500">
                        {stateOf(p.address) || p.address}
                      </div>
                    </div>
                  </div>
                </td>
                <td className="px-4 py-3.5 text-right tabular-nums">
                  {p.total_pre_ds}
                </td>
                <td className="px-4 py-3.5 text-right">
                  <Rate n={p.approved} of={p.total_pre_ds} />
                </td>
                <td className="px-4 py-3.5 text-right tabular-nums">
                  {p.pended + p.denied}
                </td>
                <td className="px-4 py-3.5 text-right tabular-nums">
                  {p.cost_estimates_available
                    ? formatCurrency(p.total_patient_pays)
                    : "—"}
                </td>
                <td className="px-4 py-3.5 text-right">
                  {/* Same denominator rule as the approval rate. An
                      average criteria score over five cases is one
                      case's evidence, not a practice's habits. */}
                  {rateIsMeaningful(p.total_pre_ds) ? (
                    <span className="font-semibold tabular-nums text-gray-900">
                      {Math.round(p.avg_criteria_score * 100)}%
                    </span>
                  ) : (
                    <span className="font-semibold text-gray-400">—</span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {thin.length > 0 && (
        <Footnote>
          {thin.map((p) => p.practice_name).join(" and ")} shows no rate —{" "}
          {thin.length === 1 ? "it has" : "they have"}{" "}
          {thin.map((p) => p.total_pre_ds).join(" and ")} pre-D
          {thin.length === 1 && thin[0].total_pre_ds === 1 ? "" : "s"}, under
          the {MIN_RATE_DENOMINATOR} it takes for a percentage to mean
          anything. One decision either way moves a rate off{" "}
          {thin[0].total_pre_ds} cases by{" "}
          {Math.round(100 / thin[0].total_pre_ds)} points.
          {/* Only worth naming a comparison when there is something to
              compare against. With one practice — or with every
              practice below the threshold — the old wording had Dallas
              comparing badly against Dallas. */}
          {biggest && !thin.includes(biggest) ? (
            <>
              {" "}
              Against {biggest.practice_name}'s {biggest.total_pre_ds} that
              would read as a real difference when it is not. The counts are
              the comparable number.
            </>
          ) : (
            <> The counts are the comparable number.</>
          )}
        </Footnote>
      )}
    </div>
  );
}

// ── Tab 2 ─────────────────────────────────────────────────────────────

interface Grouped {
  code: string;
  total: number;
  rows: DenialReason[];
}

function groupCauses(reasons: DenialReason[]): Grouped[] {
  const map = new Map<string, Grouped>();
  for (const r of reasons) {
    const g = map.get(r.condition_code) ?? {
      code: r.condition_code,
      total: 0,
      rows: [],
    };
    g.total += r.frequency;
    g.rows.push(r);
    map.set(r.condition_code, g);
  }
  return [...map.values()]
    .map((g) => ({
      ...g,
      rows: [...g.rows].sort((a, b) => b.frequency - a.frequency),
    }))
    .sort((a, b) => b.total - a.total);
}

function Causes({ data }: { data: Portfolio }) {
  const groups = useMemo(
    () => groupCauses(data.top_denial_reasons),
    [data.top_denial_reasons],
  );
  const nameOf = (tid: string) =>
    data.practices.find((p) => p.tenant_id === tid)?.practice_name ?? tid;
  const shortOf = (tid: string) => nameOf(tid).split(" ")[0];

  /**
   * ⚠ THE LIST IS A TOP-20 CUT ACROSS THE GROUP, NOT A PER-PRACTICE ONE.
   *
   * Today every one of Shyam's 20 rows is Suwanee's — Tampa's five
   * pre-Ds put its conditions below the cut, so Tampa appears nowhere
   * on this tab. Left unsaid, the screen reads as "Tampa has nothing
   * holding cases up", which is not what the data says.
   *
   * The deleted DenialChart carried this same footnote for the same
   * reason. It travels with the data, not with the component.
   */
  const present = new Set(data.top_denial_reasons.map((r) => r.tenant_id));
  const absent = data.practices.filter((p) => !present.has(p.tenant_id));

  if (groups.length === 0) {
    return (
      <div className="rounded-xl border border-gray-200 bg-white p-6 text-[13px] text-gray-500">
        Nothing is holding cases up across your practices right now.
      </div>
    );
  }

  return (
    <div className="space-y-3">
      {groups.map(({ code, total, rows }) => {
        const cause = causeFor(code);
        /**
         * Concentration, not frequency, is the insight: a cause spread
         * evenly is a payer rule, a cause sitting in one location is a
         * habit, and only one of those is worth a conversation.
         *
         * ⚠ IT TAKES AT LEAST TWO PRACTICES TO SAY "CONCENTRATED".
         * The first cut fired on rows.length >= 1, which meant every
         * card on this tab carried the same amber banner — twenty
         * identical "concentrated at Suwanee" callouts, because Tampa
         * is not in the top-20 cut at all. With one practice in the
         * data you cannot tell concentration from absence, and an
         * insight asserted twenty times is not an insight.
         */
        const concentrated =
          rows.length > 1 && rows[0].frequency / total > 0.75;
        return (
          <div
            key={code}
            className="rounded-xl border border-gray-200 bg-white p-5"
          >
            <div className="flex flex-wrap items-start justify-between gap-4">
              <div className="max-w-[520px]">
                <div className="text-[14px] font-semibold text-gray-900">
                  {cause.label}
                </div>
                {cause.cost && (
                  <p className="mt-1 text-[13px] leading-relaxed text-gray-500">
                    {cause.cost}
                  </p>
                )}
                <div className="mt-2 text-[11.5px] text-gray-500">
                  Owned by{" "}
                  <span className="font-medium text-gray-700">
                    {cause.owner}
                  </span>
                </div>
              </div>
              <div className="text-right">
                <div className="text-[22px] font-bold leading-none tabular-nums text-gray-900">
                  {total}
                </div>
                <div className="mt-1 text-[11.5px] text-gray-500">
                  case{total === 1 ? "" : "s"} affected
                </div>
              </div>
            </div>

            {/* One bar at 100% tells the reader nothing they did not
                read in the count above it. */}
            {rows.length > 1 && (
              <div className="mt-4 space-y-2">
                {rows.map((r) => (
                  <div key={r.tenant_id} className="flex items-center gap-3">
                    <span className="w-[80px] flex-shrink-0 truncate text-[11.5px] text-gray-500">
                      {shortOf(r.tenant_id)}
                    </span>
                    <span className="h-2 flex-1 overflow-hidden rounded-full bg-gray-100">
                      <span
                        className="block h-full rounded-full bg-accord-green-700"
                        style={{ width: `${(r.frequency / total) * 100}%` }}
                      />
                    </span>
                    <span className="w-7 flex-shrink-0 text-right text-[11.5px] tabular-nums text-gray-500">
                      {r.frequency}
                    </span>
                  </div>
                ))}
              </div>
            )}

            {concentrated && (
              <div className="mt-4 flex gap-2.5 rounded-lg border border-amber-200 bg-amber-50 p-3 text-[12.5px] text-accord-amber-900">
                <TrendingDown size={15} className="mt-0.5 flex-shrink-0" />
                <span>
                  Concentrated at {nameOf(rows[0].tenant_id)} —{" "}
                  {rows[0].frequency} of {total}. A pattern in one location is
                  usually a habit, not a payer rule. Worth asking the team
                  there before changing anything everywhere.
                </span>
              </div>
            )}
          </div>
        );
      })}

      {absent.length > 0 && (
        <div className="overflow-hidden rounded-xl border border-gray-200 bg-white">
          <Footnote>
            {absent.map((p) => p.practice_name).join(" and ")}{" "}
            {absent.length === 1 ? "does" : "do"} not appear above. This list
            is the twenty most frequent causes across the whole group, and{" "}
            {absent.length === 1 ? "a practice" : "practices"} with{" "}
            {absent.map((p) => p.total_pre_ds).join(" and ")} pre-D
            {absent.length === 1 && absent[0].total_pre_ds === 1 ? "" : "s"}{" "}
            {absent.length === 1 ? "falls" : "fall"} below the cut —{" "}
            {absent.length === 1 ? "it is" : "they are"} not free of blocked
            cases.
          </Footnote>
        </div>
      )}
    </div>
  );
}

// ── Tab 3 ─────────────────────────────────────────────────────────────

function ByPayer({ data }: { data: Portfolio }) {
  const rows = [...data.payer_performance].sort((a, b) => b.total - a.total);
  const nameOf = (tid: string) =>
    data.practices.find((p) => p.tenant_id === tid)?.practice_name ?? tid;

  if (rows.length === 0) {
    return (
      <div className="rounded-xl border border-gray-200 bg-white p-6 text-[13px] text-gray-500">
        No payer activity across your practices yet.
      </div>
    );
  }

  return (
    <div className="overflow-hidden rounded-xl border border-gray-200 bg-white">
      <div className="overflow-x-auto">
        <table className="w-full min-w-[560px] text-[13px]">
          <thead>
            <tr className="bg-gray-50 text-gray-700">
              <th className="px-4 py-3 text-left font-semibold">Payer</th>
              <th className="px-4 py-3 text-left font-semibold">Practice</th>
              <th className="px-4 py-3 text-right font-semibold">Pre-Ds</th>
              <th className="px-4 py-3 text-right font-semibold">Approved</th>
              <th className="px-4 py-3 text-right font-semibold">Denied</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr
                key={`${r.tenant_id}:${r.payer_id}`}
                className="border-t border-gray-200"
              >
                <td className="px-4 py-3 font-medium text-gray-900">
                  {r.payer_name}
                </td>
                <td className="px-4 py-3 text-gray-500">
                  {nameOf(r.tenant_id)}
                </td>
                <td className="px-4 py-3 text-right tabular-nums">{r.total}</td>
                <td className="px-4 py-3 text-right tabular-nums">
                  {r.approved}
                </td>
                <td
                  className={`px-4 py-3 text-right tabular-nums ${
                    r.denied > 0 ? "text-accord-amber-900" : "text-gray-400"
                  }`}
                >
                  {r.denied}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <Footnote>
        Counts, not rates. Most rows here are a handful of cases — a
        percentage would look authoritative and mean very little. The API
        returns no rate for this table for the same reason.
      </Footnote>
    </div>
  );
}

// ── Page ──────────────────────────────────────────────────────────────

export default function DSOIntelligence() {
  const { pathname } = useLocation();
  const navigate = useNavigate();
  const demoLink = useDemoLink();
  const active = tabFromPath(pathname);

  const { data, isLoading, isError, error } = usePortfolio();

  if (isLoading) {
    return (
      <div className="animate-pulse space-y-4 p-4 sm:p-6">
        <div className="h-[104px] rounded-xl bg-gray-100" />
        <div className="h-9 w-2/3 rounded-lg bg-gray-100" />
        <div className="h-[260px] rounded-xl bg-gray-100" />
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
        </div>
      </div>
    );
  }

  const s = data.summary;

  // An owner between practices. Not an error, and not a 403 — the
  // server answers with zero practices and this says so.
  if (data.practices.length === 0) {
    return (
      <div className="p-4 sm:p-6">
        <div className="rounded-xl border border-gray-200 bg-white p-6">
          <h1 className="text-[18px] font-bold text-gray-900">
            No practices yet
          </h1>
          <p className="mt-1.5 text-[13px] text-gray-500">
            Your account does not own a practice at the moment. Once one is
            assigned it will appear here.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="p-4 sm:p-6">
      {/* The money question, first and largest. */}
      <div className="rounded-xl border border-gray-200 bg-white p-5">
        <div className="flex flex-wrap items-start gap-5">
          <div className="min-w-[220px] flex-1">
            <div className="text-[11px] uppercase tracking-wide text-gray-500">
              Sitting with payers
            </div>
            <div className="mt-1 text-[26px] font-bold leading-none text-accord-amber-900">
              {formatCurrencyShort(s.total_patient_revenue_at_risk)}
            </div>
            <div className="mt-1.5 text-[12.5px] text-gray-500">
              {s.total_pended} pended · {s.total_denied} denied · across{" "}
              {s.total_practices} practice
              {s.total_practices === 1 ? "" : "s"}
            </div>
          </div>
          <div className="hidden w-px self-stretch bg-gray-200 md:block" />
          <div className="min-w-[220px] flex-1">
            <div className="text-[11px] uppercase tracking-wide text-gray-500">
              Cleared without intervention
            </div>
            <div className="mt-1 text-[26px] font-bold leading-none text-accord-green-700">
              {s.total_approved}
              <span className="text-[17px] font-medium text-gray-500">
                {" "}
                of {s.total_pre_ds}
              </span>
            </div>
            <div className="mt-1.5 text-[12.5px] text-gray-500">
              The rest needed a person, or are still waiting on one
            </div>
          </div>
        </div>
        {s.practices_missing_cost_estimates.length > 0 && (
          <p className="mt-3 border-t border-gray-100 pt-3 text-[11.5px] text-gray-500">
            No cost estimates on file for{" "}
            {s.practices_missing_cost_estimates.join(", ")} — their patient
            balances are missing from the figure above rather than counted as
            zero.
          </p>
        )}
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
        {active === "compare" && <ComparePractices data={data} />}
        {active === "causes" && <Causes data={data} />}
        {active === "payers" && <ByPayer data={data} />}
      </div>

      {/* What he cannot do, said rather than discovered by clicking. */}
      <div className="mt-5 flex gap-3 rounded-xl border border-accord-green-500/40 bg-accord-green-50 p-4">
        <AlertTriangle
          size={16}
          className="mt-0.5 flex-shrink-0 text-accord-green-700"
        />
        <div className="text-[12.5px] leading-relaxed text-accord-green-900">
          <span className="font-semibold">This view is read-only.</span>{" "}
          Individual patient records stay with the team treating them. To act
          on anything here, ask the practice — every cause above names who
          owns it.
        </div>
      </div>
    </div>
  );
}
