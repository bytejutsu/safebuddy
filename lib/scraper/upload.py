from supabase import create_client
from data import cities_data

SUPABASE_URL = "https://hjkcyekgdpqkeijdntah.supabase.co"
SUPABASE_KEY = "YOUR_KEY"

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

for city in cities_data:
    supabase.table("safety_data").insert(city).execute()

print("✅ Data uploaded successfully")