// docs/smoke.cjs — explorer smoke test (no browser, no npm deps).
//
// Loads the REAL docs/app.js in Node with minimal browser stubs and runs
// the full explorer flow: fetch → filters → stats → table → pagination.
// Catches ReferenceError/scope bugs that `node --check` (syntax-only)
// cannot catch — e.g. module-scope callers using initExplorer-scoped
// helpers (the `escapeHtml is not defined` outage).
//
// Usage (from repo root): node docs/smoke.cjs
// Exit 0 = pass, 1 = fail. Runs in CI (see .github/workflows/dart.yml).
const fs = require('fs');
const vm = require('vm');
const path = require('path');

const ROOT = __dirname;
const data = JSON.parse(fs.readFileSync(path.join(ROOT, 'data.json'), 'utf8'));
const appSrc = fs.readFileSync(path.join(ROOT, 'app.js'), 'utf8');

function makeEl() {
  const el = {
    children: [],
    dataset: {},
    style: {},
    _text: '',
    _html: '',
    classList: {
      _s: new Set(),
      toggle(c, force) {
        if (force === undefined) {
          if (this._s.has(c)) this._s.delete(c);
          else this._s.add(c);
        } else if (force) this._s.add(c);
        else this._s.delete(c);
      },
      add(c) { this._s.add(c); },
      remove(c) { this._s.delete(c); },
      contains(c) { return this._s.has(c); },
    },
    set textContent(v) {
      this._text = String(v);
      this._html = String(v)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;')
        .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    },
    get textContent() { return this._text; },
    set innerHTML(v) { this._html = String(v); },
    get innerHTML() { return this._html; },
    appendChild(c) { this.children.push(c); return c; },
    addEventListener() {},
    querySelectorAll() { return []; },
    querySelector() { return null; },
    setAttribute() {},
    getAttribute() { return null; },
    scrollIntoView() {},
    blur() {},
  };
  return el;
}

const elements = {
  'search-input': makeEl(),
  'province-filter': makeEl(),
  'district-filter': makeEl(),
  'type-filter': makeEl(),
  'map-status': makeEl(),
  'theme-toggle': null,
  'nav-menu': null,
  'retry-load': null,
};
elements['search-input'].value = '';
elements['province-filter'].value = '';
elements['district-filter'].value = '';
elements['type-filter'].value = '';
const tableBody = makeEl();
const statsEl = makeEl();
const paginationEl = makeEl();

const sandbox = {
  console,
  document: {
    querySelector(sel) {
      if (sel === '.explorer-table') return makeEl();
      if (sel === '.explorer-table tbody') return tableBody;
      if (sel === '.explorer-stats') return statsEl;
      if (sel === '.pagination') return paginationEl;
      if (sel === '.header') return null;
      if (sel === '.toast') return null;
      if (sel === '#map') return null; // map short-circuits (no Leaflet here)
      if (sel === '.nav-toggle') return null;
      if (sel === '#nav-menu') return null;
      return null;
    },
    querySelectorAll(sel) {
      if (sel === '.nav-link') return [];
      if (sel === 'a[href^="#"]') return [];
      if (sel === 'img[data-logo-light]') return [];
      return [];
    },
    getElementById(id) { return elements[id] || null; },
    createElement() { return makeEl(); },
    addEventListener() {},
    head: makeEl(),
    body: makeEl(),
    documentElement: { classList: makeEl().classList, setAttribute() {} },
  },
  window: {
    location: { search: '', pathname: '/explorer.html' },
    matchMedia: () => ({ matches: false }),
    scrollTo() {},
    addEventListener() {},
  },
  localStorage: {
    _s: {},
    getItem(k) { return this._s[k] ?? null; },
    setItem(k, v) { this._s[k] = v; },
  },
  fetch: () => Promise.resolve({ ok: true, json: () => Promise.resolve(data) }),
  requestAnimationFrame: (fn) => { fn(); return 0; },
  IntersectionObserver: function () { this.observe = () => {}; },
  URLSearchParams,
};
sandbox.globalThis = sandbox;
vm.createContext(sandbox);

(async () => {
  vm.runInContext(appSrc, sandbox, { filename: 'app.js' });
  await new Promise((r) => setTimeout(r, 100));
  const assert = require('assert');
  assert.ok(
    statsEl.innerHTML.includes(`Total: <strong>${data.length}</strong>`),
    'stats rendered, got: ' + statsEl.innerHTML.slice(0, 120));
  assert.ok(
    tableBody.innerHTML.includes('type-badge'),
    'rows rendered with badges');
  assert.ok(
    !tableBody.innerHTML.includes('Failed to load') &&
      !tableBody.innerHTML.includes('failed to render'),
    'no error UI, got: ' + tableBody.innerHTML.slice(0, 200));
  assert.ok(
    tableBody.innerHTML.includes('type-rural'),
    'rural chips use the type-rural class');
  const rows = (tableBody.innerHTML.match(/<tr/g) || []).length;
  console.log(`SMOKE OK: ${data.length} records, ${rows} rows rendered, no errors`);
})().catch((err) => {
  console.error('SMOKE FAILED:', err && err.message ? err.message : err);
  process.exit(1);
});
