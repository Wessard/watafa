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
