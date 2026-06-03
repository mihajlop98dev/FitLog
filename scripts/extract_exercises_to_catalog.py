#!/usr/bin/env python3
"""
Extract Exercises to Catalog Script
Izdvaja sve jedinstvene vežbe iz JSON fajla i upisuje ih u Supabase exercise_catalog tabelu
"""

import sys
import json
from pathlib import Path

try:
    from supabase import create_client, Client
except ImportError:
    print("Instalirajte Supabase Python SDK: pip install supabase")
    sys.exit(1)


def initialize_supabase(url: str, key: str) -> Client:
    """Inicijalizuje Supabase klijent"""
    try:
        supabase = create_client(url, key)
        print("✅ Supabase klijent inicijalizovan")
        return supabase
    except Exception as e:
        print(f"❌ Greška pri inicijalizaciji Supabase: {e}")
        sys.exit(1)


def extract_unique_exercises(json_path: Path) -> list[str]:
    """Izdvaja sve jedinstvene vežbe iz JSON fajla"""
    print(f"📖 Čitanje JSON fajla: {json_path}")
    
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # Izdvoji sve vežbe iz svih treninga
    unique_exercises = set()
    
    workouts = data.get('workouts', [])
    print(f"📊 Pronađeno {len(workouts)} treninga")
    
    for workout in workouts:
        exercises = workout.get('exercises', [])
        for exercise in exercises:
            exercise_name = exercise.get('name', '').strip()
            if exercise_name:  # Ignoriši prazne imena
                unique_exercises.add(exercise_name)
    
    # Sortiraj po imenu
    sorted_exercises = sorted(list(unique_exercises))
    print(f"✅ Izdvojeno {len(sorted_exercises)} jedinstvenih vežbi")
    
    return sorted_exercises


def upload_exercises_to_catalog(supabase: Client, exercises: list[str], clear_existing: bool = False):
    """Upisuje vežbe u exercise_catalog tabelu"""
    
    if clear_existing:
        print("🗑️ Brisanje postojećih vežbi iz kataloga...")
        try:
            supabase.table('exercise_catalog').delete().neq('id', '').execute()
            print("✅ Postojeće vežbe obrisane")
        except Exception as e:
            print(f"⚠️ Greška pri brisanju: {e}")
    
    print(f"📤 Upisivanje {len(exercises)} vežbi u katalog...")
    
    # Pripremi podatke za batch insert
    exercise_data = []
    for exercise_name in exercises:
        exercise_data.append({
            'name': exercise_name
        })
    
    # Batch insert (Supabase podržava do 1000 redova)
    batch_size = 500
    total_inserted = 0
    
    for i in range(0, len(exercise_data), batch_size):
        batch = exercise_data[i:i + batch_size]
        try:
            supabase.table('exercise_catalog').upsert(batch).execute()
            total_inserted += len(batch)
            print(f"  ✓ Upisano {total_inserted}/{len(exercises)} vežbi...")
        except Exception as e:
            print(f"  ⚠️ Greška pri upisivanju batch-a {i//batch_size + 1}: {e}")
            # Pokušaj pojedinačno
            for exercise in batch:
                try:
                    supabase.table('exercise_catalog').upsert(exercise).execute()
                    total_inserted += 1
                except Exception as e2:
                    print(f"    ⚠️ Greška pri upisivanju '{exercise['name']}': {e2}")
    
    print(f"✅ Uspešno upisano {total_inserted} vežbi u katalog")


def main():
    if len(sys.argv) < 4:
        print("Upotreba: python extract_exercises_to_catalog.py <json_file> <supabase_url> <supabase_key> [--clear]")
        print("Primer: python extract_exercises_to_catalog.py program-102234.json https://xxx.supabase.co supabase_key")
        print("Primer sa brisanjem: python extract_exercises_to_catalog.py program-102234.json https://xxx.supabase.co supabase_key --clear")
        sys.exit(1)
    
    json_path = Path(sys.argv[1])
    supabase_url = sys.argv[2]
    supabase_key = sys.argv[3]
    
    # Proveri --clear argument
    clear_existing = '--clear' in sys.argv
    
    if not json_path.exists():
        print(f"❌ Fajl ne postoji: {json_path}")
        sys.exit(1)
    
    # Inicijalizuj Supabase
    supabase = initialize_supabase(supabase_url, supabase_key)
    
    # Izdvoji jedinstvene vežbe
    exercises = extract_unique_exercises(json_path)
    
    if not exercises:
        print("⚠️ Nema vežbi za upisivanje")
        sys.exit(0)
    
    # Upisi u katalog
    upload_exercises_to_catalog(supabase, exercises, clear_existing)
    
    print("\n✅ Uspešno završeno!")


if __name__ == "__main__":
    main()
