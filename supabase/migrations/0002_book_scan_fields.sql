-- BookShare — extend books for the ISBN-scan "add a book" flow.
-- Adds the fields the scanner captures (ISBN, real cover art, description,
-- condition) and threads cover_url through the proximity RPCs so scanned
-- books show their real covers on Discover and the Shelf.

-- Physical condition of a listed copy (mirrors the Swift BookCondition enum).
create type book_condition as enum ('new', 'like_new', 'good', 'fair', 'worn');

alter table public.books
    add column isbn        text,
    add column cover_url   text,             -- remote cover art (Open Library / Google Books)
    add column description text,
    add column condition   book_condition not null default 'good';

-- Recreate the two feed RPCs to also return cover_url. (Return-type columns
-- can't be changed via CREATE OR REPLACE, so drop first.)
drop function if exists public.books_near_me(double precision);
drop function if exists public.books_within_radius(double precision, double precision, double precision);

create function public.books_near_me(radius_m double precision default 3200)
returns table (
    id uuid, title text, author text, genre book_genre, cover_hex text,
    cover_url text, status loan_status, rating numeric,
    owner_name text, owner_verified boolean, distance_mi numeric
)
language sql
security definer set search_path = ''
stable
as $$
    with me as (
        select home_location as g from public.profiles where id = auth.uid()
    )
    select
        b.id, b.title, b.author, b.genre, b.cover_hex, b.cover_url, b.status, b.rating,
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

create function public.books_within_radius(
    lat double precision, lng double precision, radius_m double precision default 3200
)
returns table (
    id uuid, title text, author text, genre book_genre, cover_hex text,
    cover_url text, status loan_status, rating numeric,
    owner_name text, owner_verified boolean, distance_mi numeric
)
language sql
security definer set search_path = ''
stable
as $$
    with origin as (
        select extensions.st_setsrid(extensions.st_makepoint(lng, lat), 4326)::extensions.geography as g
    )
    select
        b.id, b.title, b.author, b.genre, b.cover_hex, b.cover_url, b.status, b.rating,
        p.name as owner_name, p.verified as owner_verified,
        round((extensions.st_distance(p.home_location, o.g) / 1609.344)::numeric, 1) as distance_mi
    from public.books b
    join public.profiles p on p.id = b.owner_id
    cross join origin o
    where p.home_location is not null
      and extensions.st_dwithin(p.home_location, o.g, radius_m)
    order by extensions.st_distance(p.home_location, o.g) asc;
$$;

grant execute on function public.books_near_me(double precision) to authenticated;
grant execute on function public.books_within_radius(double precision, double precision, double precision) to authenticated, anon;
