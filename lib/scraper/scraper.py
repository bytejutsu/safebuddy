import requests
from bs4 import BeautifulSoup
from supabase import create_client
import time

# =====================
# SUPABASE
# =====================
SUPABASE_URL = "https://hjkcyekgdpqkeijdntah.supabase.co"
SUPABASE_KEY = "sb_publishable_BZO0LBVdNsybm0Hh90xmLw_Ov2I-6oG"

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

# =====================
# SAFETY FUNCTION
# =====================
def get_safety_level(index):
    index = float(index)

    if index < 40:
        return "Safe 🟢"
    elif index < 55:
        return "Moderate 🟡"
    else:
        return "Dangerous 🔴"

# =====================
# HEADERS
# =====================
headers = {
    "User-Agent": "Mozilla/5.0"
}

# =====================
# CITIES
# =====================
cities = ["Tunis", "Paris", "Rome", "Berlin", "London"]

# =====================
# LOOP
# =====================
for city in cities:

    try:
        url = f"https://www.numbeo.com/crime/in/{city}"

        response = requests.get(url, headers=headers, timeout=10)

        # DEBUG (VERY IMPORTANT)
        # print(response.text[:1000])

        soup = BeautifulSoup(response.text, "html.parser")

        # ⚠️ THIS WILL OFTEN FAIL ON NUMBEO
        element = soup.select_one(".index_value")

        if not element:
            print(f"❌ Data not found for {city}")
            continue

        crime_index = float(element.text.strip())
        safety_level = get_safety_level(crime_index)

        print(f"{city} → {crime_index} → {safety_level}")

        supabase.table("safety_data").insert({
            "city": city,
            "crime_index": crime_index,
            "safety_level": safety_level
        }).execute()

        time.sleep(1)

    except Exception as e:
        print(f"⚠️ Error with {city}: {e}")