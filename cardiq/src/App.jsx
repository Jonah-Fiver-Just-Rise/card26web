import { useState, useRef, useEffect, useMemo } from "react";
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from "recharts";
import {
  onAuthStateChanged,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signOut,
  updatePassword
} from "firebase/auth";
import {
  collection,
  addDoc,
  doc,
  deleteDoc,
  onSnapshot,
  query,
  orderBy,
  setDoc,
  updateDoc
} from "firebase/firestore";
import { auth, db } from "./firebase";
import LogoImg from "./assets/Logo.png";

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

const fmt = (n) => {
  const num = Number(n);
  if (isNaN(num)) return "$0";
  if (num === 0) return "$0";
  const abs = Math.abs(num);
  const sign = num < 0 ? "-" : "";
  if (abs < 10) {
    return `${sign}$${abs.toFixed(2)}`;
  }
  return `${sign}$${Math.round(abs).toLocaleString("en-US")}`;
};

const detectSport = (name, releaseName, setName) => {
  const text = `${name || ""} ${releaseName || ""} ${setName || ""}`.toLowerCase();
  
  // Specific players mapping first
  if (/\bohtani\b|\bjudge\b|\btrout\b|\bacuna\b|\bsoto\b|\bharper\b|\bbetts\b|\bguerrero\b|\bpujols\b|\bripken\b|\bpiazza\b|\bortiz\b|\bmcgwire\b|\brodriguez\b|\bbaseball\b|\bmlb\b/i.test(text)) {
    return "Baseball";
  }
  if (/\bwembanyama\b|\blebron\b|\bcurry\b|\bjordan\b|\bdoncic\b|\bclark\b|\btatum\b|\bkobe\b|\bshaq\b|\bbasketball\b|\bnba\b/i.test(text)) {
    return "Basketball";
  }
  if (/\bmahomes\b|\bbrady\b|\bdart\b|\bburrow\b|\bjackson\b|\bstroud\b|\bpurdy\b|\ballen\b|\bhurts\b|\bcarter\b|\bskattebo\b|\bward\b|\bsanders\b|\bshough\b|\bmanning\b|\btarkenton\b|\bfootball\b|\bnfl\b/i.test(text)) {
    return "Football";
  }
  if (/\bmcdavid\b|\bcrosby\b|\bbedard\b|\bovechkin\b|\bgretzky\b|\bhockey\b|\bnhl\b/i.test(text)) {
    return "Hockey";
  }
  if (/\bmessi\b|\bronaldo\b|\bmbappe\b|\bhaaland\b|\bsoccer\b|\bfutbol\b|\bpremier league\b|\bchampions league\b|\bla liga\b/i.test(text)) {
    return "Soccer";
  }

  // Broad keyword matching
  if (text.includes("bowman") || text.includes("topps chrome") || text.includes("heritage") || text.includes("stadium club") || text.includes("allen & ginter")) {
    return "Baseball";
  }
  if (text.includes("hoops") || text.includes("prizm basketball") || text.includes("court kings") || text.includes("nba hoops")) {
    return "Basketball";
  }
  if (text.includes("prizm football") || text.includes("donruss") || text.includes("score") || text.includes("gridiron")) {
    return "Football";
  }
  if (text.includes("young guns") || text.includes("upper deck") || text.includes("o-pee-chee")) {
    return "Hockey";
  }
  
  return "Basketball"; // Default fallback
};
const gainColor = (n) => (n >= 0 ? "#16a34a" : "#dc2626");
const S = { // shared inline style tokens
  card: { background: "#ffffff", border: "1px solid #e2e8f0", borderRadius: 10, padding: "16px 18px", boxShadow: "0 1px 3px 0 rgba(0, 0, 0, 0.05)" },
  label: { fontSize: 11, color: "#64748b", fontWeight: 600, textTransform: "uppercase", letterSpacing: "0.1em", marginBottom: 6 },
  input: { background: "#f8fafc", border: "1px solid #cbd5e1", borderRadius: 8, padding: "10px 14px", color: "#0f172a", fontSize: 14, outline: "none", width: "100%" },
  accent: "#1e3a8a", // slightly darker gold for better contrast on white backgrounds
  bg: "#ffffff",
  text: "#0f172a",
  muted: "#64748b",
};

const renderMarkdown = (text) => {
  if (!text) return "";
  const lines = text.split("\n");
  return lines.map((line, lineIdx) => {
    let cleanLine = line.trim();
    if (!cleanLine) return <div key={lineIdx} style={{ height: 8 }} />;
    
    const isBullet = cleanLine.startsWith("* ") || cleanLine.startsWith("- ");
    const isNumbered = /^\d+\.\s/.test(cleanLine);
    
    if (isBullet) {
      cleanLine = cleanLine.substring(2);
    } else if (isNumbered) {
      const match = cleanLine.match(/^(\d+\.)\s(.*)/);
      if (match) {
        cleanLine = match[2];
      }
    }
    
    const parts = cleanLine.split(/\*\*([^*]+)\*\*/g);
    const parsedElements = parts.map((part, partIdx) => {
      if (partIdx % 2 === 1) {
        return <strong key={partIdx} style={{ color: S.accent, fontWeight: 700 }}>{part}</strong>;
      }
      return part;
    });
    
    if (isBullet) {
      return (
        <div key={lineIdx} style={{ display: "flex", gap: 8, marginLeft: 12, marginBlock: 4, lineHeight: 1.6, fontSize: 13.5 }}>
          <span style={{ color: S.accent }}>•</span>
          <div>{parsedElements}</div>
        </div>
      );
    }
    
    if (isNumbered) {
      return (
        <div key={lineIdx} style={{ display: "flex", gap: 8, marginLeft: 12, marginBlock: 4, lineHeight: 1.6, fontSize: 13.5 }}>
          <span style={{ color: S.accent, fontWeight: 700 }}>{line.match(/^\d+\./)?.[0] || ""}</span>
          <div>{parsedElements}</div>
        </div>
      );
    }
    
    return (
      <p key={lineIdx} style={{ margin: "0 0 8px 0", lineHeight: 1.6, fontSize: 13.5 }}>
        {parsedElements}
      </p>
    );
  });
};

// ── Secure Client-Side API integration (Supports Gemini with OpenAI fallback) ──
const QUOTA_EXCEEDED = "__QUOTA_EXCEEDED__";
const INVALID_KEY = "__INVALID_KEY__";

const fetchWithTimeout = (url, options, timeoutMs = 30000) => {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  return fetch(url, { ...options, signal: controller.signal })
    .finally(() => clearTimeout(timer));
};

const callChatGPT = async (messages, system) => {
  const geminiKey = import.meta.env.VITE_GEMINI_API_KEY;
  if (!geminiKey || geminiKey.includes("YOUR_GEMINI_API_KEY") || geminiKey.trim() === "") {
    return "Please configure VITE_GEMINI_API_KEY in your .env file.";
  }
  
  const models = ["gemini-2.5-flash", "gemini-2.0-flash", "gemini-flash-latest"];
  let lastError = null;

  // Gemini requires strict user/model alternation, starting with "user"
  // Build a clean alternating conversation from messages
  const buildGeminiContents = (msgs) => {
    const mapped = msgs.map(m => ({
      role: m.role === "assistant" ? "model" : "user",
      parts: [{ text: m.content }]
    }));

    // Drop leading "model" turns (Gemini must start with user)
    let start = 0;
    while (start < mapped.length && mapped[start].role === "model") start++;
    const trimmed = mapped.slice(start);

    // Merge consecutive same-role turns to enforce strict alternation
    const merged = [];
    for (const turn of trimmed) {
      if (merged.length > 0 && merged[merged.length - 1].role === turn.role) {
        merged[merged.length - 1].parts[0].text += "\n\n" + turn.parts[0].text;
      } else {
        merged.push({ role: turn.role, parts: [{ text: turn.parts[0].text }] });
      }
    }
    return merged;
  };

  for (const model of models) {
    try {
      const res = await fetchWithTimeout(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-goog-api-key": geminiKey.trim()
          },
          body: JSON.stringify({
            systemInstruction: {
              parts: [{ text: system }]
            },
            contents: buildGeminiContents(messages),
            generationConfig: {
              maxOutputTokens: 2048,
              temperature: 0.7
            }
          })
        }
      );

      // 429 = quota exceeded, 401 = invalid key — stop immediately
      if (res.status === 429) {
        console.warn(`Gemini quota exceeded (429).`);
        return QUOTA_EXCEEDED;
      }
      if (res.status === 401) {
        console.error(`Gemini API key invalid (401). Check VITE_GEMINI_API_KEY in your env vars.`);
        return INVALID_KEY;
      }

      const data = await res.json();
      if (!res.ok) {
        throw new Error(data.error?.message || `HTTP ${res.status} ${res.statusText}`);
      }
      if (data.candidates?.[0]?.content?.parts?.[0]?.text) {
        return data.candidates[0].content.parts[0].text;
      }
      throw new Error("Empty response from model.");
    } catch (err) {
      if (err.name === "AbortError") {
        console.warn(`Model ${model} timed out.`);
        lastError = new Error("Request timed out after 30s. Please try again.");
      } else {
        console.warn(`Model ${model} failed:`, err);
        lastError = err;
      }
    }
  }
  return `⚠️ ${lastError ? lastError.message : "Service Unavailable. Please try again."}`;
};

// ── Secure Client-Side CardSight AI API call (with graceful fallback support) ──
const callCardSightAPI = async (endpoint, options = {}) => {
  const apiKey = import.meta.env.VITE_CARDSIGHTAI_API_KEY;
  if (!apiKey || apiKey === "YOUR_CARDSIGHT_API_KEY" || apiKey.trim() === "") {
    console.log(`[CardSight] API Key missing or default, skipping endpoint: ${endpoint}`);
    return null; // Key not set, triggers fallback
  }
  try {
    console.log(`[CardSight] Fetching endpoint: ${endpoint}`);
    const res = await fetchWithTimeout(`https://api.cardsight.ai${endpoint}`, {
      ...options,
      headers: {
        "X-API-Key": apiKey.trim(),
        "Content-Type": "application/json",
        ...options.headers,
      },
    });
    console.log(`[CardSight] Endpoint response status: ${res.status} for ${endpoint}`);
    if (res.status === 401 || res.status === 403) {
      console.warn("CardSight API key invalid or unauthorized.");
      return "__INVALID_KEY__";
    }
    if (res.status === 429) {
      console.warn("CardSight API rate limit or quota exceeded.");
      return "__QUOTA_EXCEEDED__";
    }
    if (!res.ok) {
      throw new Error(`HTTP error! status: ${res.status}`);
    }
    const json = await res.json();
    console.log(`[CardSight] Response data for ${endpoint}:`, json);
    return json;
  } catch (err) {
    console.error("CardSight API call failed:", err);
    throw err;
  }
};

const fetchCardPrice = async (cardId) => {
  try {
    const pricingRes = await callCardSightAPI(`/v1/pricing/${cardId}`);
    if (pricingRes && typeof pricingRes === "object" && pricingRes !== null) {
      const rawSales = pricingRes.raw?.records || [];
      const gradedSales = Array.isArray(pricingRes.graded) 
        ? pricingRes.graded 
        : (pricingRes.graded?.records || []);
      const sales = [...rawSales, ...gradedSales];
      let total = 0;
      let count = 0;
      sales.forEach(s => {
        const val = s.price !== undefined ? s.price : (s.price_usd !== undefined ? s.price_usd : s.value);
        if (val !== undefined && val !== null) {
          const p = parseFloat(String(val).replace(/[^0-9.]/g, '')) || 0;
          if (p > 0) {
            total += p;
            count++;
          }
        }
      });
      const avgPrice = count > 0 ? total / count : 0;
      const finalPrice = pricingRes.averagePrice || pricingRes.average || avgPrice || 0;
      console.log(`[CardSight] fetchCardPrice for ID ${cardId} pricing average: ${finalPrice}`);
      if (finalPrice > 0) return finalPrice;
    }
  } catch (e) {
    console.warn("Pricing lookup failed for ID:", cardId, e);
  }
  try {
    const marketRes = await callCardSightAPI(`/v1/marketplace/${cardId}`);
    if (marketRes && typeof marketRes === "object" && marketRes !== null) {
      const records = marketRes.raw?.records || (Array.isArray(marketRes.raw) ? marketRes.raw : []);
      let total = 0;
      let count = 0;
      records.forEach(r => {
        const val = r.price !== undefined ? r.price : (r.price_usd !== undefined ? r.price_usd : r.value);
        if (val !== undefined && val !== null) {
          const p = parseFloat(String(val).replace(/[^0-9.]/g, '')) || 0;
          if (p > 0) {
            total += p;
            count++;
          }
        }
      });
      const avgMarket = count > 0 ? total / count : 0;
      console.log(`[CardSight] fetchCardPrice for ID ${cardId} marketplace average: ${avgMarket}`);
      if (count > 0) return avgMarket;
    }
  } catch (e) {
    console.warn("Marketplace lookup failed for ID:", cardId, e);
  }
  console.log(`[CardSight] fetchCardPrice for ID ${cardId} resolved to 0`);
  return 0;
};

// ── Quota Exceeded Banner ──────────────────────────────────────────────────
const QuotaBanner = () => (
  <div style={{
    background: "#fef3c7",
    border: "1px solid #f59e0b",
    borderRadius: 8,
    padding: "12px 16px",
    marginTop: 8,
    display: "flex",
    alignItems: "center",
    gap: 10
  }}>
    <span style={{ fontSize: 18 }}>⏳</span>
    <div>
      <span style={{ color: "#d97706", fontWeight: 700, fontSize: 13 }}>AI Quota Exceeded — </span>
      <span style={{ color: "#b45309", fontSize: 13 }}>Your AI quota has been used up. Please try again after 24 hours.</span>
    </div>
  </div>
);

// ── Invalid API Key Banner ──────────────────────────────────────────
const InvalidKeyBanner = () => (
  <div style={{
    background: "#fee2e2",
    border: "1px solid #fca5a5",
    borderRadius: 8,
    padding: "12px 16px",
    marginTop: 8,
    display: "flex",
    alignItems: "flex-start",
    gap: 10
  }}>
    <span style={{ fontSize: 18 }}>🔑</span>
    <div>
      <div style={{ color: "#ef4444", fontWeight: 700, fontSize: 13, marginBottom: 3 }}>Invalid API Key (401 Unauthorized)</div>
      <div style={{ color: "#b91c1c", fontSize: 12, lineHeight: 1.6 }}>
        The Gemini API key is missing or invalid on this deployment.<br />
        Go to <strong>Vercel → Project Settings → Environment Variables</strong> and add <code style={{ background: "#fecaca", padding: "1px 5px", borderRadius: 3 }}>VITE_GEMINI_API_KEY</code>, then redeploy.
      </div>
    </div>
  </div>
);

// ── Custom Tooltip for chart ───────────────────────────────────────────────
const ChartTooltip = ({ active, payload, label }) => {
  if (!active || !payload?.length) return null;
  return (
    <div style={{ background: "#ffffff", border: "1px solid #cbd5e1", borderRadius: 8, padding: "8px 14px", fontSize: 13, boxShadow: "0 4px 6px -1px rgba(0, 0, 0, 0.05)" }}>
      <div style={{ color: S.muted, marginBottom: 2 }}>{label}</div>
      <div style={{ color: S.accent, fontWeight: 700 }}>{fmt(payload[0].value)}</div>
    </div>
  );
};

// ── Grading ROI Calculator ─────────────────────────────────────────────────
function GradingTab() {
  const [form, setForm] = useState({ player: "", rawValue: "", psa10Est: "", psa9Est: "", gradingCost: "22", tier: "Value" });
  const [aiAnalysis, setAiAnalysis] = useState("");
  const [loading, setLoading] = useState(false);

  const [searchQuery, setSearchQuery] = useState("");
  const [searchResults, setSearchResults] = useState([]);
  const [searchCatalogLoading, setSearchCatalogLoading] = useState(false);
  const [searchError, setSearchError] = useState("");

  const set = (k, v) => setForm((f) => ({ ...f, [k]: v }));

  const rawN = parseFloat(form.rawValue) || 0;
  const p10 = parseFloat(form.psa10Est) || 0;
  const p9 = parseFloat(form.psa9Est) || 0;
  const cost = parseFloat(form.gradingCost) || 22;

  const roi10 = rawN > 0 ? (((p10 - rawN - cost) / (rawN + cost)) * 100).toFixed(1) : null;
  const roi9 = rawN > 0 ? (((p9 - rawN - cost) / (rawN + cost)) * 100).toFixed(1) : null;
  const breakeven10 = rawN + cost;
  const verdict = roi10 !== null ? (parseFloat(roi10) > 30 ? "Submit" : parseFloat(roi10) > 0 ? "Maybe" : "Skip") : null;
  const verdictColor = verdict === "Submit" ? "#22c55e" : verdict === "Maybe" ? "#f59e0b" : "#ef4444";

  const EXAMPLES = [
    { label: "2023 Wembanyama Prizm", player: "2023 Victor Wembanyama Prizm RC #136", rawValue: "250", psa10Est: "1100", psa9Est: "400", gradingCost: "22", tier: "Value" },
    { label: "2018 Luka Dončić Prizm", player: "2018 Luka Dončić Prizm Rookie #280", rawValue: "350", psa10Est: "1400", psa9Est: "550", gradingCost: "50", tier: "Economy" },
    { label: "2003 LeBron James Topps", player: "2003 LeBron James Topps Rookie #111", rawValue: "800", psa10Est: "4500", psa9Est: "1500", gradingCost: "150", tier: "Express" },
  ];

  const loadExample = (ex) => {
    setForm({
      player: ex.player,
      rawValue: ex.rawValue,
      psa10Est: ex.psa10Est,
      psa9Est: ex.psa9Est,
      gradingCost: ex.gradingCost,
      tier: ex.tier
    });
    setSearchResults([]);
    setSearchQuery("");
    setSearchError("");
    setAiAnalysis("");
  };

  const runCatalogSearch = async () => {
    if (!searchQuery.trim()) return;
    setSearchCatalogLoading(true);
    setSearchResults([]);
    setSearchError("");
    try {
      const apiRes = await callCardSightAPI(`/v1/catalog/search?q=${encodeURIComponent(searchQuery)}`);
      if (apiRes === "__INVALID_KEY__") {
        setSearchError("CardSight AI API key invalid. Check VITE_CARDSIGHTAI_API_KEY.");
        setSearchCatalogLoading(false);
        return;
      }
      if (apiRes === "__QUOTA_EXCEEDED__") {
        setSearchError("CardSight AI rate limit exceeded.");
        setSearchCatalogLoading(false);
        return;
      }
      const results = apiRes?.results || apiRes?.data;
      if (apiRes && results && Array.isArray(results)) {
        const mappedPromises = results.slice(0, 5).map(async (item) => {
          const price = await fetchCardPrice(item.id);
          const detected = detectSport(item.name, item.releaseName, item.setName);
          const setDesc = `${item.releaseName || ""} ${item.setName || ""}${item.parallelName ? " (" + item.parallelName + ")" : ""}`.trim();
          return {
            player: item.name || item.player || "",
            year: parseInt(item.year) || new Date().getFullYear(),
            set: setDesc,
            sport: detected,
            rawValue: price,
            psa10Value: price * 1.5 || 15,
            psa9Value: price * 1.1 || 8
          };
        });
        const mapped = await Promise.all(mappedPromises);
        setSearchResults(mapped);
        setSearchCatalogLoading(false);
        return;
      }
    } catch (e) {
      console.warn("CardSight catalog search failed, falling back to simulation:", e);
    }

    // Fallback: OpenAI simulation
    const system = "You are a sports card database API. Return ONLY a raw JSON array (no markdown, no code blocks, no explanation) of exactly 3 matching sports cards. Each object must have: 'player' (string), 'year' (number), 'set' (string), 'sport' (Basketball|Baseball|Football|Hockey|Soccer), 'rawValue' (number), 'psa10Value' (number), 'psa9Value' (number). Example: [{\"player\":\"LeBron James\",\"year\":2003,\"set\":\"Topps\",\"sport\":\"Basketball\",\"rawValue\":800,\"psa10Value\":4500,\"psa9Value\":1500}]";
    try {
      const result = await callChatGPT([{ role: "user", content: `Find sports cards matching: ${searchQuery}` }], system);
      if (result === QUOTA_EXCEEDED) {
        setSearchError("QUOTA_EXCEEDED");
        return;
      }
      if (result === INVALID_KEY) {
        setSearchError("INVALID_KEY");
        return;
      }
      const startIndex = result.indexOf("[");
      const endIndex = result.lastIndexOf("]") + 1;
      if (startIndex === -1 || endIndex <= 0) {
        setSearchError("No results returned. Try a more specific search (e.g. '2003 LeBron James Topps').");
        return;
      }
      const parsed = JSON.parse(result.substring(startIndex, endIndex));
      if (!Array.isArray(parsed) || parsed.length === 0) {
        setSearchError("No matching cards found. Try a different search.");
        return;
      }
      setSearchResults(parsed);
    } catch (e) {
      console.error("Failed parsing search results: ", e);
      setSearchError("Parse error — try again.");
    } finally {
      setSearchCatalogLoading(false);
    }
  };

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
      <div style={{ fontSize: 13, color: S.muted, marginBottom: 16 }}>Find out if submitting to PSA/BGS is worth it before you pay.</div>

      {/* Quick Example Presets */}
      <div style={{ display: "flex", gap: 8, flexWrap: "wrap", marginBottom: 20, alignItems: "center" }}>
        <span style={{ fontSize: 12, color: S.muted, fontWeight: 600 }}>Try Examples:</span>
        {EXAMPLES.map((ex) => (
          <button key={ex.label} onClick={() => loadExample(ex)} style={{ background: "#f1f5f9", border: "1px solid #cbd5e1", borderRadius: 20, padding: "5px 12px", fontSize: 12, color: S.accent, cursor: "pointer", transition: "all 0.2s" }} onMouseEnter={(e) => { e.currentTarget.style.borderColor = S.accent; e.currentTarget.style.background = "#e2e8f0"; }} onMouseLeave={(e) => { e.currentTarget.style.borderColor = '#cbd5e1'; e.currentTarget.style.background = "#f1f5f9"; }}>
            {ex.label}
          </button>
        ))}
      </div>

      {/* AI Catalog Search for Grading values */}
      <div style={{ ...S.card, borderColor: "#cbd5e1", marginBottom: 20, background: "linear-gradient(145deg, #ffffff, #f8fafc)" }}>
        <div style={S.label}>Search Card Database for Price Comps</div>
        <div style={{ display: "flex", gap: 10 }}>
          <input value={searchQuery} onChange={(e) => setSearchQuery(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && runCatalogSearch()} placeholder="e.g. 2023 Wembanyama Prizm" style={S.input} />
          <button type="button" onClick={runCatalogSearch} disabled={searchCatalogLoading} style={{ background: S.accent, border: "none", borderRadius: 8, padding: "0 20px", color: S.bg, fontWeight: 700, fontSize: 13, cursor: "pointer", opacity: searchCatalogLoading ? 0.5 : 1 }}>
            {searchCatalogLoading ? "Searching..." : "Search"}
          </button>
        </div>
        {searchCatalogLoading && (
          <div style={{ marginTop: 10, display: "flex", flexDirection: "column", gap: 6, background: "#f8fafc", border: "1px solid #cbd5e1", borderRadius: 8, padding: 12 }}>
            {[1, 2, 3].map((i) => (
              <div key={i} style={{ display: "flex", justifyContent: "space-between", padding: "8px 10px", borderRadius: 6, background: "#f1f5f9", animation: "pulse 1.5s infinite ease-in-out" }}>
                <div style={{ height: 14, width: "60%", background: "#cbd5e1", borderRadius: 4 }} />
                <div style={{ height: 14, width: "15%", background: S.accent, opacity: 0.3, borderRadius: 4 }} />
              </div>
            ))}
          </div>
        )}
        {searchError && (
          searchError === "QUOTA_EXCEEDED"
            ? <QuotaBanner />
            : searchError === "INVALID_KEY"
              ? <InvalidKeyBanner />
              : <div style={{ marginTop: 10, color: "#ef4444", fontSize: 13, background: "#ef444411", padding: "10px 12px", borderRadius: 8, border: "1px solid #ef444433" }}>{searchError}</div>
        )}
        {!searchCatalogLoading && searchResults.length > 0 && (
          <div style={{ marginTop: 10, display: "flex", flexDirection: "column", gap: 6, maxHeight: 150, overflowY: "auto", background: "#f8fafc", border: "1px solid #cbd5e1", borderRadius: 8, padding: 8 }}>
            {searchResults.map((item, idx) => (
              <div key={idx} onClick={() => {
                setForm({
                  player: `${item.year} ${item.player} (${item.set})`,
                  rawValue: item.rawValue,
                  psa10Est: item.psa10Value,
                  psa9Est: item.psa9Value,
                  gradingCost: "22",
                  tier: "Value"
                });
                setSearchResults([]);
                setSearchQuery("");
              }} style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "8px 10px", cursor: "pointer", borderRadius: 6, borderBottom: "1px solid #e2e8f0", transition: "background 0.2s" }} onMouseEnter={(e) => e.currentTarget.style.backgroundColor = '#f1f5f9'} onMouseLeave={(e) => e.currentTarget.style.backgroundColor = 'transparent'}>
                <span style={{ fontSize: 13 }}>{item.year} {item.player} ({item.set}) - Raw: {fmt(item.rawValue)} · PSA 10: {fmt(item.psa10Value)}</span>
                <span style={{ color: S.accent, fontWeight: 700, fontSize: 12 }}>Select</span>
              </div>
            ))}
          </div>
        )}
      </div>

      <div className="grid-2" style={{ marginBottom: 16 }}>
        {[
          { k: "player", label: "Player / Card", ph: "e.g. 2023 Wembanyama Prizm" },
          { k: "rawValue", label: "Raw (Ungraded) Value ($)", ph: "e.g. 250" },
          { k: "psa10Est", label: "PSA 10 Market Value ($)", ph: "e.g. 1100" },
          { k: "psa9Est", label: "PSA 9 Market Value ($)", ph: "e.g. 400" },
        ].map((f) => (
          <div key={f.k}>
            <div style={{ ...S.label, marginBottom: 6 }}>{f.label}</div>
            <input value={form[f.k]} onChange={(e) => set(f.k, e.target.value)} placeholder={f.ph} style={S.input} />
          </div>
        ))}

        <div>
          <div style={{ ...S.label, marginBottom: 6 }}>Grading Tier</div>
          <select value={form.tier} onChange={(e) => {
            const t = e.target.value;
            const priceMap = { Value: "22", Economy: "50", Regular: "100", Express: "150", "Super Express": "300" };
            setForm((prev) => ({ ...prev, tier: t, gradingCost: priceMap[t] || prev.gradingCost }));
          }} style={{ ...S.input }}>
            {[["Value", "$18–22"], ["Economy", "$50"], ["Regular", "$100"], ["Express", "$150"], ["Super Express", "$300"]].map(([t, p]) => (
              <option key={t} value={t}>{t} ({p})</option>
            ))}
          </select>
        </div>
        <div>
          <div style={{ ...S.label, marginBottom: 6 }}>Grading Cost ($)</div>
          <input value={form.gradingCost} onChange={(e) => set("gradingCost", e.target.value)} placeholder="22" style={S.input} />
        </div>
      </div>

      {verdict && (
        <div className="grid-4 mb-20">
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

      <button onClick={getAIAnalysis} disabled={loading || !form.player} style={{ background: S.accent, color: S.bg, border: "none", borderRadius: 8, padding: "11px 22px", fontWeight: 800, fontSize: 14, cursor: "pointer", opacity: loading || !form.player ? 0.5 : 1, marginBottom: 16 }}>
        {loading ? "Analyzing…" : "Get AI Grading Advice"}
      </button>

      {aiAnalysis && (
        aiAnalysis === QUOTA_EXCEEDED
          ? <QuotaBanner />
          : aiAnalysis === INVALID_KEY
            ? <InvalidKeyBanner />
            : (
              <div style={{ ...S.card, borderColor: "#1e3a8a33" }}>
                <div style={{ ...S.label, color: S.accent, marginBottom: 10 }}>AI Grading Advisor</div>
                <div style={{ fontSize: 14, lineHeight: 1.75, color: "#475569" }}>{renderMarkdown(aiAnalysis)}</div>
              </div>
            )
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

  const [searchQuery, setSearchQuery] = useState("");
  const [searchResults, setSearchResults] = useState([]);
  const [searchCatalogLoading, setSearchCatalogLoading] = useState(false);
  const [searchError, setSearchError] = useState("");

  useEffect(() => {
    if (!user) return;
    const q = query(collection(db, `users/${user.uid}/watchlists`), orderBy("addedAt", "desc"));
    const unsubscribe = onSnapshot(q, (snapshot) => {
      setItems(snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() })));
    });
    return unsubscribe;
  }, [user]);

  const setField = (k, v) => setNewItem((n) => ({ ...n, [k]: v }));

  const runCatalogSearch = async () => {
    if (!searchQuery.trim()) return;
    setSearchCatalogLoading(true);
    setSearchResults([]);
    setSearchError("");
    try {
      const apiRes = await callCardSightAPI(`/v1/catalog/search?q=${encodeURIComponent(searchQuery)}`);
      if (apiRes === "__INVALID_KEY__") {
        setSearchError("CardSight AI API key invalid. Check VITE_CARDSIGHTAI_API_KEY.");
        setSearchCatalogLoading(false);
        return;
      }
      if (apiRes === "__QUOTA_EXCEEDED__") {
        setSearchError("CardSight AI rate limit exceeded.");
        setSearchCatalogLoading(false);
        return;
      }
      const results = apiRes?.results || apiRes?.data;
      if (apiRes && results && Array.isArray(results)) {
        const mappedPromises = results.slice(0, 5).map(async (item) => {
          const price = await fetchCardPrice(item.id);
          const detected = detectSport(item.name, item.releaseName, item.setName);
          const setDesc = `${item.releaseName || ""} ${item.setName || ""}${item.parallelName ? " (" + item.parallelName + ")" : ""}`.trim();
          return {
            player: item.name || item.player || "",
            year: parseInt(item.year) || new Date().getFullYear(),
            set: setDesc,
            sport: detected,
            estimatedPrice: price
          };
        });
        const mapped = await Promise.all(mappedPromises);
        setSearchResults(mapped);
        setSearchCatalogLoading(false);
        return;
      }
    } catch (e) {
      console.warn("CardSight catalog search failed, falling back to simulation:", e);
    }

    // Fallback: OpenAI simulation
    const system = "You are a sports card database API. Return ONLY a raw JSON array (no markdown, no code blocks, no explanation) of exactly 3 matching sports cards. Each object must have: 'player' (string), 'year' (number), 'set' (string), 'sport' (Basketball|Baseball|Football|Hockey|Soccer), 'estimatedPrice' (number). Example: [{\"player\":\"LeBron James\",\"year\":2003,\"set\":\"Topps\",\"sport\":\"Basketball\",\"estimatedPrice\":800}]";
    try {
      const result = await callChatGPT([{ role: "user", content: `Find sports cards matching: ${searchQuery}` }], system);
      if (result === QUOTA_EXCEEDED) {
        setSearchError("QUOTA_EXCEEDED");
        return;
      }
      if (result === INVALID_KEY) {
        setSearchError("INVALID_KEY");
        return;
      }
      const startIndex = result.indexOf("[");
      const endIndex = result.lastIndexOf("]") + 1;
      if (startIndex === -1 || endIndex <= 0) {
        setSearchError("No results returned. Try a more specific search.");
        return;
      }
      const parsed = JSON.parse(result.substring(startIndex, endIndex));
      if (!Array.isArray(parsed) || parsed.length === 0) {
        setSearchError("No matching cards found. Try a different search.");
        return;
      }
      setSearchResults(parsed);
    } catch (e) {
      console.error("Failed parsing search results: ", e);
      setSearchError("Parse error — try again.");
    } finally {
      setSearchCatalogLoading(false);
    }
  };

  const resetForm = () => {
    setNewItem({ player: "", year: "", set: "", grade: "", sport: "Basketball", targetBuy: "", currentEst: "" });
    setSearchQuery("");
    setSearchResults([]);
    setSearchError("");
  };

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
      resetForm();
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
    try {
      const searchRes = await callCardSightAPI(`/v1/catalog/search?q=${encodeURIComponent(ebayQuery)}`);
      if (searchRes === "__INVALID_KEY__") {
        setEbayResult("⚠️ CardSight AI API key invalid. Check VITE_CARDSIGHTAI_API_KEY.");
        setEbayLoading(false);
        return;
      }
      if (searchRes === "__QUOTA_EXCEEDED__") {
        setEbayResult("⚠️ CardSight AI rate limit exceeded.");
        setEbayLoading(false);
        return;
      }
      const searchResults = searchRes?.results || searchRes?.data;
      if (searchRes && searchResults && searchResults.length > 0) {
        const cardId = searchResults[0].id;
        const pricingRes = await callCardSightAPI(`/v1/pricing/${cardId}`);
        if (pricingRes && typeof pricingRes === "object" && pricingRes !== null) {
          const rawSales = pricingRes.raw?.records || [];
          const gradedSales = Array.isArray(pricingRes.graded) 
            ? pricingRes.graded 
            : (pricingRes.graded?.records || []);
          const sales = [...rawSales, ...gradedSales];
          let total = 0;
          let count = 0;
          sales.forEach(s => {
            const val = s.price !== undefined ? s.price : (s.price_usd !== undefined ? s.price_usd : s.value);
            if (val !== undefined && val !== null) {
              const p = parseFloat(String(val).replace(/[^0-9.]/g, '')) || 0;
              if (p > 0) {
                total += p;
                count++;
              }
            }
          });
          const avgPrice = count > 0 ? total / count : 0;
          if (sales.length > 0 || avgPrice > 0) {
            let resultStr = `**30-Day Average:** ${fmt(avgPrice)}\n\n`;
            resultStr += `**Recent Sold Prices (CardSight AI Live Data):**\n`;
            sales.slice(0, 5).forEach((sale) => {
              const val = sale.price !== undefined ? sale.price : (sale.price_usd !== undefined ? sale.price_usd : sale.value);
              const price = val !== undefined && val !== null ? parseFloat(String(val).replace(/[^0-9.]/g, '')) || 0 : 0;
              const dateStr = sale.date || sale.sale_date ? new Date(sale.date || sale.sale_date).toLocaleDateString() : 'Recent';
              const source = sale.source || 'eBay';
              const grade = sale.grade || 'Raw';
              resultStr += `*   ${fmt(price)} (${dateStr}) - Grade: ${grade} [${source}]\n`;
            });
            if (pricingRes.trend) {
              resultStr += `\n**Trend Note:** ${pricingRes.trend}`;
            }
            setEbayResult(resultStr);
            setEbayLoading(false);
            return;
          }
        }
      }
    } catch (err) {
      console.warn("CardSight live comps query failed, falling back to simulation:", err);
    }

    // Fallback: OpenAI comps simulation
    try {
      const system = `You are a sports card pricing expert simulating eBay sold listing data. Based on your knowledge of the market, provide realistic recent sold prices for the card queried. Format as: 3–5 recent "sold" prices with dates, a 30-day average, and a trend note. Be specific and realistic. Under 150 words.`;
      const res = await callChatGPT([{ role: "user", content: `Simulate recent eBay sold listings for: ${ebayQuery}` }], system);
      setEbayResult(res);
    } catch (err) {
      setEbayResult(`⚠️ Failed to fetch prices: ${err.message}`);
    } finally {
      setEbayLoading(false);
    }
  };

  return (
    <div>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 16 }}>
        <div>
          <div style={S.label}>Watchlist</div>
          <div style={{ fontSize: 13, color: S.muted }}>Cards you're watching to buy. Set target prices and track vs. market.</div>
        </div>
        <button onClick={() => {
          if (showAdd) {
            resetForm();
          }
          setShowAdd(!showAdd);
        }} style={{ background: S.accent, color: S.bg, border: "none", borderRadius: 6, padding: "8px 16px", fontSize: 12, fontWeight: 700, cursor: "pointer" }}>+ Watch Card</button>
      </div>

      {showAdd && (
        <div style={{ ...S.card, borderColor: "#1e3a8a33", marginBottom: 14 }}>
          <div style={{ borderBottom: "1px solid #e2e8f0", paddingBottom: 14, marginBottom: 14 }}>
            <div style={S.label}>Search Card Catalog</div>
            <div style={{ display: "flex", gap: 10 }}>
              <input value={searchQuery} onChange={(e) => setSearchQuery(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && runCatalogSearch()} placeholder="e.g. 2003 LeBron James Topps" style={S.input} />
              <button type="button" onClick={runCatalogSearch} disabled={searchCatalogLoading} style={{ background: S.accent, border: "none", borderRadius: 8, padding: "0 20px", color: S.bg, fontWeight: 700, fontSize: 13, cursor: "pointer", opacity: searchCatalogLoading ? 0.5 : 1 }}>
                {searchCatalogLoading ? "Searching..." : "Search"}
              </button>
            </div>
            {searchCatalogLoading && (
              <div style={{ marginTop: 10, display: "flex", flexDirection: "column", gap: 6, background: "#f8fafc", border: "1px solid #cbd5e1", borderRadius: 8, padding: 12 }}>
                {[1, 2, 3].map((i) => (
                  <div key={i} style={{ display: "flex", justifyContent: "space-between", padding: "8px 10px", borderRadius: 6, background: "#f1f5f9", animation: "pulse 1.5s infinite ease-in-out" }}>
                    <div style={{ height: 14, width: "60%", background: "#cbd5e1", borderRadius: 4 }} />
                    <div style={{ height: 14, width: "15%", background: S.accent, opacity: 0.3, borderRadius: 4 }} />
                  </div>
                ))}
              </div>
            )}
            {searchError && (
              searchError === "QUOTA_EXCEEDED"
                ? <QuotaBanner />
                : searchError === "INVALID_KEY"
                  ? <InvalidKeyBanner />
                  : (
                    <div style={{ marginTop: 10, color: "#ef4444", fontSize: 13, background: "#ef444411", padding: "10px 12px", borderRadius: 8, border: "1px solid #ef444433" }}>
                      {searchError}
                    </div>
                  )
            )}
            {!searchCatalogLoading && searchResults.length > 0 && (
              <div style={{ marginTop: 10, display: "flex", flexDirection: "column", gap: 6, maxHeight: 150, overflowY: "auto", background: "#f8fafc", border: "1px solid #cbd5e1", borderRadius: 8, padding: 8 }}>
                {searchResults.map((item, idx) => (
                  <div key={idx} onClick={() => {
                    setNewItem({
                      player: item.player,
                      year: item.year,
                      set: item.set,
                      grade: "Raw",
                      sport: item.sport,
                      targetBuy: item.estimatedPrice,
                      currentEst: item.estimatedPrice
                    });
                    setSearchResults([]);
                  }} style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "8px 10px", cursor: "pointer", borderRadius: 6, borderBottom: "1px solid #e2e8f0", transition: "background 0.2s" }} onMouseEnter={(e) => e.currentTarget.style.backgroundColor = '#f1f5f9'} onMouseLeave={(e) => e.currentTarget.style.backgroundColor = 'transparent'}>
                    <span style={{ fontSize: 13 }}>{item.year} {item.player} ({item.set}) - {item.sport}</span>
                    <span style={{ color: S.accent, fontWeight: 700, fontSize: 13 }}>{fmt(item.estimatedPrice)}</span>
                  </div>
                ))}
              </div>
            )}
          </div>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
            {[
              { k: "player", ph: "Player" }, { k: "year", ph: "Year" },
              { k: "set", ph: "Set / Product" }, { k: "grade", ph: "Grade" },
              { k: "targetBuy", ph: "Target Buy Price ($)" }, { k: "currentEst", ph: "Current Est. Value ($)" },
            ].map((f) => (
              <input key={f.k} value={newItem[f.k]} onChange={(e) => setField(f.k, e.target.value)} placeholder={f.ph} style={S.input} />
            ))}
            <select value={newItem.sport} onChange={(e) => setField("sport", e.target.value)} style={S.input}>
              {["Basketball", "Baseball", "Football", "Hockey", "Soccer"].map((s) => <option key={s}>{s}</option>)}
            </select>
          </div>
          <div style={{ display: "flex", gap: 8, marginTop: 12 }}>
            <button onClick={addItem} style={{ background: S.accent, color: S.bg, border: "none", borderRadius: 6, padding: "8px 18px", fontSize: 13, fontWeight: 700, cursor: "pointer" }}>Add to Watchlist</button>
            <button onClick={() => { resetForm(); setShowAdd(false); }} style={{ background: "none", color: S.muted, border: "1px solid #cbd5e1", borderRadius: 6, padding: "8px 18px", fontSize: 13, cursor: "pointer" }}>Cancel</button>
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
                <div style={{ fontSize: 12, color: S.muted, marginTop: 2 }}>Target: <span style={{ color: S.accent }}>{fmt(item.targetBuy)}</span></div>
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
          <div style={{ border: "1px dashed #cbd5e1", borderRadius: 10, padding: 32, textAlign: "center", color: "#64748b", fontSize: 13 }}>No cards on watchlist yet.</div>
        )}
      </div>

      {/* eBay Price Lookup */}
      <div style={{ borderTop: "1px solid #e2e8f0", paddingTop: 24 }}>
        <div style={{ ...S.label, marginBottom: 4 }}>eBay Price Lookup</div>
        <div style={{ fontSize: 13, color: S.muted, marginBottom: 12 }}>Get AI-estimated recent sold prices based on market data.</div>
        <div style={{ display: "flex", gap: 10, marginBottom: 14 }}>
          <input value={ebayQuery} onChange={(e) => setEbayQuery(e.target.value)} onKeyDown={(e) => e.key === "Enter" && fetchEbayPrices()} placeholder="e.g. 2021 Panini Prizm Josh Allen PSA 10" style={{ ...S.input }} />
          <button onClick={fetchEbayPrices} disabled={ebayLoading} style={{ background: S.accent, color: S.bg, border: "none", borderRadius: 8, padding: "10px 20px", fontWeight: 800, fontSize: 14, cursor: "pointer", whiteSpace: "nowrap", opacity: ebayLoading ? 0.5 : 1 }}>
            {ebayLoading ? "…" : "Look Up"}
          </button>
        </div>
        {ebayLoading && (
          <div style={{ ...S.card, borderColor: "#1e3a8a55", background: "linear-gradient(145deg, #ffffff, #f8fafc)", padding: 20 }}>
            <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 14 }}>
              <div style={{ width: 8, height: 8, borderRadius: "50%", background: S.accent, animation: "pulse 1.2s infinite" }} />
              <div style={{ ...S.label, color: S.accent, marginBottom: 0 }}>Querying Live Comps...</div>
            </div>
            <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
              <div style={{ height: 12, width: "85%", background: "#cbd5e1", borderRadius: 4, animation: "pulse 1.5s infinite" }} />
              <div style={{ height: 12, width: "70%", background: "#cbd5e1", borderRadius: 4, animation: "pulse 1.5s infinite 0.2s" }} />
              <div style={{ height: 12, width: "90%", background: "#cbd5e1", borderRadius: 4, animation: "pulse 1.5s infinite 0.4s" }} />
            </div>
          </div>
        )}
        {!ebayLoading && ebayResult && (
          ebayResult === QUOTA_EXCEEDED
            ? <QuotaBanner />
            : ebayResult === INVALID_KEY
              ? <InvalidKeyBanner />
              : (
                <div style={{ ...S.card, borderColor: "#1e3a8a33" }}>
                  <div style={{ ...S.label, color: S.accent, marginBottom: 10 }}>Recent Sales: {ebayQuery}</div>
                  <div style={{ fontSize: 14, lineHeight: 1.8, color: "#475569" }}>{renderMarkdown(ebayResult)}</div>
                </div>
              )
        )}
      </div>
    </div>
  );
}

function HistoryTab({ cards }) {
  const [timeFilter, setTimeFilter] = useState("1Y");
  const totalValue = cards.reduce((s, c) => s + (c.currentValue * (c.quantity || 1)), 0);
  const totalCost = cards.reduce((s, c) => s + (c.purchasePrice * (c.quantity || 1)), 0);

  // Generate dynamic relative history that scales to the user's actual portfolio value based on card addition dates (addedAt)
  const data = useMemo(() => {
    const now = new Date();
    
    const getCutoff = (filter, label) => {
      const date = new Date(now);
      if (filter === "1D") {
        if (label === "Today") return date;
        const hourMap = { "9 AM": 9, "12 PM": 12, "3 PM": 15, "6 PM": 18, "9 PM": 21 };
        date.setHours(hourMap[label] || 12, 0, 0, 0);
        return date;
      }
      if (filter === "1W") {
        if (label === "Today") return date;
        const match = label.match(/^(\d+)d\sago$/);
        const daysAgo = match ? parseInt(match[1]) : 0;
        date.setDate(date.getDate() - daysAgo);
        date.setHours(23, 59, 59, 999);
        return date;
      }
      if (filter === "1M") {
        if (label === "Today") return date;
        const match = label.match(/^(\d+)w\sago$/);
        const weeksAgo = match ? parseInt(match[1]) : 0;
        date.setDate(date.getDate() - (weeksAgo * 7));
        date.setHours(23, 59, 59, 999);
        return date;
      }
      if (filter === "3Y" || filter === "5Y") {
        if (label === "Today") return date;
        const match = label.match(/^(\d+)y\sago$/);
        const yearsAgo = match ? parseInt(match[1]) : 0;
        date.setFullYear(date.getFullYear() - yearsAgo);
        date.setHours(23, 59, 59, 999);
        return date;
      }
      // 1Y Filter
      if (label === "Today") return date;
      const match = label.match(/^([A-Za-z]+)\s'(\d+)$/);
      if (match) {
        const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        const mIdx = monthNames.indexOf(match[1]);
        const year = 2000 + parseInt(match[2]);
        return new Date(year, mIdx + 1, 0, 23, 59, 59, 999); // last day of month
      }
      return date;
    };

    const getPortfolioValueAt = (cutoff) => {
      let total = 0;
      let hasAnyCard = false;
      cards.forEach((c) => {
        const addedDate = c.addedAt ? new Date(c.addedAt) : new Date(0);
        if (addedDate <= cutoff) {
          total += c.currentValue * (c.quantity || 1);
          hasAnyCard = true;
        }
      });
      // If we don't have any cards at this cutoff point, but the portfolio is NOT empty overall,
      // return a baseline of 0 so the chart shows a spike/progression.
      return hasAnyCard ? total : 0;
    };

    let points = [];
    if (timeFilter === "1D") {
      points = ["9 AM", "12 PM", "3 PM", "6 PM", "9 PM", "Today"].map((label) => ({
        month: label,
        value: getPortfolioValueAt(getCutoff("1D", label))
      }));
    } else if (timeFilter === "1W") {
      points = ["6d ago", "5d ago", "4d ago", "3d ago", "2d ago", "1d ago", "Today"].map((label) => ({
        month: label,
        value: getPortfolioValueAt(getCutoff("1W", label))
      }));
    } else if (timeFilter === "1M") {
      points = ["4w ago", "3w ago", "2w ago", "1w ago", "Today"].map((label) => ({
        month: label,
        value: getPortfolioValueAt(getCutoff("1M", label))
      }));
    } else if (timeFilter === "3Y") {
      points = ["3y ago", "2y ago", "1y ago", "Today"].map((label) => ({
        month: label,
        value: getPortfolioValueAt(getCutoff("3Y", label))
      }));
    } else if (timeFilter === "5Y") {
      points = ["5y ago", "4y ago", "3y ago", "2y ago", "1y ago", "Today"].map((label) => ({
        month: label,
        value: getPortfolioValueAt(getCutoff("5Y", label))
      }));
    } else { // 1Y
      const months = [];
      const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      for (let i = 11; i >= 0; i--) {
        const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
        const label = `${monthNames[d.getMonth()]} '${String(d.getFullYear()).slice(-2)}`;
        months.push(label);
      }
      points = months.map((label) => ({
        month: label,
        value: getPortfolioValueAt(getCutoff("1Y", label))
      }));
      points.push({ month: "Today", value: totalValue });
    }

    // Fallback if all values are 0 (e.g. empty portfolio), show beautiful mock data
    if (points.every(p => p.value === 0)) {
      const demoVal = 4810;
      const demoCost = 3200;
      const norm = [0.0, 0.24, 0.37, 0.26, 0.47, 0.63, 0.55, 0.74, 0.85, 1.0, 0.89, 0.85];
      if (timeFilter === "1D") {
        return ["9 AM", "12 PM", "3 PM", "6 PM", "9 PM", "Today"].map((h, idx) => ({ month: h, value: demoCost + (demoVal - demoCost) * [0, 0.1, 0.2, 0.3, 0.6, 1][idx] }));
      }
      const months = ["Jan '24", "Feb '24", "Mar '24", "Apr '24", "May '24", "Jun '24", "Jul '24", "Aug '24", "Sep '24", "Oct '24", "Nov '24", "Dec '24"];
      const historyData = months.map((m, idx) => ({ month: m, value: demoCost + (demoVal - demoCost) * norm[idx] }));
      return [...historyData, { month: "Today", value: demoVal }];
    }

    return points;
  }, [cards, totalValue, timeFilter]);

  const start = data[0].value;
  const end = data[data.length - 1].value;
  const overallGain = end - start;
  const overallPct = start > 0 ? ((overallGain / start) * 100).toFixed(1) : 0;
  const best = data.reduce((a, b) => (b.value > a.value ? b : a));
  const worst = data.reduce((a, b) => (b.value < a.value ? b : a));

  const getStartSub = () => {
    if (timeFilter === "1D") return "9:00 AM today";
    if (timeFilter === "1W") return "6 days ago";
    if (timeFilter === "1M") return "4 weeks ago";
    if (timeFilter === "3Y") return "3 years ago";
    if (timeFilter === "5Y") return "5 years ago";
    return data[0].month;
  };

  return (
    <div>
      <div style={S.label}>Portfolio History</div>

      <div className="grid-4 mb-24">
        {[
          { label: "Starting Value", value: fmt(start), sub: getStartSub() },
          { label: "Current Value", value: fmt(end), sub: "Today" },
          { label: ["1Y", "3Y", "5Y"].includes(timeFilter) ? "All-Time Gain" : "Period Gain", value: `${overallGain >= 0 ? "+" : ""}${fmt(overallGain)}`, sub: `${overallPct}%`, color: gainColor(overallGain) },
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
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 16 }}>
          <div style={{ ...S.label, marginBottom: 0 }}>Portfolio Value Over Time</div>
          <div style={{ display: "flex", gap: 6 }}>
            {["1D", "1W", "1M", "1Y", "3Y", "5Y"].map((f) => (
              <button key={f} onClick={() => setTimeFilter(f)} style={{
                background: timeFilter === f ? S.accent : "#f1f5f9",
                color: timeFilter === f ? "#ffffff" : S.muted,
                border: "none",
                borderRadius: 12,
                padding: "4px 12px",
                fontSize: 11,
                fontWeight: 700,
                cursor: "pointer",
                transition: "all 0.15s"
              }}>
                {f}
              </button>
            ))}
          </div>
        </div>
        <ResponsiveContainer width="100%" height={240}>
          <LineChart data={data} margin={{ top: 4, right: 8, left: 0, bottom: 0 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#e2e8f0" />
            <XAxis dataKey="month" tick={{ fill: "#64748b", fontSize: 11 }} axisLine={false} tickLine={false} />
            <YAxis tick={{ fill: "#64748b", fontSize: 11 }} axisLine={false} tickLine={false} tickFormatter={(v) => totalValue < 100 ? (totalValue < 10 ? `$${v.toFixed(2)}` : `$${v.toFixed(0)}`) : `$${(v / 1000).toFixed(1)}k`} />
            <Tooltip content={<ChartTooltip />} />
            <Line type="monotone" dataKey="value" stroke="#1e3a8a" strokeWidth={2.5} dot={false} activeDot={{ r: 5, fill: "#1e3a8a", stroke: "#ffffff", strokeWidth: 2 }} />
          </LineChart>
        </ResponsiveContainer>
      </div>

      <div className="grid-2">
        <div style={S.card}>
          <div style={{ ...S.label, marginBottom: 8 }}>Peak Value</div>
          <div style={{ fontSize: 22, fontWeight: 800, color: "#16a34a" }}>{fmt(best.value)}</div>
          <div style={{ fontSize: 12, color: S.muted }}>{best.month}</div>
        </div>
        <div style={S.card}>
          <div style={{ ...S.label, marginBottom: 8 }}>Monthly Low</div>
          <div style={{ fontSize: 22, fontWeight: 800, color: "#dc2626" }}>{fmt(worst.value)}</div>
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
  const [showProfileModal, setShowProfileModal] = useState(false);
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [passwordLoading, setPasswordLoading] = useState(false);
  const [passwordError, setPasswordError] = useState("");
  const [passwordSuccess, setPasswordSuccess] = useState("");

  const [tab, setTab] = useState(() => {
    const hash = window.location.hash.replace("#", "");
    const found = TABS.find(t => t.toLowerCase() === hash.toLowerCase());
    return found || "Portfolio";
  });
  const [cards, setCards] = useState([]);
  const [chatMessages, setChatMessages] = useState([
    { role: "assistant", content: "Hey! I'm your Kartis financial advisor. I know your full portfolio — ask me anything about valuations, buy/sell signals, grading strategy, or market trends." },
  ]);
  const [chatInput, setChatInput] = useState("");
  const [chatLoading, setChatLoading] = useState(false);
  const [showAddCard, setShowAddCard] = useState(false);
  const [newCard, setNewCard] = useState({ player: "", year: "", set: "", grade: "", sport: "Basketball", purchasePrice: "", currentValue: "", quantity: "1" });
  const [marketQuery, setMarketQuery] = useState("");
  const [marketResult, setMarketResult] = useState("");
  const [marketLoading, setMarketLoading] = useState(false);
  const [marketSearchResults, setMarketSearchResults] = useState([]);
  const [marketSearchLoading, setMarketSearchLoading] = useState(false);
  const [marketSearchError, setMarketSearchError] = useState("");
  const [analyzedCard, setAnalyzedCard] = useState(null);
  const [autoPricingLoading, setAutoPricingLoading] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const [searchResults, setSearchResults] = useState([]);
  const [searchCatalogLoading, setSearchCatalogLoading] = useState(false);
  const [searchError, setSearchError] = useState("");
  const [firebaseError, setFirebaseError] = useState("");
  const [saveSuccess, setSaveSuccess] = useState(false);
  const [toast, setToast] = useState({ visible: false, message: "", type: "success" });
  const showToast = (message, type = "success") => {
    setToast({ visible: true, message, type });
    setTimeout(() => {
      setToast(prev => ({ ...prev, visible: false }));
    }, 4500);
  };
  const [trendingMovements, setTrendingMovements] = useState(() => {
    const cached = localStorage.getItem("cardiq_trending_movements_v2");
    return cached ? JSON.parse(cached) : [
      { id: "2d14868b-f060-4830-85c8-44e1e9560b15", name: "Wembanyama Prizm RC", query: "2023 Panini Panini Prizm Draft Picks Victor Wembanyama (Base Set)", price: 40.00, change: 5.2, trend: "up" },
      { id: "9551abef-ed4b-4662-bcd3-181549e704b2", name: "Shohei Ohtani Chrome Auto", query: "2018 Bowman Chrome Shohei Ohtani RC Rookie #1 Angels", price: 1420.00, change: 8.5, trend: "up" },
      { id: "b2189857-ba5d-4552-9bef-592ed1da57c8", name: "Patrick Mahomes Prizm", query: "2017 Panini Prizm - Rookies Patrick Mahomes II #269 Silver Prizm (RC)", price: 2850.00, change: -2.4, trend: "down" },
      { id: "08271afe-a16d-444f-8366-a4230acce486", name: "Caitlin Clark Select RC", query: "2024 Caitlin Clark (Panini Select WNBA Base Set)", price: 92.00, change: 12.1, trend: "up" },
      { id: "403a7398-4b20-43c0-8cdb-cd78cfc8c78a", name: "Luka Doncic Prizm RC", query: "2018-19 Panini Prizm Luka Doncic Rookie Card #280", price: 150.00, change: 5.8, trend: "up" },
      { id: "9106f332-0bad-4507-8744-8cd5872b2703", name: "Connor Bedard Young Guns", query: "2023-24 Connor Bedard (Upper Deck Base Set)", price: 225.00, change: 14.5, trend: "up" }
    ];
  });
  const [loadingTrendingPrices, setLoadingTrendingPrices] = useState(false);
  const [trendingLastUpdated, setTrendingLastUpdated] = useState(() => {
    return localStorage.getItem("cardiq_trending_last_updated_v2") || "";
  });

  const getReadableLastUpdated = () => {
    if (!trendingLastUpdated) return "";
    const diffMs = new Date() - new Date(trendingLastUpdated);
    const diffMins = Math.floor(diffMs / (1000 * 60));
    if (diffMins < 1) return "Just now";
    if (diffMins < 60) return `${diffMins}m ago`;
    const diffHours = Math.floor(diffMins / 60);
    if (diffHours < 24) return `${diffHours}h ago`;
    return new Date(trendingLastUpdated).toLocaleDateString();
  };

  useEffect(() => {
    if (tab === "Market") {
      fetchTrendingPrices(false);
    }
  }, [tab]);

  useEffect(() => {
    window.location.hash = tab.toLowerCase();
  }, [tab]);

  useEffect(() => {
    const handleHashChange = () => {
      const hash = window.location.hash.replace("#", "");
      const found = TABS.find(t => t.toLowerCase() === hash.toLowerCase());
      if (found && found !== tab) {
        setTab(found);
      }
    };
    window.addEventListener("hashchange", handleHashChange);
    return () => window.removeEventListener("hashchange", handleHashChange);
  }, [tab]);

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

  // Read Chat History from Firestore
  useEffect(() => {
    if (!user) return;
    const unsubscribe = onSnapshot(doc(db, `users/${user.uid}/chats`, "history"), (docSnap) => {
      if (docSnap.exists() && docSnap.data().messages) {
        setChatMessages(docSnap.data().messages);
      }
    });
    return unsubscribe;
  }, [user]);

  useEffect(() => { chatEndRef.current?.scrollIntoView({ behavior: "smooth" }); }, [chatMessages]);

  const totalCost = cards.reduce((s, c) => s + (c.purchasePrice * (c.quantity || 1)), 0);
  const totalValue = cards.reduce((s, c) => s + (c.currentValue * (c.quantity || 1)), 0);
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

  const handlePasswordChange = async (e) => {
    e.preventDefault();
    if (newPassword !== confirmPassword) {
      setPasswordError("Passwords do not match.");
      return;
    }
    if (newPassword.length < 6) {
      setPasswordError("Password must be at least 6 characters long.");
      return;
    }
    setPasswordLoading(true);
    setPasswordError("");
    setPasswordSuccess("");
    try {
      await updatePassword(auth.currentUser, newPassword);
      setPasswordSuccess("Password updated successfully!");
      setNewPassword("");
      setConfirmPassword("");
    } catch (err) {
      if (err.code === 'auth/requires-recent-login') {
        setPasswordError("For security reasons, please sign out and sign back in to change your password.");
      } else {
        setPasswordError(err.message.replace("Firebase: ", ""));
      }
    } finally {
      setPasswordLoading(false);
    }
  };

  const saveChatHistory = async (messagesList) => {
    if (!user) return;
    try {
      await setDoc(doc(db, `users/${user.uid}/chats`, "history"), { messages: messagesList });
    } catch (e) {
      console.error("Error saving chat history: ", e);
    }
  };

  const sendChat = async () => {
    if (!chatInput.trim() || chatLoading) return;
    const userMsg = { role: "user", content: chatInput };
    const newHistory = [...chatMessages, userMsg];
    setChatMessages(newHistory);
    setChatInput("");
    setChatLoading(true);
    await saveChatHistory(newHistory);

    try {
      const ctx = cards.map((c) => `${c.quantity || 1}x ${c.year} ${c.player} (${c.set}, ${c.grade}) — bought ${fmt(c.purchasePrice)}, now ${fmt(c.currentValue)}`).join("\n");
      const trendsCtx = trendingMovements.map(t => `${t.name}: current price ${fmt(t.price)} (${t.change >= 0 ? '+' : ''}${t.change}% ${t.trend === 'up' ? '📈' : '📉'})`).join("\n");
      
      const system = `You are Kartis, the client's premium sports card financial advisor. Your sole purpose is to analyze the market, player performance/news, market trends, and the client's portfolio to tell them exactly when to BUY, SELL, or HOLD. You do all the analytical work and give clear, decisive instructions so the client does not have to think.

Client's Active Portfolio:
${ctx || "Empty portfolio"}
Total Invested: ${fmt(totalCost)} | Current Value: ${fmt(totalValue)} | Return: ${totalGainPct}%

Current Market Trends:
${trendsCtx}

Instructions:
- Take all portfolio details and current market trends, news, and pricing into account.
- Act as a decisive financial advisor. Tell the client exactly when to BUY, SELL, or HOLD specific cards in their portfolio or watchlists. Do not give generic or passive advice.
- When suggesting actions, prioritize the client's risk management and ROI maximization.
- Keep responses concise, direct, and under 200 words. Speak like a professional card fund manager. Use bold headings and clean formatting.`;

      const reply = await callChatGPT(newHistory.map((m) => ({ role: m.role, content: m.content })), system);
      const finalHistory = [...newHistory, { role: "assistant", content: reply }];
      setChatMessages(finalHistory);
      await saveChatHistory(finalHistory);
    } catch (err) {
      const errorHistory = [...newHistory, { role: "assistant", content: `⚠️ Something went wrong: ${err.message}. Please try again.` }];
      setChatMessages(errorHistory);
    } finally {
      setChatLoading(false);
    }
  };

  const fetchTrendingPrices = async (force = false) => {
    if (loadingTrendingPrices) return;

    // Cache check: if not forced, load from cache if less than 6 hours old
    const cachedData = localStorage.getItem("cardiq_trending_movements_v2");
    const cachedTime = localStorage.getItem("cardiq_trending_last_updated_v2");
    if (!force && cachedData && cachedTime) {
      const diffMs = new Date() - new Date(cachedTime);
      const diffHours = diffMs / (1000 * 60 * 60);
      if (diffHours < 6) { // Less than 6 hours old
        setTrendingMovements(JSON.parse(cachedData));
        return;
      }
    }

    setLoadingTrendingPrices(true);
    const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

    try {
      const cardIds = trendingMovements.map(item => item.id).filter(Boolean);
      console.log(`[CardSight] Fetching bulk pricing for ${cardIds.length} cards`);
      
      const bulkRes = await callCardSightAPI(`/v1/pricing/`, {
        method: "POST",
        body: JSON.stringify({
          card_ids: cardIds,
          period: "all",
          listing_type: "both"
        })
      });

      if (bulkRes === "__INVALID_KEY__" || bulkRes === "__QUOTA_EXCEEDED__") {
        console.warn("Bulk pricing lookup failed due to authentication or quota limits.");
        setLoadingTrendingPrices(false);
        return;
      }

      const resultsMap = {};
      if (bulkRes && Array.isArray(bulkRes.results)) {
        bulkRes.results.forEach(r => {
          resultsMap[r.card_id] = r;
        });
      }

      const updated = [];
      for (const item of trendingMovements) {
        let currentItem = { ...item };
        let finalPrice = 0;
        
        const result = resultsMap[item.id];
        if (result && result.success && result.data) {
          const pricingRes = result.data;
          const rawSales = pricingRes.raw?.records || [];
          const gradedSales = Array.isArray(pricingRes.graded) 
            ? pricingRes.graded 
            : (pricingRes.graded?.records || []);
          const sales = [...rawSales, ...gradedSales];
          let total = 0;
          let count = 0;
          sales.forEach(s => {
            const val = s.price !== undefined ? s.price : (s.price_usd !== undefined ? s.price_usd : s.value);
            if (val !== undefined && val !== null) {
              const p = parseFloat(String(val).replace(/[^0-9.]/g, '')) || 0;
              if (p > 0) {
                total += p;
                count++;
              }
            }
          });
          const avgPrice = count > 0 ? total / count : 0;
          finalPrice = pricingRes.averagePrice || pricingRes.average || avgPrice || 0;
        }

        // If completed sales price is 0, attempt marketplace active listings lookup as fallback
        if (finalPrice <= 0 && item.id) {
          try {
            console.log(`[CardSight] Fallback query to marketplace for ID: ${item.id}`);
            const marketRes = await callCardSightAPI(`/v1/marketplace/${item.id}`);
            if (marketRes && typeof marketRes === "object" && marketRes !== null) {
              const records = marketRes.raw?.records || (Array.isArray(marketRes.raw) ? marketRes.raw : []);
              let total = 0;
              let count = 0;
              records.forEach(r => {
                const val = r.price !== undefined ? r.price : (r.price_usd !== undefined ? r.price_usd : r.value);
                if (val !== undefined && val !== null) {
                  const p = parseFloat(String(val).replace(/[^0-9.]/g, '')) || 0;
                  if (p > 0) {
                    total += p;
                    count++;
                  }
                }
              });
              if (count > 0) {
                finalPrice = total / count;
              }
            }
          } catch (err) {
            console.warn(`Marketplace fallback failed for ID: ${item.id}`, err);
          }
          // Brief throttle sleep to respect rate limit of fallback queries
          await sleep(400);
        }

        if (finalPrice > 0) {
          const baseline = item.price;
          const changePct = baseline > 0 ? parseFloat((((finalPrice - baseline) / baseline) * 100).toFixed(1)) : 0;
          currentItem = {
            ...item,
            price: finalPrice,
            change: changePct,
            trend: changePct > 0 ? "up" : (changePct < 0 ? "down" : "up")
          };
        } else {
          currentItem = {
            ...item,
            price: 0,
            change: 0,
            trend: "up"
          };
        }
        updated.push(currentItem);
      }

      setTrendingMovements(updated);
      const nowStr = new Date().toISOString();
      setTrendingLastUpdated(nowStr);
      localStorage.setItem("cardiq_trending_movements_v2", JSON.stringify(updated));
      localStorage.setItem("cardiq_trending_last_updated_v2", nowStr);
      showToast("Trending market movements updated with live CardSight AI bulk pricing.", "success");
    } catch (err) {
      console.error("Failed to load trending prices:", err);
    } finally {
      setLoadingTrendingPrices(false);
    }
  };

  const handleTrendingClick = (item) => {
    setMarketQuery(item.query);
    runMarketSearchWithQuery(item.query);
  };

  const runMarketSearchWithQuery = async (queryStr) => {
    const q = queryStr || marketQuery;
    if (!q.trim() || marketSearchLoading) return;
    setMarketSearchLoading(true);
    setMarketSearchResults([]);
    setMarketSearchError("");
    setMarketResult("");
    setAnalyzedCard(null);
    try {
      const searchRes = await callCardSightAPI(`/v1/catalog/search?q=${encodeURIComponent(q)}`);
      if (searchRes === "__INVALID_KEY__") {
        setMarketSearchError("CardSight AI API key invalid. Check VITE_CARDSIGHTAI_API_KEY.");
        return;
      }
      if (searchRes === "__QUOTA_EXCEEDED__") {
        setMarketSearchError("CardSight AI rate limit exceeded.");
        return;
      }
      const results = searchRes?.results || searchRes?.data;
      if (searchRes && Array.isArray(results) && results.length > 0) {
        setMarketSearchResults(results.slice(0, 8));
      } else {
        setMarketSearchError("No matching cards found. Try a different query.");
      }
    } catch (e) {
      console.warn("CardSight catalog search failed:", e);
      setMarketSearchError("Search failed. Please try again.");
    } finally {
      setMarketSearchLoading(false);
    }
  };

  const runMarketAnalysisForCard = async (card) => {
    if (marketLoading) return;
    setMarketLoading(true);
    setMarketResult("");
    setAnalyzedCard(card);
    try {
      let apiContext = "";
      
      // Step 1: Fetch pricing
      let pricingData = null;
      try {
        pricingData = await callCardSightAPI(`/v1/pricing/${card.id}`);
      } catch (e) {
        console.warn("Pricing fetch failed for market analysis:", e);
      }
      
      // Step 2: Fetch marketplace
      let marketData = null;
      try {
        marketData = await callCardSightAPI(`/v1/marketplace/${card.id}`);
      } catch (e) {
        console.warn("Marketplace fetch failed for market analysis:", e);
      }
      
      const rawSales = pricingData?.raw?.records || [];
      const gradedSales = Array.isArray(pricingData?.graded) 
        ? pricingData.graded 
        : (pricingData?.graded?.records || []);
      const allComps = [...rawSales, ...gradedSales].slice(0, 10);
      
      const compsList = allComps.map(s => {
        const price = s.price !== undefined ? s.price : (s.price_usd !== undefined ? s.price_usd : s.value);
        return `- Date: ${s.date || s.sold_date || 'Recent'}, Price: ${fmt(price)}, Grade: ${s.grade || 'Raw'}, Source: ${s.source || 'eBay'}`;
      }).join("\n");
      
      const activeListings = (marketData?.raw?.records || (Array.isArray(marketData?.raw) ? marketData.raw : [])).slice(0, 5);
      const activesList = activeListings.map(a => {
        const price = a.price !== undefined ? a.price : (a.price_usd !== undefined ? a.price_usd : a.value);
        return `- Active Listing: ${a.title || card.name}, Price: ${fmt(price)}`;
      }).join("\n");
      
      apiContext = `
Card Details from Catalog API:
- Name: ${card.name || card.player}
- Year: ${card.year}
- Set/Product: ${card.releaseName || ''} ${card.setName || ''}
- Parallel/Variation: ${card.parallelName || 'Base'}
- Sport: ${detectSport(card.name, card.releaseName, card.setName)}

Real-Time Market Comps:
${compsList || "No completed sales records found."}

Active Listings:
${activesList || "No active listings found."}
`;

      const system = `You are an expert sports card market analyst and financial advisor.
You MUST analyze the card using the real-time CardSight AI API data provided below.
In addition to the API data, you must integrate recent player news, performance trends (injuries, hot streaks, trades, college stats vs pro projection), and overall market trends for the sport and set.
To prevent hallucinating card values, you must strictly align your advice with the actual pricing comps and active listings provided in the Live API Data. Do not invent or assume sales prices or active listings that contradict the provided data. If the data is empty or indicates the card does not exist yet, base your advice on draft expectations, comparable player trends, and state this clearly.

You MUST format your output using EXACTLY the following five bold headings (no variations, no extra headings, no missing headings):
**1. Current Price Ranges & Grade Premium Spreads**
[Analysis of price ranges, raw vs graded spread, and comps here]

**2. Trend Direction**
[Analysis of recent transaction dates and price movement directions here]

**3. Player News & Latest Performance Context**
[Analysis of recent player performance, injuries, stats, projection, and news here]

**4. Key Value Drivers**
[Analysis of set popularity, rookie card status, print runs, and scarcity here]

**5. Recommendation & Justification**
[Clear BUY / HOLD / SELL recommendation with reasoning based on the above sections here]

Keep the analysis professional, specific with numbers, and under 250 words.`;
      
      const prompt = `Analyze the sports card market for: "${card.year} ${card.name} ${card.releaseName} ${card.parallelName}"\n\nLive API Data:\n${apiContext}`;
      
      const result = await callChatGPT([{ role: "user", content: prompt }], system);
      setMarketResult(result);
    } catch (err) {
      setMarketResult(`⚠️ Failed to fetch analysis: ${err.message}`);
    } finally {
      setMarketLoading(false);
    }
  };

  const runAutoPricing = async () => {
    if (!newCard.player) return;
    setAutoPricingLoading(true);
    setSearchError("");
    try {
      const searchRes = await callCardSightAPI(`/v1/catalog/search?q=${encodeURIComponent(`${newCard.year} ${newCard.player} ${newCard.set}`)}`);
      if (searchRes === "__INVALID_KEY__") {
        setSearchError("CardSight AI API key invalid. Check VITE_CARDSIGHTAI_API_KEY.");
        setAutoPricingLoading(false);
        return;
      }
      if (searchRes === "__QUOTA_EXCEEDED__") {
        setSearchError("CardSight AI rate limit exceeded.");
        setAutoPricingLoading(false);
        return;
      }
      const searchResults = searchRes?.results || searchRes?.data;
      if (searchRes && searchResults && searchResults.length > 0) {
        const cardId = searchResults[0].id;
        const pricingRes = await callCardSightAPI(`/v1/pricing/${cardId}`);
        if (pricingRes && typeof pricingRes === "object" && pricingRes !== null) {
          const rawSales = pricingRes.raw?.records || [];
          const gradedSales = Array.isArray(pricingRes.graded) 
            ? pricingRes.graded 
            : (pricingRes.graded?.records || []);
          const sales = [...rawSales, ...gradedSales];
          let total = 0;
          let count = 0;
          sales.forEach(s => {
            const val = s.price !== undefined ? s.price : (s.price_usd !== undefined ? s.price_usd : s.value);
            if (val !== undefined && val !== null) {
              const p = parseFloat(String(val).replace(/[^0-9.]/g, '')) || 0;
              if (p > 0) {
                total += p;
                count++;
              }
            }
          });
          const avgPrice = count > 0 ? total / count : 0;
          if (avgPrice > 0) {
            setNewCard((prev) => ({ ...prev, currentValue: avgPrice }));
            setAutoPricingLoading(false);
            return;
          }
        }
      }
    } catch (e) {
      console.warn("CardSight auto-pricing failed, falling back to simulation:", e);
    }

    // Fallback: OpenAI simulation
    const system = "You are a sports card valuation tool. Reply with ONLY a single raw number representing the estimated market value of the card requested. No dollar signs, no units, no text (e.g. 450).";
    try {
      const result = await callChatGPT([{ role: "user", content: `Estimated market value of sports card: ${newCard.year} ${newCard.player} ${newCard.set} ${newCard.grade}` }], system);
      if (result === QUOTA_EXCEEDED) {
        setSearchError("QUOTA_EXCEEDED");
        setAutoPricingLoading(false);
        return;
      }
      if (result === INVALID_KEY) {
        setSearchError("INVALID_KEY");
        setAutoPricingLoading(false);
        return;
      }
      const cleanedPrice = parseFloat(result.replace(/[^0-9.]/g, '')) || 0.0;
      setNewCard((prev) => ({ ...prev, currentValue: cleanedPrice }));
    } catch (e) {
      console.error("Auto-pricing simulation failed:", e);
    } finally {
      setAutoPricingLoading(false);
    }
  };

  const [syncingPrices, setSyncingPrices] = useState(false);
  const syncPortfolioPrices = async () => {
    if (syncingPrices || !cards.length) return;
    setSyncingPrices(true);
    setFirebaseError("");
    try {
      let updatedCount = 0;
      for (const card of cards) {
        const qStr = `${card.year} ${card.player} ${card.set}`;
        const searchRes = await callCardSightAPI(`/v1/catalog/search?q=${encodeURIComponent(qStr)}`);
        const searchResults = searchRes?.results || searchRes?.data;
        if (searchRes && searchResults && searchResults.length > 0) {
          const cardId = searchResults[0].id;
          const newPrice = await fetchCardPrice(cardId);
          if (newPrice > 0 && Math.round(newPrice) !== Math.round(card.currentValue)) {
            const cardRef = doc(db, `users/${user.uid}/portfolios`, card.id);
            await updateDoc(cardRef, {
              currentValue: newPrice
            });
            updatedCount++;
          }
        }
      }
      showToast(`Sync Complete! Updated live valuations for ${updatedCount} cards using fresh CardSight AI comps.`, "success");
    } catch (err) {
      console.error("Failed to sync portfolio prices:", err);
      setFirebaseError(`Price sync failed: ${err.message}`);
    } finally {
      setSyncingPrices(false);
    }
  };

  const runCatalogSearch = async () => {
    if (!searchQuery.trim()) return;
    setSearchCatalogLoading(true);
    setSearchResults([]);
    setSearchError("");
    try {
      const apiRes = await callCardSightAPI(`/v1/catalog/search?q=${encodeURIComponent(searchQuery)}`);
      if (apiRes === "__INVALID_KEY__") {
        setSearchError("CardSight AI API key invalid. Check VITE_CARDSIGHTAI_API_KEY.");
        setSearchCatalogLoading(false);
        return;
      }
      if (apiRes === "__QUOTA_EXCEEDED__") {
        setSearchError("CardSight AI rate limit exceeded.");
        setSearchCatalogLoading(false);
        return;
      }
      const results = apiRes?.results || apiRes?.data;
      if (apiRes && results && Array.isArray(results)) {
        const mappedPromises = results.slice(0, 5).map(async (item) => {
          const price = await fetchCardPrice(item.id);
          const detected = detectSport(item.name, item.releaseName, item.setName);
          const setDesc = `${item.releaseName || ""} ${item.setName || ""}${item.parallelName ? " (" + item.parallelName + ")" : ""}`.trim();
          return {
            player: item.name || item.player || "",
            year: parseInt(item.year) || new Date().getFullYear(),
            set: setDesc,
            sport: detected,
            estimatedPrice: price
          };
        });
        const mapped = await Promise.all(mappedPromises);
        setSearchResults(mapped);
        setSearchCatalogLoading(false);
        return;
      }
    } catch (e) {
      console.warn("CardSight catalog search failed, falling back to simulation:", e);
    }

    // Fallback: OpenAI simulation
    const system = "You are a sports card database API. Return ONLY a raw JSON array (no markdown, no code blocks, no explanation) of exactly 3 matching sports cards. Each object must have: 'player' (string), 'year' (number), 'set' (string), 'sport' (Basketball|Baseball|Football|Hockey|Soccer), 'estimatedPrice' (number). Example: [{\"player\":\"LeBron James\",\"year\":2003,\"set\":\"Topps\",\"sport\":\"Basketball\",\"estimatedPrice\":800}]";
    try {
      const result = await callChatGPT([{ role: "user", content: `Find sports cards matching: ${searchQuery}` }], system);
      if (result === QUOTA_EXCEEDED) {
        setSearchError("QUOTA_EXCEEDED");
        return;
      }
      if (result === INVALID_KEY) {
        setSearchError("INVALID_KEY");
        return;
      }
      const startIndex = result.indexOf("[");
      const endIndex = result.lastIndexOf("]") + 1;
      if (startIndex === -1 || endIndex <= 0) {
        setSearchError("No results returned. Try a more specific search (e.g. '2003 LeBron James Topps').");
        return;
      }
      const parsed = JSON.parse(result.substring(startIndex, endIndex));
      if (!Array.isArray(parsed) || parsed.length === 0) {
        setSearchError("No matching cards found. Try a different search.");
        return;
      }
      setSearchResults(parsed);
    } catch (e) {
      console.error("Failed parsing search results: ", e);
      setSearchError("Parse error — try again with a different search term.");
    } finally {
      setSearchCatalogLoading(false);
    }
  };

  const addCard = async () => {
    if (!newCard.player || !newCard.purchasePrice || !newCard.currentValue) return;
    setFirebaseError("");
    try {
      await addDoc(collection(db, `users/${user.uid}/portfolios`), {
        ...newCard,
        year: parseInt(newCard.year) || new Date().getFullYear(),
        purchasePrice: parseFloat(newCard.purchasePrice),
        currentValue: parseFloat(newCard.currentValue),
        quantity: parseInt(newCard.quantity) || 1,
        addedAt: new Date().toISOString()
      });
      setNewCard({ player: "", year: "", set: "", grade: "", sport: "Basketball", purchasePrice: "", currentValue: "", quantity: "1" });
      setSearchQuery("");
      setSearchResults([]);
      setSearchError("");
      setShowAddCard(false);
      setSaveSuccess(true);
      setTimeout(() => setSaveSuccess(false), 3000);
    } catch (e) {
      console.error("Firestore addCard error:", e);
      setFirebaseError(`❌ Failed to save card: ${e.message}. Check Firestore rules at console.firebase.google.com`);
    }
  };

  const removeCard = async (id) => {
    setFirebaseError("");
    try {
      await deleteDoc(doc(db, `users/${user.uid}/portfolios`, id));
    } catch (e) {
      console.error("Firestore removeCard error:", e);
      setFirebaseError(`❌ Failed to delete card: ${e.message}`);
    }
  };

  if (authLoading) {
    return (
      <div style={{ height: "100vh", display: "flex", justifyContent: "center", alignItems: "center", background: S.bg, color: S.text }}>
        <div style={{ fontSize: 16, color: S.accent, fontWeight: 700 }}>Kartis Loading...</div>
      </div>
    );
  }

  if (!user) {
    return (
      <div style={{ height: "100vh", display: "flex", justifyContent: "center", alignItems: "center", background: S.bg, fontFamily: "'Inter', sans-serif" }}>
        <div style={{ ...S.card, width: 380, padding: 30, background: "linear-gradient(145deg, #ffffff, #f8fafc)", border: "1px solid #cbd5e1" }}>
          <div style={{ textAlign: "center", marginBottom: 24, display: "flex", flexDirection: "column", alignItems: "center" }}>
            <img src={LogoImg} alt="Kartis Logo" style={{ height: 42, marginBottom: 10 }} />
            <span style={{ fontSize: 28, fontWeight: 900, color: S.text, letterSpacing: "-1px" }}>Kart<span style={{ color: S.accent }}>is</span></span>
            <div style={{ fontSize: 12, color: S.muted, marginTop: 4 }}>Sports Card Investment & AI Advisor</div>
          </div>
          <form onSubmit={handleAuth} style={{ display: "flex", flexDirection: "column", gap: 14 }}>
            <input type="email" placeholder="Email Address" value={email} onChange={(e) => setEmail(e.target.value)} style={S.input} required />
            <input type="password" placeholder="Password" value={password} onChange={(e) => setPassword(e.target.value)} style={S.input} required />
            
            {authError && <div style={{ fontSize: 13, color: "#ef4444", textAlign: "center" }}>{authError}</div>}
            
            <button type="submit" style={{ background: S.accent, color: "#ffffff", border: "none", borderRadius: 8, padding: "12px", fontWeight: 800, fontSize: 14, cursor: "pointer", transition: "opacity 0.2s" }}>
              {isSignUp ? "Create Account" : "Sign In"}
            </button>
          </form>
          <div style={{ textAlign: "center", marginTop: 20, fontSize: 13, color: S.muted }}>
            {isSignUp ? "Already have an account? " : "New to Kartis? "}
            <span onClick={() => { setIsSignUp(!isSignUp); setAuthError(""); }} style={{ color: S.accent, cursor: "pointer", fontWeight: 600 }}>
              {isSignUp ? "Sign In" : "Sign Up"}
            </span>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div style={{ minHeight: "100vh", width: "100%", background: S.bg, color: S.text, fontFamily: "'Inter', -apple-system, sans-serif", paddingBottom: 60, textAlign: "left" }}>

      {/* Header */}
      <div className="app-header">
        <div className="header-top">
          <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
            <img src={LogoImg} alt="Kartis" style={{ height: 48, width: "auto", display: "block" }} />
            <span className="header-subtitle" style={{ fontSize: 11, fontWeight: 600, letterSpacing: "0.14em", color: S.muted, textTransform: "uppercase" }}>Sports Card Advisor</span>
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <span className="header-email" style={{ fontSize: 12, color: S.muted }}>{user.email}</span>
            <button onClick={() => setShowProfileModal(true)} style={{ background: "none", border: "1px solid #cbd5e1", borderRadius: 6, color: S.accent, padding: "4px 10px", fontSize: 11, cursor: "pointer", whiteSpace: "nowrap" }}>Profile</button>
            <button onClick={handleLogout} style={{ background: "none", border: "1px solid #cbd5e1", borderRadius: 6, color: S.text, padding: "4px 10px", fontSize: 11, cursor: "pointer", whiteSpace: "nowrap" }}>Sign Out</button>
          </div>
        </div>
        <div style={{ display: "flex", gap: 0, marginTop: 14, overflowX: "auto", WebkitOverflowScrolling: "touch" }}>
          {TABS.map((t) => (
            <button key={t} onClick={() => setTab(t)} style={{ padding: "10px 14px", background: "none", border: "none", borderBottom: tab === t ? `2px solid ${S.accent}` : "2px solid transparent", color: tab === t ? S.accent : S.muted, fontWeight: tab === t ? 700 : 400, fontSize: 13, cursor: "pointer", transition: "all 0.15s", whiteSpace: "nowrap", letterSpacing: "0.02em" }}>
              {t}
            </button>
          ))}
        </div>
      </div>

      <div className="app-content">

        {/* ── PORTFOLIO ── */}
        {tab === "Portfolio" && (
          <div>
            <div className="grid-3 mb-24">
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

            {/* Firebase error banner */}
            {firebaseError && (
              <div style={{ background: "#fee2e2", border: "1px solid #fca5a5", borderRadius: 8, padding: "12px 16px", marginBottom: 14, display: "flex", alignItems: "flex-start", gap: 10 }}>
                <div style={{ fontSize: 16 }}>❌</div>
                <div style={{ flex: 1 }}>
                  <div style={{ color: "#b91c1c", fontWeight: 700, fontSize: 13, marginBottom: 4 }}>Firebase Error</div>
                  <div style={{ color: "#991b1b", fontSize: 12, lineHeight: 1.6 }}>{firebaseError}</div>
                  <div style={{ marginTop: 8 }}>
                    <a href="https://console.firebase.google.com/project/cardiq-f2cbb/firestore/rules" target="_blank" rel="noreferrer" style={{ color: S.accent, fontSize: 12, fontWeight: 700 }}>Fix Firestore Rules →</a>
                  </div>
                </div>
                <button onClick={() => setFirebaseError("")} style={{ background: "none", border: "none", color: "#b91c1c", cursor: "pointer", fontSize: 16 }}>×</button>
              </div>
            )}

            {/* Save success toast */}
            {saveSuccess && (
              <div style={{ background: "#dcfce7", border: "1px solid #bbf7d0", borderRadius: 8, padding: "10px 16px", marginBottom: 14, display: "flex", alignItems: "center", gap: 10 }}>
                <span style={{ fontSize: 16 }}>✅</span>
                <span style={{ color: "#166534", fontSize: 13, fontWeight: 700 }}>Card saved to your portfolio!</span>
              </div>
            )}

            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 12 }}>
              <span style={{ ...S.label, marginBottom: 0 }}>Collection</span>
              <div style={{ display: "flex", gap: 10 }}>
                <button onClick={syncPortfolioPrices} disabled={syncingPrices} style={{ background: "none", border: `1px solid ${S.accent}`, color: S.accent, borderRadius: 6, padding: "7px 14px", fontSize: 12, fontWeight: 700, cursor: "pointer", opacity: syncingPrices ? 0.5 : 1 }}>
                  {syncingPrices ? "Syncing..." : "🔄 Sync Live Prices"}
                </button>
                <button onClick={() => {
                  if (showAddCard) {
                    setNewCard({ player: "", year: "", set: "", grade: "", sport: "Basketball", purchasePrice: "", currentValue: "", quantity: "1" });
                    setSearchQuery("");
                    setSearchResults([]);
                    setSearchError("");
                  }
                  setShowAddCard(!showAddCard);
                }} style={{ background: S.accent, color: S.bg, border: "none", borderRadius: 6, padding: "7px 14px", fontSize: 12, fontWeight: 700, cursor: "pointer" }}>+ Add Card</button>
              </div>
            </div>

            {showAddCard && (
              <div style={{ ...S.card, borderColor: "#1e3a8a33", marginBottom: 14 }}>
                <div style={{ borderBottom: "1px solid #e2e8f0", paddingBottom: 14, marginBottom: 14 }}>
                  <div style={S.label}>Search Card Catalog</div>
                  <div style={{ display: "flex", gap: 10 }}>
                    <input value={searchQuery} onChange={(e) => setSearchQuery(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && runCatalogSearch()} placeholder="e.g. 2003 LeBron James Topps" style={S.input} />
                    <button type="button" onClick={runCatalogSearch} disabled={searchCatalogLoading} style={{ background: S.accent, border: "none", borderRadius: 8, padding: "0 20px", color: S.bg, fontWeight: 700, fontSize: 13, cursor: "pointer", opacity: searchCatalogLoading ? 0.5 : 1 }}>
                      {searchCatalogLoading ? "Searching..." : "Search"}
                    </button>
                  </div>
                  {searchCatalogLoading && (
                    <div style={{ marginTop: 10, display: "flex", flexDirection: "column", gap: 6, background: "#f8fafc", border: "1px solid #cbd5e1", borderRadius: 8, padding: 12 }}>
                      {[1, 2, 3].map((i) => (
                        <div key={i} style={{ display: "flex", justifyContent: "space-between", padding: "8px 10px", borderRadius: 6, background: "#f1f5f9", animation: "pulse 1.5s infinite ease-in-out" }}>
                          <div style={{ height: 14, width: "60%", background: "#cbd5e1", borderRadius: 4 }} />
                          <div style={{ height: 14, width: "15%", background: S.accent, opacity: 0.3, borderRadius: 4 }} />
                        </div>
                      ))}
                    </div>
                  )}
                  {searchError && (
                    searchError === "QUOTA_EXCEEDED"
                      ? <QuotaBanner />
                      : searchError === "INVALID_KEY"
                        ? <InvalidKeyBanner />
                        : (
                          <div style={{ marginTop: 10, color: "#ef4444", fontSize: 13, background: "#ef444411", padding: "10px 12px", borderRadius: 8, border: "1px solid #ef444433" }}>
                            {searchError}
                          </div>
                        )
                  )}
                  {!searchCatalogLoading && searchResults.length > 0 && (
                    <div style={{ marginTop: 10, display: "flex", flexDirection: "column", gap: 6, maxHeight: 150, overflowY: "auto", background: "#f8fafc", border: "1px solid #cbd5e1", borderRadius: 8, padding: 8 }}>
                      {searchResults.map((item, idx) => (
                        <div key={idx} onClick={() => {
                          setNewCard({
                            player: item.player,
                            year: item.year,
                            set: item.set,
                            grade: "Raw",
                            sport: item.sport,
                            purchasePrice: item.estimatedPrice,
                            currentValue: item.estimatedPrice,
                            quantity: "1"
                          });
                          setSearchResults([]);
                        }} style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "8px 10px", cursor: "pointer", borderRadius: 6, borderBottom: "1px solid #e2e8f0", transition: "background 0.2s" }} onMouseEnter={(e) => e.currentTarget.style.backgroundColor = '#f1f5f9'} onMouseLeave={(e) => e.currentTarget.style.backgroundColor = 'transparent'}>
                          <span style={{ fontSize: 13 }}>{item.year} {item.player} ({item.set}) - {item.sport}</span>
                          <span style={{ color: S.accent, fontWeight: 700, fontSize: 13 }}>{fmt(item.estimatedPrice)}</span>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
                <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
                  {[
                    { k: "player", ph: "Player" }, { k: "year", ph: "Year" },
                    { k: "set", ph: "Set / Product" }, { k: "grade", ph: "Grade (e.g. PSA 10)" },
                    { k: "purchasePrice", ph: "Purchase Price ($)" }, { k: "currentValue", ph: "Current Value ($)" },
                    { k: "quantity", ph: "Quantity" },
                  ].map((f) => (
                    <input key={f.k} value={newCard[f.k]} onChange={(e) => setNewCard({ ...newCard, [f.k]: e.target.value })} placeholder={f.ph} style={S.input} />
                  ))}
                  <select value={newCard.sport} onChange={(e) => setNewCard({ ...newCard, sport: e.target.value })} style={S.input}>
                    {["Basketball", "Baseball", "Football", "Hockey", "Soccer"].map((s) => <option key={s}>{s}</option>)}
                  </select>
                </div>
                <div style={{ display: "flex", gap: 8, marginTop: 12 }}>
                  <button onClick={addCard} style={{ background: S.accent, color: S.bg, border: "none", borderRadius: 6, padding: "8px 18px", fontSize: 13, fontWeight: 700, cursor: "pointer" }}>Save</button>
                  <button onClick={runAutoPricing} disabled={autoPricingLoading} style={{ background: "none", border: "1px solid #cbd5e1", borderRadius: 6, padding: "8px 18px", fontSize: 13, color: S.accent, cursor: "pointer" }}>
                    {autoPricingLoading ? "Loading Price..." : "AI Auto-Price Estimation"}
                  </button>
                  <button onClick={() => {
                    setNewCard({ player: "", year: "", set: "", grade: "", sport: "Basketball", purchasePrice: "", currentValue: "", quantity: "1" });
                    setSearchQuery("");
                    setSearchResults([]);
                    setSearchError("");
                    setShowAddCard(false);
                  }} style={{ background: "none", color: S.muted, border: "1px solid #cbd5e1", borderRadius: 6, padding: "8px 18px", fontSize: 13, cursor: "pointer" }}>Cancel</button>
                </div>
              </div>
            )}

            <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
              {cards.map((card) => {
                const qty = card.quantity || 1;
                const cost = card.purchasePrice * qty;
                const value = card.currentValue * qty;
                const gain = value - cost;
                const gainPct = cost > 0 ? ((gain / cost) * 100).toFixed(1) : 0;
                return (
                  <div key={card.id} style={{ ...S.card, display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                    <div>
                      <div style={{ fontWeight: 700, fontSize: 15 }}>{qty}x {card.year} {card.player}</div>
                      <div style={{ fontSize: 12, color: S.muted, marginTop: 3 }}>{card.set} · {card.grade} · {card.sport}</div>
                    </div>
                    <div style={{ display: "flex", alignItems: "center", gap: 20 }}>
                      <div style={{ textAlign: "right" }}>
                        <div style={{ fontSize: 16, fontWeight: 800 }}>{fmt(value)}</div>
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
                <button key={p} onClick={() => setChatInput(p)} style={{ background: "#f8fafc", border: "1px solid #cbd5e1", borderRadius: 20, padding: "6px 13px", fontSize: 12, color: S.muted, cursor: "pointer" }}>{p}</button>
              ))}
            </div>
            <div style={{ flex: 1, overflowY: "auto", display: "flex", flexDirection: "column", gap: 14, paddingBottom: 16 }}>
              {chatMessages.map((m, i) => (
                <div key={i} style={{ display: "flex", justifyContent: m.role === "user" ? "flex-end" : "flex-start" }}>
                  <div style={{ maxWidth: "80%", background: m.role === "user" ? S.accent : "#f1f5f9", border: m.role === "assistant" ? "1px solid #e2e8f0" : "none", borderRadius: m.role === "user" ? "18px 18px 4px 18px" : "18px 18px 18px 4px", padding: "12px 16px", fontSize: 14, lineHeight: 1.65, color: m.role === "user" ? "#ffffff" : S.text, fontWeight: m.role === "user" ? 600 : 400 }}>
                    {m.role === "user"
                      ? m.content
                      : m.content === QUOTA_EXCEEDED
                        ? <QuotaBanner />
                        : m.content === INVALID_KEY
                          ? <InvalidKeyBanner />
                          : renderMarkdown(m.content)
                    }
                  </div>
                </div>
              ))}
              {chatLoading && (
                <div style={{ display: "flex", gap: 5, paddingLeft: 4 }}>
                  {[0, 1, 2].map((i) => <div key={i} style={{ width: 8, height: 8, borderRadius: "50%", background: S.accent, opacity: 0.4, animation: `pulse 1.2s ${i * 0.2}s infinite` }} />)}
                </div>
              )}
              <div ref={chatEndRef} />
            </div>
            <div style={{ display: "flex", gap: 10, paddingTop: 12, borderTop: "1px solid #e2e8f0" }}>
              <input value={chatInput} onChange={(e) => setChatInput(e.target.value)} onKeyDown={(e) => e.key === "Enter" && sendChat()} placeholder="Ask about any card, player, trend…" style={{ ...S.input }} />
              <button onClick={sendChat} disabled={chatLoading} style={{ background: S.accent, border: "none", borderRadius: 10, padding: "12px 20px", color: S.bg, fontWeight: 800, fontSize: 14, cursor: "pointer", opacity: chatLoading ? 0.5 : 1 }}>→</button>
            </div>
          </div>
        )}

        {/* ── MARKET ── */}
        {tab === "Market" && (
          <div>
            <div style={{ ...S.label, marginBottom: 4 }}>Market Intelligence</div>
            <div style={{ fontSize: 13, color: S.muted, marginBottom: 16 }}>Enter any player, card, or set to search the database and run a buy/hold/sell analysis.</div>
            <div style={{ display: "flex", gap: 10, marginBottom: 16 }}>
              <input value={marketQuery} onChange={(e) => setMarketQuery(e.target.value)} onKeyDown={(e) => e.key === "Enter" && runMarketSearchWithQuery()} placeholder="e.g. 2018 Luka Dončić Prizm PSA 10" style={{ ...S.input }} />
              <button onClick={() => runMarketSearchWithQuery()} disabled={marketSearchLoading} style={{ background: S.accent, border: "none", borderRadius: 8, padding: "10px 20px", color: S.bg, fontWeight: 800, fontSize: 14, cursor: "pointer", whiteSpace: "nowrap", opacity: marketSearchLoading ? 0.5 : 1 }}>
                {marketSearchLoading ? "Searching..." : "Search"}
              </button>
            </div>

            {marketSearchError && (
              <div style={{ color: "#ef4444", fontSize: 13, background: "#ef444411", padding: "10px 12px", borderRadius: 8, border: "1px solid #ef444433", marginBottom: 16 }}>
                {marketSearchError}
              </div>
            )}

            {marketSearchResults.length > 0 && (
              <div style={{ ...S.card, borderColor: "#cbd5e1", marginBottom: 20, background: "#f8fafc" }}>
                <div style={{ ...S.label, marginBottom: 8 }}>Matching Cards (Select one to analyze)</div>
                <div style={{ display: "flex", flexDirection: "column", gap: 8, maxHeight: 220, overflowY: "auto" }}>
                  {marketSearchResults.map((card) => (
                    <div key={card.id} style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "10px 12px", background: "#ffffff", border: "1px solid #e2e8f0", borderRadius: 8 }}>
                      <span style={{ fontSize: 13, fontWeight: 600, color: S.text, marginRight: 10 }}>
                        {card.year} {card.name || card.player} {card.releaseName || ''} {card.setName || ''} {card.parallelName ? `(${card.parallelName})` : ''}
                      </span>
                      <button onClick={() => { runMarketAnalysisForCard(card); setMarketSearchResults([]); }} disabled={marketLoading} style={{ background: S.accent, color: "#ffffff", border: "none", borderRadius: 6, padding: "6px 12px", fontSize: 12, fontWeight: 700, cursor: "pointer", opacity: marketLoading ? 0.5 : 1, whiteSpace: "nowrap" }}>
                        {marketLoading && analyzedCard?.id === card.id ? "Analyzing..." : "Analyze"}
                      </button>
                    </div>
                  ))}
                </div>
              </div>
            )}
             <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 12 }}>
              <div style={{ fontSize: 11, fontWeight: 800, color: S.accent, letterSpacing: "1px" }}>🔥 DYNAMIC TRENDING MOVEMENTS</div>
              {loadingTrendingPrices ? (
                <span style={{ fontSize: 11, color: S.accent, display: "flex", alignItems: "center", gap: 6 }}>
                  <span className="spinner" style={{ display: "inline-block", width: 10, height: 10, border: "2px solid #1e3a8a", borderTopColor: "transparent", borderRadius: "50%", animation: "spin 0.8s linear infinite" }} />
                  Updating live prices...
                </span>
              ) : (
                <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                  {trendingLastUpdated && (
                    <span style={{ fontSize: 11, color: S.muted }}>
                      Last updated: {getReadableLastUpdated()}
                    </span>
                  )}
                  <button onClick={() => fetchTrendingPrices(true)} style={{ background: "transparent", border: "none", color: S.muted, fontSize: 11, cursor: "pointer", textDecoration: "underline" }}>
                    Refresh Prices
                  </button>
                </div>
              )}
            </div>

            <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(200px, 1fr))", gap: 10, marginBottom: 24 }}>
              {trendingMovements.filter(item => item.change >= 0).map((item) => {
                const isUp = item.trend === "up";
                return (
                  <div
                    key={item.name}
                    onClick={() => handleTrendingClick(item)}
                    style={{
                      background: "linear-gradient(135deg, #ffffff, #f8fafc)",
                      border: `1px solid ${isUp ? "rgba(22, 163, 74, 0.3)" : "rgba(220, 38, 38, 0.3)"}`,
                      borderRadius: 10,
                      padding: "10px 14px",
                      cursor: "pointer",
                      transition: "transform 0.2s, border-color 0.2s",
                      display: "flex",
                      flexDirection: "column",
                      gap: 4
                    }}
                    onMouseOver={(e) => {
                      e.currentTarget.style.transform = "translateY(-2px)";
                      e.currentTarget.style.borderColor = isUp ? "#22c55e" : "#ef4444";
                    }}
                    onMouseOut={(e) => {
                      e.currentTarget.style.transform = "none";
                      e.currentTarget.style.borderColor = isUp ? "rgba(34, 197, 94, 0.2)" : "rgba(239, 68, 68, 0.2)";
                    }}
                  >
                    <div style={{ fontSize: 12.5, fontWeight: 700, color: S.text, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
                      {item.name}
                    </div>
                    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 2 }}>
                      <span style={{ fontSize: 13, color: S.accent, fontWeight: 800 }}>
                        {fmt(item.price)}
                      </span>
                      <span style={{
                        fontSize: 11,
                        fontWeight: 800,
                        color: isUp ? "#16a34a" : "#dc2626",
                        background: isUp ? "rgba(22, 163, 74, 0.1)" : "rgba(220, 38, 38, 0.1)",
                        padding: "2px 6px",
                        borderRadius: 6,
                        display: "flex",
                        alignItems: "center",
                        gap: 2
                      }}>
                        {isUp ? "▲" : "▼"} {isUp ? "+" : ""}{item.change}%
                      </span>
                    </div>
                  </div>
                );
              })}
            </div>
            {marketLoading && (
              <div style={{ ...S.card, borderColor: "#1e3a8a55", background: "linear-gradient(145deg, #ffffff, #f8fafc)", padding: 24 }}>
                <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 18 }}>
                  <div style={{ width: 10, height: 10, borderRadius: "50%", background: S.accent, animation: "pulse 1.2s infinite" }} />
                  <div style={{ ...S.label, color: S.accent, marginBottom: 0 }}>Generating Market Intelligence Report...</div>
                </div>
                <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
                  <div style={{ height: 14, width: "95%", background: "#e2e8f0", borderRadius: 4, animation: "pulse 1.5s infinite" }} />
                  <div style={{ height: 14, width: "80%", background: "#e2e8f0", borderRadius: 4, animation: "pulse 1.5s infinite 0.15s" }} />
                  <div style={{ height: 14, width: "88%", background: "#e2e8f0", borderRadius: 4, animation: "pulse 1.5s infinite 0.3s" }} />
                  <div style={{ height: 14, width: "65%", background: "#e2e8f0", borderRadius: 4, animation: "pulse 1.5s infinite 0.45s" }} />
                </div>
              </div>
            )}
            {!marketLoading && marketResult ? (
              marketResult === QUOTA_EXCEEDED
                ? <QuotaBanner />
                : marketResult === INVALID_KEY
                  ? <InvalidKeyBanner />
                  : (
                    <div style={{ ...S.card, borderColor: "#1e3a8a33" }}>
                      <div style={{ ...S.label, color: S.accent, marginBottom: 12 }}>
                        Analysis: {analyzedCard 
                          ? `${analyzedCard.year} ${analyzedCard.name || analyzedCard.player} ${analyzedCard.releaseName || ''} ${analyzedCard.setName || ''} ${analyzedCard.parallelName ? `(${analyzedCard.parallelName})` : ''}` 
                          : marketQuery}
                      </div>
                      <div style={{ fontSize: 14, lineHeight: 1.8, color: "#475569" }}>{renderMarkdown(marketResult)}</div>
                    </div>
                  )
            ) : !marketLoading && (
              <div style={{ border: "1px dashed #cbd5e1", borderRadius: 12, padding: 40, textAlign: "center", color: "#64748b" }}>
                <div style={{ fontSize: 32, marginBottom: 10 }}>📊</div>
                <div style={{ fontSize: 13 }}>Search a card to see AI-powered market analysis</div>
              </div>
            )}
          </div>
        )}
      </div>

      <style>{`
        @keyframes pulse { 0%,100%{opacity: 0.3} 50%{opacity: 0.8} }
        @keyframes spin { to { transform: rotate(360deg); } }
        *{box-sizing:border-box}
        input::placeholder{color:#94a3b8}
        select{color:#0f172a}
        ::-webkit-scrollbar{width:4px}::-webkit-scrollbar-track{background:#f1f5f9}::-webkit-scrollbar-thumb{background:#cbd5e1;border-radius:2px}

        /* ── Layout ── */
        .app-header { padding: 20px 24px 0; border-bottom: 1px solid #e2e8f0; }
        .header-top { display: flex; justify-content: space-between; align-items: center; }
        .app-content { padding: 20px 24px 0; }

        /* ── Responsive Grids ── */
        .grid-3 { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; }
        .grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
        .grid-4 { display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; }
        .mb-24 { margin-bottom: 24px; }
        .mb-20 { margin-bottom: 20px; }

        /* ── Mobile (≤ 600px) ── */
        @media (max-width: 600px) {
          .app-header { padding: 14px 16px 0; }
          .app-content { padding: 16px 16px 0; }
          .header-subtitle { display: none; }
          .header-email { display: none; }
          .grid-3 { grid-template-columns: 1fr; }
          .grid-2 { grid-template-columns: 1fr; }
          .grid-4 { grid-template-columns: 1fr 1fr; }
        }

        /* ── Tablet (601px – 900px) ── */
        @media (min-width: 601px) and (max-width: 900px) {
          .app-header { padding: 18px 20px 0; }
          .app-content { padding: 18px 20px 0; }
          .grid-3 { grid-template-columns: repeat(3, 1fr); }
          .grid-4 { grid-template-columns: repeat(2, 1fr); }
        }

        @keyframes slideInRight {
          from {
            transform: translateX(120%);
            opacity: 0;
          }
          to {
            transform: translateX(0);
            opacity: 1;
          }
        }
      `}</style>

      {/* Profile Modal */}
      {showProfileModal && (
        <div style={{
          position: "fixed",
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          background: "rgba(15, 23, 42, 0.4)",
          backdropFilter: "blur(8px)",
          display: "flex",
          justifyContent: "center",
          alignItems: "center",
          zIndex: 9999,
          fontFamily: "'Inter', sans-serif"
        }}>
          <div style={{
            ...S.card,
            width: 400,
            padding: 30,
            background: "linear-gradient(145deg, #ffffff, #f8fafc)",
            border: "1px solid #e2e8f0"
          }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 20 }}>
              <span style={{ fontSize: 18, fontWeight: 800, color: S.text }}>User Profile & Security</span>
              <button onClick={() => {
                setShowProfileModal(false);
                setPasswordError("");
                setPasswordSuccess("");
                setNewPassword("");
                setConfirmPassword("");
              }} style={{ background: "none", border: "none", color: S.muted, cursor: "pointer", fontSize: 20 }}>✕</button>
            </div>
            
            <div style={{ marginBottom: 20 }}>
              <div style={S.label}>Email Address</div>
              <div style={{ fontSize: 15, fontWeight: 700, color: S.text, background: "#0d0d18", border: "1px solid #1e1e2e", borderRadius: 8, padding: "10px 14px" }}>
                {user.email}
              </div>
            </div>

            <form onSubmit={handlePasswordChange}>
              <div style={{ ...S.label, marginBottom: 8 }}>Change Password</div>
              <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
                <input
                  type="password"
                  placeholder="New Password"
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                  style={S.input}
                  required
                />
                <input
                  type="password"
                  placeholder="Confirm New Password"
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  style={S.input}
                  required
                />
              </div>

              {passwordError && (
                <div style={{ fontSize: 13, color: "#ef4444", marginTop: 12, background: "rgba(239, 68, 68, 0.1)", border: "1px solid rgba(239, 68, 68, 0.2)", borderRadius: 6, padding: "8px 12px" }}>
                  {passwordError}
                </div>
              )}
              {passwordSuccess && (
                <div style={{ fontSize: 13, color: "#22c55e", marginTop: 12, background: "rgba(34, 197, 94, 0.1)", border: "1px solid rgba(34, 197, 94, 0.2)", borderRadius: 6, padding: "8px 12px" }}>
                  {passwordSuccess}
                </div>
              )}

              <button
                type="submit"
                disabled={passwordLoading}
                style={{
                  background: S.accent,
                  color: S.bg,
                  border: "none",
                  borderRadius: 8,
                  padding: "12px",
                  fontWeight: 800,
                  fontSize: 14,
                  cursor: "pointer",
                  width: "100%",
                  marginTop: 18,
                  opacity: passwordLoading ? 0.6 : 1
                }}
              >
                {passwordLoading ? "Updating..." : "Update Password"}
              </button>
            </form>
          </div>
        </div>
      )}

      {/* Toast Notification */}
      {toast.visible && (
        <div style={{
          position: "fixed",
          bottom: 24,
          right: 24,
          background: "rgba(255, 255, 255, 0.95)",
          backdropFilter: "blur(12px)",
          border: "1px solid rgba(30, 58, 138, 0.25)",
          borderRadius: 12,
          padding: "14px 18px",
          boxShadow: "0 10px 40px 0 rgba(0, 0, 0, 0.08)",
          zIndex: 10000,
          display: "flex",
          alignItems: "center",
          gap: 12,
          maxWidth: 420,
          animation: "slideInRight 0.35s cubic-bezier(0.16, 1, 0.3, 1)",
          fontFamily: "'Inter', sans-serif"
        }}>
          <span style={{ fontSize: 20, color: toast.type === "success" ? S.accent : "#ef4444" }}>
            {toast.type === "success" ? "🔄" : "⚠️"}
          </span>
          <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>
            <div style={{ fontSize: 11, fontWeight: 800, color: S.accent, letterSpacing: "1px" }}>
              {toast.type === "success" ? "LIVE SYNC STATUS" : "ALERT"}
            </div>
            <div style={{ fontSize: 13, color: S.text, lineHeight: 1.4, fontWeight: 500 }}>
              {toast.message}
            </div>
          </div>
          <button 
            onClick={() => setToast(prev => ({ ...prev, visible: false }))}
            style={{
              background: "transparent",
              border: "none",
              color: S.muted,
              fontSize: 16,
              cursor: "pointer",
              marginLeft: 14,
              padding: "4px",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              transition: "color 0.2s"
            }}
            onMouseOver={(e) => e.target.style.color = S.text}
            onMouseOut={(e) => e.target.style.color = S.muted}
          >
            ✕
          </button>
        </div>
      )}
    </div>
  );
}