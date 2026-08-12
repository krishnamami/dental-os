import { Link, useLocation, useNavigate, useParams } from "react-router-dom";
import { ArrowLeft } from "lucide-react";

import BillingDetail from "../../../components/BillingDetail";
import PreDDetail from "../../../components/PreDDetail";
import Toast, { useToast } from "../../../components/Toast";
import { useDemo, useDemoLink } from "../../../hooks/useDemo";

/**
 * D-03 — one pre-D at /workbench/:id.
 *
 * WHICH VIEW depends on where the user came from, not on their role.
 * A biller who arrives from Revenue ops gets the billing view; the same
 * biller opening the workbench directly gets the clinical one, because
 * they asked for the workbench. Role would be the wrong key: Kim
 * legitimately reads the clinical view when she is checking a
 * dentist's narrative, and keying off `from` lets the same person have
 * both without a preference toggle.
 *
 * `from` arrives in location.state, so it survives a back-forward but
 * not a fresh load of the URL — which is right. A pasted link has no
 * origin to return to, and the view falls back to clinical.
 */
interface FromState {
  from?: string;
  fromLabel?: string;
  /** The queue row's created_at, so the payer window is dated from
   *  when the case actually entered the queue. */
  createdAt?: string | null;
}

export default function WorkbenchDetail() {
  const { id } = useParams<{ id: string }>();
  const { demoPredId, isDemo } = useDemo();
  const demoLink = useDemoLink();
  const navigate = useNavigate();
  const location = useLocation();
  const { toast, flash } = useToast();

  const state = (location.state ?? {}) as FromState;
  const from = state.from;
  const fromLabel = state.fromLabel;

  // The route param wins; demo mode only supplies a default for a bare
  // /workbench/ visit.
  const predRequestId = id ?? (isDemo ? demoPredId : undefined);

  if (!predRequestId) {
    return (
      <div className="p-6 text-[13.5px] text-gray-500">
        No pre-D selected.{" "}
        <Link
          to={demoLink("/workbench")}
          className="text-accord-green-900 underline"
        >
          Back to the queue
        </Link>
      </div>
    );
  }

  if (from === "/revenue-ops") {
    return (
      <>
        <BillingDetail
          predRequestId={predRequestId}
          onBack={() => navigate(demoLink(from))}
          backLabel={fromLabel ?? "Back"}
          createdAt={state.createdAt}
          onToast={flash}
        />
        <Toast message={toast} />
      </>
    );
  }

  return (
    <PreDDetail
      predRequestId={predRequestId}
      back={
        from ? { label: fromLabel ?? "Back", onClick: () => navigate(demoLink(from)) } : undefined
      }
      backLink={
        <Link
          to={demoLink("/workbench")}
          className="mb-3 inline-flex items-center gap-1.5 text-[12.5px] font-medium text-gray-500 hover:text-gray-900"
        >
          <ArrowLeft size={14} />
          Back to queue
        </Link>
      }
    />
  );
}
