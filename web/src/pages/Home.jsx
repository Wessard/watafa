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
