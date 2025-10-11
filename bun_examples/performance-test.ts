import { Database } from "./lmdbx";

function randomString(length: number): string {
  const chars = "abcdefghijklmnopqrstuvwxyz0123456789";
  let result = "";
  for (let i = 0; i < length; i++) {
    result += chars[Math.floor(Math.random() * chars.length)];
  }
  return result;
}

const COUNT = 1000;
const keys: string[] = [];
const values: string[] = [];

for (let i = 0; i < COUNT; i++) {
  keys.push(randomString(32));
  values.push(randomString(32));
}

const db = new Database("perf.db");

const start = performance.now();

for (let i = 0; i < COUNT; i++) {
  db.put(keys[i], values[i]);
}

for (let i = 0; i < COUNT; i++) {
  db.get(keys[i]);
}

const end = performance.now();

db.close();

console.log(`${COUNT} put + ${COUNT} get: ${(end - start).toFixed(2)}ms`);
console.log(`Operations/sec: ${((COUNT * 2) / ((end - start) / 1000)).toFixed(0)}`);
