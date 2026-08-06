import Placeholder from "../../../components/Placeholder";

export default function RevenueOps() {
  return (
    <Placeholder
      title="Revenue operations"
      description="Denials, appeals and money left on the table for one practice. Which denials are appealable, what each appeal is worth, and how long is left to file."
      endpoint="GET /decisions/{id}/appeal"
      audience="Revenue operations, billing"
    />
  );
}
