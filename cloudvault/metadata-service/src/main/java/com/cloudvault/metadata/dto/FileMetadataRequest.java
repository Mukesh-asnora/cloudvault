package com.cloudvault.metadata.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.util.UUID;

public record FileMetadataRequest(
        @NotBlank String name,
        Long sizeBytes,
        String contentType,
        UUID parentFolderId,
        String s3Key,
        @NotNull Boolean isFolder
) {}
