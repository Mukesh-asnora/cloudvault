package com.cloudvault.file.dto;

import java.util.UUID;

public record CompleteUploadResponse(
        UUID fileId,
        String name,
        Long sizeBytes,
        String contentType
) {}
