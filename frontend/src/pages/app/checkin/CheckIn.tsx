import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";

import { DatePickerDropdown } from "../../../components/DatePickerDropdown";
import { useDatePicker } from "../../../hooks/useDatePicker";
import { ROLE_LABELS, useAuth } from "../../../context/AuthContext";
import { api } from "../../../hooks/useApi";
import { useDemo } from "../../../hooks/useDemo";

/**
 * F-01 — patient check-in, from GET /checkin/today.
 *
 * One request for the whole morning. The endpoint does the joining and
 * the translating; this file renders what it returns and reads nothing
 * else. That is what keeps a signal code, a wave number and a criteria
 * score off a receptionist's screen — they never reach the browser.
 *
 * ── Demo mode writes nothing ─────────────────────────────────────────
 *
 * POST /checkin is a write, and X-Demo-Mode is refused on writes by
 * design: an anonymous header must not mutate shared state. So a demo
 * visitor's check-in is kept in local state and the card says so. A
 * signed-in user's goes to the database and survives a refresh.
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
  deductible_remaining: number | null;
  annual_max_remaining_after: number | null;
  patient_pays_today: number | null;
  alerts: Alert[];
  status: "heads_up" | "clear" | "checked_in";
  checked_in_at: string | null;
}

const BADGE: Record<string, { label: string; cls: string }> = {
  heads_up: { label: "HEADS UP", cls: "bg-amber-100 text-amber-700" },
  clear: { label: "CLEAR", cls: "bg-green-100 text-green-700" },
  checked_in: { label: "CHECKED IN", cls: "bg-green-100 text-green-700" },
};

function money(v: number | null): string {
  return v == null
    ? "—"
    : v.toLocaleString(undefined, {
        style: "currency",
        currency: "USD",
        maximumFractionDigits: 0,
      });
}

function timeOf(iso: string | null): string {
  if (!iso) return "";
  const d = new Date(iso);
  return Number.isNaN(d.getTime())
    ? ""
    : d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

function firstNameOf(full: string): string {
  return full.replace(/^(Dr|Mr|Mrs|Ms)\.?\s+/i, "").split(/\s+/)[0] ?? "";
}

/** One tile in the dark summary strip. */
function Tile({
  ok,
  title,
  detail,
}: {
  ok: boolean;
  title: string;
  detail: string;
}) {
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

/**
 * A one-page summary the patient takes away.
 *
 * A new window rather than window.print(), because printing the app
 * would put the sidebar and today's other patients on paper — other
 * people's names on a sheet handed to this one.
 */
function openPrintWindow(p: CheckInPatient, tenantName: string) {
  const esc = (v: string) =>
    v.replace(/[&<>"]/g, (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c] ?? c,
    );
  const notes = p.alerts
    .map(
      (a) =>
        `<div style="border-left:3px solid #f59e0b;background:#fffbeb;padding:8px 10px;margin-bottom:6px;border-radius:4px">
           <div style="font-size:12px;font-weight:600;color:#92400e">${esc(a.title)}</div>
           <div style="font-size:11px;color:#57534e;margin-top:2px">${esc(a.detail)}</div>
         </div>`,
    )
    .join("");

  const html = `<!doctype html><html><head><meta charset="utf-8">
    <title>Check-in · ${esc(p.patient_name)}</title>
    <style>
      body{font-family:system-ui,sans-serif;background:#f9fafb;margin:0}
      .card{max-width:420px;margin:30px auto;background:#fff;border-radius:12px;
            overflow:hidden;border:1px solid #e5e7eb}
      .hdr{background:${GREEN};color:#fff;padding:16px 20px}
      .body{padding:18px 20px}
      td{padding:3px 0;font-size:12px}
      @media print{.no-print{display:none}body{background:#fff}}
    </style></head><body>
    <div class="card">
      <div class="hdr">
        <div style="font-size:16px;font-weight:600">${esc(tenantName)}</div>
        <div style="font-size:11px;opacity:.75">Check-in summary · ${new Date().toLocaleDateString()}</div>
      </div>
      <div class="body">
        <div style="font-size:16px;font-weight:600">${esc(p.patient_name)}</div>
        <div style="font-size:12px;color:#6b7280;margin-top:3px">
          ${esc(p.procedure_summary)} · ${esc(p.appointment_time)} · ${esc(p.provider_name)}
        </div>
        <div style="margin-top:14px;padding-top:14px;border-top:1px solid #e5e7eb">
          <div style="font-size:11px;font-weight:700;text-transform:uppercase;margin-bottom:8px">Insurance status</div>
          <table style="width:100%;border-collapse:collapse">
            <tr><td style="color:#6b7280">Plan</td><td style="font-weight:500">${esc(p.payer_name)}</td></tr>
            <tr><td style="color:#6b7280">Member</td><td style="font-weight:500">${esc(p.member_id ?? "—")}</td></tr>
            <tr><td style="color:#6b7280">Status</td><td style="color:#16a34a;font-weight:500">Active</td></tr>
            <tr><td style="color:#6b7280">Network</td><td style="color:#16a34a;font-weight:500">In-network</td></tr>
            ${
              p.deductible_remaining != null && p.deductible_remaining > 0
                ? `<tr><td style="color:#6b7280">Deductible</td><td style="font-weight:500">${money(p.deductible_remaining)} still to meet</td></tr>`
                : ""
            }
          </table>
        </div>
        ${
          notes
            ? `<div style="margin-top:14px;padding-top:14px;border-top:1px solid #e5e7eb">
                 <div style="font-size:11px;font-weight:700;color:#b45309;text-transform:uppercase;margin-bottom:8px">Before your appointment</div>
                 ${notes}
               </div>`
            : ""
        }
        <div style="margin-top:14px;padding:12px;background:#f0fdf4;border-radius:8px;font-size:12px;color:#374151;font-style:italic">
          A treatment coordinator will review your full cost estimate and answer
          any questions shortly. Figures are an estimate based on current
          benefits and may change.
        </div>
      </div>
    </div>
    <div class="no-print" style="text-align:center;margin:16px">
      <button onclick="window.print()" style="background:${GREEN};color:#fff;border:none;padding:10px 28px;border-radius:8px;font-size:14px;cursor:pointer;font-weight:600">Print ↓</button>
    </div></body></html>`;

  const w = window.open("", "_blank", "width=520,height=680");
  if (!w) return false;
  w.document.write(html);
  w.document.close();
  return true;
}

function PatientCard({
  p,
  tenantName,
  localTime,
  busy,
  past,
  onCheckIn,
  onPrintBlocked,
}: {
  p: CheckInPatient;
  tenantName: string;
  localTime?: string;
  busy: boolean;
  /** Viewing a day that is not today — arrivals cannot be recorded. */
  past: boolean;
  onCheckIn: () => void;
  onPrintBlocked: () => void;
}) {
  const at = p.checked_in_at ? timeOf(p.checked_in_at) : localTime;
  const done = Boolean(at);
  const badge = BADGE[done ? "checked_in" : p.status] ?? BADGE.clear;
  const heads = p.alerts.length > 0;

  return (
    <article className="mb-3 overflow-hidden rounded-xl border border-gray-200 bg-white">
      <div className="flex flex-wrap items-center gap-2 px-5 pt-4">
        <span
          aria-hidden="true"
          className="h-2 w-2 flex-shrink-0 rounded-full"
          style={{ backgroundColor: done || !heads ? "#16a34a" : "#d97706" }}
        />
        <span className="text-sm font-semibold text-slate-800">
          {p.patient_name}
        </span>
        <span className="text-sm text-slate-500">
          {p.procedure_summary} · {p.appointment_time}
        </span>
        <span
          className={`ml-auto rounded-full px-2.5 py-0.5 text-[11px] font-bold ${badge.cls}`}
        >
          {badge.label}
        </span>
      </div>

      {/* Dark strip: the four facts, impossible to scroll past. */}
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
          {/* Not "deductible met" unless it is. The API returns the
              amount outstanding and this says so — a patient told the
              deductible is met, then billed for it, is the complaint
              this avoids. */}
          <Tile
            ok={p.deductible_met}
            title={p.deductible_met ? "Deductible met" : "Deductible outstanding"}
            detail={
              p.deductible_met
                ? "Nothing more owed on the deductible"
                : `${money(p.deductible_remaining)} still to meet this year`
            }
          />
          {heads ? (
            <Tile
              ok={false}
              title={`${p.alerts.length} item${p.alerts.length > 1 ? "s" : ""} need attention`}
              detail={p.alerts.map((a) => a.title).join(" · ")}
            />
          ) : (
            <Tile
              ok
              title="All clear — ready to check in"
              detail="No issues for today's visit"
            />
          )}
        </div>
      </div>

      {heads && (
        <div className="px-5 pt-4">
          <p className="text-xs font-bold uppercase tracking-wide text-amber-600">
            Before check-in
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
          <p className="mt-2 text-[12.5px] italic text-slate-400">
            A treatment coordinator will review the full cost estimate with{" "}
            {firstNameOf(p.patient_name)} shortly.
          </p>
        </div>
      )}

      <div className="flex flex-wrap gap-2 px-5 py-4">
        {/* POST /checkin stamps checkin_day with the SERVER's today, so
            checking someone in while looking at last Tuesday would file
            the arrival under the wrong day and silently move a card on
            the live screen. Read-only is the honest state here. */}
        <button
          type="button"
          onClick={onCheckIn}
          disabled={done || busy || past}
          title={past ? "Arrivals can only be recorded on the day" : undefined}
          className="cursor-pointer rounded-lg border-none px-4 py-2 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-60"
          style={{ backgroundColor: GREEN }}
        >
          {done
            ? `Checked in at ${at}`
            : past
              ? "Not today"
              : busy
                ? "Checking in…"
                : "Check in patient ✓"}
        </button>
        <button
          type="button"
          onClick={() => {
            if (!openPrintWindow(p, tenantName)) onPrintBlocked();
          }}
          className="cursor-pointer rounded-lg border border-slate-200 bg-white px-4 py-2 text-sm text-slate-600 transition hover:bg-slate-50"
        >
          Print for patient
        </button>
      </div>
    </article>
  );
}

type Filter = "all" | "heads_up" | "clear" | "checked_in";

const FILTER_STYLE: Record<
  Exclude<Filter, "all">,
  { active: string; ring: string }
> = {
  heads_up: { active: "border-amber-400 bg-amber-50", ring: "ring-amber-300" },
  clear: { active: "border-green-500 bg-green-50", ring: "ring-green-300" },
  checked_in: { active: "border-slate-400 bg-slate-50", ring: "ring-slate-300" },
};

/**
 * A count and a filter in one control.
 *
 * The number is always the TOTAL for that status, never the filtered
 * view — a card that changed its own number when you clicked it would
 * make it impossible to see what you had narrowed away from.
 */
function StatCard({
  label,
  value,
  tone,
  status,
  active,
  onClick,
}: {
  label: string;
  value: number;
  tone: string;
  status: Exclude<Filter, "all">;
  active: boolean;
  onClick: () => void;
}) {
  const style = FILTER_STYLE[status];
  return (
    <button
      type="button"
      onClick={onClick}
      aria-pressed={active}
      className={`cursor-pointer rounded-xl border p-5 text-left transition ${
        active
          ? `border-2 ${style.active} ring-2 ${style.ring}`
          : "border-gray-200 bg-white hover:bg-slate-50"
      }`}
    >
      <p className="text-xs uppercase tracking-wide text-slate-500">{label}</p>
      <p className={`mt-1 text-3xl font-semibold ${tone}`}>{value}</p>
    </button>
  );
}

export default function CheckIn() {
  const { effectiveUser, role } = useAuth();
  const { isDemo } = useDemo();
  const queryClient = useQueryClient();
  const [toast, setToast] = useState<string | null>(null);
  const [filter, setFilter] = useState<Filter>("all");
  // Demo mode cannot write, so its check-ins live here instead.
  const [localCheckIn, setLocalCheckIn] = useState<Record<string, string>>({});
  const { selectedDate, setSelectedDate, availableDates, today } =
    useDatePicker();

  // The date is in the KEY, not just the URL. Without it React Query
  // serves the previous day's cached list under the same key while the
  // new one loads, and the screen shows yesterday's patients captioned
  // with today's date.
  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: ["checkin", "today", selectedDate],
    queryFn: async () =>
      (
        await api.get<CheckInPatient[]>(
          `/checkin/today?date=${encodeURIComponent(selectedDate)}`,
        )
      ).data,
    refetchInterval: 30_000,
  });
  const patients = Array.isArray(data) ? data : [];

  function flash(msg: string) {
    setToast(msg);
    window.setTimeout(() => setToast(null), 3000);
  }

  const checkInMutation = useMutation({
    mutationFn: async (p: CheckInPatient) => {
      await api.post("/checkin", {
        pred_request_id: p.pred_request_id,
        patient_name: p.patient_name,
      });
    },
    onSuccess: (_r, p) => {
      void queryClient.invalidateQueries({ queryKey: ["checkin", "today"] });
      flash(`${p.patient_name} checked in ✓`);
    },
    onError: (_e, p) => flash(`Could not check ${p.patient_name} in`),
  });

  function checkIn(p: CheckInPatient) {
    if (isDemo) {
      // No write in demo mode — the API refuses it, correctly.
      setLocalCheckIn((prev) => ({
        ...prev,
        [p.pred_request_id]: new Date().toLocaleTimeString([], {
          hour: "2-digit",
          minute: "2-digit",
        }),
      }));
      flash(`${p.patient_name} checked in ✓ (demo — not saved)`);
      return;
    }
    checkInMutation.mutate(p);
  }

  const isDone = (p: CheckInPatient) =>
    p.status === "checked_in" || Boolean(localCheckIn[p.pred_request_id]);

  // ONE definition of where a patient sits, used by the counts, the
  // sections and the filter alike. p.status alone is not it: a demo
  // check-in is local, so the API still calls that patient heads_up.
  // Filtering on the raw field would file them under HEADS UP while
  // the CHECKED IN card counted them — two answers on one screen.
  const statusOf = (p: CheckInPatient): Exclude<Filter, "all"> =>
    isDone(p) ? "checked_in" : p.status;

  const inBucket = (s: Exclude<Filter, "all">) =>
    patients.filter((p) => statusOf(p) === s);

  const isPast = selectedDate !== today;
  const allHeadsUp = inBucket("heads_up");
  const allClear = inBucket("clear");
  const allSeen = inBucket("checked_in");

  const shows = (s: Exclude<Filter, "all">) => filter === "all" || filter === s;
  const headsUp = shows("heads_up") ? allHeadsUp : [];
  const clear = shows("clear") ? allClear : [];
  const seen = shows("checked_in") ? allSeen : [];

  function toggle(s: Exclude<Filter, "all">) {
    setFilter((f) => (f === s ? "all" : s));
  }

  const firstName = firstNameOf(effectiveUser?.name ?? "");
  const tenantName = effectiveUser?.tenant_name ?? "Accord Dental";

  return (
    <div className="relative min-h-full pb-16">
      <div className="mx-auto max-w-3xl px-6 py-6">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h1 className="text-[22px] font-semibold text-gray-900">
              Good morning{firstName ? `, ${firstName}` : ""}
            </h1>
            <p className="mt-0.5 text-[13px] text-slate-500">
              {role ? ROLE_LABELS[role] : ""}
              {role && " · "}
              {tenantName}
            </p>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <DatePickerDropdown
              selectedDate={selectedDate}
              availableDates={availableDates}
              onChange={setSelectedDate}
            />
            {!isLoading && (
              <span
                className={`rounded-full px-3 py-1 text-[12px] font-semibold ${
                  allHeadsUp.length > 0
                    ? "bg-amber-50 text-amber-700"
                    : "bg-green-50 text-green-700"
                }`}
              >
                {allHeadsUp.length > 0
                  ? `⚠ ${allHeadsUp.length} heads up`
                  : "✅ All clear"}
              </span>
            )}
          </div>
        </div>

        <div className="mt-5 grid grid-cols-3 gap-3">
          <StatCard
            label="Heads up"
            value={allHeadsUp.length}
            tone="text-amber-600"
            status="heads_up"
            active={filter === "heads_up"}
            onClick={() => toggle("heads_up")}
          />
          <StatCard
            label="Clear"
            value={allClear.length}
            tone="text-green-600"
            status="clear"
            active={filter === "clear"}
            onClick={() => toggle("clear")}
          />
          <StatCard
            label="Checked in"
            value={allSeen.length}
            tone="text-slate-400"
            status="checked_in"
            active={filter === "checked_in"}
            onClick={() => toggle("checked_in")}
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
                <div className="mt-3 h-8 w-40 rounded bg-gray-100" />
              </div>
            ))}
          </div>
        )}

        {isError && !isLoading && (
          <div className="mt-6 rounded-xl border border-red-200 bg-red-50 p-5">
            <p className="text-[13.5px] font-medium text-red-700">
              Could not load today&rsquo;s patients.
            </p>
            <p className="mt-1 text-[12.5px] text-red-600">
              The dental-os API did not answer.
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

        {!isLoading &&
          !isError &&
          patients.length > 0 &&
          headsUp.length + clear.length + seen.length === 0 && (
            <p className="mt-6 rounded-xl border border-gray-200 bg-white p-5 text-[13px] text-slate-500">
              No patients in that group right now.
            </p>
          )}

        {headsUp.length > 0 && (
          <section className="mt-6">
            <h2 className="mb-3 text-sm font-semibold text-slate-600">
              ⚠ HEADS UP BEFORE CHECK-IN ({headsUp.length})
            </h2>
            {headsUp.map((p) => (
              <PatientCard
                key={p.pred_request_id}
                p={p}
                tenantName={tenantName}
                busy={checkInMutation.isPending}
                past={isPast}
                onCheckIn={() => checkIn(p)}
                onPrintBlocked={() => flash("Allow pop-ups to print")}
              />
            ))}
          </section>
        )}

        {clear.length > 0 && (
          <section className="mt-6">
            <h2 className="mb-3 text-sm font-semibold text-slate-600">
              ✅ CLEAR TO CHECK IN ({clear.length})
            </h2>
            {clear.map((p) => (
              <PatientCard
                key={p.pred_request_id}
                p={p}
                tenantName={tenantName}
                busy={checkInMutation.isPending}
                past={isPast}
                onCheckIn={() => checkIn(p)}
                onPrintBlocked={() => flash("Allow pop-ups to print")}
              />
            ))}
          </section>
        )}

        {seen.length > 0 && (
          <section className="mt-6">
            <h2 className="mb-3 text-sm font-semibold text-slate-600">
              CHECKED IN ({seen.length})
            </h2>
            {seen.map((p) => (
              <PatientCard
                key={p.pred_request_id}
                p={p}
                tenantName={tenantName}
                localTime={localCheckIn[p.pred_request_id]}
                busy={false}
                past={isPast}
                onCheckIn={() => checkIn(p)}
                onPrintBlocked={() => flash("Allow pop-ups to print")}
              />
            ))}
          </section>
        )}

        {patients.length > 0 && (
          <p className="mt-6 text-[11px] leading-relaxed text-gray-400">
            Live from dental-os, refreshed every 30 seconds. Appointment times
            are illustrative — there is no schedule in dental-os yet.
            {isDemo &&
              " In demo mode a check-in is not saved: the API refuses writes without a sign-in."}
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
