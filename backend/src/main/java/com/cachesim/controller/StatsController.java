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