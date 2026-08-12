import { useDemoModal } from "../../hooks/useDemoModal";
import { Container } from "./primitives";

/**
 * Closing call to action.
 *
 * The form moved into DemoModal — every "Request a demo" on the page
 * now opens the same modal, so there is one form to maintain and one
 * place a lead can be lost. The section keeps its `id="demo-cta"`
 * because older anchors and the deploy notes point at it.
 */
export default function CTASection() {
  const modal = useDemoModal();

  return (
    <section
      id="demo-cta"
      className="bg-accord-green-900 py-16 text-white sm:py-20"
    >
      <Container>
        <div className="mx-auto max-w-xl text-center">
          <h2 className="text-[26px] font-semibold leading-[1.2] tracking-[-0.02em] sm:text-[30px]">
            See Accord on your own pre-Ds
          </h2>
          <p className="mt-3 text-[15px] text-white/70">
            Your practice. Real product. Your team.
          </p>
          <button
            type="button"
            onClick={modal.open}
            className="mt-7 inline-flex items-center justify-center rounded-lg bg-white px-6 py-3 text-sm font-semibold text-accord-green-900 transition hover:bg-accord-green-50"
          >
            Request a demo
          </button>
        </div>
      </Container>
    </section>
  );
}
