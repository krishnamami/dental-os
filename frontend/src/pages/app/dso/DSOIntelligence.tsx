import Placeholder from "../../../components/Placeholder";

export default function DSOIntelligence() {
  return (
    <Placeholder
      title="DSO intelligence"
      description="Every practice in the group side by side: approval rate, average criteria score, patient responsibility and the denial patterns they share. Aggregates only — no patient ever appears here."
      endpoint="GET /portfolio/summary"
      audience="DSO owner"
    />
  );
}
