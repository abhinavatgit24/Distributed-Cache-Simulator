package com.cachesim.model;
import java.util.List;

public record CacheStats(
        long hits, long misses, double hitRate,
        long puts, long deletes, int totalNodes,
        int healthyNodes, List<OperationResult> recentOps) {}