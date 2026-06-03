# Plan Generator Specification

## Goal
Generate high-quality, personalized workout plans using DeepSeek AI. Each workout must have 5-8 exercises minimum. The plan must be realistic and usable, not just random exercises thrown together.

## How It Works

### 1. Onboarding Input
User provides during onboarding:
- **Goal**: dobijanje mase / mršavljenje / održavanje / definicija
- **Level**: pocetnik / srednji / napredan
- **Days per week**: 2-6
- **Equipment**: teretana / kucni / bodyweight (multi-select)
- **Injuries**: ledja / kolena / ramena / vrat / zglobovi (multi-select)
- **Has nutrition**: bool
- **Meals per day** (if nutrition): 3-6

### 2. Template Data
Supabase tables used as reference:
- `workouts` (175 template workouts, plan_id = "102234")
- `exercises` (linked to each workout)
- `exercise_catalog` (all available exercises with categories)

### 3. Data Preparation

Before calling the AI, the app must:

1. **Fetch all template workouts** from `workouts` table where `plan_id = "102234"`
2. **Fetch all exercises** for those workouts from `exercises` table
3. **Fetch exercise catalog** from `exercise_catalog` table (names + categories)

### 4. AI Prompt Engineering

The prompt sent to DeepSeek must include:

1. **User profile**: goal, level, days/week, equipment, injuries
2. **Available exercises**: grouped by category (chest, back, legs, shoulders, arms, core, cardio)
3. **Template reference**: "Here are 175 real workouts used as reference. Create a similar structured plan."

System prompt:
```
You are an elite fitness coach creating personalized workout plans. 

RULES:
1. Create EXACTLY [days_per_week] workouts
2. Each workout MUST have 5-8 exercises
3. Never repeat the same exercise across multiple workouts in the same week
4. Match the user's goal:
   - "dobijanje mase": 8-12 reps, 3-4 sets, focus on compound lifts
   - "mrsavljenje": 12-15 reps, 3-4 sets, supersets, shorter rest
   - "odrzavanje": 10-12 reps, 3 sets
   - "definicija": 12-15 reps, 3-4 sets, drop sets
5. Match the user's level:
   - "pocetnik": simpler exercises, more machine/cable work, lower volume
   - "srednji": mix of compound and isolation, moderate volume
   - "napredan": advanced techniques, high volume, progressive overload
6. Respect equipment:
   - "teretana": barbell, dumbbell, machines, cables
   - "kucni": dumbbell only, bands, bodyweight
   - "bodyweight": only bodyweight exercises
7. Avoid exercises that conflict with reported injuries
8. Structure workouts logically (push/pull/legs or upper/lower or full body)
9. Name each workout descriptively in Serbian
10. Return ONLY valid JSON, no markdown
```

User prompt format:
```
Napravi plan treninga za:
- Cilj: [goal]
- Nivo: [level]
- Dana nedeljno: [days]
- Oprema: [equipment]
- Povrede: [injuries]

Dostupne vezbe (izaberi odgovarajuce):
[category_1]: [exercise_1, exercise_2, ...]
[category_2]: [exercise_1, exercise_2, ...]
...

Primer strukture treninga iz nase baze (jedan od 175):
- Gornji deo: bench press, military press, pull ups, lateral raises, triceps dips, bicep curls, face pulls
- Donji deo: squat, deadlift, leg press, lunges, leg curls, calf raises

Vrati JSON:
{"workouts": [{"name": "Naziv", "day": 1, "exercises": [{"name": "Vezba", "sets": 3, "reps": 10}]}]}
```

### 5. Response Parsing

After getting AI response:
1. Parse JSON from response
2. Validate: each workout has 5-8 exercises
3. If less than 5 exercises per workout → ask AI to regenerate with stricter instructions
4. Save to `user_workouts` + `user_exercise_records`

### 6. Fallback Plan (when AI fails)

If AI is unavailable, use a rule-based generator:
- Select exercises from catalog filtered by equipment and injuries
- Group by muscle group
- Assign 5-8 exercises per workout based on push/pull/legs split
- Use default sets/reps based on level and goal

### 7. "Započni trening" Button

After onboarding completes:
1. Save workouts to Supabase
2. Show the generated plan on a success screen
3. "Započni trening" button navigates to Workouts tab (Tab 1)
4. The generated workouts should appear in the "Plan treninga" section

### 8. Implementation Checklist

- [ ] Fetch template workouts + exercises from Supabase
- [ ] Build detailed prompt with categorized exercises
- [ ] Call DeepSeek API
- [ ] Parse and validate response
- [ ] Show results on success screen
- [ ] "Započni trening" navigates to workouts tab
- [ ] Fallback plan with minimum 5 exercises per workout
- [ ] Error handling for API failures
