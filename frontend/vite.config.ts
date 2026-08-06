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
});
