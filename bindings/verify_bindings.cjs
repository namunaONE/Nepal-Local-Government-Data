// bindings/verify_bindings.cjs — execute the generated bindings and assert
// they agree with the one source of truth.
//
// Usage (from the repo root):
//   node bindings/verify_bindings.cjs
//
// Exit 0 = pass, 1 = fail. Runs in CI (see .github/workflows/dart.yml).
//
// Why this exists
// ---------------
// Generating a binding proves only that the generator ran. It does not prove
// the JavaScript is loadable, that the CSV parses, that the GeoJSON is valid,
// or that any of them still agrees with the dataset. This executes the JS,
// parses the CSV and GeoJSON, and cross-checks every artifact against
// data/nepal_local_levels.json — so a binding that silently diverges, or a
// syntax error in a template, fails here rather than in a user's project.
//
// The Python binding is NOT verified here: it needs a Python interpreter.
// CI runs it in a separate job (see the bindings job in dart.yml).

'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const BINDINGS = path.join(ROOT, 'bindings');

let failures = 0;
let checks = 0;

function check(cond, label, detail) {
  checks++;
  if (!cond) {
    failures++;
    console.error(`  FAIL  ${label}${detail ? `\n        ${detail}` : ''}`);
  }
}

function section(title) {
  console.log(`\n${title}`);
}

// ---------------------------------------------------------------------------
// The source of truth
// ---------------------------------------------------------------------------

const source = JSON.parse(
  fs.readFileSync(path.join(ROOT, 'data', 'nepal_local_levels.json'), 'utf8'),
);

const srcProvinces = source.provinces;
const srcDistricts = [];
const srcBodies = [];
for (const p of srcProvinces) {
  for (const d of p.districts) {
    srcDistricts.push({ ...d, province: p.name });
    for (const b of d.localBodies) {
      srcBodies.push({ ...b, district: d.name, province: p.name });
    }
  }
}

console.log('='.repeat(70));
console.log('BINDINGS VERIFICATION');
console.log(`source: data/nepal_local_levels.json (${srcBodies.length} palikas)`);
console.log('='.repeat(70));

// ---------------------------------------------------------------------------
// 1. JavaScript binding
// ---------------------------------------------------------------------------

section('1. JavaScript binding (bindings/javascript/index.js)');

let nad;
try {
  nad = require(path.join(BINDINGS, 'javascript', 'index.js'));
  check(true, 'module loads without throwing');
} catch (err) {
  check(false, 'module loads without throwing', err && err.stack);
}

if (nad) {
  check(nad.provinces.length === srcProvinces.length,
    `provinces: ${nad.provinces.length} === ${srcProvinces.length}`);
  check(nad.districts.length === srcDistricts.length,
    `districts: ${nad.districts.length} === ${srcDistricts.length}`);
  check(nad.localBodies.length === srcBodies.length,
    `localBodies: ${nad.localBodies.length} === ${srcBodies.length}`);

  // --- counts the bindings must reproduce exactly ---
  const s = nad.getNationalStats();
  check(s.provinces === 7, `nationalStats.provinces === 7 (got ${s.provinces})`);
  check(s.districts === 77, `nationalStats.districts === 77 (got ${s.districts})`);
  check(s.metro === 6, `nationalStats.metro === 6 (got ${s.metro})`);
  check(s.subMetro === 11, `nationalStats.subMetro === 11 (got ${s.subMetro})`);
  check(s.municipalities === 276,
    `nationalStats.municipalities === 276 (got ${s.municipalities})`);
  check(s.ruralMunicipalities === 460,
    `nationalStats.ruralMunicipalities === 460 (got ${s.ruralMunicipalities})`);
  check(s.total === 753, `nationalStats.total === 753 (got ${s.total})`);
  check(s.wards === 6743, `nationalStats.wards === 6743 declared (got ${s.wards})`);
  check(s.verifiedWards === 6697,
    `nationalStats.verifiedWards === 6697 (got ${s.verifiedWards})`);
  check(s.wardGaps === 8, `nationalStats.wardGaps === 8 (got ${s.wardGaps})`);
  check(s.unreconciledWards === s.wards - s.verifiedWards,
    'unreconciledWards is consistent with the two totals');

  // --- confidence tiers must match the Dart package's ---
  const coded = nad.getLocalBodiesWithCode().length;
  const doubled = nad.getVerifiedLocalBodies().length;
  const single = nad.getSingleSourceLocalBodies().length;
  const uncoded = nad.getUncodedLocalBodies().length;
  check(coded === 744, `744 palikas carry a code (got ${coded})`);
  check(doubled === 548, `548 doubly-attested (got ${doubled})`);
  check(single === 196, `196 single-source (got ${single})`);
  check(uncoded === 9, `9 uncoded (got ${uncoded})`);
  check(doubled + single + uncoded === 753,
    'tiers partition all 753 without loss or overlap');
  // Mappable means BOTH a code and a coordinate. That is a smaller set than
  // either one alone: 726 have coordinates, 744 have codes, and the
  // intersection is 718.
  const mappedOnly = nad.getAllLocalBodies().filter((b) => b.lat != null && b.lng != null).length;
  const mappable = nad.getMappableLocalBodies().length;
  check(mappedOnly === 726, `726 mapped (got ${mappedOnly})`);
  check(mappable === 718, `718 mapped AND coded (got ${mappable})`);
  check(mappable <= Math.min(coded, mappedOnly),
    'the mapped+coded set cannot exceed either parent set');

  // --- record-level parity against the source dataset ---
  let mismatches = 0;
  let firstMismatch = null;
  for (let i = 0; i < srcBodies.length; i++) {
    const a = srcBodies[i];
    const b = nad.localBodies[i];
    const same =
      a.name === b.name &&
      (a.nameNe ?? null) === (b.nameNe ?? null) &&
      a.type === b.type &&
      a.district === b.district &&
      a.province === b.province &&
      (a.cbsCode ?? null) === (b.cbsCode ?? null) &&
      (a.wards ?? null) === (b.wards ?? null) &&
      (a.lat ?? null) === (b.lat ?? null) &&
      (a.lng ?? null) === (b.lng ?? null);
    if (!same) {
      mismatches++;
      if (!firstMismatch) firstMismatch = `#${i} ${a.name}`;
    }
  }
  check(mismatches === 0,
    `every local body matches the source (${mismatches} mismatches)`,
    firstMismatch);

  // --- lookups ---
  const bharatpur = nad.getLocalBodyByCbs(31304);
  check(bharatpur && bharatpur.name === 'Bharatpur',
    'getLocalBodyByCbs(31304) === Bharatpur');
  check(bharatpur && bharatpur.cbsCodeVerified === true,
    'Bharatpur is doubly-attested');
  // Pokhara's code is single-source: reachable, but not by the strict lookup.
  const pokhara = nad.getLocalBodyByCbs(40504);
  check(pokhara && pokhara.name === 'Pokhara',
    'getLocalBodyByCbs(40504) resolves the single-source tier');
  check(nad.getLocalBodyByCbsVerified(40504) === undefined,
    'the strict lookup correctly refuses a single-source code');
  check(nad.getLocalBodyByCbs(99999) === undefined,
    'an unknown code returns undefined');

  check(nad.getProvinceById('bagmati').name === 'Bagmati',
    'getProvinceById("bagmati")');
  check(nad.getProvinceById('NP-P3').id === 'bagmati',
    'getProvinceById accepts an ISO code');
  check(nad.getProvinceByCbs(3).name === 'Bagmati',
    'getProvinceByCbs(3) === Bagmati');
  check(nad.getDistrictByCbs(306).name === 'Kathmandu',
    'getDistrictByCbs(306) === Kathmandu');
  check(nad.getDistrictByName('chitwan').headquarter === 'Bharatpur',
    'district headquarter is carried through');

  // --- bilingual search, both directions ---
  const en = nad.search('Bharatpur').localBodies;
  const ne = nad.search(bharatpur.nameNe).localBodies;
  check(ne.length > 0 && ne.length === en.length,
    `Devanagari search matches English (${ne.length} vs ${en.length})`);
  check(nad.search(bharatpur.nameNe.slice(0, 3)).localBodies.length > 0,
    'a partial Devanagari fragment matches');
  check(nad.search('चितवन').districts.length === 1,
    'Devanagari district search works');
  check(nad.search('जकजकजक').isEmpty === true,
    'a nonsense query returns nothing rather than everything');

  // --- duplicate-name disambiguation ---
  const sunkoshi = nad.getLocalBodiesByName('Sunkoshi', 'Okhaldhunga');
  check(sunkoshi.length === 1 && sunkoshi[0].district === 'Okhaldhunga',
    'getLocalBodiesByName disambiguates by district');
  check(nad.getLocalBodiesByName('Sunkoshi', 'Atlantis').length === 0,
    'an unknown district returns an empty list');
  check(nad.getLocalBodyByFullPath('Bharatpur, Chitwan, Bagmati').name === 'Bharatpur',
    'getLocalBodyByFullPath resolves an unambiguous path');
  check(nad.getLocalBodyByFullPath('Sunkoshi') === null,
    'an ambiguous full path returns null rather than guessing');

  // --- the code-keyed join is lossless ---
  const byCode = new Map(nad.getLocalBodiesWithCode().map((b) => [b.cbsCode, b]));
  check(byCode.size === 744, `the code-keyed join is lossless (${byCode.size})`);

  // --- honesty guarantees survive the port ---
  check(nad.getUncodedLocalBodies().every((b) => b.cbsCode == null),
    'uncoded palikas carry a null code in the binding');
  check(nad.getUncodedLocalBodies().every((b) => b.cbsCodeConfidence === 'unverified'),
    'uncoded palikas are labelled unverified');
  const noNameNe = nad.localBodies.filter((b) => b.nameNe == null);
  check(noNameNe.length === 22,
    `22 palikas have no Devanagari name (got ${noNameNe.length})`);
  check(noNameNe.every((b) => b.nameNeVerified === false),
    'a palika without a Devanagari name is not marked verified');

  // --- province ward reconciliation ---
  const lumbini = nad.getProvinceStats('lumbini');
  check(lumbini && lumbini.wardsReconcile === true,
    'Lumbini reconciles exactly (109 units, 983 wards)');
  const gandaki = nad.getProvinceStats('gandaki');
  check(gandaki && gandaki.unreconciledWards === 14,
    `Gandaki reports its 14-ward gap (got ${gandaki && gandaki.unreconciledWards})`);
}

// ---------------------------------------------------------------------------
// 2. CSV
// ---------------------------------------------------------------------------

section('2. CSV (bindings/csv/)');

/** Minimal RFC 4180 parser, so the check does not depend on a CSV library. */
function parseCsv(text) {
  const rows = [];
  let row = [];
  let field = '';
  let inQuotes = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (inQuotes) {
      if (c === '"') {
        if (text[i + 1] === '"') {
          field += '"';
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field += c;
      }
      continue;
    }
    if (c === '"') {
      inQuotes = true;
    } else if (c === ',') {
      row.push(field);
      field = '';
    } else if (c === '\n') {
      row.push(field);
      rows.push(row);
      row = [];
      field = '';
    } else if (c !== '\r') {
      field += c;
    }
  }
  if (field !== '' || row.length > 0) {
    row.push(field);
    rows.push(row);
  }
  return rows.filter((r) => r.length > 1 || (r.length === 1 && r[0] !== ''));
}

for (const [file, expectedRows, expectedCols] of [
  ['provinces.csv', srcProvinces.length, 12],
  ['districts.csv', srcDistricts.length, 11],
  ['local_bodies.csv', srcBodies.length, 19],
]) {
  const text = fs.readFileSync(path.join(BINDINGS, 'csv', file), 'utf8');
  const rows = parseCsv(text);
  const header = rows[0];
  const body = rows.slice(1);
  check(body.length === expectedRows,
    `${file}: ${body.length} data rows === ${expectedRows}`);
  check(header.length === expectedCols,
    `${file}: ${header.length} columns === ${expectedCols}`);
  check(!text.includes('\r'),
    `${file}: LF line endings only`);
  check(!text.charCodeAt(0) === 0xfeff || text.charCodeAt(0) !== 0xfeff,
    `${file}: no UTF-8 BOM`);
}

// CSV quoting. The current dataset happens to contain no field with a comma,
// so the generator's quoting path is exercised here against a synthetic value
// rather than left untested until a future dataset trips over it.
{
  const quoted = '"Parasi (Nawalparasi West)","a,b","""quoted""",trailing\n';
  const rows = parseCsv(quoted);
  check(rows.length === 1, 'synthetic quoted row parses as one row');
  check(rows[0][0] === 'Parasi (Nawalparasi West)', 'parenthesised field survives');
  check(rows[0][1] === 'a,b', 'embedded comma survives quoting');
  check(rows[0][2] === '"quoted"', 'escaped quotes unescape to one pair');
  check(rows[0][3] === 'trailing', 'field after a quoted field is intact');

  // And confirm the assumption behind that test still holds for the real data.
  const text = fs.readFileSync(path.join(BINDINGS, 'csv', 'districts.csv'), 'utf8');
  const rows2 = parseCsv(text);
  const header = rows2[0];
  const nameIdx = header.indexOf('name');
  const withParens = rows2.slice(1).filter((r) => r[nameIdx].includes('('));
  check(withParens.length === 1,
    `exactly one district name carries parentheses (got ${withParens.length})`);
  if (withParens.length === 1) {
    check(withParens[0][nameIdx] === 'Parasi (Nawalparasi West)',
      `the real district name round-trips exactly (got "${withParens[0][nameIdx]}")`);
  }
}

// The CSV and the JSON must describe the same 753 rows.
{
  const text = fs.readFileSync(path.join(BINDINGS, 'csv', 'local_bodies.csv'), 'utf8');
  const rows = parseCsv(text);
  const header = rows[0];
  const iName = header.indexOf('name');
  const iDist = header.indexOf('district');
  const iCode = header.indexOf('cbsCode');
  const pairs = rows.slice(1).map((r) => `${r[iDist]}/${r[iName]}:${r[iCode]}`);
  const uniq = new Set(pairs);
  check(uniq.size === pairs.length,
    'CSV rows are unique by district+name+code (a stray comma would break this)');
  const withCode = rows.slice(1).filter((r) => r[iCode] !== '').length;
  check(withCode === 744, `CSV carries 744 codes (got ${withCode})`);
}

// ---------------------------------------------------------------------------
// 3. GeoJSON
// ---------------------------------------------------------------------------

section('3. GeoJSON (bindings/geojson/)');

for (const [file, expected] of [
  ['local-bodies.centroids.geojson', 726],
  ['districts.centroids.geojson', 77],
  ['provinces.centroids.geojson', 7],
]) {
  const fc = JSON.parse(fs.readFileSync(path.join(BINDINGS, 'geojson', file), 'utf8'));
  check(fc.type === 'FeatureCollection', `${file}: type is FeatureCollection`);
  // RFC 7946 fixes the CRS to WGS84 and deprecates the crs member.
  check(fc.crs === undefined, `${file}: no deprecated "crs" member`);
  check(Array.isArray(fc.features), `${file}: has a features array`);
  check(fc.features.length === expected,
    `${file}: ${fc.features.length} features === ${expected}`);
  let bad = 0;
  let outOfRange = 0;
  for (const f of fc.features) {
    if (f.type !== 'Feature' || !f.geometry || f.geometry.type !== 'Point') bad++;
    const c = f.geometry && f.geometry.coordinates;
    if (!Array.isArray(c) || c.length !== 2) { bad++; continue; }
    // RFC 7946 order is [longitude, latitude].
    if (c[0] < 80 || c[0] > 89 || c[1] < 26 || c[1] > 31) outOfRange++;
  }
  check(bad === 0, `${file}: every feature is a valid Point (${bad} bad)`);
  check(outOfRange === 0,
    `${file}: every coordinate is inside Nepal's bounding box (${outOfRange} outside)`);
  if (fc.features.length > 0) {
    const first = fc.features[0].geometry.coordinates;
    check(first[0] > first[1],
      `${file}: coordinates are [lng, lat] per RFC 7946`,
      `got [${first[0]}, ${first[1]}]`);
  }
}

// Derived centroids must be labelled as derived.
{
  const fc = JSON.parse(
    fs.readFileSync(path.join(BINDINGS, 'geojson', 'districts.centroids.geojson'), 'utf8'),
  );
  check(fc.features.every((f) => typeof f.properties.centroidMethod === 'string'),
    'derived district centroids declare their method');
  check(fc.features.every((f) => f.properties.centroidMethod.includes('approximate')),
    'derived district centroids are marked approximate');
}

// ---------------------------------------------------------------------------
// 4. Package manifests and attribution
// ---------------------------------------------------------------------------

section('4. Package manifests and attribution');

for (const dir of ['javascript', 'python']) {
  for (const f of ['LICENSE', 'NOTICE', 'README.md']) {
    const p = path.join(BINDINGS, dir, f);
    check(fs.existsSync(p), `${dir}/${f} exists`);
  }
  // CC-BY-4.0 requires visible attribution in the distributed artifact, so the
  // NOTICE must actually name the sources, not just exist.
  const notice = fs.readFileSync(path.join(BINDINGS, dir, 'NOTICE'), 'utf8');
  check(notice.includes('creativecommons.org/licenses/by/4.0'),
    `${dir}/NOTICE links the CC-BY-4.0 licence`);
  check(notice.includes('open-admin-data'),
    `${dir}/NOTICE credits open-admin-data`);
  check(notice.includes('Central Bureau of Statistics'),
    `${dir}/NOTICE credits the CBS harvest`);
  check(notice.includes('Not affiliated with the Government of Nepal'),
    `${dir}/NOTICE carries the non-affiliation note`);
}

{
  const pkg = JSON.parse(
    fs.readFileSync(path.join(BINDINGS, 'javascript', 'package.json'), 'utf8'),
  );
  check(pkg.name === 'nepal-admin-data', `npm package is nepal-admin-data`);
  check(pkg.main === 'index.js' && pkg.types === 'index.d.ts',
    'npm package declares main and types');
  check(pkg.dependencies === undefined || Object.keys(pkg.dependencies).length === 0,
    'npm package has zero dependencies');
  const version = JSON.parse(
    fs.readFileSync(path.join(ROOT, 'data', 'nepal_local_levels.json'), 'utf8'),
  ) && require(path.join(BINDINGS, 'meta.json')).version;
  const pubspec = fs.readFileSync(path.join(ROOT, 'pubspec.yaml'), 'utf8');
  const dartVersion = /^\s*version:\s*(\S+)/m.exec(pubspec)[1];
  check(pkg.version === dartVersion,
    `npm version ${pkg.version} matches pubspec ${dartVersion}`);
  check(require(path.join(BINDINGS, 'meta.json')).version === dartVersion,
    'bindings/meta.json version matches pubspec');
}

{
  const pyproject = fs.readFileSync(
    path.join(BINDINGS, 'python', 'pyproject.toml'), 'utf8');
  check(pyproject.includes('name = "nepal-admin-data"'),
    'PyPI project is nepal-admin-data');
  check(pyproject.includes('dependencies = []'),
    'Python package declares no dependencies');
  check(/requires-python\s*=\s*">=3\.8"/.test(pyproject),
    'Python package supports 3.8+');
}

// The shipped .d.ts must actually describe the runtime that exists. Without a
// TypeScript compiler here, this checks structural agreement instead: every
// exported function name in index.js appears in the declarations.
{
  const js = fs.readFileSync(path.join(BINDINGS, 'javascript', 'index.js'), 'utf8');
  const dts = fs.readFileSync(path.join(BINDINGS, 'javascript', 'index.d.ts'), 'utf8');
  const exportBlock = /module\.exports = \{([\s\S]*?)\};/.exec(js);
  check(!!exportBlock, 'index.js has a module.exports block');
  if (exportBlock) {
    const names = exportBlock[1]
      .split(',')
      .map((s) => s.trim().split(':')[0].trim())
      .filter((n) => /^[A-Za-z_$][\w$]*$/.test(n));
    const missing = names.filter((n) => !new RegExp(`\\b${n}\\b`).test(dts));
    check(missing.length === 0,
      `every runtime export is declared in index.d.ts (missing: ${missing.join(', ')})`);
  }
  check(dts.includes('export function'), 'index.d.ts declares functions');
}

// ---------------------------------------------------------------------------
// 5. Line endings and determinism markers
// ---------------------------------------------------------------------------

section('5. Repository hygiene');

for (const f of [
  'javascript/index.js',
  'javascript/index.d.ts',
  'javascript/data.json',
  'python/nepal_admin/__init__.py',
  'python/nepal_admin/data.json',
  'csv/local_bodies.csv',
  'geojson/local-bodies.centroids.geojson',
]) {
  const buf = fs.readFileSync(path.join(BINDINGS, f));
  check(buf[0] !== 0xef || buf[1] !== 0xbb || buf[2] !== 0xbf, `${f}: no UTF-8 BOM`);
  check(!buf.includes(0x0d), `${f}: LF line endings only`);
}

{
  // The python runtime must have its version substituted, not the placeholder.
  const py = fs.readFileSync(
    path.join(BINDINGS, 'python', 'nepal_admin', '__init__.py'), 'utf8');
  check(!py.includes('VERSION_PLACEHOLDER'), 'python version placeholder replaced');
  check(!py.includes('DATA_AS_OF'), 'python dataAsOf placeholder replaced');
  const js = fs.readFileSync(path.join(BINDINGS, 'javascript', 'index.js'), 'utf8');
  check(!js.includes('DATA_AS_OF'), 'javascript dataAsOf placeholder replaced');
}

// ---------------------------------------------------------------------------

console.log('\n' + '='.repeat(70));
if (failures === 0) {
  console.log(`BINDINGS OK: ${checks} checks passed, 0 failures`);
  console.log('='.repeat(70));
  process.exit(0);
} else {
  console.error(`BINDINGS FAILED: ${failures} of ${checks} checks failed`);
  process.exit(1);
}