module.exports = {
  content: ["./pages/**/*.{js,jsx}", "./components/**/*.{js,jsx}", "./lib/**/*.{js,jsx}"],
  theme: {
    extend: {
      colors: {
        ink: "#0e1216",
        accent: "#ff8a3d",
        accentSoft: "#4bb6ff"
      },
      boxShadow: {
        neo: "12px 12px 30px rgba(143, 157, 175, 0.45), -12px -12px 28px rgba(255, 255, 255, 0.9)",
        neoInset: "inset 4px 4px 12px rgba(160, 170, 185, 0.4), inset -4px -4px 12px rgba(255, 255, 255, 0.9)",
        glass: "0 24px 60px rgba(9, 15, 21, 0.18)",
        glow: "0 10px 24px rgba(255, 138, 61, 0.35)"
      }
    }
  },
  plugins: []
};