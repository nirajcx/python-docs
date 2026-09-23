// Run: node postgres-practice/verify.mjs [temporary npm tool directory]
// Default resolves local npm dependencies. All DB state is in memory.
import { createRequire } from 'node:module';
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';
const here = dirname(fileURLToPath(import.meta.url));
const require = createRequire(process.argv[2] ? resolve(process.argv[2], 'package.json') : import.meta.url);
const { PGlite } = require('@electric-sql/pglite');
const db = new PGlite();
const read = name => readFileSync(resolve(here, name), 'utf8');
const exercises = JSON.parse(read('exercise-manifest.json'));
try {
  for (const name of ['01-schema.sql', '02-seed.sql', '07-verify.sql']) await db.exec(read(name));
  await db.exec("SET search_path=interview_lab,public; SET TIME ZONE 'UTC';");
  const results = [];
  for (const exercise of exercises) results.push((await db.query(exercise.sql)).rows);
  const get = n => results[n-1];
  const ids = (n, column='id') => get(n).map(row => Number(row[column]));
  // Independent expectations, not derived by repeating the solution algorithm.
  assert.deepEqual(ids(1), [4,1,2]);
  assert.deepEqual(ids(2), [4,8]);
  assert.deepEqual(get(3).map(r=>r.city), ['Bengaluru','Delhi','Mumbai','Pune']);
  assert.deepEqual(get(5).map(r=>Number(r.orders)), [3,2,2,1,0,2,2,0]);
  assert.deepEqual(get(6).map(r=>Number(r.paid_orders)), [2,1,1,1,0,2,1,0]);
  assert.deepEqual(ids(7), [5,8]);
  assert.deepEqual(get(8).map(r=>Number(r.total)), [2000,600,1000,10000,700,300,600,10000,10500,2000,300,900]);
  assert.equal(Number(get(9)[0].revenue),18300);
  assert.deepEqual(get(10).map(r=>Number(r.paid_spend)),[2600,1000,700,600,0,12500,900,0]);
  assert.deepEqual(ids(11,'customer_id'),[1,6]);
  assert.deepEqual(get(12).map(r=>Number(r.revenue)),[3600,11800,2900]);
  assert.deepEqual(get(13).map(r=>Number(r.revenue)),[2000,0,1600,0,0]);
  assert.deepEqual(ids(14),[108,104,106,107,110,112]);
  assert.deepEqual(ids(15),[102,103,105,107,110,112]);
  assert.deepEqual(ids(16),[5]);
  assert.deepEqual(ids(17),[1,2,3,5,6,7,8]);
  assert.deepEqual(ids(18),[1,5]);
  assert.deepEqual(ids(20),[2,3,4]);
  assert.deepEqual(get(21).map(r=>Number(r.employees)),[4,2,2,0]);
  assert.deepEqual(ids(22,'order_id'),[103]);
  assert.deepEqual(get(23),[]);
  assert.equal(Number(get(24).find(r=>r.id===103).total),1000);
  assert.deepEqual(get(25).map(r=>r.previous_id),[null,101,102]);
  assert.deepEqual(get(25).map(r=>r.days_since===null?null:Number(r.days_since)),[null,2,31]);
  assert.deepEqual(get(26).map(r=>Number(r.running_revenue)),[2000,2600,3600,4300,14800,15400,17400,18300]);
  assert.deepEqual(get(28).map(r=>Number(r.revenue)),[1500,800,16000]);
  assert.deepEqual(ids(29),[6]);
  assert.deepEqual(get(30).map(r=>Number(r.revenue)),[4900,13400]);
  assert.deepEqual(ids(31),[102,105,108,110]);
  assert.deepEqual(ids(32),[102,105,110]);
  assert.deepEqual(get(33).map(r=>[r.name,Number(r.count)]),[['Asha',2]]);
  assert.deepEqual(ids(34),[106,105,104]);
  assert.deepEqual(ids(35),[105,106,107,108,109]);
  assert.deepEqual(get(36).map(r=>Number(r.active)),[2,2,2,1,1]);
  assert.deepEqual(get(37).map(r=>Number(r.longest)),[3,2,1]);
  assert.deepEqual(get(38).map(r=>Number(r.percent)),[56.76,27.03,16.22]);
  assert.deepEqual(get(39),[]);
  assert.deepEqual(Object.values(get(40)[0]).map(Number),[8,6,0]);
  // Negative integrity checks, with transaction rollback even after error.
  for (const [sql,code] of [
    ["INSERT INTO orders VALUES(999,2,1,'paid',now(),'{}')",'23503'],
    ["UPDATE inventory SET stock=-1 WHERE product_id=4",'23514'],
    ["INSERT INTO customers SELECT * FROM customers WHERE id=1",'23505']
  ]) {
    await db.exec('BEGIN');
    try { await db.exec(sql); assert.fail('Expected constraint rejection'); }
    catch(error) { assert.equal(error.code,code); }
    finally { await db.exec('ROLLBACK'); }
  }
  await db.exec('BEGIN');
  assert.equal((await db.query('UPDATE inventory SET stock=stock-1 WHERE product_id=4 AND stock>0 RETURNING stock')).rows.length,1);
  assert.equal((await db.query('UPDATE inventory SET stock=stock-1 WHERE product_id=4 AND stock>0 RETURNING stock')).rows.length,0);
  await db.exec('ROLLBACK');
  // Exercise empty-result reconciliation with an actual missing payment.
  await db.exec("BEGIN; DELETE FROM payments WHERE order_id=101;");
  assert.deepEqual((await db.query(exercises[22].sql)).rows,[{id:101}]);
  await db.exec('ROLLBACK');
  // All indexing statements, with VACUUM outside transaction.
  // This controlled lab has no semicolons in quoted values/functions.
  // Execute statements separately so VACUUM is not inside an implicit batch transaction.
  for (const sql of read('05-indexing-lab.sql').replace(/^--.*$/gm, '').split(';')) {
    if (sql.trim()) await db.exec(sql);
  }
  assert.equal(Number((await db.query('SELECT COUNT(*) AS n FROM order_events')).rows[0].n),100000);
  const output=['# Expected results — fixed seed data\n',
    'Generated by executing the 40 solutions in embedded PostgreSQL (PGlite), with independent fixture/output/constraint checks. PostgreSQL server planner timings and concurrent sessions are separate labs. Numeric display formatting may differ in your client.\n'];
  const cell=value=>value===null?'NULL':String(value).replaceAll('|','\\|');
  for(let i=0;i<exercises.length;i++) {
    output.push(`## Q${String(i+1).padStart(2,'0')}. ${exercises[i].title}\n`);
    const rows=results[i];
    if(!rows.length) output.push('Expected: **0 rows**.\n');
    else {
      const cols=Object.keys(rows[0]);
      output.push('| '+cols.join(' | ')+' |\n| '+cols.map(()=> '---').join(' | ')+' |');
      for(const row of rows) output.push('| '+cols.map(c=>cell(row[c])).join(' | ')+' |');
      output.push('');
    }
    output.push(`**Reason:** ${exercises[i].why}\n`);
  }
  writeFileSync(resolve(here,'EXPECTED-RESULTS.md'),output.join('\n'));
  console.log(JSON.stringify({engine:(await db.query('SELECT version()')).rows[0].version,queries:40,negativeConstraints:3,indexLabRows:100000,status:'passed'}));
} catch (error) {
  console.error(error.code || error.name, error.message);
  process.exitCode = 1;
} finally { await db.close(); }
