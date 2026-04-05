import { useState, useEffect } from 'react'

const API = 'http://localhost:8080/api'

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
      background: '#f4f5f7',
      color: '#2d3142',
      fontFamily: 'system-ui, -apple-system, "Segoe UI", Roboto, sans-serif',
      padding: '28px 24px 40px',
    },
    header: {
      display: 'grid',
      gridTemplateColumns: '1fr auto 1fr',
      alignItems: 'center',
      gap: 16,
      marginBottom: 28,
      paddingBottom: 20,
      borderBottom: '1px solid #e2e5eb',
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
      fontSize: 'clamp(17px, 2.5vw, 22px)',
      fontWeight: 600,
      letterSpacing: '-0.02em',
      color: '#1a1d26',
      textAlign: 'center',
    },
    badge: (ok) => ({
      fontSize: 12,
      padding: '5px 12px',
      borderRadius: 999,
      background: ok ? '#ecfdf5' : '#fef2f2',
      color: ok ? '#047857' : '#b91c1c',
      border: `1px solid ${ok ? '#a7f3d0' : '#fecaca'}`,
      fontWeight: 500,
    }),
    statsRow: {
      display: 'grid',
      gridTemplateColumns: 'repeat(5, 1fr)',
      gap: 12,
      marginBottom: 24,
    },
    statCard: (accent) => ({
      background: '#ffffff',
      border: '1px solid #e8eaef',
      borderLeft: `3px solid ${accent}`,
      borderRadius: 10,
      padding: '14px 16px',
      boxShadow: '0 1px 2px rgba(15, 23, 42, 0.04)',
    }),
    statVal: { fontSize: 24, fontWeight: 600, lineHeight: 1, letterSpacing: '-0.02em' },
    statLbl: { fontSize: 11, color: '#8b909e', marginBottom: 6, textTransform: 'uppercase', letterSpacing: '0.07em', fontWeight: 500 },
    grid: {
      display: 'grid',
      gridTemplateColumns: '1fr 1fr',
      gap: 20,
    },
    card: {
      background: '#ffffff',
      border: '1px solid #e8eaef',
      borderRadius: 12,
      padding: 20,
      boxShadow: '0 1px 3px rgba(15, 23, 42, 0.05)',
    },
    sectionLabel: {
      fontSize: 11,
      color: '#8b909e',
      textTransform: 'uppercase',
      letterSpacing: '0.08em',
      marginBottom: 14,
      fontWeight: 600,
    },
    nodeCard: (failed) => ({
      background: failed ? '#fef2f2' : '#fafbfc',
      border: `1px solid ${failed ? '#fecaca' : '#e8eaef'}`,
      borderRadius: 10,
      padding: '12px 14px',
      marginBottom: 10,
      opacity: failed ? 0.9 : 1,
    }),
    bar: { background: '#e8eaef', borderRadius: 999, height: 5, overflow: 'hidden', margin: '8px 0 4px' },
    input: {
      width: '100%',
      background: '#ffffff',
      border: '1px solid #e2e5eb',
      borderRadius: 8,
      color: '#2d3142',
      padding: '10px 12px',
      fontSize: 13,
      fontFamily: 'ui-monospace, SFMono-Regular, Menlo, Consolas, monospace',
      marginBottom: 10,
      outline: 'none',
      boxSizing: 'border-box',
    },
    select: {
      width: '100%',
      background: '#ffffff',
      border: '1px solid #e2e5eb',
      borderRadius: 8,
      color: '#2d3142',
      padding: '10px 12px',
      fontSize: 13,
      fontFamily: 'inherit',
      marginBottom: 10,
      outline: 'none',
      boxSizing: 'border-box',
      cursor: 'pointer',
    },
    fieldLbl: { fontSize: 11, color: '#8b909e', fontWeight: 600, marginBottom: 6, display: 'block', letterSpacing: '0.04em' },
    btn: (color) => ({
      background: `${color}12`,
      color: color,
      border: `1px solid ${color}35`,
      borderRadius: 8,
      padding: '9px 16px',
      cursor: 'pointer',
      fontFamily: 'inherit',
      fontSize: 13,
      fontWeight: 600,
      width: '100%',
    }),
    tabBar: {
      display: 'flex',
      gap: 4,
      marginBottom: 16,
      background: '#f0f1f4',
      borderRadius: 10,
      padding: 4,
    },
    tab: (active) => ({
      flex: 1,
      padding: '7px 0',
      fontSize: 11,
      fontFamily: 'inherit',
      fontWeight: 600,
      borderRadius: 8,
      border: 'none',
      cursor: 'pointer',
      background: active ? '#ffffff' : 'transparent',
      color: active ? '#1a1d26' : '#8b909e',
      letterSpacing: '0.04em',
      boxShadow: active ? '0 1px 2px rgba(15, 23, 42, 0.06)' : 'none',
    }),
  }

  const opColors = { HIT: '#059669', MISS: '#dc2626', PUT: '#2563eb', DELETE: '#d97706', NODE_ADD: '#7c3aed', NODE_REMOVE: '#ea580c' }

  return (
    <div style={s.page}>
      <header style={s.header}>
        <div style={{ minWidth: 0 }} aria-hidden="true" />
        <h1 style={s.heroTitle}>Distributed Cache Simulator</h1>
        <div style={s.headerSide}>
          <span style={s.badge(connected)}>{connected ? '● connected' : '○ disconnected'}</span>
          <button type="button" onClick={refresh} style={{ ...s.btn('#64748b'), width: 'auto', padding: '6px 14px' }}>↻</button>
        </div>
      </header>

      <div style={s.statsRow}>
        {[
          ['Hit rate', stats ? `${stats.hitRate}%` : '—', '#059669'],
          ['Hits', stats ? stats.hits : '—', '#059669'],
          ['Misses', stats ? stats.misses : '—', '#dc2626'],
          ['Puts', stats ? stats.puts : '—', '#2563eb'],
          ['Nodes', stats ? `${stats.healthyNodes}/${stats.totalNodes}` : '—', '#7c3aed'],
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
          {nodes.length === 0 && <div style={{ color: '#8b909e', fontSize: 13 }}>Waiting for backend...</div>}
          {nodes.map(node => {
            const pct = node.utilization ?? 0
            const barColor = pct > 80 ? '#dc2626' : pct > 50 ? '#d97706' : '#059669'
            return (
              <div key={node.id} style={s.nodeCard(node.failed)}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <div style={{ fontWeight: 600, fontSize: 14, color: '#1a1d26' }}>{node.id}</div>
                    <div style={{ fontSize: 11, color: '#8b909e' }}>{node.used}/{node.capacity} keys</div>
                  </div>
                  <div style={{ display: 'flex', gap: 6 }}>
                    <button
                      type="button"
                      onClick={() => run(`/nodes/${node.id}/${node.failed ? 'restore' : 'fail'}`, { method: 'POST' })}
                      style={{ fontSize: 11, padding: '4px 9px', borderRadius: 6, cursor: 'pointer', fontFamily: 'inherit', background: node.failed ? '#ecfdf5' : '#fef2f2', color: node.failed ? '#047857' : '#b91c1c', border: `1px solid ${node.failed ? '#a7f3d0' : '#fecaca'}` }}
                    >{node.failed ? 'restore' : 'fail'}</button>
                    <button
                      type="button"
                      onClick={() => run(`/nodes/${node.id}`, { method: 'DELETE' })}
                      style={{ fontSize: 11, padding: '4px 9px', borderRadius: 6, cursor: 'pointer', fontFamily: 'inherit', background: '#f0f1f4', color: '#64748b', border: '1px solid #e2e5eb' }}
                    >✕</button>
                  </div>
                </div>
                <div style={s.bar}>
                  <div style={{ width: `${pct}%`, height: '100%', background: barColor, borderRadius: 999, transition: 'width 0.4s' }} />
                </div>
                <div style={{ fontSize: 10, color: '#8b909e' }}>{pct}% full</div>
                {node.keys && node.keys.length > 0 && (
                  <div style={{ marginTop: 8, display: 'flex', flexWrap: 'wrap', gap: 4 }}>
                    {node.keys.slice(0, 6).map(k => (
                      <span key={k} style={{ fontSize: 10, background: '#eff6ff', color: '#1d4ed8', padding: '2px 7px', borderRadius: 6, border: '1px solid #bfdbfe' }}>{k}</span>
                    ))}
                    {node.keys.length > 6 && <span style={{ fontSize: 10, color: '#8b909e' }}>+{node.keys.length - 6}</span>}
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
            <div style={{ marginBottom: 14, padding: '10px 12px', borderRadius: 8, background: '#ecfdf5', border: '1px solid #a7f3d0', fontSize: 12, color: '#047857', wordBreak: 'break-all', fontFamily: 'ui-monospace, SFMono-Regular, Menlo, Consolas, monospace' }}>
              {JSON.stringify(result)}
            </div>
          )}

          {tab === 'log' && (
            <div>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 10 }}>
                <span style={s.sectionLabel}>Recent operations</span>
                <button type="button" onClick={() => run('/stats/reset', { method: 'DELETE' })} style={{ ...s.btn('#d97706'), width: 'auto', padding: '4px 11px', fontSize: 11 }}>reset</button>
              </div>
              {ops.length === 0 && <div style={{ color: '#8b909e', fontSize: 13 }}>No operations yet.</div>}
              {ops.map((op, i) => (
                <div key={i} style={{ display: 'flex', gap: 10, padding: '6px 0', borderBottom: '1px solid #eef0f4', fontSize: 12, opacity: 1 - i * 0.04 }}>
                  <span style={{ minWidth: 64, fontWeight: 600, color: opColors[op.type] || '#8b909e' }}>{op.type}</span>
                  <span style={{ flex: 1, color: '#2d3142' }}>{op.key || '—'}</span>
                  <span style={{ color: '#8b909e' }}>→ {op.nodeId}</span>
                  {op.value && <span style={{ color: '#4d7c0f', maxWidth: 100, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{op.value}</span>}
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
              <p style={{ fontSize: 11, color: '#8b909e', margin: '-4px 0 12px', lineHeight: 1.45 }}>
                Manual target skips the hash ring for this write. GET and DELETE still map the key by hash.
              </p>
              <button type="button" style={s.btn('#2563eb')} onClick={() => {
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
              <button type="button" style={s.btn('#059669')} onClick={() => run(`/cache/${encodeURIComponent(getKey)}`)}>GET</button>
            </div>
          )}

          {tab === 'del' && (
            <div>
              <input style={s.input} placeholder="key  e.g. user:42" value={delKey} onChange={e => setDelKey(e.target.value)} onKeyDown={e => e.key === 'Enter' && run(`/cache/${encodeURIComponent(delKey)}`, { method: 'DELETE' })} />
              <button type="button" style={s.btn('#dc2626')} onClick={() => run(`/cache/${encodeURIComponent(delKey)}`, { method: 'DELETE' })}>DELETE</button>
            </div>
          )}

          {tab === 'node' && (
            <div>
              <input style={s.input} placeholder="node id  e.g. node-4" value={newNodeId} onChange={e => setNewNodeId(e.target.value)} />
              <input style={s.input} placeholder="capacity (default 100)" value={newNodeCap} onChange={e => setNewNodeCap(e.target.value)} type="number" />
              <button type="button" style={s.btn('#7c3aed')} onClick={() => run('/nodes', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                  id: newNodeId,
                  capacity: newNodeCap === '' ? 100 : Number(newNodeCap) || 100,
                }),
              })}>ADD NODE</button>
              <div style={{ fontSize: 11, color: '#8b909e', marginTop: 10 }}>Adding a node triggers automatic key rebalancing.</div>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
