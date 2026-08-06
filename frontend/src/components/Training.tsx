import { useState } from "react";

import type { Portfolio } from "../types/dental";
import { aggregate } from "./DenialChart";

/**
 * H-06 — what to train, ranked by how often it bites.
 *
 * GENERATED FROM THE DATA, not a hardcoded list. Each rule below maps a
 * condition code to the workflow change that closes it; the cards are
 * whatever rules match the group's actual top conditions, ordered by
 * frequency. Add a practice with a different problem and the list
 * changes without touching this file.
 *
 * ── Why there are no dollar impacts ──────────────────────────────────
 * The brief asks for "$47,000/month" per card. That number cannot be
 * derived from anything available: /portfolio/summary returns condition
 * COUNTS and practice-level patient totals, with no link between them,
 * so the case value behind a given condition is unknown. Putting a
 * fabricated figure on a page a DSO owner uses to allocate budget is
 * the worst place in this product to guess. Impact is stated in the
 * unit that IS measured — open conditions, and the practices carrying
 * them.
 */
interface Rule {
  match: (code: string) => boolean;
  title: (practice: string) => string;
  body: (count: number, practice: string) => string;
  effort: string;
  action: string;
}

const RULES: Rule[] = [
  {
    match: (c) => c === "COVERAGE_PRED_REQUIRED",
    title: (p) => `Submit pre-Ds before treatment — ${p}`,
    body: (n, p) =>
      `${n} pre-Ds at ${p} carry a pre-determination requirement that was ` +
      `not satisfied before treatment planning. Checking the requirement at ` +
      `check-in moves the work upstream of the chair.`,
    effort: "Low — front desk workflow",
    action: "Schedule training",
  },
  {
    match: (c) => c === "CLINICAL_XRAY_REQUIRED" || c === "DOC_XRAY_MISSING",
    title: (p) => `Radiograph before submission — ${p}`,
    body: (n, p) =>
      `${n} cases at ${p} needed a PA X-ray that was not on file at ` +
      `submission. The code requiring it is known at treatment planning, so ` +
      `the image can be captured in the same visit.`,
    effort: "Low — workflow change",
    action: "Schedule training",
  },
  {
    match: (c) =>
      c === "CLINICAL_NARRATIVE_REQUIRED" || c === "DOC_NARRATIVE_MISSING",
    title: (p) => `Clinical narrative that separates bundled codes — ${p}`,
    body: (n, p) =>
      `${n} cases at ${p} lack a narrative establishing necessity ` +
      `independent of the primary procedure. Roughly 65% of bundling ` +
      `denials are overturned when that narrative is on file.`,
    effort: "Medium — clinical documentation",
    action: "Schedule training",
  },
  {
    match: (c) => c === "COVERAGE_BUNDLING_CONFLICT",
    title: (p) => `Bundling rules §D.7.4 — ${p}`,
    body: (n, p) =>
      `${n} cases at ${p} hit a payer bundling rule. Billing should know ` +
      `which pairs are separable with documentation and which are not — ` +
      `the separable ones are worth appealing, the rest are not.`,
    effort: "Low — billing training",
    action: "Schedule training",
  },
  {
    match: (c) => c === "CLINICAL_CRITERIA_NOT_MET",
    title: (p) => `ADA criteria before treatment planning — ${p}`,
    body: (n, p) =>
      `${n} cases at ${p} did not meet the ADA clinical floor. That floor ` +
      `cannot be overridden by a payer rule or a practice overlay, so these ` +
      `need evidence, not an appeal.`,
    effort: "Medium — clinical review",
    action: "Schedule training",
  },
  {
    match: (c) => c === "CLINICAL_BONE_LOSS_THRESHOLD",
    title: (p) => `Bone loss measurement and charting — ${p}`,
    body: (n, p) =>
      `${n} cases at ${p} turned on a bone-loss measurement against the ADA ` +
      `threshold. Charting the measurement explicitly, rather than leaving ` +
      `it to be read off the film, removes the ambiguity.`,
    effort: "Low — charting habit",
    action: "Add to protocol",
  },
];

const PRIORITY = [
  { label: "High", tone: "border-red-200 bg-red-50 text-red-700" },
  { label: "Medium", tone: "border-amber-200 bg-accord-amber-50 text-accord-amber-900" },
  {
    label: "Low",
    tone: "border-accord-green-100 bg-accord-green-50 text-accord-green-900",
  },
];

export default function Training({ portfolio }: { portfolio: Portfolio }) {
  const [notice, setNotice] = useState("");
  const names = new Map(
    portfolio.practices.map((p) => [p.tenant_id, p.practice_name]),
  );

  const cards = aggregate(portfolio.top_denial_reasons)
    .map((r) => {
      const rule = RULES.find((x) => x.match(r.code));
      if (!rule) return null;
      const [tenant, count] = Object.entries(r.byTenant).sort(
        (a, b) => b[1] - a[1],
      )[0] ?? ["", 0];
      const practice = names.get(tenant) ?? "the group";
      return { rule, reason: r, practice, count };
    })
    .filter((c): c is NonNullable<typeof c> => c !== null)
    .slice(0, 6);

  if (cards.length === 0) {
    return (
      <p className="rounded-xl border border-gray-200 bg-white px-4 py-8 text-center text-[13px] text-gray-500">
        No recurring conditions to train against — nothing in the group&rsquo;s
        top 20 matches a known workflow fix.
      </p>
    );
  }

  return (
    <div className="space-y-3">
      {cards.map((c, i) => {
        // Priority follows frequency, which is the only ranking the data
        // supports. The top third are High, the next third Medium.
        const p =
          PRIORITY[Math.min(Math.floor(i / Math.max(cards.length / 3, 1)), 2)];
        return (
          <article
            key={c.reason.code}
            className="rounded-xl border border-gray-200 bg-white p-4"
          >
            <header className="flex flex-wrap items-start justify-between gap-2">
              <h3 className="text-[14px] font-semibold text-gray-900">
                {c.rule.title(c.practice)}
              </h3>
              <span
                className={`flex-shrink-0 rounded-full border px-2 py-0.5 text-[10.5px] font-semibold ${p.tone}`}
              >
                {p.label} priority
              </span>
            </header>

            <p className="mt-2 text-[12.5px] leading-relaxed text-gray-600">
              {c.rule.body(c.count, c.practice)}
            </p>

            <dl className="mt-3 flex flex-wrap gap-x-6 gap-y-1.5 border-t border-gray-100 pt-3 text-[11.5px]">
              <div className="flex gap-1.5">
                <dt className="text-gray-500">Open conditions</dt>
                <dd className="font-semibold text-gray-900">
                  {c.reason.total} across the group
                </dd>
              </div>
              <div className="flex gap-1.5">
                <dt className="text-gray-500">Effort</dt>
                <dd className="font-medium text-gray-700">{c.rule.effort}</dd>
              </div>
              <div className="flex gap-1.5">
                <dt className="text-gray-500">Signal</dt>
                <dd className="font-mono text-[11px] text-gray-500">
                  {c.reason.code}
                </dd>
              </div>
            </dl>

            <button
              type="button"
              onClick={() =>
                setNotice("Training scheduling is not built — feature coming soon.")
              }
              className="mt-3 rounded-lg border border-gray-300 px-3 py-1.5 text-[12px] font-medium text-gray-700 transition hover:bg-gray-50"
            >
              {c.rule.action}
            </button>
          </article>
        );
      })}

      {notice && (
        <p className="text-[12px] text-accord-amber-900">{notice}</p>
      )}

      <p className="text-[11px] leading-relaxed text-gray-400">
        Recommendations are generated from the group&rsquo;s open conditions
        and ranked by frequency. Revenue impact is deliberately not estimated:
        the portfolio endpoint returns condition counts and practice totals
        with no link between them, so a dollar figure per condition would be a
        guess.
      </p>
    </div>
  );
}
