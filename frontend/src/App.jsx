import { useState, useEffect } from 'react'

const API = 'http://localhost:8080/api'

/** Black + cream palette — single source for contrast and “hand-rolled” UI */
const th = {
  bg: '#0a0a09',
  surface: '#121210',
  surface2: '#181816',
  border: '#2e2c27',
  borderSoft: '#3a3732',
  cream: '#f2ebe0',
  creamMuted: '#c9c2b4',
  creamFaint: '#8a8478',
  accentHit: '#7dd3a8',
  accentMiss: '#f0a0a0',
  accentPut: '#9ec5ff',
  accentDel: '#e8c27a',
  accentNode: '#c9b4f0',
  accentWarn: '#e8c27a',
  okBg: '#14261c',
  okFg: '#a8e8c4',
  okBorder: '#2d4a3a',
  errBg: '#2a1515',
  errFg: '#f0b4b4',
  errBorder: '#5a3030',
}

async function apiFetch(path, opts = {}) {
  try {
    const r = await fetch(API + path, opts)
    const text = await r.text()
    return text ? JSON.parse(text) : null
  } catch (e) {
    return null
  }
}

export default function App() {
  const [stats, setStats] = useState(null)
  const [nodes, setNodes] = useState([])
  const [ops, setOps] = useState([])
  const [connected, setConnected] = useState(false)

  const [tab, setTab] = useState('log')
  const [putKey, setPutKey] = useState('')
  const [putVal, setPutVal] = useState('')
  const [putTtl, setPutTtl] = useState('')
  const [putNode, setPutNode] = useState('')
  const [getKey, setGetKey] = useState('')
  const [delKey, setDelKey] = useState('')
  const [newNodeId, setNewNodeId] = useState('')
  const [newNodeCap, setNewNodeCap] = useState('100')
  const [result, setResult] = useState(null)

  async function refresh() {
    const [s, n] = await Promise.all([
      apiFetch('/stats'),
      apiFetch('/nodes')
    ])
    const statsPayload = s?.stats ?? null
    const nodesList = Array.isArray(n?.nodes) ? n.nodes : []
    if (s?.success && n?.success && statsPayload != null) {
      setConnected(true)
      setStats(statsPayload)
      setNodes(nodesList)
      setOps(Array.isArray(statsPayload.recentOps) ? statsPayload.recentOps : [])
    } else {
      setConnected(false)
    }
  }

  useEffect(() => {
    refresh()
    const t = setInterval(refresh, 2000)
    return () => clearInterval(t)
  }, [])

  async function run(path, opts = {}) {
    const r = await apiFetch(path, opts)
    setResult(r)
    refresh()
  }

  const s = {
    page: {
      minHeight: '100vh',
      background: th.bg,
      color: th.cream,
      fontFamily: 'Georgia, "Times New Roman", Times, serif',
      padding: '28px 24px 40px',
    },
    header: {
      display: 'grid',
      gridTemplateColumns: '1fr auto 1fr',
      alignItems: 'center',
      gap: 16,
      marginBottom: 28,
      paddingBottom: 20,
      borderBottom: `1px solid ${th.border}`,
    },
    headerSide: {
      minWidth: 0,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'flex-end',
      gap: 10,
    },
    heroTitle: {
      margin: 0,
      fontSize: 'clamp(18px, 2.6vw, 24px)',
      fontWeight: 600,
      letterSpacing: '0.01em',
      color: th.cream,
      textAlign: 'center',
      textShadow: '0 1px 0 rgba(0,0,0,0.5)',
    },
    badge: (ok) => ({
      fontSize: 12,
      padding: '6px 13px',
      borderRadius: 6,
      background: ok ? th.okBg : th.errBg,
      color: ok ? th.okFg : th.errFg,
      border: `1px solid ${ok ? th.okBorder : th.errBorder}`,
      fontWeight: 600,
      fontFamily: 'Consolas, "Courier New", monospace',
    }),
    statsRow: {
      display: 'grid',
      gridTemplateColumns: 'repeat(5, 1fr)',
      gap: 12,
      marginBottom: 24,
    },
    statCard: (accent) => ({
      background: th.surface,
      border: `1px solid ${th.border}`,
      borderLeft: `3px solid ${accent}`,
      borderRadius: 6,
      padding: '14px 16px',
      boxShadow: 'inset 0 1px 0 rgba(242,235,224,0.04)',
    }),
    statVal: { fontSize: 24, fontWeight: 700, lineHeight: 1, letterSpacing: '-0.02em', fontFamily: 'Consolas, "Courier New", monospace' },
    statLbl: { fontSize: 11, color: th.creamMuted, marginBottom: 6, textTransform: 'uppercase', letterSpacing: '0.1em', fontWeight: 600 },
    grid: {
      display: 'grid',
      gridTemplateColumns: '1fr 1fr',
      gap: 20,
    },
    card: {
      background: th.surface,
      border: `1px solid ${th.border}`,
      borderRadius: 6,
      padding: 20,
      boxShadow: 'inset 0 1px 0 rgba(242,235,224,0.05)',
    },
    sectionLabel: {
      fontSize: 11,
      color: th.creamMuted,
      textTransform: 'uppercase',
      letterSpacing: '0.12em',
      marginBottom: 14,
      fontWeight: 700,
    },
    nodeCard: (failed) => ({
      background: failed ? th.errBg : th.surface2,
      border: `1px solid ${failed ? th.errBorder : th.border}`,
      borderRadius: 6,
      padding: '12px 14px',
      marginBottom: 10,
      opacity: failed ? 1 : 1,
    }),
    bar: { background: th.border, borderRadius: 999, height: 5, overflow: 'hidden', margin: '8px 0 4px' },
    input: {
      width: '100%',
      background: th.bg,
      border: `1px solid ${th.borderSoft}`,
      borderRadius: 4,
      color: th.cream,
      padding: '10px 12px',
      fontSize: 13,
      fontFamily: 'Consolas, "Courier New", monospace',
      marginBottom: 10,
      outline: 'none',
      boxSizing: 'border-box',
    },
    select: {
      width: '100%',
      background: th.bg,
      border: `1px solid ${th.borderSoft}`,
      borderRadius: 4,
      color: th.cream,
      padding: '10px 12px',
      fontSize: 13,
      fontFamily: 'inherit',
      marginBottom: 10,
      outline: 'none',
      boxSizing: 'border-box',
      cursor: 'pointer',
    },
    fieldLbl: { fontSize: 11, color: th.creamMuted, fontWeight: 700, marginBottom: 6, display: 'block', letterSpacing: '0.06em' },
    btn: (hex) => ({
      background: `${hex}22`,
      color: hex,
      border: `1px solid ${hex}55`,
      borderRadius: 4,
      padding: '9px 16px',
      cursor: 'pointer',
      fontFamily: 'Consolas, "Courier New", monospace',
      fontSize: 12,
      fontWeight: 700,
      letterSpacing: '0.04em',
      width: '100%',
    }),
    tabBar: {
      display: 'flex',
      gap: 4,
      marginBottom: 16,
      background: th.bg,
      border: `1px solid ${th.border}`,
      borderRadius: 6,
      padding: 4,
    },
    tab: (active) => ({
      flex: 1,
      padding: '8px 0',
      fontSize: 11,
      fontFamily: 'Consolas, "Courier New", monospace',
      fontWeight: 700,
      borderRadius: 4,
      border: 'none',
      cursor: 'pointer',
      background: active ? th.surface2 : 'transparent',
      color: active ? th.cream : th.creamFaint,
      letterSpacing: '0.06em',
      boxShadow: active ? `inset 0 0 0 1px ${th.borderSoft}` : 'none',
    }),
  }

  const opColors = {
    HIT: th.accentHit,
    MISS: th.accentMiss,
    PUT: th.accentPut,
    DELETE: th.accentDel,
    NODE_ADD: th.accentNode,
    NODE_REMOVE: '#f0a878',
  }

  return (
    <div style={s.page}>
      <header style={s.header}>
        <div style={{ minWidth: 0 }} aria-hidden="true" />
        <h1 style={s.heroTitle}>Distributed Cache Simulator</h1>
        <div style={s.headerSide}>
          <span style={s.badge(connected)}>{connected ? '● connected' : '○ disconnected'}</span>
          <button type="button" onClick={refresh} style={{ ...s.btn(th.creamMuted), width: 'auto', padding: '6px 14px' }}>↻</button>
        </div>
      </header>

      <div style={s.statsRow}>
        {[
          ['Hit rate', stats ? `${stats.hitRate}%` : '—', th.accentHit],
          ['Hits', stats ? stats.hits : '—', th.accentHit],
          ['Misses', stats ? stats.misses : '—', th.accentMiss],
          ['Puts', stats ? stats.puts : '—', th.accentPut],
          ['Nodes', stats ? `${stats.healthyNodes}/${stats.totalNodes}` : '—', th.accentNode],
        ].map(([lbl, val, accent]) => (
          <div key={lbl} style={s.statCard(accent)}>
            <div style={s.statLbl}>{lbl}</div>
            <div style={{ ...s.statVal, color: accent }}>{val}</div>
          </div>
        ))}
      </div>

      <div style={s.grid}>
        <div style={s.card}>
          <div style={s.sectionLabel}>Cache nodes ({nodes.length})</div>
          {nodes.length === 0 && <div style={{ color: th.creamFaint, fontSize: 13 }}>Waiting for backend...</div>}
          {nodes.map(node => {
            const pct = node.utilization ?? 0
            const barColor = pct > 80 ? th.accentMiss : pct > 50 ? th.accentWarn : th.accentHit
            return (
              <div key={node.id} style={s.nodeCard(node.failed)}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <div style={{ fontWeight: 700, fontSize: 14, color: th.cream }}>{node.id}</div>
                    <div style={{ fontSize: 11, color: th.creamMuted }}>{node.used}/{node.capacity} keys</div>
                  </div>
                  <div style={{ display: 'flex', gap: 6 }}>
                    <button
                      type="button"
                      onClick={() => run(`/nodes/${node.id}/${node.failed ? 'restore' : 'fail'}`, { method: 'POST' })}
                      style={{ fontSize: 11, padding: '4px 9px', borderRadius: 4, cursor: 'pointer', fontFamily: 'Consolas, "Courier New", monospace', fontWeight: 700, background: node.failed ? th.okBg : th.errBg, color: node.failed ? th.okFg : th.errFg, border: `1px solid ${node.failed ? th.okBorder : th.errBorder}` }}
                    >{node.failed ? 'restore' : 'fail'}</button>
                    <button
                      type="button"
                      onClick={() => run(`/nodes/${node.id}`, { method: 'DELETE' })}
                      style={{ fontSize: 11, padding: '4px 9px', borderRadius: 4, cursor: 'pointer', fontFamily: 'Consolas, "Courier New", monospace', fontWeight: 700, background: th.surface2, color: th.creamMuted, border: `1px solid ${th.borderSoft}` }}
                    >✕</button>
                  </div>
                </div>
                <div style={s.bar}>
                  <div style={{ width: `${pct}%`, height: '100%', background: barColor, borderRadius: 999, transition: 'width 0.4s' }} />
                </div>
                <div style={{ fontSize: 10, color: th.creamFaint }}>{pct}% full</div>
                {node.keys && node.keys.length > 0 && (
                  <div style={{ marginTop: 8, display: 'flex', flexWrap: 'wrap', gap: 4 }}>
                    {node.keys.slice(0, 6).map(k => (
                      <span key={k} style={{ fontSize: 10, fontFamily: 'Consolas, "Courier New", monospace', background: `${th.accentPut}18`, color: th.accentPut, padding: '2px 7px', borderRadius: 4, border: `1px solid ${th.accentPut}44` }}>{k}</span>
                    ))}
                    {node.keys.length > 6 && <span style={{ fontSize: 10, color: th.creamFaint }}>+{node.keys.length - 6}</span>}
                  </div>
                )}
              </div>
            )
          })}
        </div>

        <div style={s.card}>
          <div style={s.tabBar}>
            {[['log','log'],['put','PUT'],['get','GET'],['del','DEL'],['node','node']].map(([id, label]) => (
              <button key={id} type="button" style={s.tab(tab === id)} onClick={() => { setTab(id); setResult(null) }}>{label}</button>
            ))}
          </div>

          {result && (
            <div style={{ marginBottom: 14, padding: '10px 12px', borderRadius: 4, background: th.okBg, border: `1px solid ${th.okBorder}`, fontSize: 12, color: th.okFg, wordBreak: 'break-all', fontFamily: 'Consolas, "Courier New", monospace' }}>
              {JSON.stringify(result)}
            </div>
          )}

          {tab === 'log' && (
            <div>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 10 }}>
                <span style={s.sectionLabel}>Recent operations</span>
                <button type="button" onClick={() => run('/stats/reset', { method: 'DELETE' })} style={{ ...s.btn(th.accentWarn), width: 'auto', padding: '4px 11px', fontSize: 11 }}>reset</button>
              </div>
              {ops.length === 0 && <div style={{ color: th.creamFaint, fontSize: 13 }}>No operations yet.</div>}
              {ops.map((op, i) => (
                <div key={i} style={{ display: 'flex', gap: 10, padding: '6px 0', borderBottom: `1px solid ${th.border}`, fontSize: 12, opacity: 1 - i * 0.04 }}>
                  <span style={{ minWidth: 64, fontWeight: 700, fontFamily: 'Consolas, "Courier New", monospace', color: opColors[op.type] || th.creamFaint }}>{op.type}</span>
                  <span style={{ flex: 1, color: th.cream }}>{op.key || '—'}</span>
                  <span style={{ color: th.creamMuted }}>→ {op.nodeId}</span>
                  {op.value && <span style={{ color: th.accentHit, maxWidth: 100, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{op.value}</span>}
                </div>
              ))}
            </div>
          )}

          {tab === 'put' && (
            <div>
              <input style={s.input} placeholder="key  e.g. user:42" value={putKey} onChange={e => setPutKey(e.target.value)} />
              <input style={s.input} placeholder="value  e.g. Alice" value={putVal} onChange={e => setPutVal(e.target.value)} />
              <input style={s.input} placeholder="TTL seconds (optional)" value={putTtl} onChange={e => setPutTtl(e.target.value)} type="number" />
              <label htmlFor="put-target-node" style={s.fieldLbl}>Target node</label>
              <select
                id="put-target-node"
                style={s.select}
                value={putNode}
                onChange={e => setPutNode(e.target.value)}
              >
                <option value="">Auto (consistent hash)</option>
                {nodes.map(n => (
                  <option key={n.id} value={n.id} disabled={n.failed}>
                    {n.id}{n.failed ? ' — unavailable' : ''}
                  </option>
                ))}
              </select>
              <p style={{ fontSize: 11, color: th.creamMuted, margin: '-4px 0 12px', lineHeight: 1.45 }}>
                Manual target skips the hash ring for this write. GET and DELETE still map the key by hash.
              </p>
              <button type="button" style={s.btn(th.accentPut)} onClick={() => {
                const ttlNum = putTtl.trim() === '' ? null : Number(putTtl)
                const body = {
                  key: putKey,
                  value: putVal,
                  ttl: Number.isFinite(ttlNum) ? ttlNum : null,
                }
                if (putNode.trim()) body.nodeId = putNode.trim()
                run('/cache', {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify(body),
                })
              }}>PUT</button>
            </div>
          )}

          {tab === 'get' && (
            <div>
              <input style={s.input} placeholder="key  e.g. user:42" value={getKey} onChange={e => setGetKey(e.target.value)} onKeyDown={e => e.key === 'Enter' && run(`/cache/${encodeURIComponent(getKey)}`)} />
              <button type="button" style={s.btn(th.accentHit)} onClick={() => run(`/cache/${encodeURIComponent(getKey)}`)}>GET</button>
            </div>
          )}

          {tab === 'del' && (
            <div>
              <input style={s.input} placeholder="key  e.g. user:42" value={delKey} onChange={e => setDelKey(e.target.value)} onKeyDown={e => e.key === 'Enter' && run(`/cache/${encodeURIComponent(delKey)}`, { method: 'DELETE' })} />
              <button type="button" style={s.btn(th.accentMiss)} onClick={() => run(`/cache/${encodeURIComponent(delKey)}`, { method: 'DELETE' })}>DELETE</button>
            </div>
          )}

          {tab === 'node' && (
            <div>
              <input style={s.input} placeholder="node id  e.g. node-4" value={newNodeId} onChange={e => setNewNodeId(e.target.value)} />
              <input style={s.input} placeholder="capacity (default 100)" value={newNodeCap} onChange={e => setNewNodeCap(e.target.value)} type="number" />
              <button type="button" style={s.btn(th.accentNode)} onClick={() => run('/nodes', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                  id: newNodeId,
                  capacity: newNodeCap === '' ? 100 : Number(newNodeCap) || 100,
                }),
              })}>ADD NODE</button>
              <div style={{ fontSize: 11, color: th.creamMuted, marginTop: 10 }}>Adding a node triggers automatic key rebalancing.</div>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
