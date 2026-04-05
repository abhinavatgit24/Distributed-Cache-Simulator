package com.cachesim.service;

import java.time.Instant;
import java.util.*;
import java.util.concurrent.locks.*;

public class CacheNode {

    private final String id;
    private final int capacity;
    private final Instant createdAt;
    private volatile boolean failed = false;
    private final ReadWriteLock lock = new ReentrantReadWriteLock();

    private final LinkedHashMap<String, CacheEntry> data;

    public CacheNode(String id, int capacity) {
        this.id = id;
        this.capacity = capacity;
        this.createdAt = Instant.now();
        this.data = new LinkedHashMap<>(16, 0.75f, true) {
            @Override
            protected boolean removeEldestEntry(Map.Entry<String, CacheEntry> eldest) {
                return size() > capacity;
            }
        };
    }

    public void put(String key, String value, Long ttlSeconds) {
        lock.writeLock().lock();
        try {
            Long expiresAt = ttlSeconds != null ? Instant.now().getEpochSecond() + ttlSeconds : null;
            data.put(key, new CacheEntry(value, expiresAt));
        } finally { lock.writeLock().unlock(); }
    }

    public boolean delete(String key) {
        lock.writeLock().lock();
        try { return data.remove(key) != null; }
        finally { lock.writeLock().unlock(); }
    }

    public void clear() {
        lock.writeLock().lock();
        try { data.clear(); }
        finally { lock.writeLock().unlock(); }
    }

    public Optional<String> get(String key) {
        lock.writeLock().lock();
        try {
            CacheEntry entry = data.get(key);
            if (entry == null) return Optional.empty();
            if (entry.expiresAt() != null && Instant.now().getEpochSecond() > entry.expiresAt()) {
                data.remove(key);
                return Optional.empty();
            }
            return Optional.of(entry.value());
        } finally { lock.writeLock().unlock(); }
    }

    public Map<String, CacheEntry> snapshot() {
        lock.readLock().lock();
        try { return new LinkedHashMap<>(data); }
        finally { lock.readLock().unlock(); }
    }

    public List<String> keys() {
        lock.readLock().lock();
        try { return new ArrayList<>(data.keySet()); }
        finally { lock.readLock().unlock(); }
    }

    public int size() {
        lock.readLock().lock();
        try { return data.size(); }
        finally { lock.readLock().unlock(); }
    }

    public String getId()          { return id; }
    public int getCapacity()       { return capacity; }
    public Instant getCreatedAt()  { return createdAt; }
    public boolean isFailed()      { return failed; }
    public void setFailed(boolean v) { this.failed = v; }

    public record CacheEntry(String value, Long expiresAt) {}
}