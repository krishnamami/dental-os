import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// The dental-os API runs on :9010 and has no CORS middleware, so the
// browser cannot call it directly from :5173. The proxy makes it
// same-origin in development: the app always fetches "/api/...", and
// only this file knows where that actually goes.
//
// In production the app is served from CloudFront and "/api" is
// expected to be routed to the API by the CDN or an ALB — which is why
// no component hardcodes localhost:9010.
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      "/api": {
        target: "http://localhost:9010",
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, ""),
      },
    },
  },
  build: {
    /**
     * Emit `@media (min-width: 1024px)` rather than the range syntax
     * `@media (width >= 1024px)`.
     *
     * The default minifier rewrites media queries to the Level 4 range
     * form, which Safari only understands from 16.4. An iPad on iOS
     * 16.0-16.3 does not error on it — it SKIPS the rule, so every
     * responsive breakpoint silently stops applying and the app renders
     * at its widest layout on a tablet. Dr. Chinta's chairside iPad is
     * exactly that device, so the two bytes saved are not worth it.
     */
    cssTarget: ["chrome87", "safari14", "firefox78", "edge88"],
    rollupOptions: {
      output: {
        /**
         * Vendor splitting only. The APPLICATION split is done with
         * React.lazy() in App.tsx, not here — a route's chunk should be
         * defined by the import that reaches it, so adding a page
         * cannot silently land it in the landing-page bundle.
         *
         * Function form rather than the object form: object entries are
         * matched against resolved module ids, and a relative path like
         * "./src/pages/lp/LandingPage" does not match the absolute id
         * rolldown actually sees. It fails silently — you get one chunk
         * and no error.
         *
         * The groups are split on how often they change:
         *   vendor-react   react + react-dom, upgrades only
         *   vendor-router  react-router, moves independently of React
         *   vendor-query   data layer
         *   vendor-icons   lucide, imported by 27 components
         *   vendor         everything else (axios today)
         * Each gets a stable hash, so a product deploy does not
         * invalidate the framework a returning visitor already has.
         *
         * Router is separated from React rather than bundled with it
         * for two reasons: it keeps every chunk under 200 KB raw, and
         * react-router ships breaking majors far more often than React
         * does — pinning them together would throw away a 180 KB cache
         * entry on a router bump.
         */
        manualChunks(id: string) {
          if (!id.includes("node_modules")) return undefined;
          if (/[\\/]node_modules[\\/]react-router/.test(id)) {
            return "vendor-router";
          }
          if (
            /[\\/]node_modules[\\/](react|react-dom|scheduler)[\\/]/.test(id)
          ) {
            return "vendor-react";
          }
          if (id.includes("@tanstack")) return "vendor-query";
          if (id.includes("lucide-react")) return "vendor-icons";
          return "vendor";
        },
      },
    },
    // Nothing should approach this once the split lands; leaving the
    // limit high enough to be quiet but low enough to still shout if a
    // chunk regresses.
    chunkSizeWarningLimit: 250,
  },
});
