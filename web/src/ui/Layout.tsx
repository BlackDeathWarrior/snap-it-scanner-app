import { NavLink, Outlet } from 'react-router-dom';
import { ScanIcon, HistoryIcon, SettingsIcon } from './icons';

const navItems = [
  { to: '/', label: 'Scan', icon: ScanIcon, end: true },
  { to: '/history', label: 'History', icon: HistoryIcon, end: false },
  { to: '/settings', label: 'Settings', icon: SettingsIcon, end: false },
];

export function Layout() {
  return (
    <div className="mx-auto flex min-h-full max-w-2xl flex-col px-4 pb-24 pt-5 sm:pb-6">
      <header className="mb-5 flex items-center gap-3">
        <div className="grid h-10 w-10 place-items-center rounded-xl bg-brand-500 shadow-lg shadow-brand-700/40">
          <ScanIcon className="h-6 w-6 text-white" />
        </div>
        <div>
          <h1 className="text-lg font-bold leading-tight">Snap-It Scanner</h1>
          <p className="text-xs text-slate-400">
            Barcodes · QR · product labels
          </p>
        </div>
        {/* Desktop / wide nav */}
        <nav className="ml-auto hidden gap-1 sm:flex">
          {navItems.map(({ to, label, icon: Icon, end }) => (
            <NavLink
              key={to}
              to={to}
              end={end}
              className={({ isActive }) =>
                `flex items-center gap-2 rounded-lg px-3 py-2 text-sm font-medium transition-colors ${
                  isActive
                    ? 'bg-white/10 text-white'
                    : 'text-slate-400 hover:text-slate-200'
                }`
              }
            >
              <Icon className="h-5 w-5" />
              {label}
            </NavLink>
          ))}
        </nav>
      </header>

      <main className="flex-1">
        <Outlet />
      </main>

      {/* Mobile bottom nav */}
      <nav className="fixed inset-x-0 bottom-0 z-20 border-t border-white/10 bg-ink-800/95 backdrop-blur sm:hidden">
        <div className="mx-auto flex max-w-2xl">
          {navItems.map(({ to, label, icon: Icon, end }) => (
            <NavLink
              key={to}
              to={to}
              end={end}
              className={({ isActive }) =>
                `flex flex-1 flex-col items-center gap-1 py-2.5 text-xs font-medium transition-colors ${
                  isActive ? 'text-brand-400' : 'text-slate-400'
                }`
              }
            >
              <Icon className="h-6 w-6" />
              {label}
            </NavLink>
          ))}
        </div>
      </nav>
    </div>
  );
}
