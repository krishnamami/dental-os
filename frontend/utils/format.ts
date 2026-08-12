/**
 * Formatting used on patient-facing pages, so the rules are stricter
 * than they look.
 */

/** Dollars, always two decimals. A cost estimate handed to a patient
 *  that reads "$1,825" when the answer is $1,825.00 invites the
 *  question "and the cents?" — which is the trust this product sells. */
export function formatCurrency(value: number | null | undefined): string {
  if (value === null || value === undefined || Number.isNaN(value)) return "—";
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(value);
}

/** Whole dollars, for headline figures where cents are noise. */
export function formatCurrencyShort(value: number | null | undefined): string {
  if (value === null || value === undefined || Number.isNaN(value)) return "—";
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: 0,
  }).format(value);
}

/** 0.325 -> "32.5%". Takes a RATIO, not a percentage — the API returns
 *  approval_rate as 0..1 and coverage_pct as 0..100, and mixing them up
 *  is the easiest way to publish a 3250% approval rate. */
export function formatPercent(ratio: number | null | undefined, digits = 1): string {
  if (ratio === null || ratio === undefined || Number.isNaN(ratio)) return "—";
  return `${(ratio * 100).toFixed(digits)}%`;
}

/**
 * ISO date -> "6 Aug 2026". Date-only strings are parsed as UTC by
 * JavaScript but rendered in local time, which shows the previous day
 * for anyone west of Greenwich. Appending T12:00 keeps a plain date on
 * the day it says.
 */
export function formatDate(value: string | null | undefined): string {
  if (!value) return "—";
  const iso = /^\d{4}-\d{2}-\d{2}$/.test(value) ? `${value}T12:00:00` : value;
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat("en-GB", {
    day: "numeric",
    month: "short",
    year: "numeric",
  }).format(date);
}

/** PRED-SIM-DA-A01 -> DA-A01. The scenario id is what S3 keys and
 *  screens use; the PRED-SIM- prefix is plumbing. */
export function scenarioId(predRequestId: string): string {
  return predRequestId.replace(/^PRED-SIM-/, "");
}

/** ELIG_IMPLANTS_NOT_COVERED -> "Elig implants not covered". */
export function humaniseSignal(code: string): string {
  const lower = code.toLowerCase().replace(/_/g, " ");
  return lower.charAt(0).toUpperCase() + lower.slice(1);
}

/**
 * "Good morning, Dr. Chinta" from "Dr. Sridhar Chinta".
 *
 * ⚠ THE TITLE IS READ, NOT ASSUMED. The engine view is Kim's screen as
 * much as the dentist's, and an earlier cut of this hardcoded "Dr."
 * for everyone — which greeted "Kim B." as "Good morning, Dr. B."
 * Someone with a title gets title + surname, because that is how a
 * dentist is addressed; everyone else gets their first name.
 *
 * Shared by both workbench views so the two cannot greet the same
 * person differently.
 */
export function greetingFor(name: string | null | undefined): string {
  const raw = (name ?? "").trim();
  if (!raw) return "Good morning";
  const title = raw.match(/^(Dr|Mr|Mrs|Ms)\.?\s+/i)?.[1];
  const parts = raw.replace(/^(Dr|Mr|Mrs|Ms)\.?\s+/i, "").split(/\s+/).filter(Boolean);
  if (!parts.length) return "Good morning";
  if (title) {
    return `Good morning, ${title}. ${parts[parts.length - 1]}`;
  }
  // "Kim B." -> "Kim". A trailing initial is not a name to greet by.
  return `Good morning, ${parts[0].replace(/\.$/, "")}`;
}
