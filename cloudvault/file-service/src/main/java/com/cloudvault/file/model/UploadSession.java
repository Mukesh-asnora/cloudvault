package com.cloudvault.file.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UploadSession {
    private String uploadId;
    private UUID ownerId;
    private String fileName;
    private Long totalSizeBytes;
    private Integer totalChunks;
    private String contentType;
    private UUID parentFolderId;
    private String s3Key;
    private String s3MultipartUploadId;
}
