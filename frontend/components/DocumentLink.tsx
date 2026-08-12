import { ExternalLink, Loader2 } from "lucide-react";
import { useState } from "react";

import { api } from "../hooks/useApi";
import { useAuth } from "../context/AuthContext";
import type { DocumentUrl } from "../types/dental";
import { canOpenDocuments, NO_DOCUMENT_ACCESS } from "../utils/capabilities";

/**
 * Open one clinical document.
 *
 * ── WHY A COMPONENT AND NOT AN <a href> ───────────────────────────────
 * There is no durable URL to put in an href. The API mints a presigned
 * link that lives five minutes, so the link has to be fetched by the
 * click that uses it. Rendering it ahead of time would mean either a
 * dead link by the time anyone pressed it, or a bucket path sitting in
 * the DOM of every row on the page.
 *
 * ── WHY PLAIN axios AND NOT useMutation ───────────────────────────────
 * Opening a document is a side effect on the browser, not state this
 * component owns, and there is nothing to cache — the URL is dead in
 * five minutes. A mutation would add a lifecycle the navigation does
 * not need: React Query v5 drops the callbacks passed to mutate() if
 * the component unmounts first, and a tab that opens or not depending
 * on whether a row re-rendered is not a trade worth making.
 *
 * ── THE POPUP DANCE, WHICH IS NOT OPTIONAL ────────────────────────────
 * window.open() after an await is blocked by every browser — the tab is
 * no longer attributable to a user gesture. So a blank tab is opened
 * SYNCHRONOUSLY on the click, and its location is set when the URL
 * arrives. If the request fails the tab is closed again rather than
 * left showing about:blank.
 *
 * ── WHAT IT DOES NOT DO ───────────────────────────────────────────────
 * It does not decide who may read a document; the API does, and refuses
 * independently. Hiding the control for a role that would be refused is
 * the same courtesy as the disabled write buttons elsewhere — a link
 * that 403s is worse than no link.
 */
export default function DocumentLink({
  predRequestId,
  evidenceId,
  hasDocument = true,
  label = "Open",
  className = "",
}: {
  predRequestId: string;
  evidenceId?: string | null;
  /** False for structured payloads — a real record with no file. */
  hasDocument?: boolean;
  label?: string;
  className?: string;
}) {
  const { role } = useAuth();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const allowed = canOpenDocuments(role);

  // Nothing to open, and saying "Open" would be a lie. The caller
  // renders the document's name either way; this is only the verb.
  if (!evidenceId || !hasDocument) return null;

  if (!allowed) {
    return (
      <span
        title={NO_DOCUMENT_ACCESS}
        className={`inline-flex items-center gap-1 text-[11.5px] text-gray-400 ${className}`}
      >
        <ExternalLink size={11} aria-hidden="true" />
        Not available to your role
      </span>
    );
  }

  async function open() {
    setError(null);
    setBusy(true);
    // Synchronously, inside the gesture. See the note above.
    //
    // ⚠ NO "noopener". window.open returns NULL when it is set: the
    // tab opens and the handle does not come back, so the location can
    // never be assigned. That was a real bug in the first cut.
    //
    // ⚠ AND IT CANNOT BE VERIFIED HEADLESS. Headless Chromium refuses
    // the deferred navigation of a popup — the tab stays on
    // about:blank however correct the code is, with no error anywhere.
    // Three separate rewrites chased that before running the same
    // click headed, where it worked first time. If this needs testing
    // again: chromium.launch({ headless: false }).
    const tab = window.open("", "_blank");
    try {
      const { data } = await api.get<DocumentUrl>(
        `/decisions/${predRequestId}/documents/${evidenceId}`,
      );
      // replace(), not href: the blank placeholder should not become a
      // back-button stop between the document and where the user was.
      if (tab) tab.location.replace(data.url);
      else window.location.href = data.url; // popup blocked
    } catch (e: unknown) {
      tab?.close();
      const status = (e as { response?: { status?: number } })?.response
        ?.status;
      setError(
        status === 403
          ? "Your role cannot open clinical documents."
          : status === 404
            ? "That document is not on this pre-D."
            : status === 409
              ? "This record is a structured payload, not a file."
              : "Could not open the document.",
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <span className={`inline-flex items-center gap-2 ${className}`}>
      <button
        type="button"
        onClick={open}
        disabled={busy}
        className="inline-flex items-center gap-1 rounded text-[11.5px] font-medium text-accord-green-700 underline-offset-2 transition hover:underline disabled:cursor-wait disabled:text-gray-400"
      >
        {busy ? (
          <Loader2 size={11} className="animate-spin" aria-hidden="true" />
        ) : (
          <ExternalLink size={11} aria-hidden="true" />
        )}
        {label}
      </button>
      {/* Persistent, on the row. Not a toast — the row is where the
          person is looking, and a toast about one document among
          fifteen names nothing. */}
      {error && (
        <span role="alert" className="text-[11px] text-red-600">
          {error}
        </span>
      )}
    </span>
  );
}
