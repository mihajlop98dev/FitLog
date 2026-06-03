#!/usr/bin/env python3
"""
Analyze and Categorize Exercises Script
Analizira vežbe, identifikuje duplikate i kategorizuje ih po delovima tela
"""

import sys
import json
import re
from pathlib import Path
from typing import Dict, List, Tuple, Set
from collections import defaultdict

try:
    from supabase import create_client, Client
except ImportError:
    print("Instalirajte Supabase Python SDK: pip install supabase")
    sys.exit(1)


def normalize_exercise_name(name: str) -> str:
    """Normalizuje ime vežbe za poređenje (uklanja razmake, mala slova, itd.)"""
    # Ukloni razmake, zareze, tačke
    normalized = re.sub(r'[,\s\.]', '', name.lower())
    # Ukloni dijakritike (ć, č, š, đ, ž)
    replacements = {
        'ć': 'c', 'č': 'c', 'š': 's', 'đ': 'd', 'ž': 'z',
        'Ć': 'C', 'Č': 'C', 'Š': 'S', 'Đ': 'D', 'Ž': 'Z'
    }
    for old, new in replacements.items():
        normalized = normalized.replace(old, new)
    return normalized


def identify_category(exercise_name: str) -> str:
    """Identifikuje kategoriju vežbe na osnovu imena"""
    name_lower = exercise_name.lower()
    
    # Kategorije po delovima tela
    categories = {
        'Noge': [
            'noge', 'cucanj', 'cučanj', 'squat', 'leg', 'thigh', 'quad', 'hamstring',
            'glute', 'butt', 'calves', 'calf', 'lunge', 'iskorak', 'boks cucanj',
            'box cucanj', 'rumunsko', 'deadlift', 'hip thrust', 'prednja loža',
            'zadnja loža', 'loža', 'izdrzaj uz zid'
        ],
        'Biceps': [
            'biceps', 'bicep', 'pregib', 'curl', 'zotman', 'hamer', 'hammer',
            'magnetik', 'magnetic'
        ],
        'Triceps': [
            'triceps', 'tricep', 'ekstenzija', 'extension', 'uski benc', 'narrow bench',
            't riceps', 't-riceps'
        ],
        'Ruke': [
            'ruke', 'arm', 'pregib', 'ekstenzija'
        ],
        'Grudi': [
            'grudi', 'chest', 'bench', 'benc', 'pres', 'press', 'potisak', 'push',
            'razvlacenje', 'razvlačenje', 'fly', 'sklekovi', 'push-up', 'dips'
        ],
        'Leđa': [
            'ledja', 'leđa', 'back', 'latisimus', 'lat', 'pull', 'rowing', 'roving',
            'veslanje', 'mrtvo dizanje', 'deadlift', 'hiperekstenzija', 'hyperextension',
            'pull down', 'pull-up', 'chin-up', 'povlačenje'
        ],
        'Ramena': [
            'ramena', 'shoulder', 'deltoid', 'bočno letenje', 'lateral raise',
            'arnold', 'potisak', 'press', 'povlačenje konopca', 'reverse fly'
        ],
        'Trbuh': [
            'trbuh', 'abs', 'abdominal', 'crunch', 'plank', 'makaze', 'sklopka',
            'sit-up', 'leg raise', 'kratko gibanje', 'bočno dodirivanje'
        ],
        'Kardio': [
            'kardio', 'cardio', 'trčanje', 'running', 'bicikl', 'bike', 'rowing machine'
        ],
        'Celotelo': [
            'celotelo', 'full body', 'burpee', 'thruster', 'clean', 'snatch'
        ]
    }
    
    # Proveri svaku kategoriju
    for category, keywords in categories.items():
        for keyword in keywords:
            if keyword in name_lower:
                # Specijalni slučajevi
                if category == 'Ruke' and ('biceps' in name_lower or 'triceps' in name_lower):
                    continue  # Preskoči ako je specifična kategorija
                return category
    
    # Ako nije pronađeno, vrati "Ostalo"
    return "Ostalo"


def find_duplicates(exercises: List[str]) -> Dict[str, List[str]]:
    """Pronalazi duplikate vežbi na osnovu normalizovanog imena"""
    normalized_map: Dict[str, List[str]] = defaultdict(list)
    
    for exercise in exercises:
        normalized = normalize_exercise_name(exercise)
        normalized_map[normalized].append(exercise)
    
    # Vrati samo one koje imaju više od jedne varijante
    duplicates = {norm: ex_list for norm, ex_list in normalized_map.items() 
                  if len(ex_list) > 1}
    
    return duplicates


def choose_best_name(variants: List[str]) -> str:
    """Bira najbolje ime iz varijanti (najduže, najkompletnije)"""
    # Sortiraj po dužini (najduže prvo), pa po alfabetskom redosledu
    return sorted(variants, key=lambda x: (-len(x), x))[0]


def analyze_exercises(json_path: Path) -> Tuple[Dict[str, str], Dict[str, str]]:
    """Analizira vežbe i vraća mapiranje imena i kategorija"""
    print(f"📖 Čitanje JSON fajla: {json_path}")
    
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # Izdvoji sve vežbe
    all_exercises = set()
    for workout in data.get('workouts', []):
        for exercise in workout.get('exercises', []):
            name = exercise.get('name', '').strip()
            if name:
                all_exercises.add(name)
    
    print(f"📊 Pronađeno {len(all_exercises)} jedinstvenih vežbi")
    
    # Pronađi duplikate
    duplicates = find_duplicates(list(all_exercises))
    print(f"🔍 Pronađeno {len(duplicates)} grupa duplikata")
    
    # Kreiraj mapiranje: originalno ime -> normalizovano ime
    name_mapping: Dict[str, str] = {}
    category_mapping: Dict[str, str] = {}
    
    # Prvo obradi duplikate
    processed_normalized: Set[str] = set()
    
    for normalized, variants in duplicates.items():
        best_name = choose_best_name(variants)
        category = identify_category(best_name)
        
        # Mapiraj sve varijante na najbolje ime
        for variant in variants:
            name_mapping[variant] = best_name
            category_mapping[best_name] = category
        
        processed_normalized.add(normalized)
        print(f"  ✓ '{best_name}' ({len(variants)} varijanti)")
        for variant in variants:
            if variant != best_name:
                print(f"    → '{variant}'")
    
    # Obradi ostale vežbe (bez duplikata)
    for exercise in all_exercises:
        normalized = normalize_exercise_name(exercise)
        if normalized not in processed_normalized:
            name_mapping[exercise] = exercise  # Nema duplikata, koristi originalno ime
            category_mapping[exercise] = identify_category(exercise)
    
    # Broj jedinstvenih vežbi nakon uklanjanja duplikata
    unique_exercises = set(name_mapping.values())
    print(f"\n✅ Nakon uklanjanja duplikata: {len(unique_exercises)} jedinstvenih vežbi")
    
    # Prikaži kategorije
    category_counts = defaultdict(int)
    for exercise, category in category_mapping.items():
        category_counts[category] += 1
    
    print(f"\n📊 Kategorije:")
    for category, count in sorted(category_counts.items()):
        print(f"  {category}: {count} vežbi")
    
    return name_mapping, category_mapping


def upload_to_supabase(supabase: Client, name_mapping: Dict[str, str], 
                      category_mapping: Dict[str, str], clear_existing: bool = False):
    """Upisuje analizirane vežbe u Supabase"""
    
    if clear_existing:
        print("\n🗑️ Brisanje postojećih vežbi iz kataloga...")
        try:
            supabase.table('exercise_catalog').delete().neq('id', '').execute()
            print("✅ Postojeće vežbe obrisane")
        except Exception as e:
            print(f"⚠️ Greška pri brisanju: {e}")
    
    # Pripremi podatke - koristi samo jedinstvene vežbe (bez duplikata)
    unique_exercises = set(name_mapping.values())
    exercise_data = []
    
    for exercise_name in sorted(unique_exercises):
        normalized = normalize_exercise_name(exercise_name)
        category = category_mapping.get(exercise_name, "Ostalo")
        
        exercise_data.append({
            'name': exercise_name,
            'category': category,
            'normalized_name': normalized
        })
    
    print(f"\n📤 Upisivanje {len(exercise_data)} vežbi u katalog...")
    
    # Batch insert
    batch_size = 500
    total_inserted = 0
    
    for i in range(0, len(exercise_data), batch_size):
        batch = exercise_data[i:i + batch_size]
        try:
            supabase.table('exercise_catalog').upsert(batch).execute()
            total_inserted += len(batch)
            print(f"  ✓ Upisano {total_inserted}/{len(exercise_data)} vežbi...")
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
        print("Upotreba: python analyze_and_categorize_exercises.py <json_file> <supabase_url> <supabase_key> [--clear]")
        print("Primer: python analyze_and_categorize_exercises.py program-102234.json https://xxx.supabase.co supabase_key")
        print("Primer sa brisanjem: python analyze_and_categorize_exercises.py program-102234.json https://xxx.supabase.co supabase_key --clear")
        sys.exit(1)
    
    json_path = Path(sys.argv[1])
    supabase_url = sys.argv[2]
    supabase_key = sys.argv[3]
    
    clear_existing = '--clear' in sys.argv
    
    if not json_path.exists():
        print(f"❌ Fajl ne postoji: {json_path}")
        sys.exit(1)
    
    # Inicijalizuj Supabase
    try:
        supabase = create_client(supabase_url, supabase_key)
        print("✅ Supabase klijent inicijalizovan")
    except Exception as e:
        print(f"❌ Greška pri inicijalizaciji Supabase: {e}")
        sys.exit(1)
    
    # Analiziraj vežbe
    name_mapping, category_mapping = analyze_exercises(json_path)
    
    # Upisi u Supabase
    upload_to_supabase(supabase, name_mapping, category_mapping, clear_existing)
    
    print("\n✅ Uspešno završeno!")


if __name__ == "__main__":
    main()
