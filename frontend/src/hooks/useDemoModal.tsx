/**
 * Shared open/close state for the demo-request modal.
 *
 * Backed by context, NOT plain useState. Four separate components open
 * the same modal — Nav, Hero, MetricsBanner and CTASection — and a
 * bare `useState` hook would give each of them its own isolated flag,
 * so the button in the nav would set a boolean nobody renders. The
 * modal has to live once, above all four.
 *
 * The public shape is still `{ isOpen, open, close }`.
 */
import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from "react";

interface DemoModalState {
  isOpen: boolean;
  open: () => void;
  close: () => void;
}

const DemoModalContext = createContext<DemoModalState | undefined>(undefined);

export function DemoModalProvider({ children }: { children: ReactNode }) {
  const [isOpen, setIsOpen] = useState(false);
  const open = useCallback(() => setIsOpen(true), []);
  const close = useCallback(() => setIsOpen(false), []);
  const value = useMemo(
    () => ({ isOpen, open, close }),
    [isOpen, open, close],
  );
  return (
    <DemoModalContext.Provider value={value}>
      {children}
    </DemoModalContext.Provider>
  );
}

export function useDemoModal(): DemoModalState {
  const ctx = useContext(DemoModalContext);
  if (!ctx) {
    throw new Error("useDemoModal must be used inside <DemoModalProvider>");
  }
  return ctx;
}
