package com.cloudvault.file.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.util.UUID;

public record InitUploadRequest(
        @NotBlank String fileName,
        @NotNull @Min(1) Long totalSizeBytes,
        @NotNull @Min(1) Integer totalChunks,
        String contentType,
        UUID parentFolderId
) {}
