-- BookShare — Phase A: the loan lifecycle.
-- request -> accept -> arrange handoff (spot + time) -> on loan -> return -> rate.
-- State transitions run through SECURITY DEFINER RPCs that enforce who may act and
-- the valid from-status, so the client can't drive an invalid transition.

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------
create table public.loans (
    id                 uuid primary key default gen_random_uuid(),
    book_id            uuid not null references public.books (id) on delete cascade,
    lender_id          uuid not null references public.profiles (id) on delete cascade,
    borrower_id        uuid not null references public.profiles (id) on delete cascade,
    status             loan_status not null default 'requested',
    requested_at       timestamptz not null default now(),
    responded_at       timestamptz,
    handoff_place      text,
    handoff_time       timestamptz,
    handoff_proposed_by uuid references public.profiles (id),
    handoff_confirmed_at timestamptz,
    due_date           date,
    returned_at        timestamptz,
    created_at         timestamptz not null default now(),
    updated_at         timestamptz not null default now(),
    check (borrower_id <> lender_id)
);

create index loans_borrower_idx on public.loans (borrower_id);
create index loans_lender_idx   on public.loans (lender_id);
create index loans_book_idx     on public.loans (book_id);

-- One active loan per book at a time (blocks double-booking). 'returned' + declined
-- (which we delete) don't count, so a book can loan again after it's back.
create unique index loans_one_active_per_book
    on public.loans (book_id)
    where status in ('requested', 'accepted', 'on_loan');

create table public.ratings (
    id         uuid primary key default gen_random_uuid(),
    loan_id    uuid not null references public.loans (id) on delete cascade,
    rater_id   uuid not null references public.profiles (id) on delete cascade,
    ratee_id   uuid not null references public.profiles (id) on delete cascade,
    stars      int  not null check (stars between 1 and 5),
    comment    text,
    created_at timestamptz not null default now(),
    unique (loan_id, rater_id)   -- one rating per person per loan
);

-- ---------------------------------------------------------------------------
-- Keep books.status in sync with the active loan (single source of truth for
-- availability). on_loan blocks the listing; returning frees it.
-- ---------------------------------------------------------------------------
create or replace function public.sync_book_status()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
    if new.status = 'on_loan' then
        update public.books set status = 'on_loan' where id = new.book_id;
    elsif new.status = 'returned' then
        update public.books set status = 'available' where id = new.book_id;
    end if;
    return new;
end;
$$;

create trigger loans_sync_book_status
    after update of status on public.loans
    for each row execute function public.sync_book_status();

-- ---------------------------------------------------------------------------
-- RPCs — the state machine
-- ---------------------------------------------------------------------------

-- Borrow a book: creates a 'requested' loan. Guards ownership, availability,
-- no existing active loan, and a simple concurrent-borrow cap (BR-06).
create or replace function public.request_loan(p_book_id uuid)
returns uuid
language plpgsql
security definer set search_path = ''
as $$
declare
    v_uid   uuid := auth.uid();
    v_owner uuid;
    v_status public.loan_status;
    v_active int;
    v_loan  uuid;
begin
    if v_uid is null then raise exception 'not authenticated'; end if;

    select owner_id, status into v_owner, v_status from public.books where id = p_book_id;
    if v_owner is null then raise exception 'book not found'; end if;
    if v_owner = v_uid then raise exception 'you own this book'; end if;
    if v_status <> 'available' then raise exception 'book is not available'; end if;

    select count(*) into v_active
    from public.loans
    where borrower_id = v_uid and status in ('requested','accepted','on_loan');
    if v_active >= 3 then raise exception 'borrow limit reached'; end if;

    insert into public.loans (book_id, lender_id, borrower_id, status)
    values (p_book_id, v_owner, v_uid, 'requested')
    returning id into v_loan;
    return v_loan;
end;
$$;

-- Lender accepts or declines a pending request. Declining deletes the loan so the
-- book frees up immediately.
create or replace function public.respond_to_loan(p_loan_id uuid, p_accept boolean)
returns void
language plpgsql
security definer set search_path = ''
as $$
declare v_uid uuid := auth.uid(); v_lender uuid; v_status public.loan_status;
begin
    select lender_id, status into v_lender, v_status from public.loans where id = p_loan_id;
    if v_lender is null then raise exception 'loan not found'; end if;
    if v_lender <> v_uid then raise exception 'only the lender can respond'; end if;
    if v_status <> 'requested' then raise exception 'loan is not pending'; end if;

    if p_accept then
        update public.loans set status = 'accepted', responded_at = now(), updated_at = now()
        where id = p_loan_id;
    else
        delete from public.loans where id = p_loan_id;
    end if;
end;
$$;

-- Either party proposes a handoff spot + time (accepted stage).
create or replace function public.propose_handoff(p_loan_id uuid, p_place text, p_time timestamptz)
returns void
language plpgsql
security definer set search_path = ''
as $$
declare v_uid uuid := auth.uid(); v_l uuid; v_b uuid; v_status public.loan_status;
begin
    select lender_id, borrower_id, status into v_l, v_b, v_status from public.loans where id = p_loan_id;
    if v_l is null then raise exception 'loan not found'; end if;
    if v_uid not in (v_l, v_b) then raise exception 'not your loan'; end if;
    if v_status <> 'accepted' then raise exception 'loan is not in the handoff stage'; end if;

    update public.loans
       set handoff_place = p_place, handoff_time = p_time,
           handoff_proposed_by = v_uid, handoff_confirmed_at = null, updated_at = now()
     where id = p_loan_id;
end;
$$;

-- The OTHER party confirms the proposed handoff -> on loan, 14-day due date.
create or replace function public.confirm_handoff(p_loan_id uuid)
returns void
language plpgsql
security definer set search_path = ''
as $$
declare v_uid uuid := auth.uid(); v_l uuid; v_b uuid; v_status public.loan_status; v_by uuid;
begin
    select lender_id, borrower_id, status, handoff_proposed_by
      into v_l, v_b, v_status, v_by from public.loans where id = p_loan_id;
    if v_l is null then raise exception 'loan not found'; end if;
    if v_uid not in (v_l, v_b) then raise exception 'not your loan'; end if;
    if v_status <> 'accepted' then raise exception 'loan is not in the handoff stage'; end if;
    if v_by is null then raise exception 'no handoff proposed yet'; end if;
    if v_by = v_uid then raise exception 'the other neighbor confirms the handoff'; end if;

    update public.loans
       set status = 'on_loan', handoff_confirmed_at = now(),
           due_date = (now() + interval '14 days')::date, updated_at = now()
     where id = p_loan_id;
end;
$$;

-- Lender confirms the book came back.
create or replace function public.mark_returned(p_loan_id uuid)
returns void
language plpgsql
security definer set search_path = ''
as $$
declare v_uid uuid := auth.uid(); v_l uuid; v_status public.loan_status;
begin
    select lender_id, status into v_l, v_status from public.loans where id = p_loan_id;
    if v_l is null then raise exception 'loan not found'; end if;
    if v_l <> v_uid then raise exception 'only the lender marks a return'; end if;
    if v_status <> 'on_loan' then raise exception 'loan is not on loan'; end if;

    update public.loans set status = 'returned', returned_at = now(), updated_at = now()
    where id = p_loan_id;
end;
$$;

-- Either party rates the other after return; recomputes the ratee's avg rating.
create or replace function public.rate_loan(p_loan_id uuid, p_stars int, p_comment text default null)
returns void
language plpgsql
security definer set search_path = ''
as $$
declare v_uid uuid := auth.uid(); v_l uuid; v_b uuid; v_status public.loan_status; v_ratee uuid;
begin
    if p_stars < 1 or p_stars > 5 then raise exception 'stars must be 1..5'; end if;
    select lender_id, borrower_id, status into v_l, v_b, v_status from public.loans where id = p_loan_id;
    if v_l is null then raise exception 'loan not found'; end if;
    if v_uid not in (v_l, v_b) then raise exception 'not your loan'; end if;
    if v_status <> 'returned' then raise exception 'you can rate after the book is returned'; end if;

    v_ratee := case when v_uid = v_l then v_b else v_l end;
    insert into public.ratings (loan_id, rater_id, ratee_id, stars, comment)
    values (p_loan_id, v_uid, v_ratee, p_stars, p_comment)
    on conflict (loan_id, rater_id) do update set stars = excluded.stars, comment = excluded.comment;

    update public.profiles p
       set rating = round((select avg(stars) from public.ratings where ratee_id = v_ratee)::numeric, 1)
     where p.id = v_ratee;
end;
$$;

-- The caller's loans (as borrower or lender) for the Home queue. Counterparty phone
-- is exposed only once the loan is accepted+ (never pre-accept), per the privacy model.
create or replace function public.my_loans()
returns table (
    id uuid, status loan_status, is_lender boolean,
    book_id uuid, book_title text, book_author text, book_cover_hex text, book_cover_url text,
    counterparty_name text, counterparty_phone text,
    handoff_place text, handoff_time timestamptz, handoff_proposed_by uuid,
    due_date date
)
language sql
security definer set search_path = ''
stable
as $$
    select
        l.id, l.status, (l.lender_id = auth.uid()) as is_lender,
        b.id, b.title, b.author, b.cover_hex, b.cover_url,
        cp.name as counterparty_name,
        case when l.status in ('accepted','on_loan','returned') then cp.phone else null end as counterparty_phone,
        l.handoff_place, l.handoff_time, l.handoff_proposed_by,
        l.due_date
    from public.loans l
    join public.books b on b.id = l.book_id
    join public.profiles cp
      on cp.id = case when l.lender_id = auth.uid() then l.borrower_id else l.lender_id end
    where auth.uid() in (l.lender_id, l.borrower_id)
    order by l.updated_at desc;
$$;

-- ---------------------------------------------------------------------------
-- RLS + grants (writes only via the SECURITY DEFINER RPCs above)
-- ---------------------------------------------------------------------------
alter table public.loans   enable row level security;
alter table public.ratings enable row level security;

create policy "loans: parties read"
    on public.loans for select to authenticated
    using (auth.uid() in (lender_id, borrower_id));

create policy "ratings: parties read"
    on public.ratings for select to authenticated
    using (auth.uid() in (rater_id, ratee_id));

grant select on public.loans, public.ratings to authenticated;
grant execute on function public.request_loan(uuid)              to authenticated;
grant execute on function public.respond_to_loan(uuid, boolean)  to authenticated;
grant execute on function public.propose_handoff(uuid, text, timestamptz) to authenticated;
grant execute on function public.confirm_handoff(uuid)           to authenticated;
grant execute on function public.mark_returned(uuid)             to authenticated;
grant execute on function public.rate_loan(uuid, int, text)      to authenticated;
grant execute on function public.my_loans()                      to authenticated;
