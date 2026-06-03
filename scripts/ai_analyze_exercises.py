#!/usr/bin/env python3
"""
AI Analyze Exercises Script
Koristi AI (OpenAI) da analizira vežbe, identifikuje duplikate i kategorizuje ih
"""

import sys
import json
import os
from pathlib import Path
from typing import Dict, List, Tuple
from collections import defaultdict

try:
    from openai import OpenAI
except ImportError:
    print("Instalirajte OpenAI Python SDK: pip install openai")
    sys.exit(1)

try:
    from supabase import create_client, Client
except ImportError:
    print("Instalirajte Supabase Python SDK: pip install supabase")
    sys.exit(1)


def load_exercises_from_json(json_path: Path) -> List[str]:
    """Učitava sve vežbe iz JSON fajla"""
    print(f"📖 Čitanje JSON fajla: {json_path}")
    
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    exercises = set()
    for workout in data.get('workouts', []):
        for exercise in workout.get('exercises', []):
            name = exercise.get('name', '').strip()
            if name:
                exercises.add(name)
    
    exercises_list = sorted(list(exercises))
    print(f"📊 Pronađeno {len(exercises_list)} jedinstvenih vežbi")
    return exercises_list


def analyze_with_ai(client: OpenAI, exercises: List[str]) -> Dict:
    """Koristi AI da analizira vežbe i identifikuje duplikate i kategorije"""
    print(f"\n🤖 Analiziranje {len(exercises)} vežbi pomoću AI...")
    
    # Prvo pošalji sve vežbe odjednom da AI identifikuje duplikate
    # Ako je previše vežbi, podeli u batch-ove ali sa kontekstom svih vežbi
    all_results = {
        'exercises': {},  # original_name -> {normalized_name, category}
        'duplicates': {}  # normalized_name -> [original_names]
    }
    
    # Pokušaj da pošalješ sve vežbe odjednom (za identifikaciju duplikata)
    max_tokens_per_request = 100000  # GPT-4o-mini može da primi do ~128k tokena
    exercises_text = "\n".join([f"{idx+1}. {ex}" for idx, ex in enumerate(exercises)])
    estimated_tokens = len(exercises_text) // 4  # Približna procena (1 token ≈ 4 karaktera)
    
    if estimated_tokens < max_tokens_per_request:
        # Možemo poslati sve odjednom
        print(f"  📦 Šaljem sve {len(exercises)} vežbi odjednom...")
        try:
            response = client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {
                        "role": "system",
                        "content": """Ti si ekspert za vežbe i trening. Tvoj zadatak je da analiziraš KOMPLETNU listu vežbi i:

1. PRVO identifikuješ SVE duplikate - vežbe koje su iste ali drugačije napisane (npr. "kosi bench" i "kosi bendz" su ista vežba, "Grudi kosi benc" i "Grudi, kosi benč pres" su ista vežba)
2. ZATIM kategorizuješ vežbe po delovima tela: Noge, Grudi, Leđa, Ramena, Biceps, Triceps, Trbuh, Kardio, Celotelo, Ostalo
3. Normalizuješ imena - izaberi najbolje/najkompletnije ime za svaku grupu duplikata

VAŽNO:
- Prođi kroz SVE vežbe i identifikuj duplikate - čak i ako su u različitim delovima liste
- Normalizovano ime treba da bude najkompletnije i najjasnije ime vežbe
- Kategorije moraju biti tačno: Noge, Grudi, Leđa, Ramena, Biceps, Triceps, Trbuh, Kardio, Celotelo, ili Ostalo
- Identifikuj sve duplikate, čak i ako su samo malo drugačije napisani (npr. "benc" vs "bench", "cucanj" vs "čučanj", "Grudi" vs "Grudi,")

Vrati JSON u formatu:
{
  "exercises": {
    "original_name": {
      "normalized_name": "normalizovano ime",
      "category": "kategorija"
    }
  },
  "duplicates": {
    "normalized_name": ["original_name1", "original_name2", ...]
  }
}"""
                    },
                    {
                        "role": "user",
                        "content": f"Analiziraj SVE sledeće vežbe i identifikuj SVE duplikate (čak i ako su u različitim delovima liste), zatim kategorizuj:\n\n{exercises_text}"
                    }
                ],
                response_format={"type": "json_object"},
                temperature=0.3
            )
            
            result_text = response.choices[0].message.content
            all_results = json.loads(result_text)
            
            print(f"    ✅ Analizirano {len(exercises)} vežbi odjednom")
            
        except Exception as e:
            print(f"    ⚠️ Greška pri slanju svih vežbi odjednom: {e}")
            print(f"    📦 Podeljujem u batch-ove...")
            # Fallback na batch-ove
            return analyze_with_ai_batched(client, exercises)
    else:
        # Previše vežbi, moramo u batch-ove ali sa kontekstom
        print(f"  📦 Previše vežbi ({len(exercises)}), podeljujem u batch-ove sa kontekstom...")
        return analyze_with_ai_batched(client, exercises)
    
    print(f"\n✅ AI analiza završena")
    return all_results


def analyze_with_ai_batched(client: OpenAI, exercises: List[str]) -> Dict:
    """Analizira vežbe u batch-ovima ali sa kontekstom svih vežbi"""
    all_results = {
        'exercises': {},
        'duplicates': {}
    }
    
    # Prvo pošalji sve imena vežbi da AI identifikuje duplikate
    print(f"  🔍 Korak 1: Identifikacija duplikata (sve vežbe)...")
    exercises_list_text = "\n".join([f"{idx+1}. {ex}" for idx, ex in enumerate(exercises)])
    
    try:
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {
                    "role": "system",
                    "content": """Ti si ekspert za vežbe. Tvoj zadatak je da identifikuješ SVE duplikate u listi vežbi.
Duplikati su vežbe koje su iste ali drugačije napisane (npr. "kosi bench" i "kosi bendz", "Grudi kosi benc" i "Grudi, kosi benč pres").

Vrati JSON sa grupama duplikata:
{
  "duplicate_groups": [
    {
      "normalized_name": "najbolje ime vežbe",
      "variants": ["original_name1", "original_name2", ...]
    }
  ],
  "unique_exercises": ["vežba1", "vežba2", ...]  // vežbe koje nisu duplikati
}"""
                },
                {
                    "role": "user",
                    "content": f"Identifikuj SVE duplikate u sledećoj listi vežbi:\n\n{exercises_list_text}"
                }
            ],
            response_format={"type": "json_object"},
            temperature=0.3
        )
        
        duplicates_result = json.loads(response.choices[0].message.content)
        print(f"    ✅ Identifikovano {len(duplicates_result.get('duplicate_groups', []))} grupa duplikata")
        
        # Kreiraj mapiranje duplikata
        duplicate_mapping = {}
        for group in duplicates_result.get('duplicate_groups', []):
            normalized = group.get('normalized_name', '')
            for variant in group.get('variants', []):
                duplicate_mapping[variant] = normalized
        
        # Sada kategorizuj sve jedinstvene vežbe (normalizovane + jedinstvene)
        unique_exercises = set(duplicate_mapping.values()) | set(duplicates_result.get('unique_exercises', []))
        
        print(f"  📊 Korak 2: Kategorizacija {len(unique_exercises)} jedinstvenih vežbi...")
        
        # Kategorizuj u batch-ovima
        batch_size = 100
        for i in range(0, len(unique_exercises), batch_size):
            batch = list(unique_exercises)[i:i + batch_size]
            batch_num = i // batch_size + 1
            total_batches = (len(unique_exercises) + batch_size - 1) // batch_size
            
            print(f"    📦 Batch {batch_num}/{total_batches} ({len(batch)} vežbi)...")
            
            try:
                response = client.chat.completions.create(
                    model="gpt-4o-mini",
                    messages=[
                        {
                            "role": "system",
                            "content": """Kategorizuj vežbe po delovima tela: Noge, Grudi, Leđa, Ramena, Biceps, Triceps, Trbuh, Kardio, Celotelo, Ostalo.

Vrati JSON:
{
  "exercises": {
    "exercise_name": "kategorija"
  }
}"""
                        },
                        {
                            "role": "user",
                            "content": f"Kategorizuj sledeće vežbe:\n\n" + "\n".join([f"{idx+1}. {ex}" for idx, ex in enumerate(batch)])
                        }
                    ],
                    response_format={"type": "json_object"},
                    temperature=0.3
                )
                
                categories_result = json.loads(response.choices[0].message.content)
                
                # Spoji rezultate
                for exercise_name, category in categories_result.get('exercises', {}).items():
                    all_results['exercises'][exercise_name] = {
                        'normalized_name': exercise_name,
                        'category': category
                    }
                
                print(f"      ✅ Kategorizovano {len(batch)} vežbi")
                
            except Exception as e:
                print(f"      ⚠️ Greška pri kategorizaciji batch-a {batch_num}: {e}")
                for ex in batch:
                    if ex not in all_results['exercises']:
                        all_results['exercises'][ex] = {
                            'normalized_name': ex,
                            'category': 'Ostalo'
                        }
        
        # Mapiraj sve originalne vežbe na normalizovane
        for original, normalized in duplicate_mapping.items():
            if normalized in all_results['exercises']:
                all_results['exercises'][original] = all_results['exercises'][normalized].copy()
                all_results['exercises'][original]['normalized_name'] = normalized
        
        # Dodaj duplikate u rezultate
        for group in duplicates_result.get('duplicate_groups', []):
            normalized = group.get('normalized_name', '')
            all_results['duplicates'][normalized] = group.get('variants', [])
        
    except Exception as e:
        print(f"    ⚠️ Greška pri identifikaciji duplikata: {e}")
        # Fallback: svaka vežba je jedinstvena
        for ex in exercises:
            all_results['exercises'][ex] = {
                'normalized_name': ex,
                'category': 'Ostalo'
            }
    
    return all_results


def process_ai_results(ai_results: Dict, all_exercises: List[str]) -> Tuple[Dict[str, str], Dict[str, str]]:
    """Procesira AI rezultate i kreira finalno mapiranje"""
    name_mapping: Dict[str, str] = {}
    category_mapping: Dict[str, str] = {}
    
    # Prvo obradi vežbe koje je AI analizirao
    for original_name, data in ai_results.get('exercises', {}).items():
        normalized = data.get('normalized_name', original_name)
        category = data.get('category', 'Ostalo')
        
        name_mapping[original_name] = normalized
        category_mapping[normalized] = category
    
    # Obradi vežbe koje AI nije pokrio
    for exercise in all_exercises:
        if exercise not in name_mapping:
            # Pokušaj da nađeš u duplikatima
            found = False
            for normalized, originals in ai_results.get('duplicates', {}).items():
                if exercise in originals:
                    name_mapping[exercise] = normalized
                    if normalized in category_mapping:
                        found = True
                        break
            
            if not found:
                # Koristi originalno ime
                name_mapping[exercise] = exercise
                category_mapping[exercise] = 'Ostalo'
    
    # Prikaži statistiku
    unique_exercises = set(name_mapping.values())
    category_counts = defaultdict(int)
    for exercise, category in category_mapping.items():
        category_counts[category] += 1
    
    print(f"\n📊 Rezultati:")
    print(f"  Originalno: {len(all_exercises)} vežbi")
    print(f"  Nakon uklanjanja duplikata: {len(unique_exercises)} vežbi")
    print(f"  Uklonjeno duplikata: {len(all_exercises) - len(unique_exercises)}")
    
    print(f"\n📊 Kategorije:")
    for category, count in sorted(category_counts.items()):
        print(f"  {category}: {count} vežbi")
    
    # Prikaži neke duplikate
    duplicates_found = ai_results.get('duplicates', {})
    if duplicates_found:
        print(f"\n🔍 Primeri duplikata:")
        for normalized, originals in list(duplicates_found.items())[:5]:
            if len(originals) > 1:
                print(f"  '{normalized}':")
                for orig in originals:
                    print(f"    → '{orig}'")
    
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
        # Normalizuj ime za poređenje (bez razmaka, mala slova)
        normalized = ''.join(exercise_name.lower().split())
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
    if len(sys.argv) < 5:
        print("Upotreba: python ai_analyze_exercises.py <json_file> <supabase_url> <supabase_key> <openai_api_key> [--clear]")
        print("Primer: python ai_analyze_exercises.py program-102234.json https://xxx.supabase.co supabase_key sk-xxx")
        print("\nKako dobiti OpenAI API key:")
        print("  1. Idite na https://platform.openai.com/api-keys")
        print("  2. Kliknite 'Create new secret key'")
        print("  3. Kopirajte key (počinje sa 'sk-')")
        sys.exit(1)
    
    json_path = Path(sys.argv[1])
    supabase_url = sys.argv[2]
    supabase_key = sys.argv[3]
    openai_api_key = sys.argv[4]
    
    clear_existing = '--clear' in sys.argv
    
    if not json_path.exists():
        print(f"❌ Fajl ne postoji: {json_path}")
        sys.exit(1)
    
    # Inicijalizuj OpenAI
    try:
        openai_client = OpenAI(api_key=openai_api_key)
        print("✅ OpenAI klijent inicijalizovan")
    except Exception as e:
        print(f"❌ Greška pri inicijalizaciji OpenAI: {e}")
        sys.exit(1)
    
    # Inicijalizuj Supabase
    try:
        supabase = create_client(supabase_url, supabase_key)
        print("✅ Supabase klijent inicijalizovan")
    except Exception as e:
        print(f"❌ Greška pri inicijalizaciji Supabase: {e}")
        sys.exit(1)
    
    # Učitaj vežbe
    exercises = load_exercises_from_json(json_path)
    
    # Analiziraj pomoću AI
    ai_results = analyze_with_ai(openai_client, exercises)
    
    # Procesiraj rezultate
    name_mapping, category_mapping = process_ai_results(ai_results, exercises)
    
    # Upisi u Supabase
    upload_to_supabase(supabase, name_mapping, category_mapping, clear_existing)
    
    print("\n✅ Uspešno završeno!")


if __name__ == "__main__":
    main()
