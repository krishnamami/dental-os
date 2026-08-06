import Placeholder from "../../../components/Placeholder";

export default function ClinicalEvidence() {
  return (
    <Placeholder
      title="Clinical evidence"
      description="What documents are on file, what each one established, and what is missing. Extraction confidence is shown because a value read at 0.65 is not the same as one read at 0.95."
      endpoint="GET /decisions/{id} (documentation_reviewer signals)"
      audience="Dentist, front desk"
    />
  );
}
