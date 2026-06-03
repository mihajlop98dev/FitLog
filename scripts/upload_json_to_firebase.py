#!/usr/bin/env python3
"""
JSON to Firebase Uploader Script
Učitava JSON fajlove u Firebase Firestore
"""

import sys
import json
import time
from pathlib import Path

try:
    import firebase_admin
    from firebase_admin import credentials, firestore
except ImportError:
    print("Instalirajte Firebase Admin SDK: pip install firebase-admin")
    sys.exit(1)


def initialize_firebase(service_account_path=None):
    """Inicijalizuje Firebase Admin SDK"""
    try:
        # Pokušaj da učitaš postojeću inicijalizaciju
        firebase_admin.get_app()
        print("Firebase već inicijalizovan")
    except ValueError:
        if service_account_path:
            # Koristi service account fajl
            cred = credentials.Certificate(service_account_path)
            firebase_admin.initialize_app(cred)
            print(f"Firebase inicijalizovan sa service account: {service_account_path}")
        else:
            # Pokušaj da koristiš GoogleService-Info.plist ili environment varijable
            print("Greška: Potreban je service account JSON fajl")
            print("Preuzmite service account key iz Firebase Console:")
            print("1. Idite u Firebase Console > Project Settings > Service Accounts")
            print("2. Kliknite 'Generate New Private Key'")
            print("3. Sačuvajte JSON fajl")
            print("4. Koristite: python upload_json_to_firebase.py <json_file> --service-account <service_account.json>")
            sys.exit(1)


def upload_workout_plan(db, plan_data):
    """Učitava workout plan u Firestore koristeći subkolekcije za velike planove"""
    collection = db.collection('workoutPlans')
    plan_doc_ref = collection.document(plan_data['planId'])
    
    # Sačuvaj samo metadata plana (bez workouts liste)
    plan_metadata = {
        'planId': plan_data['planId'],
        'name': plan_data['name'],
        'startDate': plan_data.get('startDate'),
        'endDate': plan_data.get('endDate'),
        'notes': plan_data.get('notes')
    }
    plan_doc_ref.set(plan_metadata)
    
    # Učitaj workouts u subkolekciju (svaki workout kao poseban dokument)
    workouts = plan_data.get('workouts', [])
    if workouts:
        workouts_collection = plan_doc_ref.collection('workouts')
        
        for workout in workouts:
            workout_id = workout.get('id', f"workout-{workout.get('day', 'unknown')}")
            workout_doc_ref = workouts_collection.document(workout_id)
            
            # Sačuvaj workout metadata (bez exercises liste)
            exercises = workout.get('exercises', [])
            workout_metadata = {
                'id': workout.get('id'),
                'day': workout.get('day'),
                'name': workout.get('name'),
                'notes': workout.get('notes')
            }
            # Dodaj datum ako postoji
            if 'date' in workout:
                workout_metadata['date'] = workout['date']
            workout_doc_ref.set(workout_metadata)
            
            # Dodaj mali delay između workout-ova
            time.sleep(0.1)  # 100ms delay
            
            # Sačuvaj exercises u subkolekciju
            if exercises:
                exercises_collection = workout_doc_ref.collection('exercises')
                batch = db.batch()
                batch_count = 0
                max_batch_size = 500  # Firestore batch limit
                
                for idx, exercise in enumerate(exercises):
                    exercise_id = exercise.get('id') or f"exercise-{idx + 1}"
                    exercise_doc_ref = exercises_collection.document(exercise_id)
                    batch.set(exercise_doc_ref, exercise)
                    batch_count += 1
                    
                    # Commit batch kada dostigne limit
                    if batch_count >= max_batch_size:
                        batch.commit()
                        print(f"    Učitano {batch_count} vežbi za workout {workout_id}...")
                        # Dodaj delay da izbegnemo quota exceeded grešku
                        time.sleep(0.5)  # 500ms delay između batch-ova
                        batch = db.batch()
                        batch_count = 0
                
                # Commit preostalih
                if batch_count > 0:
                    batch.commit()
                    print(f"    Učitano {batch_count} vežbi za workout {workout_id}...")
                
                print(f"  ✓ Workout {workout_id} (dan {workout.get('day')}): {len(exercises)} vežbi")
            else:
                print(f"  ✓ Workout {workout_id} (dan {workout.get('day')}): nema vežbi")
        
        print(f"\n✓ Workout plan '{plan_data['name']}' (ID: {plan_data['planId']}) je učitan")
        print(f"  Broj treninga: {len(workouts)}")
        print(f"  Lokacija: workoutPlans/{plan_data['planId']}/workouts/")
    else:
        print(f"✓ Workout plan '{plan_data['name']}' (ID: {plan_data['planId']}) je učitan (nema treninga)")


def upload_meal_plan(db, plan_data):
    """Učitava meal plan u Firestore - jednostavan pristup"""
    collection = db.collection('mealPlans')
    plan_doc_ref = collection.document(plan_data['planId'])
    
    # Sačuvaj samo metadata plana (bez meals liste)
    plan_metadata = {
        'planId': plan_data['planId'],
        'name': plan_data['name'],
        'startDate': plan_data.get('startDate'),
        'endDate': plan_data.get('endDate'),
        'notes': plan_data.get('notes')
    }
    plan_doc_ref.set(plan_metadata)
    
    # Učitaj meals u subkolekciju - jednostavan pristup
    meals = plan_data.get('meals', [])
    if meals:
        print(f"  📤 Učitavanje {len(meals)} obroka...")
        meals_collection = plan_doc_ref.collection('meals')
        
        # Jednostavan pristup - uploaduj jedan po jedan
        # Opciono: nastavi od određenog indeksa (ako je prethodni upload prekinut)
        start_index = 0
        if '--start-from' in sys.argv:
            try:
                start_idx = sys.argv.index('--start-from')
                if start_idx + 1 < len(sys.argv):
                    start_index = int(sys.argv[start_idx + 1])
                    print(f"  📍 Nastavljam upload od obroka {start_index + 1}...")
            except (ValueError, IndexError):
                pass
        
        for idx, meal in enumerate(meals[start_index:], start=start_index):
            meal_id = meal.get('id') or f"meal-{idx + 1}"
            meal_doc_ref = meals_collection.document(meal_id)
            
            try:
                meal_doc_ref.set(meal)
                if (idx + 1) % 20 == 0:
                    print(f"  ✓ Učitano {idx + 1}/{len(meals)} obroka...")
            except Exception as e:
                error_str = str(e)
                if "Quota exceeded" in error_str or "RESOURCE_EXHAUSTED" in error_str:
                    print(f"\n  ⚠️ QUOTA EXCEEDED na obroku {idx + 1}")
                    print(f"  💡 Prekinuto. Da nastaviš upload, pokreni:")
                    print(f"     python3 upload_json_to_firebase.py meal-plan-102234.json --service-account service-account.json --start-from {idx}")
                    print(f"  💡 Ili sačekaj da se Firebase kvota resetuje (obično se resetuje dnevno)\n")
                    break
                else:
                    print(f"  ⚠️ Greška pri učitavanju obroka {idx + 1}: {e}")
                    # Nastavi sa sledećim obrokom
                    continue
            
            # Mali delay svakih 10 obroka
            if (idx + 1) % 10 == 0:
                time.sleep(0.1)
        
        print(f"✓ Meal plan '{plan_data['name']}' (ID: {plan_data['planId']}) je učitan")
        print(f"  Broj obroka: {len(meals)}")
        print(f"  Lokacija: mealPlans/{plan_data['planId']}/meals/")
    else:
        print(f"✓ Meal plan '{plan_data['name']}' (ID: {plan_data['planId']}) je učitan (nema obroka)")


def main():
    if len(sys.argv) < 2:
        print("Upotreba: python upload_json_to_firebase.py <json_file> [--service-account <service_account.json>] [--start-from <index>]")
        print("Primer: python upload_json_to_firebase.py program-102234.json --service-account service-account.json")
        print("Primer (nastavi od obroka 50): python upload_json_to_firebase.py meal-plan-102234.json --service-account service-account.json --start-from 50")
        sys.exit(1)
    
    json_path = Path(sys.argv[1])
    if not json_path.exists():
        print(f"Fajl ne postoji: {json_path}")
        sys.exit(1)
    
    # Proveri service account argument
    service_account_path = None
    if '--service-account' in sys.argv:
        idx = sys.argv.index('--service-account')
        if idx + 1 < len(sys.argv):
            service_account_path = sys.argv[idx + 1]
            # Konvertuj u Path objekat za lakše rukovanje
            service_account_path = Path(service_account_path)
            
            # Ako je relativna putanja, pokušaj da je nađeš
            if not service_account_path.is_absolute():
                # Pokušaj iz trenutnog direktorijuma
                current_dir = Path.cwd()
                if (current_dir / service_account_path).exists():
                    service_account_path = current_dir / service_account_path
                # Pokušaj iz scripts direktorijuma
                elif (Path(__file__).parent / service_account_path).exists():
                    service_account_path = Path(__file__).parent / service_account_path
                # Pokušaj iz project root
                elif (Path(__file__).parent.parent / service_account_path).exists():
                    service_account_path = Path(__file__).parent.parent / service_account_path
            
            # Proveri da li fajl postoji
            if not service_account_path.exists():
                print(f"❌ Greška: Service account fajl ne postoji: {service_account_path}")
                print("\nKako dobiti service account fajl:")
                print("  1. Idite u Firebase Console: https://console.firebase.google.com/")
                print("  2. Izaberite vaš projekat")
                print("  3. Project Settings > Service Accounts")
                print("  4. Kliknite 'Generate New Private Key'")
                print("  5. Sačuvajte JSON fajl")
                sys.exit(1)
    
    # Inicijalizuj Firebase
    initialize_firebase(str(service_account_path) if service_account_path else None)
    
    # Učitaj JSON
    print(f"Čitanje JSON-a: {json_path}")
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # Poveži se sa Firestore
    db = firestore.client()
    
    # Odredi tip i učitaj
    if 'workouts' in data:
        upload_workout_plan(db, data)
    elif 'meals' in data:
        upload_meal_plan(db, data)
    else:
        print("Greška: Ne mogu da odredim tip plana (nema 'workouts' ili 'meals' polja)")
        sys.exit(1)
    
    print("\n✓ Uspešno učitano u Firebase!")


if __name__ == "__main__":
    main()
