package com.cloudvault.file.controller;

import com.cloudvault.file.dto.CompleteUploadResponse;
import com.cloudvault.file.dto.InitUploadRequest;
import com.cloudvault.file.dto.InitUploadResponse;
import com.cloudvault.file.dto.UploadStatusResponse;
import com.cloudvault.file.service.ChunkedUploadService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.UUID;

@RestController
@RequestMapping("/files/upload")
@RequiredArgsConstructor
public class FileUploadController {

    private final ChunkedUploadService chunkedUploadService;

    @PostMapping("/init")
    public ResponseEntity<InitUploadResponse> initUpload(@Valid @RequestBody InitUploadRequest request) {
        UUID ownerId = currentUserId();
        return ResponseEntity.status(HttpStatus.CREATED).body(chunkedUploadService.initUpload(ownerId, request));
    }

    @PutMapping("/{uploadId}/chunk/{chunkNumber}")
    public ResponseEntity<Void> uploadChunk(
            @PathVariable String uploadId,
            @PathVariable int chunkNumber,
            @RequestParam("file") MultipartFile file
    ) {
        chunkedUploadService.uploadChunk(uploadId, chunkNumber, file);
        return ResponseEntity.ok().build();
    }

    @GetMapping("/{uploadId}/status")
    public ResponseEntity<UploadStatusResponse> getStatus(@PathVariable String uploadId) {
        return ResponseEntity.ok(chunkedUploadService.getStatus(uploadId));
    }

    @PostMapping("/{uploadId}/complete")
    public ResponseEntity<CompleteUploadResponse> completeUpload(
            @PathVariable String uploadId,
            @RequestHeader("Authorization") String authorizationHeader
    ) {
        return ResponseEntity.ok(chunkedUploadService.completeUpload(uploadId, authorizationHeader));
    }

    @DeleteMapping("/{uploadId}")
    public ResponseEntity<Void> abortUpload(@PathVariable String uploadId) {
        chunkedUploadService.abortUpload(uploadId);
        return ResponseEntity.noContent().build();
    }

    private UUID currentUserId() {
        String principal = (String) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        return UUID.fromString(principal);
    }
}
