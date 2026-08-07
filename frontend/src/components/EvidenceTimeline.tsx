import {
  AlertTriangle,
  CheckCircle2,
  ClipboardCheck,
  Cpu,
  FileText,
  type LucideIcon,
} from "lucide-react";

import type { Decision, EvidenceItem, Signal } from "../types/dental";

/**
 * F-02 — the chain from a radiograph to a clinical verdict.
 *
 * ── Derived, not hardcoded ───────────────────────────────────────────
 * The brief specified six fixed nodes with DA-A01's values written in.
 * That reads well for one pre-D and is wrong for the other forty-nine:
 * /evidence/:id is a real route, and a scenario with no bone-loss
 * measurement or no bundling rule would show another patient's chain.
 *
 * So each node is built from what the decision actually contains. On
 * DA-A01 that produces exactly the six the brief describes; on a clean
 * prophylaxis it produces three, which is the honest answer.
 *
 * ── The wave numbers in the brief are wrong ──────────────────────────
 * It says "filter to Wave 3 (clinical_reviewer)". clinical_reviewer is
 * WAVE 2 — wave 3 is documentation_reviewer. Filtering on wave 3 would
 * have dropped CLINICAL_CRITERIA_MET, the one signal this page exists
 * to explain. Nodes therefore key off decision_id and signal_code,
 * which are stable, rather than a wave number that is easy to misread.
 */

export type NodeTone = "blue" | "green" | "amber" | "red";

export interface TimelineNode {
  id: string;
  icon: LucideIcon;
  tone: NodeTone;
  title: string;
  sub: string;
  detail?: string;
  result?: string;
  /** The signal this node explains, if any. Drives the right panel. */
  signal?: Signal;
}

const DOT: Record<NodeTone, string> = {
  blue: "bg-blue-500",
  green: "bg-accord-green-500",
  amber: "bg-amber-400",
  red: "bg-red-500",
};

const BORDER: Record<NodeTone, string> = {
  blue: "border-l-blue-500",
  green: "border-l-accord-green-500",
  amber: "border-l-amber-400",
  red: "border-l-red-500",
};

const RESULT_TONE: Record<NodeTone, string> = {
  blue: "bg-blue-50 text-blue-700",
  green: "bg-accord-green-50 text-accord-green-900",
  amber: "bg-accord-amber-50 text-accord-amber-900",
  red: "bg-red-50 text-red-700",
};

function num(v: unknown): number | undefined {
  return typeof v === "number" ? v : undefined;
}

function str(v: unknown): string | undefined {
  return typeof v === "string" ? v : undefined;
}

/** Build the chain for one pre-D. `documents` is optional — per-document
 *  confidence is only exposed by the appeal endpoint, which 404s for an
 *  approved pre-D, so the source node degrades rather than inventing. */
export function buildTimeline(
  decision: Decision,
  documents: EvidenceItem[] = [],
): TimelineNode[] {
  const by = (code: string) =>
    (decision.all_signals ?? []).find((s) => s.signal_code === code);

  const nodes: TimelineNode[] = [];

  const criteria = by("CLINICAL_CRITERIA_MET") ?? by("CLINICAL_CRITERIA_NOT_MET");
  const boneLoss = num(criteria?.data.bone_loss_mm);
  const threshold = num(criteria?.data.threshold);
  const tooth = num(criteria?.data.tooth_number);

  // ── 1. Source document ───────────────────────────────────────────
  const xray = documents.find((d) => d.document_type.startsWith("XRAY"));
  if (xray || boneLoss !== undefined) {
    nodes.push({
      id: "source",
      icon: FileText,
      tone: "blue",
      title: `PA X-ray${tooth ? ` — tooth #${tooth}` : ""}`,
      sub: xray
        ? `${Math.round((xray.confidence ?? 0) * 100)}% confidence · ${
            xray.description ?? xray.document_type
          }`
        : "Radiograph on file",
      detail: xray?.s3_key ?? undefined,
    });
  }

  // ── 2. Extraction ────────────────────────────────────────────────
  if (boneLoss !== undefined) {
    nodes.push({
      id: "extraction",
      icon: Cpu,
      tone: "blue",
      title: "Bone loss extracted",
      sub: `${boneLoss}mm${
        xray?.confidence === 1 ? " · deterministic measurement" : ""
      }`,
      detail:
        xray?.confidence === 1
          ? "Read from the radiograph's structured payload — no AI inference"
          : "Extracted from the periapical radiograph",
    });
  }

  // ── 3. ADA threshold check ───────────────────────────────────────
  if (criteria && boneLoss !== undefined && threshold !== undefined) {
    const met = criteria.signal_code === "CLINICAL_CRITERIA_MET";
    nodes.push({
      id: "ada",
      icon: CheckCircle2,
      tone: met ? "green" : "red",
      title: "ADA criteria evaluated",
      sub: `Threshold ${threshold}mm`,
      detail: criteria.citation ?? undefined,
      result: `${boneLoss}mm ${met ? "≥" : "<"} ${threshold}mm → ${
        met ? "CRITERIA MET ✓" : "NOT MET ✗"
      }`,
      signal: criteria,
    });
  }

  // ── 4. Clinical narrative ────────────────────────────────────────
  const narrative = by("CLINICAL_NARRATIVE_MISSING");
  if (narrative) {
    const onFile = narrative.data.note_on_file === true;
    nodes.push({
      id: "narrative",
      icon: FileText,
      tone: "amber",
      title: "Clinical narrative reviewed",
      sub: `note_on_file = ${onFile ? "True" : "False"}`,
      detail: onFile
        ? "A note exists in clinical_evidence — the question is what it establishes"
        : "No clinical note found",
      result: onFile
        ? "Note present but does not establish independent necessity"
        : "No narrative on file",
      signal: narrative,
    });
  }

  // ── 5. Bundling policy ───────────────────────────────────────────
  const bundling = by("COVERAGE_BUNDLING_CONFLICT");
  if (bundling) {
    const section = str(bundling.data.policy_section);
    const primary = str(bundling.data.primary);
    const bundled = str(bundling.data.bundled);
    nodes.push({
      id: "bundling",
      icon: AlertTriangle,
      tone: "amber",
      title: `Bundling policy${section ? ` — §${section}` : ""}`,
      sub:
        primary && bundled
          ? `${bundled} + ${primary} · ${str(bundling.data.bundling_type) ?? "bundled"} rule`
          : "Bundling rule applies",
      detail: str(bundling.data.separation_criteria),
      result:
        bundling.data.separable === true
          ? "Separable with documentation — narrative does not yet satisfy it"
          : "Not separable",
      signal: bundling,
    });
  }

  // ── 6. Final clinical assessment ─────────────────────────────────
  const open = (decision.open_conditions ?? []).length;
  const blocking = (decision.all_signals ?? []).filter(
    (s) => s.mode === "human_approval",
  ).length;
  nodes.push({
    id: "assessment",
    icon: ClipboardCheck,
    tone:
      decision.decision === "approved"
        ? "green"
        : decision.decision === "denied"
          ? "red"
          : "amber",
    title: "Clinical assessment",
    sub: `criteria_score = ${decision.criteria_score ?? "—"} · ${decision.confidence_label}`,
    detail: `${open} condition${open === 1 ? "" : "s"} open · ${blocking} needing a signature`,
    result: `${decision.decision[0].toUpperCase()}${decision.decision.slice(1)}${
      decision.submission_ready ? " — ready to submit" : " — not yet submittable"
    }`,
    signal: by("PRED_CONDITIONS_OPEN") ?? by("PRED_READY_TO_SUBMIT"),
  });

  return nodes;
}

export default function EvidenceTimeline({
  nodes,
  selectedId,
  onSelect,
}: {
  nodes: TimelineNode[];
  selectedId?: string;
  onSelect: (node: TimelineNode) => void;
}) {
  return (
    <ol className="relative space-y-2">
      {nodes.map((node, i) => {
        const Icon = node.icon;
        const active = node.id === selectedId;
        return (
          <li key={node.id} className="relative flex gap-3">
            {/* Rail */}
            <div className="flex flex-col items-center">
              <span
                className={`mt-3 flex h-6 w-6 flex-shrink-0 items-center justify-center rounded-full text-white ${DOT[node.tone]}`}
              >
                <Icon size={12} />
              </span>
              {i < nodes.length - 1 && (
                <span className="w-px flex-1 bg-gray-200" aria-hidden="true" />
              )}
            </div>

            <button
              type="button"
              onClick={() => onSelect(node)}
              aria-pressed={active}
              className={`mb-2 w-full rounded-r-lg border-y border-r border-l-4 px-3.5 py-2.5 text-left transition ${
                BORDER[node.tone]
              } ${
                active
                  ? "border-gray-300 bg-gray-50 shadow-sm"
                  : "border-gray-200 bg-white hover:bg-gray-50"
              }`}
            >
              <p className="text-[13px] font-semibold text-gray-900">
                {node.title}
              </p>
              <p className="mt-0.5 text-[11.5px] text-gray-500">{node.sub}</p>
              {node.detail && (
                <p className="mt-1 break-words text-[11px] leading-relaxed text-gray-400">
                  {node.detail}
                </p>
              )}
              {node.result && (
                <p
                  className={`mt-1.5 inline-block rounded px-1.5 py-0.5 text-[11px] font-medium ${RESULT_TONE[node.tone]}`}
                >
                  {node.result}
                </p>
              )}
            </button>
          </li>
        );
      })}
    </ol>
  );
}
