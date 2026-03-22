import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  reactCompiler: true,

  // ── HTTP Cache Headers ──────────────────────────────────────
  async headers() {
    return [
      // Service Worker — NEVER cache so updates deploy instantly
      {
        source: "/sw.js",
        headers: [
          { key: "Cache-Control", value: "no-cache, no-store, must-revalidate" },
          { key: "Service-Worker-Allowed", value: "/" },
        ],
      },
      // Next.js static assets — content-hashed, cache forever
      {
        source: "/_next/static/:path*",
        headers: [
          { key: "Cache-Control", value: "public, max-age=31536000, immutable" },
        ],
      },
      // App icons & static images — long cache
      {
        source: "/icons/:path*",
        headers: [
          { key: "Cache-Control", value: "public, max-age=31536000, immutable" },
        ],
      },
      // API routes — never cache
      {
        source: "/api/:path*",
        headers: [
          { key: "Cache-Control", value: "no-store, must-revalidate" },
          { key: "Access-Control-Allow-Origin", value: "*" },
          {
            key: "Access-Control-Allow-Methods",
            value: "GET, POST, PUT, DELETE, OPTIONS",
          },
          {
            key: "Access-Control-Allow-Headers",
            value: "Content-Type, Authorization",
          },
        ],
      },
      // All pages — security headers + short cache for HTML
      {
        source: "/:path*",
        headers: [
          // Revalidate HTML on every request (cache busting for deploys)
          {
            key: "Cache-Control",
            value: "public, max-age=0, must-revalidate",
          },
          // Security headers
          { key: "X-DNS-Prefetch-Control", value: "on" },
          { key: "X-Frame-Options", value: "SAMEORIGIN" },
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "Referrer-Policy", value: "origin-when-cross-origin" },
          {
            key: "Strict-Transport-Security",
            value: "max-age=31536000; includeSubDomains",
          },
          { key: "X-XSS-Protection", value: "1; mode=block" },
          {
            key: "Permissions-Policy",
            value: "camera=(self), microphone=(self), geolocation=()",
          },
        ],
      },
    ];
  },
};

export default nextConfig;

