/**
 * C-02 — where each role lives.
 *
 * One table, imported by Login (where to land after sign-in),
 * AppShell (which sidebar to draw) and App (which route redirects
 * home). Three copies of this map would drift the first time a role
 * gained a page.
 */
import type { LucideIcon } from "lucide-react";
import {
  Activity,
  BarChart3,
  Building2,
  CalendarCheck,
  ClipboardCheck,
  ClipboardList,
  Clock,
  FileSearch,
  FileText,
  FolderPlus,
  GraduationCap,
  Layers,
  Receipt,
  Send,
  ShieldCheck,
  TrendingUp,
  Users,
} from "lucide-react";

import type { Role } from "./types/dental";

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

export const NAV_FOR_ROLE: Record<Role, NavItem[]> = {
  dentist: [
    { label: "My patients today", to: "/workbench", icon: CalendarCheck, gate: "Pre-D" },
    { label: "Clinical evidence", to: "/evidence", icon: FileSearch, gate: "Clinical" },
    { label: "Pre-D review", to: "/workbench?filter=review", icon: ClipboardCheck, gate: "Pre-D" },
  ],
  front_desk: [
    { label: "Patient check-in", to: "/coverage", icon: Users, gate: "Coverage" },
    { label: "Coverage check", to: "/coverage", icon: ShieldCheck, gate: "Coverage" },
    { label: "Document requests", to: "/workbench?filter=docs", icon: FileText, gate: "Pre-D" },
    { label: "SLA queue", to: "/workbench?filter=sla", icon: Clock, gate: "Pre-D" },
  ],
  revenue_ops: [
    { label: "Submission queue", to: "/revenue-ops", icon: Send, gate: "Revenue ops" },
    { label: "Conditions", to: "/revenue-ops/conditions", icon: ClipboardList, gate: "Revenue ops" },
    { label: "Appeals", to: "/revenue-ops/appeals", icon: Receipt, gate: "Revenue ops" },
    { label: "Analytics", to: "/revenue-ops/analytics", icon: TrendingUp, gate: "Revenue ops" },
    { label: "Coverage checks", to: "/coverage", icon: ShieldCheck, gate: "Coverage" },
  ],
  dso_owner: [
    { label: "Portfolio", to: "/dso", icon: BarChart3, gate: "DSO" },
    { label: "Denial patterns", to: "/dso/denials", icon: Layers, gate: "DSO" },
    { label: "Revenue", to: "/dso/revenue", icon: TrendingUp, gate: "DSO" },
    { label: "Training", to: "/dso/training", icon: GraduationCap, gate: "DSO" },
  ],
  accord_admin: [
    { label: "Tenants", to: "/admin", icon: Building2, gate: "Admin" },
    { label: "Onboard tenant", to: "/admin/onboard", icon: FolderPlus, gate: "Admin" },
    { label: "Catalogue", to: "/admin/catalogue", icon: Layers, gate: "Admin" },
    { label: "System health", to: "/admin/health", icon: Activity, gate: "Admin" },
  ],
};

/** Page titles for the top bar, longest prefix wins. */
export const TITLE_FOR_PATH: Array<[string, string]> = [
  ["/workbench/", "Pre-D review"],
  ["/workbench", "Pre-D workbench"],
  ["/coverage/all", "All pre-Ds"],
  ["/coverage", "Coverage intelligence"],
  ["/evidence", "Clinical evidence"],
  ["/revenue-ops/conditions", "Conditions"],
  ["/revenue-ops/appeals", "Appeals"],
  ["/revenue-ops/analytics", "Revenue analytics"],
  ["/revenue-ops", "Revenue operations"],
  ["/dso/denials", "Denial patterns"],
  ["/dso/revenue", "Revenue"],
  ["/dso/training", "Training"],
  ["/dso", "DSO intelligence"],
  ["/admin/onboard", "Onboard tenant"],
  ["/admin/catalogue", "Catalogue"],
  ["/admin/health", "System health"],
  ["/admin", "Admin console"],
];

export function titleForPath(pathname: string): string {
  const match = TITLE_FOR_PATH.filter(([prefix]) =>
    pathname.startsWith(prefix),
  ).sort((a, b) => b[0].length - a[0].length)[0];
  return match ? match[1] : "Accord Dental";
}
