import { Container } from "./primitives";

const PAYERS = [
  "Delta Dental PPO",
  "Cigna DPPO",
  "MetLife PDP",
  "Aetna DMO",
  "Humana DPO",
  "Guardian",
];

export default function PayerStrip() {
  return (
    <div className="border-y border-gray-200 bg-gray-50 py-7">
      <Container>
        <p className="text-center text-[11px] font-semibold uppercase tracking-[0.14em] text-gray-500">
          Works with all major dental payers
        </p>
        {/* Scrolls rather than wraps on a phone: six pills wrapping to
            three lines reads as a list, not a logo strip. */}
        <div className="mt-4 flex snap-x gap-2 overflow-x-auto pb-1 sm:flex-wrap sm:justify-center sm:overflow-visible sm:pb-0">
          {PAYERS.map((p) => (
            <span
              key={p}
              className="flex-shrink-0 snap-start rounded-full border border-gray-200 bg-white px-3.5 py-1.5 text-[12.5px] font-medium text-gray-600"
            >
              {p}
            </span>
          ))}
        </div>
      </Container>
    </div>
  );
}
