import { BookOpen } from "lucide-react";

/**
 * F-03 — the sentence that makes a decision defensible.
 *
 * RULE 13: every citation traces to a catalogue row. This renders what
 * the engine supplied and never composes a reference of its own — if a
 * signal carries no citation, nothing appears, because an invented
 * policy section is worse than a missing one in front of a payer's
 * medical director.
 *
 * `section` is passed separately because the API splits them: a
 * bundling signal carries payer_citation "Delta Dental PPO" and the
 * policy section lives in data.policy_section. Joining them here beats
 * hardcoding "§D.7.4", which is only right for this one rule.
 */
export default function ADACitation({
  citation,
  payerCitation,
  section,
}: {
  citation?: string | null;
  payerCitation?: string | null;
  section?: string | null;
}) {
  const payerLine = payerCitation
    ? section
      ? `${payerCitation} §${section}`
      : payerCitation
    : null;

  if (!citation && !payerLine) return null;

  return (
    <div className="space-y-2">
      {citation && (
        <div className="flex gap-2.5 rounded-r-lg border-y border-r border-l-4 border-gray-200 border-l-accord-green-500 bg-white px-3.5 py-2.5">
          <BookOpen
            size={14}
            className="mt-px flex-shrink-0 text-accord-green-700"
          />
          <div className="min-w-0">
            <p className="text-[10.5px] font-semibold uppercase tracking-wide text-accord-green-700">
              ADA citation
            </p>
            <p className="mt-0.5 text-[12.5px] leading-relaxed text-gray-700">
              {citation}
            </p>
          </div>
        </div>
      )}
      {payerLine && (
        <div className="flex gap-2.5 rounded-r-lg border-y border-r border-l-4 border-gray-200 border-l-accord-green-500 bg-white px-3.5 py-2.5">
          <BookOpen
            size={14}
            className="mt-px flex-shrink-0 text-accord-green-700"
          />
          <div className="min-w-0">
            <p className="text-[10.5px] font-semibold uppercase tracking-wide text-accord-green-700">
              Payer policy
            </p>
            <p className="mt-0.5 text-[12.5px] leading-relaxed text-gray-700">
              {payerLine}
            </p>
          </div>
        </div>
      )}
    </div>
  );
}
