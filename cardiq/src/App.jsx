import { useState, useRef, useEffect, useMemo } from "react";
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from "recharts";
import {
  onAuthStateChanged,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signOut
} from "firebase/auth";
import {
  collection,
  addDoc,
  doc,
  deleteDoc,
  onSnapshot,
  query,
  orderBy
} from "firebase/firestore";
import { auth, db } from "./firebase";

// Simulated portfolio history (fallback if Firestore history tracking isn't set up yet)
const HISTORY = [
  { month: "Jan '24", value: 3200 },
  { month: "Feb '24", value: 3650 },
  { month: "Mar '24", value: 3900 },
  { month: "Apr '24", value: 3700 },
  { month: "May '24", value: 4100 },
  { month: "Jun '24", value: 4400 },
  { month: "Jul '24", value: 4250 },
  { month: "Aug '24", value: 4600 },
  { month: "Sep '24", value: 4810 },
  { month: "Oct '24", value: 5100 },
  { month: "Nov '24", value: 4900 },
  { month: "Dec '24", value: 4810 },
];

const TABS = ["Portfolio", "History", "Watchlist", "Grading", "Advisor", "Market"];

const fmt = (n) => `$${Number(n).toLocaleString("en-US", { minimumFractionDigits: 0 })}`;
const gainColor = (n) => (n >= 0 ? "#22c55e" : "#ef4444");
const S = { // shared inline style tokens
  card: { background: "#111118", border: "1px solid #1e1e2e", borderRadius: 10, padding: "16px 18px" },
  label: { fontSize: 11, color: "#6b6b8a", fontWeight: 600, textTransform: "uppercase", letterSpacing: "0.1em", marginBottom: 6 },
  input: { background: "#0d0d18", border: "1px solid #2a2a3e", borderRadius: 8, padding: "10px 14px", color: "#e8e4d9", fontSize: 14, outline: "none", width: "100%" },
  gold: "#c9a84c",
  bg: "#0a0a0f",
  text: "#e8e4d9",
  muted: "#6b6b8a",
};

// ── Secure Client-Side ChatGPT integration ────────────────────────────────────
const callChatGPT = async (messages, system) => {
  const apiKey = import.meta.env.VITE_OPENAI_API_KEY;
  if (!apiKey || apiKey.includes("YOUR_OPENAI_API_KEY")) {
    return "Please configure VITE_OPENAI_API_KEY in your .env file to enable the AI advisor.";
  }
  try {
    const res = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${apiKey}`
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        max_tokens: 800,
        messages: [
          { role: "system", content: system },
          ...messages
        ]
      }),
    });
    const data = await res.json();
    return data.choices?.[0]?.message?.content || "No response received.";
  } catch (err) {
    return `AI Error: ${err.message}`;
  }
};

// ── Custom Tooltip for chart ───────────────────────────────────────────────
const ChartTooltip = ({ active, payload, label }) => {
  if (!active || !payload?.length) return null;
  return (
    <div style={{ background: "#1a1a28", border: "1px solid #2a2a3e", borderRadius: 8, padding: "8px 14px", fontSize: 13 }}>
      <div style={{ color: S.muted, marginBottom: 2 }}>{label}</div>
      <div style={{ color: S.gold, fontWeight: 700 }}>{fmt(payload[0].value)}</div>
    </div>
  );
};

// ── Grading ROI Calculator ─────────────────────────────────────────────────
function GradingTab() {
  const [form, setForm] = useState({ player: "", rawValue: "", psa10Est: "", psa9Est: "", gradingCost: "50", tier: "Value" });
  const [aiAnalysis, setAiAnalysis] = useState("");
  const [loading, setLoading] = useState(false);

  const set = (k, v) => setForm((f) => ({ ...f, [k]: v }));

  const rawN = parseFloat(form.rawValue) || 0;
  const p10 = parseFloat(form.psa10Est) || 0;
  const p9 = parseFloat(form.psa9Est) || 0;
  const cost = parseFloat(form.gradingCost) || 50;

  const roi10 = rawN > 0 ? (((p10 - rawN - cost) / (rawN + cost)) * 100).toFixed(1) : null;
  const roi9 = rawN > 0 ? (((p9 - rawN - cost) / (rawN + cost)) * 100).toFixed(1) : null;
  const breakeven10 = rawN + cost;
  const verdict = roi10 !== null ? (parseFloat(roi10) > 30 ? "Submit" : parseFloat(roi10) > 0 ? "Maybe" : "Skip") : null;
  const verdictColor = verdict === "Submit" ? "#22c55e" : verdict === "Maybe" ? "#f59e0b" : "#ef4444";

  const getAIAnalysis = async () => {
    if (!form.player || !rawN) return;
    setLoading(true);
    setAiAnalysis("");
    const system = `You are a sports card grading expert. Analyze whether it's worth submitting a card for PSA grading. Consider: pop report density, centering risk, surface issues common to that set, whether the grade premium justifies cost. Be direct and specific. Under 180 words.`;
    const res = await callChatGPT([{ role: "user", content: `Should I submit this card for PSA grading?\nCard: ${form.player}\nRaw value: $${rawN}\nPSA 10 est: $${p10}\nPSA 9 est: $${p9}\nGrading cost: $${cost}\nTier: ${form.tier}` }], system);
    setAiAnalysis(res);
    setLoading(false);
  };

  return (
    <div>
      <div style={S.label}>Grading ROI Calculator</div>
      <div style={{ fontSize: 13, color: S.muted, marginBottom: 20 }}>Find out if submitting to PSA/BGS is worth it before you pay.</div>

      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12, marginBottom: 16 }}>
        {[
          { k: "player", label: "Player / Card", ph: "e.g. 2023 Wembanyama Prizm" },
          { k: "rawValue", label: "Raw (Ungraded) Value ($)", ph: "e.g. 300" },
          { k: "psa10Est", label: "PSA 10 Market Value ($)", ph: "e.g. 1200" },
          { k: "psa9Est", label: "PSA 9 Market Value ($)", ph: "e.g. 500" },
        ].map((f) => (
          <div key={f.k}>
            <div style={{ ...S.label, marginBottom: 6 }}>{f.label}</div>
            <input value={form[f.k]} onChange={(e) => set(f.k, e.target.value)} placeholder={f.ph} style={S.input} />
          </div>
        ))}

        <div>
          <div style={{ ...S.label, marginBottom: 6 }}>Grading Tier</div>
          <select value={form.tier} onChange={(e) => set("tier", e.target.value)} style={{ ...S.input }}>
            {[["Value", "$18–22"], ["Economy", "$50"], ["Regular", "$100"], ["Express", "$150"], ["Super Express", "$300"]].map(([t, p]) => (
              <option key={t} value={t}>{t} ({p})</option>
            ))}
          </select>
        </div>
        <div>
          <div style={{ ...S.label, marginBottom: 6 }}>Grading Cost ($)</div>
          <input value={form.gradingCost} onChange={(e) => set("gradingCost", e.target.value)} placeholder="50" style={S.input} />
        </div>
      </div>

      {verdict && (
        <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 10, marginBottom: 20 }}>
          {[
            { label: "Verdict", value: verdict, color: verdictColor },
            { label: "ROI if PSA 10", value: `${roi10}%`, color: gainColor(parseFloat(roi10)) },
            { label: "ROI if PSA 9", value: `${roi9}%`, color: gainColor(parseFloat(roi9)) },
            { label: "Breakeven Price", value: fmt(breakeven10), color: S.text },
          ].map((s) => (
            <div key={s.label} style={{ ...S.card, textAlign: "center" }}>
              <div style={{ ...S.label, marginBottom: 8 }}>{s.label}</div>
              <div style={{ fontSize: 20, fontWeight: 800, color: s.color }}>{s.value}</div>
            </div>
          ))}
        </div>
      )}

      <button onClick={getAIAnalysis} disabled={loading || !form.player} style={{ background: S.gold, color: S.bg, border: "none", borderRadius: 8, padding: "11px 22px", fontWeight: 800, fontSize: 14, cursor: "pointer", opacity: loading || !form.player ? 0.5 : 1, marginBottom: 16 }}>
        {loading ? "Analyzing…" : "Get AI Grading Advice"}
      </button>

      {aiAnalysis && (
        <div style={{ ...S.card, borderColor: "#c9a84c33" }}>
          <div style={{ ...S.label, color: S.gold, marginBottom: 10 }}>AI Grading Advisor</div>
          <div style={{ fontSize: 14, lineHeight: 1.75, color: "#c8c4b8" }}>{aiAnalysis}</div>
        </div>
      )}
    </div>
  );
}

// ── Watchlist Tab ──────────────────────────────────────────────────────────
function WatchlistTab({ user }) {
  const [items, setItems] = useState([]);
  const [showAdd, setShowAdd] = useState(false);
  const [newItem, setNewItem] = useState({ player: "", year: "", set: "", grade: "", sport: "Basketball", targetBuy: "", currentEst: "" });
  const [ebayQuery, setEbayQuery] = useState("");
  const [ebayResult, setEbayResult] = useState("");
  const [ebayLoading, setEbayLoading] = useState(false);

  useEffect(() => {
    if (!user) return;
    const q = query(collection(db, `users/${user.uid}/watchlists`), orderBy("addedAt", "desc"));
    const unsubscribe = onSnapshot(q, (snapshot) => {
      setItems(snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() })));
    });
    return unsubscribe;
  }, [user]);

  const setField = (k, v) => setNewItem((n) => ({ ...n, [k]: v }));

  const addItem = async () => {
    if (!newItem.player) return;
    try {
      await addDoc(collection(db, `users/${user.uid}/watchlists`), {
        ...newItem,
        targetBuy: parseFloat(newItem.targetBuy) || 0,
        currentEst: parseFloat(newItem.currentEst) || 0,
        alert: false,
        addedAt: new Date().toISOString()
      });
      setNewItem({ player: "", year: "", set: "", grade: "", sport: "Basketball", targetBuy: "", currentEst: "" });
      setShowAdd(false);
    } catch (e) {
      console.error(e);
    }
  };

  const removeItem = async (id) => {
    try {
      await deleteDoc(doc(db, `users/${user.uid}/watchlists`, id));
    } catch (e) {
      console.error(e);
    }
  };

  const fetchEbayPrices = async () => {
    if (!ebayQuery.trim() || ebayLoading) return;
    setEbayLoading(true);
    setEbayResult("");
    const system = `You are a sports card pricing expert simulating eBay sold listing data. Based on your knowledge of the market, provide realistic recent sold prices for the card queried. Format as: 3–5 recent "sold" prices with dates, a 30-day average, and a trend note. Be specific and realistic. Under 150 words.`;
    const res = await callChatGPT([{ role: "user", content: `Simulate recent eBay sold listings for: ${ebayQuery}` }], system);
    setEbayResult(res);
    setEbayLoading(false);
  };

  return (
    <div>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 16 }}>
        <div>
          <div style={S.label}>Watchlist</div>
          <div style={{ fontSize: 13, color: S.muted }}>Cards you're watching to buy. Set target prices and track vs. market.</div>
        </div>
        <button onClick={() => setShowAdd(!showAdd)} style={{ background: S.gold, color: S.bg, border: "none", borderRadius: 6, padding: "8px 16px", fontSize: 12, fontWeight: 700, cursor: "pointer" }}>+ Watch Card</button>
      </div>

      {showAdd && (
        <div style={{ ...S.card, borderColor: "#c9a84c33", marginBottom: 14 }}>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
            {[
              { k: "player", ph: "Player" }, { k: "year", ph: "Year" },
              { k: "set", ph: "Set / Product" }, { k: "grade", ph: "Grade" },
              { k: "targetBuy", ph: "Target Buy Price ($)" }, { k: "currentEst", ph: "Current Est. Value ($)" },
            ].map((f) => (
              <input key={f.k} value={newItem[f.k]} onChange={(e) => setField(f.k, e.target.value)} placeholder={f.ph} style={S.input} />
            ))}
          </div>
          <div style={{ display: "flex", gap: 8, marginTop: 12 }}>
            <button onClick={addItem} style={{ background: S.gold, color: S.bg, border: "none", borderRadius: 6, padding: "8px 18px", fontSize: 13, fontWeight: 700, cursor: "pointer" }}>Add to Watchlist</button>
            <button onClick={() => setShowAdd(false)} style={{ background: "none", color: S.muted, border: "1px solid #2a2a3e", borderRadius: 6, padding: "8px 18px", fontSize: 13, cursor: "pointer" }}>Cancel</button>
          </div>
        </div>
      )}

      <div style={{ display: "flex", flexDirection: "column", gap: 10, marginBottom: 28 }}>
        {items.map((item) => {
          const diff = item.currentEst - item.targetBuy;
          const pct = item.targetBuy > 0 ? ((diff / item.targetBuy) * 100).toFixed(0) : 0;
          const atTarget = diff <= 0;
          return (
            <div key={item.id} style={{ ...S.card, display: "flex", justifyContent: "space-between", alignItems: "center" }}>
              <div>
                <div style={{ fontWeight: 700, fontSize: 15, color: S.text, display: "flex", alignItems: "center", gap: 8 }}>
                  {item.year} {item.player}
                  {atTarget && <span style={{ fontSize: 10, fontWeight: 700, background: "#22c55e22", color: "#22c55e", borderRadius: 4, padding: "2px 7px", letterSpacing: "0.06em" }}>BUY ZONE</span>}
                </div>
                <div style={{ fontSize: 12, color: S.muted, marginTop: 3 }}>{item.set} · {item.grade} · {item.sport}</div>
                <div style={{ fontSize: 12, color: S.muted, marginTop: 2 }}>Target: <span style={{ color: S.gold }}>{fmt(item.targetBuy)}</span></div>
              </div>
              <div style={{ textAlign: "right", display: "flex", alignItems: "center", gap: 16 }}>
                <div>
                  <div style={{ fontSize: 16, fontWeight: 800, color: S.text }}>{fmt(item.currentEst)}</div>
                  <div style={{ fontSize: 12, fontWeight: 600, color: gainColor(-diff) }}>{diff > 0 ? "+" : ""}{pct}% vs target</div>
                </div>
                <button onClick={() => removeItem(item.id)} style={{ background: "none", border: "none", color: "#3a3a5e", cursor: "pointer", fontSize: 18 }}>×</button>
              </div>
            </div>
          );
        })}
        {items.length === 0 && (
          <div style={{ border: "1px dashed #2a2a3e", borderRadius: 10, padding: 32, textAlign: "center", color: "#3a3a5e", fontSize: 13 }}>No cards on watchlist yet.</div>
        )}
      </div>

      {/* eBay Price Lookup */}
      <div style={{ borderTop: "1px solid #1e1e2e", paddingTop: 24 }}>
        <div style={{ ...S.label, marginBottom: 4 }}>eBay Price Lookup</div>
        <div style={{ fontSize: 13, color: S.muted, marginBottom: 12 }}>Get AI-estimated recent sold prices based on market data.</div>
        <div style={{ display: "flex", gap: 10, marginBottom: 14 }}>
          <input value={ebayQuery} onChange={(e) => setEbayQuery(e.target.value)} onKeyDown={(e) => e.key === "Enter" && fetchEbayPrices()} placeholder="e.g. 2021 Panini Prizm Josh Allen PSA 10" style={{ ...S.input }} />
          <button onClick={fetchEbayPrices} disabled={ebayLoading} style={{ background: S.gold, color: S.bg, border: "none", borderRadius: 8, padding: "10px 20px", fontWeight: 800, fontSize: 14, cursor: "pointer", whiteSpace: "nowrap", opacity: ebayLoading ? 0.5 : 1 }}>
            {ebayLoading ? "…" : "Look Up"}
          </button>
        </div>
        {ebayResult && (
          <div style={{ ...S.card, borderColor: "#c9a84c33" }}>
            <div style={{ ...S.label, color: S.gold, marginBottom: 10 }}>Recent Sales: {ebayQuery}</div>
            <div style={{ fontSize: 14, lineHeight: 1.8, color: "#c8c4b8", whiteSpace: "pre-wrap" }}>{ebayResult}</div>
          </div>
        )}
      </div>
    </div>
  );
}

// ── History Tab ────────────────────────────────────────────────────────────
function HistoryTab({ cards }) {
  const totalValue = cards.reduce((s, c) => s + c.currentValue, 0);
  const totalCost = cards.reduce((s, c) => s + c.purchasePrice, 0);

  // Append today to history
  const data = [...HISTORY, { month: "Today", value: totalValue }];
  const start = data[0].value;
  const end = data[data.length - 1].value;
  const overallGain = end - start;
  const overallPct = start > 0 ? ((overallGain / start) * 100).toFixed(1) : 0;
  const best = data.reduce((a, b) => (b.value > a.value ? b : a));
  const worst = data.reduce((a, b) => (b.value < a.value ? b : a));

  return (
    <div>
      <div style={S.label}>Portfolio History</div>

      <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 10, marginBottom: 24 }}>
        {[
          { label: "Starting Value", value: fmt(start), sub: "Jan 2024" },
          { label: "Current Value", value: fmt(end), sub: "Today" },
          { label: "All-Time Gain", value: `${overallGain >= 0 ? "+" : ""}${fmt(overallGain)}`, sub: `${overallPct}%`, color: gainColor(overallGain) },
          { label: "Total Invested", value: fmt(totalCost), sub: "cost basis" },
        ].map((s) => (
          <div key={s.label} style={S.card}>
            <div style={S.label}>{s.label}</div>
            <div style={{ fontSize: 18, fontWeight: 800, color: s.color || S.text }}>{s.value}</div>
            <div style={{ fontSize: 11, color: S.muted, marginTop: 2 }}>{s.sub}</div>
          </div>
        ))}
      </div>

      <div style={{ ...S.card, marginBottom: 20 }}>
        <div style={{ ...S.label, marginBottom: 16 }}>Portfolio Value Over Time</div>
        <ResponsiveContainer width="100%" height={240}>
          <LineChart data={data} margin={{ top: 4, right: 8, left: 0, bottom: 0 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#1e1e2e" />
            <XAxis dataKey="month" tick={{ fill: "#6b6b8a", fontSize: 11 }} axisLine={false} tickLine={false} />
            <YAxis tick={{ fill: "#6b6b8a", fontSize: 11 }} axisLine={false} tickLine={false} tickFormatter={(v) => `$${(v / 1000).toFixed(1)}k`} />
            <Tooltip content={<ChartTooltip />} />
            <Line type="monotone" dataKey="value" stroke="#c9a84c" strokeWidth={2.5} dot={false} activeDot={{ r: 5, fill: "#c9a84c", stroke: "#0a0a0f", strokeWidth: 2 }} />
          </LineChart>
        </ResponsiveContainer>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
        <div style={S.card}>
          <div style={{ ...S.label, marginBottom: 8 }}>Peak Value</div>
          <div style={{ fontSize: 22, fontWeight: 800, color: "#22c55e" }}>{fmt(best.value)}</div>
          <div style={{ fontSize: 12, color: S.muted }}>{best.month}</div>
        </div>
        <div style={S.card}>
          <div style={{ ...S.label, marginBottom: 8 }}>Monthly Low</div>
          <div style={{ fontSize: 22, fontWeight: 800, color: "#ef4444" }}>{fmt(worst.value)}</div>
          <div style={{ fontSize: 12, color: S.muted }}>{worst.month}</div>
        </div>
      </div>
    </div>
  );
}

// ── Main App ───────────────────────────────────────────────────────────────
export default function App() {
  const [user, setUser] = useState(null);
  const [authLoading, setAuthLoading] = useState(true);
  const [isSignUp, setIsSignUp] = useState(false);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [authError, setAuthError] = useState("");

  const [tab, setTab] = useState("Portfolio");
  const [cards, setCards] = useState([]);
  const [chatMessages, setChatMessages] = useState([
    { role: "assistant", content: "Hey! I'm your CardIQ financial advisor. I know your full portfolio — ask me anything about valuations, buy/sell signals, grading strategy, or market trends." },
  ]);
  const [chatInput, setChatInput] = useState("");
  const [chatLoading, setChatLoading] = useState(false);
  const [showAddCard, setShowAddCard] = useState(false);
  const [newCard, setNewCard] = useState({ player: "", year: "", set: "", grade: "", sport: "Basketball", purchasePrice: "", currentValue: "" });
  const [marketQuery, setMarketQuery] = useState("");
  const [marketResult, setMarketResult] = useState("");
  const [marketLoading, setMarketLoading] = useState(false);
  const chatEndRef = useRef(null);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (u) => {
      setUser(u);
      setAuthLoading(false);
    });
    return unsubscribe;
  }, []);

  useEffect(() => {
    if (!user) return;
    const q = query(collection(db, `users/${user.uid}/portfolios`), orderBy("addedAt", "desc"));
    const unsubscribe = onSnapshot(q, (snapshot) => {
      setCards(snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() })));
    });
    return unsubscribe;
  }, [user]);

  useEffect(() => { chatEndRef.current?.scrollIntoView({ behavior: "smooth" }); }, [chatMessages]);

  const totalCost = cards.reduce((s, c) => s + c.purchasePrice, 0);
  const totalValue = cards.reduce((s, c) => s + c.currentValue, 0);
  const totalGain = totalValue - totalCost;
  const totalGainPct = totalCost > 0 ? ((totalGain / totalCost) * 100).toFixed(1) : 0;

  const handleAuth = async (e) => {
    e.preventDefault();
    setAuthError("");
    try {
      if (isSignUp) {
        await createUserWithEmailAndPassword(auth, email, password);
      } else {
        await signInWithEmailAndPassword(auth, email, password);
      }
    } catch (err) {
      setAuthError(err.message.replace("Firebase: ", ""));
    }
  };

  const handleLogout = () => signOut(auth);

  const sendChat = async () => {
    if (!chatInput.trim() || chatLoading) return;
    const userMsg = { role: "user", content: chatInput };
    const newHistory = [...chatMessages, userMsg];
    setChatMessages(newHistory);
    setChatInput("");
    setChatLoading(true);
    const ctx = cards.map((c) => `${c.year} ${c.player} (${c.set}, ${c.grade}) — bought ${fmt(c.purchasePrice)}, now ${fmt(c.currentValue)}`).join("\n");
    const system = `You are an expert sports card financial advisor with deep knowledge of PSA/BGS grading, Panini, Topps, Upper Deck, rookie card investing, pop reports, auction results, and market trends.\n\nUser portfolio:\n${ctx}\nTotal invested: ${fmt(totalCost)} | Current value: ${fmt(totalValue)} | Return: ${totalGainPct}%\n\nGive concise, confident, actionable advice. Use dollar figures. Be honest about risks. Speak like a knowledgeable collector friend. Under 200 words.`;
    const reply = await callChatGPT(newHistory.map((m) => ({ role: m.role, content: m.content })), system);
    setChatMessages([...newHistory, { role: "assistant", content: reply }]);
    setChatLoading(false);
  };

  const runMarketAnalysis = async () => {
    if (!marketQuery.trim() || marketLoading) return;
    setMarketLoading(true);
    setMarketResult("");
    const system = `You are a sports card market analyst. Give detailed analysis: current price ranges, trend direction, key value drivers, PSA 9 vs 10 grade premium spread, and a clear BUY / HOLD / SELL recommendation with reasoning. Be specific with numbers. Under 250 words.`;
    const result = await callChatGPT([{ role: "user", content: `Analyze the sports card market for: ${marketQuery}` }], system);
    setMarketResult(result);
    setMarketLoading(false);
  };

  const addCard = async () => {
    if (!newCard.player || !newCard.purchasePrice || !newCard.currentValue) return;
    try {
      await addDoc(collection(db, `users/${user.uid}/portfolios`), {
        ...newCard,
        year: parseInt(newCard.year) || new Date().getFullYear(),
        purchasePrice: parseFloat(newCard.purchasePrice),
        currentValue: parseFloat(newCard.currentValue),
        addedAt: new Date().toISOString()
      });
      setNewCard({ player: "", year: "", set: "", grade: "", sport: "Basketball", purchasePrice: "", currentValue: "" });
      setShowAddCard(false);
    } catch (e) {
      console.error(e);
    }
  };

  const removeCard = async (id) => {
    try {
      await deleteDoc(doc(db, `users/${user.uid}/portfolios`, id));
    } catch (e) {
      console.error(e);
    }
  };

  if (authLoading) {
    return (
      <div style={{ height: "100vh", display: "flex", justifyContent: "center", alignItems: "center", background: S.bg, color: S.text }}>
        <div style={{ fontSize: 16, color: S.gold, fontWeight: 700 }}>CardIQ Loading...</div>
      </div>
    );
  }

  if (!user) {
    return (
      <div style={{ height: "100vh", display: "flex", justifyContent: "center", alignItems: "center", background: S.bg, fontFamily: "'Inter', sans-serif" }}>
        <div style={{ ...S.card, width: 380, padding: 30, background: "linear-gradient(145deg, #111118, #0a0a0f)", border: "1px solid #2a2a3e" }}>
          <div style={{ textAlign: "center", marginBottom: 24 }}>
            <span style={{ fontSize: 28, fontWeight: 900, color: S.text, letterSpacing: "-1px" }}>Card<span style={{ color: S.gold }}>IQ</span></span>
            <div style={{ fontSize: 12, color: S.muted, marginTop: 4 }}>Sports Card Investment & AI Advisor</div>
          </div>
          <form onSubmit={handleAuth} style={{ display: "flex", flexDirection: "column", gap: 14 }}>
            <input type="email" placeholder="Email Address" value={email} onChange={(e) => setEmail(e.target.value)} style={S.input} required />
            <input type="password" placeholder="Password" value={password} onChange={(e) => setPassword(e.target.value)} style={S.input} required />
            
            {authError && <div style={{ fontSize: 13, color: "#ef4444", textAlign: "center" }}>{authError}</div>}
            
            <button type="submit" style={{ background: S.gold, color: S.bg, border: "none", borderRadius: 8, padding: "12px", fontWeight: 800, fontSize: 14, cursor: "pointer", transition: "opacity 0.2s" }}>
              {isSignUp ? "Create Account" : "Sign In"}
            </button>
          </form>
          <div style={{ textAlign: "center", marginTop: 20, fontSize: 13, color: S.muted }}>
            {isSignUp ? "Already have an account? " : "New to CardIQ? "}
            <span onClick={() => { setIsSignUp(!isSignUp); setAuthError(""); }} style={{ color: S.gold, cursor: "pointer", fontWeight: 600 }}>
              {isSignUp ? "Sign In" : "Sign Up"}
            </span>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div style={{ minHeight: "100vh", background: S.bg, color: S.text, fontFamily: "'Inter', -apple-system, sans-serif", maxWidth: 920, margin: "0 auto", paddingBottom: 60 }}>

      {/* Header */}
      <div style={{ padding: "24px 24px 0", borderBottom: "1px solid #1e1e2e" }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 4 }}>
          <div style={{ display: "flex", alignItems: "baseline", gap: 12 }}>
            <span style={{ fontSize: 22, fontWeight: 800, letterSpacing: "-0.5px" }}>CardIQ</span>
            <span style={{ fontSize: 11, fontWeight: 600, letterSpacing: "0.14em", color: S.muted, textTransform: "uppercase" }}>Sports Card Advisor</span>
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
            <span style={{ fontSize: 12, color: S.muted }}>{user.email}</span>
            <button onClick={handleLogout} style={{ background: "none", border: "1px solid #2a2a3e", borderRadius: 6, color: S.text, padding: "4px 10px", fontSize: 11, cursor: "pointer" }}>Sign Out</button>
          </div>
        </div>
        <div style={{ display: "flex", gap: 0, marginTop: 18, overflowX: "auto" }}>
          {TABS.map((t) => (
            <button key={t} onClick={() => setTab(t)} style={{ padding: "10px 18px", background: "none", border: "none", borderBottom: tab === t ? `2px solid ${S.gold}` : "2px solid transparent", color: tab === t ? S.gold : S.muted, fontWeight: tab === t ? 700 : 400, fontSize: 13, cursor: "pointer", transition: "all 0.15s", whiteSpace: "nowrap", letterSpacing: "0.02em" }}>
              {t}
            </button>
          ))}
        </div>
      </div>

      <div style={{ padding: "24px 24px 0" }}>

        {/* ── PORTFOLIO ── */}
        {tab === "Portfolio" && (
          <div>
            <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 12, marginBottom: 24 }}>
              {[
                { label: "Total Value", value: fmt(totalValue), sub: `${cards.length} cards` },
                { label: "Total Invested", value: fmt(totalCost), sub: "cost basis" },
                { label: "Total Return", value: `${totalGain >= 0 ? "+" : ""}${fmt(totalGain)}`, sub: `${totalGainPct}%`, color: gainColor(totalGain) },
              ].map((s) => (
                <div key={s.label} style={S.card}>
                  <div style={S.label}>{s.label}</div>
                  <div style={{ fontSize: 22, fontWeight: 800, color: s.color || S.text, letterSpacing: "-0.5px" }}>{s.value}</div>
                  <div style={{ fontSize: 12, color: S.muted, marginTop: 2 }}>{s.sub}</div>
                </div>
              ))}
            </div>

            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 12 }}>
              <span style={{ ...S.label, marginBottom: 0 }}>Collection</span>
              <button onClick={() => setShowAddCard(!showAddCard)} style={{ background: S.gold, color: S.bg, border: "none", borderRadius: 6, padding: "7px 14px", fontSize: 12, fontWeight: 700, cursor: "pointer" }}>+ Add Card</button>
            </div>

            {showAddCard && (
              <div style={{ ...S.card, borderColor: "#c9a84c33", marginBottom: 14 }}>
                <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
                  {[
                    { k: "player", ph: "Player" }, { k: "year", ph: "Year" },
                    { k: "set", ph: "Set / Product" }, { k: "grade", ph: "Grade (e.g. PSA 10)" },
                    { k: "purchasePrice", ph: "Purchase Price ($)" }, { k: "currentValue", ph: "Current Value ($)" },
                  ].map((f) => (
                    <input key={f.k} value={newCard[f.k]} onChange={(e) => setNewCard({ ...newCard, [f.k]: e.target.value })} placeholder={f.ph} style={S.input} />
                  ))}
                  <select value={newCard.sport} onChange={(e) => setNewCard({ ...newCard, sport: e.target.value })} style={S.input}>
                    {["Basketball", "Baseball", "Football", "Hockey", "Soccer"].map((s) => <option key={s}>{s}</option>)}
                  </select>
                </div>
                <div style={{ display: "flex", gap: 8, marginTop: 12 }}>
                  <button onClick={addCard} style={{ background: S.gold, color: S.bg, border: "none", borderRadius: 6, padding: "8px 18px", fontSize: 13, fontWeight: 700, cursor: "pointer" }}>Save</button>
                  <button onClick={() => setShowAddCard(false)} style={{ background: "none", color: S.muted, border: "1px solid #2a2a3e", borderRadius: 6, padding: "8px 18px", fontSize: 13, cursor: "pointer" }}>Cancel</button>
                </div>
              </div>
            )}

            <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
              {cards.map((card) => {
                const gain = card.currentValue - card.purchasePrice;
                const gainPct = card.purchasePrice > 0 ? ((gain / card.purchasePrice) * 100).toFixed(1) : 0;
                return (
                  <div key={card.id} style={{ ...S.card, display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                    <div>
                      <div style={{ fontWeight: 700, fontSize: 15 }}>{card.year} {card.player}</div>
                      <div style={{ fontSize: 12, color: S.muted, marginTop: 3 }}>{card.set} · {card.grade} · {card.sport}</div>
                    </div>
                    <div style={{ display: "flex", alignItems: "center", gap: 20 }}>
                      <div style={{ textAlign: "right" }}>
                        <div style={{ fontSize: 16, fontWeight: 800 }}>{fmt(card.currentValue)}</div>
                        <div style={{ fontSize: 12, fontWeight: 600, color: gainColor(gain) }}>{gain >= 0 ? "+" : ""}{fmt(gain)} ({gainPct}%)</div>
                      </div>
                      <button onClick={() => removeCard(card.id)} style={{ background: "none", border: "none", color: "#3a3a5e", cursor: "pointer", fontSize: 18 }}>×</button>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* ── HISTORY ── */}
        {tab === "History" && <HistoryTab cards={cards} />}

        {/* ── WATCHLIST ── */}
        {tab === "Watchlist" && <WatchlistTab user={user} />}

        {/* ── GRADING ── */}
        {tab === "Grading" && <GradingTab />}

        {/* ── ADVISOR ── */}
        {tab === "Advisor" && (
          <div style={{ display: "flex", flexDirection: "column", height: "calc(100vh - 165px)" }}>
            <div style={{ ...S.label, marginBottom: 10 }}>AI Advisor · Knows your full portfolio</div>
            <div style={{ display: "flex", gap: 8, flexWrap: "wrap", marginBottom: 14 }}>
              {["Should I sell anything?", "What's my best performer?", "What should I add?", "Is grading any of my cards worth it?", "Biggest risks in my portfolio?"].map((p) => (
                <button key={p} onClick={() => setChatInput(p)} style={{ background: "#111118", border: "1px solid #2a2a3e", borderRadius: 20, padding: "6px 13px", fontSize: 12, color: "#9b9bba", cursor: "pointer" }}>{p}</button>
              ))}
            </div>
            <div style={{ flex: 1, overflowY: "auto", display: "flex", flexDirection: "column", gap: 14, paddingBottom: 16 }}>
              {chatMessages.map((m, i) => (
                <div key={i} style={{ display: "flex", justifyContent: m.role === "user" ? "flex-end" : "flex-start" }}>
                  <div style={{ maxWidth: "80%", background: m.role === "user" ? S.gold : "#111118", border: m.role === "assistant" ? "1px solid #1e1e2e" : "none", borderRadius: m.role === "user" ? "18px 18px 4px 18px" : "18px 18px 18px 4px", padding: "12px 16px", fontSize: 14, lineHeight: 1.65, color: m.role === "user" ? S.bg : S.text, fontWeight: m.role === "user" ? 600 : 400 }}>
                    {m.content}
                  </div>
                </div>
              ))}
              {chatLoading && (
                <div style={{ display: "flex", gap: 5, paddingLeft: 4 }}>
                  {[0, 1, 2].map((i) => <div key={i} style={{ width: 8, height: 8, borderRadius: "50%", background: S.gold, opacity: 0.4, animation: `pulse 1.2s ${i * 0.2}s infinite` }} />)}
                </div>
              )}
              <div ref={chatEndRef} />
            </div>
            <div style={{ display: "flex", gap: 10, paddingTop: 12, borderTop: "1px solid #1e1e2e" }}>
              <input value={chatInput} onChange={(e) => setChatInput(e.target.value)} onKeyDown={(e) => e.key === "Enter" && sendChat()} placeholder="Ask about any card, player, trend…" style={{ ...S.input }} />
              <button onClick={sendChat} disabled={chatLoading} style={{ background: S.gold, border: "none", borderRadius: 10, padding: "12px 20px", color: S.bg, fontWeight: 800, fontSize: 14, cursor: "pointer", opacity: chatLoading ? 0.5 : 1 }}>→</button>
            </div>
          </div>
        )}

        {/* ── MARKET ── */}
        {tab === "Market" && (
          <div>
            <div style={{ ...S.label, marginBottom: 4 }}>Market Intelligence</div>
            <div style={{ fontSize: 13, color: S.muted, marginBottom: 16 }}>Enter any player, card, or set for a buy/hold/sell analysis.</div>
            <div style={{ display: "flex", gap: 10, marginBottom: 16 }}>
              <input value={marketQuery} onChange={(e) => setMarketQuery(e.target.value)} onKeyDown={(e) => e.key === "Enter" && runMarketAnalysis()} placeholder="e.g. 2018 Luka Dončić Prizm PSA 10" style={{ ...S.input }} />
              <button onClick={runMarketAnalysis} disabled={marketLoading} style={{ background: S.gold, border: "none", borderRadius: 8, padding: "10px 20px", color: S.bg, fontWeight: 800, fontSize: 14, cursor: "pointer", whiteSpace: "nowrap", opacity: marketLoading ? 0.5 : 1 }}>
                {marketLoading ? "…" : "Analyze"}
              </button>
            </div>
            <div style={{ display: "flex", gap: 8, flexWrap: "wrap", marginBottom: 24 }}>
              {["Wembanyama RC 2023", "Shohei Ohtani Chrome Auto", "Patrick Mahomes Prizm", "Caitlin Clark RC", "2024 Topps Chrome Baseball", "Jayden Daniels RC"].map((p) => (
                <button key={p} onClick={() => setMarketQuery(p)} style={{ background: "#111118", border: "1px solid #2a2a3e", borderRadius: 20, padding: "6px 13px", fontSize: 12, color: "#9b9bba", cursor: "pointer" }}>{p}</button>
              ))}
            </div>
            {marketResult ? (
              <div style={{ ...S.card, borderColor: "#c9a84c33" }}>
                <div style={{ ...S.label, color: S.gold, marginBottom: 12 }}>Analysis: {marketQuery}</div>
                <div style={{ fontSize: 14, lineHeight: 1.8, color: "#c8c4b8", whiteSpace: "pre-wrap" }}>{marketResult}</div>
              </div>
            ) : !marketLoading && (
              <div style={{ border: "1px dashed #2a2a3e", borderRadius: 12, padding: 40, textAlign: "center", color: "#3a3a5e" }}>
                <div style={{ fontSize: 32, marginBottom: 10 }}>📊</div>
                <div style={{ fontSize: 13 }}>Search a card to see AI-powered market analysis</div>
              </div>
            )}
          </div>
        )}
      </div>

      <style>{`
        @keyframes pulse { 0%,100%{opacity:.2;transform:scale(.9)} 50%{opacity:1;transform:scale(1.1)} }
        *{box-sizing:border-box}
        input::placeholder{color:#3a3a5e}
        ::-webkit-scrollbar{width:4px}::-webkit-scrollbar-track{background:#0a0a0f}::-webkit-scrollbar-thumb{background:#2a2a3e;border-radius:2px}
      `}</style>
    </div>
  );
}