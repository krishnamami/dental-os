/**
 * One toast, shared by every revenue-ops surface.
 *
 * Four screens each growing their own `const [notice, setNotice]` is
 * how two of them end up with different dismiss timings and one never
 * clears at all.
 *
 * role="status" rather than role="alert": these confirm something the
 * user just did. An alert interrupts a screen reader mid-sentence,
 * which is right for "submission failed" and wrong for "saved".
 */
import { useCallback, useEffect, useRef, useState } from "react";

const GREEN = "#0F4D37";

export function useToast() {
  const [toast, setToast] = useState<string | null>(null);
  const timer = useRef<number | undefined>(undefined);

  const flash = useCallback((message: string) => {
    window.clearTimeout(timer.current);
    setToast(message);
    timer.current = window.setTimeout(() => setToast(null), 3200);
  }, []);

  // A toast whose component unmounts mid-timeout would otherwise call
  // setState on nothing.
  useEffect(() => () => window.clearTimeout(timer.current), []);

  return { toast, flash };
}

export default function Toast({ message }: { message: string | null }) {
  if (!message) return null;
  return (
    <div
      role="status"
      className="pointer-events-none fixed inset-x-0 bottom-[76px] z-50 flex justify-center px-4 lg:bottom-6"
    >
      <span
        className="rounded-lg px-4 py-2.5 text-[13px] font-medium text-white shadow-lg"
        style={{ backgroundColor: GREEN }}
      >
        {message}
      </span>
    </div>
  );
}
