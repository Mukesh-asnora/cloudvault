package com.cloudvault.metadata.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "file_metadata")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FileMetadata {

    @Id
    @GeneratedValue
    private UUID id;

    @Column(nullable = false)
    private String name;

    @Column(name = "size_bytes")
    private Long sizeBytes;

    @Column(name = "content_type")
    private String contentType;

    @Column(name = "owner_id", nullable = false)
    private UUID ownerId;

    @Column(name = "parent_folder_id")
    private UUID parentFolderId;

    @Column(name = "is_folder", nullable = false)
    @Builder.Default
    private boolean isFolder = false;

    // Pointer to the actual bytes in S3/MinIO - set by file-service after upload completes.
    // Null for folders, which have no backing object.
    @Column(name = "s3_key")
    private String s3Key;

    @Column(nullable = false)
    @Builder.Default
    private Integer version = 1;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    void onCreate() {
        Instant now = Instant.now();
        this.createdAt = now;
        this.updatedAt = now;
    }

    @PreUpdate
    void onUpdate() {
        this.updatedAt = Instant.now();
    }
}
