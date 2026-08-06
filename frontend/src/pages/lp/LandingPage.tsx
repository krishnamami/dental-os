/**
 * accorddental.io — the public landing page.
 *
 * Section order is the argument the page makes: what it does (Hero),
 * who it works with (PayerStrip), what it looks like (DemoSection),
 * why it matters (ValueProps), how it works (Steps), proof against the
 * live API (WhatIf), what you can buy (Products, Pricing), and the ask
 * (CTASection).
 *
 * Two sections talk to dental-os: WorkbenchCard inside Hero, and
 * WhatIf. Both fall back to values captured from real responses if the
 * API is unreachable — a visitor never sees an error, and never sees a
 * number the product cannot reproduce.
 */
import CTASection from "../../components/lp/CTASection";
import DemoSection from "../../components/lp/DemoSection";
import FAQ from "../../components/lp/FAQ";
import Footer from "../../components/lp/Footer";
import Hero from "../../components/lp/Hero";
import MetricsBanner from "../../components/lp/MetricsBanner";
import Nav from "../../components/lp/Nav";
import PayerStrip from "../../components/lp/PayerStrip";
import Pricing from "../../components/lp/Pricing";
import Products from "../../components/lp/Products";
import Steps from "../../components/lp/Steps";
import ValueProps from "../../components/lp/ValueProps";
import WhatIf from "../../components/lp/WhatIf";

export default function LandingPage() {
  return (
    <div className="min-h-screen scroll-smooth bg-white text-gray-900">
      <Nav />
      <main>
        <Hero />
        <PayerStrip />
        <DemoSection />
        <ValueProps />
        <Steps />
        <WhatIf />
        <Products />
        <MetricsBanner />
        <Pricing />
        <FAQ />
        <CTASection />
      </main>
      <Footer />
    </div>
  );
}
