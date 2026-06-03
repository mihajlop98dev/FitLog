#!/usr/bin/env python3
"""
JSON to Supabase Uploader Script
Učitava JSON fajlove u Supabase PostgreSQL bazu
"""

import sys
import json
import time
from pathlib import Path
from datetime import datetime

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


def clean_string(value):
    """Uklanja null karaktere i druge problematične karaktere iz stringa"""
    if value is None:
        return None
    if isinstance(value, str):
        # Ukloni null karaktere (\u0000) i druge kontrolne karaktere
        cleaned = value.replace('\u0000', '').replace('\x00', '')
        # Ukloni ostale kontrolne karaktere osim newline, tab, itd.
        cleaned = ''.join(char for char in cleaned if ord(char) >= 32 or char in '\n\t\r')
        return cleaned
    return value


def clean_dict(data):
    """Rekurzivno čisti dictionary od null karaktera"""
    if isinstance(data, dict):
        return {key: clean_dict(value) for key, value in data.items()}
    elif isinstance(data, list):
        return [clean_dict(item) for item in data]
    else:
        return clean_string(data)


def upload_workout_plan(supabase: Client, plan_data: dict):
    """Učitava workout plan u Supabase"""
    plan_id = plan_data['planId']
    
    # Sačuvaj plan metadata
    plan_metadata = {
        'plan_id': plan_id,
        'name': plan_data.get('name', ''),
        'start_date': plan_data.get('startDate'),
        'end_date': plan_data.get('endDate'),
        'notes': plan_data.get('notes')
    }
    
    try:
        # Očisti null karaktere iz plan_metadata
        plan_metadata = clean_dict(plan_metadata)
        # Insert ili update plan metadata
        supabase.table('workout_plans').upsert(plan_metadata).execute()
        print(f"✓ Plan metadata sačuvan: {plan_id}")
    except Exception as e:
        print(f"⚠️ Greška pri čuvanju plan metadata: {e}")
    
    # Učitaj workouts
    workouts = plan_data.get('workouts', [])
    if workouts:
        print(f"  📤 Učitavanje {len(workouts)} treninga...")
        
        for idx, workout in enumerate(workouts):
            try:
                # Pripremi workout podatke
                workout_id = workout.get('id', f"workout-day-{workout.get('day', idx + 1)}")
                workout_data = {
                    'plan_id': plan_id,
                    'workout_id': workout_id,
                    'day': workout.get('day'),
                    'name': workout.get('name', f"Dan {workout.get('day', idx + 1)}"),
                    'workout_date': workout.get('date'),
                    'notes': workout.get('notes')
                }
                # Očisti null karaktere iz workout_data
                workout_data = clean_dict(workout_data)
                
                # Insert workout metadata
                supabase.table('workouts').upsert(workout_data).execute()
                
                # Učitaj exercises u batch-ovima
                exercises = workout.get('exercises', [])
                if exercises:
                    # Batch insert exercises (Supabase podržava do 1000 redova)
                    exercise_batch = []
                    for exercise in exercises:
                        exercise_data = {
                            'workout_id': workout_id,
                            'plan_id': plan_id,
                            'exercise_id': exercise.get('id') or f"exercise-{len(exercise_batch) + 1}",
                            'name': exercise.get('name', ''),
                            'sets': exercise.get('sets'),
                            'reps': exercise.get('reps'),
                            'weight': exercise.get('weight'),
                            'duration': exercise.get('duration'),
                            'notes': exercise.get('notes')
                        }
                        # Očisti null karaktere iz exercise_data
                        exercise_data = clean_dict(exercise_data)
                        exercise_batch.append(exercise_data)
                        
                        # Insert batch kada dostigne 500 (sigurno ispod limita)
                        if len(exercise_batch) >= 500:
                            supabase.table('exercises').upsert(exercise_batch).execute()
                            exercise_batch = []
                    
                    # Insert preostalih exercises
                    if exercise_batch:
                        supabase.table('exercises').upsert(exercise_batch).execute()
                
                if (idx + 1) % 20 == 0:
                    print(f"  ✓ Učitano {idx + 1}/{len(workouts)} treninga...")
                    
            except Exception as e:
                print(f"  ⚠️ Greška pri učitavanju treninga {idx + 1}: {e}")
                continue
        
        print(f"✓ Workout plan '{plan_data['name']}' (ID: {plan_id}) je učitan")
        print(f"  Broj treninga: {len(workouts)}")
    else:
        print(f"✓ Workout plan '{plan_data['name']}' (ID: {plan_id}) je učitan (nema treninga)")


def upload_meal_plan(supabase: Client, plan_data: dict):
    """Učitava meal plan u Supabase"""
    plan_id = plan_data['planId']
    
    # Sačuvaj plan metadata
    plan_metadata = {
        'plan_id': plan_id,
        'name': plan_data.get('name', ''),
        'start_date': plan_data.get('startDate'),
        'end_date': plan_data.get('endDate'),
        'notes': plan_data.get('notes')
    }
    
    try:
        # Očisti null karaktere iz plan_metadata
        plan_metadata = clean_dict(plan_metadata)
        supabase.table('meal_plans').upsert(plan_metadata).execute()
        print(f"✓ Plan metadata sačuvan: {plan_id}")
    except Exception as e:
        print(f"⚠️ Greška pri čuvanju plan metadata: {e}")
    
    # Učitaj meals
    meals = plan_data.get('meals', [])
    if meals:
        print(f"  📤 Učitavanje {len(meals)} obroka...")
        
        # Batch insert meals (Supabase podržava do 1000 redova)
        meal_batch = []
        for idx, meal in enumerate(meals):
            try:
                meal_data = {
                    'plan_id': plan_id,
                    'meal_id': meal.get('id', f"meal-{idx + 1}"),
                    'day': meal.get('day'),
                    'time': meal.get('time', 'Meal'),
                    'name': meal.get('name', ''),
                    'calories': meal.get('calories'),
                    'protein': meal.get('protein'),
                    'carbs': meal.get('carbs'),
                    'fat': meal.get('fat'),
                    'recipe': meal.get('recipe'),
                    'notes': meal.get('notes')
                }
                # Očisti null karaktere iz meal_data
                meal_data = clean_dict(meal_data)
                meal_batch.append(meal_data)
                
                # Insert batch kada dostigne 500
                if len(meal_batch) >= 500:
                    supabase.table('meals').upsert(meal_batch).execute()
                    print(f"  ✓ Učitano {len(meal_batch)} obroka...")
                    meal_batch = []
                
            except Exception as e:
                print(f"  ⚠️ Greška pri učitavanju obroka {idx + 1}: {e}")
                continue
        
        # Insert preostalih meals
        if meal_batch:
            supabase.table('meals').upsert(meal_batch).execute()
        
        # Učitaj foods za sve meals
        print(f"  📤 Učitavanje namirnica...")
        food_batch = []
        for idx, meal in enumerate(meals):
            meal_id = meal.get('id', f"meal-{idx + 1}")
            foods = meal.get('foods', [])
            
            for food in foods:
                food_data = {
                    'meal_id': meal_id,
                    'plan_id': plan_id,
                    'food_id': food.get('id') or f"food-{len(food_batch) + 1}",
                    'name': food.get('name', ''),
                    'quantity': food.get('quantity'),
                    'calories': food.get('calories')
                }
                # Očisti null karaktere iz food_data
                food_data = clean_dict(food_data)
                food_batch.append(food_data)
                
                # Insert batch kada dostigne 500
                if len(food_batch) >= 500:
                    supabase.table('foods').upsert(food_batch).execute()
                    food_batch = []
        
        # Insert preostalih foods
        if food_batch:
            supabase.table('foods').upsert(food_batch).execute()
        
        print(f"✓ Meal plan '{plan_data['name']}' (ID: {plan_id}) je učitan")
        print(f"  Broj obroka: {len(meals)}")
    else:
        print(f"✓ Meal plan '{plan_data['name']}' (ID: {plan_id}) je učitan (nema obroka)")


def clear_workout_plan(supabase: Client, plan_id: str):
    """Briše postojeće podatke za workout plan"""
    try:
        print(f"🗑️  Brisanje postojećih podataka za plan {plan_id}...")
        
        # Učitaj sve workouts za plan
        workouts = supabase.table('workouts').select('workout_id').eq('plan_id', plan_id).execute().data
        
        # Obriši exercises za sve workouts
        for workout in workouts:
            workout_id = workout['workout_id']
            supabase.table('exercises').delete().eq('plan_id', plan_id).eq('workout_id', workout_id).execute()
        
        # Obriši workouts
        supabase.table('workouts').delete().eq('plan_id', plan_id).execute()
        
        # Obriši plan metadata
        supabase.table('workout_plans').delete().eq('plan_id', plan_id).execute()
        
        print(f"✅ Obrisani postojeći podaci za plan {plan_id}")
    except Exception as e:
        print(f"⚠️  Greška pri brisanju: {e}")


def clear_meal_plan(supabase: Client, plan_id: str):
    """Briše postojeće podatke za meal plan"""
    try:
        print(f"🗑️  Brisanje postojećih podataka za plan {plan_id}...")
        
        # Učitaj sve meals za plan
        meals = supabase.table('meals').select('meal_id').eq('plan_id', plan_id).execute().data
        
        # Obriši foods za sve meals
        for meal in meals:
            meal_id = meal['meal_id']
            supabase.table('foods').delete().eq('plan_id', plan_id).eq('meal_id', meal_id).execute()
        
        # Obriši meals
        supabase.table('meals').delete().eq('plan_id', plan_id).execute()
        
        # Obriši plan metadata
        supabase.table('meal_plans').delete().eq('plan_id', plan_id).execute()
        
        print(f"✅ Obrisani postojeći podaci za plan {plan_id}")
    except Exception as e:
        print(f"⚠️  Greška pri brisanju: {e}")


def main():
    if len(sys.argv) < 4:
        print("Upotreba: python upload_json_to_supabase.py <json_file> <supabase_url> <supabase_key> [--clear]")
        print("Primer: python upload_json_to_supabase.py program-102234.json https://xxx.supabase.co supabase_key")
        print("\nOpcije:")
        print("  --clear  Obriši postojeće podatke pre upload-a (opciono)")
        print("\nKako dobiti Supabase credentials:")
        print("  1. Idite na https://supabase.com")
        print("  2. Kreirajte novi projekat")
        print("  3. Project Settings > API")
        print("  4. Kopirajte 'Project URL' i 'anon public' key")
        sys.exit(1)
    
    json_path = Path(sys.argv[1])
    supabase_url = sys.argv[2]
    supabase_key = sys.argv[3]
    clear_existing = '--clear' in sys.argv
    
    if not json_path.exists():
        print(f"❌ Fajl ne postoji: {json_path}")
        sys.exit(1)
    
    # Inicijalizuj Supabase
    supabase = initialize_supabase(supabase_url, supabase_key)
    
    # Učitaj JSON
    print(f"📖 Čitanje JSON-a: {json_path}")
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # Odredi tip i učitaj
    if 'workouts' in data:
        plan_id = data.get('planId')
        if clear_existing and plan_id:
            clear_workout_plan(supabase, plan_id)
        upload_workout_plan(supabase, data)
    elif 'meals' in data:
        plan_id = data.get('planId')
        if clear_existing and plan_id:
            clear_meal_plan(supabase, plan_id)
        upload_meal_plan(supabase, data)
    else:
        print("❌ Greška: Ne mogu da odredim tip plana (nema 'workouts' ili 'meals' polja)")
        sys.exit(1)
    
    print("\n✅ Uspešno učitano u Supabase!")


if __name__ == "__main__":
    main()
