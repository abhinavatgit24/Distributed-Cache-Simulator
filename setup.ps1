# CacheSim Java - Full Project Setup Script
# Run this from inside your cachesim-java folder in VSCode terminal

Write-Host "Creating CacheSim project structure..." -ForegroundColor Cyan

# ── Create all directories ────────────────────────────────────────────────────
$dirs = @(
  "backend/src/main/java/com/cachesim/config",
  "backend/src/main/java/com/cachesim/controller",
  "backend/src/main/java/com/cachesim/service",
  "backend/src/main/java/com/cachesim/model",
  "backend/src/main/java/com/cachesim/repository",
  "backend/src/main/resources",
  "frontend/src/components",
  "frontend/src/pages",
  "frontend/src/api",
  "frontend/src/store"
)
foreach ($d in $dirs) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
Write-Host "  Directories created" -ForegroundColor Green

# ── Helper function ───────────────────────────────────────────────────────────
function Write-File($path, $content) {
  $dir = Split-Path $path
  if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [System.IO.File]::WriteAllText($path, $content, [System.Text.Encoding]::UTF8)
}

# ══════════════════════════════════════════════════════════════════════════════
# BACKEND FILES
# ══════════════════════════════════════════════════════════════════════════════

Write-File "backend/pom.xml" @'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.3.0</version>
    <relativePath/>
  </parent>
  <groupId>com.cachesim</groupId>
  <artifactId>cachesim-backend</artifactId>
  <version>1.0.0</version>
  <properties>
    <java.version>17</java.version>
  </properties>
  <dependencies>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-data-mongodb</artifactId>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-validation</artifactId>
    </dependency>
    <dependency>
      <groupId>org.projectlombok</groupId>
      <artifactId>lombok</artifactId>
      <optional>true</optional>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-test</artifactId>
      <scope>test</scope>
    </dependency>
  </dependencies>
  <build>
    <plugins>
      <plugin>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-maven-plugin</artifactId>
        <configuration>
          <excludes>
            <exclude>
              <groupId>org.projectlombok</groupId>
              <artifactId>lombok</artifactId>
            </exclude>
          </excludes>
        </configuration>
      </plugin>
    </plugins>
  </build>
</project>
'@

Write-File "backend/src/main/resources/application.yml" @'
server:
  port: 8080

spring:
  data:
    mongodb:
      uri: mongodb://localhost:27017/cachesim
      auto-index-creation: true
  jackson:
    default-property-inclusion: non_null
    serialization:
      write-dates-as-timestamps: false

logging:
  level:
    com.cachesim: DEBUG
'@

Write-File "backend/src/main/java/com/cachesim/CacheSimApplication.java" @'
package com.cachesim;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class CacheSimApplication {
    public static void main(String[] args) {
        SpringApplication.run(CacheSimApplication.class, args);
    }
}
'@

Write-File "backend/src/main/java/com/cachesim/config/WebConfig.java" @'
package com.cachesim.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.*;

@Configuration
public class WebConfig implements WebMvcConfigurer {
    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
                .allowedOrigins("http://localhost:3000", "http://localhost:5173")
                .allowedMethods("GET", "POST", "DELETE", "PUT", "OPTIONS")
                .allowedHeaders("*");
    }
}
'@

Write-File "backend/src/main/java/com/cachesim/service/ConsistentHashRing.java" @'
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
'@

Write-File "backend/src/main/java/com/cachesim/service/CacheNode.java" @'
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
'@

Write-File "backend/src/main/java/com/cachesim/service/CacheEngine.java" @'
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

    public CacheEngine(ConsistentHashRing ring) {
        this.ring = ring;
        addNodeInternal("node-1", 100);
        addNodeInternal("node-2", 100);
        addNodeInternal("node-3", 100);
    }

    public OperationResult put(String key, String value, Long ttlSeconds) {
        String nodeId = ring.getNode(key);
        if (nodeId == null) throw new IllegalStateException("No nodes available");
        CacheNode node = nodes.get(nodeId);
        if (node == null || node.isFailed()) throw new IllegalStateException("Node " + nodeId + " is unavailable");
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
            if (newNodeId != null) { CacheNode dest = nodes.get(newNodeId); if (dest != null) dest.put(e.getKey(), e.getValue().value(), e.getValue().expiresAt()); }
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

    private synchronized OperationResult log(OperationResult r) {
        recentOps.addFirst(r);
        while (recentOps.size() > MAX_RECENT) recentOps.removeLast();
        return r;
    }
}
'@

Write-File "backend/src/main/java/com/cachesim/model/OperationResult.java" @'
package com.cachesim.model;

public record OperationResult(
        String type, String key, String nodeId,
        String value, String reason, Boolean existed) {}
'@

Write-File "backend/src/main/java/com/cachesim/model/NodeStatus.java" @'
package com.cachesim.model;
import java.util.List;

public record NodeStatus(
        String id, int capacity, int used, int utilization,
        boolean failed, String createdAt, List<String> keys) {}
'@

Write-File "backend/src/main/java/com/cachesim/model/CacheStats.java" @'
package com.cachesim.model;
import java.util.List;

public record CacheStats(
        long hits, long misses, double hitRate,
        long puts, long deletes, int totalNodes,
        int healthyNodes, List<OperationResult> recentOps) {}
'@

Write-File "backend/src/main/java/com/cachesim/model/OperationLog.java" @'
package com.cachesim.model;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;
import java.time.Instant;

@Document(collection = "operation_logs")
public class OperationLog {
    @Id private String id;
    private String type, key, nodeId, value, reason;
    @Indexed private Instant createdAt = Instant.now();

    public OperationLog() {}
    public OperationLog(String type, String key, String nodeId, String value, String reason) {
        this.type = type; this.key = key; this.nodeId = nodeId; this.value = value; this.reason = reason;
    }

    public String getId()         { return id; }
    public String getType()       { return type; }
    public String getKey()        { return key; }
    public String getNodeId()     { return nodeId; }
    public String getValue()      { return value; }
    public String getReason()     { return reason; }
    public Instant getCreatedAt() { return createdAt; }
    public void setType(String t)      { this.type = t; }
    public void setKey(String k)       { this.key = k; }
    public void setNodeId(String n)    { this.nodeId = n; }
    public void setValue(String v)     { this.value = v; }
    public void setReason(String r)    { this.reason = r; }
    public void setCreatedAt(Instant i){ this.createdAt = i; }
}
'@

Write-File "backend/src/main/java/com/cachesim/repository/OperationLogRepository.java" @'
package com.cachesim.repository;

import com.cachesim.model.OperationLog;
import org.springframework.data.domain.Pageable;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface OperationLogRepository extends MongoRepository<OperationLog, String> {
    List<OperationLog> findAllByOrderByCreatedAtDesc(Pageable pageable);
}
'@

Write-File "backend/src/main/java/com/cachesim/controller/CacheController.java" @'
package com.cachesim.controller;

import com.cachesim.model.OperationLog;
import com.cachesim.model.OperationResult;
import com.cachesim.repository.OperationLogRepository;
import com.cachesim.service.CacheEngine;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.Map;

@RestController
@RequestMapping("/api/cache")
public class CacheController {
    private final CacheEngine engine;
    private final OperationLogRepository logRepo;

    public CacheController(CacheEngine engine, OperationLogRepository logRepo) {
        this.engine = engine; this.logRepo = logRepo;
    }

    @PostMapping
    public ResponseEntity<?> put(@Valid @RequestBody PutRequest req) {
        try {
            OperationResult r = engine.put(req.key(), req.value(), req.ttl());
            persist(r);
            return ResponseEntity.ok(Map.of("success", true, "result", r));
        } catch (Exception e) { return ResponseEntity.badRequest().body(Map.of("error", e.getMessage())); }
    }

    @GetMapping("/{key}")
    public ResponseEntity<?> get(@PathVariable String key) {
        try {
            OperationResult r = engine.get(key);
            persist(r);
            return ResponseEntity.ok(Map.of("success", true, "result", r));
        } catch (Exception e) { return ResponseEntity.badRequest().body(Map.of("error", e.getMessage())); }
    }

    @DeleteMapping("/{key}")
    public ResponseEntity<?> delete(@PathVariable String key) {
        try {
            OperationResult r = engine.delete(key);
            persist(r);
            return ResponseEntity.ok(Map.of("success", true, "result", r));
        } catch (Exception e) { return ResponseEntity.badRequest().body(Map.of("error", e.getMessage())); }
    }

    private void persist(OperationResult r) {
        try { logRepo.save(new OperationLog(r.type(), r.key(), r.nodeId(), r.value(), r.reason())); }
        catch (Exception ignored) {}
    }

    record PutRequest(@NotBlank String key, @NotBlank String value, Long ttl) {}
}
'@

Write-File "backend/src/main/java/com/cachesim/controller/NodeController.java" @'
package com.cachesim.controller;

import com.cachesim.service.CacheEngine;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.Map;

@RestController
@RequestMapping("/api/nodes")
public class NodeController {
    private final CacheEngine engine;
    public NodeController(CacheEngine engine) { this.engine = engine; }

    @GetMapping
    public ResponseEntity<?> list() {
        return ResponseEntity.ok(Map.of("success", true, "nodes", engine.getNodes(), "ringSize", engine.getRingSize()));
    }

    @PostMapping
    public ResponseEntity<?> add(@Valid @RequestBody AddNodeRequest req) {
        try {
            engine.addNode(req.id(), req.capacity() != null ? req.capacity() : 100);
            return ResponseEntity.ok(Map.of("success", true, "nodes", engine.getNodes()));
        } catch (IllegalArgumentException e) { return ResponseEntity.badRequest().body(Map.of("error", e.getMessage())); }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> remove(@PathVariable String id) {
        try {
            engine.removeNode(id);
            return ResponseEntity.ok(Map.of("success", true, "nodes", engine.getNodes()));
        } catch (IllegalArgumentException e) { return ResponseEntity.badRequest().body(Map.of("error", e.getMessage())); }
    }

    record AddNodeRequest(@NotBlank String id, Integer capacity) {}
}
'@

Write-File "backend/src/main/java/com/cachesim/controller/StatsController.java" @'
package com.cachesim.controller;

import com.cachesim.model.OperationLog;
import com.cachesim.repository.OperationLogRepository;
import com.cachesim.service.CacheEngine;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/stats")
public class StatsController {
    private final CacheEngine engine;
    private final OperationLogRepository logRepo;

    public StatsController(CacheEngine engine, OperationLogRepository logRepo) {
        this.engine = engine; this.logRepo = logRepo;
    }

    @GetMapping
    public ResponseEntity<?> stats() {
        return ResponseEntity.ok(Map.of("success", true, "stats", engine.getStats()));
    }

    @GetMapping("/logs")
    public ResponseEntity<?> logs(@RequestParam(defaultValue = "50") int limit) {
        try {
            List<OperationLog> logs = logRepo.findAllByOrderByCreatedAtDesc(PageRequest.of(0, Math.min(limit, 200)));
            return ResponseEntity.ok(Map.of("success", true, "logs", logs));
        } catch (Exception e) {
            return ResponseEntity.ok(Map.of("success", false, "logs", List.of()));
        }
    }

    @DeleteMapping("/reset")
    public ResponseEntity<?> reset() {
        engine.resetStats();
        return ResponseEntity.ok(Map.of("success", true, "message", "Stats reset"));
    }
}
'@

Write-Host "  Backend Java files written" -ForegroundColor Green

# ══════════════════════════════════════════════════════════════════════════════
# FRONTEND FILES
# ══════════════════════════════════════════════════════════════════════════════

Write-File "frontend/package.json" @'
{
  "name": "cachesim-frontend",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "axios": "^1.7.2",
    "lucide-react": "^0.383.0",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "recharts": "^2.12.7",
    "zustand": "^4.5.4"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.3.1",
    "vite": "^5.3.1"
  }
}
'@

Write-File "frontend/vite.config.js" @'
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    proxy: {
      "/api": {
        target: "http://localhost:8080",
        changeOrigin: true,
      },
    },
  },
});
'@

Write-File "frontend/index.html" @'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>CacheSim</title>
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link href="https://fonts.googleapis.com/css2?family=DM+Mono:ital,wght@0,300;0,400;0,500;1,400&family=DM+Sans:wght@300;400;500;600&display=swap" rel="stylesheet" />
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
'@

Write-File "frontend/src/index.css" @'
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
:root {
  --white: #ffffff; --bg: #f7f7f5; --bg-card: #ffffff; --bg-hover: #f2f2ef;
  --border: #e4e4e0; --border-mid: #d4d4ce;
  --text: #1a1a18; --text-2: #6b6b65; --text-3: #a8a8a0;
  --accent: #1a1a18;
  --green: #1a7a4a; --green-bg: #edf7f2;
  --red: #b83232; --red-bg: #fdf2f2;
  --amber: #9a6b00; --amber-bg: #fdf8ed;
  --blue: #1a4fa0; --blue-bg: #eef3fd;
  --sans: "DM Sans", system-ui, sans-serif;
  --mono: "DM Mono", "Courier New", monospace;
  --r: 6px; --r-lg: 10px;
}
html, body, #root { height: 100%; background: var(--bg); color: var(--text); font-family: var(--sans); font-size: 14px; line-height: 1.5; -webkit-font-smoothing: antialiased; }
::-webkit-scrollbar { width: 3px; height: 3px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb { background: var(--border-mid); border-radius: 2px; }
input, button { font-family: inherit; }
::selection { background: #1a1a1820; }
'@

Write-File "frontend/src/main.jsx" @'
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "./index.css";
import App from "./App.jsx";
createRoot(document.getElementById("root")).render(<StrictMode><App /></StrictMode>);
'@

Write-File "frontend/src/api/client.js" @'
import axios from "axios";
const api = axios.create({ baseURL: "/api" });
export const cacheApi = {
  put:    (key, value, ttl) => api.post("/cache", { key, value, ttl }),
  get:    (key)             => api.get(`/cache/${encodeURIComponent(key)}`),
  delete: (key)             => api.delete(`/cache/${encodeURIComponent(key)}`),
};
export const nodesApi = {
  list:   ()             => api.get("/nodes"),
  add:    (id, capacity) => api.post("/nodes", { id, capacity }),
  remove: (id)           => api.delete(`/nodes/${id}`),
};
export const statsApi = {
  get:   ()           => api.get("/stats"),
  logs:  (limit = 50) => api.get(`/stats/logs?limit=${limit}`),
  reset: ()           => api.delete("/stats/reset"),
};
export default api;
'@

Write-File "frontend/src/store/useStore.js" @'
import { create } from "zustand";
import { cacheApi, nodesApi, statsApi } from "../api/client.js";

const useStore = create((set, get) => ({
  nodes: [], ringSize: 0, nodesLoading: false,
  fetchNodes: async () => {
    set({ nodesLoading: true });
    try { const res = await nodesApi.list(); set({ nodes: res.data.nodes, ringSize: res.data.ringSize }); }
    catch (e) { console.error(e); } finally { set({ nodesLoading: false }); }
  },
  addNode: async (id, capacity) => {
    const res = await nodesApi.add(id, capacity);
    set({ nodes: res.data.nodes });
    get().addLog({ type: "NODE_ADD", nodeId: id, timestamp: new Date().toISOString() });
  },
  removeNode: async (id) => {
    const res = await nodesApi.remove(id);
    set({ nodes: res.data.nodes });
    get().addLog({ type: "NODE_REMOVE", nodeId: id, timestamp: new Date().toISOString() });
  },
  lastResult: null, opLoading: false,
  doPut: async (key, value, ttl) => {
    set({ opLoading: true, lastResult: null });
    try {
      const res = await cacheApi.put(key, value, ttl || null);
      const result = { ...res.data.result, op: "PUT" };
      set({ lastResult: result }); get().addLog({ ...result, timestamp: new Date().toISOString() });
      await get().fetchNodes(); await get().fetchStats();
    } catch (e) { set({ lastResult: { error: e.response?.data?.error || e.message } }); }
    finally { set({ opLoading: false }); }
  },
  doGet: async (key) => {
    set({ opLoading: true, lastResult: null });
    try {
      const res = await cacheApi.get(key);
      const result = { ...res.data.result, op: "GET" };
      set({ lastResult: result }); get().addLog({ ...result, timestamp: new Date().toISOString() });
      await get().fetchStats();
    } catch (e) { set({ lastResult: { error: e.response?.data?.error || e.message } }); }
    finally { set({ opLoading: false }); }
  },
  doDelete: async (key) => {
    set({ opLoading: true, lastResult: null });
    try {
      const res = await cacheApi.delete(key);
      const result = { ...res.data.result, op: "DELETE" };
      set({ lastResult: result }); get().addLog({ ...result, timestamp: new Date().toISOString() });
      await get().fetchNodes(); await get().fetchStats();
    } catch (e) { set({ lastResult: { error: e.response?.data?.error || e.message } }); }
    finally { set({ opLoading: false }); }
  },
  stats: null,
  fetchStats: async () => {
    try { const res = await statsApi.get(); set({ stats: res.data.stats }); }
    catch (e) { console.error(e); }
  },
  resetStats: async () => { await statsApi.reset(); await get().fetchStats(); },
  logs: [],
  addLog: (entry) => set(s => ({ logs: [entry, ...s.logs].slice(0, 100) })),
}));

export default useStore;
'@

Write-File "frontend/src/components/Sidebar.jsx" @'
import { LayoutDashboard, Terminal, Cpu, ScrollText } from "lucide-react";
const NAV = [
  { id: "dashboard",  label: "Dashboard",  icon: LayoutDashboard },
  { id: "operations", label: "Operations", icon: Terminal },
  { id: "nodes",      label: "Nodes",      icon: Cpu },
  { id: "logs",       label: "Logs",       icon: ScrollText },
];
export default function Sidebar({ active, setActive }) {
  return (
    <aside style={{ width:200, minWidth:200, background:"var(--white)", borderRight:"1px solid var(--border)", display:"flex", flexDirection:"column" }}>
      <div style={{ padding:"22px 20px 20px", borderBottom:"1px solid var(--border)" }}>
        <div style={{ fontFamily:"var(--mono)", fontWeight:500, fontSize:13, color:"var(--text)" }}>
          cache<span style={{ color:"var(--text-3)" }}>sim</span>
        </div>
        <div style={{ fontSize:11, color:"var(--text-3)", marginTop:2 }}>Spring Boot · MongoDB</div>
      </div>
      <nav style={{ flex:1, padding:"12px 10px", display:"flex", flexDirection:"column", gap:1 }}>
        {NAV.map(({ id, label, icon: Icon }) => {
          const on = active === id;
          return (
            <button key={id} onClick={() => setActive(id)}
              style={{ display:"flex", alignItems:"center", gap:9, padding:"8px 10px", borderRadius:"var(--r)", background: on ? "var(--bg)" : "transparent", border:"none", color: on ? "var(--text)" : "var(--text-2)", cursor:"pointer", fontSize:13, fontWeight: on ? 500 : 400, width:"100%", textAlign:"left" }}
              onMouseEnter={e => { if (!on) e.currentTarget.style.background = "var(--bg-hover)"; }}
              onMouseLeave={e => { if (!on) e.currentTarget.style.background = "transparent"; }}
            >
              <Icon size={14} strokeWidth={on ? 2 : 1.5} />{label}
            </button>
          );
        })}
      </nav>
      <div style={{ padding:"14px 20px", borderTop:"1px solid var(--border)", fontSize:11, color:"var(--text-3)", fontFamily:"var(--mono)" }}>v1.0.0</div>
    </aside>
  );
}
'@

Write-File "frontend/src/components/StatCard.jsx" @'
export default function StatCard({ label, value, accent, sub }) {
  const colorMap = { green:"var(--green)", red:"var(--red)", amber:"var(--amber)", blue:"var(--blue)" };
  const color = colorMap[accent] || "var(--text)";
  return (
    <div style={{ background:"var(--white)", border:"1px solid var(--border)", borderRadius:"var(--r-lg)", padding:"18px 20px" }}>
      <div style={{ fontSize:11, color:"var(--text-3)", marginBottom:6 }}>{label}</div>
      <div style={{ fontFamily:"var(--mono)", fontSize:26, fontWeight:400, color, lineHeight:1, letterSpacing:"-.02em" }}>{value}</div>
      {sub && <div style={{ fontSize:11, color:"var(--text-3)", marginTop:6 }}>{sub}</div>}
    </div>
  );
}
'@

Write-File "frontend/src/components/NodeCard.jsx" @'
import { Trash2 } from "lucide-react";
import useStore from "../store/useStore.js";
export default function NodeCard({ node }) {
  const removeNode = useStore(s => s.removeNode);
  const pct = node.utilization;
  const barColor = pct > 80 ? "var(--red)" : pct > 50 ? "var(--amber)" : "var(--green)";
  return (
    <div style={{ background:"var(--white)", border:"1px solid var(--border)", borderRadius:"var(--r-lg)", padding:"16px 18px", display:"flex", flexDirection:"column", gap:12 }}>
      <div style={{ display:"flex", alignItems:"center", justifyContent:"space-between" }}>
        <span style={{ fontFamily:"var(--mono)", fontSize:13, fontWeight:500 }}>{node.id}</span>
        <div style={{ display:"flex", alignItems:"center", gap:10 }}>
          <div style={{ display:"flex", alignItems:"center", gap:5 }}>
            <div style={{ width:6, height:6, borderRadius:"50%", background: node.failed ? "var(--red)" : "var(--green)" }} />
            <span style={{ fontSize:11, color:"var(--text-3)" }}>{node.failed ? "offline" : "online"}</span>
          </div>
          <button onClick={() => removeNode(node.id)} style={{ background:"none", border:"none", cursor:"pointer", color:"var(--text-3)", padding:2, display:"flex", alignItems:"center" }}
            onMouseEnter={e => e.currentTarget.style.color = "var(--red)"}
            onMouseLeave={e => e.currentTarget.style.color = "var(--text-3)"}
          ><Trash2 size={12} /></button>
        </div>
      </div>
      <div>
        <div style={{ display:"flex", justifyContent:"space-between", fontSize:11, color:"var(--text-3)", marginBottom:6 }}>
          <span>{node.used} / {node.capacity} keys</span>
          <span style={{ color:barColor, fontFamily:"var(--mono)" }}>{pct}%</span>
        </div>
        <div style={{ height:2, background:"var(--border)", borderRadius:1, overflow:"hidden" }}>
          <div style={{ height:"100%", width:`${pct}%`, background:barColor, borderRadius:1, transition:"width .4s ease" }} />
        </div>
      </div>
      {node.keys.length > 0 && (
        <div style={{ display:"flex", flexWrap:"wrap", gap:4 }}>
          {node.keys.slice(0,5).map(k => (
            <span key={k} style={{ fontSize:10, padding:"2px 7px", borderRadius:"var(--r)", background:"var(--bg)", color:"var(--text-2)", border:"1px solid var(--border)", fontFamily:"var(--mono)" }}>{k}</span>
          ))}
          {node.keys.length > 5 && <span style={{ fontSize:10, color:"var(--text-3)", padding:"2px 4px" }}>+{node.keys.length - 5}</span>}
        </div>
      )}
      <div style={{ fontSize:11, color:"var(--text-3)" }}>Added {new Date(node.createdAt).toLocaleTimeString()}</div>
    </div>
  );
}
'@

Write-File "frontend/src/components/ResultDisplay.jsx" @'
import { CheckCircle2, AlertCircle, XCircle } from "lucide-react";
export default function ResultDisplay({ result }) {
  if (!result) return null;
  const isMiss = result.type === "MISS", isErr = !!result.error;
  let color = "var(--green)", bg = "var(--green-bg)", Icon = CheckCircle2, label = result.type || result.op || "OK";
  if (isMiss) { color = "var(--amber)"; bg = "var(--amber-bg)"; Icon = AlertCircle; }
  if (isErr)  { color = "var(--red)";   bg = "var(--red-bg)";   Icon = XCircle; label = "ERROR"; }
  return (
    <div style={{ background:bg, border:`1px solid ${color}30`, borderRadius:"var(--r-lg)", padding:"14px 16px", display:"flex", flexDirection:"column", gap:8 }}>
      <div style={{ display:"flex", alignItems:"center", gap:7 }}>
        <Icon size={13} color={color} strokeWidth={2} />
        <span style={{ fontSize:11, fontWeight:600, color, fontFamily:"var(--mono)", letterSpacing:".04em" }}>{label}</span>
        {result.nodeId && <span style={{ fontSize:11, color:"var(--text-3)", marginLeft:"auto", fontFamily:"var(--mono)" }}>→ {result.nodeId}</span>}
      </div>
      {result.error && <p style={{ fontSize:12, color:"var(--red)", fontFamily:"var(--mono)" }}>{result.error}</p>}
      {result.key && <div style={{ display:"flex", gap:10 }}><span style={{ fontSize:11, color:"var(--text-3)", minWidth:42 }}>key</span><span style={{ fontSize:12, fontFamily:"var(--mono)" }}>{result.key}</span></div>}
      {result.value != null && <div style={{ display:"flex", gap:10 }}><span style={{ fontSize:11, color:"var(--text-3)", minWidth:42 }}>value</span><span style={{ fontSize:12, fontFamily:"var(--mono)", color }}>{String(result.value)}</span></div>}
      {result.reason && <div style={{ display:"flex", gap:10 }}><span style={{ fontSize:11, color:"var(--text-3)", minWidth:42 }}>reason</span><span style={{ fontSize:12, fontFamily:"var(--mono)" }}>{result.reason}</span></div>}
    </div>
  );
}
'@

Write-File "frontend/src/components/LogFeed.jsx" @'
const TYPE_COLOR = {
  HIT:{ color:"var(--green)", bg:"var(--green-bg)" }, MISS:{ color:"var(--amber)", bg:"var(--amber-bg)" },
  PUT:{ color:"var(--blue)", bg:"var(--blue-bg)" }, DELETE:{ color:"var(--red)", bg:"var(--red-bg)" },
  NODE_ADD:{ color:"var(--green)", bg:"var(--green-bg)" }, NODE_REMOVE:{ color:"var(--red)", bg:"var(--red-bg)" },
};
function LogRow({ entry, index }) {
  const s = TYPE_COLOR[entry.type] || { color:"var(--text-3)", bg:"transparent" };
  const ts = entry.timestamp ? new Date(entry.timestamp).toLocaleTimeString("en-US",{hour12:false}) : "--";
  return (
    <div style={{ display:"grid", gridTemplateColumns:"68px 72px 1fr 120px", gap:12, padding:"7px 14px", borderBottom:"1px solid var(--border)", alignItems:"center", background: index===0 ? s.bg : "transparent" }}>
      <span style={{ fontSize:11, color:"var(--text-3)", fontFamily:"var(--mono)" }}>{ts}</span>
      <span style={{ fontSize:10, fontWeight:600, padding:"1px 6px", borderRadius:"var(--r)", color:s.color, background:s.bg, fontFamily:"var(--mono)", textAlign:"center" }}>{entry.type}</span>
      <span style={{ fontSize:12, fontFamily:"var(--mono)", overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>{entry.key || entry.nodeId || "—"}</span>
      <span style={{ fontSize:11, color:"var(--text-3)", fontFamily:"var(--mono)", textAlign:"right", overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>{entry.nodeId && entry.key ? entry.nodeId : ""}</span>
    </div>
  );
}
export default function LogFeed({ logs, maxHeight=400 }) {
  return (
    <div style={{ background:"var(--white)", border:"1px solid var(--border)", borderRadius:"var(--r-lg)", overflow:"hidden" }}>
      <div style={{ display:"grid", gridTemplateColumns:"68px 72px 1fr 120px", gap:12, padding:"8px 14px", borderBottom:"1px solid var(--border)", background:"var(--bg)" }}>
        {["Time","Type","Key / Node","Routed to"].map(h => <span key={h} style={{ fontSize:10, color:"var(--text-3)" }}>{h}</span>)}
      </div>
      <div style={{ maxHeight, overflowY:"auto" }}>
        {logs.length === 0
          ? <div style={{ padding:"28px 14px", textAlign:"center", color:"var(--text-3)", fontSize:12 }}>No operations yet.</div>
          : logs.map((e,i) => <LogRow key={i} entry={e} index={i} />)
        }
      </div>
    </div>
  );
}
'@

Write-File "frontend/src/components/primitives.jsx" @'
export function Input({ label, placeholder, value, onChange, type="text" }) {
  return (
    <div style={{ display:"flex", flexDirection:"column", gap:5 }}>
      {label && <label style={{ fontSize:11, color:"var(--text-3)" }}>{label}</label>}
      <input type={type} placeholder={placeholder} value={value} onChange={e => onChange(e.target.value)}
        style={{ background:"var(--white)", border:"1px solid var(--border)", borderRadius:"var(--r)", padding:"8px 11px", fontSize:13, color:"var(--text)", fontFamily:"var(--mono)", outline:"none", width:"100%" }}
        onFocus={e => e.target.style.borderColor = "var(--border-mid)"}
        onBlur={e => e.target.style.borderColor = "var(--border)"}
      />
    </div>
  );
}
export function Btn({ children, onClick, disabled, variant="default", small=false }) {
  const styles = {
    default:{ bg:"var(--text)", color:"var(--white)", border:"var(--text)" },
    ghost:  { bg:"transparent", color:"var(--text-2)", border:"var(--border)" },
    danger: { bg:"transparent", color:"var(--red)", border:"var(--border)" },
    success:{ bg:"var(--green-bg)", color:"var(--green)", border:"var(--green)30" },
  };
  const s = styles[variant];
  return (
    <button onClick={onClick} disabled={disabled}
      style={{ background:s.bg, color:s.color, border:`1px solid ${s.border}`, borderRadius:"var(--r)", padding: small ? "5px 12px" : "8px 16px", fontSize: small ? 11 : 13, fontWeight:500, cursor: disabled ? "not-allowed" : "pointer", opacity: disabled ? 0.5 : 1, display:"inline-flex", alignItems:"center", gap:6, whiteSpace:"nowrap" }}
    >{children}</button>
  );
}
'@

Write-File "frontend/src/pages/Dashboard.jsx" @'
import { useEffect } from "react";
import { PieChart, Pie, Cell, BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer } from "recharts";
import useStore from "../store/useStore.js";
import StatCard from "../components/StatCard.jsx";
import LogFeed from "../components/LogFeed.jsx";
const TIP = ({ active, payload }) => {
  if (!active || !payload?.length) return null;
  return <div style={{ background:"var(--white)", border:"1px solid var(--border)", borderRadius:"var(--r)", padding:"7px 11px", fontSize:11, fontFamily:"var(--mono)" }}>{payload[0].name}: {payload[0].value}</div>;
};
export default function Dashboard() {
  const { stats, nodes, logs, fetchStats, fetchNodes } = useStore();
  useEffect(() => {
    fetchStats(); fetchNodes();
    const iv = setInterval(() => { fetchStats(); fetchNodes(); }, 4000);
    return () => clearInterval(iv);
  }, []);
  const pieData = [{ name:"Hits", value: stats?.hits ?? 0 }, { name:"Misses", value: stats?.misses ?? 0 }];
  const barData = nodes.map(n => ({ name: n.id.replace("node-","N"), used: n.used, free: n.capacity - n.used }));
  return (
    <div style={{ padding:"28px 32px", display:"flex", flexDirection:"column", gap:28, overflowY:"auto", height:"100%" }}>
      <div>
        <h1 style={{ fontSize:18, fontWeight:600, letterSpacing:"-.02em" }}>Dashboard</h1>
        <p style={{ fontSize:12, color:"var(--text-3)", marginTop:3 }}>Auto-refreshes every 4s — Spring Boot :8080</p>
      </div>
      <div>
        <div style={{ fontSize:11, color:"var(--text-3)", marginBottom:10 }}>Overview</div>
        <div style={{ display:"grid", gridTemplateColumns:"repeat(4,1fr)", gap:12 }}>
          <StatCard label="Hit rate"     value={`${stats?.hitRate ?? 0}%`}                             accent="green" sub={`${stats?.hits ?? 0} hits`} />
          <StatCard label="Total misses" value={stats?.misses ?? 0}                                    accent="amber" />
          <StatCard label="Total PUTs"   value={stats?.puts ?? 0}                                      accent="blue" />
          <StatCard label="Nodes"        value={`${stats?.healthyNodes ?? 0} / ${stats?.totalNodes ?? 0}`} accent="green" sub="healthy" />
        </div>
      </div>
      <div>
        <div style={{ fontSize:11, color:"var(--text-3)", marginBottom:10 }}>Analytics</div>
        <div style={{ display:"grid", gridTemplateColumns:"200px 1fr", gap:12 }}>
          <div style={{ background:"var(--white)", border:"1px solid var(--border)", borderRadius:"var(--r-lg)", padding:18, display:"flex", flexDirection:"column", alignItems:"center", justifyContent:"center" }}>
            <ResponsiveContainer width="100%" height={130}>
              <PieChart><Pie data={pieData} innerRadius={38} outerRadius={58} paddingAngle={2} dataKey="value" strokeWidth={0}><Cell fill="var(--green)" /><Cell fill="var(--amber)" /></Pie><Tooltip content={<TIP />} /></PieChart>
            </ResponsiveContainer>
            <div style={{ display:"flex", gap:14, marginTop:4 }}>
              {[["Hits","var(--green)"],["Misses","var(--amber)"]].map(([l,c]) => (
                <div key={l} style={{ display:"flex", alignItems:"center", gap:5, fontSize:11, color:"var(--text-3)" }}><div style={{ width:7, height:7, borderRadius:"50%", background:c }} />{l}</div>
              ))}
            </div>
          </div>
          <div style={{ background:"var(--white)", border:"1px solid var(--border)", borderRadius:"var(--r-lg)", padding:"18px 18px 14px" }}>
            <div style={{ fontSize:11, color:"var(--text-3)", marginBottom:10 }}>Node utilization</div>
            <ResponsiveContainer width="100%" height={130}>
              <BarChart data={barData} barSize={24} barCategoryGap="40%">
                <XAxis dataKey="name" tick={{ fill:"var(--text-3)", fontSize:10, fontFamily:"var(--mono)" }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fill:"var(--text-3)", fontSize:10 }} axisLine={false} tickLine={false} />
                <Tooltip content={<TIP />} />
                <Bar dataKey="used" name="Used" fill="var(--text)" radius={[2,2,0,0]} stackId="a" />
                <Bar dataKey="free" name="Free" fill="var(--border)" radius={[2,2,0,0]} stackId="a" />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>
      <div>
        <div style={{ fontSize:11, color:"var(--text-3)", marginBottom:10 }}>Recent operations</div>
        <LogFeed logs={logs.slice(0,12)} maxHeight={220} />
      </div>
    </div>
  );
}
'@

Write-File "frontend/src/pages/Operations.jsx" @'
import { useState } from "react";
import useStore from "../store/useStore.js";
import ResultDisplay from "../components/ResultDisplay.jsx";
import { Input, Btn } from "../components/primitives.jsx";
const SAMPLE = [
  { key:"user:1001", value:"Alice" }, { key:"user:1002", value:"Bob" },
  { key:"session:a", value:"tok_xyz" }, { key:"product:5", value:"Laptop" }, { key:"cfg:theme", value:"light" },
];
export default function Operations() {
  const { doPut, doGet, doDelete, lastResult, opLoading } = useStore();
  const [putKey,setPutKey] = useState(""); const [putVal,setPutVal] = useState(""); const [putTtl,setPutTtl] = useState("");
  const [getKey,setGetKey] = useState(""); const [delKey,setDelKey] = useState("");
  const card = { background:"var(--white)", border:"1px solid var(--border)", borderRadius:"var(--r-lg)", padding:"20px 22px", display:"flex", flexDirection:"column", gap:14 };
  const badge = (label, color, bg) => (
    <div style={{ display:"inline-block", fontFamily:"var(--mono)", fontSize:10, fontWeight:600, color, letterSpacing:".06em", padding:"2px 7px", borderRadius:"var(--r)", background:bg }}>{label}</div>
  );
  return (
    <div style={{ padding:"28px 32px", display:"flex", flexDirection:"column", gap:24, overflowY:"auto", height:"100%" }}>
      <div>
        <h1 style={{ fontSize:18, fontWeight:600, letterSpacing:"-.02em" }}>Operations</h1>
        <p style={{ fontSize:12, color:"var(--text-3)", marginTop:3 }}>Execute cache operations against the cluster</p>
      </div>
      <div style={{ display:"grid", gridTemplateColumns:"repeat(3,1fr)", gap:14 }}>
        <div style={card}>
          {badge("PUT","var(--blue)","var(--blue-bg)")}
          <Input label="Key"   placeholder="user:1001" value={putKey} onChange={setPutKey} />
          <Input label="Value" placeholder="Alice"     value={putVal} onChange={setPutVal} />
          <Input label="TTL (seconds)" placeholder="60" value={putTtl} onChange={setPutTtl} type="number" />
          <Btn disabled={opLoading || !putKey || !putVal} onClick={() => doPut(putKey, putVal, putTtl ? parseInt(putTtl) : null)}>Run PUT</Btn>
        </div>
        <div style={card}>
          {badge("GET","var(--green)","var(--green-bg)")}
          <Input label="Key" placeholder="user:1001" value={getKey} onChange={setGetKey} />
          <div style={{ flex:1 }} />
          <Btn variant="success" disabled={opLoading || !getKey} onClick={() => doGet(getKey)}>Run GET</Btn>
        </div>
        <div style={card}>
          {badge("DELETE","var(--red)","var(--red-bg)")}
          <Input label="Key" placeholder="user:1001" value={delKey} onChange={setDelKey} />
          <div style={{ flex:1 }} />
          <Btn variant="danger" disabled={opLoading || !delKey} onClick={() => doDelete(delKey)}>Run DELETE</Btn>
        </div>
      </div>
      {lastResult && (
        <div>
          <div style={{ fontSize:11, color:"var(--text-3)", marginBottom:8 }}>Result</div>
          <ResultDisplay result={lastResult} />
        </div>
      )}
      <div style={{ background:"var(--white)", border:"1px solid var(--border)", borderRadius:"var(--r-lg)", padding:"18px 22px" }}>
        <div style={{ fontSize:11, color:"var(--text-3)", marginBottom:12 }}>Quick seed — insert sample data</div>
        <div style={{ display:"flex", flexWrap:"wrap", gap:6 }}>
          {SAMPLE.map(({ key, value }) => (
            <button key={key} onClick={() => doPut(key, value)}
              style={{ background:"var(--bg)", border:"1px solid var(--border)", borderRadius:"var(--r)", padding:"5px 11px", fontSize:11, fontFamily:"var(--mono)", color:"var(--text-2)", cursor:"pointer" }}
              onMouseEnter={e => { e.currentTarget.style.borderColor="var(--border-mid)"; e.currentTarget.style.color="var(--text)"; }}
              onMouseLeave={e => { e.currentTarget.style.borderColor="var(--border)"; e.currentTarget.style.color="var(--text-2)"; }}
            >{key}</button>
          ))}
        </div>
      </div>
    </div>
  );
}
'@

Write-File "frontend/src/pages/Nodes.jsx" @'
import { useEffect, useState } from "react";
import { Plus } from "lucide-react";
import useStore from "../store/useStore.js";
import NodeCard from "../components/NodeCard.jsx";
import { Input, Btn } from "../components/primitives.jsx";
export default function Nodes() {
  const { nodes, ringSize, fetchNodes, addNode, nodesLoading } = useStore();
  const [newId,setNewId] = useState(""); const [newCap,setNewCap] = useState("100");
  const [adding,setAdding] = useState(false); const [error,setError] = useState("");
  useEffect(() => { fetchNodes(); }, []);
  const handleAdd = async () => {
    if (!newId.trim()) { setError("Node ID is required"); return; }
    setAdding(true); setError("");
    try { await addNode(newId.trim(), parseInt(newCap)||100); setNewId(""); setNewCap("100"); }
    catch (e) { setError(e?.response?.data?.error || e.message); }
    setAdding(false);
  };
  return (
    <div style={{ padding:"28px 32px", display:"flex", flexDirection:"column", gap:24, overflowY:"auto", height:"100%" }}>
      <div>
        <h1 style={{ fontSize:18, fontWeight:600, letterSpacing:"-.02em" }}>Nodes</h1>
        <p style={{ fontSize:12, color:"var(--text-3)", marginTop:3 }}>Manage cache nodes in the consistent hash ring</p>
      </div>
      <div style={{ background:"var(--white)", border:"1px solid var(--border)", borderRadius:"var(--r-lg)", padding:"18px 22px", display:"flex", flexDirection:"column", gap:12 }}>
        <div style={{ fontSize:11, color:"var(--text-3)" }}>Add node</div>
        <div style={{ display:"flex", gap:10, alignItems:"flex-end", flexWrap:"wrap" }}>
          <div style={{ flex:"1 1 160px" }}><Input label="Node ID" placeholder="node-4" value={newId} onChange={setNewId} /></div>
          <div style={{ flex:"0 0 100px" }}><Input label="Capacity" placeholder="100" value={newCap} onChange={setNewCap} type="number" /></div>
          <Btn onClick={handleAdd} disabled={adding}><Plus size={13} />{adding ? "Adding…" : "Add"}</Btn>
        </div>
        {error && <div style={{ fontSize:11, color:"var(--red)", fontFamily:"var(--mono)" }}>{error}</div>}
      </div>
      <div style={{ display:"grid", gridTemplateColumns:"repeat(3,1fr)", gap:10 }}>
        {[{ label:"Physical nodes", value:nodes.length },{ label:"Virtual nodes ea", value:150 },{ label:"Ring points total", value:ringSize }].map(({ label, value }) => (
          <div key={label} style={{ background:"var(--white)", border:"1px solid var(--border)", borderRadius:"var(--r-lg)", padding:"14px 16px" }}>
            <div style={{ fontSize:11, color:"var(--text-3)", marginBottom:5 }}>{label}</div>
            <div style={{ fontFamily:"var(--mono)", fontSize:22, fontWeight:400, color:"var(--text)", letterSpacing:"-.02em" }}>{value}</div>
          </div>
        ))}
      </div>
      {nodesLoading && nodes.length === 0
        ? <div style={{ fontSize:12, color:"var(--text-3)" }}>Loading…</div>
        : <div style={{ display:"grid", gridTemplateColumns:"repeat(auto-fill,minmax(240px,1fr))", gap:12 }}>{nodes.map(n => <NodeCard key={n.id} node={n} />)}</div>
      }
    </div>
  );
}
'@

Write-File "frontend/src/pages/Logs.jsx" @'
import { useEffect, useState } from "react";
import { RefreshCw, Trash2 } from "lucide-react";
import useStore from "../store/useStore.js";
import LogFeed from "../components/LogFeed.jsx";
import { statsApi } from "../api/client.js";
import { Btn } from "../components/primitives.jsx";
export default function Logs() {
  const { logs, stats, resetStats, fetchStats } = useStore();
  const [dbLogs,setDbLogs] = useState([]); const [dbLoading,setDbLoading] = useState(false); const [tab,setTab] = useState("live");
  const fetchDb = async () => {
    setDbLoading(true);
    try { const res = await statsApi.logs(100); setDbLogs(res.data.logs || []); }
    catch (e) { console.error(e); }
    setDbLoading(false);
  };
  useEffect(() => { fetchStats(); fetchDb(); }, []);
  const Tab = ({ id, label }) => (
    <button onClick={() => setTab(id)} style={{ background:"none", border:"none", borderBottom: tab===id ? "1px solid var(--text)" : "1px solid transparent", padding:"6px 2px", marginRight:18, fontSize:12, fontWeight: tab===id ? 500 : 400, color: tab===id ? "var(--text)" : "var(--text-3)", cursor:"pointer" }}>{label}</button>
  );
  return (
    <div style={{ padding:"28px 32px", display:"flex", flexDirection:"column", gap:24, overflowY:"auto", height:"100%" }}>
      <div style={{ display:"flex", justifyContent:"space-between", alignItems:"flex-start" }}>
        <div>
          <h1 style={{ fontSize:18, fontWeight:600, letterSpacing:"-.02em" }}>Logs</h1>
          <p style={{ fontSize:12, color:"var(--text-3)", marginTop:3 }}>Live session and persistent MongoDB history</p>
        </div>
        <div style={{ display:"flex", gap:8 }}>
          <Btn variant="ghost" small onClick={() => { fetchDb(); fetchStats(); }}><RefreshCw size={11} /> Refresh</Btn>
          <Btn variant="danger" small onClick={resetStats}><Trash2 size={11} /> Reset stats</Btn>
        </div>
      </div>
      <div style={{ display:"flex", gap:24, flexWrap:"wrap" }}>
        {[{label:"Hit rate",value:`${stats?.hitRate??0}%`,color:"var(--green)"},{label:"Hits",value:stats?.hits??0,color:"var(--green)"},{label:"Misses",value:stats?.misses??0,color:"var(--amber)"},{label:"PUTs",value:stats?.puts??0,color:"var(--blue)"},{label:"DELETEs",value:stats?.deletes??0,color:"var(--red)"}].map(({ label, value, color }) => (
          <div key={label}>
            <div style={{ fontSize:11, color:"var(--text-3)", marginBottom:2 }}>{label}</div>
            <div style={{ fontFamily:"var(--mono)", fontSize:18, fontWeight:400, color, letterSpacing:"-.02em" }}>{value}</div>
          </div>
        ))}
      </div>
      <div style={{ borderBottom:"1px solid var(--border)" }}><Tab id="live" label="Live session" /><Tab id="db" label="MongoDB logs" /></div>
      {tab === "live"
        ? <LogFeed logs={logs} maxHeight={520} />
        : dbLoading ? <div style={{ fontSize:12, color:"var(--text-3)" }}>Loading from MongoDB…</div>
          : <LogFeed logs={dbLogs.map(l => ({ type:l.type, key:l.key, nodeId:l.nodeId, value:l.value, timestamp:l.createdAt }))} maxHeight={520} />
      }
    </div>
  );
}
'@

Write-File "frontend/src/App.jsx" @'
import { useState } from "react";
import Sidebar    from "./components/Sidebar.jsx";
import Dashboard  from "./pages/Dashboard.jsx";
import Operations from "./pages/Operations.jsx";
import Nodes      from "./pages/Nodes.jsx";
import Logs       from "./pages/Logs.jsx";
const PAGES = { dashboard:Dashboard, operations:Operations, nodes:Nodes, logs:Logs };
export default function App() {
  const [page, setPage] = useState("dashboard");
  const Page = PAGES[page] || Dashboard;
  return (
    <div style={{ display:"flex", height:"100vh", overflow:"hidden" }}>
      <Sidebar active={page} setActive={setPage} />
      <div style={{ flex:1, display:"flex", flexDirection:"column", overflow:"hidden" }}>
        <div style={{ height:44, background:"var(--white)", borderBottom:"1px solid var(--border)", display:"flex", alignItems:"center", padding:"0 28px", justifyContent:"space-between", flexShrink:0 }}>
          <div style={{ display:"flex", alignItems:"center", gap:7 }}>
            <div style={{ width:6, height:6, borderRadius:"50%", background:"var(--green)" }} />
            <span style={{ fontSize:12, color:"var(--text-3)" }}>cluster online</span>
          </div>
          <span style={{ fontSize:11, color:"var(--text-3)", fontFamily:"var(--mono)" }}>localhost:8080</span>
        </div>
        <div style={{ flex:1, overflow:"hidden" }}><Page /></div>
      </div>
      <style>{`@keyframes fadeIn{from{opacity:0;transform:translateY(-3px)}to{opacity:1;transform:translateY(0)}} input::placeholder{color:var(--text-3)} button:active:not(:disabled){opacity:.75}`}</style>
    </div>
  );
}
'@

Write-Host "  Frontend files written" -ForegroundColor Green

# ══════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "Done! Project created successfully." -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. cd backend  then  mvn spring-boot:run" -ForegroundColor White
Write-Host "  2. cd frontend  then  npm install  then  npm run dev" -ForegroundColor White
Write-Host "  3. Open http://localhost:3000" -ForegroundColor White
Write-Host ""
