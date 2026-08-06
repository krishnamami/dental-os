import { useState } from "react";

import { Container } from "./primitives";

/**
 * Demo request form.
 *
 * The Formspree endpoint is read from VITE_FORMSPREE_ENDPOINT. Create
 * the form at formspree.io against demo@accorddental.io, then:
 *
 *     echo 'VITE_FORMSPREE_ENDPOINT=https://formspree.io/f/xxxxxxxx' >> .env.local
 *
 * WHEN IT IS NOT SET, THIS FORM DOES NOT PRETEND TO WORK. It falls back
 * to a prefilled mailto: and says so. A form that shows "we'll be in
 * touch within 24 hours" while posting nowhere is worse than no form —
 * it loses the one lead it was built to catch, silently, and nobody
 * finds out until someone asks why the demo inbox is empty.
 */
const RAW_ENDPOINT = import.meta.env.VITE_FORMSPREE_ENDPOINT as
  | string
  | undefined;

/**
 * An unreplaced placeholder counts as NOT configured.
 *
 * Without this, shipping `.env.production` with the literal
 * `YOUR_FORM_ID` still reads as "configured": the button would say
 * "Request a demo" and POST to a URL that 404s, so every lead lands in
 * the error branch instead of the inbox. Treating a placeholder as
 * unset keeps the mailto fallback — which always delivers — until a
 * real id is in place.
 */
const ENDPOINT =
  RAW_ENDPOINT && !/YOUR_FORM_ID|xxxxxxxx|^\s*$/i.test(RAW_ENDPOINT)
    ? RAW_ENDPOINT
    : undefined;

const DEMO_EMAIL = "demo@accorddental.io";

const LOCATIONS = ["1", "2-5", "6-20", "20+"];

type Status = "idle" | "sending" | "sent" | "error";

export default function CTASection() {
  const [status, setStatus] = useState<Status>("idle");
  const [form, setForm] = useState({
    name: "",
    practice: "",
    email: "",
    phone: "",
    locations: LOCATIONS[0],
  });

  const set = (key: keyof typeof form) => (
    e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>,
  ) => setForm((f) => ({ ...f, [key]: e.target.value }));

  function mailtoHref() {
    const body = [
      `Name: ${form.name}`,
      `Practice: ${form.practice}`,
      `Email: ${form.email}`,
      form.phone ? `Phone: ${form.phone}` : null,
      `Locations: ${form.locations}`,
    ]
      .filter(Boolean)
      .join("\n");
    return `mailto:${DEMO_EMAIL}?subject=${encodeURIComponent(
      "Demo request — " + (form.practice || form.name),
    )}&body=${encodeURIComponent(body)}`;
  }

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!ENDPOINT) {
      window.location.href = mailtoHref();
      return;
    }
    setStatus("sending");
    try {
      const res = await fetch(ENDPOINT, {
        method: "POST",
        headers: { Accept: "application/json", "Content-Type": "application/json" },
        body: JSON.stringify(form),
      });
      setStatus(res.ok ? "sent" : "error");
    } catch {
      setStatus("error");
    }
  }

  const input =
    "w-full rounded-lg border border-white/25 bg-white/10 px-3.5 py-2.5 text-sm text-white placeholder-white/50 focus:border-white/60 focus:outline-none";

  return (
    <section id="demo-cta" className="bg-accord-green-900 py-16 text-white sm:py-20">
      <Container>
        <div className="mx-auto max-w-xl text-center">
          <h2 className="text-[26px] font-semibold leading-[1.2] tracking-[-0.02em] sm:text-[30px]">
            See Accord on your own pre-Ds
          </h2>
          <p className="mt-3 text-[15px] text-white/70">
            Your practice. Real product. Your team.
          </p>
        </div>

        {status === "sent" ? (
          <div className="mx-auto mt-9 max-w-xl rounded-xl border border-white/20 bg-white/10 p-6 text-center">
            <p className="text-[16px] font-semibold">
              We&rsquo;ll be in touch within 24 hours.
            </p>
            <p className="mt-2 text-[13.5px] text-white/70">
              Sent to {DEMO_EMAIL}.
            </p>
          </div>
        ) : (
          <form onSubmit={onSubmit} className="mx-auto mt-9 max-w-xl">
            <div className="grid gap-3 sm:grid-cols-2">
              <input
                required
                value={form.name}
                onChange={set("name")}
                placeholder="Name"
                aria-label="Name"
                className={input}
              />
              <input
                required
                value={form.practice}
                onChange={set("practice")}
                placeholder="Practice name"
                aria-label="Practice name"
                className={input}
              />
              <input
                required
                type="email"
                value={form.email}
                onChange={set("email")}
                placeholder="Email"
                aria-label="Email"
                className={input}
              />
              <input
                type="tel"
                value={form.phone}
                onChange={set("phone")}
                placeholder="Phone (optional)"
                aria-label="Phone"
                className={input}
              />
              <select
                value={form.locations}
                onChange={set("locations")}
                aria-label="Number of locations"
                className={`${input} sm:col-span-2`}
              >
                {LOCATIONS.map((l) => (
                  <option key={l} value={l} className="text-gray-900">
                    {l} {l === "1" ? "location" : "locations"}
                  </option>
                ))}
              </select>
            </div>

            <button
              type="submit"
              disabled={status === "sending"}
              className="mt-4 inline-flex w-full items-center justify-center rounded-lg bg-white px-6 py-3 text-sm font-semibold text-accord-green-900 transition hover:bg-accord-green-50 disabled:opacity-60"
            >
              {status === "sending"
                ? "Sending…"
                : ENDPOINT
                  ? "Request a demo"
                  : `Email ${DEMO_EMAIL}`}
            </button>

            {!ENDPOINT && (
              <p className="mt-3 text-center text-[12px] text-white/60">
                Form delivery is not configured yet — this opens your mail
                client instead of posting. Set{" "}
                <code className="font-mono">VITE_FORMSPREE_ENDPOINT</code> to
                enable it.
              </p>
            )}
            {status === "error" && (
              <p className="mt-3 text-center text-[12.5px] text-accord-amber-50">
                That didn&rsquo;t send. Email{" "}
                <a className="underline" href={mailtoHref()}>
                  {DEMO_EMAIL}
                </a>{" "}
                and we&rsquo;ll pick it up.
              </p>
            )}
          </form>
        )}
      </Container>
    </section>
  );
}
