import type { NextConfig } from "next";

const isIpfs = process.env.NEXT_PUBLIC_IPFS_BUILD === "true";

const nextConfig: NextConfig = {
  reactStrictMode: true,
  devIndicators: false,

  typescript: {
    ignoreBuildErrors: true,
  },

  eslint: {
    ignoreDuringBuilds: false,
  },

  webpack: config => {
    config.resolve.fallback = { fs: false, net: false, tls: false };
    config.externals.push("pino-pretty", "lokijs", "encoding");
    return config;
  },

  // 👇 CLAVE: standalone solo cuando NO es IPFS
  ...(isIpfs
    ? {
        output: "export",
        trailingSlash: true,
        images: {
          unoptimized: true,
        },
      }
    : {
        output: "standalone",
      }),
};

module.exports = nextConfig;
