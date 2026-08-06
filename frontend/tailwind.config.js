/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      colors: {
        // Accord brand. Green carries "approved / covered / verified",
        // amber carries "needs a human". Nothing in the product uses
        // red for a denial — a denial is an answer, not an error, and
        // the appeal path starts there.
        "accord-green": {
          50: "#E8F5E9",
          100: "#C8E6C9",
          500: "#4CAF50",
          700: "#388E3C",
          900: "#1B5E20",
        },
        "accord-amber": {
          50: "#FFF9C4",
          900: "#5D4037",
        },
      },
    },
  },
  plugins: [],
};
