-- BookShare — local seed data
-- Neighbors + books placed at known distances around a Cobble Hill test origin
-- (40.6862, -73.9959) so books_within_radius() returns a realistic feed.
--
-- One neighbor (Far F.) sits ~2.5 mi out to prove the 2-mi radius filter excludes them.
-- Distances are set by offsetting latitude north by d/69 degrees (~69 mi per degree lat).

-- Helper: create an auth user + let the on_auth_user_created trigger make the profile,
-- then position/decorate the profile and add their book.
do $$
declare
    origin_lat constant double precision := 40.6862;
    origin_lng constant double precision := -73.9959;

    r record;
    uid uuid;
begin
    for r in
        select * from (values
            -- name,      neighborhood,      dist_mi, verified, rating, title,                          author,          genre,        cover,   status
            ('Alma R.',   'Cobble Hill',     0.3, true,  5.0, 'Book of Ordinary Anguish',     'M. Delacroix',  'fiction',    '6B4A3A', 'available'),
            ('Dev P.',    'Cobble Hill',     0.4, true,  4.8, 'The Gruffalo',                 'J. Donaldson',  'kids',       '7C5A9B', 'available'),
            ('Marcus T.', 'Boerum Hill',     0.5, true,  4.7, 'Tiny Habits',                  'BJ Fogg',       'nonfiction', '9A7B3F', 'on_loan'),
            ('Sofia L.',  'Carroll Gardens', 0.7, true,  4.9, 'Where the Crawdads Sing',      'D. Owens',      'fiction',    '3E5266', 'available'),
            ('Omar F.',   'Carroll Gardens', 0.8, false, 4.5, 'The Very Hungry Caterpillar',  'E. Carle',      'kids',       'B4632A', 'available'),
            ('Jin W.',    'Boerum Hill',     0.9, true,  4.8, 'Quiet Machines',               'H. Roper',      'fiction',    '8E6F4E', 'available'),
            ('Priya K.',  'Gowanus',         1.2, false, 4.6, 'The Salt Path',                'R. Winn',       'nonfiction', '4F6353', 'available'),
            ('Nadia H.',  'Park Slope',      1.6, true,  5.0, 'Braiding Sweetgrass',          'R. Kimmerer',   'nonfiction', '556B3F', 'available'),
            ('Far F.',    'Bushwick',        2.5, true,  4.4, 'Out of Range',                 'N. Obar',       'fiction',    '333333', 'available')
        ) as t(name, neighborhood, dist_mi, verified, rating, title, author, genre, cover, status)
    loop
        uid := gen_random_uuid();

        insert into auth.users (
            instance_id, id, aud, role, email,
            encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data,
            created_at, updated_at
        ) values (
            '00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated',
            lower(replace(r.name, ' ', '')) || '@seed.bookshare.test',
            extensions.crypt('seed-not-a-real-login', extensions.gen_salt('bf')),
            now(),
            '{"provider":"email","providers":["email"]}',
            jsonb_build_object('name', r.name),
            now(), now()
        );

        -- Trigger already inserted the profile; position + decorate it.
        update public.profiles
           set neighborhood  = r.neighborhood,
               verified      = r.verified,
               rating        = r.rating,
               home_location = extensions.st_setsrid(
                                   extensions.st_makepoint(origin_lng, origin_lat + (r.dist_mi / 69.0)),
                                   4326)::extensions.geography
         where id = uid;

        insert into public.books (owner_id, title, author, genre, cover_hex, status, rating)
        values (uid, r.title, r.author, r.genre::book_genre, r.cover, r.status::loan_status, r.rating);
    end loop;
end $$;
