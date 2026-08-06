import Placeholder from "../../../components/Placeholder";

export default function WorkbenchQueue() {
  return (
    <Placeholder
      title="Workbench — queue"
      description="Every pre-D that needs somebody to do something, hardest first. Signals needing a signature outrank signals needing a task, and the tightest SLA wins within each."
      endpoint="GET /decisions/{id}/conditions"
      audience="Front desk, billing"
    />
  );
}
