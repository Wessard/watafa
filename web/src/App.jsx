import React from "react";
import { NavLink, Route, Routes } from "react-router-dom";
import Home from "./pages/Home.jsx";
import Master from "./pages/Master.jsx";
import Bookings from "./pages/Bookings.jsx";
import { tgUser } from "./lib/telegram.js";

function cn({ isActive }) {
  return isActive
    ? "px-3 py-2 rounded-xl bg-white/10"
    : "px-3 py-2 rounded-xl hover:bg-white/5";
}

export default function App() {
  const user = tgUser();

  return (
    <div className="min-h-dvh">
      <header className="sticky top-0 z-10 border-b border-white/10 bg-slate-950/80 backdrop-blur">
        <div className="mx-auto max-w-md px-4 py-3 flex items-center justify-between gap-3">
          <div className="flex flex-col">
            <div className="text-lg font-semibold">Beauty MVP</div>
            <div className="text-xs text-white/60">
              {user ? `Telegram: ${user.first_name}` : "Demo mode (без Telegram)"}
            </div>
          </div>
          <nav className="flex items-center gap-2 text-sm">
            <NavLink to="/" className={cn}>Поиск</NavLink>
            <NavLink to="/bookings" className={cn}>Мои записи</NavLink>
          </nav>
        </div>
      </header>

      <main className="mx-auto max-w-md px-4 py-4">
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/m/:id" element={<Master />} />
          <Route path="/bookings" element={<Bookings />} />
        </Routes>
      </main>

      <footer className="mx-auto max-w-md px-4 pb-6 pt-2 text-xs text-white/50">
        API: http://localhost:4000 · Web: http://localhost:5173
      </footer>
    </div>
  );
}
