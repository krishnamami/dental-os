/**
 * A write failed, and the card says so until someone deals with it.
 *
 * ⚠ WHY NOT A TOAST. Every failing mutation in this app used to report
 * itself through `flash()`, which disappears after three seconds. Kim's
 * submit card moved to "Submitted today" while the request 422'd and
 * the toast timed out before anyone read it — the screen then showed a
 * success state for something that had not happened, indefinitely.
 *
 * This is deliberately unmissable and deliberately persistent:
 *   - it renders INSIDE the card the action belongs to, so it cannot be
 *     read as being about some other row;
 *   - it stays until the retry succeeds or the user dismisses it;
 *   - role="alert" so a screen reader announces it rather than leaving
 *     it to be discovered by eye.
 *
 * Pair it with reverting the optimistic state. An error banner beside a
 * card still showing "Submitted ✓" is worse than either alone.
 */
export default function ActionError({
  message,
  onRetry,
  onDismiss,
  retrying = false,
  className = "",
}: {
  /** null hides the banner entirely — render it unconditionally. */
  message: string | null;
  /** Omit when the action is not safely repeatable. */
  onRetry?: () => void;
  onDismiss?: () => void;
  retrying?: boolean;
  className?: string;
}) {
  if (!message) return null;
  return (
    <div
      role="alert"
      className={`mt-2 rounded-lg border border-red-300 bg-red-50 px-3 py-2 ${className}`}
    >
      <p className="text-[12px] font-medium leading-relaxed text-red-800">
        <span aria-hidden="true">⚠ </span>
        {message}
      </p>
      {(onRetry || onDismiss) && (
        <div className="mt-1.5 flex flex-wrap gap-2">
          {onRetry && (
            <button
              type="button"
              disabled={retrying}
              onClick={onRetry}
              className="min-h-[32px] cursor-pointer rounded-lg border border-red-300 bg-white px-2.5 py-1 text-[11.5px] font-semibold text-red-800 transition hover:bg-red-100 disabled:opacity-60"
            >
              {retrying ? "Retrying…" : "Try again"}
            </button>
          )}
          {onDismiss && (
            <button
              type="button"
              onClick={onDismiss}
              className="min-h-[32px] cursor-pointer rounded-lg px-2.5 py-1 text-[11.5px] text-red-700 hover:text-red-900"
            >
              Dismiss
            </button>
          )}
        </div>
      )}
    </div>
  );
}
