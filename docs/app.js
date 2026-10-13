// nepal_admin_api website JavaScript

// Theme toggle with localStorage persistence
function initTheme() {
  const toggle = document.getElementById('theme-toggle');
  if (!toggle) return;

  const savedTheme = localStorage.getItem('theme');
  const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
  const isDark = savedTheme ? savedTheme === 'dark' : prefersDark;

  document.documentElement.classList.toggle('dark', isDark);
  if (savedTheme) {
    document.documentElement.setAttribute('data-theme', savedTheme);
  }

  toggle.addEventListener('click', () => {
    const newDark = !document.documentElement.classList.contains('dark');
    document.documentElement.classList.toggle('dark', newDark);
    localStorage.setItem('theme', newDark ? 'dark' : 'light');
    document.documentElement.setAttribute('data-theme', newDark ? 'dark' : 'light');
  });
}

// Toast notification
function showToast(message) {
  const existing = document.querySelector('.toast');
  if (existing) existing.remove();

  const toast = document.createElement('div');
  toast.className = 'toast';
  toast.textContent = message;
  document.body.appendChild(toast);

  requestAnimationFrame(() => toast.classList.add('show'));

  setTimeout(() => {
    toast.classList.remove('show');
    setTimeout(() => toast.remove(), 200);
  }, 2000);
}

// Copy code blocks
document.addEventListener('click', (e) => {
  if (e.target.matches('.copy-btn')) {
    const codeBlock = e.target.closest('.code-block');
    const code = codeBlock.querySelector('code').textContent;

    navigator.clipboard.writeText(code).then(() => {
      const originalText = e.target.textContent;
      e.target.textContent = 'Copied!';
      e.target.style.background = 'var(--color-success)';
      e.target.style.color = 'white';
      e.target.style.borderColor = 'var(--color-success)';

      setTimeout(() => {
        e.target.textContent = originalText;
        e.target.style.background = '';
        e.target.style.color = '';
        e.target.style.borderColor = '';
      }, 1500);

      showToast('Code copied to clipboard');
    }).catch(() => {
      showToast('Failed to copy');
    });
  }
});

// Active nav highlighting
const currentPage = window.location.pathname.split('/').pop() || 'index.html';
document.querySelectorAll('.nav-link').forEach(link => {
  if (link.getAttribute('href') === currentPage) {
    link.classList.add('active');
  }
});

// Smooth scroll for anchor links
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
  anchor.addEventListener('click', function(e) {
    const target = document.querySelector(this.getAttribute('href'));
    if (target) {
      e.preventDefault();
      target.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  });
});

// Explorer functionality (if on explorer page)
if (document.querySelector('.explorer-table')) {
  initExplorer();
}

function initExplorer() {
  const searchInput = document.getElementById('search-input');
  const provinceFilter = document.getElementById('province-filter');
  const districtFilter = document.getElementById('district-filter');
  const typeFilter = document.getElementById('type-filter');
  const tableBody = document.querySelector('.explorer-table tbody');
  const statsEl = document.querySelector('.explorer-stats');
  const paginationEl = document.querySelector('.pagination');

  let allData = [];
  let filteredData = [];
  let currentPage = 1;
  const pageSize = 25;

  // Load data
  fetch('data.json')
    .then(res => res.json())
    .then(data => {
      allData = data;
      filteredData = [...data];
      window.__explorerByCbs = (cbs) =>
        allData.find(d => String(d.cbsCode) === String(cbs)) || null;
      populateFilters();
      render();
    })
    .catch(err => {
      console.error('Failed to load data:', err);
      tableBody.innerHTML = '<tr><td colspan="8" style="text-align:center; padding: 48px; color: var(--color-text-muted);">Failed to load data. Please ensure data.json exists.</td></tr>';
    });

  function populateFilters() {
    const provinces = [...new Set(allData.map(d => d.province))].sort();
    const districts = [...new Set(allData.map(d => d.district))].sort();
    const types = [...new Set(allData.map(d => d.type))].sort();

    provinceFilter.innerHTML = '<option value="">All Provinces</option>' +
      provinces.map(p => `<option value="${p}">${p}</option>`).join('');
    districtFilter.innerHTML = '<option value="">All Districts</option>' +
      districts.map(d => `<option value="${d}">${d}</option>`).join('');
    typeFilter.innerHTML = '<option value="">All Types</option>' +
      types.map(t => `<option value="${t}">${t}</option>`).join('');
  }

  function applyFilters() {
    const search = searchInput.value.toLowerCase().trim();
    const province = provinceFilter.value;
    const district = districtFilter.value;
    const type = typeFilter.value;

    filteredData = allData.filter(item => {
      const matchesSearch = !search ||
        item.name.toLowerCase().includes(search) ||
        item.district.toLowerCase().includes(search) ||
        item.province.toLowerCase().includes(search);
      const matchesProvince = !province || item.province === province;
      const matchesDistrict = !district || item.district === district;
      const matchesType = !type || item.type === type;
      return matchesSearch && matchesProvince && matchesDistrict && matchesType;
    });

    currentPage = 1;
    render();
  }

  function render() {
    const start = (currentPage - 1) * pageSize;
    const end = start + pageSize;
    const pageData = filteredData.slice(start, end);

    // Update stats
    const verified = filteredData.filter(d => d.cbsCode !== null).length;
    const mapped = filteredData.filter(d => d.lat != null && d.lng != null).length;
    statsEl.innerHTML = `
      <span>Total: <strong>${filteredData.length}</strong></span>
      <span>Verified CBS: <strong>${verified}</strong></span>
      <span>Unverified: <strong>${filteredData.length - verified}</strong></span>
      <span>Mapped: <strong>${mapped}</strong></span>
    `;
    syncMap(filteredData);

    // Render table
    if (pageData.length === 0) {
      tableBody.innerHTML = '<tr><td colspan="8" style="text-align:center; padding: 48px; color: var(--color-text-muted);">No matching records</td></tr>';
    } else {
      tableBody.innerHTML = pageData.map(item => `
        <tr data-cbs="${item.cbsCode ?? ''}" data-lat="${item.lat ?? ''}" data-lng="${item.lng ?? ''}" data-name="${escapeHtml(item.name)}" tabindex="0" title="${item.lat != null ? 'Click to locate on map' : 'No coordinates available'}">
          <td>${escapeHtml(item.name)}</td>
          <td><span class="type-badge type-${item.type.toLowerCase().replace('municipality', 'mun').replace('rural', 'rural').replace('metropolitan', 'metro').replace('sub-metropolitan', 'sub')}">${escapeHtml(item.type)}</span></td>
          <td>${escapeHtml(item.district)}</td>
          <td>${escapeHtml(item.province)}</td>
          <td>${item.cbsCode !== null ? `<code>${item.cbsCode}</code>` : '<span class="unverified">—</span>'}</td>
          <td>${item.cbsCodeVerified ? '<span class="verified">✓ Verified</span>' : '<span class="unverified">Unverified</span>'}</td>
          <td>${item.isoCode ? `<code>${item.isoCode}</code>` : '—'}</td>
          <td>${item.wards != null ? `${item.wards}` : '<span class="unverified">—</span>'}</td>
        </tr>
      `).join('');
      // Row → map: click a mapped row to fly to its marker.
      tableBody.querySelectorAll('tr[data-lat]').forEach(row => {
        if (!row.dataset.lat || !row.dataset.lng) return;
        const go = () => focusMarker(parseFloat(row.dataset.lat), parseFloat(row.dataset.lng), row.dataset.name);
        row.style.cursor = 'pointer';
        row.addEventListener('click', go);
        row.addEventListener('keydown', (e) => {
          if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); go(); }
        });
      });
    }

    // Render pagination
    const totalPages = Math.ceil(filteredData.length / pageSize);
    if (totalPages <= 1) {
      paginationEl.innerHTML = '';
      return;
    }

    let paginationHtml = '';
    if (currentPage > 1) {
      paginationHtml += `<button data-page="${currentPage - 1}">‹ Prev</button>`;
    }

    const maxVisible = 5;
    let startPage = Math.max(1, currentPage - Math.floor(maxVisible / 2));
    let endPage = Math.min(totalPages, startPage + maxVisible - 1);

    if (endPage - startPage + 1 < maxVisible) {
      startPage = Math.max(1, endPage - maxVisible + 1);
    }

    if (startPage > 1) {
      paginationHtml += `<button data-page="1">1</button>`;
      if (startPage > 2) paginationHtml += `<span class="ellipsis">…</span>`;
    }

    for (let i = startPage; i <= endPage; i++) {
      paginationHtml += `<button data-page="${i}" class="${i === currentPage ? 'active' : ''}">${i}</button>`;
    }

    if (endPage < totalPages) {
      if (endPage < totalPages - 1) paginationHtml += `<span class="ellipsis">…</span>`;
      paginationHtml += `<button data-page="${totalPages}">${totalPages}</button>`;
    }

    if (currentPage < totalPages) {
      paginationHtml += `<button data-page="${currentPage + 1}">Next ›</button>`;
    }

    paginationEl.innerHTML = paginationHtml;

    paginationEl.querySelectorAll('button[data-page]').forEach(btn => {
      btn.addEventListener('click', () => {
        currentPage = parseInt(btn.dataset.page, 10);
        render();
        window.scrollTo({ top: 0, behavior: 'smooth' });
      });
    });
  }

  function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  // Event listeners
  searchInput.addEventListener('input', debounce(applyFilters, 200));
  provinceFilter.addEventListener('change', applyFilters);
  districtFilter.addEventListener('change', applyFilters);
  typeFilter.addEventListener('change', applyFilters);
}

function debounce(fn, delay) {
  let timeoutId;
  return (...args) => {
    clearTimeout(timeoutId);
    timeoutId = setTimeout(() => fn.apply(null, args), delay);
  };
}

// ---- Centroid map (Leaflet + OSM Standard, no API key) ----
// Single tile factory so a future vector/PMTiles migration is surgical.
const MAP_TILES = {
  url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  maxZoom: 19,
  attribution: '© <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener">OpenStreetMap</a> contributors',
};
const TYPE_COLORS = {
  metropolitan: '#dc2626',
  'sub-metropolitan': '#ea580c',
  municipality: '#2563eb',
  ruralMunicipality: '#16a34a',
};
let _map = null;
let _cluster = null;
let _leafletReady = null;

function loadLeaflet() {
  if (_leafletReady) return _leafletReady;
  _leafletReady = new Promise((resolve, reject) => {
    if (window.L && window.L.markerClusterGroup) { resolve(); return; }
    const css = (href) => {
      if (document.querySelector(`link[href="${href}"]`)) return;
      const l = document.createElement('link');
      l.rel = 'stylesheet'; l.href = href;
      document.head.appendChild(l);
    };
    css('https://unpkg.com/leaflet@1.9.4/dist/leaflet.css');
    css('https://unpkg.com/leaflet.markercluster@1.5.3/dist/MarkerCluster.css');
    css('https://unpkg.com/leaflet.markercluster@1.5.3/dist/MarkerCluster.Default.css');
    const js = (src) => new Promise((res, rej) => {
      const s = document.createElement('script');
      s.src = src; s.defer = true;
      s.onload = res; s.onerror = rej;
      document.head.appendChild(s);
    });
    js('https://unpkg.com/leaflet@1.9.4/dist/leaflet.js')
      .then(() => js('https://unpkg.com/leaflet.markercluster@1.5.3/dist/leaflet.markercluster.js'))
      .then(resolve)
      .catch(reject);
  });
  return _leafletReady;
}

function createTileLayer() {
  return window.L.tileLayer(MAP_TILES.url, {
    maxZoom: MAP_TILES.maxZoom,
    attribution: MAP_TILES.attribution,
  });
}

function ensureMap() {
  const el = document.getElementById('map');
  if (!el || _map) return Promise.resolve(_map);
  return loadLeaflet().then(() => {
    const status = document.getElementById('map-status');
    _map = window.L.map('map', {
      preferCanvas: true,
      scrollWheelZoom: false,
      tap: true,
    }).setView([28.39, 84.12], 7);
    _map.on('focus', () => _map.scrollWheelZoom.enable());
    _map.on('blur', () => _map.scrollWheelZoom.disable());
    createTileLayer().addTo(_map);
    _cluster = window.L.markerClusterGroup({
      chunkedLoading: true,
      removeOutsideVisibleBounds: true,
      showCoverageOnHover: false,
      maxClusterRadius: 48,
    });
    _map.addLayer(_cluster);
    if (status) status.textContent = '';
    // Deep link: explorer.html?cbs=31304
    const cbs = new URLSearchParams(window.location.search).get('cbs');
    if (cbs && window.__explorerByCbs) {
      const hit = window.__explorerByCbs(cbs);
      if (hit && hit.lat != null) focusMarker(hit.lat, hit.lng, hit.name);
    }
    return _map;
  }).catch((err) => {
    console.error('Map failed to load:', err);
    const status = document.getElementById('map-status');
    if (status) status.textContent = 'Map unavailable offline — table still works.';
  });
}

function markerColor(item) {
  return TYPE_COLORS[item.type] || '#64748b';
}

function syncMap(items) {
  if (!document.getElementById('map')) return;
  ensureMap().then(() => {
    if (!_map || !_cluster) return;
    _cluster.clearLayers();
    const pts = items.filter(d => d.lat != null && d.lng != null);
    const markers = pts.map((item) => {
      const color = markerColor(item);
      const m = window.L.circleMarker([item.lat, item.lng], {
        radius: item.type === 'metropolitan' ? 9 : item.type === 'sub-metropolitan' ? 8 : 6,
        color,
        weight: 2,
        opacity: 1,
        fillColor: color,
        fillOpacity: item.cbsCodeVerified ? 0.85 : 0.2,
      });
      const cbs = item.cbsCode != null ? `<code>${item.cbsCode}</code>` : '—';
      const wards = item.wards != null ? `${item.wards} wards` : 'wards n/a';
      m.bindPopup(
        `<strong>${escapeHtmlAttr(item.name)}</strong>` +
        `${escapeHtmlAttr(item.district)}, ${escapeHtmlAttr(item.province)}<br>` +
        `CBS: ${cbs} ${item.cbsCodeVerified ? '✓' : '(unverified)'} · ${wards}<br>` +
        `<span style="color:#64748b;font-size:12px">${item.lat.toFixed(3)}, ${item.lng.toFixed(3)} · ${escapeHtmlAttr(item.geoSource || 'compiled')}</span>`
      );
      return m;
    });
    _cluster.addLayers(markers);
    const status = document.getElementById('map-status');
    if (status) {
      const total = items.length;
      status.textContent = `${pts.length} of ${total} shown on map` +
        (total - pts.length > 0 ? ` (${total - pts.length} without coordinates — table only)` : '');
    }
    if (pts.length > 0 && !_map.__fitted) {
      _map.__fitted = true;
      _map.fitBounds(_cluster.getBounds().pad(0.15));
    }
  });
}

function focusMarker(lat, lng, name) {
  ensureMap().then(() => {
    if (!_map) return;
    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    _map.flyTo([lat, lng], Math.max(_map.getZoom(), 10), { duration: reduced ? 0 : 0.8 });
    window.L.popup()
      .setLatLng([lat, lng])
      .setContent(`<strong>${escapeHtmlAttr(name || 'Selected')}</strong>`)
      .openOn(_map);
    document.getElementById('map')?.scrollIntoView({ behavior: reduced ? 'auto' : 'smooth', block: 'nearest' });
  });
}

function escapeHtmlAttr(text) {
  return String(text ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

// Initialize theme on load
document.addEventListener('DOMContentLoaded', initTheme);

// API docs nav highlighting
if (document.querySelector('.api-nav')) {
  const sections = document.querySelectorAll('.api-section[id]');
  const navLinks = document.querySelectorAll('.api-nav a[href^="#"]');

  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        navLinks.forEach(link => {
          link.classList.toggle('active', link.getAttribute('href') === '#' + entry.target.id);
        });
      }
    });
  }, { rootMargin: '-100px 0px -66%' });

  sections.forEach(section => observer.observe(section));
}