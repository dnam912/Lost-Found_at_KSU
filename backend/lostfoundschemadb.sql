-- db schema: extensions, tables, auth signup, RLS, and item_images storage.

-- EXTENSIONS
create extension if not exists pgcrypto with schema extensions;
create extension if not exists vector with schema extensions;

set search_path = public, extensions;

-- TABLES
create table public.users (
  user_id uuid primary key references auth.users (id) on delete cascade,
  email text not null unique,
  role text not null default 'student',
  created_at timestamptz not null default now(),
  constraint users_kent_email_chk check (lower(email) like '%@kent.edu'),
  constraint users_role_chk check (role in ('student', 'admin'))
);

create table public.items (
  item_id uuid primary key default gen_random_uuid(),
  category text,
  primary_color text,
  material text,
  description_raw text,
  created_at timestamptz not null default now()
);

create table public.reports (
  report_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (user_id) on delete cascade,
  item_id uuid not null references public.items (item_id) on delete cascade,
  status text not null,
  report_date date,
  estimated_time_start time,
  estimated_time_end time,
  location text,
  area text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint reports_status_chk check (status in ('lost', 'found')),
  constraint reports_estimated_time_window_chk check (
    estimated_time_start is null
    or estimated_time_end is null
    or estimated_time_start <= estimated_time_end
  )
);

create index reports_user_id_idx on public.reports (user_id);
create index reports_item_id_idx on public.reports (item_id);
create index reports_status_idx on public.reports (status);
create index reports_report_date_idx on public.reports (report_date);

create table public.item_images (
  image_id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.items (item_id) on delete cascade,
  image_url text not null,
  image_type text not null,
  -- Temporary text stand-in; replace with vector later
  embedding text,
  created_at timestamptz not null default now(),
  constraint item_images_type_chk check (image_type in ('photo', 'sketch'))
);

create index item_images_item_id_idx on public.item_images (item_id);

create table public.extracted_features (
  feature_id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.items (item_id) on delete cascade,
  feature_type text not null,
  feature_value text not null,
  visibility text not null default 'public',
  created_at timestamptz not null default now(),
  constraint extracted_features_visibility_chk check (visibility in ('public', 'private'))
);

create index extracted_features_item_id_idx on public.extracted_features (item_id);
create index extracted_features_visibility_idx on public.extracted_features (visibility);

-- FUNCTIONS & TRIGGERS
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger reports_set_updated_at
  before update on public.reports
  for each row execute function public.set_updated_at();

create or replace function public.enforce_kent_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.email is null or lower(new.email) not like '%@kent.edu' then
    raise exception 'Only @kent.edu Google accounts are allowed';
  end if;
  return new;
end;
$$;

create trigger enforce_kent_email_on_signup
  before insert or update of email on auth.users
  for each row execute function public.enforce_kent_email();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (user_id, email, role)
  values (new.id, new.email, 'student');
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ROW LEVEL SECURITY
alter table public.users enable row level security;
alter table public.items enable row level security;
alter table public.reports enable row level security;
alter table public.item_images enable row level security;
alter table public.extracted_features enable row level security;

create policy users_select_own
  on public.users for select to authenticated
  using (user_id = auth.uid());

create policy users_update_own
  on public.users for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy items_select_authenticated
  on public.items for select to authenticated using (true);

create policy items_insert_authenticated
  on public.items for insert to authenticated with check (true);

create policy items_update_via_own_report
  on public.items for update to authenticated
  using (
    exists (
      select 1 from public.reports r
      where r.item_id = items.item_id and r.user_id = auth.uid()
    )
  );

create policy reports_select_authenticated
  on public.reports for select to authenticated using (true);

create policy reports_insert_own
  on public.reports for insert to authenticated
  with check (user_id = auth.uid());

create policy reports_update_own
  on public.reports for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy item_images_select_authenticated
  on public.item_images for select to authenticated using (true);

create policy item_images_insert_via_own_report
  on public.item_images for insert to authenticated
  with check (
    exists (
      select 1 from public.reports r
      where r.item_id = item_images.item_id and r.user_id = auth.uid()
    )
  );

create policy extracted_features_select
  on public.extracted_features for select to authenticated
  using (
    visibility = 'public'
    or exists (
      select 1 from public.reports r
      where r.item_id = extracted_features.item_id and r.user_id = auth.uid()
    )
  );

create policy extracted_features_insert_via_own_report
  on public.extracted_features for insert to authenticated
  with check (
    exists (
      select 1 from public.reports r
      where r.item_id = extracted_features.item_id and r.user_id = auth.uid()
    )
  );

-- STORAGE BUCKET & STORAGE POLICIES
insert into storage.buckets (id, name, public)
values ('item_images', 'item_images', true)
on conflict (id) do nothing;

create policy "Public read access for item images bucket"
  on storage.objects for select to public
  using (bucket_id = 'item_images');

create policy "Authenticated upload access for item images bucket"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'item_images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Owners update access for item images bucket"
  on storage.objects for update to authenticated
  using (bucket_id = 'item_images' and owner = auth.uid())
  with check (bucket_id = 'item_images' and owner = auth.uid());

create policy "Owners delete access for item images bucket"
  on storage.objects for delete to authenticated
  using (bucket_id = 'item_images' and owner = auth.uid());
