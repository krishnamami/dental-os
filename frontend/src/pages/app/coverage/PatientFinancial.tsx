import { useQueries, useQuery } from "@tanstack/react-query";
import { useState } from "react";

import { ROLE_LABELS, useAuth } from "../../../context/AuthContext";
import { api, keys } from "../../../hooks/useApi";
import type { PatientSummary } from "../../../types/dental";
import { formatCurrency } from "../../../utils/format";
import {
  COORDINATOR_ITEMS,
  generateEmailText,
  generatePrintHTML,
} from "./estimateDoc";

/**
 * G-01 — the money conversation, at /coverage.
 *
 * Jennifer sits with a patient after check-in and explains what the
 * plan pays and what they owe. Everything here is already computed by
 * dental-os; this page presents it and records that the conversation
 * happened.
 *
 * ── Every figure has one source ──────────────────────────────────────
 *
 * The table, the savings line, the benefit pills and the printed sheet
 * all read the SAME /patient-summary payload. Nothing is recomputed in
 * this file and no percentage is typed — the coverage share is derived
 * from the plan-pays and contracted amounts on the very rows shown
 * underneath it. A patient who adds up the column must get the total,
 * and a printed sheet must match the screen it was printed from.
 */

const GREEN = "#0F4D37";

interface Alert {
  type: string;
  title: string;
  detail: string;
}

interface CheckInPatient {
  pred_request_id: string;
  patient_name: string;
  appointment_time: string;
  procedure_summary: string;
  payer_name: string;
  member_id: string | null;
  enrollment_months: number | null;
  provider_name: string;
  provider_npi: string;
  insurance_active: boolean;
  provider_in_network: boolean;
  deductible_met: boolean;
  deductible_total: number | null;
  deductible_remaining: number | null;
  annual_max: number | null;
  annual_max_remaining: number | null;
  annual_max_remaining_after: number | null;
  patient_pays_today: number | null;
  alerts: Alert[];
  status: "heads_up" | "clear" | "checked_in";
  checked_in_at: string | null;
}

// One list, shared with the printed document. Two copies would let a
// coordinator tick six boxes on screen and print six different ones.
const CHECKLIST = COORDINATOR_ITEMS;

type Bucket = "ready" | "waiting" | "done";

const BUCKET_LABEL: Record<Bucket, string> = {
  ready: "Ready for consultation",
  waiting: "Waiting",
  done: "Consultation done",
};

function firstNameOf(full: string): string {
  return full.replace(/^(Dr|Mr|Mrs|Ms)\.?\s+/i, "").split(/\s+/)[0] ?? "";
}

/** Tile in the dark strip — same shape as the check-in screen's. */
function Tile({ ok, title, detail }: { ok: boolean; title: string; detail: string }) {
  return (
    <div
      className="flex gap-2 rounded-lg p-2.5"
      style={
        ok
          ? { background: "rgba(255,255,255,0.10)" }
          : {
              background: "rgba(255,200,0,0.15)",
              border: "1px solid rgba(255,200,0,0.3)",
            }
      }
    >
      <span className="flex-shrink-0 text-[12px]" aria-hidden="true">
        {ok ? "✅" : "⚠"}
      </span>
      <div className="min-w-0">
        <p
          className="text-[12px] font-medium"
          style={{ color: ok ? "#ffffff" : "#fcd34d" }}
        >
          {title}
        </p>
        <p
          className="mt-0.5 text-[11px] leading-snug"
          style={{ color: ok ? "rgba(255,255,255,0.65)" : "rgba(252,211,77,0.8)" }}
        >
          {detail}
        </p>
      </div>
    </div>
  );
}

function Pill({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-gray-200 bg-white px-3 py-2">
      <p className="text-[10px] uppercase tracking-wide text-slate-500">{label}</p>
      <p className="mt-0.5 text-[12.5px] font-semibold text-slate-800">{value}</p>
    </div>
  );
}

/** The coverage share, computed from the same rows the table shows. */
function sharePhrase(ps: PatientSummary): string {
  const parts = ps.procedures
    .filter((p) => p.contracted_rate > 0)
    .map(
      (p) =>
        `${p.cdt_code} ${Math.round((p.insurance_pays / p.contracted_rate) * 100)}%`,
    );
  return parts.join(" · ") || "—";
}

function StatCard({
  label,
  value,
  tone,
  active,
  onClick,
}: {
  label: string;
  value: number;
  tone: string;
  active: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-pressed={active}
      className={`cursor-pointer rounded-xl border p-5 text-left transition ${
        active
          ? "border-2 border-accord-green-500 bg-accord-green-50 ring-2 ring-accord-green-300"
          : "border-gray-200 bg-white hover:bg-slate-50"
      }`}
    >
      <p className="text-xs uppercase tracking-wide text-slate-500">{label}</p>
      <p className={`mt-1 text-3xl font-semibold ${tone}`}>{value}</p>
    </button>
  );
}

function TableSkeleton() {
  return (
    <div className="animate-pulse space-y-2 px-5 py-4">
      <div className="h-3 w-44 rounded bg-gray-100" />
      {[0, 1, 2].map((i) => (
        <div key={i} className="h-3 w-full rounded bg-gray-100" />
      ))}
      <div className="h-3 w-2/3 rounded bg-gray-100" />
    </div>
  );
}

function PatientCard({
  p,
  ps,
  loadingSummary,
  practice,
  address,
  checked,
  onToggle,
  done,
  onComplete,
  onToast,
}: {
  p: CheckInPatient;
  ps?: PatientSummary;
  loadingSummary: boolean;
  practice: string;
  address: string;
  checked: Set<number>;
  onToggle: (i: number) => void;
  done: boolean;
  onComplete: () => void;
  onToast: (m: string) => void;
}) {
  // No navigate/demoLink here any more. The card no longer routes
  // anywhere — the coordinator's work ends on this screen.
  const heads = p.alerts.length > 0;
  const downgrade = ps?.procedures.find((x) => x.downgrade_applied);
  const progress = checked.size;

  return (
    <article className="mb-3 overflow-hidden rounded-xl border border-gray-200 bg-white">
      <div className="flex flex-wrap items-center gap-2 px-5 pt-4">
        <span
          aria-hidden="true"
          className="h-2 w-2 flex-shrink-0 rounded-full"
          style={{ backgroundColor: heads && !done ? "#d97706" : "#16a34a" }}
        />
        <span className="text-sm font-semibold text-slate-800">
          {p.patient_name}
        </span>
        <span className="text-sm text-slate-500">
          {p.procedure_summary} · {p.appointment_time}
        </span>
        <span
          className={`ml-auto rounded-full px-2.5 py-0.5 text-[11px] font-bold ${
            done
              ? "bg-slate-100 text-slate-600"
              : p.status === "checked_in"
                ? "bg-green-100 text-green-700"
                : "bg-amber-100 text-amber-700"
          }`}
        >
          {done
            ? "CONSULTATION DONE"
            : p.status === "checked_in"
              ? "READY"
              : "WAITING"}
        </span>
      </div>

      <div className="mt-3 px-5 py-3.5" style={{ background: GREEN }}>
        <p className="text-[10px] uppercase tracking-wider text-white/55">
          At a glance
        </p>
        <div className="mt-2 grid gap-2 sm:grid-cols-2">
          <Tile
            ok={p.insurance_active}
            title="Insurance active"
            detail={`${p.payer_name}${p.member_id ? ` · member ${p.member_id}` : ""}${
              p.enrollment_months ? ` · enrolled ${p.enrollment_months} months` : ""
            }`}
          />
          <Tile
            ok={p.provider_in_network}
            title="Provider in-network"
            detail={`${p.provider_name} · NPI ${p.provider_npi} · verified`}
          />
          <Tile
            ok={p.deductible_met}
            title={p.deductible_met ? "Deductible met" : "Deductible outstanding"}
            detail={
              p.deductible_met
                ? "Nothing more owed on the deductible"
                : `${formatCurrency(p.deductible_remaining)} still to meet this year`
            }
          />
          {heads ? (
            <Tile
              ok={false}
              title={`${p.alerts.length} item${p.alerts.length > 1 ? "s" : ""} to raise`}
              detail={p.alerts.map((a) => a.title).join(" · ")}
            />
          ) : (
            <Tile ok title="Nothing to flag" detail="Straightforward conversation" />
          )}
        </div>
      </div>

      {loadingSummary && <TableSkeleton />}

      {ps && (
        <>
          <div className="px-5 pt-4">
            <p className="text-[13px] font-semibold text-slate-800">
              Treatment plan · {ps.patient_name}
            </p>
            <p className="text-[11.5px] text-slate-500">
              {ps.plan_name} · {ps.provider_name} · {ps.state}
            </p>

            <div className="mt-2.5 overflow-x-auto rounded-lg border border-gray-200">
              <table className="w-full min-w-[520px] text-left">
                <thead className="border-b border-gray-200 bg-slate-50">
                  <tr className="text-[10px] font-semibold uppercase tracking-wide text-slate-500">
                    <th className="px-3 py-2">Procedure</th>
                    <th className="px-3 py-2">Description</th>
                    <th className="px-3 py-2 text-right">Plan pays</th>
                    <th className="px-3 py-2 text-right">Patient pays</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {ps.procedures.map((x) => (
                    <tr key={x.cdt_code}>
                      <td className="px-3 py-2 font-mono text-[12px] text-slate-700">
                        {x.cdt_code}
                      </td>
                      <td className="px-3 py-2 text-[12.5px] text-slate-600">
                        {x.description ?? "—"}
                        {x.tooth_number ? ` · tooth #${x.tooth_number}` : ""}
                        {x.downgrade_applied ? " (at the lower rate)" : ""}
                      </td>
                      <td className="px-3 py-2 text-right text-[12.5px] tabular-nums text-slate-700">
                        {formatCurrency(x.insurance_pays)}
                      </td>
                      <td className="px-3 py-2 text-right text-[12.5px] font-medium tabular-nums text-slate-900">
                        {formatCurrency(x.patient_pays)}
                      </td>
                    </tr>
                  ))}
                  <tr className="bg-slate-50">
                    <td className="px-3 py-2.5 text-[12.5px] font-semibold" colSpan={2}>
                      Total
                    </td>
                    <td className="px-3 py-2.5 text-right text-[13px] font-bold tabular-nums text-slate-800">
                      {formatCurrency(ps.summary.total_insurance_pays)}
                    </td>
                    <td className="px-3 py-2.5 text-right text-[15px] font-bold tabular-nums text-slate-900">
                      {formatCurrency(ps.summary.total_patient_pays)}
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>

            <p className="mt-2 rounded-lg bg-green-50 px-3 py-2 text-[12.5px] text-green-800">
              Your in-network savings of{" "}
              {formatCurrency(ps.summary.total_in_network_savings)} are not your
              responsibility.
            </p>

            {downgrade && (
              <p className="mt-2 rounded-lg border-l-4 border-l-amber-400 bg-amber-50 px-3 py-2 text-[12.5px] text-amber-900">
                ⚠ {downgrade.downgrade_note ??
                  `${downgrade.cdt_code} is reimbursed at a lower material's rate. The patient is responsible for the difference.`}
              </p>
            )}

            <div className="mt-3 grid grid-cols-2 gap-2 lg:grid-cols-4">
              <Pill
                label="Annual max"
                value={`${formatCurrency(p.annual_max)} · ${formatCurrency(p.annual_max_remaining)} left`}
              />
              <Pill
                label="Deductible"
                value={
                  p.deductible_met
                    ? `${formatCurrency(p.deductible_total)} · met`
                    : `${formatCurrency(p.deductible_remaining)} to meet`
                }
              />
              {/* Percentages derived from the rows above, so the pill
                  cannot contradict the table under it. */}
              <Pill label="Plan pays" value={sharePhrase(ps)} />
              <Pill
                label="After this case"
                value={formatCurrency(p.annual_max_remaining_after)}
              />
            </div>
          </div>

          {heads && (
            <div className="px-5 pt-4">
              <p className="text-xs font-bold uppercase tracking-wide text-amber-600">
                Important notes
              </p>
              <div className="mt-2 space-y-2">
                {p.alerts.map((a) => (
                  <div
                    key={a.type}
                    className="rounded border-l-4 border-l-amber-400 bg-amber-50 px-3 py-2"
                  >
                    <p className="text-[13px] font-semibold text-amber-900">
                      {a.title}
                    </p>
                    <p className="mt-0.5 text-sm text-slate-600">{a.detail}</p>
                  </div>
                ))}
              </div>
            </div>
          )}

          <div className="px-5 pt-4">
            <div className="flex items-baseline justify-between gap-2">
              <p className="text-[13px] font-semibold text-slate-800">
                Conversation checklist
              </p>
              <p className="text-[11.5px] text-slate-500">
                {progress}/{CHECKLIST.length} complete
              </p>
            </div>
            <div className="mt-1.5 h-1.5 w-full overflow-hidden rounded bg-gray-200">
              <div
                className="h-full rounded transition-all"
                style={{
                  width: `${(progress / CHECKLIST.length) * 100}%`,
                  background: GREEN,
                }}
              />
            </div>
            <ul className="mt-2 space-y-0.5">
              {CHECKLIST.map((item, i) => (
                <li key={item}>
                  <label className="flex cursor-pointer items-center gap-2.5 rounded px-1.5 py-1.5 transition hover:bg-slate-50">
                    <input
                      type="checkbox"
                      checked={checked.has(i)}
                      onChange={() => onToggle(i)}
                      className="h-4 w-4 rounded border-gray-300 text-accord-green-900 focus:ring-accord-green-500"
                    />
                    <span className="text-[13px] text-slate-700">
                      {item}
                      {/* The figure is named in the item itself, so a
                          coordinator cannot tick "confirmed" against a
                          number they never said out loud. */}
                      {i === 2 &&
                        ` (${formatCurrency(ps.summary.total_patient_pays)})`}
                    </span>
                  </label>
                </li>
              ))}
            </ul>
          </div>

          <div className="flex flex-wrap gap-2 px-5 py-4">
            <button
              type="button"
              onClick={onComplete}
              disabled={done}
              className="cursor-pointer rounded-lg border-none px-4 py-2 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-60"
              style={{ backgroundColor: GREEN }}
            >
              {done ? "Consultation complete ✓" : "Mark consultation complete"}
            </button>
            <button
              type="button"
              onClick={() => {
                const w = window.open("", "_blank", "width=900,height=1100");
                if (!w) return onToast("Allow pop-ups to print");
                w.document.write(
                  generatePrintHTML(p, ps, checked, practice, address),
                );
                w.document.close();
              }}
              className="cursor-pointer rounded-lg border border-slate-200 bg-white px-4 py-2 text-sm text-slate-600 transition hover:bg-slate-50"
            >
              Print estimate
            </button>
            <button
              type="button"
              onClick={() => {
                const text = generateEmailText(p, ps, checked, practice, address);
                navigator.clipboard
                  ?.writeText(text)
                  .then(() => onToast("Email content copied ✓"))
                  .catch(() => onToast("Could not copy — check clipboard permission"));
              }}
              className="cursor-pointer rounded-lg border border-slate-200 bg-white px-4 py-2 text-sm text-slate-600 transition hover:bg-slate-50"
            >
              Email to patient
            </button>
          </div>
        </>
      )}
    </article>
  );
}

export default function PatientFinancial() {
  const { effectiveUser, role } = useAuth();
  const [toast, setToast] = useState<string | null>(null);
  const [filter, setFilter] = useState<Bucket | "all">("all");
  const [doneIds, setDoneIds] = useState<Set<string>>(new Set());
  const [checks, setChecks] = useState<Record<string, Set<number>>>({});

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: ["checkin", "today"],
    queryFn: async () => (await api.get<CheckInPatient[]>("/checkin/today")).data,
    refetchInterval: 30_000,
  });
  const patients = Array.isArray(data) ? data : [];

  // One query per patient, cached under the SAME key /coverage/:id uses,
  // so opening a patient's full breakdown is instant and cannot show a
  // different number than the card did.
  const summaries = useQueries({
    queries: patients.map((p) => ({
      queryKey: keys.patientSummary(p.pred_request_id),
      queryFn: async () =>
        (
          await api.get<PatientSummary>(
            `/decisions/${p.pred_request_id}/patient-summary`,
          )
        ).data,
      staleTime: 5 * 60_000,
    })),
  });

  function flash(m: string) {
    setToast(m);
    window.setTimeout(() => setToast(null), 3000);
  }

  const bucketOf = (p: CheckInPatient): Bucket =>
    doneIds.has(p.pred_request_id)
      ? "done"
      : p.status === "checked_in"
        ? "ready"
        : "waiting";

  const all = { ready: [], waiting: [], done: [] } as Record<Bucket, CheckInPatient[]>;
  patients.forEach((p) => all[bucketOf(p)].push(p));
  const shown = (b: Bucket) => (filter === "all" || filter === b ? all[b] : []);

  const firstName = firstNameOf(effectiveUser?.name ?? "");
  const practice = effectiveUser?.tenant_name ?? "Accord Dental";
  const address = effectiveUser?.tenant_address ?? "";

  function renderSection(b: Bucket) {
    const list = shown(b);
    if (list.length === 0) return null;
    return (
      <section className="mt-6" key={b}>
        <h2 className="mb-3 text-sm font-semibold text-slate-600">
          {BUCKET_LABEL[b].toUpperCase()} ({list.length})
        </h2>
        {list.map((p) => {
          const i = patients.indexOf(p);
          const q = summaries[i];
          return (
            <PatientCard
              key={p.pred_request_id}
              p={p}
              ps={q?.data}
              loadingSummary={Boolean(q?.isLoading)}
              practice={practice}
              address={address}
              done={doneIds.has(p.pred_request_id)}
              checked={checks[p.pred_request_id] ?? new Set<number>()}
              onToggle={(idx) =>
                setChecks((prev) => {
                  const next = new Set(prev[p.pred_request_id] ?? []);
                  if (next.has(idx)) next.delete(idx);
                  else next.add(idx);
                  return { ...prev, [p.pred_request_id]: next };
                })
              }
              onComplete={() => {
                setDoneIds((prev) => new Set(prev).add(p.pred_request_id));
                flash(`Consultation complete ✓ — ${p.patient_name}`);
              }}
              onToast={flash}
            />
          );
        })}
      </section>
    );
  }

  // No tab bar. This page is the whole of the coordinator's screen —
  // the "All pre-Ds" tab pointed at /coverage/all, which is the
  // reviewer's queue and is not part of this job. The route still
  // exists for the roles that hold it; it is just not reachable from
  // here.
  return (
    <div className="relative min-h-full pb-16">
      <div className="mx-auto max-w-4xl px-6 py-6">
        <div>
          <h1 className="text-[22px] font-semibold text-gray-900">
            Good morning{firstName ? `, ${firstName}` : ""}
          </h1>
          <p className="mt-0.5 text-[13px] text-slate-500">
            {role ? ROLE_LABELS[role] : ""}
            {role && " · "}
            {practice}
          </p>
        </div>

        <div className="mt-5 grid grid-cols-3 gap-3">
          <StatCard
            label="Ready for consultation"
            value={all.ready.length}
            tone="text-green-600"
            active={filter === "ready"}
            onClick={() => setFilter((f) => (f === "ready" ? "all" : "ready"))}
          />
          <StatCard
            label="Waiting"
            value={all.waiting.length}
            tone="text-amber-600"
            active={filter === "waiting"}
            onClick={() => setFilter((f) => (f === "waiting" ? "all" : "waiting"))}
          />
          <StatCard
            label="Consultation done"
            value={all.done.length}
            tone="text-slate-400"
            active={filter === "done"}
            onClick={() => setFilter((f) => (f === "done" ? "all" : "done"))}
          />
        </div>

        {filter !== "all" && (
          <button
            type="button"
            onClick={() => setFilter("all")}
            className="mb-3 mt-4 text-sm text-slate-500 transition hover:text-slate-800"
          >
            ← All patients
          </button>
        )}

        {isLoading && (
          <div className="mt-6 space-y-3">
            {[0, 1, 2].map((i) => (
              <div
                key={i}
                className="animate-pulse rounded-xl border border-gray-200 bg-white p-5"
              >
                <div className="h-3 w-52 rounded bg-gray-100" />
                <div className="mt-3 h-20 rounded-lg bg-gray-100" />
                <div className="mt-3 h-16 rounded bg-gray-100" />
              </div>
            ))}
          </div>
        )}

        {isError && !isLoading && (
          <div className="mt-6 rounded-xl border border-red-200 bg-red-50 p-5">
            <p className="text-[13.5px] font-medium text-red-700">
              Could not load today&rsquo;s patients.
            </p>
            <button
              type="button"
              onClick={() => void refetch()}
              className="mt-3 rounded-lg border border-red-300 px-3 py-1.5 text-[12.5px] font-medium text-red-700 transition hover:bg-red-100"
            >
              Retry
            </button>
          </div>
        )}

        {!isLoading && !isError && patients.length === 0 && (
          <p className="mt-6 rounded-xl border border-gray-200 bg-white p-5 text-[13px] text-slate-500">
            No patients scheduled for today.
          </p>
        )}

        {renderSection("ready")}
        {renderSection("waiting")}
        {renderSection("done")}

        {!isLoading &&
          patients.length > 0 &&
          shown("ready").length + shown("waiting").length + shown("done").length ===
            0 && (
            <p className="mt-6 rounded-xl border border-gray-200 bg-white p-5 text-[13px] text-slate-500">
              No patients in that group right now.
            </p>
          )}

        {patients.length > 0 && (
          <p className="mt-6 text-[11px] leading-relaxed text-gray-400">
            Live from dental-os. The checklist and &ldquo;consultation
            complete&rdquo; are remembered in this tab only — there is no
            consultation record in dental-os yet.
          </p>
        )}
      </div>

      {toast && (
        <div
          role="status"
          className="pointer-events-none absolute inset-x-0 bottom-4 flex justify-center"
        >
          <span
            className="rounded-lg px-4 py-2.5 text-[13px] font-medium text-white shadow-lg"
            style={{ backgroundColor: GREEN }}
          >
            {toast}
          </span>
        </div>
      )}
    </div>
  );
}
