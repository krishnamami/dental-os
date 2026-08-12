import { AlertTriangle } from "lucide-react";

import type { ProcedureCost } from "../types/dental";

/**
 * E-04 — the ceramic-to-metal downgrade, said out loud.
 *
 * Renders nothing when no procedure is downgraded, which is most cases.
 * When it does render, the note comes from the API — coverage_resolver
 * writes it with the actual target code — rather than being composed
 * here from a guess about which code the plan pays at.
 */
export default function DowngradeAlert({
  procedures,
}: {
  procedures: ProcedureCost[];
}) {
  const downgraded = procedures.filter((p) => p.downgrade_applied);
  if (downgraded.length === 0) return null;

  return (
    <div className="space-y-2">
      {downgraded.map((p) => (
        <div
          key={p.cdt_code}
          className="flex gap-2.5 rounded-lg border border-amber-200 bg-accord-amber-50 px-3.5 py-3"
        >
          <AlertTriangle
            size={15}
            className="mt-px flex-shrink-0 text-accord-amber-900"
          />
          <div className="min-w-0">
            <p className="text-[12.5px] font-semibold text-accord-amber-900">
              {p.cdt_code} is reimbursed at a lower code&rsquo;s rate
            </p>
            <p className="mt-1 text-[12.5px] leading-relaxed text-accord-amber-900/90">
              {/* The engine's own wording, naming the real target code. */}
              {p.downgrade_note ??
                `${p.cdt_code} is paid at a downgraded rate under this plan; the difference is the patient's responsibility.`}
            </p>
          </div>
        </div>
      ))}
    </div>
  );
}
