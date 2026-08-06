import { useEffect, useRef, useState } from "react";
import { X } from "lucide-react";

/**
 * Demo request modal.
 *
 * Posts to the Formspree form behind VITE_FORMSPREE_ENDPOINT. As in the
 * old inline form, an unreplaced placeholder counts as NOT configured:
 * shipping `YOUR_FORM_ID` verbatim would read as wired, POST to a URL
 * that 404s, and drop every lead into the error branch. Falling back to
 * a prefilled mailto always delivers.
 */
const RAW_ENDPOINT = import.meta.env.VITE_FORMSPREE_ENDPOINT as
  | string
  | undefined;

const ENDPOINT =
  RAW_ENDPOINT && !/YOUR_FORM_ID|xxxxxxxx|^\s*$/i.test(RAW_ENDPOINT)
    ? RAW_ENDPOINT
    : undefined;

export const DEMO_EMAIL = "demo@accorddental.io";

const LOCATIONS = [
  { value: "1", label: "1 location" },
  { value: "2-5", label: "2–5 locations" },
  { value: "6-20", label: "6–20 locations" },
  { value: "20+", label: "20+ locations" },
];

type Status = "idle" | "sending" | "sent" | "error";

const EMPTY = {
  firstName: "",
  lastName: "",
  practice: "",
  email: "",
  phone: "",
  locations: LOCATIONS[0].value,
  problem: "",
};

export default function DemoModal({
  isOpen,
  onClose,
}: {
  isOpen: boolean;
  onClose: () => void;
}) {
  const [form, setForm] = useState(EMPTY);
  const [status, setStatus] = useState<Status>("idle");
  const closeRef = useRef(onClose);
  closeRef.current = onClose;

  // Escape closes; body scroll locks while open so the page behind does
  // not slide under the overlay on a phone.
  useEffect(() => {
    if (!isOpen) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") closeRef.current();
    };
    document.addEventListener("keydown", onKey);
    const previous = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = previous;
    };
  }, [isOpen]);

  // Reset a moment AFTER closing, not on open — resetting on open would
  // wipe what someone typed if they closed by accident and reopened.
  useEffect(() => {
    if (isOpen) return;
    const t = setTimeout(() => {
      setForm(EMPTY);
      setStatus("idle");
    }, 300);
    return () => clearTimeout(t);
  }, [isOpen]);

  // Auto-close on success. The ref keeps this from re-firing if the
  // parent re-renders with a new onClose identity.
  useEffect(() => {
    if (status !== "sent") return;
    const t = setTimeout(() => closeRef.current(), 3000);
    return () => clearTimeout(t);
  }, [status]);

  if (!isOpen) return null;

  const set =
    (key: keyof typeof form) =>
    (
      e: React.ChangeEvent<
        HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement
      >,
    ) =>
      setForm((f) => ({ ...f, [key]: e.target.value }));

  function mailtoHref() {
    const body = [
      `Name: ${form.firstName} ${form.lastName}`,
      `Practice: ${form.practice}`,
      `Email: ${form.email}`,
      form.phone ? `Phone: ${form.phone}` : null,
      `Locations: ${form.locations}`,
      form.problem ? `\nLooking to solve:\n${form.problem}` : null,
    ]
      .filter(Boolean)
      .join("\n");
    return `mailto:${DEMO_EMAIL}?subject=${encodeURIComponent(
      `Demo request — ${form.practice || form.firstName}`,
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
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
        },
        body: JSON.stringify(form),
      });
      setStatus(res.ok ? "sent" : "error");
    } catch {
      setStatus("error");
    }
  }

  const field =
    "w-full rounded-lg border border-gray-300 px-3 py-2 text-sm text-gray-900 placeholder-gray-400 focus:border-accord-green-500 focus:outline-none focus:ring-1 focus:ring-accord-green-500";
  const label = "mb-1 block text-[12.5px] font-medium text-gray-700";

  return (
    <div
      className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-black/50 p-4 sm:items-center"
      onClick={onClose}
      role="presentation"
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="demo-modal-title"
        // Stops a click inside the card from reaching the overlay
        // handler and closing the modal mid-typing.
        onClick={(e) => e.stopPropagation()}
        className="relative my-8 w-full max-w-lg rounded-2xl bg-white p-6 shadow-xl sm:my-0 sm:p-8"
      >
        <button
          type="button"
          onClick={onClose}
          aria-label="Close"
          className="absolute right-4 top-4 rounded-lg p-1.5 text-gray-400 transition hover:bg-gray-100 hover:text-gray-600"
        >
          <X size={18} />
        </button>

        {status === "sent" ? (
          <div className="py-8 text-center">
            <p className="text-[18px] font-semibold text-accord-green-900">
              Thank you! We&rsquo;ll be in touch within one business day.
            </p>
            <p className="mt-2 text-[13.5px] text-gray-500">
              Sent to {DEMO_EMAIL}.
            </p>
          </div>
        ) : (
          <>
            <h2
              id="demo-modal-title"
              className="text-[20px] font-semibold tracking-[-0.01em] text-gray-900"
            >
              Request a demo
            </h2>
            <p className="mt-1.5 text-[13.5px] leading-relaxed text-gray-500">
              We&rsquo;ll show you Accord on your own pre-Ds — no slides, real
              product.
            </p>

            <form onSubmit={onSubmit} className="mt-5 space-y-3.5">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className={label} htmlFor="dm-first">
                    First name *
                  </label>
                  <input
                    id="dm-first"
                    required
                    value={form.firstName}
                    onChange={set("firstName")}
                    className={field}
                  />
                </div>
                <div>
                  <label className={label} htmlFor="dm-last">
                    Last name *
                  </label>
                  <input
                    id="dm-last"
                    required
                    value={form.lastName}
                    onChange={set("lastName")}
                    className={field}
                  />
                </div>
              </div>

              <div>
                <label className={label} htmlFor="dm-practice">
                  Practice name *
                </label>
                <input
                  id="dm-practice"
                  required
                  value={form.practice}
                  onChange={set("practice")}
                  className={field}
                />
              </div>

              <div>
                <label className={label} htmlFor="dm-email">
                  Work email *
                </label>
                <input
                  id="dm-email"
                  required
                  type="email"
                  value={form.email}
                  onChange={set("email")}
                  className={field}
                />
              </div>

              <div>
                <label className={label} htmlFor="dm-phone">
                  Phone
                </label>
                <input
                  id="dm-phone"
                  type="tel"
                  value={form.phone}
                  onChange={set("phone")}
                  className={field}
                />
              </div>

              <div>
                <label className={label} htmlFor="dm-locations">
                  Number of locations
                </label>
                <select
                  id="dm-locations"
                  value={form.locations}
                  onChange={set("locations")}
                  className={field}
                >
                  {LOCATIONS.map((l) => (
                    <option key={l.value} value={l.value}>
                      {l.label}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className={label} htmlFor="dm-problem">
                  What are you looking to solve?
                </label>
                <textarea
                  id="dm-problem"
                  rows={3}
                  value={form.problem}
                  onChange={set("problem")}
                  className={`${field} resize-none`}
                />
              </div>

              <button
                type="submit"
                disabled={status === "sending"}
                className="inline-flex w-full items-center justify-center gap-2 rounded-lg bg-accord-green-900 px-5 py-2.5 text-sm font-semibold text-white transition hover:bg-accord-green-700 disabled:opacity-60"
              >
                {status === "sending"
                  ? "Sending…"
                  : ENDPOINT
                    ? "Request demo →"
                    : `Email ${DEMO_EMAIL}`}
              </button>

              {status === "error" && (
                <p className="text-center text-[12.5px] text-red-600">
                  Something went wrong. Email us at{" "}
                  <a className="underline" href={mailtoHref()}>
                    {DEMO_EMAIL}
                  </a>
                </p>
              )}
              {!ENDPOINT && (
                <p className="text-center text-[12px] text-gray-400">
                  Form delivery is not configured — this opens your mail client.
                </p>
              )}

              <p className="pt-1 text-center text-[12px] text-gray-400">
                We&rsquo;ll respond within one business day.
              </p>
            </form>
          </>
        )}
      </div>
    </div>
  );
}
