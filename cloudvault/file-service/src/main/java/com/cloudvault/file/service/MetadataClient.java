package com.cloudvault.file.service;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

import java.util.UUID;

@Component
@RequiredArgsConstructor
public class MetadataClient {

    private final RestTemplate restTemplate;

    @Value("${metadata-service.url}")
    private String metadataServiceUrl;

    public FileRecord registerFile(
            String authorizationHeader, String name, Long sizeBytes,
            String contentType, UUID parentFolderId, String s3Key
    ) {
        HttpHeaders headers = new HttpHeaders();
        headers.set("Authorization", authorizationHeader);
        headers.set("Content-Type", "application/json");

        var body = new CreateFileRequestBody(name, sizeBytes, contentType, parentFolderId, s3Key, false);
        HttpEntity<CreateFileRequestBody> entity = new HttpEntity<>(body, headers);

        return restTemplate.exchange(
                metadataServiceUrl + "/metadata/files", HttpMethod.POST, entity, FileRecord.class
        ).getBody();
    }

    /**
     * Confirms the caller actually has access to this file before file-service
     * generates a presigned URL for it. metadata-service independently
     * verifies the forwarded JWT and checks ownership/Permission rows -
     * file-service never touches that data directly.
     *
     * Returns null if the caller has no access (metadata-service returns 403/404).
     */
    public FileRecord getFileIfAuthorized(String authorizationHeader, UUID fileId) {
        HttpHeaders headers = new HttpHeaders();
        headers.set("Authorization", authorizationHeader);
        HttpEntity<Void> entity = new HttpEntity<>(headers);

        try {
            return restTemplate.exchange(
                    metadataServiceUrl + "/metadata/files/" + fileId, HttpMethod.GET, entity, FileRecord.class
            ).getBody();
        } catch (HttpClientErrorException.Forbidden | HttpClientErrorException.NotFound e) {
            return null;
        }
    }

    private record CreateFileRequestBody(
            String name, Long sizeBytes, String contentType, UUID parentFolderId, String s3Key, Boolean isFolder
    ) {}

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record FileRecord(UUID id, String name, Long sizeBytes, String contentType, String s3Key) {}
}