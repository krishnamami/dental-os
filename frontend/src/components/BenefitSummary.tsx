import { useState } from "react";
import { Copy, Printer } from "lucide-react";

import type { PatientSummary } from "../types/dental";
import { formatCurrency, formatDate } from "../utils/format";

/**
 * E-06 — the one page a patient takes home.
 *
 * The print view deliberately DROPS the UCR fee and the in-network
 * discount columns. A patient does not need to reconcile four numbers
 * per code; they need to know what they owe. Those columns stay on the
 * screen version for the front desk, who do need them to answer "why
 * is the bill different from the estimate".
 *
 * Printing is CSS, not a PDF library: `.print-only` is hidden on screen
 * and everything else is hidden on paper, so window.print() emits just
 * this sheet without the sidebar or nav. That keeps the dependency
 * count at zero and the output identical to what the browser shows in
 * its own preview.
 */

const PRACTICE = {
  name: "Suwanee Smiles Dental",
  address: "3155 Peachtree Pkwy Ste 120, Suwanee GA 30024",
  phone: "470-291-4593",
  site: "suwanee-smiles.accorddental.io",
};

function summaryText(s: PatientSummary): string {
  const lines = [
    `${PRACTICE.name} — treatment cost estimate`,
    `${PRACTICE.address}`,
    "",
    `Patient: ${s.patient_name}`,
    `Plan: ${s.plan_name}`,
    `Date: ${formatDate(new Date().toISOString())}`,
    "",
    ...s.procedures.map(
      (p) =>
        `${p.cdt_code}  ${p.description ?? ""}${
          p.tooth_number ? ` (tooth #${p.tooth_number})` : ""
        } — you pay ${formatCurrency(p.patient_pays)}`,
    ),
    "",
    `Total treatment: ${formatCurrency(s.summary.total_provider_charges)}`,
    `Your insurance pays: ${formatCurrency(s.summary.total_insurance_pays)}`,
    `YOUR ESTIMATED COST: ${formatCurrency(s.summary.total_patient_pays)}`,
    "",
    "This is an estimate. Final amounts may vary.",
    `Your in-network savings (${formatCurrency(
      s.summary.total_in_network_savings,
    )}) are not your responsibility.`,
    `This estimate is based on your current ${s.plan_name} benefits.`,
    "",
    `Questions? Call ${PRACTICE.phone} or visit ${PRACTICE.site}`,
  ];
  return lines.join("\n");
}

export default function BenefitSummary({
  patient,
  practiceName = PRACTICE.name,
}: {
  patient: PatientSummary;
  practiceName?: string;
}) {
  const [copied, setCopied] = useState(false);

  async function copy() {
    const text = summaryText(patient);
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      setTimeout(() => setCopied(false), 3000);
    } catch {
      // Clipboard needs a secure context and permission. Falling back
      // to a prompt beats a button that silently does nothing.
      window.prompt("Copy the summary below:", text);
    }
  }

  const s = patient.summary;

  return (
    <>
      <div className="flex flex-wrap items-center gap-2 print:hidden">
        <button
          type="button"
          onClick={() => window.print()}
          className="inline-flex items-center gap-1.5 rounded-lg bg-accord-green-900 px-3.5 py-2 text-[12.5px] font-semibold text-white transition hover:bg-accord-green-700"
        >
          <Printer size={14} />
          Print summary
        </button>
        <button
          type="button"
          onClick={copy}
          className="inline-flex items-center gap-1.5 rounded-lg border border-gray-300 px-3.5 py-2 text-[12.5px] font-medium text-gray-700 transition hover:bg-gray-50"
        >
          <Copy size={14} />
          Email to patient
        </button>
        {copied && (
          <span className="text-[12px] font-medium text-accord-green-700">
            Summary copied — paste into email
          </span>
        )}
      </div>

      {/* Hidden on screen, the only thing on paper. */}
      <div className="print-only hidden text-[12px] text-black">
        <header className="border-b border-black pb-2">
          <h1 className="text-[17px] font-bold">{practiceName}</h1>
          <p>{PRACTICE.address}</p>
          <p>{formatDate(new Date().toISOString())}</p>
        </header>

        <section className="mt-3">
          <p>
            <strong>Patient:</strong> {patient.patient_name}
          </p>
          <p>
            <strong>Plan:</strong> {patient.plan_name}
          </p>
          <p>
            <strong>Provider:</strong> {patient.provider_name}
          </p>
        </section>

        <table className="mt-4 w-full border-collapse text-left">
          <thead>
            <tr className="border-b border-black">
              <th className="py-1 pr-2">Procedure</th>
              <th className="py-1 pr-2">Description</th>
              <th className="py-1 text-right">You pay</th>
            </tr>
          </thead>
          <tbody>
            {patient.procedures.map((p) => (
              <tr
                key={`${p.cdt_code}-${p.tooth_number ?? "x"}`}
                className="border-b border-gray-300"
              >
                <td className="py-1 pr-2 font-mono">{p.cdt_code}</td>
                <td className="py-1 pr-2">
                  {p.description ?? "—"}
                  {p.tooth_number ? ` (tooth #${p.tooth_number})` : ""}
                </td>
                <td className="py-1 text-right">
                  {formatCurrency(p.patient_pays)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        <section className="mt-4 border border-black p-3">
          <p>
            Total treatment: {formatCurrency(s.total_provider_charges)}
          </p>
          <p>Your insurance pays: {formatCurrency(s.total_insurance_pays)}</p>
          <p className="mt-1 text-[16px] font-bold">
            YOUR ESTIMATED COST: {formatCurrency(s.total_patient_pays)}
          </p>
        </section>

        <ul className="mt-3 list-disc pl-5">
          <li>This is an estimate. Final amounts may vary.</li>
          <li>
            Your in-network savings ({formatCurrency(s.total_in_network_savings)}
            ) are not your responsibility.
          </li>
          <li>
            This estimate is based on your current {patient.plan_name} benefits.
          </li>
          {/* RULE 11 — a patient-facing number with a silent gap behind
              it is the failure this product exists to prevent. */}
          {patient.caveats.map((c) => (
            <li key={c}>{c}</li>
          ))}
        </ul>

        <footer className="mt-4 border-t border-black pt-2">
          <p>Questions? Call us at {PRACTICE.phone}</p>
          <p>or visit {PRACTICE.site}</p>
        </footer>
      </div>
    </>
  );
}
