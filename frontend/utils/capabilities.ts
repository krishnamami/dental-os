/**
 * Role -> capability, mirrored from dental-os/api/auth.py.
 *
 * ⚠ THIS IS A UI COURTESY, NOT A BOUNDARY. The API is the boundary and
 * refuses independently. What this buys is that a control which would
 * 403 is visibly disabled with a reason, instead of failing under the
 * cursor. A dso_owner reaches the Workbench and Revenue Ops screens by
 * design; every write on them is denied to him, and discovering that
 * one button at a time is a bad way to learn it.
 *
 * When a capability changes in api/auth.py it changes here too. There
 * is no derivation between them and there cannot be — the frontend
 * never sees the dependency graph.
 */

// Mirrors require_engine_feedback in dental-os/api/auth.py: revenue_ops
// and dentist, plus accord_admin. A dso_owner holds the Workbench and
// Revenue Ops products and can reach these controls, so they are
// DISABLED for him rather than left to 403 on click — the same pattern
// as canChaseDocs in PreDDetail and canFile in AppealsDashboard.
export const ENGINE_FEEDBACK_ROLES = ["revenue_ops", "dentist", "accord_admin"];

export const NO_ENGINE_FEEDBACK =
  "This role cannot record a verdict on an engine finding";

export function canGiveEngineFeedback(role?: string | null): boolean {
  return !!role && ENGINE_FEEDBACK_ROLES.includes(role);
}


// Mirrors require_document_read in dental-os/api/auth.py.
//
// The dentist reads the chart; billing assembles the appeal packet out
// of the same documents. dso_owner is OUT, and it is the same line
// drawn on per-pre-D access: an owner may know Tampa denies at 20% and
// may not read a Tampa patient's radiograph. front_desk and tx_coord
// are out because no screen of theirs names a document.
export const DOCUMENT_ROLES = ["dentist", "revenue_ops", "accord_admin"];

export const NO_DOCUMENT_ACCESS =
  "This role cannot open a patient's clinical documents";

export function canOpenDocuments(role?: string | null): boolean {
  return !!role && DOCUMENT_ROLES.includes(role);
}
