// check.mjs: end-to-end checks of the guest page, the trunk page and
// the listen page, in headless Chromium with a fake camera and a test
// tone for a microphone. README.md says how to set up and run them.
//
//   SHIP=http://localhost:8110 CODE=<+code> BROWSER=/usr/bin/chromium \
//     node check.mjs [guest|video|page|listen|all]
//
// It signs in as the owner, opens a party line 'browser-check' with a
// permanent link of the same name, and closes both at the end. Each
// check prints ok or BAD; the run ends PASS or FAIL.
import { writeFileSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import puppeteer from 'puppeteer-core';

const { SHIP, CODE, BROWSER, LISTEN } = process.env;
if (!SHIP || !CODE || !BROWSER) {
  console.error('set SHIP, CODE and BROWSER; see README.md');
  process.exit(2);
}
const only = process.argv[2] || 'all';
const LINE = 'browser-check';
const LINK = `${SHIP}/apps/trunk/guest/${LINE}`;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let failed = 0;
const check = (name, ok, info) => {
  if (!ok) failed++;
  console.log(ok ? 'ok ' : 'BAD', name, ok || info === undefined ? '' : JSON.stringify(info));
};

// A 440 Hz tone, 0.7 s on and 0.3 s off, like speech. Chrome's own fake
// microphone beeps too briefly for a level meter to catch.
function tone() {
  const rate = 48000, secs = 30, n = rate * secs;
  const b = Buffer.alloc(44 + n * 2);
  b.write('RIFF', 0); b.writeUInt32LE(36 + n * 2, 4); b.write('WAVEfmt ', 8);
  b.writeUInt32LE(16, 16); b.writeUInt16LE(1, 20); b.writeUInt16LE(1, 22);
  b.writeUInt32LE(rate, 24); b.writeUInt32LE(rate * 2, 28); b.writeUInt16LE(2, 32);
  b.writeUInt16LE(16, 34); b.write('data', 36); b.writeUInt32LE(n * 2, 40);
  for (let i = 0; i < n; i++) {
    const t = i / rate;
    const v = t % 1 < 0.7 ? Math.round(0.3 * 32767 * Math.sin(2 * Math.PI * 440 * t)) : 0;
    b.writeInt16LE(v, 44 + i * 2);
  }
  const f = join(tmpdir(), 'trunk-check-tone.wav');
  writeFileSync(f, b);
  return f;
}
const wav = tone();

const browsers = [];
async function page() {
  const b = await puppeteer.launch({
    executablePath: BROWSER,
    headless: true,
    args: [
      '--use-fake-device-for-media-stream',
      '--use-fake-ui-for-media-stream',
      `--use-file-for-fake-audio-capture=${wav}`,
      '--auto-select-desktop-capture-source=Entire screen',
      '--no-first-run',
    ],
  });
  browsers.push(b);
  const p = await b.newPage();
  p.on('pageerror', (e) => console.log('  page error:', e.message));
  // keep every peer connection, to read its stats
  await p.evaluateOnNewDocument(() => {
    const Real = window.RTCPeerConnection;
    window.__pcs = [];
    window.RTCPeerConnection = function (...a) { const pc = new Real(...a); window.__pcs.push(pc); return pc; };
    window.RTCPeerConnection.prototype = Real.prototype;
  });
  return p;
}

async function owner() {
  const p = await page();
  await p.goto(`${SHIP}/~/login`);
  await p.type('input[name=password]', CODE);
  await Promise.all([p.waitForNavigation(), p.keyboard.press('Enter')]);
  return p;
}

// one trunk-action through the owner's page route; answers the status
const act = (p, body) => p.evaluate(async (b) => (await fetch('/apps/trunk/action', {
  method: 'POST', credentials: 'same-origin',
  headers: { 'content-type': 'application/json' }, body: JSON.stringify(b),
})).status, body);

const onCall = (p) => p.waitForFunction(
  () => /on the call/i.test(document.querySelector('#status').textContent), { timeout: 20000 });

async function guest(name) {
  const p = await page();
  await p.goto(LINK);
  await p.waitForSelector('#form:not([hidden])', { timeout: 15000 });
  await p.click('#name', { clickCount: 3 });
  await p.type('#name', name);
  await p.click('#join');
  await onCall(p);
  return p;
}

// what page `p` shows for the tile whose name starts with `who`
const tile = (p, who) => p.evaluate(async (who) => {
  const t = [...document.querySelectorAll('.tile')].find((t) => t.querySelector('.name').textContent.startsWith(who));
  if (!t) return null;
  const v = t.querySelector('video');
  return { video: t.classList.contains('video'), w: v.videoWidth, h: v.videoHeight, label: t.querySelector('.name').textContent };
}, who);

const bytes = (p, kind, dir) => p.evaluate(async (kind, dir) => {
  let n = 0;
  for (const pc of window.__pcs) {
    (await pc.getStats()).forEach((r) => {
      if (r.type === dir && r.kind === kind) n += (dir === 'inbound-rtp' ? r.bytesReceived : r.bytesSent) || 0;
    });
  }
  return n;
}, kind, dir);

async function until(f, ms = 6000) {
  for (let t = 0; t < ms; t += 250) { if (await f()) return true; await sleep(250); }
  return false;
}

// audio both ways, rejoining as the same guest, the alone line, the
// speaking ring and the mute reset
async function guestChecks() {
  const a = await guest('Alice');
  await sleep(1000);
  const alone = await a.$eval('#alone', (e) => !e.hidden && /Nobody else/.test(e.textContent));
  check('a guest alone is told others will appear', alone);
  const b = await guest('Bob');
  await sleep(4000);
  check('audio flows both ways',
    (await bytes(a, 'audio', 'inbound-rtp')) > 0 && (await bytes(b, 'audio', 'inbound-rtp')) > 0);
  check('the alone line goes when someone joins', await a.$eval('#alone', (e) => e.hidden));
  check('a speaking ring lights for the other guest', await until(() => a.evaluate(
    () => [...document.querySelectorAll('.tile.speaking')].some((t) => /Bob/.test(t.textContent)))));
  check('your own tile says (you), not (guest)', !!(await tile(a, 'Alice (you)')));
  const key = (p) => p.evaluate(() => localStorage.getItem(location.pathname.split('/').pop() + ':secret'));
  const before = await key(a);
  await a.click('#mute');
  await a.click('#leave');
  await a.reload();
  await a.waitForSelector('#form:not([hidden])');
  check('a reload keeps the name', (await a.$eval('#name', (e) => e.value)) === 'Alice');
  await a.click('#join');
  await onCall(a);
  check('a rejoin is the same guest', (await key(a)) === before);
  await sleep(1000);
  const t = await tile(a, 'Alice');
  check('a rejoin after leaving muted is unmuted',
    (await a.$eval('#mute', (e) => e.textContent)) === 'Mute' && !/muted/.test(t.label), t);
}

// camera frames, a late joiner, mute, a share on the same tile, video off
async function videoChecks() {
  const a = await guest('Ann');
  const b = await guest('Ben');
  await sleep(2000);
  check('no video before the camera', (await tile(b, 'Ann'))?.video === false);
  await a.click('#camera');
  check('the camera reaches the others', await until(async () => {
    const t = await tile(b, 'Ann');
    return t && t.video && t.w > 0;
  }), await tile(b, 'Ann'));
  const c = await guest('Cat');
  check('a late joiner sees the camera', await until(async () => {
    const t = await tile(c, 'Ann');
    return t && t.video && t.w > 0;
  }), await tile(c, 'Ann'));
  await a.click('#mute');
  check('mute shows to the others', await until(async () => /muted/.test((await tile(b, 'Ann'))?.label)));
  const cam = await tile(b, 'Ann');
  await a.click('#share');
  check('a share replaces the camera on the same tile', await until(async () => {
    const t = await tile(b, 'Ann');
    return t && t.video && t.w > 0 && (t.w !== cam.w || t.h !== cam.h);
  }), await tile(b, 'Ann'));
  await a.click('#share');
  await a.click('#camera');
  check('video off is seen', await until(async () => (await tile(b, 'Ann'))?.video === false));
}

// the Guests section: permanent-link mode, a new line with its link,
// the new link marked with Copy focused
async function pageChecks(o) {
  await o.goto(`${SHIP}/apps/trunk`);
  await o.waitForSelector('#g-room option');
  await o.select('#g-room', '');
  check('New line shows its title field', await o.$eval('#g-new-title', (e) => e.offsetParent !== null));
  const name = 'browser-check-page';
  await o.type('#g-title', 'Browser check page');
  await o.type('#g-code', name);
  const mode = await o.evaluate(() => ({
    button: document.querySelector('#g-make').textContent,
    people: document.querySelector('#g-uses-row').offsetParent !== null,
  }));
  check('a link name makes it a permanent link', mode.button === 'Make a permanent link' && !mode.people, mode);
  await o.click('#g-make');
  const made = await until(() => o.evaluate((n) => {
    const f = document.querySelector('.device.fresh');
    return !!f && f.innerText.includes(n) && document.activeElement.textContent === 'Copy link';
  }, name), 10000);
  check('the new line and link are made, marked, with Copy focused', made);
  check('the new-line fields hide again', await o.$eval('#g-new-title', (e) => e.offsetParent === null));
  await act(o, { 'revoke-invite': name });
  await act(o, { 'close-room': { name } });
}

// LISTEN is a listen link for the line 'browser-check' (README.md)
async function listenChecks() {
  if (!LISTEN) { console.log('-- listen: skipped, LISTEN not set'); return; }
  const g = await guest('Speaker');
  const l = await page();
  await l.goto(LISTEN);
  await l.click('#go');
  check('the listen page joins', await until(() => l.evaluate(
    () => /Listening/.test(document.querySelector('#status').textContent)), 10000));
  check('the listen page shows the guest speaking', await until(() => l.evaluate(
    () => [...document.querySelectorAll('#whoList li')].some((li) => /Speaker \(guest\)/.test(li.textContent) && li.querySelector('.dot.on'))), 10000));
  check('the listen page is styled', (await l.$eval('#go', (e) => getComputedStyle(e).borderRadius)) !== '0px');
  void g;
}

const o = await owner();
check('the owner can open the check line', [204].includes(await act(o, { 'open-room': { name: LINE, title: 'Browser check', members: [], admins: [] } })));
check('and give it a permanent link', [204].includes(await act(o, { 'guest-link': { code: LINE, name: LINE, speak: true } })));
const runs = { guest: guestChecks, video: videoChecks, page: () => pageChecks(o), listen: listenChecks };
try {
  for (const [k, f] of Object.entries(runs)) {
    if (only !== 'all' && only !== k) continue;
    console.log(`-- ${k}`);
    await f();
  }
} catch (e) {
  failed++;
  console.log('BAD crashed:', e.message);
} finally {
  await act(o, { 'revoke-invite': LINE });
  await act(o, { 'close-room': { name: LINE } });
  for (const b of browsers) await b.close();
}
console.log(failed ? `FAIL (${failed})` : 'PASS');
process.exit(failed ? 1 : 0);
