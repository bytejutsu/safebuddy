"""
SafeBuddy Flask API
────────────────────────────────────────────────────────────────────
Endpoints:
  GET /city?name=Paris          → city safety card
  GET /cities                   → all cities in DB
  GET /scrape?city=Paris        → scrape + upsert one city
  GET /scrape/all               → scrape + upsert every city in CITIES list
  GET /seed                     → insert static fallback data into Supabase
  GET /health                   → liveness check
────────────────────────────────────────────────────────────────────
Priority for /city:
  1. Supabase (live / scraped data)
  2. Static fallback list (cities_data)
  3. 404
"""

from flask import Flask, jsonify, request
from flask_cors import CORS
from supabase import create_client
import requests
from bs4 import BeautifulSoup
import time

app = Flask(__name__)
CORS(app)

# ── Supabase ──────────────────────────────────────────────────────────────────
SUPABASE_URL = "https://hjkcyekgdpqkeijdntah.supabase.co"
SUPABASE_KEY = "sb_publishable_BZO0LBVdNsybm0Hh90xmLw_Ov2I-6oG"
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

# ── Static fallback data ──────────────────────────────────────────────────────
cities_data = [
    # SAFE
    {"city": "Tokyo",      "country": "Japan",       "crime_index": 24.0, "safety_level": "Safe 🟢",      "risk_note": "Very low violent crime",      "night_advice": "Safe even at night in most areas"},
    {"city": "Singapore",  "country": "Singapore",   "crime_index": 16.0, "safety_level": "Safe 🟢",      "risk_note": "Strict laws, very low crime",  "night_advice": "Safe at night everywhere"},
    {"city": "Dubai",      "country": "UAE",          "crime_index": 15.8, "safety_level": "Safe 🟢",      "risk_note": "Strong security",              "night_advice": "Very safe at night"},
    {"city": "Abu Dhabi",  "country": "UAE",          "crime_index": 12.5, "safety_level": "Safe 🟢",      "risk_note": "Very low crime",               "night_advice": "Safe at night"},
    {"city": "Zurich",     "country": "Switzerland",  "crime_index": 25.4, "safety_level": "Safe 🟢",      "risk_note": "Low crime",                    "night_advice": "Safe at night"},
    {"city": "Helsinki",   "country": "Finland",      "crime_index": 23.7, "safety_level": "Safe 🟢",      "risk_note": "Very peaceful",                "night_advice": "Safe at night"},
    {"city": "Copenhagen", "country": "Denmark",      "crime_index": 26.9, "safety_level": "Safe 🟢",      "risk_note": "Low crime rate",               "night_advice": "Safe at night"},
    {"city": "Oslo",       "country": "Norway",       "crime_index": 28.3, "safety_level": "Safe 🟢",      "risk_note": "Calm environment",             "night_advice": "Safe at night"},
    {"city": "Vienna",     "country": "Austria",      "crime_index": 27.0, "safety_level": "Safe 🟢",      "risk_note": "Very safe transport",          "night_advice": "Safe at night"},
    {"city": "Sydney",     "country": "Australia",    "crime_index": 33.4, "safety_level": "Safe 🟢",      "risk_note": "Mostly safe",                  "night_advice": "Avoid empty areas at night"},
    {"city": "Toronto",    "country": "Canada",       "crime_index": 32.1, "safety_level": "Safe 🟢",      "risk_note": "Generally safe",               "night_advice": "Normal caution at night"},
    # MODERATE
    {"city": "Paris",         "country": "France",   "crime_index": 57.9, "safety_level": "Moderate 🟡",  "risk_note": "Pickpocketing in tourist areas","night_advice": "Avoid isolated metro stations"},
    {"city": "London",        "country": "UK",        "crime_index": 55.4, "safety_level": "Moderate 🟡",  "risk_note": "Some theft in crowded zones",  "night_advice": "Avoid empty streets at night"},
    {"city": "Rome",          "country": "Italy",     "crime_index": 46.8, "safety_level": "Moderate 🟡",  "risk_note": "Tourist scams possible",       "night_advice": "Be careful at stations"},
    {"city": "Madrid",        "country": "Spain",     "crime_index": 35.2, "safety_level": "Moderate 🟡",  "risk_note": "Minor theft risk",             "night_advice": "Avoid dark parks at night"},
    {"city": "Berlin",        "country": "Germany",   "crime_index": 44.6, "safety_level": "Moderate 🟡",  "risk_note": "Some theft zones",             "night_advice": "Stay in well-lit areas"},
    {"city": "New York",      "country": "USA",       "crime_index": 49.3, "safety_level": "Moderate 🟡",  "risk_note": "Some unsafe districts",        "night_advice": "Avoid poorly lit subway exits"},
    {"city": "Los Angeles",   "country": "USA",       "crime_index": 47.1, "safety_level": "Moderate 🟡",  "risk_note": "Area-dependent safety",        "night_advice": "Avoid isolated streets"},
    {"city": "Istanbul",      "country": "Turkey",    "crime_index": 42.6, "safety_level": "Moderate 🟡",  "risk_note": "Busy city risks",              "night_advice": "Avoid empty alleys"},
    {"city": "Athens",        "country": "Greece",    "crime_index": 45.0, "safety_level": "Moderate 🟡",  "risk_note": "Pickpocket risk",              "night_advice": "Stay in crowded areas"},
    {"city": "Milan",         "country": "Italy",     "crime_index": 48.2, "safety_level": "Moderate 🟡",  "risk_note": "Metro theft risk",             "night_advice": "Avoid empty stations"},
    {"city": "Cairo",         "country": "Egypt",     "crime_index": 52.4, "safety_level": "Moderate 🟡",  "risk_note": "Crowded city risks",           "night_advice": "Avoid scams"},
    # DANGEROUS
    {"city": "Johannesburg",  "country": "South Africa", "crime_index": 72.1, "safety_level": "Dangerous 🔴", "risk_note": "High crime rate",          "night_advice": "Avoid night travel alone"},
    {"city": "Cape Town",     "country": "South Africa", "crime_index": 65.4, "safety_level": "Dangerous 🔴", "risk_note": "Risk in some districts",   "night_advice": "Avoid isolated suburbs"},
    {"city": "Rio de Janeiro","country": "Brazil",        "crime_index": 70.5, "safety_level": "Dangerous 🔴", "risk_note": "Robbery risk in some zones","night_advice": "Avoid beaches at night"},
    {"city": "São Paulo",     "country": "Brazil",        "crime_index": 66.8, "safety_level": "Dangerous 🔴", "risk_note": "Urban crime areas",        "night_advice": "Avoid empty streets"},
    {"city": "Mexico City",   "country": "Mexico",        "crime_index": 63.2, "safety_level": "Dangerous 🔴", "risk_note": "Theft risk",               "night_advice": "Avoid unsafe neighborhoods"},
    {"city": "Bogotá",        "country": "Colombia",      "crime_index": 64.5, "safety_level": "Dangerous 🔴", "risk_note": "Varies by district",       "night_advice": "Avoid night travel alone"},
    {"city": "Lagos",         "country": "Nigeria",       "crime_index": 68.9, "safety_level": "Dangerous 🔴", "risk_note": "High crime zones",         "night_advice": "Avoid night movement"},
    {"city": "Nairobi",       "country": "Kenya",         "crime_index": 60.3, "safety_level": "Dangerous 🔴", "risk_note": "Some unsafe districts",    "night_advice": "Avoid isolated areas"},
    {"city": "Delhi",         "country": "India",         "crime_index": 60.2, "safety_level": "Dangerous 🔴", "risk_note": "Safety varies",            "night_advice": "Avoid isolated streets"},
    # TUNISIA (local data)
    {"city": "Tunis",         "country": "Tunisia",       "crime_index": 43.5, "safety_level": "Moderate 🟡", "risk_note": "Generally safe for tourists, petty theft in busy markets", "night_advice": "Avoid poorly lit areas of the Medina at night"},
    {"city": "Sousse",        "country": "Tunisia",       "crime_index": 41.0, "safety_level": "Moderate 🟡", "risk_note": "Tourist-friendly, minor theft risk",                       "night_advice": "Stay near the hotel zone at night"},
    {"city": "Sfax",          "country": "Tunisia",       "crime_index": 39.0, "safety_level": "Safe 🟢",     "risk_note": "Calm commercial city",                                     "night_advice": "Generally safe at night"},
    {"city": "Djerba",        "country": "Tunisia",       "crime_index": 34.0, "safety_level": "Safe 🟢",     "risk_note": "Tourist island, low crime",                                "night_advice": "Safe at night in resort areas"},
]

# ── Helpers ───────────────────────────────────────────────────────────────────
def get_safety_level(index: float) -> str:
    if index < 40:
        return "Safe 🟢"
    elif index < 55:
        return "Moderate 🟡"
    else:
        return "Dangerous 🔴"


def static_lookup(city_name: str) -> object:
    """Case-insensitive lookup in the static list."""
    name = city_name.strip().lower()
    for entry in cities_data:
        if entry["city"].lower() == name:
            return entry
    return None


def db_lookup(city_name: str) -> object:
    """Fetch a city row from Supabase (case-insensitive via ilike)."""
    try:
        res = (
            supabase.table("safety_data")
            .select("*")
            .ilike("city", city_name.strip())
            .limit(1)
            .execute()
        )
        if res.data:
            return res.data[0]
    except Exception as e:
        print(f"[Supabase] lookup error: {e}")
    return None


def scrape_numbeo(city: str) -> object:
    """Scrape crime index from Numbeo. Returns float or None."""
    url = f"https://www.numbeo.com/crime/in/{city.replace(' ', '-')}"
    headers = {"User-Agent": "Mozilla/5.0"}
    try:
        r = requests.get(url, headers=headers, timeout=10)
        soup = BeautifulSoup(r.text, "html.parser")
        el = soup.select_one(".index_value")
        if el:
            return float(el.text.strip())
    except Exception as e:
        print(f"[Scraper] {city}: {e}")
    return None


def upsert_city(city: str, country: str, crime_index: float,
                risk_note: str = "", night_advice: str = "") -> dict:
    """Insert or update a city row in Supabase."""
    safety_level = get_safety_level(crime_index)
    row = {
        "city":         city,
        "country":      country,
        "crime_index":  crime_index,
        "safety_level": safety_level,
        "risk_note":    risk_note,
        "night_advice": night_advice,
    }
    supabase.table("safety_data").upsert(row, on_conflict="city").execute()
    return row


# ── Routes ────────────────────────────────────────────────────────────────────

@app.route("/health")
def health():
    return jsonify({"status": "ok"})


@app.route("/city")
def city():
    """
    GET /city?name=Paris
    Priority: Supabase → static fallback → 404
    """
    name = request.args.get("name", "").strip()
    if not name:
        return jsonify({"error": "Missing ?name= parameter"}), 400

    # 1. Try Supabase (live data)
    row = db_lookup(name)
    if row:
        return jsonify(row)

    # 2. Try static fallback
    row = static_lookup(name)
    if row:
        return jsonify(row)

    return jsonify({"error": f"City '{name}' not found"}), 404


@app.route("/cities")
def cities():
    """GET /cities → all rows from Supabase."""
    try:
        res = supabase.table("safety_data").select("*").order("city").execute()
        return jsonify(res.data)
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/scrape")
def scrape_one():
    """
    GET /scrape?city=Paris&country=France
    Scrapes Numbeo and upserts into Supabase.
    """
    city  = request.args.get("city", "").strip()
    country = request.args.get("country", "Unknown").strip()

    if not city:
        return jsonify({"error": "Missing ?city= parameter"}), 400

    index = scrape_numbeo(city)
    if index is None:
        # Try static data as fallback for crime index
        static = static_lookup(city)
        if static:
            index = static["crime_index"]
            risk_note    = static.get("risk_note", "")
            night_advice = static.get("night_advice", "")
            country      = static.get("country", country)
        else:
            return jsonify({"error": f"Could not scrape data for '{city}'"}), 502
    else:
        static = static_lookup(city)
        risk_note    = static.get("risk_note", "")    if static else ""
        night_advice = static.get("night_advice", "") if static else ""
        if static:
            country = static.get("country", country)

    row = upsert_city(city, country, index, risk_note, night_advice)
    return jsonify({"scraped": True, **row})


@app.route("/scrape/all")
def scrape_all():
    """
    GET /scrape/all
    Scrapes every city in cities_data and upserts into Supabase.
    Returns a summary of successes / failures.
    """
    results = {"success": [], "failed": []}

    for entry in cities_data:
        city    = entry["city"]
        country = entry["country"]
        index   = scrape_numbeo(city)

        if index is None:
            # Fall back to static crime index so we still populate the DB
            index = entry["crime_index"]

        try:
            upsert_city(
                city, country, index,
                entry.get("risk_note", ""),
                entry.get("night_advice", ""),
            )
            results["success"].append(city)
            print(f"✅ {city} → {index}")
        except Exception as e:
            results["failed"].append({"city": city, "error": str(e)})
            print(f"❌ {city}: {e}")

        time.sleep(1)   # be polite to Numbeo

    return jsonify(results)


@app.route("/seed")
def seed():
    """
    GET /seed
    Inserts all cities_data into Supabase without scraping.
    Safe to run multiple times (upsert on city name).
    """
    success, failed = [], []
    for entry in cities_data:
        try:
            supabase.table("safety_data").upsert(entry, on_conflict="city").execute()
            success.append(entry["city"])
        except Exception as e:
            failed.append({"city": entry["city"], "error": str(e)})

    return jsonify({"seeded": len(success), "failed": failed})


# ── Run ───────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
