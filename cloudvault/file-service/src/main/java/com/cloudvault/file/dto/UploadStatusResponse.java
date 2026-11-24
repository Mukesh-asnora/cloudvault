package com.cloudvault.file.dto;

import java.util.List;

public record UploadStatusResponse(
        String uploadId,
        int totalChunks,
        List<Integer> receivedChunks,
        List<Integer> missingChunks
) {}
