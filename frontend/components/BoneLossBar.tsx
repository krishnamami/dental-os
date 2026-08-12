/**
 * F-04 — the measurement against the rule, on one line.
 *
 * The whole product argument in a single graphic: a number read off a
 * radiograph, the ADA threshold it is judged against, and the margin
 * between them. A dentist can check it at a glance; a payer's medical
 * director can check it too.
 *
 * `measured` and `threshold` come from the signal's own `data` block
 * (bone_loss_mm, threshold) — they are never props a caller chose.
 *
 * The scale runs to whichever is larger: double the threshold, or the
 * measurement plus headroom. A fixed 8mm axis would squash a 3mm
 * threshold into the left edge and make a comfortable pass look
 * marginal.
 */
export default function BoneLossBar({
  measured,
  threshold,
  unit = "mm",
  label = "Measured (PA X-ray)",
  thresholdLabel = "ADA minimum",
  description,
}: {
  measured: number;
  threshold: number;
  unit?: string;
  label?: string;
  thresholdLabel?: string;
  description?: string;
}) {
  const met = measured >= threshold;
  const scale = Math.max(threshold * 2, measured * 1.35, threshold + 1);
  const pct = (v: number) => `${Math.min((v / scale) * 100, 100)}%`;

  return (
    <section className="rounded-xl border border-gray-200 bg-white p-4">
      <div className="flex items-center justify-between gap-3">
        <h3 className="text-[12.5px] font-semibold text-gray-900">
          Bone loss vs ADA threshold
        </h3>
        <span
          className={`rounded-full border px-2 py-0.5 text-[11px] font-semibold ${
            met
              ? "border-accord-green-100 bg-accord-green-50 text-accord-green-900"
              : "border-red-200 bg-red-50 text-red-700"
          }`}
        >
          {met ? "MET ✓" : "NOT MET ✗"}
        </span>
      </div>

      <div className="relative mt-6">
        {/* Track. Below the threshold is the zone that fails; from the
            threshold up to the measurement is the margin that passes. */}
        <div className="flex h-3 w-full overflow-hidden rounded-full bg-gray-100">
          <div
            style={{ width: pct(Math.min(threshold, measured)) }}
            className={met ? "bg-gray-300" : "bg-red-400"}
          />
          {met && (
            <div
              style={{ width: pct(measured - threshold) }}
              className="bg-accord-green-500"
            />
          )}
        </div>

        {/* Threshold marker */}
        <div
          className="absolute -top-1 flex flex-col items-center"
          style={{ left: pct(threshold), transform: "translateX(-50%)" }}
        >
          <span className="h-5 w-0.5 bg-gray-700" />
          <span className="mt-1 whitespace-nowrap text-[10.5px] font-semibold text-gray-700">
            {threshold.toFixed(1)}
            {unit}
          </span>
          <span className="whitespace-nowrap text-[9.5px] text-gray-500">
            {thresholdLabel}
          </span>
        </div>

        {/* Measured marker */}
        <div
          className="absolute -top-1 flex flex-col items-center"
          style={{ left: pct(measured), transform: "translateX(-50%)" }}
        >
          <span
            className={`h-5 w-0.5 ${met ? "bg-accord-green-700" : "bg-red-600"}`}
          />
          <span
            className={`mt-1 whitespace-nowrap text-[10.5px] font-semibold ${
              met ? "text-accord-green-900" : "text-red-700"
            }`}
          >
            {measured.toFixed(1)}
            {unit}
          </span>
          <span className="whitespace-nowrap text-[9.5px] text-gray-500">
            {label}
          </span>
        </div>
      </div>

      <p className="mt-14 text-[12.5px] leading-relaxed text-gray-600">
        {description ??
          `Bone loss of ${measured.toFixed(1)}${unit} ${
            met ? "exceeds" : "falls short of"
          } the ADA minimum of ${threshold.toFixed(1)}${unit}. Clinical criteria ${
            met ? "met" : "not met"
          }.`}
      </p>
    </section>
  );
}
