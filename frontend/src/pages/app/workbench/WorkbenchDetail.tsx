import Placeholder from "../../../components/Placeholder";

export default function WorkbenchDetail() {
  return (
    <Placeholder
      title="Workbench — one pre-D"
      description="All nine persona outputs across five waves for a single pre-D: what each found, the citation behind it, and the one action that clears it."
      endpoint="GET /decisions/{id}"
      audience="Front desk, billing, dentist"
    />
  );
}
