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