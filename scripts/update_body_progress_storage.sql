-- Body progress cloud sync (entries + photo blob as base64 text)

create table if not exists public.user_body_progress (
    id text primary key,
    date timestamptz not null,
    weight double precision,
    waist double precision,
    chest double precision,
    arm double precision,
    photo_path text,
    photo_base64 text,
    analysis_json text,
    comparison_json text,
    created_at timestamptz not null default now()
);

alter table public.user_body_progress
    add column if not exists comparison_json text;
alter table public.user_body_progress
    add column if not exists photo_path text;

alter table public.user_body_progress enable row level security;

drop policy if exists "Users can view own body progress" on public.user_body_progress;
create policy "Users can view own body progress"
on public.user_body_progress
for select
using (true);

drop policy if exists "Users can insert own body progress" on public.user_body_progress;
create policy "Users can insert own body progress"
on public.user_body_progress
for insert
with check (true);

drop policy if exists "Users can update own body progress" on public.user_body_progress;
create policy "Users can update own body progress"
on public.user_body_progress
for update
using (true)
with check (true);

drop policy if exists "Users can delete own body progress" on public.user_body_progress;
create policy "Users can delete own body progress"
on public.user_body_progress
for delete
using (true);

insert into storage.buckets (id, name, public)
values ('body-progress-photos', 'body-progress-photos', false)
on conflict (id) do nothing;

drop policy if exists "Body progress photos read" on storage.objects;
create policy "Body progress photos read"
on storage.objects
for select
using (bucket_id = 'body-progress-photos' and auth.role() = 'authenticated');

drop policy if exists "Body progress photos insert" on storage.objects;
create policy "Body progress photos insert"
on storage.objects
for insert
with check (bucket_id = 'body-progress-photos' and auth.role() = 'authenticated');

drop policy if exists "Body progress photos update" on storage.objects;
create policy "Body progress photos update"
on storage.objects
for update
using (bucket_id = 'body-progress-photos' and auth.role() = 'authenticated')
with check (bucket_id = 'body-progress-photos' and auth.role() = 'authenticated');

drop policy if exists "Body progress photos delete" on storage.objects;
create policy "Body progress photos delete"
on storage.objects
for delete
using (bucket_id = 'body-progress-photos' and auth.role() = 'authenticated');
