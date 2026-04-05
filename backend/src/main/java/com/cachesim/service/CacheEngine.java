package com.cachesim.service;

import com.cachesim.model.*;
import org.springframework.stereotype.Service;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicLong;

@Service
public class CacheEngine {

    private final ConsistentHashRing ring;
    private final ConcurrentHashMap<String, CacheNode> nodes = new ConcurrentHashMap<>();
    private final AtomicLong hits    = new AtomicLong();
    private final AtomicLong misses  = new AtomicLong();
    private final AtomicLong puts    = new AtomicLong();
    private final AtomicLong deletes = new AtomicLong();
    private final Deque<OperationResult> recentOps = new ArrayDeque<>();
    private static final int MAX_RECENT = 100;
    /** Keys written via explicit target node — rebalance must not relocate them. */
    private final Set<String> manualTargetKeys = ConcurrentHashMap.newKeySet();

    public CacheEngine(ConsistentHashRing ring) {
        this.ring = ring;
        addNodeInternal("node-1", 100);
        addNodeInternal("node-2", 100);
        addNodeInternal("node-3", 100);
    }

    public OperationResult put(String key, String value, Long ttlSeconds) {
        return put(key, value, ttlSeconds, null);
    }

    /** @param targetNodeId if non-null and non-blank, store on that node; otherwise use the hash ring. */
    public OperationResult put(String key, String value, Long ttlSeconds, String targetNodeId) {
        String nodeId;
        CacheNode node;
        if (targetNodeId != null && !targetNodeId.isBlank()) {
            nodeId = targetNodeId.trim();
            node = nodes.get(nodeId);
            if (node == null) throw new IllegalArgumentException("Node '" + nodeId + "' not found");
            if (node.isFailed()) throw new IllegalStateException("Node " + nodeId + " is unavailable");
            manualTargetKeys.add(key);
        } else {
            manualTargetKeys.remove(key);
            nodeId = ring.getNode(key);
            if (nodeId == null) throw new IllegalStateException("No nodes available");
            node = nodes.get(nodeId);
            if (node == null || node.isFailed()) throw new IllegalStateException("Node " + nodeId + " is unavailable");
            for (CacheNode n : nodes.values()) {
                if (!n.getId().equals(nodeId)) n.delete(key);
            }
        }
        node.put(key, value, ttlSeconds);
        puts.incrementAndGet();
        return log(new OperationResult("PUT", key, nodeId, value, null, null));
    }

    public OperationResult get(String key) {
        String nodeId = ring.getNode(key);
        if (nodeId == null) throw new IllegalStateException("No nodes available");
        CacheNode node = nodes.get(nodeId);
        if (node == null || node.isFailed()) {
            misses.incrementAndGet();
            return log(new OperationResult("MISS", key, nodeId, null, "node_down", null));
        }
        Optional<String> value = node.get(key);
        if (value.isPresent()) {
            hits.incrementAndGet();
            return log(new OperationResult("HIT", key, nodeId, value.get(), null, null));
        } else {
            misses.incrementAndGet();
            return log(new OperationResult("MISS", key, nodeId, null, null, null));
        }
    }

    public OperationResult delete(String key) {
        String nodeId = ring.getNode(key);
        if (nodeId == null) throw new IllegalStateException("No nodes available");
        CacheNode node = nodes.get(nodeId);
        if (node == null || node.isFailed()) throw new IllegalStateException("Node " + nodeId + " is unavailable");
        boolean existed = node.delete(key);
        if (!existed && manualTargetKeys.contains(key)) {
            for (CacheNode n : nodes.values()) {
                if (n.delete(key)) { existed = true; break; }
            }
        }
        if (existed) manualTargetKeys.remove(key);
        deletes.incrementAndGet();
        return log(new OperationResult("DELETE", key, nodeId, null, null, existed));
    }

    public CacheNode addNode(String id, int capacity) {
        if (nodes.containsKey(id)) throw new IllegalArgumentException("Node '" + id + "' already exists");
        CacheNode node = addNodeInternal(id, capacity);
        rebalance();
        log(new OperationResult("NODE_ADD", null, id, null, null, null));
        return node;
    }

    public void removeNode(String id) {
        CacheNode target = nodes.get(id);
        if (target == null) throw new IllegalArgumentException("Node '" + id + "' not found");
        for (Map.Entry<String, CacheNode.CacheEntry> e : target.snapshot().entrySet()) {
            ring.removeNode(id);
            String newNodeId = ring.getNode(e.getKey());
            if (newNodeId != null) {
                CacheNode dest = nodes.get(newNodeId);
                if (dest != null) {
                    dest.put(e.getKey(), e.getValue().value(), e.getValue().expiresAt());
                    manualTargetKeys.remove(e.getKey());
                }
            }
            ring.addNode(id);
        }
        ring.removeNode(id);
        nodes.remove(id);
        log(new OperationResult("NODE_REMOVE", null, id, null, null, null));
    }

    private CacheNode addNodeInternal(String id, int capacity) {
        CacheNode node = new CacheNode(id, capacity);
        nodes.put(id, node);
        ring.addNode(id);
        return node;
    }

    private void rebalance() {
        List<Map.Entry<String, String>> displaced = new ArrayList<>();
        for (CacheNode node : nodes.values()) {
            for (Map.Entry<String, CacheNode.CacheEntry> e : node.snapshot().entrySet()) {
                if (manualTargetKeys.contains(e.getKey())) continue;
                String correct = ring.getNode(e.getKey());
                if (!node.getId().equals(correct)) { displaced.add(Map.entry(e.getKey(), e.getValue().value())); node.delete(e.getKey()); }
            }
        }
        for (Map.Entry<String, String> e : displaced) { String nid = ring.getNode(e.getKey()); if (nid != null) nodes.get(nid).put(e.getKey(), e.getValue(), null); }
    }

    public List<NodeStatus> getNodes() {
        return nodes.values().stream()
                .map(n -> new NodeStatus(n.getId(), n.getCapacity(), n.size(),
                        n.getCapacity() == 0 ? 0 : (int) Math.round((double) n.size() / n.getCapacity() * 100),
                        n.isFailed(), n.getCreatedAt().toString(), n.keys()))
                .sorted(Comparator.comparing(NodeStatus::id)).toList();
    }

    public CacheStats getStats() {
        long h = hits.get(), m = misses.get(), total = h + m;
        double hitRate = total == 0 ? 0.0 : Math.round((double) h / total * 1000.0) / 10.0;
        long healthy = nodes.values().stream().filter(n -> !n.isFailed()).count();
        return new CacheStats(h, m, hitRate, puts.get(), deletes.get(), nodes.size(), (int) healthy,
                new ArrayList<>(recentOps).subList(0, Math.min(20, recentOps.size())));
    }

    public void resetStats() { hits.set(0); misses.set(0); puts.set(0); deletes.set(0); recentOps.clear(); }
    public int getRingSize() { return ring.getRingSize(); }

    public void setNodeFailed(String id, boolean failed) {
        CacheNode n = nodes.get(id);
        if (n == null) throw new IllegalArgumentException("Node '" + id + "' not found");
        n.setFailed(failed);
    }

    private synchronized OperationResult log(OperationResult r) {
        recentOps.addFirst(r);
        while (recentOps.size() > MAX_RECENT) recentOps.removeLast();
        return r;
    }
}