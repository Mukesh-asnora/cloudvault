package com.cloudvault.file.controller;

import com.cloudvault.file.dto.DownloadUrlResponse;
import com.cloudvault.file.exception.UploadException;
import com.cloudvault.file.service.DownloadService;
import com.cloudvault.file.service.MetadataClient;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
public class FileDownloadController {

    private final DownloadService downloadService;
    private final MetadataClient metadataClient;

    public FileDownloadController(DownloadService downloadService, MetadataClient metadataClient) {
        this.downloadService = downloadService;
        this.metadataClient = metadataClient;
    }

    @GetMapping("/files/download")
    public ResponseEntity<DownloadUrlResponse> download(
            @RequestParam UUID fileId,
            @RequestHeader("Authorization") String authorizationHeader
    ) {
        // file-service never checks ownership itself - it defers entirely to
        // metadata-service, the single source of truth for who owns/can-access
        // a file. This is what makes sharing actually secure: a user can only
        // ever get a presigned URL for a file metadata-service confirms they
        // have a right to see.
        MetadataClient.FileRecord record = metadataClient.getFileIfAuthorized(authorizationHeader, fileId);

        if (record == null) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        }
        if (record.s3Key() == null) {
            throw new UploadException("This file has no associated storage object");
        }

        String presignedUrl = downloadService.generatePresignedDownloadUrl(record.s3Key());
        return ResponseEntity.ok(new DownloadUrlResponse(presignedUrl));
    }
}