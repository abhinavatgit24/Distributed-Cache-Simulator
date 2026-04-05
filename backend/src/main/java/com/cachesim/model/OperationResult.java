package com.cachesim.model;

public record OperationResult(
        String type, String key, String nodeId,
        String value, String reason, Boolean existed) {}