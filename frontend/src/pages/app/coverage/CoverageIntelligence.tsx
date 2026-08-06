import Placeholder from "../../../components/Placeholder";

export default function CoverageIntelligence() {
  return (
    <Placeholder
      title="Coverage intelligence"
      description="The phone call to Delta Dental, answered from the catalogue. Per CDT code: UCR fee, in-network discount, contracted rate, deductible, plan pays, patient owes."
      endpoint="GET /decisions/{id}/patient-summary"
      audience="Front desk, dentist, patient"
    />
  );
}
