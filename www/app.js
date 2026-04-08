// StoryCharts — shared utilities

async function api(method, path, body) {
  var opts = { method: method, headers: {} };
  if (body) { opts.headers['Content-Type'] = 'application/json'; opts.body = JSON.stringify(body); }
  var res = await fetch('/api/' + path, opts);
  if (!res.ok) { var e = await res.json().catch(function() { return { error: 'Failed' }; }); throw new Error(e.error || 'Failed'); }
  return res.json();
}

async function getUser() { try { return await api('GET', 'auth/me'); } catch(e) { return null; } }

function showModal(title, fields, onSave, onDelete) {
  var ov = document.createElement('div'); ov.className = 'modal-overlay';
  var h = '<div class="modal"><h2>' + title + '</h2>';
  for (var i = 0; i < fields.length; i++) {
    var f = fields[i];
    h += '<div class="form-group"><label>' + f.label + '</label>';
    h += f.type === 'textarea' ? '<textarea name="' + f.name + '">' + (f.value||'') + '</textarea>'
       : '<input type="text" name="' + f.name + '" value="' + (f.value||'') + '">';
    h += '</div>';
  }
  h += '<div class="actions"><button class="btn btn-primary" id="m-ok">Save</button>';
  h += '<button class="btn" id="m-no">Cancel</button>';
  if (onDelete) h += '<button class="btn btn-danger" id="m-del" style="margin-left:auto">Delete</button>';
  h += '</div></div>';
  ov.innerHTML = h; document.body.appendChild(ov);
  ov.querySelector('#m-ok').onclick = function() {
    var d = {}; for (var i = 0; i < fields.length; i++) d[fields[i].name] = ov.querySelector('[name="'+fields[i].name+'"]').value;
    document.body.removeChild(ov); onSave(d);
  };
  ov.querySelector('#m-no').onclick = function() { document.body.removeChild(ov); };
  if (onDelete) ov.querySelector('#m-del').onclick = function() { if(confirm('Sure?')) { document.body.removeChild(ov); onDelete(); } };
  var first = ov.querySelector('input, textarea'); if (first) first.focus();
}

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
    s += '<a href="/api/auth/login" class="auth-btn">Login</a>';
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
