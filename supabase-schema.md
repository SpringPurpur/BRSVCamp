# BRSVCamp — Supabase Schema & Setup

Rulează secțiunile SQL în **Supabase → SQL Editor**, în ordinea în care apar.

---

## 1. Tabele

### `profiles` — extinde auth.users

```sql
create table profiles (
  id            uuid primary key references auth.users on delete cascade,
  display_name  text not null,
  avatar_color  text not null default '#3B82F6',
  share_location boolean not null default true,
  share_battery  boolean not null default true,
  appear_online  boolean not null default true,
  created_at    timestamptz not null default now()
);
```

> `avatar_color` — hex string, setat la înregistrare. Folosit pentru avatar-ul colorat din UI.

---

### `groups`

```sql
create table groups (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  invite_code  text not null unique,
  created_by   uuid not null references profiles on delete set null,
  created_at   timestamptz not null default now()
);
```

---

### `group_members`

```sql
create type member_role as enum ('admin', 'member');

create table group_members (
  id        uuid primary key default gen_random_uuid(),
  group_id  uuid not null references groups on delete cascade,
  user_id   uuid not null references profiles on delete cascade,
  role      member_role not null default 'member',
  joined_at timestamptz not null default now(),
  unique (group_id, user_id)
);
```

---

### `user_locations` — Realtime, UPSERT, un rând per user per grup

```sql
create table user_locations (
  user_id       uuid not null references profiles on delete cascade,
  group_id      uuid not null references groups on delete cascade,
  latitude      float8 not null,
  longitude     float8 not null,
  accuracy      float8,
  battery_level smallint check (battery_level between 0 and 100),
  is_online     boolean not null default true,
  updated_at    timestamptz not null default now(),
  primary key (user_id, group_id)
);
```

> PK compus `(user_id, group_id)` permite UPSERT direct fără index separat.

---

### `points_of_interest`

```sql
create type poi_category as enum (
  'restaurant', 'viewpoint', 'camp', 'activity', 'other'
);

create table points_of_interest (
  id          uuid primary key default gen_random_uuid(),
  group_id    uuid not null references groups on delete cascade,
  created_by  uuid not null references profiles on delete set null,
  title       text not null,
  description text,
  latitude    float8 not null,
  longitude   float8 not null,
  category    poi_category not null default 'other',
  photo_url   text,
  created_at  timestamptz not null default now()
);
```

---

### `blog_posts`

```sql
create table blog_posts (
  id         uuid primary key default gen_random_uuid(),
  group_id   uuid not null references groups on delete cascade,
  author_id  uuid not null references profiles on delete set null,
  poi_id     uuid references points_of_interest on delete set null,
  title      text not null,
  content    text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table blog_post_photos (
  id           uuid primary key default gen_random_uuid(),
  post_id      uuid not null references blog_posts on delete cascade,
  storage_path text not null,
  order_index  smallint not null default 0
);
```

---

### `expenses` + `expense_splits`

```sql
create type expense_category as enum (
  'food', 'transport', 'accommodation', 'activities', 'other'
);

create table expenses (
  id          uuid primary key default gen_random_uuid(),
  group_id    uuid not null references groups on delete cascade,
  paid_by     uuid not null references profiles on delete set null,
  amount      numeric(10, 2) not null check (amount > 0),
  currency    text not null default 'RON',
  category    expense_category not null default 'other',
  description text not null,
  receipt_url text,
  date        date not null default current_date,
  created_at  timestamptz not null default now()
);

create table expense_splits (
  id          uuid primary key default gen_random_uuid(),
  expense_id  uuid not null references expenses on delete cascade,
  user_id     uuid not null references profiles on delete cascade,
  amount      numeric(10, 2) not null check (amount > 0),
  settled     boolean not null default false,
  settled_at  timestamptz,
  unique (expense_id, user_id)
);
```

---

## 2. Indexes

```sql
create index on group_members (user_id);
create index on group_members (group_id);
create index on user_locations (group_id);
create index on points_of_interest (group_id);
create index on blog_posts (group_id);
create index on expenses (group_id);
create index on expense_splits (expense_id);
```

---

## 3. Funcții helper

### `is_group_member` — folosită în toate politicile RLS

```sql
create or replace function is_group_member(gid uuid)
returns boolean
language sql security definer stable as $$
  select exists (
    select 1 from group_members
    where group_id = gid
      and user_id  = auth.uid()
  );
$$;
```

### `handle_new_user` — creează profilul automat la înregistrare

```sql
create or replace function handle_new_user()
returns trigger
language plpgsql security definer as $$
begin
  insert into profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();
```

### `join_group_by_code` — alăturare grup cu invite code

```sql
create or replace function join_group_by_code(p_invite_code text)
returns uuid
language plpgsql security definer as $$
declare
  v_group_id uuid;
begin
  select id into v_group_id
  from groups
  where invite_code = upper(p_invite_code);

  if v_group_id is null then
    raise exception 'Cod de invitație invalid.';
  end if;

  insert into group_members (group_id, user_id, role)
  values (v_group_id, auth.uid(), 'member')
  on conflict (group_id, user_id) do nothing;

  return v_group_id;
end;
$$;
```

> Apelat din Swift: `supabase.rpc("join_group_by_code", params: ["p_invite_code": code])`

### `generate_invite_code` — generat la creare grup

```sql
create or replace function generate_invite_code()
returns text
language sql as $$
  select upper(
    substr(md5(random()::text), 1, 4) || '-' ||
    substr(md5(random()::text), 1, 4)
  );
$$;
```

> Apelat din Swift la creare grup: `let code = try await supabase.rpc("generate_invite_code").execute().value`  
> Sau generezi codul direct în Swift și îl trimiți la INSERT.

---

## 4. Row Level Security (RLS)

Activează RLS pe toate tabelele, apoi adaugă politicile.

```sql
alter table profiles           enable row level security;
alter table groups             enable row level security;
alter table group_members      enable row level security;
alter table user_locations     enable row level security;
alter table points_of_interest enable row level security;
alter table blog_posts         enable row level security;
alter table blog_post_photos   enable row level security;
alter table expenses           enable row level security;
alter table expense_splits     enable row level security;
```

### profiles

```sql
-- Oricine autentificat poate vedea profilurile (necesar pentru a afișa numele în UI)
create policy "profiles_select" on profiles
  for select to authenticated using (true);

-- Fiecare user îți poate modifica doar propriul profil
create policy "profiles_update" on profiles
  for update to authenticated using (auth.uid() = id);
```

### groups

```sql
create policy "groups_select" on groups
  for select to authenticated using (is_group_member(id));

create policy "groups_insert" on groups
  for insert to authenticated with check (created_by = auth.uid());

create policy "groups_update" on groups
  for update to authenticated using (
    exists (
      select 1 from group_members
      where group_id = id and user_id = auth.uid() and role = 'admin'
    )
  );
```

### group_members

```sql
create policy "group_members_select" on group_members
  for select to authenticated using (is_group_member(group_id));

-- Inserarea se face exclusiv prin funcția join_group_by_code (security definer)
-- și prin creatorul grupului la creare. Nu permitem INSERT direct.

create policy "group_members_delete" on group_members
  for delete to authenticated using (
    user_id = auth.uid()  -- leave group
    or exists (           -- sau admin-ul poate scoate pe cineva
      select 1 from group_members gm
      where gm.group_id = group_members.group_id
        and gm.user_id  = auth.uid()
        and gm.role     = 'admin'
    )
  );
```

### user_locations

```sql
create policy "locations_select" on user_locations
  for select to authenticated using (is_group_member(group_id));

create policy "locations_upsert" on user_locations
  for insert to authenticated with check (user_id = auth.uid());

create policy "locations_update" on user_locations
  for update to authenticated using (user_id = auth.uid());
```

### points_of_interest

```sql
create policy "poi_select" on points_of_interest
  for select to authenticated using (is_group_member(group_id));

create policy "poi_insert" on points_of_interest
  for insert to authenticated with check (
    is_group_member(group_id) and created_by = auth.uid()
  );

create policy "poi_delete" on points_of_interest
  for delete to authenticated using (
    created_by = auth.uid()
    or exists (
      select 1 from group_members
      where group_id = points_of_interest.group_id
        and user_id  = auth.uid() and role = 'admin'
    )
  );
```

### blog_posts

```sql
create policy "posts_select" on blog_posts
  for select to authenticated using (is_group_member(group_id));

create policy "posts_insert" on blog_posts
  for insert to authenticated with check (
    is_group_member(group_id) and author_id = auth.uid()
  );

create policy "posts_update" on blog_posts
  for update to authenticated using (author_id = auth.uid());

create policy "posts_delete" on blog_posts
  for delete to authenticated using (
    author_id = auth.uid()
    or exists (
      select 1 from group_members
      where group_id = blog_posts.group_id
        and user_id  = auth.uid() and role = 'admin'
    )
  );
```

### blog_post_photos

```sql
create policy "photos_select" on blog_post_photos
  for select to authenticated using (
    exists (
      select 1 from blog_posts bp
      where bp.id = post_id and is_group_member(bp.group_id)
    )
  );

create policy "photos_insert" on blog_post_photos
  for insert to authenticated with check (
    exists (
      select 1 from blog_posts bp
      where bp.id = post_id and bp.author_id = auth.uid()
    )
  );

create policy "photos_delete" on blog_post_photos
  for delete to authenticated using (
    exists (
      select 1 from blog_posts bp
      where bp.id = post_id and bp.author_id = auth.uid()
    )
  );
```

### expenses

```sql
create policy "expenses_select" on expenses
  for select to authenticated using (is_group_member(group_id));

create policy "expenses_insert" on expenses
  for insert to authenticated with check (
    is_group_member(group_id) and paid_by = auth.uid()
  );

create policy "expenses_delete" on expenses
  for delete to authenticated using (
    paid_by = auth.uid()
    or exists (
      select 1 from group_members
      where group_id = expenses.group_id
        and user_id  = auth.uid() and role = 'admin'
    )
  );
```

### expense_splits

```sql
create policy "splits_select" on expense_splits
  for select to authenticated using (
    exists (
      select 1 from expenses e
      where e.id = expense_id and is_group_member(e.group_id)
    )
  );

-- Inserarea spliturilor se face o dată cu cheltuiala, de către cel care plătește
create policy "splits_insert" on expense_splits
  for insert to authenticated with check (
    exists (
      select 1 from expenses e
      where e.id = expense_id and e.paid_by = auth.uid()
    )
  );

-- Fiecare user poate marca ca settled doar propriul split
create policy "splits_update_settled" on expense_splits
  for update to authenticated using (user_id = auth.uid());
```

---

## 5. Realtime

Activează Realtime doar pe tabela care necesită live updates. Restul se fetch-uiesc la nevoie.

**Supabase Dashboard → Database → Replication → 0 tables → adaugă:**

| Tabelă | Motivul |
|--------|---------|
| `user_locations` | Locații live ale membrilor grupului |

```sql
-- Alternativ, din SQL:
alter publication supabase_realtime add table user_locations;
```

---

## 6. Storage Buckets

**Supabase Dashboard → Storage → New bucket:**

| Bucket | Public | Folosit pentru |
|--------|--------|----------------|
| `poi-photos` | ✓ | Fotografii la puncte de interes |
| `blog-photos` | ✓ | Fotografii în postările de blog |
| `receipts` | ✗ | Bonuri fiscale (acces privat) |

---

### Policies pentru `poi-photos` și `blog-photos`

Bucketele sunt **publice** — SELECT nu necesită policy (oricine poate citi).
Adaugi doar 2 policies pentru write, identic pentru ambele bucket-uri.

**Storage → poi-photos → Policies → New policy → Get started quickly →
"Give users access to a folder only to authenticated users"**

Templateul pre-completează câmpurile. Ajustezi manual după cum urmează și dai **Review → Save**.

> ⚠️ Câmpul **Policy definition** primește întotdeauna doar expresia booleană — fără `CREATE POLICY`, fără `USING`, fără paranteze exterioare.

---

**Policy 1 — INSERT**

| Câmp | Valoare |
|------|---------|
| Policy name | `poi_photos_insert` *(pentru blog: `blog_photos_insert`)* |
| Allowed operation | ☑ INSERT |
| Target roles | `authenticated` |
| Policy definition | `bucket_id = 'poi-photos'` *(pentru blog: `bucket_id = 'blog-photos'`)* |

---

**Policy 2 — DELETE**

| Câmp | Valoare |
|------|---------|
| Policy name | `poi_photos_delete` *(pentru blog: `blog_photos_delete`)* |
| Allowed operation | ☑ DELETE |
| Target roles | `authenticated` |
| Policy definition | `bucket_id = 'poi-photos'` *(pentru blog: `bucket_id = 'blog-photos'`)* |

---

### Policies pentru `receipts` (bucket privat)

Bucket privat — SELECT, INSERT și DELETE necesită policy explicită.

**Storage → receipts → Policies → New policy → For full customization**

> **Important:** câmpul **Policy definition** primește doar expresia booleană de mai jos.
> Nu include `create policy`, `using`, sau paranteze exterioare — dashboard-ul le adaugă singur.

---

**Policy 1 — SELECT**

| Câmp | Valoare |
|------|---------|
| Policy name | `receipts_select` |
| Allowed operation | ☑ SELECT |
| Target roles | `authenticated` |
| Policy definition | *(vezi mai jos)* |

```sql
bucket_id = 'receipts'
and exists (
  select 1 from expenses e
  join group_members gm on gm.group_id = e.group_id
  where e.receipt_url like '%' || name || '%'
    and gm.user_id = auth.uid()
)
```

Dai **Review → Save**.

---

**Policy 2 — INSERT**

| Câmp | Valoare |
|------|---------|
| Policy name | `receipts_insert` |
| Allowed operation | ☑ INSERT |
| Target roles | `authenticated` |
| Policy definition | *(vezi mai jos)* |

```sql
bucket_id = 'receipts'
and (storage.foldername(name))[1] = auth.uid()::text
```

Dai **Review → Save**.

---

**Policy 3 — DELETE**

| Câmp | Valoare |
|------|---------|
| Policy name | `receipts_delete` |
| Allowed operation | ☑ DELETE |
| Target roles | `authenticated` |
| Policy definition | *(vezi mai jos)* |

```sql
bucket_id = 'receipts'
and (storage.foldername(name))[1] = auth.uid()::text
```

Dai **Review → Save**.

> Convenție path la upload: `receipts/{user_id}/{expense_id}.jpg`

---

## 7. Pași de configurare (în ordine)

1. **Creare proiect** Supabase — salvează `Project URL` și `anon key`
2. **SQL Editor** — rulează secțiunile 1, 2, 3, 4, 5 în ordine
3. **Replication** — adaugă `user_locations` (secțiunea 5)
4. **Storage** — creează cele 3 bucket-uri (secțiunea 6) + politicile pentru `receipts`
5. **Authentication → Providers** — activează Email (dezactivează "Confirm email" pentru dev)
6. **API Settings** — copiază `URL` și `anon key` pentru Swift SDK

---

## 8. Integrare Swift (preview)

```swift
// Package.swift / SPM — URL de adăugat în Xcode:
// https://github.com/supabase/supabase-swift  (versiune: 2.x)

import Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://xxxx.supabase.co")!,
    supabaseKey: "eyJ..."
)

// UPSERT locație (apelat la fiecare update GPS):
try await supabase
    .from("user_locations")
    .upsert([
        "user_id":   userId,
        "group_id":  groupId,
        "latitude":  coord.latitude,
        "longitude": coord.longitude,
        "battery_level": batteryLevel,
        "is_online": true,
        "updated_at": ISO8601DateFormatter().string(from: Date())
    ])
    .execute()

// Realtime — abonare la locații grup:
let channel = supabase.channel("group-locations")
channel.on(.postgres_changes, table: "user_locations", filter: "group_id=eq.\(groupId)") { payload in
    // actualizează pini pe hartă
}
await channel.subscribe()
```
