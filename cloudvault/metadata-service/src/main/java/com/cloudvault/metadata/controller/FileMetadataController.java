package com.cloudvault.metadata.controller;

import com.cloudvault.metadata.dto.FileMetadataRequest;
import com.cloudvault.metadata.dto.FileMetadataResponse;
import com.cloudvault.metadata.dto.RenameRequest;
import com.cloudvault.metadata.dto.ShareRequest;
import com.cloudvault.metadata.service.FileMetadataService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/metadata/files")
@RequiredArgsConstructor
public class FileMetadataController {

    private final FileMetadataService fileMetadataService;

    @GetMapping
    public ResponseEntity<List<FileMetadataResponse>> listFiles(
            @RequestParam(required = false) UUID parentFolderId) {
        return ResponseEntity.ok(fileMetadataService.listFiles(currentUserId(), parentFolderId));
    }

    // Called by file-service (server-to-server, JWT forwarded) to confirm
    // the caller has access to a file before generating a download URL.
    // Also usable directly by the frontend for a "file details" view later.
    @GetMapping("/{id}")
    public ResponseEntity<FileMetadataResponse> getFile(@PathVariable UUID id) {
        return ResponseEntity.ok(fileMetadataService.getFile(id, currentUserId()));
    }

    @PostMapping
    public ResponseEntity<FileMetadataResponse> createFile(@Valid @RequestBody FileMetadataRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(fileMetadataService.createFile(currentUserId(), request));
    }

    @PatchMapping("/{id}")
    public ResponseEntity<FileMetadataResponse> rename(
            @PathVariable UUID id, @Valid @RequestBody RenameRequest request) {
        return ResponseEntity.ok(fileMetadataService.rename(id, currentUserId(), request.newName()));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable UUID id) {
        fileMetadataService.delete(id, currentUserId());
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{id}/share")
    public ResponseEntity<Void> share(@PathVariable UUID id, @Valid @RequestBody ShareRequest request) {
        fileMetadataService.share(id, currentUserId(), request);
        return ResponseEntity.ok().build();
    }

    private UUID currentUserId() {
        String principal = (String) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        return UUID.fromString(principal);
    }
}