-- Primeiro corte: presença gratuita, associações por patota e fila FIFO.
-- Não aplicar manualmente em produção sem homologação e testes de concorrência.
create schema if not exists private;
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 2 and 60),
  created_at timestamptz not null default now()
);

create table public.patotas (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 3 and 80),
  modality text not null check (modality in ('futsal', 'society', 'campo')),
  timezone text not null,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

create table public.patota_members (
  patota_id uuid not null references public.patotas(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'player' check (role in ('admin', 'player')),
  status text not null default 'active' check (status in ('active', 'inactive')),
  joined_at timestamptz not null default now(),
  primary key (patota_id, user_id)
);
create index patota_members_user on public.patota_members(user_id, status);

create table public.players (
  id uuid primary key default gen_random_uuid(),
  patota_id uuid not null references public.patotas(id) on delete cascade,
  user_id uuid,
  display_name text not null check (char_length(display_name) between 2 and 60),
  active boolean not null default true,
  foreign key (patota_id, user_id) references public.patota_members(patota_id, user_id),
  unique (patota_id, user_id),
  unique (id, patota_id)
);

create table public.matches (
  id uuid primary key default gen_random_uuid(),
  patota_id uuid not null references public.patotas(id) on delete cascade,
  starts_at timestamptz not null,
  timezone text not null,
  venue text not null check (char_length(btrim(venue)) between 3 and 120),
  capacity integer not null check (capacity between 2 and 100),
  status text not null default 'scheduled'
    check (status in ('scheduled', 'in_progress', 'finished', 'cancelled')),
  attendance_opens_at timestamptz not null default now(),
  attendance_closes_at timestamptz not null,
  rules_snapshot jsonb not null,
  next_queue_sequence bigint not null default 0,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  check (attendance_opens_at <= attendance_closes_at),
  check (attendance_closes_at <= starts_at),
  unique (id, patota_id)
);
create index matches_patota_date on public.matches(patota_id, starts_at);

create table public.match_attendances (
  match_id uuid not null,
  player_id uuid not null,
  patota_id uuid not null,
  status text not null default 'invited' check (status in (
    'invited', 'confirmed', 'declined', 'waitlisted', 'cancelled', 'attended', 'no_show')),
  responded_at timestamptz,
  source text not null default 'app' check (source in ('app', 'admin')),
  queue_sequence bigint,
  queue_position integer,
  version integer not null default 0,
  primary key (match_id, player_id),
  foreign key (match_id, patota_id) references public.matches(id, patota_id) on delete cascade,
  foreign key (player_id, patota_id) references public.players(id, patota_id),
  check ((status = 'waitlisted') = (queue_sequence is not null)),
  check ((status = 'waitlisted') = (queue_position is not null)),
  check (queue_position is null or queue_position > 0)
);
create index attendance_fifo on public.match_attendances(match_id, queue_sequence)
  where status = 'waitlisted';

create table public.audit_log (
  id bigint generated always as identity primary key,
  patota_id uuid not null references public.patotas(id) on delete cascade,
  actor_id uuid not null references public.profiles(id),
  event text not null,
  resource_id uuid not null,
  details jsonb not null default '{}',
  created_at timestamptz not null default now()
);
create index audit_log_patota_date on public.audit_log(patota_id, created_at);

-- Códigos ficam fora da Data API. Somente o RPC autorizado os lê.
create table private.patota_invitations (
  patota_id uuid primary key references public.patotas(id) on delete cascade,
  code text not null unique check (code ~ '^[A-HJ-NP-Z2-9]{8}$'),
  rotated_at timestamptz not null default now()
);
create table private.join_throttles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  window_started_at timestamptz not null,
  attempts integer not null
);
create table private.attendance_commands (
  actor_id uuid not null references auth.users(id) on delete cascade,
  request_id uuid not null,
  match_id uuid not null references public.matches(id) on delete cascade,
  going boolean not null,
  result jsonb not null,
  created_at timestamptz not null default now(),
  primary key (actor_id, request_id)
);

create function private.is_member(p_patota_id uuid, p_admin boolean default false)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.patota_members
    where patota_id = p_patota_id and user_id = (select auth.uid())
      and status = 'active' and (not p_admin or role = 'admin'));
$$;
revoke all on function private.is_member(uuid, boolean) from public, anon;
grant execute on function private.is_member(uuid, boolean) to authenticated;

alter table public.profiles enable row level security;
alter table public.patotas enable row level security;
alter table public.patota_members enable row level security;
alter table public.players enable row level security;
alter table public.matches enable row level security;
alter table public.match_attendances enable row level security;
alter table public.audit_log enable row level security;
alter table private.patota_invitations enable row level security;
alter table private.join_throttles enable row level security;
alter table private.attendance_commands enable row level security;

create policy profile_read_self on public.profiles for select to authenticated
  using (id = (select auth.uid()));
create policy profile_update_self on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy patota_read_member on public.patotas for select to authenticated
  using (private.is_member(id));
create policy members_read_patota on public.patota_members for select to authenticated
  using (private.is_member(patota_id));
create policy players_read_member on public.players for select to authenticated
  using (private.is_member(patota_id));
create policy matches_read_member on public.matches for select to authenticated
  using (private.is_member(patota_id));
create policy attendance_read_member on public.match_attendances for select to authenticated
  using (private.is_member(patota_id));
create policy audit_read_admin on public.audit_log for select to authenticated
  using (private.is_member(patota_id, true));

-- Não há escrita direta em tabelas críticas; todos os comandos usam RPC.
revoke all on public.profiles, public.patotas, public.patota_members,
  public.players, public.matches, public.match_attendances, public.audit_log
  from public, anon, authenticated;
grant select on public.profiles, public.patotas, public.patota_members,
  public.players, public.matches, public.match_attendances, public.audit_log to authenticated;
grant update(display_name) on public.profiles to authenticated;
revoke all on all tables in schema private from public, anon, authenticated;

create function private.on_user_created() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_name text;
begin
  v_name := btrim(coalesce(new.raw_user_meta_data ->> 'display_name', 'Jogador'));
  if char_length(v_name) < 2 then v_name := 'Jogador'; end if;
  insert into public.profiles(id, display_name) values (new.id, left(v_name, 60));
  return new;
end;
$$;
revoke all on function private.on_user_created() from public, anon, authenticated;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function private.on_user_created();

-- Instalação em projeto com contas existentes preserva perfis já criados.
insert into public.profiles(id, display_name)
select id, case when char_length(btrim(coalesce(raw_user_meta_data ->> 'display_name', ''))) >= 2
  then left(btrim(raw_user_meta_data ->> 'display_name'), 60) else 'Jogador' end
from auth.users on conflict (id) do nothing;

create function private.random_join_code() returns text
language plpgsql volatile set search_path = '' as $$
declare v_bytes bytea := extensions.gen_random_bytes(8);
  v_alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_code text := '';
begin
  for i in 0..7 loop
    v_code := v_code || substr(v_alphabet, (get_byte(v_bytes, i) % 32) + 1, 1);
  end loop;
  return v_code;
end;
$$;
revoke all on function private.random_join_code() from public, anon, authenticated;

create function public.create_patota(p_name text, p_modality text, p_timezone text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_user uuid := auth.uid(); v_id uuid; v_name text;
begin
  if v_user is null then raise exception 'not_authorized' using errcode = '42501'; end if;
  if p_name is null or char_length(btrim(p_name)) not between 3 and 80
    or p_modality is null or p_modality not in ('futsal', 'society', 'campo')
    or p_timezone is null or not exists (select 1 from pg_catalog.pg_timezone_names where name = p_timezone)
    then raise exception 'invalid_input' using errcode = '22023'; end if;
  select display_name into strict v_name from public.profiles where id = v_user;
  insert into public.patotas(name, modality, timezone, created_by)
    values (btrim(p_name), p_modality, p_timezone, v_user) returning id into v_id;
  insert into public.patota_members(patota_id, user_id, role) values (v_id, v_user, 'admin');
  insert into public.players(patota_id, user_id, display_name) values (v_id, v_user, v_name);
  loop
    begin
      insert into private.patota_invitations(patota_id, code) values (v_id, private.random_join_code());
      exit;
    exception when unique_violation then null;
    end;
  end loop;
  insert into public.audit_log(patota_id, actor_id, event, resource_id)
    values (v_id, v_user, 'PatotaCreated', v_id);
  return v_id;
end;
$$;

create function public.join_patota_by_code(p_code text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_user uuid := auth.uid(); v_id uuid; v_attempts integer;
  v_name text; v_added integer;
begin
  if v_user is null then raise exception 'not_authorized' using errcode = '42501'; end if;
  -- Retornar NULL em tentativas inválidas mantém o contador na transação.
  -- Lançar uma exceção aqui faria rollback do rate limit.
  insert into private.join_throttles(user_id, window_started_at, attempts)
    values (v_user, now(), 1)
    on conflict (user_id) do update set
      attempts = case when private.join_throttles.window_started_at <= now() - interval '15 minutes'
        then 1 else least(private.join_throttles.attempts + 1, 1000000) end,
      window_started_at = case when private.join_throttles.window_started_at <= now() - interval '15 minutes'
        then now() else private.join_throttles.window_started_at end
    returning attempts into v_attempts;
  if v_attempts > 10 then return null; end if;
  select patota_id into v_id from private.patota_invitations where code = upper(btrim(p_code));
  if v_id is null then return null; end if;
  -- Bloqueia rotação do código e serializa entrada na patota.
  perform 1 from private.patota_invitations
    where patota_id = v_id and code = upper(btrim(p_code)) for update;
  if not found then return null; end if;
  if exists (select 1 from public.patota_members
    where patota_id = v_id and user_id = v_user and status = 'inactive') then return null; end if;
  select display_name into strict v_name from public.profiles where id = v_user;
  insert into public.patota_members(patota_id, user_id) values (v_id, v_user)
    on conflict (patota_id, user_id) do nothing;
  get diagnostics v_added = row_count;
  insert into public.players(patota_id, user_id, display_name) values (v_id, v_user, v_name)
    on conflict (patota_id, user_id) do nothing;
  if v_added > 0 then
    insert into public.audit_log(patota_id, actor_id, event, resource_id)
      values (v_id, v_user, 'PlayerJoined', v_user);
  end if;
  return v_id;
end;
$$;

create function public.patota_invitation_code(p_patota_id uuid, p_regenerate boolean default false)
returns text language plpgsql security definer set search_path = '' as $$
declare v_code text;
begin
  if not private.is_member(p_patota_id, true) then
    raise exception 'not_authorized' using errcode = '42501'; end if;
  select code into strict v_code from private.patota_invitations where patota_id = p_patota_id for update;
  if p_regenerate then
    loop
      begin
        update private.patota_invitations set code = private.random_join_code(), rotated_at = now()
          where patota_id = p_patota_id returning code into v_code;
        exit;
      exception when unique_violation then null;
      end;
    end loop;
    insert into public.audit_log(patota_id, actor_id, event, resource_id)
      values (p_patota_id, auth.uid(), 'PatotaJoinCodeRegenerated', p_patota_id);
  end if;
  return v_code;
end;
$$;

create function public.schedule_match(p_patota_id uuid, p_starts_at timestamptz,
  p_venue text, p_capacity integer) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_patota public.patotas%rowtype; v_id uuid;
begin
  if not private.is_member(p_patota_id, true) then
    raise exception 'not_authorized' using errcode = '42501'; end if;
  if p_starts_at is null or p_starts_at <= now() or p_capacity is null
    or p_capacity not between 2 and 100 or p_venue is null
    or char_length(btrim(p_venue)) not between 3 and 120
    then raise exception 'invalid_input' using errcode = '22023'; end if;
  select * into strict v_patota from public.patotas where id = p_patota_id;
  insert into public.matches(patota_id, starts_at, timezone, venue, capacity,
    attendance_closes_at, rules_snapshot, created_by)
    values (p_patota_id, p_starts_at, v_patota.timezone, btrim(p_venue), p_capacity,
      p_starts_at, jsonb_build_object('version', 1, 'modality', v_patota.modality,
        'queue_policy', 'fifo', 'promotion', 'automatic'), auth.uid()) returning id into v_id;
  insert into public.match_attendances(match_id, player_id, patota_id)
    select v_id, p.id, p_patota_id from public.players p
      join public.patota_members m on m.patota_id = p.patota_id and m.user_id = p.user_id
      where p.patota_id = p_patota_id and p.active and m.status = 'active';
  insert into public.audit_log(patota_id, actor_id, event, resource_id)
    values (p_patota_id, auth.uid(), 'MatchScheduled', v_id);
  return v_id;
end;
$$;

create function public.respond_to_match(p_match_id uuid, p_going boolean, p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_match public.matches%rowtype; v_player uuid; v_previous text;
  v_status text; v_count integer; v_sequence bigint; v_promoted uuid; v_position integer;
  v_command private.attendance_commands%rowtype; v_result jsonb;
begin
  if auth.uid() is null then raise exception 'not_authorized' using errcode = '42501'; end if;
  -- Toda aquisição/liberação de vaga usa o mesmo lock da rodada.
  select * into v_match from public.matches where id = p_match_id for update;
  if not found or not private.is_member(v_match.patota_id) then
    raise exception 'not_authorized' using errcode = '42501'; end if;
  if p_going is null or p_request_id is null then raise exception 'invalid_input' using errcode = '22023'; end if;
  select * into v_command from private.attendance_commands
    where actor_id = auth.uid() and request_id = p_request_id;
  if found then
    if v_command.match_id <> p_match_id or v_command.going <> p_going then
      raise exception 'invalid_input' using errcode = '22023'; end if;
    return v_command.result;
  end if;
  if v_match.status <> 'scheduled' or clock_timestamp() < v_match.attendance_opens_at
    or clock_timestamp() >= v_match.attendance_closes_at then
    raise exception 'match_closed' using errcode = '22023'; end if;
  select id into v_player from public.players where patota_id = v_match.patota_id
    and user_id = auth.uid() and active;
  if v_player is null then raise exception 'not_authorized' using errcode = '42501'; end if;
  select status, queue_position into v_previous, v_position from public.match_attendances
    where match_id = p_match_id and player_id = v_player;
  -- Mesma intenção repetida não altera ordem, versão, timestamps ou auditoria.
  if (p_going and v_previous in ('confirmed', 'waitlisted'))
    or (not p_going and v_previous = 'declined') then
    v_result := jsonb_build_object('status', v_previous, 'queue_position', v_position);
    insert into private.attendance_commands(actor_id, request_id, match_id, going, result)
      values (auth.uid(), p_request_id, p_match_id, p_going, v_result);
    return v_result;
  end if;
  if not p_going then
    v_status := 'declined';
  else
    select count(*) into v_count from public.match_attendances
      where match_id = p_match_id and status = 'confirmed';
    if v_count < v_match.capacity and not exists (select 1 from public.match_attendances
      where match_id = p_match_id and status = 'waitlisted') then
      v_status := 'confirmed';
    else
      v_status := 'waitlisted';
      update public.matches set next_queue_sequence = next_queue_sequence + 1
        where id = p_match_id returning next_queue_sequence into v_sequence;
    end if;
  end if;
  insert into public.match_attendances(match_id, player_id, patota_id, status,
    responded_at, queue_sequence, queue_position, version)
    values (p_match_id, v_player, v_match.patota_id, v_status, now(), v_sequence,
      case when v_status = 'waitlisted' then 1 end, 1)
    on conflict (match_id, player_id) do update set status = excluded.status,
      responded_at = now(), queue_sequence = excluded.queue_sequence,
      queue_position = excluded.queue_position, version = public.match_attendances.version + 1;
  insert into public.audit_log(patota_id, actor_id, event, resource_id, details)
    values (v_match.patota_id, auth.uid(), 'AttendanceChanged', p_match_id,
      jsonb_build_object('player_id', v_player, 'previous', v_previous, 'status', v_status));
  if v_previous = 'confirmed' and not p_going then
    select player_id into v_promoted from public.match_attendances
      where match_id = p_match_id and status = 'waitlisted' order by queue_sequence limit 1;
    if v_promoted is not null then
      update public.match_attendances set status = 'confirmed', queue_sequence = null,
        queue_position = null, version = version + 1
        where match_id = p_match_id and player_id = v_promoted;
      insert into public.audit_log(patota_id, actor_id, event, resource_id, details)
        values (v_match.patota_id, auth.uid(), 'WaitlistPromoted', p_match_id,
          jsonb_build_object('player_id', v_promoted));
    end if;
  end if;
  with positions as (select player_id, row_number() over (order by queue_sequence)::integer as position
    from public.match_attendances where match_id = p_match_id and status = 'waitlisted')
  update public.match_attendances a set queue_position = positions.position
    from positions where a.match_id = p_match_id and a.player_id = positions.player_id;
  select queue_position into v_position from public.match_attendances
    where match_id = p_match_id and player_id = v_player;
  v_result := jsonb_build_object('status', v_status, 'queue_position', v_position);
  insert into private.attendance_commands(actor_id, request_id, match_id, going, result)
    values (auth.uid(), p_request_id, p_match_id, p_going, v_result);
  return v_result;
end;
$$;

revoke all on function public.create_patota(text, text, text),
  public.join_patota_by_code(text), public.patota_invitation_code(uuid, boolean),
  public.schedule_match(uuid, timestamptz, text, integer), public.respond_to_match(uuid, boolean, uuid)
  from public, anon;
grant execute on function public.create_patota(text, text, text),
  public.join_patota_by_code(text), public.patota_invitation_code(uuid, boolean),
  public.schedule_match(uuid, timestamptz, text, integer), public.respond_to_match(uuid, boolean, uuid)
  to authenticated;
