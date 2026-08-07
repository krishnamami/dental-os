/**
 * The dark bar above a detail view — breadcrumb left, actions right.
 *
 * ONE definition, used by the coverage detail and the workbench. Two
 * copies drift on the first colour change, and a bar that is #0B1220
 * on one screen and #0C1220 on the next reads as a rendering bug.
 *
 * Why inline styles rather than Tailwind classes: the palette here is
 * translucent white over a fixed navy, and `rgba(255,255,255,0.12)`
 * as an arbitrary value is both unreadable and easy to typo into a
 * class that silently does not exist. These five values are the
 * contract with the design, so they are written literally.
 *
 * On the ghost buttons: filled at 12% with a 28% border, not
 * border-only. A hairline outline on navy disappears on a dim laptop
 * screen at an angle — which is most chairside screens — and an action
 * a user cannot see is an action they do not take.
 */
const BAR = "#0B1220";
const BORDER = "#1e2d3d";
const GHOST_FILL = "rgba(255,255,255,0.12)";
const GHOST_BORDER = "rgba(255,255,255,0.28)";
const GREEN = "#0F4D37";

export interface TopbarAction {
  label: string;
  onClick?: () => void;
  /** Shown on hover. Say plainly when an action is demo-only. */
  title?: string;
  disabled?: boolean;
}

export default function DetailTopbar({
  root,
  current,
  actions,
  primary,
}: {
  /** Left half of the breadcrumb, e.g. "Coverage". */
  root: string;
  /** Right half — the patient. Empty until their record loads. */
  current: string;
  actions: TopbarAction[];
  primary?: TopbarAction;
}) {
  return (
    <div
      style={{
        background: BAR,
        borderBottom: `1px solid ${BORDER}`,
        minHeight: 44,
        display: "flex",
        alignItems: "center",
        flexWrap: "wrap",
        padding: "6px 16px",
        gap: 8,
        flexShrink: 0,
      }}
    >
      <span style={{ fontSize: 11, marginRight: "auto" }}>
        <span style={{ color: "rgba(255,255,255,0.45)" }}>{root}</span>
        {current && (
          <>
            <span style={{ color: "rgba(255,255,255,0.2)", margin: "0 6px" }}>
              ›
            </span>
            <span style={{ color: "#ffffff", fontWeight: 500 }}>{current}</span>
          </>
        )}
      </span>

      {actions.map((a) => (
        <button
          key={a.label}
          type="button"
          onClick={a.onClick}
          title={a.title}
          disabled={a.disabled}
          style={{
            background: GHOST_FILL,
            border: `1px solid ${GHOST_BORDER}`,
            color: "#ffffff",
            padding: "4px 12px",
            borderRadius: 6,
            fontSize: 11,
            fontWeight: 500,
            cursor: a.disabled ? "not-allowed" : "pointer",
            opacity: a.disabled ? 0.45 : 1,
            whiteSpace: "nowrap",
          }}
        >
          {a.label}
        </button>
      ))}

      {primary && (
        <button
          type="button"
          onClick={primary.onClick}
          title={primary.title}
          disabled={primary.disabled}
          style={{
            background: GREEN,
            border: "none",
            color: "#ffffff",
            padding: "4px 14px",
            borderRadius: 6,
            fontSize: 11,
            fontWeight: 600,
            cursor: primary.disabled ? "not-allowed" : "pointer",
            opacity: primary.disabled ? 0.45 : 1,
            whiteSpace: "nowrap",
          }}
        >
          {primary.label}
        </button>
      )}
    </div>
  );
}
