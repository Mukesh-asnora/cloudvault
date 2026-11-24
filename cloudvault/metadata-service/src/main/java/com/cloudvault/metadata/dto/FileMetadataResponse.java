package com.cloudvault.metadata.dto;

import com.cloudvault.metadata.entity.FileMetadata;
import com.cloudvault.metadata.entity.PermissionLevel;

import java.time.Instant;
import java.util.UUID;

public record FileMetadataResponse(
        UUID id,
        String name,
        Long sizeBytes,
        String contentType,
        boolean isFolder,
        UUID parentFolderId,
        String s3Key,
        Instant createdAt,
        boolean isOwner,
        PermissionLevel permissionLevel  // null if isOwner is true
) {
    public static FileMetadataResponse ownedBy(FileMetadata entity) {
        return new FileMetadataResponse(
                entity.getId(), entity.getName(), entity.getSizeBytes(), entity.getContentType(),
                entity.isFolder(), entity.getParentFolderId(), entity.getS3Key(), entity.getCreatedAt(),
                true, null
        );
    }

    public static FileMetadataResponse sharedWith(FileMetadata entity, PermissionLevel level) {
        return new FileMetadataResponse(
                entity.getId(), entity.getName(), entity.getSizeBytes(), entity.getContentType(),
                entity.isFolder(), entity.getParentFolderId(), entity.getS3Key(), entity.getCreatedAt(),
                false, level
        );
    }
}