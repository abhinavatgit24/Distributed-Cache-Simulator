package com.cachesim.controller;

import com.cachesim.model.OperationLog;
import com.cachesim.model.OperationResult;
import com.cachesim.repository.OperationLogRepository;
import com.cachesim.service.CacheEngine;
import com.fasterxml.jackson.annotation.JsonProperty;
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
            OperationResult r = engine.put(req.key(), req.value(), req.ttl(), req.nodeId());
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

    record PutRequest(
            @NotBlank @JsonProperty("key") String key,
            @NotBlank @JsonProperty("value") String value,
            @JsonProperty("ttl") Long ttl,
            @JsonProperty("nodeId") String nodeId
    ) {}
}