import { AlertTriangle, Check, ShieldCheck } from "lucide-react";

import { useDocumentAccess } from "../hooks/useApi";

/**
 * Case History — was the evidence read before the case was filed?
 *
 * ── THE QUESTION THIS ANSWERS ─────────────────────────────────────────
 * "Did the clinician review the X-ray before submitting this pre-D?" is
 * the first thing a payer asks when it pushes back, and until
 * document_access_events existed it was unanswerable: the presign
 * endpoint handed out a link to a radiograph and recorded nothing.
 *
 * Every other clinical act in this product already left a row with an
 * actor and a timestamp. Reading the chart did not. This section is the
 * readable end of that fix.
 *
 * ── WHAT "COMPLETE" MEANS, AND WHAT IT DOES NOT ───────────────────────
 * It means every reviewable document on the case — imaging, perio
 * chart, clinical note — was opened by someone before the submission
 * timestamp. It does not mean anyone read them properly, and the copy
 * is careful not to imply that. It says the trail is there.
 *
 * ⚠ THREE STATES, NOT TWO. `audit_complete` is null when the case has
 * not been filed. A case nobody has submitted cannot have been reviewed
 * late, and showing "AUDIT GAP" against it would be an accusation the
 * data does not support. Unfiled says so plainly instead.
 */

function timeOf(iso: string | null): string {
  if (!iso) return "";
  const d = new Date(iso);
  return `${d.toLocaleDateString("en-US", { month: "short", day: "numeric" })} · ${d
    .toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" })
    .toLowerCase()}`;
}

export default function CaseHistory({
  predRequestId,
}: {
  predRequestId: string;
}) {
  const { data, isLoading, isError } = useDocumentAccess(predRequestId);

  if (isLoading) {
    return (
      <section className="mt-4">
        <h3 className="text-[11px] font-bold uppercase tracking-[0.1em] text-gray-500">
          Case history
        </h3>
        <div className="mt-2 h-24 animate-pulse rounded-xl bg-gray-100" />
      </section>
    );
  }

  // A failure here must not look like "no documents were reviewed".
  // Silence and a gap are different findings.
  if (isError || !data) {
    return (
      <section className="mt-4">
        <h3 className="text-[11px] font-bold uppercase tracking-[0.1em] text-gray-500">
          Case history
        </h3>
        <p className="mt-2 rounded-xl border border-gray-200 bg-white p-4 text-[12.5px] text-gray-500">
          Could not load the document access record. This is not the same
          as no documents having been reviewed — try again before drawing a
          conclusion.
        </p>
      </section>
    );
  }

  const docs = data.required_documents;
  const missing = docs.filter((d) => !d.reviewed);

  return (
    <section className="mt-4">
      <h3 className="text-[11px] font-bold uppercase tracking-[0.1em] text-gray-500">
        Case history
      </h3>

      <div className="mt-2 overflow-hidden rounded-xl border border-gray-200 bg-white">
        <header className="border-b border-gray-200 bg-gray-50 px-4 py-2.5">
          <p className="text-[11px] font-semibold uppercase tracking-wide text-gray-600">
            Documents reviewed before submission
          </p>
        </header>

        {docs.length === 0 ? (
          <p className="px-4 py-4 text-[12.5px] text-gray-500">
            No imaging, perio chart or clinical note is stored on this case,
            so there is nothing a reviewer could have opened.
          </p>
        ) : (
          <ul className="divide-y divide-gray-100">
            {docs.map((d) => (
              <li key={d.evidence_id} className="flex gap-2.5 px-4 py-2.5">
                <span
                  aria-hidden="true"
                  className={`mt-0.5 flex-shrink-0 ${
                    d.reviewed ? "text-accord-green-700" : "text-amber-600"
                  }`}
                >
                  {d.reviewed ? <Check size={14} /> : <AlertTriangle size={14} />}
                </span>
                <span className="min-w-0">
                  <span className="block text-[12.5px] font-medium text-gray-900">
                    {d.document_label}
                  </span>
                  <span className="mt-0.5 block text-[11.5px] text-gray-500">
                    {d.reviewed
                      ? `${d.reviewed_by ?? "Opened"} · ${timeOf(d.reviewed_at)}`
                      : "Not opened before submission"}
                  </span>
                </span>
              </li>
            ))}
          </ul>
        )}

        {/* The verdict, in the three states the data actually has. */}
        {data.audit_complete === true && (
          <div className="flex gap-2.5 border-t border-accord-green-500/30 bg-accord-green-50 px-4 py-3">
            <ShieldCheck
              size={15}
              className="mt-0.5 flex-shrink-0 text-accord-green-700"
            />
            <p className="text-[12.5px] leading-relaxed text-accord-green-900">
              <span className="font-semibold">Audit trail complete.</span> Every
              stored document was opened before the case was filed
              {data.submitted_at ? ` on ${timeOf(data.submitted_at)}` : ""}.
              Defensible on a payer dispute.
            </p>
          </div>
        )}

        {data.audit_complete === false && (
          <div className="flex gap-2.5 border-t border-amber-200 bg-amber-50 px-4 py-3">
            <AlertTriangle
              size={15}
              className="mt-0.5 flex-shrink-0 text-amber-700"
            />
            <p className="text-[12.5px] leading-relaxed text-accord-amber-900">
              <span className="font-semibold">Audit gap.</span>{" "}
              {missing.map((d) => d.document_label).join(", ")}{" "}
              {missing.length === 1 ? "was" : "were"} not opened before
              submission. Cannot confirm clinical review occurred.
            </p>
          </div>
        )}

        {data.audit_complete === null && (
          <div className="border-t border-gray-200 bg-gray-50 px-4 py-3 text-[12.5px] text-gray-600">
            Not submitted yet — there is no filing to measure the review
            against.
          </div>
        )}
      </div>

      <p className="mt-1.5 text-[11px] text-gray-400">
        {data.total_accesses} document{data.total_accesses === 1 ? "" : "s"}{" "}
        opened on this case in total. Records who opened a file, not whether
        they read it.
      </p>
    </section>
  );
}
