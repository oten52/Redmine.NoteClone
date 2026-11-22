document.addEventListener('DOMContentLoaded', function () {
  var root = document.getElementById('redmine-note-clone');
  if (!root) return;

  var labels = readLabels(root);
  var drawer = root.querySelector('.redmine-note-clone-drawer');
  var status = root.querySelector('.redmine-note-clone-status');
  var noteList = root.querySelector('[data-list="notes"]');
  var targetList = root.querySelector('[data-list="targets"]');
  var loaded = false;
  var busy = false;

  var menu = document.querySelector('#content .contextual');
  var actions = root.querySelector('.redmine-note-clone-actions');
  if (menu && actions) menu.insertBefore(actions, menu.firstChild);

  document.addEventListener('click', function (event) {
    var node = event.target;
    if (node && node.nodeType !== 1) node = node.parentElement;
    var button = node && node.closest ? node.closest('[data-action]') : null;
    if (!button) return;
    if (!root.contains(button) && !(actions && actions.contains(button))) return;
    var action = button.getAttribute('data-action');
    if (action === 'open') openDrawer();
    if (action === 'close') closeDrawer();
    if (action === 'direct') copyDirect();
    if (action === 'lookup') lookupIssues();
    if (action === 'submit') submitCopy();
    if (action === 'notes-all') setChecks('.redmine-note-clone-note-check', true);
    if (action === 'notes-none') setChecks('.redmine-note-clone-note-check', false);
    if (action === 'targets-all') setChecks('.redmine-note-clone-target-check', true);
    if (action === 'targets-none') setChecks('.redmine-note-clone-target-check', false);
  });

  var issueInput = root.querySelector('[data-field="issue-id"]');
  if (issueInput) {
    issueInput.addEventListener('keydown', function (event) {
      if (event.key === 'Enter') {
        event.preventDefault();
        lookupIssues();
      }
    });
  }

  document.addEventListener('keydown', function (event) {
    if (event.key === 'Escape' && drawer && !drawer.hidden) closeDrawer();
  });

  function readLabels(node) {
    var script = node.querySelector('.redmine-note-clone-labels');
    try {
      return JSON.parse(script ? script.textContent : '{}');
    } catch (error) {
      return {};
    }
  }

  function openDrawer() {
    drawer.hidden = false;
    if (!loaded) loadPanel();
  }

  function closeDrawer() {
    drawer.hidden = true;
  }

  function loadPanel() {
    setStatus(labels.loading || '', true);
    request(root.getAttribute('data-url')).then(function (body) {
      if (body.error) {
        setStatus(body.error, false);
        return;
      }
      renderNotes(body.notes || []);
      renderTargets(body.targets || []);
      loaded = true;
      setStatus('', true);
    }).catch(function () {
      setStatus(labels.network || '', false);
    });
  }

  function copyDirect() {
    if (busy) return;
    busy = true;
    request(root.getAttribute('data-url')).then(function (body) {
      if (body.error && !(body.targets || []).length) {
        showBanner(body.error, false);
        return;
      }
      var related = (body.targets || []).filter(function (target) { return target.kind === 'related'; });
      var writable = related.filter(function (target) { return target.writable; });
      var blocked = related.filter(function (target) { return !target.writable; });
      if (!writable.length) {
        showBanner(labels.noRelated || '', false);
        return;
      }
      var lines = [labels.confirm || '', ''];
      writable.forEach(function (target) { lines.push('#' + target.id + ' ' + (target.subject || '')); });
      if (blocked.length) {
        lines.push('');
        lines.push(labels.confirmSkip || '');
        blocked.forEach(function (target) { lines.push('#' + target.id + ' ' + (target.subject || '')); });
      }
      if (!window.confirm(lines.join('\n'))) return;
      return request(root.getAttribute('data-url'), {
        method: 'POST',
        body: JSON.stringify({ mode: 'direct' })
      }).then(function (result) { showBanner(formatResult(result), !result.error); });
    }).catch(function () {
      showBanner(labels.network || '', false);
    }).then(function () { busy = false; });
  }

  function lookupIssues() {
    var input = root.querySelector('[data-field="issue-id"]');
    var ids = (input.value || '').match(/\d+/g) || [];
    if (!ids.length) return;
    var url = root.getAttribute('data-lookup-url') + '?issue_ids=' + encodeURIComponent(ids.join(','));
    request(url).then(function (body) {
      (body.issues || []).forEach(function (issue) {
        if (issue.error && !issue.subject) {
          setStatus('#' + issue.id + ' ' + issue.error, false);
          return;
        }
        var existing = targetList.querySelector('[data-target-id="' + issue.id + '"]');
        if (existing) {
          var box = existing.querySelector('input');
          if (box && !box.disabled) box.checked = true;
          return;
        }
        targetList.appendChild(targetRow(issue));
      });
      input.value = '';
    }).catch(function () {
      setStatus(labels.network || '', false);
    });
  }

  function submitCopy() {
    if (busy) return;
    var notes = [];
    root.querySelectorAll('.redmine-note-clone-note').forEach(function (card) {
      var check = card.querySelector('.redmine-note-clone-note-check');
      if (!check.checked) return;
      var attachmentIds = [];
      card.querySelectorAll('.redmine-note-clone-file-check').forEach(function (fileBox) {
        if (fileBox.checked) attachmentIds.push(parseInt(fileBox.value, 10));
      });
      notes.push({
        journal_id: parseInt(card.getAttribute('data-journal-id'), 10),
        text: card.querySelector('textarea').value,
        attachment_ids: attachmentIds
      });
    });
    var targetIds = [];
    root.querySelectorAll('.redmine-note-clone-target').forEach(function (row) {
      var check = row.querySelector('.redmine-note-clone-target-check');
      if (check && check.checked && !check.disabled) targetIds.push(parseInt(row.getAttribute('data-target-id'), 10));
    });
    busy = true;
    setStatus(labels.sending || '', true);
    request(root.getAttribute('data-url'), {
      method: 'POST',
      body: JSON.stringify({
        mode: 'edit',
        include_source: root.querySelector('[data-field="source"]').checked,
        notify: root.querySelector('[data-field="notify"]').checked,
        target_ids: targetIds,
        notes: notes
      })
    }).then(function (result) {
      setStatus(formatResult(result), !result.error);
    }).catch(function () {
      setStatus(labels.network || '', false);
    }).then(function () { busy = false; });
  }

  function renderNotes(notes) {
    noteList.textContent = '';
    notes.forEach(function (note) { noteList.appendChild(noteCard(note)); });
  }

  function renderTargets(targets) {
    targetList.textContent = '';
    targets.forEach(function (target) { targetList.appendChild(targetRow(target)); });
  }

  function noteCard(note) {
    var card = document.createElement('article');
    card.className = 'redmine-note-clone-note';
    card.setAttribute('data-journal-id', String(note.id));

    var head = document.createElement('label');
    var box = document.createElement('input');
    box.type = 'checkbox';
    box.checked = true;
    box.className = 'redmine-note-clone-note-check';
    var meta = document.createElement('span');
    meta.textContent = [note.author, note.created_on, note.private ? labels.private : ''].filter(Boolean).join(' · ');
    head.appendChild(box);
    head.appendChild(meta);
    card.appendChild(head);

    if (note.files && note.files.length) {
      var files = document.createElement('div');
      files.className = 'redmine-note-clone-files';
      note.files.forEach(function (file) { files.appendChild(fileRow(file)); });
      card.appendChild(files);
    }

    var area = document.createElement('textarea');
    area.className = 'redmine-note-clone-text';
    area.value = note.text || '';
    card.appendChild(area);
    return card;
  }

  function fileRow(file) {
    var row = document.createElement('label');
    row.className = 'redmine-note-clone-file';
    var box = document.createElement('input');
    box.type = 'checkbox';
    box.checked = true;
    box.value = String(file.id);
    box.className = 'redmine-note-clone-file-check';
    row.appendChild(box);
    var thumb = safePath(file.thumbnail || file.url);
    if (file.image && thumb) {
      var image = document.createElement('img');
      image.alt = file.filename || '';
      image.src = thumb;
      row.appendChild(image);
    }
    var name = document.createElement('span');
    name.textContent = file.filename || '';
    row.appendChild(name);
    return row;
  }

  function targetRow(target) {
    var row = document.createElement('label');
    row.className = 'redmine-note-clone-target';
    row.setAttribute('data-target-id', String(target.id));
    var box = document.createElement('input');
    box.type = 'checkbox';
    box.className = 'redmine-note-clone-target-check';
    box.checked = !!(target.selected && target.writable);
    box.disabled = !target.writable;
    row.appendChild(box);

    var text = document.createElement('span');
    var link = document.createElement('a');
    link.textContent = '#' + target.id;
    var href = safePath(target.url);
    if (href) {
      link.href = href;
      link.target = '_blank';
      link.rel = 'noopener';
    }
    text.appendChild(link);
    text.appendChild(document.createTextNode(' ' + (target.subject || '')));
    if (target.project) text.appendChild(document.createTextNode(' · ' + target.project));
    if (target.label) {
      var badge = document.createElement('em');
      badge.textContent = target.label;
      text.appendChild(badge);
    }
    if (!target.writable && (target.reason || target.error)) {
      var reason = document.createElement('small');
      reason.textContent = target.reason || target.error;
      text.appendChild(reason);
    }
    row.appendChild(text);
    return row;
  }

  function setChecks(selector, checked) {
    root.querySelectorAll(selector).forEach(function (box) {
      if (!box.disabled) box.checked = checked;
    });
  }

  function formatResult(body) {
    var parts = [];
    if (body.message) parts.push(body.message);
    else if (body.error) parts.push(body.error);
    (body.warnings || []).forEach(function (warning) { parts.push(warning); });
    var skipped = body.skipped || [];
    if (body.message || skipped.length > 1) {
      skipped.forEach(function (row) {
        parts.push('#' + row.id + (row.reason ? ' ' + row.reason : ''));
      });
    }
    return parts.join('\n');
  }

  function setStatus(text, ok) {
    status.textContent = text || '';
    status.className = 'redmine-note-clone-status' + (text ? (ok ? ' is-ok' : ' is-error') : '');
  }

  function showBanner(text, ok) {
    var banner = document.getElementById('redmine-note-clone-banner');
    if (!banner) {
      banner = document.createElement('div');
      banner.id = 'redmine-note-clone-banner';
      var content = document.getElementById('content');
      if (content) content.insertBefore(banner, content.firstChild);
      else root.insertBefore(banner, root.firstChild);
    }
    banner.className = 'flash ' + (ok ? 'notice' : 'error');
    banner.textContent = text || '';
  }

  function request(url, options) {
    var settings = options || {};
    settings.credentials = 'same-origin';
    settings.headers = settings.headers || {};
    settings.headers.Accept = 'application/json';
    if (settings.method && settings.method !== 'GET') {
      settings.headers['Content-Type'] = 'application/json';
      settings.headers['X-CSRF-Token'] = csrfToken();
    }
    return fetch(url, settings).then(function (response) {
      return response.json().catch(function () { return {}; }).then(function (body) {
        if (!response.ok && !body.error) body.error = labels.network || '';
        return body;
      });
    });
  }

  function csrfToken() {
    var tag = document.querySelector('meta[name="csrf-token"]');
    return tag ? tag.getAttribute('content') : '';
  }

  function safePath(url) {
    if (typeof url !== 'string') return '';
    if (url.charAt(0) === '/' && url.charAt(1) !== '/') return url;
    return '';
  }
});
