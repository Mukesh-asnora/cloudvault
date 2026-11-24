package com.cloudvault.metadata.service;

import com.cloudvault.metadata.dto.FileMetadataRequest;
import com.cloudvault.metadata.dto.FileMetadataResponse;
import com.cloudvault.metadata.dto.ShareRequest;
import com.cloudvault.metadata.entity.FileMetadata;
import com.cloudvault.metadata.entity.Permission;
import com.cloudvault.metadata.entity.PermissionLevel;
import com.cloudvault.metadata.exception.AccessDeniedException;
import com.cloudvault.metadata.exception.ResourceNotFoundException;
import com.cloudvault.metadata.repository.FileMetadataRepository;
import com.cloudvault.metadata.repository.PermissionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class FileMetadataService {

    private final FileMetadataRepository fileMetadataRepository;
    private final PermissionRepository permissionRepository;

    @Cacheable(value = "fileListings", key = "#ownerId + ':' + #parentFolderId")
    @Transactional(readOnly = true)
    public List<FileMetadataResponse> listFiles(UUID ownerId, UUID parentFolderId) {
        // Files this user owns, in the requested folder
        List<FileMetadata> owned = (parentFolderId == null)
                ? fileMetadataRepository.findByOwnerIdAndParentFolderIdIsNull(ownerId)
                : fileMetadataRepository.findByOwnerIdAndParentFolderId(ownerId, parentFolderId);

        List<FileMetadataResponse> result = owned.stream()
                .map(FileMetadataResponse::ownedBy)
                .collect(Collectors.toList());

        // Files shared with this user (only shown at the root listing,
        // regardless of what folder they originally lived in for the owner -
        // shared items are flattened into one "shared with me" view)
        if (parentFolderId == null) {
            List<Permission> permissions = permissionRepository.findByUserId(ownerId);
            for (Permission permission : permissions) {
                fileMetadataRepository.findById(permission.getFileId()).ifPresent(file ->
                        result.add(FileMetadataResponse.sharedWith(file, permission.getLevel()))
                );
            }
        }

        return result;
    }

    @Transactional(readOnly = true)
    public FileMetadataResponse getFile(UUID fileId, UUID callerId) {
        FileMetadata file = getFileOrThrow(fileId);

        if (file.getOwnerId().equals(callerId)) {
            return FileMetadataResponse.ownedBy(file);
        }

        Permission permission = permissionRepository.findByFileIdAndUserId(fileId, callerId)
                .orElseThrow(() -> new AccessDeniedException("You do not have access to this file"));

        return FileMetadataResponse.sharedWith(file, permission.getLevel());
    }

    @CacheEvict(value = "fileListings", allEntries = true)
    @Transactional
    public FileMetadataResponse createFile(UUID ownerId, FileMetadataRequest request) {
        FileMetadata file = FileMetadata.builder()
                .name(request.name())
                .sizeBytes(request.sizeBytes())
                .contentType(request.contentType())
                .ownerId(ownerId)
                .parentFolderId(request.parentFolderId())
                .s3Key(request.s3Key())
                .isFolder(Boolean.TRUE.equals(request.isFolder()))
                .build();

        fileMetadataRepository.save(file);
        return FileMetadataResponse.ownedBy(file);
    }

    @CacheEvict(value = "fileListings", allEntries = true)
    @Transactional
    public FileMetadataResponse rename(UUID fileId, UUID callerId, String newName) {
        FileMetadata file = getFileOrThrow(fileId);
        assertCanEdit(file, callerId);
        file.setName(newName);
        fileMetadataRepository.save(file);
        return FileMetadataResponse.ownedBy(file);
    }

    @CacheEvict(value = "fileListings", allEntries = true)
    @Transactional
    public void delete(UUID fileId, UUID callerId) {
        FileMetadata file = getFileOrThrow(fileId);
        assertIsOwner(file, callerId);
        fileMetadataRepository.delete(file);
    }

    @Transactional
    public void share(UUID fileId, UUID callerId, ShareRequest request) {
        FileMetadata file = getFileOrThrow(fileId);
        assertIsOwner(file, callerId);

        if (request.targetUserId().equals(callerId)) {
            throw new AccessDeniedException("You cannot share a file with yourself");
        }

        Permission permission = Permission.builder()
                .fileId(fileId)
                .userId(request.targetUserId())
                .level(request.level())
                .build();

        permissionRepository.save(permission);
    }

    private FileMetadata getFileOrThrow(UUID fileId) {
        return fileMetadataRepository.findById(fileId)
                .orElseThrow(() -> new ResourceNotFoundException("File not found: " + fileId));
    }

    private void assertIsOwner(FileMetadata file, UUID callerId) {
        if (!file.getOwnerId().equals(callerId)) {
            throw new AccessDeniedException("Only the owner can perform this action");
        }
    }

    private void assertCanEdit(FileMetadata file, UUID callerId) {
        if (file.getOwnerId().equals(callerId)) {
            return;
        }
        boolean hasEditPermission = permissionRepository.findByFileIdAndUserId(file.getId(), callerId)
                .map(p -> p.getLevel() == PermissionLevel.EDITOR || p.getLevel() == PermissionLevel.OWNER)
                .orElse(false);
        if (!hasEditPermission) {
            throw new AccessDeniedException("You do not have permission to edit this file");
        }
    }
}