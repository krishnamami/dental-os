/**
 * AccordDental Demo Recording Script
 *
 * HOW TO USE:
 * 1. Start Loom recording — full screen, no audio
 * 2. Run: node record_dental_demo.cjs
 * 3. Watch browser navigate automatically
 * 4. Stop Loom when terminal prints "Done"
 *
 * Scenes:
 *   Scene 1  — Landing page          (6s)
 *   Scene 2  — Sarah front desk      (14s)
 *   Scene 3  — Jennifer TC           (20s)
 *   Scene 4  — Dr. Chinta workbench  (16s)
 *   Scene 5  — Kim revenue ops       (16s)
 *   Scene 6  — Dr. Shyam DSO         (12s)
 *   Scene 7  — Landing page again    (6s)
 *   Total: ~89 seconds
 *
 * RESET BEFORE EACH TAKE:
 *   Scene 2 has Sarah check Linda Taylor in, which writes a row to
 *   checkin_events. Once written, the button disappears and the motion cannot
 *   be filmed again that day. Clear it first (dental_os DB, RLS needs the
 *   tenant set):
 *
 *     SET app.tenant_id = 'suwanee_smiles';
 *     DELETE FROM checkin_events
 *      WHERE tenant_id = 'suwanee_smiles'
 *        AND patient_name = 'Linda Taylor'
 *        AND checkin_day = CURRENT_DATE;
 *
 *   Leave the Aug 9 rows alone — those are seed data.
 *
 * SELECTOR NOTES (verified against the live site, Aug 2026):
 *   - Patient names are NOT clickable on /checkin or /coverage. Both pages
 *     render read-only <article> cards; only the status filter buttons at the
 *     top respond. Scenes 2 and 3 drive those filters instead.
 *   - /coverage has no patient detail view, so there are no "Talking points",
 *     "Treatment & cost" or "Checklist" tabs to open.
 *   - /workbench DOES have a real case strip: each case is a <button>, so
 *     button:has-text("James Mitchell") selects the tab (a bare text= selector
 *     matches an inert <span> instead).
 */

const { chromium } = require('playwright');

const BASE = 'https://www.accorddental.io';
const PASS = 'demo2026';

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
 * The route to this site drops connections intermittently, and a single
 * ERR_CONNECTION_RESET part-way through a take wastes the whole recording.
 *
 * The resets arrive in bursts rather than uniformly — measured at 30% one
 * minute and 0% the next, with runs long enough to defeat three attempts two
 * seconds apart. What matters is therefore the total time the retries span,
 * not the attempt count: these delays widen the window to ~60s so a burst can
 * pass, where 3 x 2s covered only ~6s.
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
  console.log(`  Logging in as ${email}...`);
  await go(page, `${BASE}/login`);
  await page.waitForSelector('input#email', { timeout: 15000 });
  await page.fill('input#email', '');
  await page.type('input#email', email, { delay: 60 });
  await page.fill('input#password', '');
  await page.type('input#password', PASS, { delay: 60 });
  await sleep(800);
  await page.click('button[type=submit]');
  await sleep(4000);
}

/**
 * Clicks a selector and holds for `wait`. The hold happens whether or not the
 * element was found, so a missing selector shortens nothing — the original
 * version skipped its sleep on a miss, which silently collapsed Scene 3 from
 * 20s to 14s. A miss is logged loudly rather than swallowed.
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

async function main() {
  console.log('AccordDental demo recording script');
  console.log('───────────────────────────────────');
  console.log('START YOUR LOOM RECORDING NOW.');
  console.log('Press Enter when Loom is recording...');

  await new Promise(resolve => {
    process.stdin.once('data', resolve);
  });

  const browser = await chromium.launch({
    headless: false,
    args: ['--start-maximized', '--disable-infobars'],
  });

  const context = await browser.newContext({ viewport: null });
  const page = await context.newPage();

  // ── SCENE 1 — Landing page (6s) ─────────────────────────
  console.log('\n[1/7] Landing page...');
  await go(page, BASE);
  await sleep(6000);

  // ── SCENE 2 — Sarah / Front Desk (14s) ──────────────────
  console.log('[2/7] Sarah — front desk...');
  await login(page, USERS.sarah);
  try {
    await page.waitForSelector('text=Good morning, Sarah', {
      timeout: 15000,
    });
  } catch {
    console.log('  Warning: Sarah greeting not visible');
  }
  await sleep(2000);

  // Nothing expands here: the patient cards render their AT A GLANCE detail
  // up front, and no element in a card carries a click handler (verified via
  // React fiber props — no onClick anywhere in the James Mitchell subtree).
  // The HEADS UP filter is the live control, narrowing to the flagged
  // patients; the scroll then brings AT A GLANCE into frame.
  await clickIfExists(page, 'button:has-text("HEADS UP")', 3000);

  await page.evaluate(() =>
    window.scrollBy({ top: 320, behavior: 'smooth' })
  );

  // Hold on AT A GLANCE —
  // insurance active, 4 items flagged
  await sleep(5000);

  // Sarah checks Linda Taylor in. This is the hinge of the whole demo: it
  // moves her from WAITING to READY FOR CONSULTATION, which is what makes
  // her talking-points card render for Jennifer in scene 3.
  //
  // It writes a real row to checkin_events, so it only works once per day.
  // On a re-run the button is gone, clickIfExists logs a warning and carries
  // on, and scene 3 still works because she is already checked in. To film
  // this motion again, clear the row first — see RESET at the bottom.
  await clickIfExists(
    page,
    'article:has-text("Linda Taylor") button:has-text("Check in patient")',
    4000
  );

  // ── SCENE 3 — Jennifer / TC (20s) ───────────────────────
  console.log('[3/7] Jennifer — treatment coordinator...');
  await login(page, USERS.jennifer);
  try {
    await page.waitForSelector('text=Good morning, Jennifer', {
      timeout: 15000,
    });
  } catch {
    console.log('  Warning: Jennifer greeting not visible');
  }
  await sleep(2000);

  // The talking-points card is NOT opened by clicking a patient — the cards
  // carry their own tabs, and only for the READY FOR CONSULTATION bucket
  // (status checked_in). A WAITING patient renders a stripped WaitingCard with
  // no scripts at all, by design — PatientFinancial.tsx:986.
  //
  // Linda Taylor is in that bucket because Sarah checked her in during scene
  // 2, on today's date. No date-picker detour needed: the two scenes are the
  // same working day, and the hand-off is the story.

  // Hold on Talking points — the default tab on her card
  await sleep(5000);

  await clickIfExists(page, 'button:has-text("Treatment & cost")', 4000);
  await clickIfExists(page, 'button:has-text("Checklist")', 3000);
  await clickIfExists(page, 'button:has-text("Talking points")', 2000);

  // ── SCENE 4 — Dr. Chinta (16s) ──────────────────────────
  console.log('[4/7] Dr. Chinta — clinical workbench...');
  await login(page, USERS.drchinta);
  try {
    await page.waitForSelector(
      'text=Good morning, Dr. Chinta',
      { timeout: 15000 }
    );
  } catch {
    console.log('  Warning: Dr. Chinta greeting not visible');
  }
  await sleep(2000);

  // The case strip: each case is a <button>. text= would match an inert span.
  // James Mitchell is already selected on load, so clicking him first would be
  // a silent no-op. Step to Linda Taylor and back — the strip visibly switches
  // and the scene still ends on the James Mitchell case the narration needs.
  await clickIfExists(page, 'button:has-text("Linda Taylor")', 2500);
  await clickIfExists(page, 'button:has-text("James Mitchell")', 3000);

  // Hold on clinical support —
  // criteria met + narrative missing
  await sleep(4000);

  // Scroll to clinical narrative + sign section
  await page.evaluate(() =>
    window.scrollBy({ top: 500, behavior: 'smooth' })
  );
  await sleep(6000);

  // ── SCENE 5 — Kim / Revenue Ops (16s) ───────────────────
  console.log('[5/7] Kim — revenue operations...');
  await login(page, USERS.kim);
  try {
    await page.waitForSelector('text=Revenue operations', {
      timeout: 15000,
    });
  } catch {
    console.log('  Warning: Revenue ops not visible');
  }
  await sleep(2000);

  // Hold on submission queue —
  // Blocked 3 · $9,450 at risk
  await sleep(4000);

  // Conditions tab
  await clickIfExists(page, 'text=Conditions', 4000);

  // Appeals tab
  await clickIfExists(page, 'text=Appeals', 4000);

  // ── SCENE 6 — Dr. Shyam / DSO (12s) ─────────────────────
  console.log('[6/7] Dr. Shyam — DSO view...');
  await login(page, USERS.drshyam);
  try {
    await page.waitForSelector(
      'text=Suwanee Smiles Dental',
      { timeout: 15000 }
    );
  } catch {
    console.log('  Warning: DSO view not visible');
  }
  await sleep(3000);

  // What's holding cases up tab
  await clickIfExists(
    page,
    "text=What's holding cases up",
    5000
  );

  // Hold on:
  // Pre-auth not filed — 21 cases
  // Radiograph missing — 9 cases
  // No clinical narrative — 7 cases
  await sleep(4000);

  // ── SCENE 7 — Back to landing page (6s) ─────────────────
  console.log('[7/7] Back to landing page...');
  await go(page, BASE);
  await sleep(6000);

  console.log('\n✓ All scenes complete.');
  console.log('STOP YOUR LOOM RECORDING NOW.');
  console.log('\nNext steps:');
  console.log('  1. Export Loom video (no audio)');
  console.log('  2. Paste ElevenLabs script → generate MP3');
  console.log('  3. Combine in CapCut → export MP4');
  console.log('  4. Save as: dental-os/frontend/public/accord_dental_demo.mp4');

  await sleep(3000);
  await browser.close();
  process.exit(0);
}

main().catch(err => {
  console.error('Script failed:', err.message);
  process.exit(1);
});
