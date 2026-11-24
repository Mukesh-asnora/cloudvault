package com.cloudvault.metadata.repository;

import com.cloudvault.metadata.entity.FileMetadata;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface FileMetadataRepository extends JpaRepository<FileMetadata, UUID> {
    List<FileMetadata> findByOwnerIdAndParentFolderId(UUID ownerId, UUID parentFolderId);
    List<FileMetadata> findByOwnerIdAndParentFolderIdIsNull(UUID ownerId);
}