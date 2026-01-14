set -e

mkdir -p api web/src/pages web/src/lib

# ---------------- root package.json ----------------
cat > package.json <<'JSON'
{
  "name": "beauty-mvp",
  "private": true,
  "workspaces": ["api", "web"],
  "scripts": {
    "dev": "npm --workspace api run dev & npm --workspace web run dev",
    "dev:win": "npm --workspace api run dev | npm --workspace web run dev"
  }
}
JSON

# ---------------- API ----------------
cat > api/package.json <<'JSON'
{
  "name": "api",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "node server.js"
  },
  "dependencies": {
    "cors": "^2.8.5",
    "dotenv": "^16.4.5",
    "express": "^4.19.2",
    "lowdb": "^7.0.1",
    "nanoid": "^5.0.7"
  }
}
JSON

cat > api/.env.example <<'ENV'
PORT=4000
# TG_BOT_TOKEN=123456:ABCDEF...   # опционально (для Telegram initData verify)
ENV

cat > api/db.json <<'JSON'
{
  "masters": [],
  "services": [],
  "masterServices": [],
  "slots": [],
  "bookings": [],
  "reviews": []
}
JSON

cat > api/server.js <<'JS'
import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import crypto from "crypto";
import { nanoid } from "nanoid";
import { Low } from "lowdb";
import { JSONFile } from "lowdb/node";

dotenv.config();

const PORT = Number(process.env.PORT || 4000);
const TG_BOT_TOKEN = process.env.TG_BOT_TOKEN || "";

const app = express();
app.use(cors());
app.use(express.json());

const adapter = new JSONFile(new URL("./db.json", import.meta.url));
const db = new Low(adapter, {
  masters: [],
  services: [],
  masterServices: [],
  slots: [],
  bookings: [],
  reviews: []
});

function yyyyMmDd(d) {
  const x = new Date(d);
  const y = x.getFullYear();
  const m = String(x.getMonth() + 1).padStart(2, "0");
  const day = String(x.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

function addDays(date, days) {
  const d = new Date(date);
  d.setDate(d.getDate() + days);
  return d;
}

function seedIfEmpty() {
  if (db.data.services.length) return;

  const services = [
    { id: "svc_manicure", name: "Маникюр" },
    { id: "svc_pedicure", name: "Педикюр" },
    { id: "svc_haircut", name: "Стрижка" },
    { id: "svc_color", name: "Окрашивание" },
    { id: "svc_brows", name: "Брови/Ресницы" }
  ];

  const masters = [
    {
      id: "m_1",
      name: "Amina",
      district: "Чиланзар",
      address: "Чиланзар, ориентир: метро",
      bio: "Ногти без сколов. Опыт 5 лет.",
      avatar: "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=256&q=60",
      portfolio: [
        "https://images.unsplash.com/photo-1604654894610-df63bc536371?auto=format&fit=crop&w=900&q=60",
        "https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?auto=format&fit=crop&w=900&q=60"
      ]
    },
    {
      id: "m_2",
      name: "Sardor",
      district: "Юнусабад",
      address: "Юнусабад, рядом с парком",
      bio: "Барбер. Быстро и аккуратно.",
      avatar: "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=256&q=60",
      portfolio: [
        "https://images.unsplash.com/photo-1599351431202-1e0f0137899a?auto=format&fit=crop&w=900&q=60",
        "https://images.unsplash.com/photo-1585747860715-2ba37e788b70?auto=format&fit=crop&w=900&q=60"
      ]
    },
    {
      id: "m_3",
      name: "Dilnoza",
      district: "Мирзо-Улугбек",
      address: "М-Улугбек, возле ТЦ",
      bio: "Брови/ресницы + лёгкий макияж.",
      avatar: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=256&q=60",
      portfolio: [
        "https://images.unsplash.com/photo-1527799820374-dcf8c7d3fc7f?auto=format&fit=crop&w=900&q=60",
        "https://images.unsplash.com/photo-1526045478516-99145907023c?auto=format&fit=crop&w=900&q=60"
      ]
    }
  ];

  const masterServices = [
    { id: nanoid(), masterId: "m_1", serviceId: "svc_manicure", priceFrom: 120000, durationMin: 90 },
    { id: nanoid(), masterId: "m_1", serviceId: "svc_pedicure", priceFrom: 160000, durationMin: 90 },

    { id: nanoid(), masterId: "m_2", serviceId: "svc_haircut", priceFrom: 90000, durationMin: 45 },
    { id: nanoid(), masterId: "m_2", serviceId: "svc_color", priceFrom: 220000, durationMin: 120 },

    { id: nanoid(), masterId: "m_3", serviceId: "svc_brows", priceFrom: 110000, durationMin: 60 }
  ];

  // slots: на 10 дней вперёд, 4 слота в день на каждого мастера
  const slots = [];
  const times = ["10:00", "12:00", "14:00", "16:00"];
  const today = new Date();

  for (const m of masters) {
    for (let i = 0; i < 10; i++) {
      const date = yyyyMmDd(addDays(today, i));
      for (const t of times) {
        slots.push({
          id: nanoid(),
          masterId: m.id,
          date,
          time: t,
          isBooked: false
        });
      }
    }
  }

  db.data.services = services;
  db.data.masters = masters;
  db.data.masterServices = masterServices;
  db.data.slots = slots;
}

function getMasterPriceFrom(masterId, serviceId) {
  const ms = db.data.masterServices.find(x => x.masterId === masterId && x.serviceId === serviceId);
  return ms?.priceFrom ?? null;
}

function getNextAvailableSlot(masterId, fromDate) {
  const f = fromDate ? String(fromDate) : yyyyMmDd(new Date());
  const candidates = db.data.slots
    .filter(s => s.masterId === masterId && !s.isBooked)
    .sort((a, b) => (a.date + " " + a.time).localeCompare(b.date + " " + b.time));

  return candidates.find(s => s.date >= f) || null;
}

// Telegram initData validation (опционально)
function validateTelegramInitData(initData, botToken) {
  // initData выглядит как querystring: a=1&b=2&hash=...
  const params = new URLSearchParams(initData);
  const hash = params.get("hash");
  if (!hash) return { ok: false, error: "hash missing" };

  params.delete("hash");
  const dataCheckString = [...params.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([k, v]) => `${k}=${v}`)
    .join("\n");

  const secretKey = crypto.createHmac("sha256", "WebAppData").update(botToken).digest();
  const computedHash = crypto.createHmac("sha256", secretKey).update(dataCheckString).digest("hex");

  return computedHash === hash ? { ok: true, data: Object.fromEntries(params.entries()) } : { ok: false, error: "bad hash" };
}

await db.read();
seedIfEmpty();
await db.write();

app.get("/health", (req, res) => res.json({ ok: true }));

app.get("/services", async (req, res) => {
  await db.read();
  res.json(db.data.services);
});

app.get("/masters", async (req, res) => {
  await db.read();
  const { serviceId = "", district = "", date = "", q = "" } = req.query;

  let items = db.data.masters.slice();

  if (district) {
    items = items.filter(m => m.district.toLowerCase().includes(String(district).toLowerCase()));
  }
  if (q) {
    const qq = String(q).toLowerCase();
    items = items.filter(m => (m.name + " " + m.bio).toLowerCase().includes(qq));
  }
  if (serviceId) {
    const ids = new Set(db.data.masterServices.filter(ms => ms.serviceId === String(serviceId)).map(ms => ms.masterId));
    items = items.filter(m => ids.has(m.id));
  }

  const enriched = items.map(m => {
    const next = getNextAvailableSlot(m.id, date ? String(date) : "");
    const prices = db.data.masterServices
      .filter(ms => ms.masterId === m.id)
      .map(ms => ms.priceFrom)
      .sort((a, b) => a - b);

    return {
      ...m,
      priceFrom: prices.length ? prices[0] : null,
      nextSlot: next ? { date: next.date, time: next.time } : null
    };
  });

  res.json(enriched);
});

app.get("/masters/:id", async (req, res) => {
  await db.read();
  const m = db.data.masters.find(x => x.id === req.params.id);
  if (!m) return res.status(404).json({ error: "not found" });

  const services = db.data.masterServices
    .filter(ms => ms.masterId === m.id)
    .map(ms => ({
      service: db.data.services.find(s => s.id === ms.serviceId),
      priceFrom: ms.priceFrom,
      durationMin: ms.durationMin
    }))
    .filter(x => x.service);

  const reviews = db.data.reviews.filter(r => r.masterId === m.id);

  res.json({ ...m, services, reviews });
});

app.get("/masters/:id/slots", async (req, res) => {
  await db.read();
  const { date = "" } = req.query;
  const d = date ? String(date) : yyyyMmDd(new Date());

  const slots = db.data.slots
    .filter(s => s.masterId === req.params.id && s.date === d && !s.isBooked)
    .sort((a, b) => a.time.localeCompare(b.time));

  res.json({ date: d, slots });
});

app.post("/bookings", async (req, res) => {
  await db.read();
  const { masterId, serviceId, slotId, clientName, clientPhone } = req.body || {};

  if (!masterId || !serviceId || !slotId || !clientName || !clientPhone) {
    return res.status(400).json({ error: "missing fields" });
  }

  const slot = db.data.slots.find(s => s.id === slotId && s.masterId === masterId);
  if (!slot) return res.status(404).json({ error: "slot not found" });
  if (slot.isBooked) return res.status(409).json({ error: "slot already booked" });

  const priceFrom = getMasterPriceFrom(masterId, serviceId);
  if (priceFrom == null) return res.status(400).json({ error: "service not available for this master" });

  const booking = {
    id: nanoid(),
    masterId,
    serviceId,
    slotId,
    clientName: String(clientName),
    clientPhone: String(clientPhone),
    date: slot.date,
    time: slot.time,
    priceFrom,
    status: "confirmed",
    createdAt: new Date().toISOString()
  };

  slot.isBooked = true;
  db.data.bookings.push(booking);
  await db.write();

  res.json({ ok: true, booking });
});

app.get("/bookings", async (req, res) => {
  await db.read();
  const { phone = "" } = req.query;
  if (!phone) return res.json([]);

  const items = db.data.bookings
    .filter(b => b.clientPhone === String(phone))
    .sort((a, b) => (b.date + " " + b.time).localeCompare(a.date + " " + a.time))
    .map(b => {
      const master = db.data.masters.find(m => m.id === b.masterId);
      const service = db.data.services.find(s => s.id === b.serviceId);
      return { ...b, masterName: master?.name, serviceName: service?.name };
    });

  res.json(items);
});

app.post("/bookings/:id/cancel", async (req, res) => {
  await db.read();
  const b = db.data.bookings.find(x => x.id === req.params.id);
  if (!b) return res.status(404).json({ error: "not found" });
  if (b.status === "canceled") return res.json({ ok: true });

  b.status = "canceled";
  const slot = db.data.slots.find(s => s.id === b.slotId);
  if (slot) slot.isBooked = false;

  await db.write();
  res.json({ ok: true });
});

// Опционально: проверка Telegram initData (если задашь TG_BOT_TOKEN)
app.post("/telegram/verify", async (req, res) => {
  const { initData } = req.body || {};
  if (!TG_BOT_TOKEN) return res.status(501).json({ error: "TG_BOT_TOKEN not set" });
  if (!initData) return res.status(400).json({ error: "initData required" });

  const r = validateTelegramInitData(String(initData), TG_BOT_TOKEN);
  if (!r.ok) return res.status(401).json({ error: r.error });

  res.json({ ok: true, data: r.data });
});

app.listen(PORT, () => {
  console.log(`API running on http://localhost:${PORT}`);
});
JS

# ---------------- WEB (Vite React SPA) ----------------
cat > web/package.json <<'JSON'
{
  "name": "web",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite --port 5173",
    "build": "vite build",
    "preview": "vite preview --port 5173"
  },
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "react-router-dom": "^6.26.2"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.3.1",
    "vite": "^5.4.2"
  }
}
JSON

cat > web/vite.config.js <<'JS'
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()]
});
JS

cat > web/index.html <<'HTML'
<!doctype html>
<html lang="ru">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Beauty MVP</title>
    <script src="https://cdn.tailwindcss.com"></script>
  </head>
  <body class="bg-slate-950 text-slate-50">
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
HTML

cat > web/src/main.jsx <<'JSX'
import React from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import App from "./App.jsx";

createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <BrowserRouter>
      <App />
    </BrowserRouter>
  </React.StrictMode>
);
JSX

cat > web/src/lib/api.js <<'JS'
export const API_URL = import.meta.env.VITE_API_URL || "http://localhost:4000";

export async function apiGet(path) {
  const r = await fetch(API_URL + path);
  if (!r.ok) throw new Error(await r.text());
  return r.json();
}

export async function apiPost(path, body) {
  const r = await fetch(API_URL + path, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body || {})
  });
  if (!r.ok) throw new Error(await r.text());
  return r.json();
}
JS

cat > web/src/lib/telegram.js <<'JS'
export function tgUser() {
  const tg = window.Telegram?.WebApp;
  const user = tg?.initDataUnsafe?.user || null;
  return user;
}

export function tgInitData() {
  return window.Telegram?.WebApp?.initData || "";
}
JS

cat > web/src/App.jsx <<'JSX'
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
JSX

cat > web/src/pages/Home.jsx <<'JSX'
import React, { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { apiGet } from "../lib/api.js";

function today() {
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

export default function Home() {
  const [services, setServices] = useState([]);
  const [masters, setMasters] = useState([]);
  const [loading, setLoading] = useState(true);

  const [serviceId, setServiceId] = useState("");
  const [district, setDistrict] = useState("");
  const [date, setDate] = useState(today());
  const [q, setQ] = useState("");

  useEffect(() => {
    (async () => {
      const s = await apiGet("/services");
      setServices(s);
    })();
  }, []);

  async function load() {
    setLoading(true);
    try {
      const params = new URLSearchParams();
      if (serviceId) params.set("serviceId", serviceId);
      if (district) params.set("district", district);
      if (date) params.set("date", date);
      if (q) params.set("q", q);
      const data = await apiGet("/masters" + (params.toString() ? `?${params.toString()}` : ""));
      setMasters(data);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { load(); }, []); // initial

  const districtsHint = useMemo(() => ["Чиланзар", "Юнусабад", "Мирзо-Улугбек"], []);

  return (
    <div className="space-y-3">
      <div className="rounded-2xl border border-white/10 bg-white/5 p-3 space-y-2">
        <div className="text-sm font-semibold">Найти мастера</div>

        <div className="grid grid-cols-2 gap-2">
          <select
            value={serviceId}
            onChange={(e) => setServiceId(e.target.value)}
            className="w-full rounded-xl bg-slate-900/60 border border-white/10 px-3 py-2 text-sm"
          >
            <option value="">Все услуги</option>
            {services.map(s => <option key={s.id} value={s.id}>{s.name}</option>)}
          </select>

          <input
            value={district}
            onChange={(e) => setDistrict(e.target.value)}
            placeholder={"Район (например " + districtsHint[0] + ")"}
            className="w-full rounded-xl bg-slate-900/60 border border-white/10 px-3 py-2 text-sm"
          />
        </div>

        <div className="grid grid-cols-2 gap-2">
          <input
            type="date"
            value={date}
            onChange={(e) => setDate(e.target.value)}
            className="w-full rounded-xl bg-slate-900/60 border border-white/10 px-3 py-2 text-sm"
          />
          <input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Поиск по имени/описанию"
            className="w-full rounded-xl bg-slate-900/60 border border-white/10 px-3 py-2 text-sm"
          />
        </div>

        <button
          onClick={load}
          className="w-full rounded-xl bg-emerald-500 text-slate-950 font-semibold py-2 active:scale-[0.99]"
        >
          Показать
        </button>
      </div>

      <div className="space-y-2">
        {loading && (
          <div className="text-sm text-white/60">Загрузка...</div>
        )}

        {!loading && masters.length === 0 && (
          <div className="rounded-2xl border border-white/10 bg-white/5 p-3 text-sm text-white/70">
            Ничего не найдено. Попробуй убрать фильтры.
          </div>
        )}

        {masters.map(m => (
          <Link key={m.id} to={`/m/${m.id}`} className="block">
            <div className="rounded-2xl border border-white/10 bg-white/5 p-3 flex gap-3 hover:bg-white/[0.07]">
              <img src={m.avatar} alt="" className="h-14 w-14 rounded-2xl object-cover border border-white/10" />
              <div className="flex-1">
                <div className="flex items-start justify-between gap-2">
                  <div>
                    <div className="font-semibold">{m.name}</div>
                    <div className="text-xs text-white/60">{m.district} · {m.address}</div>
                  </div>
                  <div className="text-right">
                    <div className="text-xs text-white/60">от</div>
                    <div className="font-semibold">{m.priceFrom ? m.priceFrom.toLocaleString() : "—"} сум</div>
                  </div>
                </div>
                <div className="mt-2 text-xs text-white/70 line-clamp-2">{m.bio}</div>
                <div className="mt-2 text-xs text-emerald-300">
                  {m.nextSlot ? `Ближайшее: ${m.nextSlot.date} ${m.nextSlot.time}` : "Нет свободных слотов"}
                </div>
              </div>
            </div>
          </Link>
        ))}
      </div>
    </div>
  );
}
JSX

cat > web/src/pages/Master.jsx <<'JSX'
import React, { useEffect, useMemo, useState } from "react";
import { useParams, Link } from "react-router-dom";
import { apiGet, apiPost } from "../lib/api.js";

function today() {
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

export default function Master() {
  const { id } = useParams();
  const [m, setM] = useState(null);
  const [slots, setSlots] = useState([]);
  const [date, setDate] = useState(today());
  const [serviceId, setServiceId] = useState("");
  const [clientName, setClientName] = useState("");
  const [clientPhone, setClientPhone] = useState("");
  const [msg, setMsg] = useState("");

  const services = useMemo(() => m?.services || [], [m]);

  useEffect(() => {
    (async () => {
      const data = await apiGet(`/masters/${id}`);
      setM(data);
      const firstSvc = data.services?.[0]?.service?.id || "";
      setServiceId(firstSvc);
    })();
  }, [id]);

  async function loadSlots(d) {
    const data = await apiGet(`/masters/${id}/slots?date=${encodeURIComponent(d)}`);
    setSlots(data.slots || []);
  }

  useEffect(() => {
    if (!m) return;
    loadSlots(date);
  }, [m, date]);

  async function book(slotId) {
    setMsg("");
    try {
      if (!serviceId) return setMsg("Выбери услугу");
      if (!clientName.trim()) return setMsg("Укажи имя");
      if (!clientPhone.trim()) return setMsg("Укажи телефон");

      const r = await apiPost("/bookings", {
        masterId: id,
        serviceId,
        slotId,
        clientName,
        clientPhone
      });

      setMsg(`✅ Запись подтверждена: ${r.booking.date} ${r.booking.time}`);
      await loadSlots(date);
    } catch (e) {
      setMsg("Ошибка: " + (e?.message || e));
    }
  }

  if (!m) return <div className="text-sm text-white/60">Загрузка...</div>;

  return (
    <div className="space-y-3">
      <Link to="/" className="text-sm text-white/70 hover:text-white">← Назад</Link>

      <div className="rounded-2xl border border-white/10 bg-white/5 p-3">
        <div className="flex gap-3">
          <img src={m.avatar} alt="" className="h-16 w-16 rounded-2xl object-cover border border-white/10" />
          <div className="flex-1">
            <div className="text-lg font-semibold">{m.name}</div>
            <div className="text-xs text-white/60">{m.district} · {m.address}</div>
            <div className="mt-2 text-sm text-white/80">{m.bio}</div>
          </div>
        </div>

        <div className="mt-3 grid grid-cols-2 gap-2">
          {m.portfolio?.slice(0, 2)?.map((src, idx) => (
            <img key={idx} src={src} alt="" className="h-28 w-full rounded-2xl object-cover border border-white/10" />
          ))}
        </div>
      </div>

      <div className="rounded-2xl border border-white/10 bg-white/5 p-3 space-y-2">
        <div className="text-sm font-semibold">Запись</div>

        <select
          value={serviceId}
          onChange={(e) => setServiceId(e.target.value)}
          className="w-full rounded-xl bg-slate-900/60 border border-white/10 px-3 py-2 text-sm"
        >
          {services.map((x, idx) => (
            <option key={idx} value={x.service.id}>
              {x.service.name} · от {x.priceFrom.toLocaleString()} сум · {x.durationMin} мин
            </option>
          ))}
        </select>

        <div className="grid grid-cols-2 gap-2">
          <input
            type="date"
            value={date}
            onChange={(e) => setDate(e.target.value)}
            className="w-full rounded-xl bg-slate-900/60 border border-white/10 px-3 py-2 text-sm"
          />
          <input
            value={clientName}
            onChange={(e) => setClientName(e.target.value)}
            placeholder="Имя"
            className="w-full rounded-xl bg-slate-900/60 border border-white/10 px-3 py-2 text-sm"
          />
        </div>

        <input
          value={clientPhone}
          onChange={(e) => setClientPhone(e.target.value)}
          placeholder="Телефон (пример: +998901234567)"
          className="w-full rounded-xl bg-slate-900/60 border border-white/10 px-3 py-2 text-sm"
        />

        {msg && (
          <div className="rounded-xl border border-white/10 bg-black/20 p-2 text-sm">
            {msg}
          </div>
        )}

        <div className="pt-1">
          <div className="text-xs text-white/60 mb-2">Свободные слоты:</div>

          {slots.length === 0 ? (
            <div className="text-sm text-white/60">Нет свободных слотов на эту дату.</div>
          ) : (
            <div className="grid grid-cols-4 gap-2">
              {slots.map(s => (
                <button
                  key={s.id}
                  onClick={() => book(s.id)}
                  className="rounded-xl border border-white/10 bg-white/5 py-2 text-sm hover:bg-emerald-500 hover:text-slate-950 font-semibold"
                >
                  {s.time}
                </button>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
JSX

cat > web/src/pages/Bookings.jsx <<'JSX'
import React, { useState } from "react";
import { apiGet, apiPost } from "../lib/api.js";

export default function Bookings() {
  const [phone, setPhone] = useState("");
  const [items, setItems] = useState([]);
  const [msg, setMsg] = useState("");

  async function load() {
    setMsg("");
    try {
      const data = await apiGet(`/bookings?phone=${encodeURIComponent(phone)}`);
      setItems(data);
      if (!data.length) setMsg("Записей не найдено.");
    } catch (e) {
      setMsg("Ошибка: " + (e?.message || e));
    }
  }

  async function cancel(id) {
    setMsg("");
    try {
      await apiPost(`/bookings/${id}/cancel`);
      await load();
      setMsg("Запись отменена.");
    } catch (e) {
      setMsg("Ошибка: " + (e?.message || e));
    }
  }

  return (
    <div className="space-y-3">
      <div className="rounded-2xl border border-white/10 bg-white/5 p-3 space-y-2">
        <div className="text-sm font-semibold">Мои записи</div>
        <div className="flex gap-2">
          <input
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            placeholder="Телефон, как при записи"
            className="flex-1 rounded-xl bg-slate-900/60 border border-white/10 px-3 py-2 text-sm"
          />
          <button
            onClick={load}
            className="rounded-xl bg-emerald-500 text-slate-950 font-semibold px-4"
          >
            Найти
          </button>
        </div>
        {msg && <div className="text-sm text-white/70">{msg}</div>}
      </div>

      <div className="space-y-2">
        {items.map(b => (
          <div key={b.id} className="rounded-2xl border border-white/10 bg-white/5 p-3">
            <div className="flex items-start justify-between gap-2">
              <div>
                <div className="font-semibold">{b.masterName} · {b.serviceName}</div>
                <div className="text-xs text-white/60">{b.date} {b.time} · от {Number(b.priceFrom).toLocaleString()} сум</div>
                <div className="text-xs mt-1">
                  Статус:{" "}
                  <span className={b.status === "confirmed" ? "text-emerald-300" : "text-white/60"}>
                    {b.status}
                  </span>
                </div>
              </div>
              {b.status === "confirmed" && (
                <button
                  onClick={() => cancel(b.id)}
                  className="rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-sm hover:bg-white/10"
                >
                  Отменить
                </button>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
JSX

echo "DONE. Next:"
echo "  1) npm install"
echo "  2) npm run dev"
