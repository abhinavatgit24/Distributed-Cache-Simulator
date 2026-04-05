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