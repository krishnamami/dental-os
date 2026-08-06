/**
 * The Accord wordmark — a green tile with an "A" plus the word.
 *
 * Matches accordlend so the two products read as one company. Drawn in
 * CSS rather than shipped as an image: it stays sharp at any DPR, needs
 * no network request in the nav's critical path, and `dark` recolours
 * the text without a second asset.
 *
 * `size` drives the tile only. The word stays at text-lg on purpose —
 * scaling both together made the 24px sidebar variant read as a
 * different logo rather than a smaller one.
 */
export function AccordLogo({
  size = 28,
  dark = false,
}: {
  /** Tile edge length in px. 28 in the marketing nav, 24 in the app. */
  size?: number;
  /** True on dark backgrounds — switches the word to white. */
  dark?: boolean;
}) {
  return (
    <span className="flex items-center gap-2">
      <span
        className="flex flex-shrink-0 items-center justify-center rounded-md bg-[#1B5E20] text-sm font-bold text-white"
        style={{ width: size, height: size }}
        aria-hidden="true"
      >
        A
      </span>
      <span
        className={`text-lg font-bold tracking-tight ${
          dark ? "text-white" : "text-slate-900"
        }`}
      >
        accord
      </span>
    </span>
  );
}
