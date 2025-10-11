import { Database } from "./lmdbx";

const db = new Database("test.db");

db.put("hello", "world");
console.log("Put: OK");

const result = db.get("hello");
console.log("Get:", result?.toString());

db.delete("hello");
console.log("Delete: OK");

db.close();
console.log("Closed!");
