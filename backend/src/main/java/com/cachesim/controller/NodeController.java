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

    @PostMapping("/{id}/fail")
    public ResponseEntity<?> fail(@PathVariable String id) {
        try {
            engine.setNodeFailed(id, true);
            return ResponseEntity.ok(Map.of("success", true, "nodes", engine.getNodes()));
        } catch (IllegalArgumentException e) { return ResponseEntity.badRequest().body(Map.of("error", e.getMessage())); }
    }

    @PostMapping("/{id}/restore")
    public ResponseEntity<?> restore(@PathVariable String id) {
        try {
            engine.setNodeFailed(id, false);
            return ResponseEntity.ok(Map.of("success", true, "nodes", engine.getNodes()));
        } catch (IllegalArgumentException e) { return ResponseEntity.badRequest().body(Map.of("error", e.getMessage())); }
    }

    record AddNodeRequest(@NotBlank String id, Integer capacity) {}
}