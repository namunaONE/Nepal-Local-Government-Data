'use strict';

// nepal-admin-data — offline administrative divisions of Nepal.
// Data as of 2026-10-13. Generated from data/nepal_local_levels.json by
// tool/generate_bindings.dart; do not edit by hand.

const raw = require('./data.json');

const meta = raw.meta;
const provinces = raw.provinces;
const districts = raw.districts;
const localBodies = raw.localBodies;

// ---------------------------------------------------------------------------
// Indexes, built once at load. A code-keyed join is the single most common
// thing callers do with this data, so the map is precomputed rather than
// rebuilt per query.
// ---------------------------------------------------------------------------

const provinceById = new Map();
const provinceByIso = new Map();
const districtByName = new Map();
const districtByCbs = new Map();
const localBodyByCbs = new Map();

for (const p of provinces) {
  provinceById.set(p.id, p);
  if (p.isoCode) provinceByIso.set(p.isoCode.toUpperCase(), p);
}
for (const d of districts) {
  districtByName.set(d.name.toLowerCase(), d);
  if (d.cbsCode != null) districtByCbs.set(d.cbsCode, d);
}
for (const b of localBodies) {
  if (b.cbsCode != null) localBodyByCbs.set(b.cbsCode, b);
}

// ---------------------------------------------------------------------------
// Lookups. Names are matched case-insensitively; ISO codes in either case.
// ---------------------------------------------------------------------------

function getProvinceById(id) {
  if (typeof id !== 'string') return undefined;
  const lower = id.toLowerCase();
  const upper = id.toUpperCase();
  return provinceById.get(lower) || provinceByIso.get(upper) || undefined;
}

const getProvinceByIso = (iso) =>
  typeof iso === 'string' ? provinceByIso.get(iso.toUpperCase()) : undefined;

const getProvinceByCbs = (code) => provinces.find((p) => p.cbsCode === code);

const getAllProvinces = () => provinces.slice();
const getAllDistricts = () => districts.slice();
const getAllLocalBodies = () => localBodies.slice();

const getDistrictByName = (name) =>
  typeof name === 'string' ? districtByName.get(name.trim().toLowerCase()) : undefined;

const getDistrictByCbs = (code) => districtByCbs.get(code);

const getLocalBodiesByDistrict = (name) => {
  const d = getDistrictByName(name);
  if (!d) return [];
  // Districts are flat records carrying localBodyCount, not a nested array, so
  // membership is tested against the flat list.
  return localBodies.filter((b) => b.district === d.name);
};

const getLocalBodiesByProvince = (provinceId) => {
  const p = getProvinceById(provinceId);
  if (!p) return [];
  return localBodies.filter((b) => b.province === p.name);
};

const getLocalBodiesByType = (type) => localBodies.filter((b) => b.type === type);

// Duplicate names are common, so scoping to a district is the precise way in.
const getLocalBodiesByName = (name, districtName) => {
  const d = getDistrictByName(districtName);
  if (!d || typeof name !== 'string') return [];
  const lower = name.toLowerCase();
  return localBodies.filter(
    (b) => b.district === d.name && b.name.toLowerCase() === lower,
  );
};

/**
 * Resolve a 'Name, District, Province' path. Order-insensitive and tolerant of
 * a partial path. Returns null when the path matches nothing or more than one
 * body - an ambiguous answer is never guessed.
 */
function getLocalBodyByFullPath(path) {
  if (typeof path !== 'string') return null;
  const parts = path.split(',').map((s) => s.trim().toLowerCase()).filter(Boolean);
  if (parts.length === 0) return null;
  const matches = localBodies.filter((b) => {
    const hay = new Set([b.name, b.district, b.province].map((s) => String(s).toLowerCase()));
    return parts.every((p) => hay.has(p));
  });
  return matches.length === 1 ? matches[0] : null;
}

// Any confidence tier. Resolves 744 of 753.
const getLocalBodyByCbs = (code) => localBodyByCbs.get(code);

// Strictly the doubly-attested tier.
const getLocalBodyByCbsVerified = (code) => {
  const b = localBodyByCbs.get(code);
  return b && b.cbsCodeVerified ? b : undefined;
};

const getLocalBodiesWithCode = () => localBodies.filter((b) => b.cbsCode != null);
const getVerifiedLocalBodies = () => localBodies.filter((b) => b.cbsCodeVerified === true);
const getSingleSourceLocalBodies = () => localBodies.filter((b) => b.cbsCodeConfidence === 'singleSource');
const getUncodedLocalBodies = () => localBodies.filter((b) => b.cbsCode == null);

// ---------------------------------------------------------------------------
// Search. Matches BOTH scripts in either direction: search('भरतपुर') and
// search('Bharatpur') return the same palika.
// ---------------------------------------------------------------------------

function search(query) {
  const term = typeof query === 'string' ? query.trim().toLowerCase() : '';
  const empty = { provinces: [], districts: [], localBodies: [], isEmpty: true, length: 0 };
  if (term === '') return empty;
  const hit = (s) => typeof s === 'string' && s.toLowerCase().includes(term);
  const foundProvinces = provinces.filter((p) => hit(p.name) || hit(p.nameNe) || hit(p.isoCode));
  const foundDistricts = districts.filter((d) => hit(d.name) || hit(d.nameNe));
  const foundBodies = localBodies.filter(
    (b) => hit(b.name) || hit(b.nameNe) ||
      hit(`${b.name}, ${b.district}, ${b.province}`)
  );
  return {
    provinces: foundProvinces,
    districts: foundDistricts,
    localBodies: foundBodies,
    get isEmpty() {
      return foundProvinces.length + foundDistricts.length + foundBodies.length === 0;
    },
    get length() {
      return foundProvinces.length + foundDistricts.length + foundBodies.length;
    },
  };
}

// ---------------------------------------------------------------------------
// Computed totals. Note the two ward figures: `wards` is the declared
// national total, `verifiedWards` is what the per-palika rows substantiate.
// They differ because 8 palikas carry no verified ward count.
// ---------------------------------------------------------------------------

function getNationalStats() {
  const count = (t) => localBodies.filter((b) => b.type === t).length;
  const verifiedWards = localBodies.reduce((s, b) => s + (b.wards || 0), 0);
  const wardGaps = localBodies.filter((b) => b.wards == null).length;
  const declaredWards = provinces.reduce((s, p) => s + p.wards, 0);
  return {
    provinces: provinces.length,
    districts: districts.length,
    metro: count('metropolitan'),
    subMetro: count('subMetropolitan'),
    municipalities: count('municipality'),
    ruralMunicipalities: count('ruralMunicipality'),
    total: localBodies.length,
    wards: declaredWards,
    verifiedWards,
    wardGaps,
    unreconciledWards: declaredWards - verifiedWards,
  };
}

/** Per-province ward reconciliation, mirroring the Dart API. */
function getProvinceStats(provinceId) {
  const p = getProvinceById(provinceId);
  if (!p) return null;
  const bodies = getLocalBodiesByProvince(p.id);
  const verifiedWards = bodies.reduce((s, b) => s + (b.wards || 0), 0);
  return {
    ...p,
    verifiedWards,
    unreconciledWards: p.wards - verifiedWards,
    wardsReconcile: p.wards === verifiedWards,
  };
}

/** The joinable subset: has a code AND a coordinate. */
const getMappableLocalBodies = () =>
  localBodies.filter((b) => b.cbsCode != null && b.lat != null && b.lng != null);

module.exports = {
  meta,
  provinces,
  districts,
  localBodies,
  provinceById,
  districtByName,
  localBodyByCbs,
  getAllProvinces,
  getAllDistricts,
  getAllLocalBodies,
  getProvinceById,
  getProvinceByIso,
  getProvinceByCbs,
  getDistrictByName,
  getDistrictByCbs,
  getLocalBodiesByDistrict,
  getLocalBodiesByProvince,
  getLocalBodiesByType,
  getLocalBodiesByName,
  getLocalBodyByFullPath,
  getLocalBodyByCbs,
  getLocalBodyByCbsVerified,
  getLocalBodiesWithCode,
  getVerifiedLocalBodies,
  getSingleSourceLocalBodies,
  getUncodedLocalBodies,
  getMappableLocalBodies,
  getNationalStats,
  getProvinceStats,
  search,
};
