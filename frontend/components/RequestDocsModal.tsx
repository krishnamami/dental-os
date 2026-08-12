import { useEffect, useRef, useState } from "react";

import ActionError from "./ActionError";
import { X } from "lucide-react";

/**
 * E-09 — ask a patient for the documents a pre-D is waiting on.
 *
 * ⚠ NOTHING IS SENT. There is no document-request endpoint in
 * dental-os, no message path to a patient, and no record written. The
 * confirmation says "queued" rather than "sent" for that reason, and
 * the modal says so on its face — a front desk that believes a request
 * went out and stops chasing it is worse off than one that never
 * clicked the button.
 *
 * Wiring it needs three things that do not exist yet: a request table,
 * a delivery channel, and a place on the pre-D to show what is
 * outstanding.
 */
const DOCUMENTS = [
  "PA X-ray (periapical)",
  "Perio chart",
  "Clinical narrative",
  "Insurance card copy",
  "Photo ID",
  "Referral letter",
];

const BRAND_GREEN = "#0F4D37";

export default function RequestDocsModal({
  patientName,
  onClose,
  onSend,
}: {
  patientName: string;
  onClose: () => void;
  /** Rejects if the request did not land; the modal stays open. */
  onSend: (documents: string[], note: string) => Promise<void>;
}) {
  const [checked, setChecked] = useState<Set<string>>(new Set());
  const [note, setNote] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const closeRef = useRef(onClose);
  closeRef.current = onClose;

  // Escape closes, and body scroll locks so the page behind does not
  // slide under a thumb on a phone.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") closeRef.current();
    };
    document.addEventListener("keydown", onKey);
    const previous = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = previous;
    };
  }, []);

  function toggle(doc: string) {
    setChecked((prev) => {
      const next = new Set(prev);
      if (next.has(doc)) next.delete(doc);
      else next.add(doc);
      return next;
    });
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-black/50 sm:items-center sm:p-4"
      onClick={onClose}
      role="presentation"
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="request-docs-title"
        onClick={(e) => e.stopPropagation()}
        className="relative min-h-full w-full max-w-md bg-white p-5 shadow-xl sm:min-h-0 sm:rounded-xl sm:p-6"
      >
        <button
          type="button"
          onClick={onClose}
          aria-label="Close"
          className="absolute right-4 top-4 rounded-lg p-1.5 text-gray-400 transition hover:bg-gray-100 hover:text-gray-600"
        >
          <X size={18} />
        </button>

        <h2
          id="request-docs-title"
          className="text-[17px] font-semibold text-gray-900"
        >
          Request documents
        </h2>
        <p className="mt-1 text-[12.5px] text-gray-500">
          Select documents needed from {patientName}
        </p>

        <fieldset className="mt-4">
          <legend className="sr-only">Documents</legend>
          <ul className="space-y-1">
            {DOCUMENTS.map((doc) => (
              <li key={doc}>
                <label className="flex cursor-pointer items-center gap-2.5 rounded-lg px-2 py-2 transition hover:bg-gray-50">
                  <input
                    type="checkbox"
                    checked={checked.has(doc)}
                    onChange={() => toggle(doc)}
                    className="h-4 w-4 rounded border-gray-300 text-accord-green-900 focus:ring-accord-green-500"
                  />
                  <span className="text-[13px] text-gray-800">{doc}</span>
                </label>
              </li>
            ))}
          </ul>
        </fieldset>

        <label className="mt-3 block">
          <span className="mb-1 block text-[12px] font-medium text-gray-700">
            Note (optional)
          </span>
          <textarea
            rows={3}
            value={note}
            onChange={(e) => setNote(e.target.value)}
            placeholder="Add a note for the patient..."
            className="w-full resize-none rounded-lg border border-gray-300 px-3 py-2 text-[13px] text-gray-900 placeholder-gray-400 focus:border-accord-green-500 focus:outline-none focus:ring-1 focus:ring-accord-green-500"
          />
        </label>

        <div className="mt-4 flex gap-2">
          <button
            type="button"
            onClick={() => {
              setBusy(true);
              setError(null);
              // Stays open on failure, keeping the selection and the
              // note. Closing regardless is how "queued ✓" appeared for
              // a request that never left.
              void onSend([...checked], note)
                .catch((e: unknown) => {
                  const status = (e as { response?: { status?: number } })
                    ?.response?.status;
                  setError(
                    status === 403
                      ? "Your role cannot request documents. Nothing was sent."
                      : "Not sent. Your selection is still here — try again.",
                  );
                })
                .finally(() => setBusy(false));
            }}
            disabled={checked.size === 0 || busy}
            className="min-h-[38px] rounded-lg px-4 text-[13px] font-semibold text-white transition hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-40"
            style={{ backgroundColor: BRAND_GREEN }}
          >
            {busy ? "Sending…" : error ? "Send request again" : "Send request"}
          </button>
          <button
            type="button"
            onClick={onClose}
            className="min-h-[38px] rounded-lg border border-gray-300 px-4 text-[13px] font-medium text-gray-700 transition hover:bg-gray-50"
          >
            Cancel
          </button>
        </div>

        <ActionError message={error} />

        <p className="mt-3 text-[11px] leading-relaxed text-gray-400">
          Recorded against this pre-D in document_requests. Nobody is paged —
          the request shows on the clinical view for whoever picks it up.
        </p>
      </div>
    </div>
  );
}
