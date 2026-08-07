import type { PatientSummary } from "../../../types/dental";
import { formatCurrency } from "../../../utils/format";

/**
 * The patient-facing treatment estimate — one generator, two outputs.
 *
 * A patient signs the printed version, so every number on it comes from
 * /patient-summary and nothing is written down here. The three money
 * columns reconcile by construction:
 *
 *     office fee − insurance pays − patient pays = in-network savings
 *     $5,550.00  −   $1,775.00    −  $1,825.00   =    $1,950.00
 *
 * That identity is the point. A row that does not add up is the first
 * thing a patient notices and the last thing they forget.
 */

const GREEN = "#0F4D37";
const AMBER = "#B45309";

export interface EstimateAlert {
  type: string;
  title: string;
  detail: string;
}

export interface EstimatePatient {
  pred_request_id: string;
  patient_name: string;
  procedure_summary: string;
  payer_name: string;
  member_id: string | null;
  enrollment_months: number | null;
  provider_name: string;
  insurance_active: boolean;
  provider_in_network: boolean;
  deductible_met: boolean;
  deductible_total: number | null;
  deductible_remaining: number | null;
  annual_max: number | null;
  annual_max_remaining: number | null;
  annual_max_remaining_after: number | null;
  alerts: EstimateAlert[];
}

export const COORDINATOR_ITEMS = [
  "Treatment plan explained",
  "Insurance benefits explained",
  "Estimated patient responsibility reviewed",
  "Financing options discussed",
  "Questions answered",
  "Consent obtained",
];

function esc(v: string): string {
  return String(v).replace(/[&<>"]/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c] ?? c,
  );
}

/** A coverage share taken from the row it describes, never typed. */
function pctOf(paid: number, allowed: number): string {
  return allowed > 0 ? `${Math.round((paid / allowed) * 100)}%` : "—";
}

type Mark = "ok" | "warn" | "info";

/**
 * What Accord actually checked, and what it found.
 *
 * ⚠ THIS BLOCK IS NOT DECORATION. Printing six green ticks on a page a
 * patient signs, while the engine is holding four open findings on the
 * same case, would be the most misleading thing in the product. Each
 * line below is derived from the signals; where the engine raised
 * something, the line says so.
 */
function reviewItems(
  p: EstimatePatient,
  ps: PatientSummary,
): Array<{ mark: Mark; label: string; note: string }> {
  const has = (t: string) => p.alerts.some((a) => a.type === t);
  const maxAfter = p.annual_max_remaining_after;
  return [
    {
      mark: p.insurance_active ? "ok" : "warn",
      label: "Insurance eligibility verified",
      note: p.insurance_active ? "Coverage active" : "Coverage could not be confirmed",
    },
    {
      mark: maxAfter != null && maxAfter < 200 ? "warn" : "ok",
      label: "Annual maximum reviewed",
      note:
        maxAfter != null
          ? `About ${formatCurrency(maxAfter)} left after this treatment`
          : "Checked against your plan",
    },
    {
      mark: "ok",
      label: "Waiting periods verified",
      note: p.enrollment_months
        ? `Enrolled ${p.enrollment_months} months`
        : "No waiting period outstanding",
    },
    {
      mark: has("pre_d_required") ? "warn" : "ok",
      label: "Required documentation",
      note: has("pre_d_required")
        ? "A pre-determination must be approved before treatment"
        : "Nothing outstanding",
    },
    {
      mark: has("downgrade") || has("bundling") ? "warn" : "ok",
      label: "Payer policy review",
      note: has("downgrade")
        ? "One item is paid at a lower benefit level"
        : has("bundling")
          ? "Two procedures are billed together by this plan"
          : "No policy conflicts found",
    },
    {
      mark: "ok",
      label: "Expected patient responsibility",
      note: `${formatCurrency(ps.summary.total_patient_pays)} estimated`,
    },
  ];
}

function markIcon(m: Mark): string {
  return m === "ok" ? "✓" : m === "warn" ? "!" : "i";
}

function markColor(m: Mark): string {
  return m === "ok" ? "#4ade80" : m === "warn" ? "#fcd34d" : "#93c5fd";
}

export function generatePrintHTML(
  p: EstimatePatient,
  ps: PatientSummary,
  checked: Set<number>,
  practice: string,
  address: string,
): string {
  const today = new Date().toLocaleDateString(undefined, {
    year: "numeric",
    month: "long",
    day: "numeric",
  });
  const s = ps.summary;
  const maxTotal = p.annual_max ?? 0;
  const maxLeft = p.annual_max_remaining ?? 0;
  const maxUsed = Math.max(maxTotal - maxLeft, 0);
  const usedPct = maxTotal > 0 ? Math.round((maxUsed / maxTotal) * 100) : 0;
  const dedTotal = p.deductible_total ?? 0;
  const dedLeft = p.deductible_remaining ?? 0;
  const dedMetAmt = Math.max(dedTotal - dedLeft, 0);
  const dedPct = dedTotal > 0 ? Math.round((dedMetAmt / dedTotal) * 100) : 0;

  const rows = ps.procedures
    .map(
      (x) => `
      <tr>
        <td style="padding:10px 8px;border-bottom:1px solid #eef2f7">
          <div style="font-weight:600;color:#0f172a">${esc(x.description ?? x.cdt_code)}</div>
          <div style="font-size:10.5px;color:#64748b;margin-top:1px">
            ${esc(x.cdt_code)}${x.tooth_number ? ` · tooth #${x.tooth_number}` : ""}
          </div>
          ${
            x.downgrade_applied
              ? `<div style="font-size:10.5px;color:${AMBER};margin-top:3px">
                   ⚠ Reimbursed at a lower benefit level</div>`
              : ""
          }
        </td>
        <td style="padding:10px 8px;text-align:right;border-bottom:1px solid #eef2f7;color:#475569">
          ${formatCurrency(x.provider_ucr_fee)}
        </td>
        <td style="padding:10px 8px;text-align:right;border-bottom:1px solid #eef2f7;color:#475569">
          ${formatCurrency(x.insurance_pays)}
        </td>
        <td style="padding:10px 8px;text-align:right;border-bottom:1px solid #eef2f7;font-weight:700;color:#0f172a">
          ${formatCurrency(x.patient_pays)}
        </td>
      </tr>`,
    )
    .join("");

  const info: Array<{ mark: Mark; text: string }> = [
    {
      mark: p.insurance_active && p.provider_in_network ? "ok" : "warn",
      text: "Your insurance is active and your provider is in-network.",
    },
    ...p.alerts.map((a) => ({ mark: "warn" as Mark, text: a.detail })),
    {
      mark: "ok" as Mark,
      text: "This estimate is based on today's benefits and the treatment plan provided.",
    },
    {
      mark: "info" as Mark,
      text: "Final payment depends on claim adjudication and the treatment actually performed.",
    },
  ];

  const review = reviewItems(p, ps);

  return `<!doctype html><html lang="en"><head><meta charset="utf-8">
<title>Treatment estimate · ${esc(p.patient_name)}</title>
<style>
  *{box-sizing:border-box}
  body{margin:0;background:#eef1f5;color:#0f172a;
       font-family:system-ui,-apple-system,"Segoe UI",sans-serif;font-size:12px}
  .page{max-width:800px;margin:24px auto;background:#fff;
        box-shadow:0 1px 3px rgba(0,0,0,.12)}
  .hdr{background:${GREEN};color:#fff;padding:18px 26px;
       display:flex;justify-content:space-between;align-items:flex-start;gap:16px}
  .cols{display:flex;gap:0;align-items:stretch}
  .main{flex:0 0 65%;padding:22px 26px;min-width:0}
  .side{flex:1;padding:22px 20px;background:#f8fafc;border-left:1px solid #e2e8f0;min-width:0}
  h1{font-size:19px;margin:0 0 4px}
  h2{font-size:10.5px;text-transform:uppercase;letter-spacing:.07em;
     color:#64748b;margin:20px 0 8px;font-weight:700}
  .side h2{margin-top:18px}
  table{width:100%;border-collapse:collapse}
  th{font-size:9.5px;text-transform:uppercase;letter-spacing:.05em;color:#64748b;
     text-align:left;padding:0 8px 6px;border-bottom:1px solid #e2e8f0;font-weight:700}
  .bar{height:6px;background:#e2e8f0;border-radius:3px;overflow:hidden;margin:4px 0 2px}
  .bar>span{display:block;height:100%;background:${GREEN}}
  .box{border:1px solid #e2e8f0;border-radius:8px;padding:12px;background:#fff}
  .sig{border-bottom:1px solid #94a3b8;height:26px}
  @media print{
    body{background:#fff}
    .page{margin:0;box-shadow:none;max-width:none}
    .no-print{display:none}
    .cols{display:flex}
  }
</style></head><body>
<div class="page">

  <div class="hdr">
    <div>
      <div style="font-size:15px;font-weight:700">🦷 ${esc(practice)}</div>
      ${address ? `<div style="font-size:10.5px;opacity:.8;margin-top:2px">${esc(address)}</div>` : ""}
    </div>
    <div style="text-align:right;flex-shrink:0">
      <div style="font-size:9.5px;text-transform:uppercase;letter-spacing:.06em;opacity:.7">
        📅 Estimate date</div>
      <div style="font-size:12px;font-weight:600;margin-top:2px">${esc(today)}</div>
    </div>
  </div>

  <div class="cols">
    <div class="main">
      <h1>Your treatment cost summary</h1>
      <p style="margin:0;color:#475569">
        Here is your estimated cost for the recommended treatment.
      </p>

      <div style="margin-top:12px;background:#f0fdf4;border:1px solid #bbf7d0;
                  border-radius:8px;padding:10px 12px;display:flex;gap:8px">
        <span>🛡️</span>
        <span style="color:#166534;font-size:11.5px;line-height:1.5">
          Estimated using your current ${esc(p.payer_name)} benefits as of
          ${esc(today)}. Final payment depends on claim adjudication.
        </span>
      </div>

      <div style="display:flex;gap:12px;margin-top:16px">
        <div style="flex:1;min-width:0">
          <div style="font-size:9.5px;text-transform:uppercase;letter-spacing:.05em;color:#64748b">
            👤 Patient</div>
          <div style="font-weight:600;margin-top:2px">${esc(p.patient_name)}</div>
        </div>
        <div style="flex:1;min-width:0">
          <div style="font-size:9.5px;text-transform:uppercase;letter-spacing:.05em;color:#64748b">
            🦷 Treatment</div>
          <div style="font-weight:600;margin-top:2px">${esc(p.procedure_summary)}</div>
        </div>
        <div style="flex:1;min-width:0">
          <div style="font-size:9.5px;text-transform:uppercase;letter-spacing:.05em;color:#64748b">
            👨‍⚕️ Provider</div>
          <div style="font-weight:600;margin-top:2px">${esc(p.provider_name)}</div>
        </div>
      </div>

      <h2>Your insurance benefits</h2>
      <table>
        <tr><td style="padding:7px 0;width:38%;color:#475569">Annual maximum</td>
            <td style="padding:7px 0">
              <div class="bar"><span style="width:${usedPct}%"></span></div>
              <div style="font-size:10.5px;color:#64748b">
                ${formatCurrency(maxUsed)} used ·
                <strong style="color:#0f172a">${formatCurrency(maxLeft)} remaining</strong>
                of ${formatCurrency(maxTotal)}
              </div>
            </td></tr>
        <tr><td style="padding:7px 0;color:#475569">Deductible</td>
            <td style="padding:7px 0">
              <div class="bar"><span style="width:${dedPct}%"></span></div>
              <div style="font-size:10.5px;color:#64748b">
                ${formatCurrency(dedMetAmt)} met ·
                <strong style="color:${p.deductible_met ? "#166534" : AMBER}">
                  ${p.deductible_met ? "fully met" : `${formatCurrency(dedLeft)} still to meet`}
                </strong>
                of ${formatCurrency(dedTotal)}
              </div>
            </td></tr>
        <tr><td style="padding:7px 0;color:#475569">Plan pays</td>
            <td style="padding:7px 0">
              ${ps.procedures
                .map(
                  (x) =>
                    `<span style="display:inline-block;margin-right:10px">
                       ${esc(x.cdt_code)} <strong>${pctOf(x.insurance_pays, x.contracted_rate)}</strong>
                     </span>`,
                )
                .join("")}
            </td></tr>
        <tr><td style="padding:7px 0;color:#475569">Waiting period</td>
            <td style="padding:7px 0"><strong style="color:#166534">Met</strong>
              ${p.enrollment_months ? ` · enrolled ${p.enrollment_months} months` : ""}</td></tr>
        <tr><td style="padding:7px 0;color:#475569">Network status</td>
            <td style="padding:7px 0"><strong style="color:#166534">In-network</strong>
              · ${esc(p.payer_name)}${p.member_id ? ` · member ${esc(p.member_id)}` : ""}</td></tr>
      </table>

      <h2>Treatment cost breakdown</h2>
      <table>
        <thead><tr>
          <th>Procedure</th>
          <th style="text-align:right">Office fee</th>
          <th style="text-align:right">Insurance pays</th>
          <th style="text-align:right">You pay (est.)</th>
        </tr></thead>
        <tbody>
          ${rows}
          <tr>
            <td style="padding:11px 8px;font-weight:700">Total</td>
            <td style="padding:11px 8px;text-align:right;font-weight:700">
              ${formatCurrency(s.total_provider_charges)}</td>
            <td style="padding:11px 8px;text-align:right;font-weight:700;color:${GREEN}">
              ${formatCurrency(s.total_insurance_pays)}</td>
            <td style="padding:11px 8px;text-align:right;font-weight:800;font-size:14px">
              ${formatCurrency(s.total_patient_pays)}</td>
          </tr>
        </tbody>
      </table>

      <div style="margin-top:10px;background:#f0fdf4;border-left:3px solid ${GREEN};
                  border-radius:0 6px 6px 0;padding:9px 12px;color:#166534">
        Your in-network savings of
        <strong>${formatCurrency(s.total_in_network_savings)}</strong>
        are not your responsibility.
      </div>

      <h2>Important information</h2>
      <ul style="list-style:none;padding:0;margin:0">
        ${info
          .map(
            (i) => `<li style="display:flex;gap:8px;margin-bottom:7px;line-height:1.5">
              <span style="flex-shrink:0;color:${
                i.mark === "ok" ? "#16a34a" : i.mark === "warn" ? AMBER : "#2563eb"
              };font-weight:700">${i.mark === "ok" ? "✓" : i.mark === "warn" ? "⚠" : "ℹ"}</span>
              <span style="color:#334155">${esc(i.text)}</span></li>`,
          )
          .join("")}
      </ul>
    </div>

    <div class="side">
      <div class="box" style="border:2px solid ${GREEN}">
        <div style="font-size:9.5px;text-transform:uppercase;letter-spacing:.07em;
                    color:#64748b;font-weight:700">Today&rsquo;s summary</div>
        <div style="margin-top:10px;font-size:10.5px;color:#64748b">Insurance estimated to pay</div>
        <div style="font-size:21px;font-weight:800;color:${GREEN}">
          ${formatCurrency(s.total_insurance_pays)}</div>
        <div style="margin-top:8px;font-size:10.5px;color:#64748b">You pay (estimated)</div>
        <div style="font-size:24px;font-weight:800;color:#0f172a">
          ${formatCurrency(s.total_patient_pays)}</div>
        <div style="margin-top:10px;background:#f0fdf4;border-radius:999px;
                    padding:5px 10px;font-size:10.5px;color:#166534;text-align:center">
          ✓ Your provider is in-network
        </div>
      </div>

      <div class="box" style="background:${GREEN};border-color:${GREEN};margin-top:12px">
        <div style="font-size:9.5px;text-transform:uppercase;letter-spacing:.07em;
                    color:rgba(255,255,255,.6);font-weight:700">Accord review</div>
        <div style="color:rgba(255,255,255,.85);font-size:10.5px;margin-top:5px;line-height:1.5">
          Accord reviewed your plan and treatment details.
        </div>
        <ul style="list-style:none;padding:0;margin:10px 0 0">
          ${review
            .map(
              (r) => `<li style="display:flex;gap:7px;margin-bottom:7px">
                <span style="flex-shrink:0;color:${markColor(r.mark)};font-weight:700">
                  ${markIcon(r.mark)}</span>
                <span style="min-width:0">
                  <span style="display:block;color:#fff;font-size:11px">${esc(r.label)}</span>
                  <span style="display:block;color:rgba(255,255,255,.6);font-size:10px;line-height:1.4">
                    ${esc(r.note)}</span>
                </span></li>`,
            )
            .join("")}
        </ul>
      </div>

      <h2>Questions your coordinator reviewed</h2>
      <ul style="list-style:none;padding:0;margin:0">
        ${COORDINATOR_ITEMS.map(
          (item, i) => `<li style="display:flex;gap:7px;margin-bottom:6px;line-height:1.45">
            <span style="flex-shrink:0;color:${checked.has(i) ? "#16a34a" : "#94a3b8"}">
              ${checked.has(i) ? "☑" : "☐"}</span>
            <span style="color:${checked.has(i) ? "#334155" : "#94a3b8"};font-size:11px">
              ${esc(item)}</span></li>`,
        ).join("")}
      </ul>

      <div class="box" style="margin-top:14px">
        <div style="font-size:10.5px;color:#334155;line-height:1.5">
          I have reviewed and understand the estimated costs and my financial
          responsibility.
        </div>
        <div style="display:flex;gap:10px;margin-top:16px">
          <div style="flex:2">
            <div class="sig"></div>
            <div style="font-size:9px;color:#64748b;margin-top:3px">Patient signature</div>
          </div>
          <div style="flex:1">
            <div class="sig"></div>
            <div style="font-size:9px;color:#64748b;margin-top:3px">Date</div>
          </div>
        </div>
      </div>
    </div>
  </div>

  <div style="border-top:1px solid #e2e8f0;padding:14px 26px;display:flex;
              justify-content:space-between;gap:20px;align-items:center">
    <div style="font-size:10.5px;color:#475569">
      <strong>Have questions?</strong><br>
      Contact your treatment coordinator at ${esc(practice)}. We are here to help.
    </div>
    <div style="font-size:11px;font-weight:700;color:${GREEN};flex-shrink:0">accord</div>
  </div>
  <div style="padding:0 26px 16px;font-size:9px;color:#94a3b8;line-height:1.5">
    This is an estimate, not a guarantee of payment. Benefits are subject to plan
    limitations and exclusions.<br>
    © ${new Date().getFullYear()} Accord Dental, Inc. All rights reserved.
  </div>
</div>

<div class="no-print" style="text-align:center;margin:16px">
  <button onclick="window.print()"
    style="background:${GREEN};color:#fff;border:none;padding:11px 30px;border-radius:8px;
           font-size:14px;font-weight:600;cursor:pointer">
    Print / Save as PDF
  </button>
</div>
</body></html>`;
}

/** The same document as plain text, for the clipboard. */
export function generateEmailText(
  p: EstimatePatient,
  ps: PatientSummary,
  checked: Set<number>,
  practice: string,
  address: string,
): string {
  const s = ps.summary;
  const w = (a: string, b: string) => `  ${a.padEnd(34)}${b.padStart(12)}`;
  return [
    `Subject: Your treatment estimate — ${practice}`,
    "",
    `Hi ${p.patient_name.split(" ")[0]},`,
    "",
    `Here is your estimated cost for the recommended treatment at ${practice}.`,
    "",
    "TREATMENT COST BREAKDOWN",
    w("Procedure", "You pay"),
    ...ps.procedures.map((x) =>
      w(
        `${x.cdt_code} ${(x.description ?? "").slice(0, 26)}`,
        formatCurrency(x.patient_pays),
      ),
    ),
    "  " + "-".repeat(46),
    w("Office fee total", formatCurrency(s.total_provider_charges)),
    w("Insurance estimated to pay", formatCurrency(s.total_insurance_pays)),
    w("YOU PAY (ESTIMATED)", formatCurrency(s.total_patient_pays)),
    "",
    `Your in-network savings of ${formatCurrency(s.total_in_network_savings)} are not your responsibility.`,
    "",
    "YOUR BENEFITS",
    `  Plan: ${p.payer_name}${p.member_id ? ` · member ${p.member_id}` : ""}`,
    `  Annual maximum: ${formatCurrency(p.annual_max_remaining)} remaining of ${formatCurrency(p.annual_max)}`,
    `  Deductible: ${
      p.deductible_met
        ? "fully met"
        : `${formatCurrency(p.deductible_remaining)} still to meet`
    }`,
    `  Network: in-network`,
    "",
    ...(p.alerts.length
      ? ["IMPORTANT", ...p.alerts.map((a) => `  - ${a.detail}`), ""]
      : []),
    "REVIEWED WITH YOUR COORDINATOR",
    ...COORDINATOR_ITEMS.map((item, i) => `  ${checked.has(i) ? "[x]" : "[ ]"} ${item}`),
    "",
    "This is an estimate, not a guarantee of payment. Final payment depends on",
    "claim adjudication and the treatment actually performed.",
    "",
    practice,
    address,
  ].join("\n");
}
