/**
 * D-11 — the workbench as a dentist sees it.
 *
 * PLACEHOLDER. The backend it will read is already deployed —
 * GET /decisions/:id/clinical returns four buckets, a status roll-up
 * and a generated narrative draft, and /decisions/queue?needs_clinician
 * filters the morning to the cases that actually want a clinician. None
 * of it is wired up here yet, on purpose: this prompt was the route
 * split, so that Kim's view could be verified untouched before anything
 * is built on top of it.
 *
 * Deliberately NOT a copy of the engine view with things hidden. A
 * dentist is not a biller with fewer buttons — the questions are
 * different (is this clinically supported, what am I attesting to)
 * and so the screen will be.
 */
import { useAuth } from "../../../context/AuthContext";

const GREEN = "#0F4D37";

export default function WorkbenchClinicalView() {
  const { effectiveUser } = useAuth();
  const first =
    (effectiveUser?.name ?? "")
      .replace(/^(Dr|Mr|Mrs|Ms)\.?\s+/i, "")
      .split(/\s+/)[0] ?? "";

  return (
    <div className="mx-auto max-w-3xl px-6 py-8">
      <div className="flex flex-wrap items-center gap-2">
        <h1 className="text-[22px] font-semibold text-gray-900">
          Clinical workbench
        </h1>
        <span
          className="rounded-full px-2.5 py-0.5 text-[11px] font-semibold text-white"
          style={{ backgroundColor: GREEN }}
        >
          COMING SOON
        </span>
      </div>
      <p className="mt-1 text-[13px] text-slate-500">
        {effectiveUser?.name}
        {effectiveUser?.tenant_name ? ` · ${effectiveUser.tenant_name}` : ""}
      </p>

      <section className="mt-6 rounded-xl border border-gray-200 bg-white p-6">
        <p className="text-[14px] text-gray-800">
          {first ? `${first}, this` : "This"} is where your morning&rsquo;s
          cases will live — the ones that need a clinician, not the ones
          waiting on billing.
        </p>
        <p className="mt-3 text-[13px] leading-relaxed text-gray-600">
          The API behind it is already running. What is not built is this
          screen.
        </p>
        <ul className="mt-3 space-y-1.5 text-[12.5px] text-gray-600">
          <li>
            · Clinical support, documentation gaps, payer friction and
            integrity, as four buckets
          </li>
          <li>· A narrative drafted from the radiograph and the chart</li>
          <li>· Justifying a criterion the engine could not confirm</li>
          <li>· Requesting a document from the front desk</li>
          <li>· Attesting before a case is submitted</li>
        </ul>
      </section>

      <p className="mt-4 text-[11.5px] leading-relaxed text-gray-400">
        Revenue operations still opens the full engine view at this URL.
        Nothing about that screen changed when this one was added.
      </p>
    </div>
  );
}
