import type { PayerDecision } from "../types/dental";

/**
 * The payer's verdict.
 *
 * A denial is amber-red, not alarm-red: it is an answer with an appeal
 * path behind it, not a system error. Nothing in this product uses red
 * to mean "something went wrong with the software".
 */
const TONE: Record<PayerDecision, string> = {
  approved: "border-accord-green-100 bg-accord-green-50 text-accord-green-900",
  pended: "border-amber-200 bg-accord-amber-50 text-accord-amber-900",
  denied: "border-red-200 bg-red-50 text-red-700",
};

export default function DecisionBadge({
  decision,
  className = "",
}: {
  decision: PayerDecision | string;
  className?: string;
}) {
  const tone = TONE[decision as PayerDecision] ?? "border-gray-200 bg-gray-50 text-gray-600";
  return (
    <span
      className={`inline-flex items-center rounded-full border px-2.5 py-0.5 text-[11.5px] font-semibold capitalize ${tone} ${className}`}
    >
      {decision}
    </span>
  );
}
