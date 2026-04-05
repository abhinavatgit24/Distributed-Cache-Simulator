package com.cachesim.model;
import java.util.List;

public record NodeStatus(
        String id, int capacity, int used, int utilization,
        boolean failed, String createdAt, List<String> keys) {}