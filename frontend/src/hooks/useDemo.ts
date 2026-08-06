/**
 * Demo mode — `?demo=true` anywhere in the app.
 *
 * The demo is Dr. Chinta's case: PRED-SIM-DA-A01, an implant + bone
 * graft + crown on tooth #19 under Delta Dental PPO. The graft bundles
 * into the implant and is denied as "not separately payable" unless its
 * necessity is documented independently. That is the case the product
 * exists for, so it is the one a cold visitor lands on.
 *
 * Overridable for a specific pitch:
 *   ?demo=true&pred=PRED-SIM-TB-B01   Aetna DMO implant exclusion
 *   ?demo=true&pred=PRED-SIM-DL-D01   adult Invisalign not covered
 *   ?demo=true&tenant=dallas_dental
 *
 * The flag survives navigation: useDemoLink() appends it to internal
 * links so a demo visitor never falls out of demo mode by clicking.
 */
import { useCallback, useMemo } from "react";
import { useLocation } from "react-router-dom";

export const DEFAULT_DEMO_PRED_ID = "PRED-SIM-DA-A01";
export const DEFAULT_DEMO_TENANT = "suwanee_smiles";

/** The three cases worth showing, in the order they tell a story. */
export const DEMO_CASES = [
  {
    predRequestId: "PRED-SIM-DA-A01",
    label: "Implant + bone graft — bundling conflict",
    tenant: "suwanee_smiles",
    blurb:
      "The graft is denied as not separately payable until a narrative " +
      "documents it independently of the implant.",
  },
  {
    predRequestId: "PRED-SIM-TB-B01",
    label: "Implant denied — Aetna DMO",
    tenant: "tampa_smiles",
    blurb:
      "Same procedure, different plan. A DMO carries no implant benefit, " +
      "so the answer is no before a clinical fact is read.",
  },
  {
    predRequestId: "PRED-SIM-DL-D01",
    label: "Adult Invisalign — not covered",
    tenant: "dallas_dental",
    blurb:
      "Humana's standard plan buys child orthodontics only. A $4,500 " +
      "answer that used to take a phone call.",
  },
] as const;

export interface DemoState {
  isDemo: boolean;
  demoTenant: string;
  demoPredId: string;
}

export function useDemo(): DemoState {
  const { search } = useLocation();
  return useMemo(() => {
    const params = new URLSearchParams(search);
    // Presence is enough — `?demo` and `?demo=true` both mean yes, and
    // only an explicit `?demo=false` turns it off.
    const raw = params.get("demo");
    const isDemo = raw !== null && raw !== "false" && raw !== "0";
    return {
      isDemo,
      demoTenant: params.get("tenant") ?? DEFAULT_DEMO_TENANT,
      demoPredId: params.get("pred") ?? DEFAULT_DEMO_PRED_ID,
    };
  }, [search]);
}

/**
 * Build an internal link that keeps demo mode on. Without this, the
 * first click out of the landing page drops a prospect at a login
 * screen — which is the one thing a demo must never do.
 */
export function useDemoLink() {
  const { search } = useLocation();
  const { isDemo } = useDemo();
  return useCallback(
    (path: string) => {
      if (!isDemo) return path;
      const current = new URLSearchParams(search);
      const next = new URLSearchParams();
      next.set("demo", "true");
      for (const key of ["tenant", "pred"]) {
        const value = current.get(key);
        if (value) next.set(key, value);
      }
      return `${path}${path.includes("?") ? "&" : "?"}${next.toString()}`;
    },
    [isDemo, search],
  );
}
