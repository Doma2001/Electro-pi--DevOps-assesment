const apiBase = (window.APP_CONFIG?.API_BASE_URL || "http://localhost:8000").replace(/\/$/, "");
const statusEl = document.getElementById("status");
const itemsEl = document.getElementById("items");
const form = document.getElementById("item-form");
const input = document.getElementById("name");

async function loadHealth() {
  try {
    const res = await fetch(`${apiBase}/api/health`);
    if (!res.ok) throw new Error("health check failed");
    statusEl.textContent = "API: healthy";
  } catch (err) {
    statusEl.textContent = "API: unavailable";
  }
}

async function loadItems() {
  const res = await fetch(`${apiBase}/api/items`);
  if (!res.ok) throw new Error("could not load items");
  const items = await res.json();
  itemsEl.innerHTML = items.map((item) => `<li>${item.name}</li>`).join("");
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  const name = input.value.trim();
  if (!name) return;
  await fetch(`${apiBase}/api/items`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name })
  });
  input.value = "";
  await loadItems();
});

loadHealth();
loadItems().catch(() => {});
