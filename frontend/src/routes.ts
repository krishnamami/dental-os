/**
 * C-02 — the workflow map.
 *
 * WORKFLOW_NAV is what the sidebar draws; AuthContext decides which of
 * its seven entries a role may see. HOME_FOR_ROLE moved to AuthContext
 * alongside the permission tables it belongs with.
 */
import type { LucideIcon } from "lucide-react";
import {
  BarChart3,
  ClipboardCheck,
  Microscope,
  Receipt,
  Settings,
  TrendingUp,
  UserCheck,
} from "lucide-react";

export interface NavItem {
  label: string;
  to: string;
  icon: LucideIcon;
  /**
   * The product family this entry belongs to, in the vocabulary
   * AuthContext.ROLE_NAV uses. Several entries share one gate — a
   * dentist's "My patients today" and "Pre-D review" are both Pre-D —
   * so the gate cannot be derived from the label.
   */
  gate: string;
}

/**
 * The seven workflows, once.
 *
 * There is no longer a per-role list. Five lists of overlapping items
 * meant "Coverage check" existed twice with two labels and one of them
 * always went stale; now AppShell filters THIS list by the role's
 * gates. Adding a workflow is one entry, and no role can accidentally
 * keep a link to something it no longer holds.
 *
 * `gate` must match a string in AuthContext.ROLE_NAV exactly.
 */
export const WORKFLOW_NAV: NavItem[] = [
  { label: "Check-in", to: "/checkin", icon: UserCheck, gate: "Check-In" },
  {
    label: "Patient financial",
    to: "/coverage",
    icon: Receipt,
    gate: "Patient Financial",
  },
  {
    label: "Pre-D workbench",
    to: "/workbench",
    icon: ClipboardCheck,
    gate: "Pre-D Workbench",
  },
  {
    label: "Clinical intelligence",
    to: "/evidence/PRED-SIM-DA-A01",
    icon: Microscope,
    gate: "Clinical Intelligence",
  },
  {
    label: "Revenue operations",
    to: "/revenue-ops",
    icon: TrendingUp,
    gate: "Revenue Ops",
  },
  {
    label: "Portfolio intelligence",
    to: "/dso",
    icon: BarChart3,
    gate: "Portfolio",
  },
  { label: "Administration", to: "/admin", icon: Settings, gate: "Admin" },
];

/** Page titles for the top bar, longest prefix wins. */
export const TITLE_FOR_PATH: Array<[string, string]> = [
  ["/workbench/", "Pre-D review"],
  ["/workbench", "Pre-D workbench"],
  ["/checkin", "Check-in"],
  ["/coverage/all", "All pre-Ds"],
  ["/coverage", "Patient financial"],
  ["/evidence", "Clinical intelligence"],
  ["/revenue-ops/conditions", "Conditions"],
  ["/revenue-ops/appeals", "Appeals"],
  ["/revenue-ops/analytics", "Revenue analytics"],
  ["/revenue-ops", "Revenue operations"],
  ["/dso/denials", "Denial patterns"],
  ["/dso/revenue", "Revenue"],
  ["/dso/training", "Training"],
  ["/dso", "Portfolio intelligence"],
  ["/admin/onboard", "Onboard tenant"],
  ["/admin/catalogue", "Catalogue"],
  ["/admin/health", "System health"],
  ["/admin", "Administration"],
];

export function titleForPath(pathname: string): string {
  const match = TITLE_FOR_PATH.filter(([prefix]) =>
    pathname.startsWith(prefix),
  ).sort((a, b) => b[0].length - a[0].length)[0];
  return match ? match[1] : "Accord Dental";
}
