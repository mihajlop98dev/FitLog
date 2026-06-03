#!/usr/bin/env python3
"""
PDF to JSON Converter Script
Parsira PDF fajlove (program i meal-plan) i kreira JSON fajlove
"""

import sys
import json
import re
from pathlib import Path

try:
    import PyPDF2
except ImportError:
    print("Instalirajte PyPDF2: pip install PyPDF2")
    sys.exit(1)


def extract_text_from_pdf(pdf_path):
    """Ekstraktuje tekst iz PDF fajla"""
    try:
        with open(pdf_path, 'rb') as file:
            pdf_reader = PyPDF2.PdfReader(file)
            text = ""
            for page in pdf_reader.pages:
                text += page.extract_text() + "\n"
            return text
    except Exception as e:
        print(f"Greška pri čitanju PDF-a {pdf_path}: {e}")
        return None


def parse_date_from_text(text):
    """Ekstraktuje datum iz teksta (npr. 'pon, 23. feb 2026.' ili '23.02.2026')"""
    from datetime import datetime
    
    # Pokušaj različite formate datuma
    date_patterns = [
        r'(\d{1,2})\.\s*(\d{1,2})\.\s*(\d{4})',  # 23.02.2026
        r'(\d{1,2})\.\s*(jan|feb|mar|apr|maj|jun|jul|avg|sep|okt|nov|dec)\.?\s*(\d{4})',  # 23. feb 2026.
        r'(\d{1,2})\.\s*(januar|februar|mart|april|maj|jun|juli|avgust|septembar|oktobar|novembar|decembar)\.?\s*(\d{4})',  # 23. februar 2026.
    ]
    
    months_map = {
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'maj': 5, 'jun': 6,
        'jul': 7, 'avg': 8, 'sep': 9, 'okt': 10, 'nov': 11, 'dec': 12,
        'januar': 1, 'februar': 2, 'mart': 3, 'april': 4, 'maj': 5, 'jun': 6,
        'juli': 7, 'avgust': 8, 'septembar': 9, 'oktobar': 10, 'novembar': 11, 'decembar': 12
    }
    
    for pattern in date_patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            try:
                if len(match.groups()) == 3:
                    if match.group(2).lower() in months_map:
                        # Format sa mesecima
                        day = int(match.group(1))
                        month = months_map[match.group(2).lower()]
                        year = int(match.group(3))
                        return datetime(year, month, day)
                    else:
                        # Format DD.MM.YYYY
                        day = int(match.group(1))
                        month = int(match.group(2))
                        year = int(match.group(3))
                        return datetime(year, month, day)
            except:
                continue
    return None


def parse_workout_plan(text, plan_id, plan_name):
    """Parsira tekst i kreira WorkoutPlan JSON strukturu sa datumima - organizuje po danima"""
    from datetime import datetime, timedelta
    
    workouts = []
    lines = text.split('\n')
    
    # Prvo, nađi sve datume u PDF-u i mapiraj ih na dane
    # Traži eksplicitne "Dan X" markere sa datumima
    day_date_map = {}  # Mapira broj dana na datum
    all_dates = []
    
    # Prođi kroz linije i nađi "Dan X" markere sa datumima
    for i, line in enumerate(lines):
        # Proveri da li linija sadrži "Dan X" marker
        day_match = re.search(r'(?i)(day|dan|dan\s*)(\d+)', line)
        if day_match:
            day_num = int(day_match.group(2))
            # Pokušaj da nađeš datum u ovoj liniji ili okolnim linijama
            date = parse_date_from_text(line)
            if not date and i > 0:
                # Pokušaj prethodnu liniju
                date = parse_date_from_text(lines[i-1])
            if not date and i < len(lines) - 1:
                # Pokušaj sledeću liniju
                date = parse_date_from_text(lines[i+1])
            if date:
                day_date_map[day_num] = date
                all_dates.append((date, day_num, line))
                print(f"📅 Dan {day_num} -> {date.strftime('%d.%m.%Y')}")
    
    # Ako nema eksplicitnih "Dan X" markera, nađi sve datume
    if not day_date_map:
        for line in lines:
            date = parse_date_from_text(line)
            if date:
                all_dates.append((date, None, line))
    
    # Nađi najstariji datum (to je Dan 1)
    start_date = None
    if all_dates:
        # Ako imamo mapiranje dana na datume, nađi datum za Dan 1
        if 1 in day_date_map:
            start_date = day_date_map[1]
            print(f"📅 StartDate (Dan 1): {start_date.strftime('%d.%m.%Y')} - pronađen eksplicitni marker")
        else:
            # Nađi najstariji datum (najmanji datum)
            all_dates_sorted = sorted([d for d in all_dates if d[0]], key=lambda x: x[0])
            if all_dates_sorted:
                start_date = all_dates_sorted[0][0]
                print(f"📅 StartDate (Dan 1): {start_date.strftime('%d.%m.%Y')} - najstariji datum u PDF-u")
    
    current_day = 1
    current_workout = None
    current_exercises = []
    workout_date_map = {}  # Mapira dan na datum
    previous_line = None  # Čuva prethodnu liniju za ekstrakciju težine
    date_index = 0  # Indeks trenutnog datuma u all_dates listi
    
    # Prođi kroz sve linije i parsiraj treninge
    for i, line in enumerate(lines):
        line = line.strip()
        if not line:
            previous_line = None
            continue
        
        # Pokušaj da ekstraktuješ datum iz linije (npr. "🏋 C51 - pon, 23. feb 2026.")
        date = parse_date_from_text(line)
        if date and start_date:
            # Ako imamo mapiranje dana na datume, koristi ga
            # Inače, izračunaj koji dan je ovaj datum (razlika u danima od startDate + 1)
            matched_day = None
            for day_num, mapped_date in day_date_map.items():
                if mapped_date.date() == date.date():
                    matched_day = day_num
                    break
            
            if matched_day:
                current_day = matched_day
            else:
                # Izračunaj koji dan je ovaj datum (razlika u danima od startDate + 1)
                days_diff = (date - start_date).days + 1
                if days_diff > 0:  # Samo pozitivni dani
                    current_day = days_diff
                else:
                    current_day = None
            
            if current_day:
                date_str = date.isoformat()
                
                # Sačuvaj prethodni trening ako postoji
                if current_workout is not None:
                    workout_data = {
                        "id": current_workout["id"],
                        "day": current_workout["day"],
                        "name": f"Dan {current_workout['day']}",
                        "date": workout_date_map.get(current_workout["day"]),
                        "exercises": current_exercises,
                        "notes": current_workout.get("notes")
                    }
                    workouts.append(workout_data)
                
                # Kreiraj novi trening za ovaj datum
                workout_id = f"workout-day-{current_day}"
                current_workout = {
                    "id": workout_id,
                    "day": current_day,
                    "name": f"Dan {current_day}",
                    "notes": None
                }
                workout_date_map[current_day] = date_str
                current_exercises = []
                # Preskoči ovu liniju jer je samo datum header
                continue
        
        # Provera za dan/dan marker
        day_match = re.search(r'(?i)(day|dan|dan\s*)(\d+)', line)
        if day_match:
            # Sačuvaj prethodni trening ako postoji
            if current_workout is not None:
                workout_data = {
                    "id": current_workout["id"],
                    "day": current_workout["day"],
                    "name": f"Dan {current_workout['day']}",
                    "date": workout_date_map.get(current_workout["day"]),
                    "exercises": current_exercises,
                    "notes": current_workout.get("notes")
                }
                workouts.append(workout_data)
            
            # Ekstraktuj broj dana
            day_num = int(day_match.group(2))
            current_day = day_num
            
            # Kreiraj novi trening
            workout_id = f"workout-day-{day_num}"
            current_workout = {
                "id": workout_id,
                "day": day_num,
                "name": f"Dan {day_num}",
                "notes": None
            }
            current_exercises = []
            
            # Ako imamo mapiranje dana na datum, koristi ga
            if day_num in day_date_map:
                workout_date_map[day_num] = day_date_map[day_num].isoformat()
            elif start_date:
                # Ako nema eksplicitnog mapiranja, izračunaj datum za ovaj dan
                workout_date = start_date + timedelta(days=day_num - 1)
                workout_date_map[day_num] = workout_date.isoformat()
        else:
            # Preskoči linije koje su samo datumi ili headeri (bez smislenog sadržaja)
            if re.search(r'(?i)^(dnevnik|treninga|🏋)', line) and len(line) < 50:
                # Ako linija sadrži datum, već smo je obradili
                continue
            
            # Proveri da li je ovo header za novu vežbu
            if is_exercise_header(line):
                # Ekstraktuj informacije o vežbi
                exercise_info = extract_exercise_info(line)
                
                # Konvertuj odmor iz minuta u sekunde za duration
                duration_seconds = None
                if exercise_info.get("rest_minutes"):
                    duration_seconds = exercise_info["rest_minutes"] * 60
                
                # Kreiraj novu vežbu
                exercise = {
                    "id": None,
                    "name": exercise_info["name"],
                    "sets": exercise_info["sets"],
                    "reps": exercise_info["reps"],
                    "weight": None,  # Težina će biti iz serija
                    "duration": duration_seconds,
                    "notes": None
                }
                
                if current_workout is None:
                    # Ako nema dana, kreiraj trening za dan 1
                    current_day = 1
                    current_workout = {
                        "id": "workout-day-1",
                        "day": 1,
                        "name": "Dan 1",
                        "notes": None
                    }
                    # Ako imamo startDate, dodeli mu datum
                    if start_date:
                        workout_date_map[1] = start_date.isoformat()
                
                current_exercises.append(exercise)
                continue
            
            # Proveri da li je ovo linija sa podacima o seriji
            set_data = parse_set_line(line)
            if set_data and current_exercises:
                # Ažuriraj poslednju vežbu sa podacima o seriji
                # Ako vežba nema težinu, dodeli je iz serije
                if current_exercises[-1]["weight"] is None and set_data.get("weight"):
                    current_exercises[-1]["weight"] = set_data["weight"]
                # Ako vežba nema reps, dodeli iz serije
                if current_exercises[-1]["reps"] is None and set_data.get("reps"):
                    current_exercises[-1]["reps"] = set_data["reps"]
                
                # Ako težina nije u liniji sa serijom, proveri prethodnu liniju
                if current_exercises[-1]["weight"] is None and previous_line:
                    weight_match = re.search(r'(\d+(?:\.\d+)?)\s*(kg|lbs?|lb)', previous_line, re.IGNORECASE)
                    if weight_match:
                        weight_value = float(weight_match.group(1))
                        current_exercises[-1]["weight"] = weight_value
                
                # Ako i dalje nema težinu, proveri sledeću liniju (može biti posle serije)
                # Ovo će biti obrađeno u sledećoj iteraciji
                
                # Ignorišemo pojedinačne serije - vežba već ima sets/reps/weight
                previous_line = line
                continue
            
            # Pokušaj da nađeš težinu u liniji koja nije serija (može biti pre ili posle serija)
            # Format: "60kg" ili "60 kg" ili "60.0kg"
            # Ovo može biti linija posle serija koja sadrži samo težinu
            weight_match = re.search(r'^(\d+(?:\.\d+)?)\s*(kg|lbs?|lb)$', line, re.IGNORECASE)
            if weight_match and current_exercises and current_exercises[-1]["weight"] is None:
                # Linija koja sadrži samo težinu (npr. "60kg" ili "60 kg")
                weight_value = float(weight_match.group(1))
                current_exercises[-1]["weight"] = weight_value
                previous_line = line
                continue
            
            # Pokušaj da nađeš težinu u kratkoj liniji (može biti posle serija)
            weight_match = re.search(r'(\d+(?:\.\d+)?)\s*(kg|lbs?|lb)', line, re.IGNORECASE)
            if weight_match and current_exercises and current_exercises[-1]["weight"] is None:
                # Proveri da li linija izgleda kao podatak o težini (kratka linija)
                # Ignoriši ako je deo opisa (duga linija sa puno teksta)
                if len(line) < 50 and not re.search(r'[a-z]{10,}', line, re.IGNORECASE):
                    # Kratka linija bez puno teksta - verovatno je podatak o težini
                    weight_value = float(weight_match.group(1))
                    current_exercises[-1]["weight"] = weight_value
                previous_line = line
                continue
            
            # Sačuvaj prethodnu liniju za sledeću iteraciju
            previous_line = line
            
            # Ignoriši sve ostale linije (opis vežbe, itd.)
            # One nisu potrebne za strukturu podataka
    
    # Sačuvaj poslednji trening
    if current_workout is not None:
        workout_data = {
            "id": current_workout["id"],
            "day": current_workout["day"],
            "name": f"Dan {current_workout['day']}",
            "date": workout_date_map.get(current_workout["day"]),
            "exercises": current_exercises,
            "notes": current_workout.get("notes")
        }
        workouts.append(workout_data)
    
    # Sortiraj treninge po datumu (od najstarijeg do najnovijeg)
    workouts.sort(key=lambda x: (
        x.get("date") or "9999-12-31",  # Sortiraj po datumu prvo (najstariji prvo)
        x["day"]  # Pa po danu ako je isti datum
    ))
    
    # Prerasporedi brojeve dana - prvi odrađen trening = Dan 1, drugi = Dan 2, itd.
    for index, workout in enumerate(workouts, start=1):
        workout["day"] = index
        workout["name"] = f"Dan {index}"
        workout["id"] = f"workout-day-{index}"
    
    # Izračunaj startDate i endDate na osnovu datuma
    start_date_str = None
    end_date_str = None
    if start_date:
        start_date_str = start_date.isoformat()
        if workouts:
            # EndDate = startDate + (najveći dan - 1)
            max_day = max(w["day"] for w in workouts)
            end_date = start_date + timedelta(days=max_day - 1)
            end_date_str = end_date.isoformat()
    
    return {
        "planId": plan_id,
        "name": plan_name,
        "workouts": workouts,
        "startDate": start_date_str,
        "endDate": end_date_str,
        "notes": None
    }


def is_exercise_header(line):
    """Proverava da li je linija header za novu vežbu (sadrži ime vežbe i zagrade sa Serije/Ponavljanja)"""
    # Traži pattern: ime vežbe + (Serije: X, Ponavljanja: Y, Odmor: Z)
    pattern = r'.*\(.*[Ss]erije?\s*:\s*\d+.*[Pp]onavljanja?\s*:\s*\d+.*\)'
    return bool(re.search(pattern, line))


def is_set_line(line):
    """Proverava da li je linija podatak o seriji (npr. "1. x 6" ili "1.   x 6")"""
    # Pattern: broj + tačka + razmak + "x" + razmak + broj
    pattern = r'^\d+\.\s*[x×]\s*\d+'
    return bool(re.search(pattern, line))


def extract_exercise_info(line):
    """Ekstraktuje informacije o vežbi iz header linije"""
    # Ekstraktuj ime vežbe (deo pre zagrade)
    name_match = re.match(r'^([^(]+)', line)
    exercise_name = name_match.group(1).strip() if name_match else line
    
    # Ekstraktuj serije, ponavljanja i odmor iz zagrade
    sets_match = re.search(r'[Ss]erije?\s*:\s*(\d+)', line)
    reps_match = re.search(r'[Pp]onavljanja?\s*:\s*(\d+)', line)
    rest_match = re.search(r'[Oo]dmor\s*:\s*(\d+)\s*(min|sek)', line)
    
    sets = int(sets_match.group(1)) if sets_match else None
    reps = int(reps_match.group(1)) if reps_match else None
    rest_min = int(rest_match.group(1)) if rest_match else None
    
    return {
        "name": exercise_name,
        "sets": sets,
        "reps": reps,
        "rest_minutes": rest_min
    }


def parse_set_line(line):
    """Parsira liniju sa podacima o seriji (npr. "1. x 6" sa težinom 60kg)"""
    # Pattern: broj. x broj (sa opcionom težinom)
    # Može biti: "1. x 6", "1.   x 6", "1. x 6 (60kg)", "1. x 6 60kg"
    set_match = re.match(r'^(\d+)\.\s*[x×]\s*(\d+)', line)
    if not set_match:
        return None
    
    set_num = int(set_match.group(1))
    reps = int(set_match.group(2))
    
    # Pokušaj da ekstraktuješ težinu iz linije (može biti u zagradi, posle reps, itd.)
    # Formati: "1. x 6 (60kg)", "1. x 6 60kg", "1. x 6 - 60kg"
    weight_match = re.search(r'(\d+(?:\.\d+)?)\s*(kg|lbs?|lb)', line, re.IGNORECASE)
    weight = float(weight_match.group(1)) if weight_match else None
    
    return {
        "set_number": set_num,
        "reps": reps,
        "weight": weight
    }


def normalize_meal_time(time_str):
    """Normalizuje vreme obroka na standardne vrednosti"""
    time_lower = time_str.lower()
    if 'doručak' in time_lower or 'breakfast' in time_lower:
        return "Doručak"
    elif 'ručak' in time_lower or 'lunch' in time_lower:
        return "Ručak"
    elif 'večera' in time_lower or 'dinner' in time_lower:
        return "Večera"
    elif 'užina' in time_lower or 'snack' in time_lower:
        return "Užina"
    return time_str.capitalize()


def extract_nutrition_info(line):
    """Ekstraktuje nutritivne vrednosti iz linije (kalorije, proteini, ugljeni hidrati, masti)"""
    # Pattern: "289 kcal", "289 kcal", "289kcal"
    calories_match = re.search(r'(\d+)\s*kcal', line, re.IGNORECASE)
    calories = int(calories_match.group(1)) if calories_match else None
    
    # Pattern: "20g proteina", "20 g proteina", "20g protein"
    protein_match = re.search(r'(\d+(?:\.\d+)?)\s*g\s*(?:proteina?|protein)', line, re.IGNORECASE)
    protein = float(protein_match.group(1)) if protein_match else None
    
    # Pattern: "30g ugljenih hidrata", "30g carbs", "30 g ugljeni"
    carbs_match = re.search(r'(\d+(?:\.\d+)?)\s*g\s*(?:ugljenih?\s*hidrata?|carbs?|ugljeni)', line, re.IGNORECASE)
    carbs = float(carbs_match.group(1)) if carbs_match else None
    
    # Pattern: "15g masti", "15g fat", "15 g mast"
    fat_match = re.search(r'(\d+(?:\.\d+)?)\s*g\s*(?:masti?|fat)', line, re.IGNORECASE)
    fat = float(fat_match.group(1)) if fat_match else None
    
    return {
        "calories": calories,
        "protein": protein,
        "carbs": carbs,
        "fat": fat
    }


def is_meal_header(line):
    """Proverava da li je linija header za novi obrok (sadrži vreme obroka i možda kalorije)"""
    # Pattern: "🍴 Doručak (10254 kcal)" ili "Doručak" ili "Breakfast (500 kcal)"
    time_pattern = r'(?i)(breakfast|doručak|lunch|ručak|dinner|večera|snack|užina)'
    return bool(re.search(time_pattern, line))


def is_recipe_name(line):
    """Proverava da li je linija ime recepta (sadrži ime i možda kalorije u zagradi)"""
    # Pattern: "Mafini od jaja i povrća (289 kcal)" ili "Recept: Mafini"
    recipe_pattern = r'^[A-ZČĆŠĐŽ][^()]+(?:\([^)]*kcal[^)]*\))?$'
    # Ne sme biti samo "Recepti:" ili "Recept:"
    if re.match(r'^[Rr]ecepti?:?\s*$', line):
        return False
    return bool(re.search(recipe_pattern, line)) and len(line) > 10


def parse_meal_plan(text, plan_id, plan_name):
    """Parsira tekst i kreira MealPlan JSON strukturu sa kategorijama"""
    meals = []
    lines = text.split('\n')
    
    current_meal = None
    current_foods = []
    current_recipe = []
    current_time = None
    in_recipe = False
    
    for line in lines:
        line = line.strip()
        if not line:
            if in_recipe and current_recipe:
                # Prazna linija može značiti kraj recepta
                in_recipe = False
            continue
        
        # Provera za vreme obroka (kategorija)
        if is_meal_header(line):
            # Sačuvaj prethodni obrok ako postoji
            if current_meal is not None:
                # Sačuvaj recept ako postoji
                recipe_text = ' '.join(current_recipe).strip() if current_recipe else None
                if recipe_text:
                    current_meal["recipe"] = recipe_text
                
                meals.append({
                    "id": current_meal["id"],
                    "day": current_meal.get("day"),
                    "time": current_meal["time"],
                    "name": current_meal["name"],
                    "foods": current_foods,
                    "calories": current_meal.get("calories"),
                    "protein": current_meal.get("protein"),
                    "carbs": current_meal.get("carbs"),
                    "fat": current_meal.get("fat"),
                    "recipe": current_meal.get("recipe"),
                    "notes": current_meal.get("notes")
                })
            
            # Ekstraktuj vreme i normalizuj
            time_match = re.search(r'(?i)(breakfast|doručak|lunch|ručak|dinner|večera|snack|užina)', line)
            if time_match:
                current_time = normalize_meal_time(time_match.group(0))
            else:
                current_time = "Meal"
            
            # Ekstraktuj nutritivne vrednosti iz header-a
            nutrition = extract_nutrition_info(line)
            
            # Ekstraktuj ime obroka (deo bez vremena i kalorija)
            meal_name = line
            # Ukloni emoji i vreme
            meal_name = re.sub(r'[🍴🍽️]', '', meal_name).strip()
            meal_name = re.sub(r'(?i)(breakfast|doručak|lunch|ručak|dinner|večera|snack|užina)', '', meal_name).strip()
            # Ukloni kalorije u zagradi
            meal_name = re.sub(r'\([^)]*kcal[^)]*\)', '', meal_name).strip()
            if not meal_name:
                meal_name = current_time
            
            # Kreiraj novi obrok
            meal_id = f"meal-{len(meals) + 1}"
            current_meal = {
                "id": meal_id,
                "day": None,
                "time": current_time,
                "name": meal_name,
                "calories": nutrition["calories"],
                "protein": nutrition["protein"],
                "carbs": nutrition["carbs"],
                "fat": nutrition["fat"],
                "recipe": None,
                "notes": None
            }
            current_foods = []
            current_recipe = []
            in_recipe = False
            continue
        
        # Provera za ime recepta (npr. "Mafini od jaja i povrća (289 kcal)")
        if is_recipe_name(line) and current_meal:
            # Ako već imamo obrok, sačuvaj ga i kreiraj novi za ovaj recept
            if current_meal["name"] != current_time:  # Ako već ima ime (nije samo kategorija)
                recipe_text = ' '.join(current_recipe).strip() if current_recipe else None
                if recipe_text:
                    current_meal["recipe"] = recipe_text
                
                meals.append({
                    "id": current_meal["id"],
                    "day": current_meal.get("day"),
                    "time": current_meal["time"],
                    "name": current_meal["name"],
                    "foods": current_foods,
                    "calories": current_meal.get("calories"),
                    "protein": current_meal.get("protein"),
                    "carbs": current_meal.get("carbs"),
                    "fat": current_meal.get("fat"),
                    "recipe": current_meal.get("recipe"),
                    "notes": current_meal.get("notes")
                })
            
            # Ekstraktuj ime recepta i nutritivne vrednosti
            nutrition = extract_nutrition_info(line)
            recipe_name = line
            # Ukloni kalorije u zagradi
            recipe_name = re.sub(r'\([^)]*kcal[^)]*\)', '', recipe_name).strip()
            recipe_name = re.sub(r'\([^)]*\)', '', recipe_name).strip()
            
            # Kreiraj novi obrok za ovaj recept
            meal_id = f"meal-{len(meals) + 1}"
            current_meal = {
                "id": meal_id,
                "day": None,
                "time": current_time or "Meal",
                "name": recipe_name,
                "calories": nutrition["calories"],
                "protein": nutrition["protein"],
                "carbs": nutrition["carbs"],
                "fat": nutrition["fat"],
                "recipe": None,
                "notes": None
            }
            current_foods = []
            current_recipe = []
            in_recipe = True
            continue
        
        # Ako smo u receptu, dodaj u recept
        if in_recipe and current_meal:
            # Preskoči linije koje su samo "Recepti:" ili "Recept:"
            if re.match(r'^[Rr]ecepti?:?\s*$', line):
                continue
            current_recipe.append(line)
            continue
        
        # Pokušaj da parsiraš namirnicu
        food = parse_food_item(line)
        if food and current_meal:
            current_foods.append(food)
    
    # Sačuvaj poslednji obrok
    if current_meal is not None:
        recipe_text = ' '.join(current_recipe).strip() if current_recipe else None
        if recipe_text:
            current_meal["recipe"] = recipe_text
        
        meals.append({
            "id": current_meal["id"],
            "day": current_meal.get("day"),
            "time": current_meal["time"],
            "name": current_meal["name"],
            "foods": current_foods,
            "calories": current_meal.get("calories"),
            "protein": current_meal.get("protein"),
            "carbs": current_meal.get("carbs"),
            "fat": current_meal.get("fat"),
            "recipe": current_meal.get("recipe"),
            "notes": current_meal.get("notes")
        })
    
    return {
        "planId": plan_id,
        "name": plan_name,
        "meals": meals,
        "startDate": None,
        "endDate": None,
        "notes": None
    }


def parse_food_item(line):
    """Parsira liniju i kreira FoodItem objekat"""
    if len(line) < 2:
        return None
    
    # Preskoči linije koje su samo "Recepti:" ili "Recept:"
    if re.match(r'^[Rr]ecepti?:?\s*$', line):
        return None
    
    # Preskoči linije koje su deo recepta (dugačak tekst bez nutritivnih vrednosti)
    # Ako linija ne sadrži kalorije ili količinu, a duga je, verovatno je deo recepta
    if len(line) > 100 and not re.search(r'(\d+\s*kcal|kcal|\d+\s*g|\d+\s*komad)', line, re.IGNORECASE):
        return None
    
    food = {
        "id": None,  # Generiše se u aplikaciji
        "name": line,
        "quantity": None,
        "calories": None
    }
    
    # Pokušaj da ekstraktuješ količinu (npr. "200g", "1 cup", "100ml", "1 komad/a")
    quantity_match = re.search(r'(\d+(?:\.\d+)?)\s*(g|kg|ml|l|cup|cups|tbsp|tsp|oz|lb|komad)', line, re.IGNORECASE)
    if quantity_match:
        food["quantity"] = quantity_match.group(0)
        # Ukloni količinu iz imena
        food["name"] = re.sub(r'\d+(?:\.\d+)?\s*(?:g|kg|ml|l|cup|cups|tbsp|tsp|oz|lb|komad)', '', line, flags=re.IGNORECASE).strip()
    
    # Pokušaj da ekstraktuješ kalorije (npr. "200 kcal", "200 calories")
    cal_match = re.search(r'(\d+)\s*(kcal|calories?|cal)', line, re.IGNORECASE)
    if cal_match:
        food["calories"] = int(cal_match.group(1))
    
    if not food["name"]:
        food["name"] = line
    
    return food


def extract_plan_id(filename):
    """Ekstraktuje plan ID iz imena fajla"""
    match = re.search(r'-(\d+)', filename)
    if match:
        return match.group(1)
    return None


def extract_plan_name(filename, text):
    """Ekstraktuje ime plana iz fajla ili teksta"""
    # Pokušaj da nađeš naslov u tekstu
    title_match = re.search(r'(?i)(title|plan|program)[\s:]+([^\n]+)', text)
    if title_match:
        title = title_match.group(2).strip()
        if title:
            return title
    
    # Koristi ime fajla
    name = filename.replace('.pdf', '').replace('-', ' ').title()
    # Ukloni ID ako postoji
    name = re.sub(r'\s+\d+$', '', name)
    return name


def main():
    if len(sys.argv) < 2:
        print("Upotreba: python pdf_to_json.py <pdf_file> [output_file]")
        print("Primer: python pdf_to_json.py program-102234.pdf program-102234.json")
        sys.exit(1)
    
    pdf_path = Path(sys.argv[1])
    if not pdf_path.exists():
        print(f"Fajl ne postoji: {pdf_path}")
        sys.exit(1)
    
    # Odredi output fajl
    if len(sys.argv) > 2:
        output_path = Path(sys.argv[2])
    else:
        output_path = pdf_path.with_suffix('.json')
    
    # Ekstraktuj tekst
    print(f"Čitanje PDF-a: {pdf_path}")
    text = extract_text_from_pdf(pdf_path)
    if text is None:
        sys.exit(1)
    
    # Odredi tip plana i parsiraj
    filename = pdf_path.stem
    plan_id = extract_plan_id(filename) or "plan-1"
    plan_name = extract_plan_name(filename, text)
    
    if 'program' in filename.lower() or 'workout' in filename.lower():
        print("Parsiranje workout plana...")
        result = parse_workout_plan(text, plan_id, plan_name)
    elif 'meal' in filename.lower() or 'ishrana' in filename.lower():
        print("Parsiranje meal plana...")
        result = parse_meal_plan(text, plan_id, plan_name)
    else:
        print("Ne mogu da odredim tip plana. Koristim workout plan parser.")
        result = parse_workout_plan(text, plan_id, plan_name)
    
    # Sačuvaj JSON
    print(f"Čuvanje JSON-a: {output_path}")
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(result, f, indent=2, ensure_ascii=False)
    
    print(f"Uspešno! Kreiran JSON fajl: {output_path}")
    print(f"Broj elemenata: {len(result.get('workouts', result.get('meals', [])))}")


if __name__ == "__main__":
    main()
