// nepal_admin_api website JavaScript

// Theme toggle with localStorage persistence
function initTheme() {
  const toggle = document.getElementById('theme-toggle');
  if (!toggle) return;

  const savedTheme = localStorage.getItem('theme');
  const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
  const isDark = savedTheme ? savedTheme === 'dark' : prefersDark;

  document.documentElement.classList.toggle('dark', isDark);

  toggle.addEventListener('click', () => {
    const newDark = !document.documentElement.classList.contains('dark');
    document.documentElement.classList.toggle('dark', newDark);
    localStorage.setItem('theme', newDark ? 'dark' : 'light');
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
      populateFilters();
      render();
    })
    .catch(err => {
      console.error('Failed to load data:', err);
      tableBody.innerHTML = '<tr><td colspan="7" style="text-align:center; padding: 48px; color: var(--color-text-muted);">Failed to load data. Please ensure data.json exists.</td></tr>';
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
    statsEl.innerHTML = `
      <span>Total: <strong>${filteredData.length}</strong></span>
      <span>Verified CBS: <strong>${verified}</strong></span>
      <span>Unverified: <strong>${filteredData.length - verified}</strong></span>
    `;

    // Render table
    if (pageData.length === 0) {
      tableBody.innerHTML = '<tr><td colspan="7" style="text-align:center; padding: 48px; color: var(--color-text-muted);">No matching records</td></tr>';
    } else {
      tableBody.innerHTML = pageData.map(item => `
        <tr>
          <td>${escapeHtml(item.name)}</td>
          <td><span class="type-badge type-${item.type.toLowerCase().replace('municipality', 'mun').replace('rural', 'rural').replace('metropolitan', 'metro').replace('sub-metropolitan', 'sub')}">${escapeHtml(item.type)}</span></td>
          <td>${escapeHtml(item.district)}</td>
          <td>${escapeHtml(item.province)}</td>
          <td>${item.cbsCode !== null ? `<code>${item.cbsCode}</code>` : '<span class="unverified">—</span>'}</td>
          <td>${item.cbsCodeVerified ? '<span class="verified">✓ Verified</span>' : '<span class="unverified">Unverified</span>'}</td>
          <td>${item.isoCode ? `<code>${item.isoCode}</code>` : '—'}</td>
        </tr>
      `).join('');
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