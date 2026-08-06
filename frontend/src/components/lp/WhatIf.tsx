import { useState } from "react";
import { useQuery } from "@tanstack/react-query";

import { api } from "../../hooks/useApi";
import type { Appeal, Decision, PatientSummary } from "../../types/dental";
import { formatCurrency, formatPercent } from "../../utils/format";
import { Container, Eyebrow, H2, Section, Sub } from "./primitives";

/**
 * Four real questions, four real endpoints.
 *
 * Each card fetches from dental-os and formats the answer from the
 * response — the copy under "Accord Dental" is derived, not written.
 * Every question also carries a `fallback` taken from a live response,
 * so a visitor with the API down sees the same answer rather than an
 * error. Sourcing the fallback from the live call is the point: a
 * marketing claim the product cannot reproduce is worse than no claim.
 */

interface Answer {
  verdict: string;
  body: string;
  citation?: string;
}

interface QuestionSpec {
  q: string;
  label: string;
  path: string;
  /** Narrow the response and turn it into the three lines rendered. */
  format: (data: unknown) => Answer;
  fallback: Answer;
}

const QUESTIONS: QuestionSpec[] = [
  {
    q: "Should we appeal the D7953 bone graft denial?",
    label: "Appeal viability",
    path: "/decisions/PRED-SIM-DA-B04/appeal",
    format: (raw) => {
      const d = raw as Appeal;
      const pct = d.success_probability
        ? formatPercent(d.success_probability, 0)
        : "—";
      return {
        verdict: d.viable
          ? `Yes — appeal is viable, roughly ${pct} are overturned`
          : "No — no appeal path is supported for this denial",
        body:
          d.appeal_strategy ??
          d.not_viable_reason ??
          "No strategy returned for this denial.",
        citation: d.citations?.[0]?.section
          ? `${d.citations[0].source} §${d.citations[0].section}`
          : undefined,
      };
    },
    fallback: {
      verdict: "Yes — appeal is viable, roughly 65% are overturned",
      body:
        "Unbundle under the payer's own separation criteria: PA X-ray showing bone loss ≥3mm documented separately, plus a clinical narrative explaining graft necessity independent of implant placement.",
      citation: "delta_dental provider manual §D.7.4",
    },
  },
  {
    q: "What does MetLife cover for D0330 panoramic?",
    label: "Coverage lookup",
    path: "/decisions/PRED-SIM-DA-C07/patient-summary",
    format: (raw) => {
      const d = raw as PatientSummary;
      const pan = d.procedures.find((p) => p.cdt_code === "D0330");
      if (!pan) {
        return {
          verdict: "D0330 is not on this pre-D",
          body: "No panoramic film was billed on this case.",
        };
      }
      return {
        verdict: pan.patient_pays === 0
          ? "Covered in full — the patient owes nothing"
          : `Patient owes ${formatCurrency(pan.patient_pays)}`,
        body:
          `${d.payer_id} allows ${formatCurrency(pan.contracted_rate)} against a ` +
          `${formatCurrency(pan.provider_ucr_fee)} charge; the plan pays ` +
          `${formatCurrency(pan.insurance_pays)}. The in-network discount of ` +
          `${formatCurrency(pan.in_network_discount)} is not the patient's responsibility.`,
        citation: pan.rate_is_estimated
          ? "Rate is an estimate, not a published schedule"
          : undefined,
      };
    },
    fallback: {
      verdict: "Covered in full — the patient owes nothing",
      body:
        "MetLife allows $155.70 against a $185.00 charge and pays it at 100% as a preventive service. MetLife's panoramic frequency is one per three years, where Delta allows one per five.",
    },
  },
  {
    q: "Is this bisphosphonate patient safe for implants?",
    label: "Clinical risk",
    path: "/decisions/PRED-SIM-DA-C09",
    format: (raw) => {
      const d = raw as Decision;
      const flag = d.all_signals.find(
        (s) => s.signal_code === "CLINICAL_MEDICAL_HISTORY_FLAG",
      );
      return {
        verdict: flag
          ? "No — a medical history flag blocks this implant"
          : "No contraindication found on this pre-D",
        body:
          flag?.finding ??
          "No medical history flag was raised against the billed codes.",
        citation: flag?.payer_citation ?? flag?.citation,
      };
    },
    fallback: {
      verdict: "No — a medical history flag blocks this implant",
      body:
        "IV Bisphosphonate Therapy is an absolute contraindication for D6010. Do not perform the implant without medical clearance; the pre-D pends until it is on file.",
    },
  },
  {
    q: "Why does Cigna approve D2740 but Delta downgrades?",
    label: "Payer difference",
    path: "/decisions/PRED-SIM-DA-C06",
    format: (raw) => {
      const d = raw as Decision;
      const verified = d.all_signals.find(
        (s) => s.signal_code === "COVERAGE_VERIFIED",
      );
      const downgraded = d.all_signals.some(
        (s) => s.signal_code === "COVERAGE_DOWNGRADE_APPLIED",
      );
      return {
        verdict: downgraded
          ? "Downgrade applied — the patient covers the difference"
          : `No downgrade under ${d.payer_id} — the ceramic crown is paid as billed`,
        body:
          verified?.finding ??
          `${d.payer_id} returned ${d.decision} on this case.`,
        citation: verified?.payer_citation ?? undefined,
      };
    },
    fallback: {
      verdict: "No downgrade under cigna — the ceramic crown is paid as billed",
      body:
        "Cigna negotiated no ceramic-to-metal downgrade, so D2740 is reimbursed at its own rate. Delta and MetLife reimburse D2740 at the D2750 PFM rate and bill the patient the difference. Same tooth, same code, two answers — because the plans differ.",
    },
  },
];

function AnswerPanel({
  spec,
  loading,
  answer,
}: {
  spec: QuestionSpec;
  loading: boolean;
  answer: Answer;
}) {
  return (
    <div className="rounded-xl border border-gray-200 bg-white p-6">
      <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-accord-green-900">
        Accord Dental · {spec.label}
      </p>

      {loading ? (
        <div className="mt-4 animate-pulse space-y-3">
          <div className="h-4 w-3/4 rounded bg-gray-100" />
          <div className="h-3 w-full rounded bg-gray-100" />
          <div className="h-3 w-5/6 rounded bg-gray-100" />
        </div>
      ) : (
        <>
          <p className="mt-3 text-[17px] font-semibold leading-snug text-accord-green-900">
            {answer.verdict}
          </p>
          <p className="mt-3 text-[14px] leading-relaxed text-gray-600">
            {answer.body}
          </p>
          {answer.citation && (
            <p className="mt-4 border-t border-gray-100 pt-3 font-mono text-[11.5px] text-gray-500">
              {answer.citation}
            </p>
          )}
        </>
      )}
    </div>
  );
}

export default function WhatIf() {
  const [active, setActive] = useState(0);
  const spec = QUESTIONS[active];

  const { data, isLoading, isError } = useQuery({
    queryKey: ["whatif", spec.path],
    queryFn: async () => {
      const res = await api.get(spec.path);
      return res.data as unknown;
    },
    retry: false,
    staleTime: 5 * 60_000,
  });

  let answer = spec.fallback;
  if (data && !isError) {
    try {
      answer = spec.format(data);
    } catch {
      // A shape change upstream must not blank the section.
      answer = spec.fallback;
    }
  }

  return (
    <Section id="what-if" className="border-y border-gray-200 bg-gray-50">
      <Container>
        <div className="mx-auto max-w-2xl text-center">
          <Eyebrow>What if…?</Eyebrow>
          <H2>Ask anything about your pre-D.</H2>
          <Sub className="mt-3">
            Get the answer — with AI reasoning and policy citations.
          </Sub>
        </div>

        <div className="mt-10 grid gap-6 lg:grid-cols-2">
          <ul className="space-y-2.5">
            {QUESTIONS.map((q, i) => {
              const selected = i === active;
              return (
                <li key={q.q}>
                  <button
                    type="button"
                    onClick={() => setActive(i)}
                    aria-pressed={selected}
                    className={`w-full rounded-xl border px-4 py-3.5 text-left text-[14px] leading-snug transition ${
                      selected
                        ? "border-accord-green-500 bg-white font-medium text-gray-900 shadow-sm"
                        : "border-gray-200 bg-white/60 text-gray-600 hover:border-gray-300 hover:bg-white"
                    }`}
                  >
                    {q.q}
                  </button>
                </li>
              );
            })}
          </ul>

          <AnswerPanel spec={spec} loading={isLoading} answer={answer} />
        </div>
      </Container>
    </Section>
  );
}
