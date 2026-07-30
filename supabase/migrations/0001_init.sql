-- BookShare — Phase 1 schema
-- Auth-linked profiles, book listings, and privacy-preserving proximity search.
--
-- Privacy model (BR-05): a user's exact home coordinates live in profiles.home_location
-- and are NEVER exposed through the API. Neighbors only ever learn a *rounded* distance,
-- returned by the books_within_radius() RPC. RLS makes the raw column unreadable to others.

-- ---------------------------------------------------------------------------
-- Extensions
-- ---------------------------------------------------------------------------
create extension if not exists postgis with schema extensions;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type book_genre  as enum ('fiction', 'nonfiction', 'kids');
-- Global status vocabulary (Deliverable 14 §05). Mirrors the Swift LoanStatus enum.
create type loan_status as enum ('available', 'requested', 'accepted', 'on_loan', 'returned');

-- ---------------------------------------------------------------------------
-- profiles — one row per auth user
-- ---------------------------------------------------------------------------
create table public.profiles (
    id            uuid primary key references auth.users (id) on delete cascade,
    name          text        not null default '',
    phone         text,
    neighborhood  text,
    -- Exact home point. Protected: never selected by any client-facing query.
    home_location geography(Point, 4326),
    verified      boolean     not null default false,
    rating        numeric(2,1) not null default 5.0,
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now()
);

comment on column public.profiles.home_location is
    'Exact coordinates. Never exposed via API — proximity is served as rounded distance by books_within_radius().';

-- Spatial index for fast ST_DWithin radius filtering.
create index profiles_home_location_gix on public.profiles using gist (home_location);

-- ---------------------------------------------------------------------------
-- books — listings owned by a profile
-- ---------------------------------------------------------------------------
create table public.books (
    id          uuid primary key default gen_random_uuid(),
    owner_id    uuid        not null references public.profiles (id) on delete cascade,
    title       text        not null,
    author      text        not null,
    genre       book_genre  not null default 'fiction',
    cover_hex   text        not null default '8E6F4E',  -- stand-in for Open Library cover art
    status      loan_status not null default 'available',
    rating      numeric(2,1) not null default 5.0,
    created_at  timestamptz not null default now()
);

create index books_owner_id_idx on public.books (owner_id);
create index books_status_idx   on public.books (status);

-- ---------------------------------------------------------------------------
-- New-user trigger: create a profile row when an auth user is created.
-- Pulls name/phone from the signup metadata when present.
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
    insert into public.profiles (id, name, phone)
    values (
        new.id,
        coalesce(new.raw_user_meta_data ->> 'name', ''),
        new.phone
    );
    return new;
end;
$$;

create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- RPC: update the caller's own home location (raw coords in, nothing out).
-- ---------------------------------------------------------------------------
create or replace function public.update_my_location(lat double precision, lng double precision)
returns void
language plpgsql
security definer set search_path = ''
as $$
begin
    if auth.uid() is null then
        raise exception 'not authenticated';
    end if;
    update public.profiles
       set home_location = extensions.st_setsrid(extensions.st_makepoint(lng, lat), 4326)::extensions.geography,
           updated_at    = now()
     where id = auth.uid();
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: books within radius of a point, with ROUNDED distance only.
-- Joins each book to its owner's home_location, filters by ST_DWithin, and
-- returns a distance bucketed to 0.1 mi so raw coordinates can't be triangulated.
-- ---------------------------------------------------------------------------
create or replace function public.books_within_radius(
    lat        double precision,
    lng        double precision,
    radius_m   double precision default 3200  -- ~2 miles
)
returns table (
    id             uuid,
    title          text,
    author         text,
    genre          book_genre,
    cover_hex      text,
    status         loan_status,
    rating         numeric,
    owner_name     text,
    owner_verified boolean,
    distance_mi    numeric   -- rounded to 0.1 mi; never raw
)
language sql
security definer set search_path = ''
stable
as $$
    with origin as (
        select extensions.st_setsrid(extensions.st_makepoint(lng, lat), 4326)::extensions.geography as g
    )
    select
        b.id, b.title, b.author, b.genre, b.cover_hex, b.status, b.rating,
        p.name     as owner_name,
        p.verified as owner_verified,
        round((extensions.st_distance(p.home_location, o.g) / 1609.344)::numeric, 1) as distance_mi
    from public.books b
    join public.profiles p on p.id = b.owner_id
    cross join origin o
    where p.home_location is not null
      and extensions.st_dwithin(p.home_location, o.g, radius_m)
    order by extensions.st_distance(p.home_location, o.g) asc;
$$;

-- ---------------------------------------------------------------------------
-- RPC: the Discover feed. Same as books_within_radius but centered on the
-- CALLER's own saved home_location, and excluding the caller's own books
-- (those live on their Shelf). No coordinates cross the wire.
-- ---------------------------------------------------------------------------
create or replace function public.books_near_me(radius_m double precision default 3200)
returns table (
    id             uuid,
    title          text,
    author         text,
    genre          book_genre,
    cover_hex      text,
    status         loan_status,
    rating         numeric,
    owner_name     text,
    owner_verified boolean,
    distance_mi    numeric
)
language sql
security definer set search_path = ''
stable
as $$
    with me as (
        select home_location as g from public.profiles where id = auth.uid()
    )
    select
        b.id, b.title, b.author, b.genre, b.cover_hex, b.status, b.rating,
        p.name as owner_name, p.verified as owner_verified,
        round((extensions.st_distance(p.home_location, me.g) / 1609.344)::numeric, 1) as distance_mi
    from public.books b
    join public.profiles p on p.id = b.owner_id
    cross join me
    where me.g is not null
      and p.home_location is not null
      and b.owner_id <> auth.uid()
      and extensions.st_dwithin(p.home_location, me.g, radius_m)
    order by extensions.st_distance(p.home_location, me.g) asc;
$$;

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.books    enable row level security;

-- profiles: a user may read and update only their own row. No cross-user SELECT,
-- so home_location can never be read by another client. (Display name/verified for
-- other users reaches the UI only via the RPC's returned columns above.)
create policy "profiles: self read"
    on public.profiles for select
    using (auth.uid() = id);

create policy "profiles: self update"
    on public.profiles for update
    using (auth.uid() = id)
    with check (auth.uid() = id);

-- books: any authenticated user may browse listings; owners manage their own.
create policy "books: authenticated read"
    on public.books for select
    to authenticated
    using (true);

create policy "books: owner insert"
    on public.books for insert
    to authenticated
    with check (auth.uid() = owner_id);

create policy "books: owner update"
    on public.books for update
    to authenticated
    using (auth.uid() = owner_id)
    with check (auth.uid() = owner_id);

create policy "books: owner delete"
    on public.books for delete
    to authenticated
    using (auth.uid() = owner_id);

-- Table-level privileges. Newer Supabase does NOT auto-grant these to the app
-- roles, so they're explicit here. RLS policies above still gate which *rows*
-- each role sees; these grants gate which *tables/operations* are reachable.
grant usage on schema public to anon, authenticated;
-- profiles: the app reads/updates the caller's own row (rows limited by RLS).
-- INSERT happens only via the SECURITY DEFINER new-user trigger, so no insert grant.
grant select, update on public.profiles to authenticated;
-- books: browse + manage own listings (rows limited by RLS).
grant select, insert, update, delete on public.books to authenticated;

-- The RPCs run as SECURITY DEFINER; grant execute to the app roles.
grant execute on function public.update_my_location(double precision, double precision) to authenticated;
grant execute on function public.books_within_radius(double precision, double precision, double precision) to authenticated, anon;
grant execute on function public.books_near_me(double precision) to authenticated;
