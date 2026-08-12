/**
 * F-05 — how much to trust a number read off a document.
 *
 * The bands are TRUST_FLOOR = 0.70, the threshold dental-os gates
 * evidence on (CONTEXT.md, PRD Gap #5). Below it a value does not
 * establish a finding; the document is treated as unreadable and
 * re-requested. That is why 0.70 is where amber becomes red here
 * rather than some rounder number.
 *
 * `method` is the engine's own vocabulary — deterministic means parsed
 * from structured data, ai_vision means Claude read the image,
 * caller_supplied means the value arrived with the document and was
 * never extracted at all. Worth showing: a 0.95 that nobody verified
 * is not a 0.95 that a parser produced.
 */
const TRUST_FLOOR = 0.7;

export default function ConfidenceBadge({
  confidence,
  method,
  className = "",
}: {
  confidence: number;
  method?: string | null;
  className?: string;
}) {
  const pct = Math.round(confidence * 100);

  let tone: string;
  let label: string;
  let tip: string;

  if (confidence >= 1) {
    tone = "border-accord-green-100 bg-accord-green-50 text-accord-green-900";
    label = "Deterministic";
    tip = "Extracted from structured data — no AI inference required";
  } else if (confidence >= 0.9) {
    tone = "border-accord-green-100 bg-accord-green-50 text-accord-green-900";
    label = "High confidence";
    tip = "High-quality extraction, comfortably above the 0.70 trust floor";
  } else if (confidence >= TRUST_FLOOR) {
    tone = "border-amber-200 bg-accord-amber-50 text-accord-amber-900";
    label = "Medium confidence";
    tip = "Above the 0.70 trust floor but worth a manual check";
  } else {
    tone = "border-red-200 bg-red-50 text-red-700";
    label = "Low confidence";
    tip =
      "Below the 0.70 trust floor — this value does not establish a finding. Re-scan recommended.";
  }

  return (
    <span className={`inline-flex flex-col items-start gap-0.5 ${className}`}>
      <span
        title={tip}
        className={`inline-flex items-center rounded-full border px-2 py-0.5 text-[11px] font-semibold ${tone}`}
      >
        {pct}% · {label}
        {confidence < TRUST_FLOOR && " ⚠"}
      </span>
      {method && (
        <span className="font-mono text-[10px] text-gray-400">{method}</span>
      )}
    </span>
  );
}
