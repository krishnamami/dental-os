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
}

/** Where a role goes after signing in. */
export const HOME_FOR_ROLE: Record<Role, string> = {
  front_desk: "/coverage",
  revenue_ops: "/revenue-ops",
  dentist: "/workbench",
  dso_owner: "/dso",
  accord_admin: "/admin",
};

export const NAV_FOR_ROLE: Record<Role, NavItem[]> = {
  dentist: [
    { label: "My patients today", to: "/workbench", icon: CalendarCheck },
    { label: "Clinical evidence", to: "/evidence", icon: FileSearch },
    { label: "Pre-D review", to: "/workbench?filter=review", icon: ClipboardCheck },
  ],
  front_desk: [
    { label: "Patient check-in", to: "/coverage", icon: Users },
    { label: "Coverage check", to: "/coverage", icon: ShieldCheck },
    { label: "Document requests", to: "/workbench?filter=docs", icon: FileText },
    { label: "SLA queue", to: "/workbench?filter=sla", icon: Clock },
  ],
  revenue_ops: [
    { label: "Submission queue", to: "/revenue-ops", icon: Send },
    { label: "Conditions", to: "/revenue-ops/conditions", icon: ClipboardList },
    { label: "Appeals", to: "/revenue-ops/appeals", icon: Receipt },
    { label: "Analytics", to: "/revenue-ops/analytics", icon: TrendingUp },
    { label: "Coverage checks", to: "/coverage", icon: ShieldCheck },
  ],
  dso_owner: [
    { label: "Portfolio", to: "/dso", icon: BarChart3 },
    { label: "Denial patterns", to: "/dso/denials", icon: Layers },
    { label: "Revenue", to: "/dso/revenue", icon: TrendingUp },
    { label: "Training", to: "/dso/training", icon: GraduationCap },
  ],
  accord_admin: [
    { label: "Tenants", to: "/admin", icon: Building2 },
    { label: "Onboard tenant", to: "/admin/onboard", icon: FolderPlus },
    { label: "Catalogue", to: "/admin/catalogue", icon: Layers },
    { label: "System health", to: "/admin/health", icon: Activity },
  ],
};

/** Page titles for the top bar, longest prefix wins. */
export const TITLE_FOR_PATH: Array<[string, string]> = [
  ["/workbench/", "Pre-D review"],
  ["/workbench", "Pre-D workbench"],
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
