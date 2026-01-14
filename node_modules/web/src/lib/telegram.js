export function tgUser() {
  const tg = window.Telegram?.WebApp;
  const user = tg?.initDataUnsafe?.user || null;
  return user;
}

export function tgInitData() {
  return window.Telegram?.WebApp?.initData || "";
}
