/**
 * G-10 — signal override audit.
 *
 * STATIC. provider_feedback is written by every [Mark resolved] and
 * FeedbackBar click in this app, but nothing READS it back — there is
 * no GET endpoint for the table. These rows are illustrative and
 * labelled as such; wiring them means adding
 * GET /decisions/{id}/feedback (or a tenant-wide feed) to dental-os.
 *
 * The compliance line under the heading is true regardless: every
 * override IS persisted, with a 365-day retention default and a role
 * rather than a named individual, per the reflection block in
 * decisions.yaml.
 */
const EVENTS = [
  {
    signal: "COVERAGE_BUNDLING_CONFLICT",
    action: "Accepted",
    role: "billing",
    when: "2h ago",
    note: "—",
  },
  {
    signal: "DOC_NARRATIVE_MISSING",
    action: "Overridden",
    role: "billing",
    when: "3h ago",
    note: "Narrative added to chart",
  },
  {
    signal: "CLINICAL_CRITERIA_MET",
    action: "Accepted",
    role: "dentist",
    when: "1d ago",
    note: "—",
  },
  {
    signal: "ELIG_FREQUENCY_UNVERIFIED",
    action: "False positive",
    role: "front_desk",
    when: "1d ago",
    note: "Prior date confirmed by phone",
  },
  {
    signal: "COVERAGE_DOWNGRADE_APPLIED",
    action: "Accepted",
    role: "billing",
    when: "2d ago",
    note: "Patient informed",
  },
];

const TONE: Record<string, string> = {
  Accepted: "bg-accord-green-50 text-accord-green-900",
  Overridden: "bg-accord-amber-50 text-accord-amber-900",
  "False positive": "bg-red-50 text-red-700",
};

export default function FeedbackAudit() {
  return (
    <section className="overflow-hidden rounded-xl border border-gray-200 bg-white">
      <header className="flex items-center justify-between gap-3 border-b border-gray-200 bg-gray-50 px-4 py-3">
        <div>
          <h2 className="text-[13.5px] font-semibold text-gray-900">
            Signal override audit
          </h2>
          <p className="mt-0.5 text-[11.5px] text-gray-500">
            All overrides are logged for compliance — by role, never by named
            individual.
          </p>
        </div>
        <span className="flex-shrink-0 text-[11px] text-gray-400">sample</span>
      </header>

      <div className="overflow-x-auto">
        <table className="w-full min-w-[560px] text-left text-[12px]">
          <thead className="border-b border-gray-100">
            <tr className="text-[10.5px] uppercase tracking-wide text-gray-500">
              <th className="px-4 py-2 font-medium">Signal</th>
              <th className="px-4 py-2 font-medium">Action</th>
              <th className="px-4 py-2 font-medium">Role</th>
              <th className="px-4 py-2 font-medium">When</th>
              <th className="px-4 py-2 font-medium">Note</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-50">
            {EVENTS.map((e) => (
              <tr key={`${e.signal}-${e.when}`}>
                <td className="px-4 py-2 font-mono text-[11px] text-gray-700">
                  {e.signal}
                </td>
                <td className="px-4 py-2">
                  <span
                    className={`rounded px-1.5 py-0.5 text-[10.5px] font-medium ${TONE[e.action]}`}
                  >
                    {e.action}
                  </span>
                </td>
                <td className="px-4 py-2 capitalize text-gray-600">
                  {e.role.replace(/_/g, " ")}
                </td>
                <td className="px-4 py-2 text-gray-500">{e.when}</td>
                <td className="px-4 py-2 text-gray-500">{e.note}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <p className="border-t border-gray-100 px-4 py-2.5 text-[11px] text-gray-400">
        Feedback written by this app persists to{" "}
        <code className="font-mono">provider_feedback</code>. Nothing reads it
        back yet — a GET endpoint would make this table live.
      </p>
    </section>
  );
}
