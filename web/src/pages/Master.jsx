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
