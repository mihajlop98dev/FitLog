# Firestore Database Struktura

## Gde se podaci čuvaju

### 1. Workout Plans (Planovi Treninga)

**Kolekcija:** `workoutPlans`

**Struktura:**
```
workoutPlans/
  └── {planId}/                    # Dokument sa metadata plana
      ├── planId: "102234"
      ├── name: "Program"
      ├── startDate: Timestamp
      ├── endDate: Timestamp
      └── notes: String?
      
      └── workouts/                # Subkolekcija sa treningima
          ├── workout-day-1/       # Dokument sa metadata treninga za dan 1
          │   ├── id: "workout-day-1"
          │   ├── day: 1
          │   ├── name: "Workout"
          │   └── notes: String?
          │
          │   └── exercises/       # Subkolekcija sa vežbama
          │       ├── exercise-1/  # Dokument sa vežbom 1
          │       │   ├── id: "exercise-1"
          │       │   ├── name: "Vežba 1"
          │       │   ├── sets: Int?
          │       │   ├── reps: Int?
          │       │   ├── weight: Double?
          │       │   ├── duration: Int?
          │       │   └── notes: String?
          │       ├── exercise-2/  # Dokument sa vežbom 2
          │       └── ...
          │
          ├── workout-day-2/       # Dokument sa treningom za dan 2
          │   └── exercises/       # Subkolekcija sa vežbama
          └── ...
```

**Primer putanje:**
- Plan metadata: `workoutPlans/102234`
- Trening metadata za dan 1: `workoutPlans/102234/workouts/workout-day-1`
- Vežbe za dan 1: `workoutPlans/102234/workouts/workout-day-1/exercises/`
- Trening metadata za dan 2: `workoutPlans/102234/workouts/workout-day-2`
- Vežbe za dan 2: `workoutPlans/102234/workouts/workout-day-2/exercises/`

### 2. Meal Plans (Planovi Ishrane)

**Kolekcija:** `mealPlans`

**Struktura:**
```
mealPlans/
  └── {planId}/                    # Dokument sa metadata plana
      ├── planId: "102234"
      ├── name: "Meal Plan"
      ├── startDate: Timestamp
      ├── endDate: Timestamp
      └── notes: String?
      
      └── meals/                    # Subkolekcija sa obrocima
          ├── meal-1/              # Dokument sa obrokom 1
          │   ├── id: "meal-1"
          │   ├── day: Int?
          │   ├── time: "Breakfast"
          │   ├── name: "Doručak"
          │   ├── foods: [...]
          │   ├── calories: Int?
          │   └── notes: String?
          ├── meal-2/              # Dokument sa obrokom 2
          └── ...
```

**Primer putanje:**
- Plan metadata: `mealPlans/102234`
- Obrok 1: `mealPlans/102234/meals/meal-1`
- Obrok 2: `mealPlans/102234/meals/meal-2`

### 3. Workouts (Završeni Treningi)

**Kolekcija:** `workouts`

**Struktura:**
```
workouts/
  └── {workoutId}/                 # Svaki završeni trening kao dokument
      ├── id: UUID
      ├── name: "Trening 1"
      ├── date: Timestamp
      ├── exercises: [...]
      ├── isCompleted: true
      ├── duration: Int?
      └── notes: String?
```

### 4. Meals (Dodatni Obroci)

**Kolekcija:** `meals`

**Struktura:**
```
meals/
  └── {mealId}/                    # Svaki dodatni obrok kao dokument
      ├── id: UUID
      ├── name: "Obrok"
      ├── time: "Lunch"
      ├── foods: [...]
      ├── calories: Int?
      ├── date: Timestamp?
      └── notes: String?
```

## Zašto Subkolekcije?

Firestore ima limit od **1 MB po dokumentu**. Veliki planovi (kao što je vaš sa 1.2MB) ne mogu se sačuvati kao jedan dokument.

**Rešenje:** Koristimo subkolekcije gde:
- Plan metadata je mali dokument (< 1KB)
- Svaki trening/obrok je poseban dokument u subkolekciji
- Ovo omogućava neograničenu veličinu plana

## Kako pristupiti podacima u Firebase Console

1. Idite u [Firebase Console](https://console.firebase.google.com/)
2. Izaberite vaš projekat
3. Idite na **Firestore Database**
4. Videćete kolekcije:
   - `workoutPlans` - kliknite da vidite planove
   - `mealPlans` - kliknite da vidite planove ishrane
   - `workouts` - završeni treningi
   - `meals` - dodatni obroci

5. Za pregled treninga u planu:
   - Kliknite na `workoutPlans` → `102234` → `workouts`
   - Videćete sve treninge u planu

6. Za pregled obroka u planu:
   - Kliknite na `mealPlans` → `102234` → `meals`
   - Videćete sve obroke u planu
