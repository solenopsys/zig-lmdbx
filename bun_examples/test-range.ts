import { Database } from "./lmdbx";

const db = new Database("range-test.db");

// Заполняем базу данными
db.transaction(() => {
  db.put("key001", "value1");
  db.put("key005", "value5");
  db.put("key010", "value10");
  db.put("key015", "value15");
  db.put("key020", "value20");
  db.put("key025", "value25");
  db.put("key030", "value30");
});

// Тест 1: Все ключи
console.log("\n=== Все ключи ===");
const all = db.getRange();
all.forEach(item => console.log(`${item.key.toString()}: ${item.value.toString()}`));

// Тест 2: С ограничением
console.log("\n=== Первые 3 ключа ===");
const limited = db.getRange({ limit: 3 });
limited.forEach(item => console.log(`${item.key.toString()}: ${item.value.toString()}`));

// Тест 3: Диапазон от key010 до key020
console.log("\n=== Диапазон key010 - key020 ===");
const range = db.getRange({ start: "key010", end: "key020" });
range.forEach(item => console.log(`${item.key.toString()}: ${item.value.toString()}`));

// Тест 4: Обратный порядок
console.log("\n=== Обратный порядок (последние 3) ===");
const reversed = db.getRange({ reverse: true, limit: 3 });
reversed.forEach(item => console.log(`${item.key.toString()}: ${item.value.toString()}`));

// Тест 5: От определенного ключа
console.log("\n=== От key015 (лимит 3) ===");
const fromKey = db.getRange({ start: "key015", limit: 3 });
fromKey.forEach(item => console.log(`${item.key.toString()}: ${item.value.toString()}`));

db.close();
console.log("\n✅ Все тесты пройдены!");
