package com.cachesim.service;

import org.springframework.stereotype.Component;
import java.util.*;

@Component
public class ConsistentHashRing {

    private static final int VIRTUAL_NODES = 150;
    private final TreeMap<Integer, String> ring = new TreeMap<>();

    public synchronized void addNode(String nodeId) {
        for (int i = 0; i < VIRTUAL_NODES; i++) {
            ring.put(hash(nodeId + "#vnode" + i), nodeId);
        }
    }

    public synchronized void removeNode(String nodeId) {
        for (int i = 0; i < VIRTUAL_NODES; i++) {
            ring.remove(hash(nodeId + "#vnode" + i));
        }
    }

    public synchronized String getNode(String key) {
        if (ring.isEmpty()) return null;
        Map.Entry<Integer, String> entry = ring.ceilingEntry(hash(key));
        return (entry != null ? entry : ring.firstEntry()).getValue();
    }

    public synchronized int getRingSize() { return ring.size(); }
    public synchronized boolean isEmpty() { return ring.isEmpty(); }

    private int hash(String key) {
        int h = 5381;
        for (char c : key.toCharArray()) h = ((h << 5) + h) ^ c;
        return Math.abs(h) % Integer.MAX_VALUE;
    }
}