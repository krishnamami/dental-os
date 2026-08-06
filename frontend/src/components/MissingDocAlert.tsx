import { useRef, useState } from "react";
import { FileX } from "lucide-react";

import type { Signal } from "../types/dental";

/**
 * F-06 — required documents that are not on file.
 *
 * Built from the DOC_*_MISSING signals rather than a list of document
 * names, so the reason and the SLA come from the engine. Renders
 * nothing when nothing is missing, which is most of Group A.
 *
 * The upload button opens a file picker and then says the feature does
 * not exist. That is deliberate: a button that silently does nothing
 * reads as a bug, and one that claims success would be a lie about a
 * document a payer will later ask for.
 */
const MISSING_PREFIX = "DOC_";

export function missingDocSignals(signals: Signal[]): Signal[] {
  return signals.filter(
    (s) =>
      s.signal_code.startsWith(MISSING_PREFIX) &&
      /_MISSING$|_REQUIRED$|_NEEDED$/.test(s.signal_code),
  );
}

export default function MissingDocAlert({ signals }: { signals: Signal[] }) {
  const missing = missingDocSignals(signals);
  const inputRef = useRef<HTMLInputElement>(null);
  const [notice, setNotice] = useState("");

  if (missing.length === 0) return null;

  return (
    <div className="rounded-xl border border-red-200 bg-red-50 p-4">
      <div className="flex items-start gap-2.5">
        <FileX size={16} className="mt-px flex-shrink-0 text-red-600" />
        <div className="min-w-0 flex-1">
          <h2 className="text-[13px] font-semibold text-red-700">
            Required documents missing
          </h2>
          <ul className="mt-2 space-y-1.5">
            {missing.map((s) => (
              <li key={s.signal_code} className="text-[12.5px] text-red-700">
                <span className="font-mono text-[11px] font-semibold">
                  {s.signal_code}
                </span>
                <span className="mt-0.5 block leading-relaxed text-red-700/90">
                  {s.finding}
                </span>
                {s.sla_hours != null && (
                  <span className="mt-0.5 block text-[11px] text-red-600">
                    {s.sla_hours}h SLA · {s.assignee?.replace(/_/g, " ")}
                  </span>
                )}
              </li>
            ))}
          </ul>

          <div className="mt-3 flex flex-wrap items-center gap-2">
            <input
              ref={inputRef}
              type="file"
              className="hidden"
              onChange={() =>
                setNotice(
                  "Upload feature coming soon — send the document through your usual channel for now.",
                )
              }
            />
            <button
              type="button"
              onClick={() => inputRef.current?.click()}
              className="rounded-lg border border-red-300 bg-white px-3 py-1.5 text-[12px] font-medium text-red-700 transition hover:bg-red-50"
            >
              Upload document
            </button>
            {notice && (
              <span className="text-[11.5px] text-red-600">{notice}</span>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
