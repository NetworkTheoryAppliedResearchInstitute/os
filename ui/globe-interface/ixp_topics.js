/**
 * NTARI OS — IXP Globe Extension
 * ui/globe-interface/ixp_topics.js
 * Phase 17: Globe Interface IXP Mode
 *
 * Works with the REAL globe architecture:
 *   - Globe receives data only from the WebSocket bridge at /ws/graph
 *     (messages: { type:"graph_snapshot", nodes:[...], edges:[...] })
 *   - IXP service nodes (ixp_bgp_node, ixp_fabric_node, etc.) appear as
 *     regular nodes in the snapshot once they are running
 *   - Detailed BGP peer data is fetched directly from the Looking Glass
 *     HTTP API (/lg/*) — the same backend the Looking Glass UI uses
 *   - There is no window.ntariGlobe API; this script shares page scope
 *     with index.html and can access state.nodes and bridge directly
 *
 * Integration:
 *   Include AFTER the globe's closing </script> tag in index.html:
 *     <script src="/ixp_topics.js"></script>
 *
 * What this provides:
 *   1. IXP mode toggle button — highlights IXP service nodes, dims others
 *   2. IXP status panel — live health summary for all IXP services
 *   3. BGP peer panel — polls /lg/summary every 30s in IXP mode
 *   4. Alert overlay — shows session flaps from /ixp/bgp/alerts (via own WS)
 */

/* global window, document, state */

(function (global) {
  'use strict';

  // ── IXP node name prefixes as they appear in the DDS graph ───────────────
  const IXP_NODE_PREFIXES = [
    'ixp_bgp_node',
    'ixp_fabric_node',
    'ixp_registry_node',
    'ixp_lg_node',
    'ixp_settlement_node',
  ];

  // ── State ─────────────────────────────────────────────────────────────────
  const ixp = {
    mode: 'cooperative',          // 'cooperative' | 'ixp'
    lastPeers: [],                // data from /lg/summary (parsed)
    lastAlerts: [],               // ring buffer of alert strings
    pollTimer: null,              // setInterval for Looking Glass polling
    ui: {},                       // DOM element references
  };

  // ── Get IXP nodes from the globe's live state ─────────────────────────────
  // state.nodes is the globe's internal array — shared scope with index.html
  function _ixpNodes() {
    if (typeof state === 'undefined' || !Array.isArray(state.nodes)) return [];
    return state.nodes.filter(n =>
      IXP_NODE_PREFIXES.some(prefix => (n.name || n.id || '').includes(prefix))
    );
  }

  function _isIxpNode(node) {
    return IXP_NODE_PREFIXES.some(p => (node.name || node.id || '').includes(p));
  }

  // ── Mode toggle ───────────────────────────────────────────────────────────

  function setMode(mode) {
    ixp.mode = mode;
    _applyModeToNodes();
    if (mode === 'ixp') {
      ixp.ui.toggleBtn && (ixp.ui.toggleBtn.textContent = 'Cooperative Mode');
      ixp.ui.panel && (ixp.ui.panel.style.display = 'block');
      _startPolling();
    } else {
      ixp.ui.toggleBtn && (ixp.ui.toggleBtn.textContent = 'IXP Mode');
      ixp.ui.panel && (ixp.ui.panel.style.display = 'none');
      _stopPolling();
      _applyModeToNodes(); // restore all nodes
    }
    _renderStatusPanel();
  }

  function _applyModeToNodes() {
    if (typeof state === 'undefined' || !Array.isArray(state.nodes)) return;
    state.nodes.forEach(node => {
      if (ixp.mode === 'ixp') {
        // Dim non-IXP nodes; IXP nodes keep their natural state
        node._ixpDimmed = !_isIxpNode(node);
      } else {
        // Restore all nodes
        node._ixpDimmed = false;
      }
    });
    // Force a redraw if globe exposes one (best-effort)
    if (typeof drawFrame === 'function') drawFrame();
    else if (typeof requestAnimationFrame === 'function') requestAnimationFrame(() => {});
  }

  // ── Graph snapshot handler — called via 'ntari:snapshot' DOM event ──────────
  // index.html fires this event after _applyGraphSnapshot(), so state.nodes
  // is already up-to-date when this runs.

  function _onSnapshot(snapshot) {
    if (!snapshot || !Array.isArray(snapshot.nodes)) return;
    _renderStatusPanel();
    if (ixp.mode === 'ixp') _applyModeToNodes();
  }

  // ── Looking Glass polling (IXP mode only) ─────────────────────────────────
  // Polls /lg/summary every 30s to get live BGP session data.
  // Falls back gracefully if lg is not running.

  function _startPolling() {
    if (ixp.pollTimer) return;
    _pollLg();
    ixp.pollTimer = setInterval(_pollLg, 30000);
  }

  function _stopPolling() {
    if (ixp.pollTimer) { clearInterval(ixp.pollTimer); ixp.pollTimer = null; }
  }

  async function _pollLg() {
    try {
      const resp = await fetch('/lg/summary', { signal: AbortSignal.timeout(8000) });
      if (!resp.ok) return;
      const html = await resp.text();
      // Extract the <pre> content from the HTML response
      const match = html.match(/<pre[^>]*>([\s\S]*?)<\/pre>/i);
      const text = match
        ? match[1].replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&amp;/g,'&')
        : '';
      ixp.lastPeers = _parseBgpSummary(text);
      _renderPeerTable();
    } catch (e) {
      // LG not available yet — silently skip
    }
  }

  function _parseBgpSummary(text) {
    // Parse FRR "show bgp summary" text output into a list of peer rows.
    // The established sessions appear as lines with 9+ space-separated fields
    // where the last field is "Established" or a prefix count.
    const peers = [];
    for (const line of text.split('\n')) {
      const cols = line.trim().split(/\s+/);
      if (cols.length >= 9 && /^\d+\.\d+\.\d+\.\d+$/.test(cols[0])) {
        peers.push({
          ip:       cols[0],
          asn:      cols[2] || '?',
          uptime:   cols[7] || '-',
          prefixes: cols[8] || '0',
          state:    cols[8] === '0' || /^\d+$/.test(cols[8]) ? 'Established' : cols[8],
        });
      }
    }
    return peers;
  }

  // ── Status panel rendering ────────────────────────────────────────────────

  function _renderStatusPanel() {
    if (!ixp.ui.serviceList) return;
    const nodes = _ixpNodes();

    if (!nodes.length) {
      ixp.ui.serviceList.innerHTML =
        '<div class="ixp-row ixp-muted">No IXP services active — '
        + 'start ntari-ixp-bgp to begin</div>';
      return;
    }

    ixp.ui.serviceList.innerHTML = nodes.map(n => {
      const health = (n.health || 'unknown').toLowerCase();
      const dot = health === 'healthy'  ? '🟢'
                : health === 'degraded' ? '🟡'
                : health === 'failed'   ? '🔴' : '⚪';
      const label = (n.name || n.id || '').replace('_node', '').replace(/_/g, '-');
      return `<div class="ixp-row">${dot} <span class="ixp-svc">${_escHtml(label)}</span>`
           + ` <span class="ixp-health">${_escHtml(health)}</span></div>`;
    }).join('');
  }

  function _renderPeerTable() {
    if (!ixp.ui.peerTable) return;
    if (!ixp.lastPeers.length) {
      ixp.ui.peerTable.innerHTML =
        '<div class="ixp-row ixp-muted">No BGP sessions · '
        + '<a class="ixp-link" href="/lg/summary" target="_blank">open LG</a></div>';
      return;
    }
    const header = '<div class="ixp-row ixp-header">'
      + '<span style="width:120px">Peer IP</span>'
      + '<span style="width:70px">ASN</span>'
      + '<span style="width:60px">Uptime</span>'
      + '<span style="width:60px">Prefixes</span>'
      + '</div>';
    const rows = ixp.lastPeers.slice(0, 12).map(p => {
      const dot = p.state === 'Established' ? '🟢' : '🔴';
      return `<div class="ixp-row">${dot} `
        + `<span style="width:120px;font-family:monospace">${_escHtml(p.ip)}</span>`
        + `<span style="width:70px">AS${_escHtml(p.asn)}</span>`
        + `<span style="width:60px">${_escHtml(p.uptime)}</span>`
        + `<span style="width:60px">${_escHtml(p.prefixes)}</span>`
        + `</div>`;
    }).join('');
    ixp.ui.peerTable.innerHTML = header + rows
      + `<div class="ixp-row ixp-muted" style="margin-top:6px">`
      + `<a class="ixp-link" href="/lg/" target="_blank">Full Looking Glass ↗</a></div>`;
  }

  // ── Build the UI ──────────────────────────────────────────────────────────

  function _buildUI() {
    // Shared styles
    const style = document.createElement('style');
    style.textContent = `
      #ixp-toggle-btn {
        position: fixed; top: 12px; right: 160px; z-index: 9999;
        padding: 6px 14px; background: #0d2452; color: #a8cce8;
        border: 1px solid #1a3a5c; border-radius: 4px;
        font: 12px 'JetBrains Mono', monospace; cursor: pointer;
        letter-spacing: 0.5px; transition: background 0.15s, border-color 0.15s;
      }
      #ixp-toggle-btn:hover { background: #1a3a5c; border-color: #4ab3ff; color: #ddeeff; }
      #ixp-toggle-btn.ixp-active { background: #1a237e; border-color: #448aff; color: #fff; }

      #ixp-panel {
        position: fixed; bottom: 12px; right: 12px; width: 340px;
        z-index: 9998; background: rgba(5,6,8,0.88);
        border: 1px solid #14202e; border-radius: 6px;
        font: 11px 'JetBrains Mono', monospace; color: #a8cce8;
        display: none;
      }
      #ixp-panel-header {
        padding: 8px 12px; border-bottom: 1px solid #14202e;
        color: #4ab3ff; font-size: 11px; letter-spacing: 1px;
        text-transform: uppercase;
      }
      #ixp-panel-body { padding: 8px 12px; max-height: 320px; overflow-y: auto; }
      .ixp-section-title {
        color: #3a5a7a; font-size: 10px; text-transform: uppercase;
        letter-spacing: 1px; margin: 8px 0 4px;
      }
      .ixp-row {
        display: flex; align-items: center; gap: 6px;
        padding: 2px 0; font-size: 11px; color: #a8cce8;
      }
      .ixp-row + .ixp-row { border-top: 1px solid rgba(26,58,92,0.4); }
      .ixp-header { color: #3a5a7a; font-size: 10px; }
      .ixp-muted { color: #3a5a7a; }
      .ixp-svc { flex: 1; color: #ddeeff; }
      .ixp-health { color: #7986cb; }
      .ixp-link { color: #448aff; text-decoration: none; }
      .ixp-link:hover { text-decoration: underline; }
    `;
    document.head.appendChild(style);

    // Toggle button
    const btn = document.createElement('button');
    btn.id = 'ixp-toggle-btn';
    btn.textContent = 'IXP Mode';
    btn.title = 'Switch between cooperative DDS node view and IXP service view';
    btn.addEventListener('click', () => {
      setMode(ixp.mode === 'ixp' ? 'cooperative' : 'ixp');
      btn.classList.toggle('ixp-active', ixp.mode === 'ixp');
    });
    document.body.appendChild(btn);
    ixp.ui.toggleBtn = btn;

    // Status panel
    const panel = document.createElement('div');
    panel.id = 'ixp-panel';
    panel.innerHTML = `
      <div id="ixp-panel-header">IXP Status</div>
      <div id="ixp-panel-body">
        <div class="ixp-section-title">Services</div>
        <div id="ixp-service-list"><div class="ixp-row ixp-muted">Waiting for DDS graph…</div></div>
        <div class="ixp-section-title" style="margin-top:10px">BGP Sessions</div>
        <div id="ixp-peer-table"><div class="ixp-row ixp-muted">Switch to IXP mode to poll</div></div>
      </div>
    `;
    document.body.appendChild(panel);
    ixp.ui.panel      = panel;
    ixp.ui.serviceList = panel.querySelector('#ixp-service-list');
    ixp.ui.peerTable   = panel.querySelector('#ixp-peer-table');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  function _escHtml(str) {
    return String(str)
      .replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  function init() {
    _buildUI();

    // Receive graph snapshots via the globe's existing WebSocket connection.
    // index.html dispatches 'ntari:snapshot' after each _applyGraphSnapshot()
    // call, so state.nodes is already populated when we receive this event.
    document.addEventListener('ntari:snapshot', (evt) => _onSnapshot(evt.detail));

    // Fallback: refresh status panel on a timer in case no snapshot arrives
    // (e.g. bridge is down but IXP mode was already active from a prior snapshot)
    setInterval(() => {
      if (ixp.mode === 'ixp') {
        _renderStatusPanel();
        _applyModeToNodes();
      }
    }, 15000);

    console.log('[ixp_topics] IXP globe extension loaded');
  }

  // Expose public API
  global.ixpTopics = { setMode, getMode: () => ixp.mode };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})(window);
