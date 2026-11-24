package com.cloudvault.file.service;

import com.cloudvault.file.dto.CompleteUploadResponse;
import com.cloudvault.file.dto.InitUploadRequest;
import com.cloudvault.file.dto.InitUploadResponse;
import com.cloudvault.file.dto.UploadStatusResponse;
import com.cloudvault.file.exception.UploadException;
import com.cloudvault.file.model.UploadSession;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.*;

import java.io.IOException;
import java.time.Duration;
import java.util.*;
import java.util.stream.Collectors;
import java.util.stream.IntStream;

@Service
public class ChunkedUploadService {

    private final S3Client s3Client;
    private final StringRedisTemplate redisTemplate;
    private final ObjectMapper objectMapper;
    private final MetadataClient metadataClient;
    private final String bucketName;

    private static final Duration SESSION_TTL = Duration.ofHours(24);
    private static final String SESSION_KEY_PREFIX = "upload-session:";
    private static final String PARTS_KEY_PREFIX = "upload-parts:";

    public ChunkedUploadService(
            S3Client s3Client,
            StringRedisTemplate redisTemplate,
            ObjectMapper objectMapper,
            MetadataClient metadataClient,
            @Value("${s3.bucket}") String bucketName
    ) {
        this.s3Client = s3Client;
        this.redisTemplate = redisTemplate;
        this.objectMapper = objectMapper;
        this.metadataClient = metadataClient;
        this.bucketName = bucketName;
    }

    public InitUploadResponse initUpload(UUID ownerId, InitUploadRequest request) {
        String uploadId = UUID.randomUUID().toString();
        String s3Key = ownerId + "/" + UUID.randomUUID() + "-" + sanitize(request.fileName());

        CreateMultipartUploadRequest createRequest = CreateMultipartUploadRequest.builder()
                .bucket(bucketName)
                .key(s3Key)
                .contentType(request.contentType())
                .build();

        CreateMultipartUploadResponse s3Response = s3Client.createMultipartUpload(createRequest);

        UploadSession session = UploadSession.builder()
                .uploadId(uploadId)
                .ownerId(ownerId)
                .fileName(request.fileName())
                .totalSizeBytes(request.totalSizeBytes())
                .totalChunks(request.totalChunks())
                .contentType(request.contentType())
                .parentFolderId(request.parentFolderId())
                .s3Key(s3Key)
                .s3MultipartUploadId(s3Response.uploadId())
                .build();

        saveSession(session);

        return new InitUploadResponse(uploadId, request.totalChunks());
    }

    public void uploadChunk(String uploadId, int chunkNumber, MultipartFile file) {
        UploadSession session = loadSession(uploadId);

        if (chunkNumber < 1 || chunkNumber > session.getTotalChunks()) {
            throw new UploadException("Chunk number " + chunkNumber + " is out of range for this upload");
        }

        byte[] bytes;
        try {
            bytes = file.getBytes();
        } catch (IOException e) {
            throw new UploadException("Failed to read chunk bytes: " + e.getMessage());
        }

        UploadPartRequest partRequest = UploadPartRequest.builder()
                .bucket(bucketName)
                .key(session.getS3Key())
                .uploadId(session.getS3MultipartUploadId())
                .partNumber(chunkNumber)
                .build();

        UploadPartResponse partResponse = s3Client.uploadPart(partRequest, RequestBody.fromBytes(bytes));

        redisTemplate.opsForHash().put(PARTS_KEY_PREFIX + uploadId, String.valueOf(chunkNumber), partResponse.eTag());
        redisTemplate.expire(PARTS_KEY_PREFIX + uploadId, SESSION_TTL);
    }

    public UploadStatusResponse getStatus(String uploadId) {
        UploadSession session = loadSession(uploadId);
        Set<Integer> received = receivedChunkNumbers(uploadId);

        List<Integer> missing = IntStream.rangeClosed(1, session.getTotalChunks())
                .filter(n -> !received.contains(n))
                .boxed()
                .collect(Collectors.toList());

        return new UploadStatusResponse(
                uploadId,
                session.getTotalChunks(),
                received.stream().sorted().collect(Collectors.toList()),
                missing
        );
    }

    public CompleteUploadResponse completeUpload(String uploadId, String authorizationHeader) {
        UploadSession session = loadSession(uploadId);
        Set<Integer> received = receivedChunkNumbers(uploadId);

        if (received.size() != session.getTotalChunks()) {
            throw new UploadException(String.format(
                    "Cannot complete upload: %d of %d chunks received. Missing: %s",
                    received.size(), session.getTotalChunks(),
                    IntStream.rangeClosed(1, session.getTotalChunks())
                            .filter(n -> !received.contains(n))
                            .boxed().collect(Collectors.toList())
            ));
        }

        Map<Object, Object> parts = redisTemplate.opsForHash().entries(PARTS_KEY_PREFIX + uploadId);

        List<CompletedPart> completedParts = parts.entrySet().stream()
                .map(e -> CompletedPart.builder()
                        .partNumber(Integer.valueOf((String) e.getKey()))
                        .eTag((String) e.getValue())
                        .build())
                .sorted(Comparator.comparingInt(CompletedPart::partNumber))
                .collect(Collectors.toList());

        CompleteMultipartUploadRequest completeRequest = CompleteMultipartUploadRequest.builder()
                .bucket(bucketName)
                .key(session.getS3Key())
                .uploadId(session.getS3MultipartUploadId())
                .multipartUpload(CompletedMultipartUpload.builder().parts(completedParts).build())
                .build();

        s3Client.completeMultipartUpload(completeRequest);

        MetadataClient.FileRecord record = metadataClient.registerFile(
                authorizationHeader,
                session.getFileName(),
                session.getTotalSizeBytes(),
                session.getContentType(),
                session.getParentFolderId(),
                session.getS3Key()
        );

        cleanupSession(uploadId);

        return new CompleteUploadResponse(record.id(), record.name(), record.sizeBytes(), record.contentType());
    }

    public void abortUpload(String uploadId) {
        UploadSession session = loadSession(uploadId);

        AbortMultipartUploadRequest abortRequest = AbortMultipartUploadRequest.builder()
                .bucket(bucketName)
                .key(session.getS3Key())
                .uploadId(session.getS3MultipartUploadId())
                .build();

        s3Client.abortMultipartUpload(abortRequest);
        cleanupSession(uploadId);
    }

    private void saveSession(UploadSession session) {
        try {
            String json = objectMapper.writeValueAsString(session);
            redisTemplate.opsForValue().set(SESSION_KEY_PREFIX + session.getUploadId(), json, SESSION_TTL);
        } catch (Exception e) {
            throw new UploadException("Failed to save upload session: " + e.getMessage());
        }
    }

    private UploadSession loadSession(String uploadId) {
        String json = redisTemplate.opsForValue().get(SESSION_KEY_PREFIX + uploadId);
        if (json == null) {
            throw new UploadException("Upload session not found or expired: " + uploadId);
        }
        try {
            return objectMapper.readValue(json, UploadSession.class);
        } catch (Exception e) {
            throw new UploadException("Corrupted upload session: " + e.getMessage());
        }
    }

    private Set<Integer> receivedChunkNumbers(String uploadId) {
        Map<Object, Object> parts = redisTemplate.opsForHash().entries(PARTS_KEY_PREFIX + uploadId);
        return parts.keySet().stream()
                .map(k -> Integer.valueOf((String) k))
                .collect(Collectors.toSet());
    }

    private void cleanupSession(String uploadId) {
        redisTemplate.delete(SESSION_KEY_PREFIX + uploadId);
        redisTemplate.delete(PARTS_KEY_PREFIX + uploadId);
    }

    private String sanitize(String fileName) {
        return fileName.replaceAll("[^a-zA-Z0-9._-]", "_");
    }
}
