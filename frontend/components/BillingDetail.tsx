/**
 * The same pre-D, seen by the person who has to bill it.
 *
 * ── Why this is a separate component, not a flag on PreDDetail ───────
 *
 * PreDDetail answers "is this clinically sound and what is still
 * missing" — bone loss in millimetres, ADA criteria, criteria score,
 * five wave bars, evidence confidence. Kim cannot act on any of it. She
 * needs the payer, the money, what is blocking submission, and who owns
 * each blocker. Threading a `variant` through 600 lines of clinical
 * layout to hide most of it would leave both views hostage to each
 * other's changes; the two jobs genuinely differ, so the screens do.
 *
 * Everything here comes from the two endpoints PreDDetail already
 * reads — no new API, and the same numbers, so the dentist and the
 * biller cannot be shown different money for one case.
 *
 * ── Conditions are grouped by OWNER ──────────────────────────────────
 *
 * The engine stamps each signal with an `assignee`. Kim can resolve the
 * ones assigned to billing; the rest are read-only with a notify
 * button, because a biller ticking "narrative added" when no dentist
 * has written one is exactly how a pre-D goes out incomplete. The
 * grouping is not cosmetic — it is the permission.
 */
import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { ChevronDown } from "lucide-react";

import ActionError from "./ActionError";
import DecisionBadge from "./DecisionBadge";
import DetailTopbar from "./DetailTopbar";
import {
  useAppeal,
  useCreateHandoff,
  useDecision,
  usePatientSummary,
  type HandoffRole,
} from "../hooks/useApi";
import { useDemoLink } from "../hooks/useDemo";
import type { Condition, Decision, Signal } from "../types/dental";
import { formatCurrency, scenarioId } from "../utils/format";
import { openConditions, submitTitle } from "../utils/predDerive";
import CaseHistory from "./CaseHistory";
import FeedbackAudit from "./FeedbackAudit";

const TABS = ["Submission", "Conditions", "Coverage", "Audit"] as const;
type Tab = (typeof TABS)[number];

/** Pre-D validity. 90 days is the industry-standard window and the
 *  figure the brief gave; nothing in the corpus stores a real one. */
/**
 * ⚠ NOT A PAYER RULE. No payer table supplies a pre-D validity window —
 * not `payers`, not `plans`, not `coverage_rules`. This is a house
 * assumption applied to pred_requests.created_at, and the date it
 * produces is labelled as an estimate wherever it renders. It is also
 * counted from when the case was CREATED, not from a submission,
 * because nothing in this corpus has been submitted.
 */
const VALIDITY_DAYS = 90;

/** Who owns a condition, in the three groups a biller thinks in. */
type Owner = "billing" | "front_desk" | "clinical";

function ownerOf(assignee?: string): Owner {
  const a = assignee ?? "";
  if (a === "billing" || a === "dso_manager") return "billing";
  if (a === "front_desk") return "front_desk";
  return "clinical"; // dentist, provider, anything unrecognised
}

const OWNER_LABEL: Record<Owner, string> = {
  billing: "Billing team — yours",
  front_desk: "Front desk — not yours",
  clinical: "Clinical — not yours",
};

/** Which role each owner group maps to when handing a case over. */
export const HANDOFF_TO: Record<Owner, HandoffRole> = {
  billing: "revenue_ops",
  front_desk: "front_desk",
  clinical: "dentist",
};

/** Exported: the submission queue chases the same people by the same
 *  name. Two copies of this map is how one screen ends up saying
 *  "Notify Dr. Chinta" and the other "Notify clinical". */
export const NOTIFY: Record<Owner, string> = {
  billing: "",
  front_desk: "Notify front desk",
  clinical: "Notify Dr. Chinta",
};

export function daysSince(iso?: string | null): number | null {
  if (!iso) return null;
  const then = new Date(iso).getTime();
  if (Number.isNaN(then)) return null;
  return Math.floor((Date.now() - then) / 86_400_000);
}

/** Green under a week, amber to a fortnight, red past it. */
export function queueTone(days: number | null): string {
  if (days == null) return "#6b7280";
  if (days < 7) return "#15803d";
  if (days <= 14) return "#b45309";
  return "#b91c1c";
}

export function deadlineFrom(iso?: string | null): {
  label: string;
  daysLeft: number | null;
  tone: string;
} {
  const started = iso ? new Date(iso) : null;
  if (!started || Number.isNaN(started.getTime())) {
    return { label: "—", daysLeft: null, tone: "#6b7280" };
  }
  const due = new Date(started.getTime() + VALIDITY_DAYS * 86_400_000);
  const daysLeft = Math.ceil((due.getTime() - Date.now()) / 86_400_000);
  const tone = daysLeft > 30 ? "#15803d" : daysLeft >= 15 ? "#b45309" : "#b91c1c";
  return {
    label: due.toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
      year: "numeric",
    }),
    daysLeft,
    tone,
  };
}

function Field({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div>
      <p className="text-[10px] font-bold uppercase tracking-[0.1em] text-gray-500">
        {label}
      </p>
      <p className="mt-0.5 text-[13px] text-gray-900">{value}</p>
    </div>
  );
}

function Group({
  owner,
  items,
  onAct,
}: {
  owner: Owner;
  items: Condition[];
  /** Resolves true only when the write really landed. "resolved" is
   *  local-only bookkeeping and always resolves true. */
  onAct: (c: Condition, action: string) => Promise<boolean>;
}) {
  const [open, setOpen] = useState(owner === "billing");
  const [done, setDone] = useState<Set<string>>(new Set());
  const [pending, setPending] = useState<string | null>(null);
  const [errors, setErrors] = useState<Record<string, string>>({});
  if (items.length === 0) return null;
  const mine = owner === "billing";

  return (
    <section className="mb-3 overflow-hidden rounded-xl border border-gray-200 bg-white">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        aria-expanded={open}
        className={`flex w-full items-center justify-between gap-2 px-4 py-2.5 text-left ${
          mine ? "bg-accord-green-50" : "bg-gray-50"
        }`}
      >
        <span
          className={`text-[12px] font-bold uppercase tracking-[0.1em] ${
            mine ? "text-accord-green-900" : "text-gray-500"
          }`}
        >
          {OWNER_LABEL[owner]} ({items.length})
        </span>
        <ChevronDown
          size={15}
          className={`text-gray-400 transition-transform ${open ? "rotate-180" : ""}`}
        />
      </button>

      {open && (
        <ul className="divide-y divide-gray-100">
          {items.map((c) => {
            const acted = done.has(c.signal_code);
            return (
              <li key={c.signal_code} className="px-4 py-3">
                <div className="flex flex-wrap items-center gap-1.5">
                  <span aria-hidden="true">
                    {acted ? "✅" : mine ? "●" : "ℹ"}
                  </span>
                  <span className="font-mono text-[11px] font-semibold text-gray-700">
                    {c.signal_code}
                  </span>
                  {c.sla_hours != null && (
                    <span
                      className={`rounded-full border px-1.5 py-0.5 text-[10.5px] font-semibold ${
                        c.sla_hours <= 0
                          ? "border-red-200 bg-red-50 text-red-700"
                          : "border-amber-200 bg-accord-amber-50 text-accord-amber-900"
                      }`}
                    >
                      {c.sla_hours <= 0
                        ? `${Math.abs(c.sla_hours)}h overdue`
                        : `${c.sla_hours}h`}
                    </span>
                  )}
                  {c.assignee && (
                    <span className="text-[11px] capitalize text-gray-500">
                      {c.assignee.replace(/_/g, " ")}
                    </span>
                  )}
                </div>
                <p className="mt-1 text-[12px] leading-relaxed text-gray-600">
                  {c.finding}
                </p>
                {/* payer_citation is the payer's NAME on every one of
                    the 50 library rows — "Delta Dental PPO" — while
                    citation is a real section like D.7.4. Rendering
                    them in one dot-separated line read as two
                    citations. The payer is now labelled as the payer. */}
                {(c.citation || c.payer_citation) && (
                  <p className="mt-1 text-[11px] text-gray-400">
                    {[
                      c.payer_citation && `payer: ${c.payer_citation}`,
                      c.citation && `policy §${c.citation}`,
                    ]
                      .filter(Boolean)
                      .join(" · ")}
                  </p>
                )}
                {/* ⚠ setDone USED TO RUN FIRST, unconditionally — the
                    button read "Notified ✓" whether or not the handoff
                    was written, which is the exact false-success this
                    sweep is about. It now waits for the answer. */}
                <button
                  type="button"
                  disabled={acted || pending === c.signal_code}
                  onClick={() => {
                    setPending(c.signal_code);
                    void onAct(c, mine ? "resolved" : "notified")
                      .then((ok) => {
                        if (ok) {
                          setDone((p) => new Set(p).add(c.signal_code));
                          setErrors((p) => {
                            const next = { ...p };
                            delete next[c.signal_code];
                            return next;
                          });
                        } else {
                          setErrors((p) => ({
                            ...p,
                            [c.signal_code]:
                              "Note not sent — nobody has been told.",
                          }));
                        }
                      })
                      .finally(() => setPending(null));
                  }}
                  className="mt-1.5 rounded-lg border border-gray-300 bg-white px-2.5 py-1 text-[11.5px] font-medium text-gray-700 transition hover:bg-gray-50 disabled:opacity-50"
                >
                  {pending === c.signal_code
                    ? "Sending…"
                    : acted
                    ? mine
                      ? "Resolved ✓"
                      : "Notified ✓"
                    : mine
                      ? "Resolve"
                      : NOTIFY[owner]}
                </button>
                <ActionError message={errors[c.signal_code] ?? null} />
              </li>
            );
          })}
        </ul>
      )}
    </section>
  );
}

/** openConditions already returns the open SIGNALS — same shape as a
 *  Condition for everything this screen reads. */
function conditionsOf(d?: Decision): Condition[] {
  return openConditions(d).map((s: Signal) => s as unknown as Condition);
}

export default function BillingDetail({
  predRequestId,
  onBack,
  backLabel,
  createdAt,
  onToast,
}: {
  predRequestId: string;
  onBack?: () => void;
  backLabel?: string;
  /** pred_requests.created_at, handed over by the queue that linked
   *  here. NOT processed_at off the decision bundle — that is when the
   *  personas last ran, which moves every time the case is re-scored
   *  and would reset a payer deadline that has not moved. */
  createdAt?: string | null;
  onToast: (m: string) => void;
}) {
  const navigate = useNavigate();
  const demoLink = useDemoLink();
  const [tab, setTab] = useState<Tab>("Submission");
  const [submitted, setSubmitted] = useState<string | null>(null);

  const { data: d, isLoading } = useDecision(predRequestId);
  const handoff = useCreateHandoff();
  const { data: ps } = usePatientSummary(predRequestId);
  const { data: appeal } = useAppeal(predRequestId);

  const conditions = useMemo(() => conditionsOf(d), [d]);
  const groups: Record<Owner, Condition[]> = useMemo(() => {
    const g: Record<Owner, Condition[]> = {
      billing: [],
      front_desk: [],
      clinical: [],
    };
    conditions.forEach((c) => g[ownerOf(c.assignee)].push(c));
    return g;
  }, [conditions]);

  const met = d?.readiness_met ?? 0;
  const total = d?.readiness_total ?? 14;
  const pct = total > 0 ? Math.round((met / total) * 100) : 0;
  const deadline = deadlineFrom(createdAt ?? null);

  function submit() {
    const at = new Date().toLocaleTimeString([], {
      hour: "numeric",
      minute: "2-digit",
    });
    setSubmitted(at);
    onToast(`${scenarioId(predRequestId)} submitted to ${d?.plan_name} ✓`);
  }

  return (
    <div className="flex min-h-full flex-col">
      <DetailTopbar
        root="Revenue ops"
        current={d?.patient_name ?? ""}
        back={onBack ? { label: backLabel ?? "Back", onClick: onBack } : undefined}
        actions={[
          {
            label: "Generate appeal",
            onClick: () => navigate(demoLink("/revenue-ops/appeals")),
            title: appeal?.viable
              ? "Open the appeal packet in Revenue ops"
              : "No viable appeal on this pre-D",
            disabled: !appeal?.viable,
          },
        ]}
        primary={{
          label: submitted ? `Submitted ✓ ${submitted}` : "Submit pre-D",
          title: submitTitle(d),
          disabled: !d?.submission_ready || Boolean(submitted),
          onClick: submit,
        }}
      />

      {isLoading && (
        <div className="animate-pulse space-y-3 p-6">
          <div className="h-6 w-52 rounded bg-gray-100" />
          <div className="h-32 rounded-xl bg-gray-100" />
        </div>
      )}

      {d && !isLoading && (
        <main className="min-w-0 flex-1 overflow-auto px-5 py-5 sm:px-6">
          <div className="flex flex-wrap items-center gap-2">
            <h2 className="text-[19px] font-semibold text-gray-900">
              {d.patient_name}
            </h2>
            <DecisionBadge decision={d.decision} />
            <span className="rounded bg-blue-50 px-1.5 py-0.5 text-[9.5px] font-semibold uppercase text-blue-700">
              billing view
            </span>
          </div>
          <p className="mt-0.5 text-[12.5px] text-slate-500">
            {d.plan_name} · {scenarioId(d.pred_request_id)} · {d.state}
          </p>

          <nav className="mt-4 flex gap-4 border-b border-slate-200">
            {TABS.map((t) => (
              <button
                key={t}
                type="button"
                onClick={() => setTab(t)}
                className={`-mb-px border-b-2 pb-2 text-[13px] font-medium transition ${
                  tab === t
                    ? "border-accord-green-900 text-accord-green-900"
                    : "border-transparent text-slate-500 hover:text-slate-800"
                }`}
              >
                {t}
                {t === "Conditions" && conditions.length > 0 && (
                  <span className="ml-1.5 rounded-full bg-gray-100 px-1.5 py-0.5 text-[10px] text-gray-600">
                    {conditions.length}
                  </span>
                )}
              </button>
            ))}
          </nav>

          {/* ── Submission ─────────────────────────────────── */}
          {tab === "Submission" && (
            <div className="mt-4 space-y-3">
              <section className="rounded-xl border border-gray-200 bg-white p-5">
                <div className="grid gap-4 sm:grid-cols-2">
                  <Field
                    label="Pre-D status"
                    value={<DecisionBadge decision={d.decision} />}
                  />
                  <Field
                    label={
                      createdAt
                        ? "Payer deadline (est. 90d)"
                        : "Payer deadline (unknown)"
                    }
                    value={
                      <span style={{ color: deadline.tone }}>
                        Submit by {deadline.label}
                        {deadline.daysLeft != null &&
                          ` · ${deadline.daysLeft} days left`}
                      </span>
                    }
                  />
                </div>

                <div className="mt-5">
                  <div className="flex items-baseline justify-between">
                    <p className="text-[10px] font-bold uppercase tracking-[0.1em] text-gray-500">
                      Submission readiness
                    </p>
                    <span className="text-[12.5px] font-semibold text-gray-900">
                      {met}/{total} · {pct}%
                    </span>
                  </div>
                  <div className="mt-1.5 h-2.5 w-full overflow-hidden rounded-full bg-gray-100">
                    <div
                      style={{ width: `${pct}%` }}
                      className={`h-full ${
                        d.submission_ready
                          ? "bg-accord-green-500"
                          : "bg-amber-400"
                      }`}
                    />
                  </div>
                  <p className="mt-1.5 text-[11.5px] text-gray-500">
                    {d.submission_ready
                      ? "Nothing outstanding — this can go out."
                      : `Blocking: ${
                          groups.billing[0]?.signal_code ??
                          conditions[0]?.signal_code ??
                          "open conditions"
                        }`}
                  </p>
                </div>

                <div className="mt-5 grid gap-4 sm:grid-cols-2">
                  <Field label="Payer" value={d.plan_name} />
                  <Field label="State" value={d.state} />
                </div>
              </section>

              <section className="overflow-hidden rounded-xl border border-gray-200 bg-white">
                <header className="border-b border-gray-200 bg-gray-50 px-4 py-2.5">
                  <h3 className="text-[12px] font-bold uppercase tracking-[0.1em] text-gray-500">
                    Procedures
                  </h3>
                </header>
                {ps ? (
                  <>
                    <ul className="divide-y divide-gray-100">
                      {ps.procedures.map((p) => (
                        <li
                          key={p.cdt_code}
                          className="flex flex-wrap items-center justify-between gap-2 px-4 py-2.5"
                        >
                          <span className="min-w-0 text-[12.5px] text-gray-700">
                            <span className="font-mono font-semibold">
                              {p.cdt_code}
                            </span>{" "}
                            {p.description}
                            {p.tooth_number ? ` · tooth #${p.tooth_number}` : ""}
                            {p.downgrade_applied && (
                              <span className="ml-1 text-amber-700">
                                (downgraded)
                              </span>
                            )}
                          </span>
                          <span className="text-[12.5px] font-medium text-gray-900">
                            {formatCurrency(p.insurance_pays)}
                          </span>
                        </li>
                      ))}
                    </ul>
                    <div className="flex flex-wrap justify-between gap-3 border-t border-gray-200 bg-gray-50 px-4 py-2.5 text-[12.5px]">
                      <span className="text-gray-600">
                        Total plan pays{" "}
                        <span className="font-semibold text-gray-900">
                          {formatCurrency(ps.summary.total_insurance_pays)}
                        </span>
                      </span>
                      <span className="text-gray-600">
                        Patient pays{" "}
                        <span className="font-semibold text-gray-900">
                          {formatCurrency(ps.summary.total_patient_pays)}
                        </span>
                      </span>
                    </div>
                  </>
                ) : (
                  <p className="px-4 py-3 text-[12.5px] text-gray-500">
                    Loading the cost breakdown…
                  </p>
                )}
              </section>
            </div>
          )}

          {/* ── Conditions, grouped by owner ────────────────── */}
          {tab === "Conditions" && (
            <div className="mt-4">
              {conditions.length === 0 && (
                <p className="rounded-xl border border-gray-200 bg-white px-4 py-6 text-[13px] text-accord-green-700">
                  Nothing open — this pre-D is clear to submit.
                </p>
              )}
              {(["billing", "front_desk", "clinical"] as Owner[]).map((o) => (
                <Group
                  key={o}
                  owner={o}
                  items={groups[o]}
                  onAct={async (c, action) => {
                    if (action === "resolved") {
                      // Local bookkeeping only — no request to fail.
                      onToast(`${c.signal_code} marked resolved ✓`);
                      return true;
                    }
                    // "Notified" used to be a toast and nothing else.
                    // It now writes a handoff addressed to the role
                    // that owns the condition, carrying the finding.
                    try {
                      await handoff.mutateAsync({
                        predRequestId,
                        to_role: HANDOFF_TO[o],
                        note: `${d?.patient_name ?? scenarioId(predRequestId)}: ${c.finding}`,
                      });
                      onToast(
                        `${c.assignee?.replace(/_/g, " ")} notified about ${c.signal_code} ✓`,
                      );
                      return true;
                    } catch {
                      return false;
                    }
                  }}
                />
              ))}
              <p className="mt-1 text-[11px] leading-relaxed text-gray-400">
                Only billing conditions can be resolved here. The others are
                someone else&rsquo;s to close, and a biller ticking
                &ldquo;narrative added&rdquo; when no dentist has written one is
                how a pre-D goes out incomplete. Either way the engine clears a
                condition when the pre-D is re-run with the evidence in place.
              </p>
            </div>
          )}

          {/* ── Coverage ────────────────────────────────────── */}
          {tab === "Coverage" && (
            <div className="mt-4 overflow-x-auto rounded-xl border border-gray-200 bg-white">
              {ps ? (
                <>
                  <table className="w-full min-w-[720px] border-collapse text-left">
                    <thead>
                      <tr className="border-b border-gray-200 bg-gray-50">
                        {[
                          "CDT",
                          "Description",
                          "UCR",
                          "Discount",
                          "Contracted",
                          "Plan pays",
                          "Patient pays",
                        ].map((h) => (
                          <th
                            key={h}
                            className="px-3 py-2 text-[10px] font-bold uppercase tracking-[0.1em] text-gray-500"
                          >
                            {h}
                          </th>
                        ))}
                      </tr>
                    </thead>
                    <tbody>
                      {ps.procedures.map((p) => (
                        <tr key={p.cdt_code} className="border-b border-gray-100">
                          <td className="px-3 py-2 font-mono text-[12px] font-semibold text-gray-800">
                            {p.cdt_code}
                          </td>
                          <td className="px-3 py-2 text-[12.5px] text-gray-700">
                            {p.description}
                            {p.downgrade_applied && p.downgrade_note && (
                              <span className="mt-0.5 block text-[11px] text-amber-700">
                                {p.downgrade_note}
                              </span>
                            )}
                          </td>
                          <td className="px-3 py-2 text-[12.5px] text-gray-700">
                            {formatCurrency(p.provider_ucr_fee)}
                          </td>
                          <td className="px-3 py-2 text-[12.5px] text-accord-green-700">
                            −{formatCurrency(p.in_network_discount)}
                          </td>
                          <td className="px-3 py-2 text-[12.5px] text-gray-700">
                            {formatCurrency(p.contracted_rate)}
                          </td>
                          <td className="px-3 py-2 text-[12.5px] font-medium text-gray-900">
                            {formatCurrency(p.insurance_pays)}
                          </td>
                          <td className="px-3 py-2 text-[12.5px] font-medium text-gray-900">
                            {formatCurrency(p.patient_pays)}
                          </td>
                        </tr>
                      ))}
                      <tr className="bg-gray-50 font-semibold">
                        <td className="px-3 py-2 text-[12.5px]" colSpan={2}>
                          Total
                        </td>
                        <td className="px-3 py-2 text-[12.5px]">
                          {formatCurrency(ps.summary.total_provider_charges)}
                        </td>
                        <td className="px-3 py-2 text-[12.5px] text-accord-green-700">
                          −{formatCurrency(ps.summary.total_in_network_savings)}
                        </td>
                        <td className="px-3 py-2 text-[12.5px]">
                          {formatCurrency(ps.summary.total_contracted)}
                        </td>
                        <td className="px-3 py-2 text-[12.5px]">
                          {formatCurrency(ps.summary.total_insurance_pays)}
                        </td>
                        <td className="px-3 py-2 text-[12.5px]">
                          {formatCurrency(ps.summary.total_patient_pays)}
                        </td>
                      </tr>
                    </tbody>
                  </table>
                  <p className="border-t border-gray-100 px-3 py-2.5 text-[11.5px] text-accord-green-700">
                    In-network saving to the patient:{" "}
                    {formatCurrency(ps.summary.total_in_network_savings)}
                  </p>
                  {ps.caveats.length > 0 && (
                    <ul className="border-t border-gray-100 px-3 py-2.5">
                      {ps.caveats.map((c) => (
                        <li key={c} className="text-[11.5px] text-amber-700">
                          ⚠ {c}
                        </li>
                      ))}
                    </ul>
                  )}
                </>
              ) : (
                <p className="px-4 py-6 text-[12.5px] text-gray-500">
                  Loading the cost breakdown…
                </p>
              )}
            </div>
          )}

          {tab === "Audit" && (
            <div className="mt-4">
              <FeedbackAudit />
            </div>
          )}

          {/* Below the tabs, not inside one. Whether the evidence was
              read before filing is a property of the case, not of a
              view of it — and it is the question a payer opens with, so
              it should not be somewhere Kim has to go looking. */}
          <CaseHistory predRequestId={predRequestId} />
        </main>
      )}
    </div>
  );
}
