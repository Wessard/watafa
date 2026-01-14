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
