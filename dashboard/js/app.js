(function () {
  "use strict";

  const $ = (sel) => document.querySelector(sel);
  const $$ = (sel) => document.querySelectorAll(sel);

  const hamburger = $("#hamburger");
  const sidebar = $("#sidebar");
  const overlay = $("#overlay");
  const navItems = $$(".nav-item");
  const sections = $$(".section");

  // ---- Sidebar toggle ----

  function openSidebar() {
    sidebar.classList.add("open");
    overlay.classList.add("visible");
    hamburger.classList.add("open");
    hamburger.setAttribute("aria-expanded", "true");
  }

  function closeSidebar() {
    sidebar.classList.remove("open");
    overlay.classList.remove("visible");
    hamburger.classList.remove("open");
    hamburger.setAttribute("aria-expanded", "false");
  }

  function toggleSidebar() {
    sidebar.classList.contains("open") ? closeSidebar() : openSidebar();
  }

  hamburger.addEventListener("click", toggleSidebar);
  overlay.addEventListener("click", closeSidebar);

  // ---- Navigation ----

  function navigate(sectionId) {
    sections.forEach(function (s) {
      s.classList.toggle("active", s.id === "section-" + sectionId);
    });
    navItems.forEach(function (a) {
      a.classList.toggle("active", a.dataset.section === sectionId);
    });

    if (sectionId === "library") loadLibrary();
    if (sectionId === "maps") loadMap();
    if (sectionId === "files") loadFiles();
    if (sectionId === "content") loadContent();
    if (sectionId === "system") loadSystem();
    if (sectionId === "ai-chat") loadAiChat();
    if (sectionId === "vault") loadVault();

    if (window.innerWidth < 768) closeSidebar();
  }

  navItems.forEach(function (item) {
    item.addEventListener("click", function (e) {
      e.preventDefault();
      var target = this.dataset.section;
      navigate(target);
      history.replaceState(null, "", "#" + target);
    });
  });

  // ---- Setup wizard check ----

  (function checkSetup() {
    fetch("/api/setup-status")
      .then(function (r) { if (!r.ok) throw new Error(); return r.json(); })
      .then(function (cfg) {
        if (cfg && cfg.setup_complete === false) {
          showWizard(cfg);
        }
      })
      .catch(function () {});
  })();

  // Handle initial hash
  var initHash = location.hash.replace("#", "");
  if (initHash && document.getElementById("section-" + initHash)) {
    navigate(initHash);
  }

  // ---- Fetch /api/status ----

  function setVal(id, text) {
    var el = document.getElementById(id);
    if (el) el.textContent = text;
  }

  function setDot(id, color) {
    var el = document.getElementById(id);
    if (el) {
      el.classList.remove("green", "amber", "red");
      el.classList.add(color);
    }
  }

  function applyStatus(data) {
    setVal("val-device", data.device || "Unknown");
    setVal("val-uptime", data.uptime || "—");
    setVal("val-storage-used", data.storage_used || "—");
    setVal("val-storage-free", data.storage_free || "—");
    setVal("val-clients", data.clients != null ? data.clients : "—");

    var pct = parseFloat(data.storage_percent) || 0;
    setDot("dot-storage", pct > 90 ? "red" : pct > 75 ? "amber" : "green");
    setDot("dot-storage-free", pct > 90 ? "red" : pct > 75 ? "amber" : "green");

    if (data.services) {
      var total = data.services.total || 0;
      var running = data.services.running || 0;
      setVal("val-services", running + " / " + total + " running");
      setDot("dot-services", running === total ? "green" : running > 0 ? "amber" : "red");
    }

    $("#status-msg").textContent = "Updated " + new Date().toLocaleTimeString();
  }

  function fallbackStatus() {
    setVal("val-device", "Cairn");
    setVal("val-uptime", "—");
    setVal("val-storage-used", "—");
    setVal("val-storage-free", "—");
    setVal("val-services", "—");
    setVal("val-clients", "—");

    $$(".status-dot").forEach(function (d) {
      d.classList.remove("green", "amber", "red");
    });

    $("#status-msg").textContent = "Could not reach /api/status";
  }

  function fetchStatus() {
    fetch("/api/status")
      .then(function (res) {
        if (!res.ok) throw new Error(res.status);
        return res.json();
      })
      .then(applyStatus)
      .catch(fallbackStatus);
  }

  fetchStatus();

  // ---- Library ----

  var libLoaded = false;
  var libBooks = [];

  function loadLibrary() {
    if (libLoaded) return;
    libLoaded = true;
    fetchCatalog();
  }

  function fetchCatalog() {
    var msg = $("#lib-msg");
    var catalog = $("#lib-catalog");
    msg.textContent = "Loading catalog…";

    fetch("/kiwix/catalog/v2/entries?lang=eng")
      .then(function (res) {
        if (!res.ok) throw new Error(res.status);
        return res.text();
      })
      .then(function (xml) {
        libBooks = parseCatalog(xml);
        if (libBooks.length === 0) {
          msg.textContent = "No content available. Add ZIM files to /opt/cairn/zim/ and reboot to index them.";
          return;
        }
        renderCatalog(libBooks);
        msg.textContent = libBooks.length + " item" + (libBooks.length !== 1 ? "s" : "") + " available";
      })
      .catch(function () {
        catalog.innerHTML = "";
        msg.textContent = "No content available. Add ZIM files to /opt/cairn/zim/ and reboot to index them.";
      });
  }

  function parseCatalog(xml) {
    var parser = new DOMParser();
    var doc = parser.parseFromString(xml, "application/xml");
    var ns = "http://www.w3.org/2005/Atom";
    var dcNs = "http://purl.org/dc/terms/";
    var entries = doc.getElementsByTagNameNS(ns, "entry");
    var books = [];

    for (var i = 0; i < entries.length; i++) {
      var entry = entries[i];
      var title = getText(entry, ns, "title");
      var summary = getText(entry, ns, "summary") || getText(entry, ns, "content");

      var articleCount = "";
      var meta = entry.getElementsByTagNameNS(dcNs, "extent");
      if (meta.length) articleCount = meta[0].textContent.trim();

      var name = "";
      var links = entry.getElementsByTagNameNS(ns, "link");
      for (var j = 0; j < links.length; j++) {
        var href = links[j].getAttribute("href") || "";
        var type = links[j].getAttribute("type") || "";
        if (type.indexOf("html") !== -1 || href.indexOf("/kiwix/") === 0) {
          name = href.replace(/^\/kiwix\//, "").replace(/\/.*$/, "");
          break;
        }
      }

      if (!name) {
        var id = getText(entry, ns, "id");
        if (id) {
          name = id.replace(/^urn:uuid:/, "");
          var nameEl = entry.getElementsByTagNameNS(ns, "name");
          if (nameEl.length) name = nameEl[0].textContent.trim();
        }
      }

      if (!name && title) {
        name = title.toLowerCase().replace(/[^a-z0-9]+/g, "_");
      }

      books.push({
        title: title || "Untitled",
        description: summary || "",
        articleCount: articleCount,
        name: name
      });
    }

    return books;
  }

  function getText(parent, ns, tag) {
    var els = parent.getElementsByTagNameNS(ns, tag);
    return els.length ? els[0].textContent.trim() : "";
  }

  function renderCatalog(books) {
    var catalog = $("#lib-catalog");
    catalog.innerHTML = "";

    books.forEach(function (book) {
      var card = document.createElement("div");
      card.className = "lib-card";

      var h = document.createElement("div");
      h.className = "lib-card-title";
      h.textContent = book.title;
      card.appendChild(h);

      if (book.description) {
        var d = document.createElement("div");
        d.className = "lib-card-desc";
        d.textContent = book.description;
        card.appendChild(d);
      }

      if (book.articleCount) {
        var m = document.createElement("div");
        m.className = "lib-card-meta";
        m.textContent = book.articleCount + " articles";
        card.appendChild(m);
      }

      var a = document.createElement("a");
      a.className = "lib-card-browse";
      a.href = "/kiwix/" + encodeURIComponent(book.name);
      a.target = "_blank";
      a.rel = "noopener";
      a.textContent = "Browse";
      card.appendChild(a);

      catalog.appendChild(card);
    });
  }

  // ---- Library search ----

  var searchForm = $("#lib-search");
  var searchInput = $("#lib-search-input");
  var searchResults = $("#lib-search-results");

  searchForm.addEventListener("submit", function (e) {
    e.preventDefault();
    var q = searchInput.value.trim();
    if (!q) return;
    performSearch(q);
  });

  function performSearch(query) {
    searchResults.innerHTML = "<p class='lib-msg'>Searching…</p>";

    fetch("/kiwix/search?pattern=" + encodeURIComponent(query) + "&books=&pageLength=25")
      .then(function (res) {
        if (!res.ok) throw new Error(res.status);
        return res.text();
      })
      .then(function (html) {
        var results = parseSearchResults(html, query);
        renderSearchResults(results, query);
      })
      .catch(function () {
        searchResults.innerHTML = "<p class='lib-msg'>Search unavailable.</p>";
      });
  }

  function parseSearchResults(html, query) {
    var parser = new DOMParser();
    var doc = parser.parseFromString(html, "text/html");
    var results = [];

    var links = doc.querySelectorAll("a");
    for (var i = 0; i < links.length; i++) {
      var href = links[i].getAttribute("href") || "";
      if (href.indexOf("/kiwix/") !== 0 && href.indexOf("/search") !== -1) continue;
      if (href.indexOf("/kiwix/") !== 0) continue;
      var text = links[i].textContent.trim();
      if (!text || text.length < 2) continue;
      results.push({ title: text, url: href });
    }

    if (results.length === 0) {
      var allText = doc.body ? doc.body.textContent : "";
      var snippets = allText.split(/\n+/);
      for (var k = 0; k < snippets.length; k++) {
        var s = snippets[k].trim();
        if (s.length > 10 && s.toLowerCase().indexOf(query.toLowerCase()) !== -1) {
          results.push({ title: s.substring(0, 200), url: "" });
        }
      }
    }

    return results;
  }

  function renderSearchResults(results, query) {
    searchResults.innerHTML = "";

    if (results.length === 0) {
      searchResults.innerHTML = "<p class='lib-msg'>No results for \"" + escapeHtml(query) + "\"</p>";
      return;
    }

    var heading = document.createElement("div");
    heading.className = "lib-results-heading";
    heading.innerHTML =
      "<span>" + results.length + " result" + (results.length !== 1 ? "s" : "") + "</span>";

    var clearBtn = document.createElement("button");
    clearBtn.className = "lib-results-clear";
    clearBtn.textContent = "Clear";
    clearBtn.addEventListener("click", function () {
      searchResults.innerHTML = "";
      searchInput.value = "";
    });
    heading.appendChild(clearBtn);
    searchResults.appendChild(heading);

    var ul = document.createElement("ul");
    ul.className = "lib-result-list";

    results.forEach(function (r) {
      var li = document.createElement("li");
      var a = document.createElement("a");
      a.className = "lib-result-link";
      a.innerHTML = highlightText(r.title, query);
      if (r.url) {
        a.href = r.url;
        a.target = "_blank";
        a.rel = "noopener";
      }
      li.appendChild(a);
      ul.appendChild(li);
    });

    searchResults.appendChild(ul);
  }

  function highlightText(text, query) {
    var safe = escapeHtml(text);
    var safeQuery = escapeHtml(query);
    var re = new RegExp("(" + safeQuery.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + ")", "gi");
    return safe.replace(re, "<mark>$1</mark>");
  }

  function escapeHtml(str) {
    var d = document.createElement("div");
    d.appendChild(document.createTextNode(str));
    return d.innerHTML;
  }

  // ---- Maps ----

  var mapInstance = null;
  var mapLoading = false;

  var MAP_LAYER_GROUPS = {
    base:     ["background", "buildings", "labels-place", "labels-road"],
    roads:    ["road-motorway", "road-trunk", "road-primary", "road-secondary", "road-minor"],
    woodland: ["landuse"],
    water:    ["water-area", "waterway"],
    flood:    ["flood-zones"]
  };

  function loadMap() {
    if (mapInstance) {
      mapInstance.resize();
      return;
    }
    if (mapLoading) return;
    mapLoading = true;

    if (typeof maplibregl === "undefined") {
      showMapFallback("MapLibre GL JS not loaded. Place maplibre-gl.js in /dashboard/assets/.");
      return;
    }

    fetch("/assets/map-style.json")
      .then(function (res) {
        if (!res.ok) throw new Error(res.status);
        return res.json();
      })
      .then(function (style) {
        initMap(style);
      })
      .catch(function () {
        showMapFallback("No map tiles available. Add .mbtiles files to /opt/cairn/tiles/ and reboot.");
      });
  }

  function initMap(style) {
    var container = $("#map-container");

    try {
      mapInstance = new maplibregl.Map({
        container: container,
        style: style,
        center: [-1.5, 53.0],
        zoom: 6,
        maxBounds: [[-12.0, 49.0], [4.0, 61.5]],
        attributionControl: false
      });
    } catch (e) {
      showMapFallback("No map tiles available. Add .mbtiles files to /opt/cairn/tiles/ and reboot.");
      return;
    }

    mapInstance.addControl(new maplibregl.NavigationControl(), "bottom-right");

    mapInstance.on("moveend", updateCoords);
    mapInstance.on("zoomend", updateCoords);
    mapInstance.on("load", function () {
      updateCoords();
      bindLayerToggles();
      syncToggleState();
    });

    mapInstance.on("error", function (e) {
      if (e && e.error && /fetch|tile|source/i.test(e.error.message || "")) {
        showMapFallback("No map tiles available. Add .mbtiles files to /opt/cairn/tiles/ and reboot.");
      }
    });
  }

  function updateCoords() {
    if (!mapInstance) return;
    var c = mapInstance.getCenter();
    var z = mapInstance.getZoom();
    var el = $("#map-coords");
    if (el) {
      el.textContent =
        c.lat.toFixed(4) + ", " + c.lng.toFixed(4) + " · z" + z.toFixed(1);
    }
  }

  function bindLayerToggles() {
    var toggles = $$("#map-controls input[type='checkbox']");
    toggles.forEach(function (cb) {
      cb.addEventListener("change", function () {
        var group = this.dataset.layer;
        var visible = this.checked;
        setLayerGroupVisibility(group, visible);
      });
    });
  }

  function syncToggleState() {
    var toggles = $$("#map-controls input[type='checkbox']");
    toggles.forEach(function (cb) {
      var group = cb.dataset.layer;
      var visible = cb.checked;
      setLayerGroupVisibility(group, visible);
    });
  }

  function setLayerGroupVisibility(group, visible) {
    if (!mapInstance) return;
    var ids = MAP_LAYER_GROUPS[group];
    if (!ids) return;
    var val = visible ? "visible" : "none";
    ids.forEach(function (id) {
      if (mapInstance.getLayer(id)) {
        mapInstance.setLayoutProperty(id, "visibility", val);
      }
    });
  }

  function showMapFallback(msg) {
    var el = $("#map-fallback");
    if (el) {
      el.textContent = msg;
      el.classList.add("visible");
    }
    var ctrl = $("#map-controls");
    if (ctrl) ctrl.style.display = "none";
    var coords = $("#map-coords");
    if (coords) coords.style.display = "none";
  }

  // ---- Files ----

  var filesLoaded = false;
  var filesCurrentPath = "/";

  function loadFiles() {
    if (filesLoaded) return;
    filesLoaded = true;
    fetchDirectory("/");
  }

  function fetchDirectory(path) {
    filesCurrentPath = path;
    var list = $("#files-list");
    var msg = $("#files-msg");
    list.innerHTML = "";
    msg.textContent = "Loading…";

    fetch("/files" + path, {
      headers: { "Accept": "application/json" }
    })
      .then(function (res) {
        if (!res.ok) throw new Error(res.status);
        return res.json();
      })
      .then(function (entries) {
        if (!entries || entries.length === 0) {
          msg.textContent = "No files available. Add documents to /opt/cairn/data/ to make them accessible here.";
          renderBreadcrumb(path);
          return;
        }
        msg.textContent = "";
        renderBreadcrumb(path);
        renderFileList(entries, path);
      })
      .catch(function () {
        list.innerHTML = "";
        msg.textContent = "No files available. Add documents to /opt/cairn/data/ to make them accessible here.";
        renderBreadcrumb(path);
      });
  }

  function renderBreadcrumb(path) {
    var bc = $("#files-breadcrumb");
    bc.innerHTML = "";

    var parts = path.split("/").filter(Boolean);
    var crumbPath = "/";

    var root = document.createElement("a");
    root.href = "#";
    root.className = "files-crumb";
    root.textContent = "📁 Root";
    root.addEventListener("click", function (e) {
      e.preventDefault();
      fetchDirectory("/");
    });
    bc.appendChild(root);

    parts.forEach(function (part) {
      crumbPath += part + "/";

      var sep = document.createElement("span");
      sep.className = "files-crumb-sep";
      sep.textContent = " / ";
      bc.appendChild(sep);

      var a = document.createElement("a");
      a.href = "#";
      a.className = "files-crumb";
      a.textContent = part;
      var target = crumbPath;
      a.addEventListener("click", function (e) {
        e.preventDefault();
        fetchDirectory(target);
      });
      bc.appendChild(a);
    });
  }

  function renderFileList(entries, basePath) {
    var list = $("#files-list");
    list.innerHTML = "";

    entries.sort(function (a, b) {
      if (a.type === "directory" && b.type !== "directory") return -1;
      if (a.type !== "directory" && b.type === "directory") return 1;
      return (a.name || "").localeCompare(b.name || "");
    });

    entries.forEach(function (entry) {
      var isDir = entry.type === "directory";
      var el = document.createElement("a");
      el.className = "files-row";

      var icon = document.createElement("span");
      icon.className = "files-icon";
      icon.textContent = isDir ? "📁" : "📄";
      el.appendChild(icon);

      var name = document.createElement("span");
      name.className = "files-name";
      name.textContent = entry.name;
      el.appendChild(name);

      if (!isDir && entry.size != null) {
        var size = document.createElement("span");
        size.className = "files-size";
        size.textContent = humanSize(entry.size);
        el.appendChild(size);
      }

      if (isDir) {
        el.href = "#";
        el.addEventListener("click", function (e) {
          e.preventDefault();
          var next = basePath.replace(/\/$/, "") + "/" + entry.name + "/";
          fetchDirectory(next);
        });
      } else {
        el.href = "/files" + basePath.replace(/\/$/, "") + "/" + entry.name;
        el.target = "_blank";
        el.rel = "noopener";
      }

      list.appendChild(el);
    });
  }

  function humanSize(bytes) {
    if (bytes == null || bytes < 0) return "";
    if (bytes < 1024) return bytes + " B";
    if (bytes < 1048576) return (bytes / 1024).toFixed(1) + " KB";
    if (bytes < 1073741824) return (bytes / 1048576).toFixed(1) + " MB";
    return (bytes / 1073741824).toFixed(2) + " GB";
  }

  // ---- Content ----

  var cntLoaded = false;
  var cntHasInternet = false;
  var cntPollers = {};

  function loadContent() {
    if (cntLoaded) return;
    cntLoaded = true;
    checkConnectivity();
    fetchManifest();
  }

  function checkConnectivity() {
    fetch("https://connectivitycheck.gstatic.com/generate_204", {
      method: "HEAD",
      mode: "no-cors",
      cache: "no-store"
    })
      .then(function () { cntHasInternet = true; })
      .catch(function () { cntHasInternet = false; });
  }

  function fetchManifest() {
    var grid = $("#cnt-grid");
    var msg = $("#cnt-msg");
    msg.textContent = "Loading manifest…";

    fetch("/api/manifest")
      .then(function (res) {
        if (!res.ok) throw new Error(res.status);
        return res.json();
      })
      .then(function (items) {
        if (!items || items.length === 0) {
          msg.textContent = "Content manifest not found. Run the content detection script or check /opt/cairn/config.json";
          return;
        }
        msg.textContent = "";
        renderContentGrid(items);
      })
      .catch(function () {
        grid.innerHTML = "";
        msg.textContent = "Content manifest not found. Run the content detection script or check /opt/cairn/config.json";
      });
  }

  function renderContentGrid(items) {
    var grid = $("#cnt-grid");
    grid.innerHTML = "";

    items.forEach(function (item) {
      var card = document.createElement("div");
      card.className = "cnt-card";
      card.dataset.id = item.id;

      var head = document.createElement("div");
      head.className = "cnt-card-head";

      var title = document.createElement("div");
      title.className = "cnt-card-title";
      title.textContent = item.name || item.id;
      head.appendChild(title);

      var status = document.createElement("span");
      status.className = "cnt-card-status " + (item.installed ? "installed" : "not-installed");
      status.textContent = item.installed ? "✓ Installed" : "Not installed";
      head.appendChild(status);

      card.appendChild(head);

      if (item.description) {
        var desc = document.createElement("div");
        desc.className = "cnt-card-desc";
        desc.textContent = item.description;
        card.appendChild(desc);
      }

      if (item.size) {
        var meta = document.createElement("div");
        meta.className = "cnt-card-meta";
        meta.textContent = item.size;
        card.appendChild(meta);
      }

      var actions = document.createElement("div");
      actions.className = "cnt-card-actions";

      if (!item.installed && cntHasInternet) {
        var btn = document.createElement("button");
        btn.className = "cnt-download-btn";
        btn.textContent = "Download";
        btn.addEventListener("click", function () {
          startDownload(item.id, card);
        });
        actions.appendChild(btn);
      }

      var progressWrap = document.createElement("div");
      progressWrap.className = "cnt-progress-wrap";

      var bar = document.createElement("div");
      bar.className = "cnt-progress-bar";
      var fill = document.createElement("div");
      fill.className = "cnt-progress-fill";
      bar.appendChild(fill);
      progressWrap.appendChild(bar);

      var pctText = document.createElement("span");
      pctText.className = "cnt-progress-text";
      pctText.textContent = "0%";
      progressWrap.appendChild(pctText);

      actions.appendChild(progressWrap);
      card.appendChild(actions);
      grid.appendChild(card);
    });
  }

  function startDownload(contentId, card) {
    var btn = card.querySelector(".cnt-download-btn");
    var progressWrap = card.querySelector(".cnt-progress-wrap");
    if (btn) {
      btn.disabled = true;
      btn.textContent = "Downloading…";
    }
    if (progressWrap) progressWrap.classList.add("active");

    fetch("/api/content/download", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ id: contentId })
    })
      .then(function (res) {
        if (!res.ok) throw new Error(res.status);
        pollProgress(contentId, card);
      })
      .catch(function () {
        if (btn) {
          btn.disabled = false;
          btn.textContent = "Retry";
        }
        if (progressWrap) progressWrap.classList.remove("active");
      });
  }

  function pollProgress(contentId, card) {
    if (cntPollers[contentId]) clearInterval(cntPollers[contentId]);
    cntPollers[contentId] = setInterval(function () {
      fetch("/api/content/status?id=" + encodeURIComponent(contentId))
        .then(function (r) { return r.json(); })
        .then(function (d) {
          var fill = card.querySelector(".cnt-progress-fill");
          var txt = card.querySelector(".cnt-progress-text");
          var pct = d.progress || 0;
          if (fill) fill.style.width = pct + "%";
          if (txt) txt.textContent = Math.round(pct) + "%";
          if (d.complete || pct >= 100) {
            clearInterval(cntPollers[contentId]);
            delete cntPollers[contentId];
            var b = card.querySelector(".cnt-download-btn");
            if (b) b.style.display = "none";
            var s = card.querySelector(".cnt-card-status");
            if (s) { s.className = "cnt-card-status installed"; s.textContent = "✓ Installed"; }
            var w = card.querySelector(".cnt-progress-wrap");
            if (w) w.classList.remove("active");
          }
        })
        .catch(function () { clearInterval(cntPollers[contentId]); delete cntPollers[contentId]; });
    }, 2000);
  }

  // ---- System ----

  var sysLoaded = false;
  var sysData = null;
  var sysTimer = null;

  function loadSystem() {
    fetchSystemStatus();
    if (!sysTimer) sysTimer = setInterval(fetchSystemStatus, 30000);
  }

  function fetchSystemStatus() {
    var msg = $("#sys-msg");
    fetch("/api/status")
      .then(function (r) { if (!r.ok) throw new Error(r.status); return r.json(); })
      .then(function (d) { sysData = d; renderSystem(d); if (msg) msg.textContent = "Updated " + new Date().toLocaleTimeString(); })
      .catch(function () { if (msg) msg.textContent = "Could not reach /api/status"; });
  }

  function renderSystem(d) {
    var grid = $("#sys-grid");
    grid.innerHTML = "";
    var groups = [];

    groups.push({ title: "Platform", rows: [
      ["Device", d.device || "—"], ["Architecture", d.arch || "—"], ["OS", d.os || "—"],
      ["Cairn version", d.version || "—"], ["Tier", d.tier || "—"]
    ]});

    if (d.cpu) groups.push({ title: "Processor", rows: [
      ["Model", d.cpu.model || "—"], ["Cores", d.cpu.cores || "—"],
      ["Load", d.cpu.load != null ? d.cpu.load + "%" : "—"],
      ["Temperature", d.cpu.temp != null ? d.cpu.temp + " °C" : "—"]
    ]});

    var memRows = [["Total", d.memory_total || "—"], ["Used", d.memory_used || "—"], ["Available", d.memory_available || "—"]];
    var totalMB = parseFloat(d.memory_total_mb) || 0;
    memRows.push(["AI-capable", totalMB >= 4096 ? "Yes" : "No (requires ≥4 GB)"]);
    groups.push({ title: "Memory", rows: memRows });

    var storRows = [];
    if (d.storage_device) storRows.push(["Device", d.storage_device]);
    storRows.push(["Total", d.storage_total || "—"], ["Used", d.storage_used || "—"], ["Free", d.storage_free || "—"]);
    if (d.content_breakdown && Array.isArray(d.content_breakdown)) {
      d.content_breakdown.forEach(function (c) { storRows.push([c.name, c.size || "—"]); });
    }
    groups.push({ title: "Storage", rows: storRows });

    var netRows = [];
    netRows.push(["Hotspot", d.hotspot_status || "—"]);
    if (d.hotspot_ssid) netRows.push(["SSID", d.hotspot_ssid]);
    if (d.clients != null) netRows.push(["Clients", d.clients]);
    if (d.ethernet_ip) netRows.push(["Ethernet IP", d.ethernet_ip]);
    netRows.push(["Internet", d.online ? "Online" : "Offline"]);
    groups.push({ title: "Network", rows: netRows });

    groups.forEach(function (g) {
      var div = document.createElement("div");
      div.className = "sys-group";
      div.innerHTML = "<div class='sys-group-title'>" + g.title + "</div>";
      g.rows.forEach(function (r) {
        var row = document.createElement("div");
        row.className = "sys-row";
        row.innerHTML = "<span class='sys-row-label'>" + escapeHtml(r[0]) + "</span><span class='sys-row-val'>" + escapeHtml(String(r[1])) + "</span>";
        div.appendChild(row);
      });
      grid.appendChild(div);
    });

    if (d.services && d.services.list) {
      var svcDiv = document.createElement("div");
      svcDiv.className = "sys-group";
      svcDiv.innerHTML = "<div class='sys-group-title'>Services</div>";
      d.services.list.forEach(function (svc) {
        var row = document.createElement("div");
        row.className = "sys-svc-row";
        row.innerHTML = "<span class='sys-svc-dot " + (svc.running ? "up" : "down") + "'></span>" +
          "<span class='sys-svc-name'>" + escapeHtml(svc.name) + "</span>" +
          "<span class='sys-svc-port'>" + (svc.port ? ":" + svc.port : "") + "</span>";
        svcDiv.appendChild(row);
      });
      grid.appendChild(svcDiv);
    }
  }

  $("#sys-copy").addEventListener("click", function () {
    if (!sysData) return;
    var lines = ["=== Cairn Diagnostic Info ===", "Time: " + new Date().toISOString()];
    var add = function (k, v) { if (v != null) lines.push(k + ": " + v); };
    add("Device", sysData.device); add("Arch", sysData.arch); add("OS", sysData.os);
    add("Version", sysData.version); add("Tier", sysData.tier); add("Uptime", sysData.uptime);
    if (sysData.cpu) { add("CPU", sysData.cpu.model); add("Cores", sysData.cpu.cores); add("Load", sysData.cpu.load + "%"); add("Temp", sysData.cpu.temp + "°C"); }
    add("Memory total", sysData.memory_total); add("Memory used", sysData.memory_used);
    add("Storage total", sysData.storage_total); add("Storage used", sysData.storage_used); add("Storage free", sysData.storage_free);
    add("Hotspot", sysData.hotspot_ssid); add("Clients", sysData.clients); add("Ethernet", sysData.ethernet_ip); add("Online", sysData.online);
    if (sysData.services && sysData.services.list) {
      lines.push("--- Services ---");
      sysData.services.list.forEach(function (s) { lines.push((s.running ? "[OK]" : "[!!]") + " " + s.name + (s.port ? " :" + s.port : "")); });
    }
    navigator.clipboard.writeText(lines.join("\n")).then(function () {
      $("#sys-copy").textContent = "Copied!";
      setTimeout(function () { $("#sys-copy").textContent = "Copy Diagnostic Info"; }, 2000);
    });
  });

  // ---- AI Chat ----

  var aiLoaded = false;
  var aiHistory = [];

  function loadAiChat() {
    if (aiLoaded) return;
    aiLoaded = true;
    fetch("/api/status")
      .then(function (r) { if (!r.ok) throw new Error(); return r.json(); })
      .then(function (d) {
        var available = false;
        if (d.services && d.services.list) {
          d.services.list.forEach(function (s) { if (s.name === "cairn-ai" && s.running) available = true; });
        }
        if (available) {
          $("#ai-chat-ui").style.display = "flex";
        } else {
          $("#ai-unavailable").style.display = "block";
        }
      })
      .catch(function () { $("#ai-unavailable").style.display = "block"; });
  }

  $("#ai-form").addEventListener("submit", function (e) {
    e.preventDefault();
    var input = $("#ai-input");
    var msg = input.value.trim();
    if (!msg) return;
    input.value = "";
    appendBubble("user", msg);
    aiHistory.push({ role: "user", content: msg });
    sendAiMessage();
  });

  function appendBubble(role, text) {
    var area = $("#ai-messages");
    var div = document.createElement("div");
    div.className = "ai-bubble " + role;
    div.textContent = text;
    area.appendChild(div);
    area.scrollTop = area.scrollHeight;
    return div;
  }

  function sendAiMessage() {
    var bubble = appendBubble("assistant", "");
    var content = "";
    $("#ai-send").disabled = true;

    fetch("/ai/v1/chat/completions", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        model: "local",
        messages: [{ role: "system", content: "You are Cairn AI, a helpful offline assistant." }].concat(aiHistory),
        stream: true
      })
    })
      .then(function (res) {
        if (!res.ok) throw new Error(res.status);
        var reader = res.body.getReader();
        var decoder = new TextDecoder();
        var buf = "";

        function read() {
          return reader.read().then(function (result) {
            if (result.done) { finishAi(content); return; }
            buf += decoder.decode(result.value, { stream: true });
            var lines = buf.split("\n");
            buf = lines.pop();
            lines.forEach(function (line) {
              if (line.indexOf("data: ") !== 0) return;
              var payload = line.slice(6).trim();
              if (payload === "[DONE]") return;
              try {
                var json = JSON.parse(payload);
                var delta = json.choices && json.choices[0] && json.choices[0].delta;
                if (delta && delta.content) {
                  content += delta.content;
                  bubble.textContent = content;
                  $("#ai-messages").scrollTop = $("#ai-messages").scrollHeight;
                }
              } catch (_) {}
            });
            return read();
          });
        }
        return read();
      })
      .catch(function () {
        if (!content) bubble.textContent = "Error: could not reach AI service.";
        finishAi(content || "");
      });
  }

  function finishAi(content) {
    if (content) aiHistory.push({ role: "assistant", content: content });
    $("#ai-send").disabled = false;
    $("#ai-input").focus();
  }

  // ---- Vault ----

  var vaultLoaded = false;
  var vaultCurrent = null;
  var vaultLockTimer = null;
  var vaultLockRemaining = 0;

  function loadVault() {
    if (vaultLoaded) return;
    vaultLoaded = true;
    fetchVaultList();
    $("#vault-create-toggle").addEventListener("click", function () {
      $("#vault-create-form").style.display = "flex";
      this.style.display = "none";
    });
    $("#vc-cancel").addEventListener("click", function () {
      $("#vault-create-form").style.display = "none";
      $("#vault-create-toggle").style.display = "";
    });
    $("#vc-pass").addEventListener("input", function () {
      var len = this.value.length;
      var fill = this.parentNode.nextElementSibling.querySelector(".vault-strength-fill") ||
        (function () { var f = document.createElement("div"); f.className = "vault-strength-fill"; $("#vc-strength").appendChild(f); return f; })();
      var pct = Math.min(len / 20 * 100, 100);
      fill.style.width = pct + "%";
      fill.style.background = pct < 50 ? "var(--red)" : pct < 80 ? "var(--accent)" : "var(--green)";
    });
    $("#vault-create-form").addEventListener("submit", function (e) {
      e.preventDefault();
      var pass = $("#vc-pass").value, pass2 = $("#vc-pass2").value;
      if (pass !== pass2) { showVaultMsg("Passphrases do not match."); return; }
      if (pass.length < 12) { showVaultMsg("Passphrase must be at least 12 characters."); return; }
      createVault($("#vc-name").value, pass, $("#vc-size").value);
    });
    $("#vu-cancel").addEventListener("click", function () {
      $("#vault-unlock-view").style.display = "none";
      $("#vault-list-view").style.display = "";
    });
    $("#vault-unlock-form").addEventListener("submit", function (e) {
      e.preventDefault();
      unlockVault(vaultCurrent, $("#vu-pass").value);
    });
    $("#vault-lock-btn").addEventListener("click", function () { lockVault(); });
    $("#vault-upload-input").addEventListener("change", function () { uploadVaultFiles(this.files); this.value = ""; });
  }

  function fetchVaultList() {
    fetch("/api/vault/list")
      .then(function (r) { if (!r.ok) throw new Error(); return r.json(); })
      .then(function (vaults) {
        var list = $("#vault-list");
        list.innerHTML = "";
        if (!vaults || vaults.length === 0) { list.innerHTML = "<p style='color:var(--text-muted);font-size:.85rem'>No vaults yet.</p>"; return; }
        vaults.forEach(function (v) {
          var div = document.createElement("div");
          div.className = "vault-item";
          div.innerHTML = "<span class='vault-item-name'>🔒 " + escapeHtml(v.name) + "</span>" +
            "<span class='vault-item-size'>" + escapeHtml(v.size || "") + "</span>";
          var btn = document.createElement("button");
          btn.className = "btn-ghost btn-sm";
          btn.textContent = "Unlock";
          btn.addEventListener("click", function () { showUnlockForm(v.name); });
          div.appendChild(btn);
          list.appendChild(div);
        });
      })
      .catch(function () { showVaultMsg("Vault service not available. Check that cryptsetup is installed."); });
  }

  function showUnlockForm(name) {
    vaultCurrent = name;
    $("#vault-unlock-name").textContent = "🔒 " + name;
    $("#vu-pass").value = "";
    $("#vault-list-view").style.display = "none";
    $("#vault-unlock-view").style.display = "";
  }

  function unlockVault(name, pass) {
    fetch("/api/vault/unlock", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: name, passphrase: pass })
    })
      .then(function (r) { if (!r.ok) throw new Error(); return r.json(); })
      .then(function () {
        $("#vault-unlock-view").style.display = "none";
        showVaultOpen(name);
      })
      .catch(function () { showVaultMsg("Unlock failed — wrong passphrase or vault error."); });
  }

  function createVault(name, pass, size) {
    showVaultMsg("Creating vault…");
    fetch("/api/vault/create", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: name, passphrase: pass, size: size })
    })
      .then(function (r) { if (!r.ok) throw new Error(); return r.json(); })
      .then(function () {
        showVaultMsg(""); $("#vault-create-form").style.display = "none";
        $("#vault-create-toggle").style.display = ""; fetchVaultList();
      })
      .catch(function () { showVaultMsg("Failed to create vault."); });
  }

  function showVaultOpen(name) {
    $("#vault-open-view").style.display = "";
    $("#vault-open-name").textContent = "🔓 " + name;
    vaultLockRemaining = 300;
    updateVaultTimer();
    if (vaultLockTimer) clearInterval(vaultLockTimer);
    vaultLockTimer = setInterval(function () {
      vaultLockRemaining--;
      updateVaultTimer();
      if (vaultLockRemaining <= 0) lockVault();
    }, 1000);
    fetchVaultDir("/");
  }

  function updateVaultTimer() {
    var m = Math.floor(vaultLockRemaining / 60), s = vaultLockRemaining % 60;
    $("#vault-timer").textContent = m + ":" + (s < 10 ? "0" : "") + s + " remaining";
  }

  function lockVault() {
    if (vaultLockTimer) { clearInterval(vaultLockTimer); vaultLockTimer = null; }
    fetch("/api/vault/lock", { method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: vaultCurrent }) }).catch(function () {});
    $("#vault-open-view").style.display = "none";
    $("#vault-list-view").style.display = "";
    fetchVaultList();
  }

  function fetchVaultDir(path) {
    var list = $("#vault-files");
    list.innerHTML = "";
    fetch("/api/vault/files?name=" + encodeURIComponent(vaultCurrent) + "&path=" + encodeURIComponent(path), {
      headers: { "Accept": "application/json" }
    })
      .then(function (r) { if (!r.ok) throw new Error(); return r.json(); })
      .then(function (entries) {
        renderVaultBreadcrumb(path);
        if (!entries || entries.length === 0) { list.innerHTML = "<p style='color:var(--text-muted);font-size:.85rem'>Empty</p>"; return; }
        entries.sort(function (a, b) {
          if (a.type === "directory" && b.type !== "directory") return -1;
          if (a.type !== "directory" && b.type === "directory") return 1;
          return (a.name || "").localeCompare(b.name || "");
        });
        entries.forEach(function (entry) {
          var isDir = entry.type === "directory";
          var el = document.createElement("a");
          el.className = "files-row";
          el.innerHTML = "<span class='files-icon'>" + (isDir ? "📁" : "📄") + "</span><span class='files-name'>" + escapeHtml(entry.name) + "</span>";
          if (!isDir && entry.size != null) el.innerHTML += "<span class='files-size'>" + humanSize(entry.size) + "</span>";
          if (isDir) {
            el.href = "#";
            var next = path.replace(/\/$/, "") + "/" + entry.name + "/";
            el.addEventListener("click", function (e) { e.preventDefault(); fetchVaultDir(next); });
          } else {
            el.href = "/api/vault/file?name=" + encodeURIComponent(vaultCurrent) + "&path=" + encodeURIComponent(path.replace(/\/$/, "") + "/" + entry.name);
            el.target = "_blank"; el.rel = "noopener";
          }
          list.appendChild(el);
        });
      })
      .catch(function () { list.innerHTML = "<p style='color:var(--text-muted);font-size:.85rem'>Could not list vault contents.</p>"; });
  }

  function renderVaultBreadcrumb(path) {
    var bc = $("#vault-breadcrumb");
    bc.innerHTML = "";
    var parts = path.split("/").filter(Boolean);
    var crumbPath = "/";
    var root = document.createElement("a");
    root.href = "#"; root.className = "files-crumb"; root.textContent = "📁 Root";
    root.addEventListener("click", function (e) { e.preventDefault(); fetchVaultDir("/"); });
    bc.appendChild(root);
    parts.forEach(function (part) {
      crumbPath += part + "/";
      var sep = document.createElement("span"); sep.className = "files-crumb-sep"; sep.textContent = " / ";
      bc.appendChild(sep);
      var a = document.createElement("a"); a.href = "#"; a.className = "files-crumb"; a.textContent = part;
      var t = crumbPath;
      a.addEventListener("click", function (e) { e.preventDefault(); fetchVaultDir(t); });
      bc.appendChild(a);
    });
  }

  function uploadVaultFiles(files) {
    if (!files || files.length === 0) return;
    var form = new FormData();
    form.append("name", vaultCurrent);
    for (var i = 0; i < files.length; i++) form.append("files", files[i]);
    fetch("/api/vault/upload", { method: "POST", body: form })
      .then(function (r) { if (!r.ok) throw new Error(); fetchVaultDir("/"); })
      .catch(function () { showVaultMsg("Upload failed."); });
  }

  function showVaultMsg(t) { var m = $("#vault-msg"); if (m) m.textContent = t; }

  // ---- Setup Wizard ----

  var wizStep = 0;
  var wizTotal = 7;
  var wizCfg = {};

  function showWizard(cfg) {
    wizCfg = cfg;
    var ov = $("#wiz-overlay");
    ov.style.display = "flex";
    $(".topbar").style.display = "none";
    $(".layout").style.display = "none";
    $("#overlay").style.display = "none";

    buildDots();
    populateWizardData(cfg);
    wizGo(0);

    $("#wiz-next").addEventListener("click", wizNext);
    $("#wiz-back").addEventListener("click", wizPrev);

    $("#wiz-vault-toggle").addEventListener("change", function () {
      $("#wiz-vault-fields").style.display = this.checked ? "block" : "none";
    });

    $$("#wiz-content-list input[type='checkbox']").forEach(function (cb) {
      cb.addEventListener("change", updateWizSize);
    });
  }

  function buildDots() {
    var container = $("#wiz-dots");
    container.innerHTML = "";
    for (var i = 0; i < wizTotal; i++) {
      var d = document.createElement("span");
      d.className = "wiz-dot" + (i === 0 ? " active" : "");
      container.appendChild(d);
    }
  }

  function wizGo(step) {
    wizStep = step;
    $$(".wiz-step").forEach(function (s) {
      s.classList.toggle("active", parseInt(s.dataset.step) === step);
    });
    $$(".wiz-dot").forEach(function (d, i) {
      d.className = "wiz-dot" + (i === step ? " active" : i < step ? " done" : "");
    });
    $("#wiz-back").style.visibility = step === 0 ? "hidden" : "";
    var btn = $("#wiz-next");
    if (step === wizTotal - 1) {
      btn.textContent = "Finish Setup";
    } else {
      btn.textContent = "Next";
    }

    if (step === 6) buildSummary();
  }

  function wizNext() {
    if (wizStep >= wizTotal - 1) { finishWizard(); return; }
    wizGo(wizStep + 1);
  }

  function wizPrev() {
    if (wizStep > 0) wizGo(wizStep - 1);
  }

  function populateWizardData(cfg) {
    var hw = "<strong>" + (cfg.model || "Unknown device") + "</strong><br>" +
      "Platform: " + (cfg.platform || "—") + " · RAM: " + (cfg.ram_mb || "?") + " MB · Storage: " + (cfg.storage_gb || "?") + " GB";
    $("#wiz-hw-summary").innerHTML = hw;
    $("#wiz-hw-detail").innerHTML = hw + "<br>Recommended tier: <strong>" + (cfg.recommended_tier || "—") + "</strong>" +
      "<br>AI capable: <strong>" + (cfg.ai_capable ? "Yes" : "No") + "</strong>";
    $("#wiz-tier").textContent = cfg.recommended_tier || "—";

    var aiInfo = cfg.ai_capable
      ? "This device has enough RAM for local AI inference. Enable it to get an offline assistant."
      : "This device has less than 4 GB RAM. Local AI will be very slow or may not work. You can still enable it.";
    $("#wiz-ai-info").textContent = aiInfo;
    if (cfg.ai_capable) $("#wiz-ai-toggle").checked = true;

    var contentPacks = [
      { id: "wikipedia-mini", name: "Wikipedia (condensed)", size: 6 },
      { id: "medical", name: "Medical reference", size: 1.2 },
      { id: "survival", name: "Survival guides", size: 0.5 },
      { id: "maps-gb", name: "GB map tiles", size: 8 },
      { id: "gutenberg", name: "Project Gutenberg books", size: 12 },
      { id: "stackexchange", name: "StackExchange archive", size: 18 },
      { id: "osm-world", name: "World map tiles", size: 45 }
    ];
    var list = $("#wiz-content-list");
    list.innerHTML = "";
    contentPacks.forEach(function (p) {
      var div = document.createElement("div");
      div.className = "wiz-content-item";
      var lbl = document.createElement("label");
      var cb = document.createElement("input");
      cb.type = "checkbox";
      cb.value = p.id;
      cb.dataset.size = p.size;
      if (p.size <= (cfg.storage_gb || 0) * 0.5) cb.checked = true;
      lbl.appendChild(cb);
      lbl.appendChild(document.createTextNode(" " + p.name));
      div.appendChild(lbl);
      var sz = document.createElement("span");
      sz.className = "files-size";
      sz.textContent = p.size + " GB";
      div.appendChild(sz);
      list.appendChild(div);
    });
    updateWizSize();
  }

  function updateWizSize() {
    var total = 0;
    $$("#wiz-content-list input:checked").forEach(function (cb) {
      total += parseFloat(cb.dataset.size) || 0;
    });
    $("#wiz-size-total").textContent = total.toFixed(1) + " GB";
  }

  function buildSummary() {
    var lines = [];
    lines.push("<strong>Device:</strong> " + (wizCfg.model || "—"));
    lines.push("<strong>SSID:</strong> " + ($("#wiz-ssid").value || "Cairn"));
    lines.push("<strong>AI:</strong> " + ($("#wiz-ai-toggle").checked ? "Enabled" : "Disabled"));

    var content = [];
    $$("#wiz-content-list input:checked").forEach(function (cb) {
      content.push(cb.value);
    });
    lines.push("<strong>Content:</strong> " + (content.length ? content.join(", ") : "None selected"));

    if ($("#wiz-vault-toggle").checked) {
      lines.push("<strong>Vault:</strong> " + ($("#wiz-vault-name").value || "Personal"));
    } else {
      lines.push("<strong>Vault:</strong> Skipped");
    }
    $("#wiz-summary").innerHTML = lines.join("<br>");
  }

  function finishWizard() {
    var btn = $("#wiz-next");
    btn.disabled = true;
    btn.textContent = "Saving…";

    var content = [];
    $$("#wiz-content-list input:checked").forEach(function (cb) { content.push(cb.value); });

    var payload = {
      ssid: $("#wiz-ssid").value || "Cairn",
      wifi_password: $("#wiz-wifi-pass").value || "cairn12345",
      wifi_channel: parseInt($("#wiz-channel").value) || 11,
      ai_enabled: $("#wiz-ai-toggle").checked,
      content_packs: content,
      create_vault: $("#wiz-vault-toggle").checked,
      vault_name: $("#wiz-vault-name").value || "Personal",
      vault_passphrase: $("#wiz-vault-pass").value || "",
      vault_size: $("#wiz-vault-size").value || "500MB"
    };

    fetch("/api/setup/complete", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    })
      .then(function (r) {
        if (!r.ok) throw new Error();
        location.reload();
      })
      .catch(function () {
        btn.disabled = false;
        btn.textContent = "Retry";
      });
  }
})();
