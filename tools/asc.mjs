// Minimal App Store Connect API helper for PrayPass. Reads the team key; never prints secrets.
// Usage: node asc.mjs GET /v1/bundleIds?filter[identifier]=com.praypass.app
//        node asc.mjs POST /v1/bundleIds '{"data":{...}}'
import crypto from "node:crypto";
import fs from "node:fs";
const KEY_PATH = "/Users/markmorrison/.appstoreconnect/private_keys/AuthKey_U6Q28J57U5.p8";
const KEY_ID = "U6Q28J57U5", ISSUER = "271a7b2c-4191-4c72-91fe-d4561462f7bf";
const b64u = (b) => Buffer.from(b).toString("base64url");
function jwt() {
  const now = Math.floor(Date.now() / 1000);
  const head = b64u(JSON.stringify({ alg: "ES256", kid: KEY_ID, typ: "JWT" }));
  const body = b64u(JSON.stringify({ iss: ISSUER, iat: now, exp: now + 1100, aud: "appstoreconnect-v1" }));
  const sig = crypto.sign("sha256", Buffer.from(`${head}.${body}`), { key: fs.readFileSync(KEY_PATH), dsaEncoding: "ieee-p1363" });
  return `${head}.${body}.${b64u(sig)}`;
}
const [method, url, body] = process.argv.slice(2);
const r = await fetch(`https://api.appstoreconnect.apple.com${url}`, {
  method, headers: { Authorization: `Bearer ${jwt()}`, "Content-Type": "application/json" }, body: body || undefined,
});
const t = await r.text();
console.log(r.status, (process.env.FULL || t.length <= 4000) ? t : t.slice(0, 4000) + "…");
