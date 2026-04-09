// StoryCharts — shared utilities

var COLORS = ['#4a7fd4','#e06040','#50a040','#b8b020','#9060c0','#2a9d8f','#e07098','#8a6540','#3b2f80','#e08050'];

async function api(method, path, body) {
  var opts = { method: method, headers: {} };
  if (body) { opts.headers['Content-Type'] = 'application/json'; opts.body = JSON.stringify(body); }
  var res = await fetch('/api/' + path, opts);
  if (!res.ok) { var e = await res.json().catch(function() { return { error: 'Failed' }; }); throw new Error(e.error || 'Failed'); }
  return res.json();
}

async function getUser() { try { return await api('GET', 'auth/me'); } catch(e) { return null; } }

function renderHeader(user) {
  var h = document.getElementById('header'); if (!h) return;
  var s = '<a href="/">Story Charts</a>';
  if (user) {
    s += '<div class="user-menu">' +
           '<button type="button" class="user-menu-btn" id="user-menu-btn">' + user.email + '</button>' +
           '<div class="user-menu-drop" id="user-menu-drop" style="display:none">' +
             '<button type="button" id="logout-btn" class="user-menu-item">Logout</button>' +
           '</div>' +
         '</div>';
  } else {
    s += '<a href="/api/auth/login?redirect=' + encodeURIComponent(location.pathname + location.search) + '" class="auth-btn">Login</a>';
  }
  h.innerHTML = s;

  if (user) {
    var drop = document.getElementById('user-menu-drop');
    document.getElementById('user-menu-btn').addEventListener('click', function(e) {
      e.preventDefault();
      e.stopPropagation();
      drop.style.display = drop.style.display === 'none' ? 'block' : 'none';
    });
    document.getElementById('logout-btn').addEventListener('click', function(e) {
      e.preventDefault();
      document.cookie = 'CF_Authorization=; Max-Age=0; path=/';
      document.cookie = 'CF_Authorization=; Max-Age=0; path=/; domain=.storycharts.com';
      document.cookie = 'CF_Authorization=; Max-Age=0; path=/; domain=storycharts.com';
      // Navigate to current page — if Cloudflare Access is protecting
      // the domain, it may re-authenticate automatically via SSO
      var here = window.location.pathname + window.location.search;
      window.location.replace(here);
    });
    document.addEventListener('click', function() { drop.style.display = 'none'; });
  }
}
