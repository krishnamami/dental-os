import { useState } from "react";
import {
  AlertTriangle,
  ArrowLeft,
  Bell,
  Camera,
  Check,
  CheckCircle2,
  ChevronDown,
  ChevronRight,
  Clock,
  FileText,
  Send,
  ShieldCheck,
  Sparkles,
  X,
} from "lucide-react";

const C = {
  green: "#0F4D37",
  greenSoft: "#E7F0EC",
  greenLine: "#B9D3C8",
  navy: "#0B1220",
  amber: "#8A5A0B",
  amberSoft: "#FDF3DF",
  amberLine: "#EBD5A6",
  slate: "#334155",
  slateSoft: "#F1F5F9",
  slateLine: "#DCE3EB",
  ink: "#0F172A",
  muted: "#64748B",
  line: "#E2E8F0",
  page: "#F7F8FA",
};

const FONT = "'Plus Jakarta Sans', system-ui, -apple-system, sans-serif";

const SEED = [
  {
    id: "DA-A01",
    patient: "James Mitchell",
    meta: "54 · Op 2 · 2:15 PM",
    payer: "Delta Dental GA",
    reason: "Crown downgrade + missing radiograph",
    handoff: {
      from: "Jennifer M. · treatment coordinator",
      note: "Patient asked whether a filling would hold instead of the crown. He's price-sensitive — wants to hear it from you.",
    },
    plan: [
      { code: "D2740", desc: "Crown — porcelain/ceramic, #19", fee: "$1,450" },
      { code: "D2950", desc: "Core buildup, #19", fee: "$285" },
    ],
    support: [
      "Bitewing 8/9/2026 — recurrent caries at distal margin, #19",
      "Existing MOD amalgam, marginal breakdown, distolingual cusp lost",
      "ADA guidance: full coverage indicated below 50% remaining structure",
    ],
    gaps: [
      { id: "g1", label: "Periapical of #19", note: "Not on file. Delta requires it for D2740.", kind: "xray" },
      { id: "g2", label: "Pre-op intraoral photo", note: "Optional — strengthens the case if this is later denied.", kind: "photo" },
    ],
    friction: [
      {
        id: "f1",
        label: "Delta downgrades D2740 to D2392 on posterior teeth",
        note: "Patient pays the $412 difference unless clinical necessity is documented.",
        needsJustification: true,
        draft:
          "Remaining coronal structure on #19 is approximately 45% following removal of recurrent caries and the fractured distolingual cusp. A two-surface direct composite cannot provide cuspal coverage under posterior occlusal load and would be expected to fail within 24 months.",
      },
    ],
    narrative:
      "Tooth #19 presents with recurrent caries at the distal margin of an existing MOD amalgam, with loss of the distolingual cusp. Remaining coronal tooth structure is approximately 45%, insufficient to retain a direct restoration under occlusal load. Core buildup and full-coverage crown are indicated to restore function and prevent cuspal fracture.",
  },
  {
    id: "DA-C03",
    patient: "Robert Thompson",
    meta: "61 · Op 1 · 3:00 PM",
    payer: "Cigna DPPO",
    reason: "Perio charting out of date",
    handoff: null,
    plan: [
      { code: "D4341", desc: "Scaling and root planing — 4 quadrants", fee: "$1,120" },
    ],
    support: [
      "Probing depths 5–7 mm in all four quadrants",
      "Radiographic horizontal bone loss, generalized",
      "Bleeding on probing at 68% of sites",
    ],
    gaps: [
      { id: "g1", label: "Full-mouth perio charting", note: "Last on file 2/14/2026. Cigna requires within 90 days.", kind: "chart" },
    ],
    friction: [
      {
        id: "f1",
        label: "Frequency limit — SRP once per quadrant per 24 months",
        note: "Last SRP was 3/2024. Clears by 5 months. No action needed.",
        needsJustification: false,
      },
    ],
    narrative:
      "Generalized moderate chronic periodontitis with probing depths of 5–7 mm across all four quadrants and radiographic evidence of horizontal bone loss. Bleeding on probing is present at 68% of sites. Scaling and root planing in four quadrants is indicated prior to any restorative treatment.",
  },
  {
    id: "DA-E05",
    patient: "Maria Santos",
    meta: "38 · Op 3 · 3:45 PM",
    payer: "Delta Dental GA",
    reason: "Buildup bundling risk — narrative only",
    handoff: null,
    plan: [
      { code: "D2740", desc: "Crown — porcelain/ceramic, #3", fee: "$1,450" },
      { code: "D2950", desc: "Core buildup, #3", fee: "$285" },
    ],
    support: [
      "Periapical 8/8/2026 — mesiobuccal cusp fracture, #3",
      "Existing large MOD restoration, undermined walls",
      "ADA descriptor: D2950 is separate from crown preparation",
    ],
    gaps: [],
    friction: [
      {
        id: "f1",
        label: "Delta bundles D2950 into the crown in roughly 30% of cases",
        note: "Your narrative below addresses this. No separate action needed.",
        needsJustification: false,
      },
    ],
    narrative:
      "Tooth #3 is fractured at the mesiobuccal cusp with an existing large MOD restoration and undermined axial walls. Core buildup is required to establish adequate resistance and retention form prior to crown preparation, and is not a component of the crown procedure.",
  },
];

const CLEARED = [
  { id: "DA-D04", patient: "Linda Taylor", note: "Submitted to Delta Dental" },
  { id: "DA-F01", patient: "Anthony Reyes", note: "Prophy — no pre-D required" },
  { id: "DA-F02", patient: "Grace Kim", note: "Evidence complete, queued for billing" },
];

function Pill({ tone, children }) {
  const map = {
    green: { bg: C.greenSoft, fg: C.green, bd: C.greenLine },
    amber: { bg: C.amberSoft, fg: C.amber, bd: C.amberLine },
    slate: { bg: C.slateSoft, fg: C.slate, bd: C.slateLine },
  };
  const t = map[tone] || map.slate;
  return (
    <span
      className="inline-flex items-center gap-1 rounded-full px-2 py-1 text-xs"
      style={{ background: t.bg, color: t.fg, border: `1px solid ${t.bd}`, fontWeight: 500 }}
    >
      {children}
    </span>
  );
}

function SectionHead({ icon, title, count, tone }) {
  const color = tone === "amber" ? C.amber : tone === "green" ? C.green : C.slate;
  return (
    <div className="flex items-center gap-2 mb-3">
      <span style={{ color }}>{icon}</span>
      <h3 className="text-sm" style={{ color: C.ink, fontWeight: 600 }}>
        {title}
      </h3>
      {typeof count === "number" && (
        <span className="text-xs" style={{ color: C.muted }}>
          {count}
        </span>
      )}
    </div>
  );
}

export default function DentistWorkbench() {
  const [cases, setCases] = useState(SEED);
  const [selectedId, setSelectedId] = useState(SEED[0].id);
  const [requested, setRequested] = useState({});
  const [justifications, setJustifications] = useState({});
  const [openJustify, setOpenJustify] = useState(null);
  const [drafts, setDrafts] = useState(() =>
    Object.fromEntries(SEED.map((c) => [c.id, c.narrative]))
  );
  const [attested, setAttested] = useState({});
  const [submitting, setSubmitting] = useState(false);
  const [submitted, setSubmitted] = useState([]);
  const [showCleared, setShowCleared] = useState(false);

  const active = cases.find((c) => c.id === selectedId) || null;

  const gapKey = (cid, gid) => `${cid}:${gid}`;

  const openGaps = active
    ? active.gaps.filter((g) => !requested[gapKey(active.id, g.id)]).length
    : 0;
  const needsJustify = active
    ? active.friction.filter((f) => f.needsJustification && !justifications[gapKey(active.id, f.id)]).length
    : 0;
  const blockers = openGaps + needsJustify;
  const canSubmit = active && attested[active.id] && !submitting;

  function requestItem(cid, gid) {
    setRequested((r) => ({ ...r, [gapKey(cid, gid)]: true }));
  }

  function saveJustification(cid, fid, text) {
    setJustifications((j) => ({ ...j, [gapKey(cid, fid)]: text }));
    setOpenJustify(null);
  }

  function submitCase() {
    if (!active) return;
    setSubmitting(true);
    setTimeout(() => {
      setSubmitting(false);
      setSubmitted((s) => [{ id: active.id, patient: active.patient, payer: active.payer }, ...s]);
      const rest = cases.filter((c) => c.id !== active.id);
      setCases(rest);
      setSelectedId(rest.length ? rest[0].id : null);
    }, 1100);
  }

  return (
    <div style={{ fontFamily: FONT, background: C.page, minHeight: "100vh", color: C.ink }}>
      {/* Topbar */}
      <div style={{ background: C.navy }} className="px-4 md:px-8 py-3">
        <div className="flex items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <div
              className="flex items-center justify-center rounded"
              style={{ background: C.green, width: 28, height: 28, color: "white", fontWeight: 700 }}
            >
              A
            </div>
            <span style={{ color: "white", fontWeight: 600 }}>accord</span>
            <span
              className="hidden sm:inline text-xs px-2 py-1 rounded"
              style={{ color: "rgba(255,255,255,0.75)", background: "rgba(255,255,255,0.12)" }}
            >
              Pre-D workbench
            </span>
          </div>
          <div className="flex items-center gap-3">
            <span className="hidden md:inline text-xs" style={{ color: "rgba(255,255,255,0.6)" }}>
              Sunday, August 9
            </span>
            <span className="text-sm" style={{ color: "white" }}>
              Dr. Chinta
            </span>
          </div>
        </div>
      </div>

      <div className="px-4 md:px-8 py-6 max-w-7xl mx-auto">
        <div className="grid grid-cols-1 md:grid-cols-12 gap-6">
          {/* Queue */}
          <div className={`md:col-span-4 ${selectedId ? "hidden md:block" : "block"}`}>
            <div className="mb-4">
              <h1 className="text-xl" style={{ fontWeight: 700 }}>
                Needs your review
              </h1>
              <p className="text-sm mt-1" style={{ color: C.muted }}>
                {cases.length} of 15 cases today. The rest cleared without you.
              </p>
            </div>

            <div className="space-y-3">
              {cases.map((c) => {
                const isActive = c.id === selectedId;
                return (
                  <button
                    key={c.id}
                    onClick={() => setSelectedId(c.id)}
                    className="w-full text-left rounded-xl p-4 transition-colors"
                    style={{
                      background: "white",
                      border: `1px solid ${isActive ? C.green : C.line}`,
                      boxShadow: isActive ? `inset 3px 0 0 ${C.green}` : "none",
                    }}
                  >
                    <div className="flex items-start justify-between gap-2">
                      <div>
                        <div style={{ fontWeight: 600 }}>{c.patient}</div>
                        <div className="text-xs mt-0.5" style={{ color: C.muted }}>
                          {c.meta}
                        </div>
                      </div>
                      <ChevronRight size={16} style={{ color: C.muted, flexShrink: 0 }} />
                    </div>
                    <div className="mt-3 flex items-center gap-2 flex-wrap">
                      <Pill tone="amber">
                        <AlertTriangle size={12} />
                        {c.reason}
                      </Pill>
                    </div>
                    {c.handoff && (
                      <div className="mt-2 flex items-center gap-1.5 text-xs" style={{ color: C.green }}>
                        <Bell size={12} />
                        Note from {c.handoff.from.split(" ·")[0]}
                      </div>
                    )}
                  </button>
                );
              })}

              {cases.length === 0 && (
                <div
                  className="rounded-xl p-6 text-center"
                  style={{ background: C.greenSoft, border: `1px solid ${C.greenLine}` }}
                >
                  <CheckCircle2 size={20} style={{ color: C.green, margin: "0 auto" }} />
                  <p className="text-sm mt-2" style={{ color: C.green, fontWeight: 600 }}>
                    Nothing left for you today
                  </p>
                  <p className="text-xs mt-1" style={{ color: C.green }}>
                    Everything else is with Kim.
                  </p>
                </div>
              )}
            </div>

            {submitted.length > 0 && (
              <div className="mt-6">
                <div className="text-xs mb-2" style={{ color: C.muted, fontWeight: 600 }}>
                  SUBMITTED TODAY
                </div>
                <div className="space-y-2">
                  {submitted.map((s) => (
                    <div
                      key={s.id}
                      className="rounded-lg px-3 py-2.5 flex items-center gap-2"
                      style={{ background: C.greenSoft, border: `1px solid ${C.greenLine}` }}
                    >
                      <Check size={14} style={{ color: C.green, flexShrink: 0 }} />
                      <div className="text-sm" style={{ color: C.green }}>
                        <span style={{ fontWeight: 600 }}>{s.patient}</span> — {s.id}
                        <div className="text-xs" style={{ opacity: 0.85 }}>
                          Sent to Kim's queue · {s.payer}
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            <div className="mt-6">
              <button
                onClick={() => setShowCleared((v) => !v)}
                className="w-full flex items-center justify-between rounded-lg px-3 py-2.5 text-sm"
                style={{ background: "white", border: `1px solid ${C.line}`, color: C.muted }}
              >
                <span>Cleared by the engine — 12 cases</span>
                <ChevronDown
                  size={16}
                  style={{ transform: showCleared ? "rotate(180deg)" : "none", transition: "transform .15s" }}
                />
              </button>
              {showCleared && (
                <div className="mt-2 space-y-1.5">
                  {CLEARED.map((c) => (
                    <div key={c.id} className="px-3 py-2 text-xs rounded-lg" style={{ background: "white", border: `1px solid ${C.line}` }}>
                      <span style={{ fontWeight: 600 }}>{c.patient}</span>
                      <span style={{ color: C.muted }}> — {c.note}</span>
                    </div>
                  ))}
                  <div className="px-3 py-2 text-xs" style={{ color: C.muted }}>
                    9 more
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* Detail */}
          <div className={`md:col-span-8 ${selectedId ? "block" : "hidden md:block"}`}>
            {!active && (
              <div
                className="rounded-xl p-10 text-center"
                style={{ background: "white", border: `1px solid ${C.line}` }}
              >
                <p className="text-sm" style={{ color: C.muted }}>
                  Select a case to review.
                </p>
              </div>
            )}

            {active && (
              <div className="space-y-4">
                <button
                  onClick={() => setSelectedId(null)}
                  className="md:hidden flex items-center gap-1.5 text-sm"
                  style={{ color: C.muted }}
                >
                  <ArrowLeft size={15} /> Back to queue
                </button>

                {/* Case header */}
                <div className="rounded-xl p-5" style={{ background: "white", border: `1px solid ${C.line}` }}>
                  <div className="flex items-start justify-between gap-4 flex-wrap">
                    <div>
                      <h2 className="text-lg" style={{ fontWeight: 700 }}>
                        {active.patient}
                      </h2>
                      <p className="text-sm mt-0.5" style={{ color: C.muted }}>
                        {active.meta} · {active.payer} · {active.id}
                      </p>
                    </div>
                    {blockers > 0 ? (
                      <Pill tone="amber">
                        <AlertTriangle size={12} />
                        {blockers} thing{blockers > 1 ? "s" : ""} to resolve
                      </Pill>
                    ) : (
                      <Pill tone="green">
                        <Check size={12} />
                        Ready to submit
                      </Pill>
                    )}
                  </div>

                  <div className="mt-4 space-y-1.5">
                    {active.plan.map((p) => (
                      <div key={p.code} className="flex items-center justify-between text-sm py-1.5" style={{ borderTop: `1px solid ${C.line}` }}>
                        <div className="flex items-center gap-3">
                          <span
                            className="text-xs px-1.5 py-0.5 rounded"
                            style={{ background: C.slateSoft, color: C.slate, fontFamily: "ui-monospace, monospace" }}
                          >
                            {p.code}
                          </span>
                          <span>{p.desc}</span>
                        </div>
                        <span style={{ color: C.muted }}>{p.fee}</span>
                      </div>
                    ))}
                  </div>
                </div>

                {/* Handoff */}
                {active.handoff && (
                  <div
                    className="rounded-xl p-4 flex gap-3"
                    style={{ background: C.greenSoft, border: `1px solid ${C.greenLine}` }}
                  >
                    <Bell size={16} style={{ color: C.green, flexShrink: 0, marginTop: 2 }} />
                    <div>
                      <div className="text-xs" style={{ color: C.green, fontWeight: 600 }}>
                        {active.handoff.from}
                      </div>
                      <p className="text-sm mt-1" style={{ color: C.green }}>
                        {active.handoff.note}
                      </p>
                    </div>
                  </div>
                )}

                {/* Clinical support */}
                <div className="rounded-xl p-5" style={{ background: "white", border: `1px solid ${C.line}` }}>
                  <SectionHead icon={<ShieldCheck size={16} />} title="What supports this plan" tone="green" />
                  <ul className="space-y-2">
                    {active.support.map((s, i) => (
                      <li key={i} className="flex gap-2.5 text-sm">
                        <Check size={15} style={{ color: C.green, flexShrink: 0, marginTop: 2 }} />
                        <span>{s}</span>
                      </li>
                    ))}
                  </ul>
                </div>

                {/* Documentation gaps */}
                <div className="rounded-xl p-5" style={{ background: "white", border: `1px solid ${C.line}` }}>
                  <SectionHead
                    icon={<Camera size={16} />}
                    title="Capture before the patient leaves"
                    count={active.gaps.length}
                    tone="amber"
                  />
                  {active.gaps.length === 0 && (
                    <p className="text-sm" style={{ color: C.muted }}>
                      Nothing missing. Everything this payer wants is already on file.
                    </p>
                  )}
                  <div className="space-y-2">
                    {active.gaps.map((g) => {
                      const done = requested[gapKey(active.id, g.id)];
                      return (
                        <div
                          key={g.id}
                          className="rounded-lg p-3 flex items-start justify-between gap-3 flex-wrap"
                          style={{
                            background: done ? C.greenSoft : C.amberSoft,
                            border: `1px solid ${done ? C.greenLine : C.amberLine}`,
                          }}
                        >
                          <div>
                            <div className="text-sm" style={{ fontWeight: 600, color: done ? C.green : C.amber }}>
                              {g.label}
                            </div>
                            <div className="text-xs mt-0.5" style={{ color: done ? C.green : C.amber }}>
                              {done ? "Requested — assistant notified" : g.note}
                            </div>
                          </div>
                          {!done && (
                            <button
                              onClick={() => requestItem(active.id, g.id)}
                              className="text-xs px-3 py-1.5 rounded-lg whitespace-nowrap"
                              style={{ background: C.amber, color: "white", fontWeight: 600 }}
                            >
                              Request now
                            </button>
                          )}
                        </div>
                      );
                    })}
                  </div>
                </div>

                {/* Payer friction */}
                <div className="rounded-xl p-5" style={{ background: "white", border: `1px solid ${C.line}` }}>
                  <SectionHead icon={<Clock size={16} />} title="What this payer will push back on" />
                  <div className="space-y-2">
                    {active.friction.map((f) => {
                      const saved = justifications[gapKey(active.id, f.id)];
                      const isOpen = openJustify === gapKey(active.id, f.id);
                      const needs = f.needsJustification && !saved;
                      return (
                        <div
                          key={f.id}
                          className="rounded-lg p-3"
                          style={{
                            background: needs ? C.amberSoft : C.slateSoft,
                            border: `1px solid ${needs ? C.amberLine : C.slateLine}`,
                          }}
                        >
                          <div className="flex items-start justify-between gap-3 flex-wrap">
                            <div>
                              <div className="text-sm" style={{ fontWeight: 600, color: needs ? C.amber : C.slate }}>
                                {f.label}
                              </div>
                              <div className="text-xs mt-0.5" style={{ color: needs ? C.amber : C.slate }}>
                                {f.note}
                              </div>
                            </div>
                            {f.needsJustification && !saved && !isOpen && (
                              <button
                                onClick={() => setOpenJustify(gapKey(active.id, f.id))}
                                className="text-xs px-3 py-1.5 rounded-lg whitespace-nowrap"
                                style={{ background: C.amber, color: "white", fontWeight: 600 }}
                              >
                                Justify necessity
                              </button>
                            )}
                          </div>

                          {isOpen && (
                            <JustifyBox
                              draft={f.draft}
                              onCancel={() => setOpenJustify(null)}
                              onSave={(text) => saveJustification(active.id, f.id, text)}
                            />
                          )}

                          {saved && (
                            <div className="mt-3 rounded-lg p-3" style={{ background: "white", border: `1px solid ${C.greenLine}` }}>
                              <div className="flex items-center gap-1.5 text-xs mb-1.5" style={{ color: C.green, fontWeight: 600 }}>
                                <Check size={13} /> Clinical necessity on record
                              </div>
                              <p className="text-sm" style={{ color: C.ink }}>
                                {saved}
                              </p>
                              <p className="text-xs mt-2" style={{ color: C.muted }}>
                                Attached to the submission and to any future appeal.
                              </p>
                            </div>
                          )}
                        </div>
                      );
                    })}
                  </div>
                </div>

                {/* Narrative */}
                <div className="rounded-xl p-5" style={{ background: "white", border: `1px solid ${C.line}` }}>
                  <div className="flex items-center justify-between gap-3 mb-3 flex-wrap">
                    <SectionHead icon={<FileText size={16} />} title="Your narrative to the payer" tone="green" />
                    <span className="inline-flex items-center gap-1.5 text-xs" style={{ color: C.green }}>
                      <Sparkles size={13} /> Drafted from the chart — edit freely
                    </span>
                  </div>
                  <textarea
                    value={drafts[active.id] || ""}
                    onChange={(e) => setDrafts((d) => ({ ...d, [active.id]: e.target.value }))}
                    rows={5}
                    className="w-full rounded-lg p-3 text-sm"
                    style={{
                      border: `1px solid ${C.line}`,
                      resize: "vertical",
                      fontFamily: FONT,
                      lineHeight: 1.6,
                      color: C.ink,
                    }}
                  />
                  <div className="flex items-center justify-between mt-2">
                    <span className="text-xs" style={{ color: C.muted }}>
                      {(drafts[active.id] || "").length} characters
                    </span>
                    <button
                      onClick={() => setDrafts((d) => ({ ...d, [active.id]: active.narrative }))}
                      className="text-xs"
                      style={{ color: C.green, fontWeight: 600 }}
                    >
                      Reset to draft
                    </button>
                  </div>
                </div>

                {/* Attest + submit */}
                <div
                  className="rounded-xl p-5"
                  style={{ background: C.greenSoft, border: `1px solid ${C.greenLine}` }}
                >
                  <label className="flex items-start gap-3 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={!!attested[active.id]}
                      onChange={(e) => setAttested((a) => ({ ...a, [active.id]: e.target.checked }))}
                      className="mt-1"
                      style={{ accentColor: C.green, width: 16, height: 16 }}
                    />
                    <span className="text-sm" style={{ color: C.green }}>
                      I attest that this treatment plan and the supporting documentation reflect my clinical judgment
                      for this patient.
                    </span>
                  </label>

                  {blockers > 0 && (
                    <p className="text-xs mt-3 pl-7" style={{ color: C.amber }}>
                      {blockers} item{blockers > 1 ? "s" : ""} still open. You can submit without them, but the payer is
                      more likely to come back.
                    </p>
                  )}

                  <div className="mt-4 flex items-center gap-3 flex-wrap">
                    <button
                      onClick={submitCase}
                      disabled={!canSubmit}
                      className="inline-flex items-center gap-2 px-4 py-2.5 rounded-lg text-sm"
                      style={{
                        background: canSubmit ? C.green : "#A9BDB4",
                        color: "white",
                        fontWeight: 600,
                        cursor: canSubmit ? "pointer" : "not-allowed",
                      }}
                    >
                      <Send size={15} />
                      {submitting ? "Submitting…" : "Sign and submit pre-D"}
                    </button>
                    <span className="text-xs" style={{ color: C.green }}>
                      Goes to Kim in revenue operations
                    </span>
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

function JustifyBox({ draft, onCancel, onSave }) {
  const [text, setText] = useState(draft || "");
  return (
    <div className="mt-3 rounded-lg p-3" style={{ background: "white", border: `1px solid ${C.line}` }}>
      <div className="flex items-center justify-between mb-2">
        <span className="inline-flex items-center gap-1.5 text-xs" style={{ color: C.green, fontWeight: 600 }}>
          <Sparkles size={13} /> Suggested wording
        </span>
        <button onClick={onCancel} style={{ color: C.muted }} aria-label="Cancel">
          <X size={15} />
        </button>
      </div>
      <textarea
        value={text}
        onChange={(e) => setText(e.target.value)}
        rows={4}
        className="w-full rounded-lg p-3 text-sm"
        style={{ border: `1px solid ${C.line}`, resize: "vertical", fontFamily: FONT, lineHeight: 1.6, color: C.ink }}
      />
      <div className="flex items-center gap-2 mt-2">
        <button
          onClick={() => onSave(text)}
          className="text-xs px-3 py-1.5 rounded-lg"
          style={{ background: C.green, color: "white", fontWeight: 600 }}
        >
          Save justification
        </button>
        <button onClick={onCancel} className="text-xs px-3 py-1.5 rounded-lg" style={{ color: C.muted }}>
          Cancel
        </button>
      </div>
    </div>
  );
}
