import { Link, useParams } from "react-router-dom";
import { ArrowLeft } from "lucide-react";

import PreDDetail from "../../../components/PreDDetail";
import { useDemo, useDemoLink } from "../../../hooks/useDemo";

/**
 * D-03 — one pre-D at /workbench/:id, reached from the queue or from
 * Coverage's "View full pre-D".
 *
 * The body is PreDDetail, the same component the pipeline's right half
 * renders. This file is only the route: which pre-D, and a way back.
 */
export default function WorkbenchDetail() {
  const { id } = useParams<{ id: string }>();
  const { demoPredId, isDemo } = useDemo();
  const demoLink = useDemoLink();

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

  return (
    <PreDDetail
      predRequestId={predRequestId}
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
