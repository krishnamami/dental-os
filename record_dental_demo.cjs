/**
 * AccordDental Demo Recording Script
 *
 * Records itself — no Loom. Output: dental-os/accord_dental_demo.mp4
 *
 *   node record_dental_demo.cjs
 *
 * Then generate the ElevenLabs voiceover and merge (command printed at end).
 *
 * ─────────────────────────────────────────────────────────────────────────
 * HOW THIS DIFFERS FROM decision-os/frontend/record_landing_video_v6.cjs
 *
 * That script uses puppeteer-core + puppeteer-screen-recorder + an ffmpeg
 * binary from @ffmpeg-installer. Two consequences worth knowing:
 *
 *   - It writes MP4 directly, because puppeteer-screen-recorder pipes frames
 *     through ffmpeg itself. Playwright's built-in recorder writes WebM and
 *     has no MP4 option, so this script transcodes at the end. ffmpeg must be
 *     on PATH (it is: ffmpeg 8.1.2).
 *
 *   - It starts the recorder mid-session, after pre-loading, on the same page
 *     — a CDP screencast can begin at any time. Playwright's recorder is
 *     configured at newContext() and records that context's whole life, so
 *     the pre-load has to happen in a SEPARATE context that is then thrown
 *     away. The warmth that carries over is server-side (the /checkin/today
 *     endpoint takes ~7s cold — see api/routes.py:654), which is the part
 *     that actually causes skeletons here.
 *
 * If you want byte-identical parity with accordlend, port this to
 * puppeteer-screen-recorder instead; it needs three extra deps and a real
 * Chrome install.
 * ─────────────────────────────────────────────────────────────────────────
 *
 * Scenes (~79s):
 *   1 Landing page        6s
 *   2 Sarah front desk   12s
 *   3 Jennifer TC        18s
 *   4 Dr. Chinta         14s
 *   5 Kim revenue ops    14s
 *   6 Dr. Shyam DSO      10s
 *   7 Landing page        5s
 *
 * SCENE 2 NOTE — the check-in click writes a real checkin_events row, so it
 * only fires once per day per patient. If Linda Taylor is already checked in
 * today the button is absent, the script warns and keeps its timing, and the
 * caption still reads correctly. checkin_day is CURRENT_DATE, so the button
 * returns on its own the next day. Same-day reset (needs dental_admin —
 * dental_app has no DELETE on this table):
 *
 *     SET app.tenant_id = 'suwanee_smiles';
 *     DELETE FROM checkin_events
 *      WHERE tenant_id = 'suwanee_smiles'
 *        AND patient_name = 'Linda Taylor'
 *        AND checkin_day = CURRENT_DATE;
 *
 * SELECTOR NOTES (verified against the live site, Aug 2026):
 *   - Patient names are NOT clickable on /checkin or /coverage. Both render
 *     read-only <article> cards; no element in a card carries an onClick
 *     (checked via React fiber props, not cursor style). Only the status
 *     filter buttons and the per-card action buttons respond.
 *   - The talking-points tabs live INSIDE each ready card and render only for
 *     the READY FOR CONSULTATION bucket. A WAITING patient renders a stripped
 *     WaitingCard with no scripts, by design — PatientFinancial.tsx:986.
 *     Aug 9 2026 has Linda Taylor already ready, which is why scene 3 picks
 *     that date rather than depending on scene 2's check-in.
 *   - /workbench DOES have a real case strip of <button>s, so scene 4 uses
 *     button:has-text(...). A bare text= selector matches an inert <span>.
 *     James Mitchell is the default-active case.
 */

const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');
const { execFileSync } = require('child_process');

const BASE = 'https://www.accorddental.io';
const PASS = 'demo2026';

const W = 1280, H = 720;
const OUT_DIR = __dirname;
const OUT_MP4 = path.resolve(OUT_DIR, 'accord_dental_demo.mp4');
const VIDEO_DIR = path.resolve(OUT_DIR, '.video_tmp');

const USERS = {
  sarah:    'sarah@suwaneesmiles.com',
  jennifer: 'tc@suwaneesmiles.com',
  drchinta: 'drchinta@suwaneesmiles.com',
  kim:      'billing@suwaneesmiles.com',
  drshyam:  'drshyam@suwaneesmiles.com',
};

function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

/**
 * The route to this site drops connections in bursts — measured at 30% one
 * minute and 0% the next, with runs long enough to defeat three attempts two
 * seconds apart. What matters is the total span the retries cover, not the
 * attempt count, so these delays widen the window to ~60s.
 */
const NAV_RETRY_DELAYS = [2000, 4000, 8000, 16000, 30000];
const NAV_RETRIES = NAV_RETRY_DELAYS.length + 1; // 6 attempts

async function go(page, url) {
  let lastErr;
  for (let attempt = 1; attempt <= NAV_RETRIES; attempt++) {
    try {
      await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
      if (attempt > 1) console.log(`    (recovered on attempt ${attempt})`);
      return;
    } catch (err) {
      lastErr = err;
      console.log(`    nav attempt ${attempt}/${NAV_RETRIES} failed: ${err.message.split('\n')[0]}`);
      if (attempt < NAV_RETRIES) {
        const delay = NAV_RETRY_DELAYS[attempt - 1];
        console.log(`    retrying in ${delay / 1000}s...`);
        await sleep(delay);
      }
    }
  }
  throw lastErr;
}

async function login(page, email) {
  await go(page, `${BASE}/login`);
  await page.waitForSelector('input#email', { timeout: 15000 });
  await page.fill('input#email', '');
  await page.type('input#email', email, { delay: 30 });
  await page.fill('input#password', '');
  await page.type('input#password', PASS, { delay: 30 });
  await page.click('button[type=submit]');
  await sleep(4000);
}

/** True if the text is on screen within `timeout`. Warns rather than throws. */
async function waitForText(page, text, timeout = 20000) {
  const start = Date.now();
  while (Date.now() - start < timeout) {
    const found = await page.locator(`text=${text}`).count().catch(() => 0);
    if (found) return true;
    await sleep(300);
  }
  console.log(`  WARN: text not visible — "${text}"`);
  return false;
}

// ── Captions ─────────────────────────────────────────────────────────────
// Re-injected per scene: page.goto wipes the DOM, so the overlay cannot
// persist across a navigation.

async function caption(page, text) {
  await page.evaluate((t) => {
    let el = document.getElementById('__cap__');
    if (!el) {
      el = document.createElement('div');
      el.id = '__cap__';
      el.style.cssText =
        'position:fixed;left:50%;bottom:32px;transform:translateX(-50%);' +
        'z-index:2147483647;max-width:600px;background:rgba(0,0,0,0.75);' +
        'color:#fff;padding:12px 20px;border-radius:8px;text-align:center;' +
        'font:18px/1.5 system-ui,-apple-system,Segoe UI,sans-serif;';
      document.body.appendChild(el);
    }
    el.textContent = t;
  }, text);
}

async function clearCaption(page) {
  await page.evaluate(() => {
    const el = document.getElementById('__cap__');
    if (el) el.textContent = '';
  }).catch(() => {});
}

/**
 * Clicks a selector and holds for `wait`. The hold happens whether or not the
 * element was found, so a missing selector shortens no scene — important when
 * a scene is timed against a voiceover.
 */
async function clickIfExists(page, selector, wait = 2000) {
  try {
    const el = page.locator(selector).first();
    if (await el.count()) {
      await el.click({ timeout: 5000 });
      await sleep(wait);
      return true;
    }
    console.log(`  WARN: selector not found — ${selector}`);
  } catch (err) {
    console.log(`  WARN: click failed — ${selector} (${err.message.split('\n')[0]})`);
  }
  await sleep(wait);
  return false;
}

// ── STEP 1 — pre-load ────────────────────────────────────────────────────
// Warms the API for every persona so no scene films a loading skeleton. This
// context is discarded; only server-side warmth carries into the recording.

async function preload(browser) {
  console.log('\nPRE-LOAD (no recording yet)');
  const ctx = await browser.newContext({ viewport: { width: W, height: H } });
  const page = await ctx.newPage();
  const ok = {};

  console.log('  a. sarah → /checkin');
  await login(page, USERS.sarah);
  ok.sarah = await waitForText(page, 'Good morning, Sarah');

  console.log('  b. jennifer → /coverage → 2026-08-09');
  await login(page, USERS.jennifer);
  await waitForText(page, 'Good morning, Jennifer');
  await page.selectOption('select', '2026-08-09').catch(() => {});
  await sleep(3000);
  const jenTxt = (await page.locator('body').innerText()).replace(/\s+/g, ' ');
  ok.jennifer = jenTxt.includes('Linda Taylor') &&
                jenTxt.toLowerCase().includes('talking point');
  console.log(`     Linda Taylor READY + talking points: ${ok.jennifer}`);

  console.log('  c. drchinta → /workbench');
  await login(page, USERS.drchinta);
  ok.drchinta = await waitForText(page, 'James Mitchell');

  console.log('  d. kim → /revenue-ops');
  await login(page, USERS.kim);
  ok.kim = await waitForText(page, 'Revenue operations');

  console.log('  e. drshyam → /dso');
  await login(page, USERS.drshyam);
  ok.drshyam = await waitForText(page, 'Suwanee Smiles Dental');

  await ctx.close();

  const failed = Object.entries(ok).filter(([, v]) => !v).map(([k]) => k);
  console.log(`  pre-load: ${Object.values(ok).filter(Boolean).length}/5 confirmed` +
              (failed.length ? ` — FAILED: ${failed.join(', ')}` : ''));
  return failed.length === 0;
}

// ── STEP 2 — record ──────────────────────────────────────────────────────

async function record(browser) {
  fs.rmSync(VIDEO_DIR, { recursive: true, force: true });
  fs.mkdirSync(VIDEO_DIR, { recursive: true });

  const ctx = await browser.newContext({
    viewport: { width: W, height: H },
    recordVideo: { dir: VIDEO_DIR, size: { width: W, height: H } },
  });
  const page = await ctx.newPage();
  console.log('\nRECORDING');

  // ── SCENE 1 — Landing page (6s) ────────────────────────────────────────
  console.log('[1/7] Landing page');
  await go(page, BASE);
  await caption(page,
    'AccordDental — Pre-D intelligence for dental practices and DSOs.');
  await sleep(6000);
  await clearCaption(page);

  // ── SCENE 2 — Sarah / front desk (12s) ─────────────────────────────────
  console.log('[2/7] Sarah — front desk');
  await login(page, USERS.sarah);
  await waitForText(page, 'Good morning, Sarah');
  await caption(page,
    'Sarah is at the front desk. Linda Taylor arrives for a crown at nine thirty.');
  await sleep(4000);

  await clickIfExists(page,
    'article:has-text("Linda Taylor") button:has-text("Check in patient")', 500);
  await caption(page, 'One click. Checked in.');
  await sleep(6000);
  await clearCaption(page);

  // ── SCENE 3 — Jennifer / TC (18s) ──────────────────────────────────────
  console.log('[3/7] Jennifer — treatment coordinator');
  await login(page, USERS.jennifer);
  await waitForText(page, 'Good morning, Jennifer');
  await page.selectOption('select', '2026-08-09').catch(() => {});
  await sleep(3000);
  await caption(page,
    'Jennifer is the treatment coordinator. Linda is now ready.');
  await sleep(4000);

  await clickIfExists(page, 'button:has-text("Talking points")', 500);
  await caption(page,
    'Accord has already written her talking points — what to say, ' +
    'what to warn, what to collect.');
  await sleep(4000);

  await clickIfExists(page, 'button:has-text("Treatment & cost")', 500);
  await caption(page,
    'Six hundred and twenty dollars. Not an estimate. The number.');
  await sleep(4000);

  await clickIfExists(page, 'button:has-text("Checklist")', 500);
  await caption(page, 'Every item covered before Linda leaves.');
  await sleep(4000);
  await clearCaption(page);

  // ── SCENE 4 — Dr. Chinta (14s) ─────────────────────────────────────────
  console.log('[4/7] Dr. Chinta — clinical workbench');
  await login(page, USERS.drchinta);
  await waitForText(page, 'Good morning, Dr. Chinta');
  await caption(page, "Dr. Chinta opens James Mitchell's implant case.");
  await sleep(3000);

  // James Mitchell is already selected on load, so clicking him first would be
  // a silent no-op. Step to Linda Taylor and back for visible motion.
  await clickIfExists(page, 'button:has-text("Linda Taylor")', 800);
  await clickIfExists(page, 'button:has-text("James Mitchell")', 500);
  await caption(page,
    'Clinical criteria met — four point two millimeters bone loss. ' +
    'But the narrative is missing.');
  await sleep(4000);

  await page.evaluate(() => window.scrollBy({ top: 500, behavior: 'smooth' }));
  await caption(page,
    'Accord drafted it from the chart. Dr. Chinta reviews and signs.');
  await sleep(5000);
  await clearCaption(page);

  // ── SCENE 5 — Kim / revenue ops (14s) ──────────────────────────────────
  console.log('[5/7] Kim — revenue operations');
  await login(page, USERS.kim);
  await waitForText(page, 'Revenue operations');
  await caption(page,
    'Kim runs revenue operations. Three cases blocked. ' +
    'Nine thousand four hundred and fifty dollars at risk.');
  await sleep(4000);

  await clickIfExists(page, 'text=Conditions', 500);
  await caption(page,
    'Every condition sorted by SLA. Every denial has a citation.');
  await sleep(4000);

  await clickIfExists(page, 'text=Appeals', 500);
  await caption(page,
    'Three appeals filed. Fifty percent overturn rate. ' +
    'One thousand eight hundred dollars recovered.');
  await sleep(4000);
  await clearCaption(page);

  // ── SCENE 6 — Dr. Shyam / DSO (10s) ────────────────────────────────────
  console.log('[6/7] Dr. Shyam — DSO view');
  await login(page, USERS.drshyam);
  await waitForText(page, 'Suwanee Smiles Dental');
  await caption(page,
    'Dr. Shyam owns two practices. Fifty-five thousand six hundred ' +
    'and fifty dollars sitting with payers right now.');
  await sleep(4000);

  await clickIfExists(page, "text=What's holding cases up", 500);
  await caption(page,
    'Twenty-one cases missing a pre-auth. Nine missing a radiograph. ' +
    'Seven with no clinical narrative. Every cause. Every owner. Named.');
  await sleep(5000);
  await clearCaption(page);

  // ── SCENE 7 — Back to landing page (5s) ────────────────────────────────
  console.log('[7/7] Back to landing page');
  await go(page, BASE);
  await caption(page,
    'AccordDental. Every signal has a citation. Every decision has a trail. ' +
    'Every denial has a fix.');
  await sleep(5000);
  await clearCaption(page);

  // ── STEP 3 — stop recorder ─────────────────────────────────────────────
  const video = page.video();
  await ctx.close();               // finalises the WebM
  const webm = await video.path();
  return webm;
}

function toMp4(webm) {
  console.log('\nTranscoding WebM → MP4 (Playwright records WebM only)...');
  execFileSync('ffmpeg', [
    '-y', '-i', webm,
    '-c:v', 'libx264', '-preset', 'medium', '-crf', '20',
    '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
    OUT_MP4,
  ], { stdio: ['ignore', 'ignore', 'pipe'] });
}

async function main() {
  const browser = await chromium.launch({ headless: true });
  try {
    const preloaded = await preload(browser);
    if (!preloaded) {
      console.log('\n  Pre-load did not confirm every persona. Recording anyway —' +
                  '\n  check the scenes above before using the take.');
    }
    const webm = await record(browser);
    await browser.close();

    toMp4(webm);
    fs.rmSync(VIDEO_DIR, { recursive: true, force: true });

    const mb = (fs.statSync(OUT_MP4).size / 1024 / 1024).toFixed(1);
    console.log(`\nSaved → accord_dental_demo.mp4  (${mb} MB)`);
    console.log('Now generate ElevenLabs voiceover and run FFmpeg to merge audio.');
    console.log('\n  ffmpeg -i accord_dental_demo.mp4 \\');
    console.log('    -i accord_dental_voiceover.mp3 \\');
    console.log('    -c:v copy -c:a aac -shortest \\');
    console.log('    accord_dental_FINAL.mp4');
  } finally {
    await browser.close().catch(() => {});
  }
}

main().catch(err => {
  console.error('Script failed:', err.message);
  process.exit(1);
});
