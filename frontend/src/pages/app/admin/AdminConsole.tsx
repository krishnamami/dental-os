import Placeholder from "../../../components/Placeholder";

export default function AdminConsole() {
  return (
    <Placeholder
      title="Admin console"
      description="Catalogue versions, persona wiring and the health of both databases. The page that answers 'which rules decided this, and were they current?'"
      endpoint="GET /health"
      audience="Accord admin only"
    />
  );
}
