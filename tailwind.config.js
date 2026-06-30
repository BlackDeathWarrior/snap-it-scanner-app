/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        brand: {
          DEFAULT: '#1565C0',
          50: '#e8f0fb',
          100: '#c5dbf5',
          400: '#3b82d6',
          500: '#1565C0',
          600: '#0f4f9c',
          700: '#0b3d78',
        },
        ink: {
          900: '#0b1220',
          800: '#111a2e',
          700: '#1b273f',
          600: '#27344f',
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'Segoe UI', 'Roboto', 'sans-serif'],
      },
    },
  },
  plugins: [],
};
