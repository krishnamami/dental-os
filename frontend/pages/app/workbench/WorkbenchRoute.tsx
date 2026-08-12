/**
 * /workbench — which workbench, decided by role.
 *
 * ── It reads the EFFECTIVE role, and that is not incidental ──────────
 *
 * `role` from useAuth() derives from `effectiveUser`, and
 * impersonate() replaces `user` with the person being impersonated —
 * the API mints a token for them and returns them. So an Accord admin
 * viewing as Dr Chinta lands on the clinical view, which is the whole
 * point of "view as": you see what they see. Keying off the ORIGINAL
 * admin would show the engine view and quietly make impersonation a
 * lie.
 *
 * ── Everything not named falls to the engine view ────────────────────
 *
 * dso_owner holds the `workbench` product and the mapping does not
 * mention them, so they keep exactly what they had. Defaulting the
 * other way would silently take a working screen away from a practice
 * owner on the strength of an omission.
 *
 * ── ?demo=true keeps the engine view ─────────────────────────────────
 *
 * ⚠ WORTH A DECISION FROM YOU. The demo identity is a DENTIST
 * (demoUser() in AuthContext returns Dr Sridhar Chinta), and the
 * landing page sends every prospect to /workbench?demo=true —
 * Products.tsx, "Pre-D workbench". Applying the role rule literally
 * would have replaced the public demo with the placeholder below, on
 * the marketing site, silently. So demo mode is pinned to the engine
 * view until the clinical one is worth showing. Flip the one line
 * below when it is.
 *
 * This picks the component only. It grants nothing: /workbench is
 * already behind ProductRoute product="workbench", and the API answers
 * on tenant, not role.
 */
import { lazy } from "react";

import { useAuth } from "../../../context/AuthContext";
import { useDemo } from "../../../hooks/useDemo";
import type { Role } from "../../../types/dental";

const WorkbenchEngineView = lazy(() => import("./WorkbenchEngineView"));
const WorkbenchClinicalView = lazy(() => import("./WorkbenchClinicalView"));

/** Roles that get the clinician's screen. Everyone else keeps the
 *  engine view they have today. */
const CLINICAL_ROLES: ReadonlySet<Role> = new Set<Role>(["dentist"]);

export function workbenchViewFor(
  role: Role | null,
  isDemo = false,
): "clinical" | "engine" {
  if (isDemo) return "engine";
  return role && CLINICAL_ROLES.has(role) ? "clinical" : "engine";
}

export default function WorkbenchRoute() {
  const { role } = useAuth();
  const { isDemo } = useDemo();
  return workbenchViewFor(role, isDemo) === "clinical" ? (
    <WorkbenchClinicalView />
  ) : (
    <WorkbenchEngineView />
  );
}
