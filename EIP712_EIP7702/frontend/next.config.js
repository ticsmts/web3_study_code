/** @type {import('next').NextConfig} */
const nextConfig = {
    // Turbopack configuration (Next.js 16+)
    turbopack: {},

    // Webpack configuration (fallback)
    webpack: (config) => {
        config.externals.push('pino-pretty', 'lokijs', 'encoding');
        return config;
    },
};

export default nextConfig;
