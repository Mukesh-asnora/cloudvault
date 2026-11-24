package com.cloudvault.metadata.repository;

import com.cloudvault.metadata.entity.Permission;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface PermissionRepository extends JpaRepository<Permission, UUID> {
    Optional<Permission> findByFileIdAndUserId(UUID fileId, UUID userId);
    boolean existsByFileIdAndUserId(UUID fileId, UUID userId);
    List<Permission> findByUserId(UUID userId);
}