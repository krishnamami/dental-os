/**
 * Sending the estimate — by mail, or by text.
 *
 * ── Neither of these sends anything from the browser ─────────────────
 *
 * "Open in mail app" hands a mailto: to the operating system. The
 * message leaves from the coordinator's own mail client, under their
 * own address, which is why the From line is display-only: this app
 * cannot send as Jennifer and should not imply it can.
 *
 * "Send text" posts to /communications/sms, which currently LOGS and
 * returns. AWS SNS is not wired — see send_sms() in dental-os for the
 * list of things that have to exist first (spend limit, 10DLC
 * origination identity, STOP/HELP handling). The modal says so in as
 * many words rather than letting a coordinator believe a patient got
 * a message.
 *
 * ── On the 160-character limit ───────────────────────────────────────
 *
 * 160 is one GSM-7 segment. Past it a message still sends, as two
 * segments at twice the cost, so the counter warns rather than
 * truncates — silently cutting a patient's cost figure in half would
 * be worse than a longer text.
 */
import { useEffect, useState } from "react";
import ActionError from "../../../components/ActionError";

const GREEN = "#0F4D37";

/** "+17705550001" -> "+1 (770) 555-0001". Anything that is not a
 *  plain US number is shown exactly as stored. */
export function prettyPhone(raw?: string | null): string {
  if (!raw) return "";
  const m = raw.match(/^\+1(\d{3})(\d{3})(\d{4})$/);
  return m ? `+1 (${m[1]}) ${m[2]}-${m[3]}` : raw;
}

function Shell({
  title,
  subtitle,
  onClose,
  children,
}: {
  title: string;
  subtitle: string;
  onClose: () => void;
  children: React.ReactNode;
}) {
  // Escape closes. A modal over a patient's financial details should
  // never need a mouse to dismiss.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
      role="dialog"
      aria-modal="true"
      aria-label={title}
      onClick={onClose}
    >
      <div
        className="max-h-[85vh] w-full max-w-lg overflow-y-auto rounded-xl bg-white p-5 shadow-xl"
        onClick={(e) => e.stopPropagation()}
      >
        <h3 className="text-[15px] font-semibold text-gray-900">{title}</h3>
        <p className="mt-0.5 text-[12px] text-gray-500">{subtitle}</p>
        {children}
      </div>
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-wrap gap-2 border-b border-gray-100 py-1.5">
      <span className="w-[68px] flex-shrink-0 text-[11px] font-semibold uppercase tracking-wide text-gray-500">
        {label}
      </span>
      <span className="min-w-0 break-all text-[12.5px] text-gray-800">
        {value}
      </span>
    </div>
  );
}

const inputCls =
  "mt-1 w-full rounded-lg border border-gray-300 px-2.5 py-1.5 text-[12.5px] text-gray-900 focus:border-accord-green-500 focus:outline-none focus:ring-1 focus:ring-accord-green-500";

export function EmailModal({
  patientName,
  patientEmail,
  senderName,
  senderEmail,
  practiceEmail,
  practice,
  defaultSubject,
  defaultBody,
  onClose,
  onToast,
}: {
  patientName: string;
  patientEmail: string | null;
  senderName: string;
  senderEmail: string;
  practiceEmail: string;
  practice: string;
  defaultSubject: string;
  defaultBody: string;
  onClose: () => void;
  onToast: (m: string) => void;
}) {
  const [to, setTo] = useState(patientEmail ?? "");
  const [subject, setSubject] = useState(defaultSubject);
  const [body, setBody] = useState(defaultBody);

  const mailto =
    `mailto:${encodeURIComponent(to)}` +
    `?subject=${encodeURIComponent(subject)}` +
    `&body=${encodeURIComponent(body)}` +
    (practiceEmail ? `&reply-to=${encodeURIComponent(practiceEmail)}` : "");

  // Measured, not guessed: the full estimate body produces a ~2.6KB
  // mailto:. Windows caps the URL it hands a mail client at roughly
  // 2KB and several clients truncate silently past that — the patient
  // would get an email that stops mid-sentence, mid-figure. Over the
  // line, point at Copy instead of pretending the handoff is clean.
  const tooLongForMailto = mailto.length > 2000;

  return (
    <Shell
      title="Email to patient"
      subtitle={`Estimate for ${patientName} · ${practice}`}
      onClose={onClose}
    >
      <div className="mt-3">
        <label className="text-[11px] font-semibold uppercase tracking-wide text-gray-500">
          To
        </label>
        <input
          value={to}
          onChange={(e) => setTo(e.target.value)}
          placeholder="patient@email.com"
          className={inputCls}
        />
        {!patientEmail && (
          <p className="mt-1 text-[11px] text-amber-700">
            No address on file for this patient — type one in.
          </p>
        )}
      </div>

      <div className="mt-3">
        {/* Display only. The mail leaves from the coordinator's own
            client under their own address; this app has no mail
            server and must not suggest it sends as them. */}
        <Row label="From" value={`${senderName} <${senderEmail || "—"}>`} />
        <Row label="Reply-to" value={practiceEmail || "—"} />
      </div>

      <div className="mt-3">
        <label className="text-[11px] font-semibold uppercase tracking-wide text-gray-500">
          Subject
        </label>
        <input
          value={subject}
          onChange={(e) => setSubject(e.target.value)}
          className={inputCls}
        />
      </div>

      <div className="mt-3">
        <label className="text-[11px] font-semibold uppercase tracking-wide text-gray-500">
          Message
        </label>
        <textarea
          value={body}
          onChange={(e) => setBody(e.target.value)}
          rows={12}
          className={`${inputCls} font-mono text-[11.5px] leading-relaxed`}
        />
      </div>

      <div className="mt-4 flex flex-wrap gap-2">
        <a
          href={mailto}
          onClick={() => {
            onToast(
              tooLongForMailto
                ? "Opening your mail app — check nothing was cut off"
                : "Opening your mail app…",
            );
            onClose();
          }}
          className="rounded-lg px-3.5 py-2 text-[12.5px] font-semibold text-white"
          style={{ backgroundColor: GREEN }}
        >
          Open in mail app
        </a>
        <button
          type="button"
          onClick={() => {
            navigator.clipboard
              ?.writeText(`Subject: ${subject}\n\n${body}`)
              .then(() => onToast("Email text copied ✓"))
              .catch(() =>
                onToast("Could not copy — check clipboard permission"),
              );
          }}
          className="rounded-lg border border-gray-300 bg-white px-3.5 py-2 text-[12.5px] font-medium text-gray-700 transition hover:bg-gray-50"
        >
          Copy to clipboard
        </button>
        <button
          type="button"
          onClick={onClose}
          className="ml-auto rounded-lg px-3 py-2 text-[12.5px] text-gray-500 hover:text-gray-800"
        >
          Cancel
        </button>
      </div>

      {tooLongForMailto && (
        <p className="mt-2 rounded-lg bg-amber-50 px-3 py-2 text-[11px] leading-relaxed text-amber-900">
          ⚠ This message is long enough ({mailto.length} characters as a link)
          that some mail clients will cut it short. Use{" "}
          <span className="font-semibold">Copy to clipboard</span> and paste it
          in instead, or shorten the message above.
        </p>
      )}

      <p className="mt-3 rounded-lg bg-slate-50 px-3 py-2 text-[11px] leading-relaxed text-gray-500">
        ✉ Accord does not send this. &ldquo;Open in mail app&rdquo; hands the
        message to your own email client with the address, subject and body
        filled in — you press send there, so it goes out under your address
        with {practiceEmail || "the practice"} on reply-to.
      </p>
    </Shell>
  );
}

export function SmsModal({
  patientName,
  patientPhone,
  defaultMessage,
  onSend,
  onClose,
}: {
  patientName: string;
  patientPhone: string | null;
  defaultMessage: string;
  onSend: (message: string) => Promise<void>;
  onClose: () => void;
}) {
  const [message, setMessage] = useState(defaultMessage);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const over = message.length > 160;

  return (
    <Shell
      title="Text to patient"
      subtitle="Send estimate summary via SMS"
      onClose={onClose}
    >
      <div className="mt-3">
        <Row label="To" value={prettyPhone(patientPhone) || "no number on file"} />
        <Row label="Patient" value={patientName} />
      </div>

      <div className="mt-3">
        <div className="flex items-baseline justify-between gap-2">
          <label className="text-[11px] font-semibold uppercase tracking-wide text-gray-500">
            Message
          </label>
          <span
            className="text-[11px] tabular-nums"
            style={{ color: over ? "#b45309" : "#6b7280" }}
          >
            {message.length}/160
            {over ? " · 2 segments" : ""}
          </span>
        </div>
        <textarea
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          rows={4}
          className={`${inputCls} leading-relaxed`}
        />
        {over && (
          // Warn, never truncate: cutting the message at 160 could
          // remove the digits off the end of a cost figure.
          <p className="mt-1 text-[11px] text-amber-700">
            Over one SMS segment. It will still send, as two messages.
          </p>
        )}
      </div>

      <div className="mt-4 flex flex-wrap gap-2">
        <button
          type="button"
          disabled={busy || !patientPhone || message.trim().length === 0}
          onClick={() => {
            setBusy(true);
            setError(null);
            // The modal stays open on failure and says so here. It used
            // to close on any outcome, so a text that never left looked
            // exactly like one that did — and the drafted message was
            // gone with it.
            void onSend(message)
              .catch(() =>
                setError(
                  `The text to ${patientName} was NOT sent. Your message is ` +
                    "still here — press Send text to try again.",
                ),
              )
              .finally(() => setBusy(false));
          }}
          className="rounded-lg px-3.5 py-2 text-[12.5px] font-semibold text-white disabled:cursor-not-allowed disabled:opacity-60"
          style={{ backgroundColor: GREEN }}
        >
          {busy ? "Sending…" : error ? "Send text again" : "Send text"}
        </button>
        <button
          type="button"
          onClick={onClose}
          className="rounded-lg border border-gray-300 bg-white px-3.5 py-2 text-[12.5px] font-medium text-gray-700 transition hover:bg-gray-50"
        >
          Cancel
        </button>
      </div>

      <ActionError message={error} />

      <p className="mt-3 rounded-lg bg-blue-50 px-3 py-2 text-[11px] leading-relaxed text-blue-900">
        💬 Nothing is sent yet. The request reaches dental-os and is logged;
        AWS SNS is not connected, and switching it on needs a spend limit, a
        registered origination number and STOP/HELP handling first.
      </p>
    </Shell>
  );
}
