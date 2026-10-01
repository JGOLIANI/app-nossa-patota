// PostgreSQL real, isolado e descartável. Auth.uid/roles simulam somente o contrato
// SQL do Supabase; estes testes não validam login, Data API ou delivery de e-mail.
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { createRequire } from 'node:module';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

const tools = process.env.PATOTA_PG_TOOLS ?? '/workspace/tools/postgres';
const require = createRequire(join(tools, 'package.json'));
const { Client } = require('pg');
const native = join(tools, 'node_modules/@embedded-postgres/linux-x64/native');
const cluster = mkdtempSync(join(tmpdir(), 'patota-postgres-'));
const data = join(cluster, 'data');
const port = 23000 + Math.floor(Math.random() * 15000);
const config = { host: cluster, port, user: 'patota_test', database: 'postgres' };
let started = false;
let admin;
const userId = (i) => `00000000-0000-4000-8000-${String(i).padStart(12, '0')}`;

async function asUser(i, action) {
  const client = new Client(config);
  await client.connect();
  try {
    await client.query('begin');
    await client.query('set local role authenticated');
    await client.query("select set_config('request.jwt.claim.sub', $1, true)", [userId(i)]);
    const result = await action(client);
    await client.query('commit');
    return result;
  } catch (error) {
    await client.query('rollback');
    throw error;
  } finally { await client.end(); }
}
async function rpc(i, name, params) {
  if (name === 'respond_to_match' && params.length === 2) params = [...params, randomUUID()];
  return asUser(i, async (c) => (await c.query(
    `select public.${name}(${params.map((_, j) => `$${j + 1}`).join(', ')}) as result`, params)).rows[0].result);
}
async function mustReject(action, message) {
  await assert.rejects(action, (error) => error.message === message);
}
async function counts(matchId) {
  return (await admin.query(`select
    count(*) filter (where status = 'confirmed')::int as confirmed,
    count(*) filter (where status = 'waitlisted')::int as waiting
    from public.match_attendances where match_id = $1`, [matchId])).rows[0];
}
try {
  execFileSync(join(native, 'bin/initdb'), ['-D', data, '-U', 'patota_test',
    '--auth=trust', '--locale=C', '--encoding=UTF8'], { stdio: 'pipe' });
  execFileSync(join(native, 'bin/pg_ctl'), ['-D', data, '-l', join(cluster, 'server.log'),
    '-o', `-F -h 127.0.0.1 -p ${port} -k ${cluster}`, '-w', 'start'], { stdio: 'pipe' });
  started = true;
  admin = new Client(config);
  await admin.connect();
  await admin.query(`
    create role anon nologin;
    create role authenticated nologin;
    create schema auth;
    create table auth.users (id uuid primary key, raw_user_meta_data jsonb default '{}');
    create function auth.uid() returns uuid language sql stable as $$
      select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
    $$;
    grant usage on schema auth, public to authenticated, anon;
    grant execute on function auth.uid() to authenticated, anon;
  `);
  await admin.query(readFileSync(new URL('../migrations/202610010001_foundation.sql', import.meta.url), 'utf8'));
  for (let i = 1; i <= 25; i++) {
    await admin.query('insert into auth.users(id, raw_user_meta_data) values ($1, $2)',
      [userId(i), JSON.stringify({ display_name: `Jogador ${i}`, role: 'admin' })]);
  }
  const patota = await rpc(1, 'create_patota', ['Resenha de teste', 'society', 'America/Sao_Paulo']);
  const code = await rpc(1, 'patota_invitation_code', [patota, false]);
  assert.match(code, /^[A-HJ-NP-Z2-9]{8}$/);
  assert.equal((await asUser(2, (c) => c.query('select * from public.patotas'))).rowCount, 0);
  await assert.rejects(asUser(1, (c) => c.query("update public.patota_members set role = 'admin'")),
    (error) => error.code === '42501');
  await mustReject(() => rpc(2, 'schedule_match', [patota, '2099-01-01T20:00:00Z', 'Quadra teste', 2]), 'not_authorized');
  await rpc(2, 'join_patota_by_code', [code.toLowerCase()]);
  await rpc(2, 'join_patota_by_code', [code]);
  await rpc(3, 'join_patota_by_code', [code]);
  assert.equal((await admin.query("select count(*)::int as n from public.audit_log where event = 'PlayerJoined'")).rows[0].n, 2);
  await mustReject(() => rpc(2, 'patota_invitation_code', [patota, false]), 'not_authorized');
  const future = new Date(Date.now() + 86400000).toISOString();
  const match = await rpc(1, 'schedule_match', [patota, future, 'Quadra teste', 2]);
  await rpc(1, 'respond_to_match', [match, true]);
  const confirmationId = randomUUID();
  await rpc(2, 'respond_to_match', [match, true, confirmationId]);
  assert.equal((await rpc(3, 'respond_to_match', [match, true])).status, 'waitlisted');
  const before = (await admin.query(`select a.version, a.responded_at, a.queue_sequence
    from public.match_attendances a join public.players p on p.id = a.player_id
    where a.match_id = $1 and p.user_id = $2`, [match, userId(3)])).rows[0];
  await rpc(3, 'respond_to_match', [match, true]);
  const after = (await admin.query(`select a.version, a.responded_at, a.queue_sequence
    from public.match_attendances a join public.players p on p.id = a.player_id
    where a.match_id = $1 and p.user_id = $2`, [match, userId(3)])).rows[0];
  assert.deepEqual(after, before);
  await rpc(2, 'respond_to_match', [match, false]);
  await rpc(2, 'respond_to_match', [match, true, confirmationId]);
  assert.deepEqual(await counts(match), { confirmed: 2, waiting: 0 });
  assert.equal((await rpc(3, 'respond_to_match', [match, true])).status, 'confirmed');
  await admin.query("update public.matches set status = 'cancelled' where id = $1", [match]);
  await mustReject(() => rpc(3, 'respond_to_match', [match, false]), 'match_closed');
  console.log('PASS: RLS, papéis, replay após desistência, FIFO e rodada cancelada');

  for (let i = 0; i < 11; i++) assert.equal(await rpc(4, 'join_patota_by_code', ['XXXXXXXX']), null);
  assert.equal(await rpc(4, 'join_patota_by_code', [code]), null);
  const rotated = await rpc(1, 'patota_invitation_code', [patota, true]);
  assert.notEqual(rotated, code);
  assert.equal(await rpc(5, 'join_patota_by_code', [code]), null);
  assert.equal(await rpc(5, 'join_patota_by_code', [rotated]), patota);
  assert.equal((await asUser(5, (c) => c.query('select role from public.patota_members where user_id = $1', [userId(5)]))).rows[0].role, 'player');
  console.log('PASS: código normalizado/revogado, limite persistente e metadados sem privilégio');

  for (let i = 6; i <= 25; i++) await rpc(i, 'join_patota_by_code', [rotated]);
  const concurrent = await rpc(1, 'schedule_match', [patota, future, 'Concorrência', 2]);
  await Promise.all(Array.from({ length: 20 }, (_, i) => rpc(i + 6, 'respond_to_match', [concurrent, true])));
  assert.deepEqual(await counts(concurrent), { confirmed: 2, waiting: 18 });
  const waiting = (await admin.query(`select player_id, queue_position from public.match_attendances
    where match_id = $1 and status = 'waitlisted' order by queue_sequence`, [concurrent])).rows;
  assert.deepEqual(waiting.map((r) => r.queue_position), Array.from({ length: 18 }, (_, i) => i + 1));
  const confirmed = (await admin.query(`select p.user_id from public.match_attendances a
    join public.players p on p.id = a.player_id where a.match_id = $1 and a.status = 'confirmed'`, [concurrent])).rows;
  await Promise.all(confirmed.map((r) => rpc(Number(r.user_id.slice(-12)), 'respond_to_match', [concurrent, false])));
  assert.deepEqual(await counts(concurrent), { confirmed: 2, waiting: 16 });
  const promoted = (await admin.query(`select player_id from public.match_attendances
    where match_id = $1 and status = 'confirmed'`, [concurrent])).rows.map((r) => r.player_id).sort();
  assert.deepEqual(promoted, waiting.slice(0, 2).map((r) => r.player_id).sort());
  console.log('PASS: 20 confirmações concorrentes para 2 vagas; duas desistências promovem o FIFO correto');
} catch (error) {
  if (started) console.error(readFileSync(join(cluster, 'server.log'), 'utf8').slice(-4000));
  throw error;
} finally {
  if (admin) await admin.end();
  if (started) execFileSync(join(native, 'bin/pg_ctl'), ['-D', data, '-m', 'fast', '-w', 'stop'], { stdio: 'pipe' });
  rmSync(cluster, { recursive: true, force: true });
}
