$base = "file-service\src\main\java\com\cloudvault\file"
$dirs = @("config","controller","dto","exception","model","security","service")
foreach ($d in $dirs) { New-Item -ItemType Directory -Force -Path "$base\$d" | Out-Null }
New-Item -ItemType Directory -Force -Path "file-service\src\main\resources" | Out-Null

Set-Content "file-service\pom.xml" @'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.5</version>
        <relativePath/>
    </parent>

    <groupId>com.cloudvault</groupId>
    <artifactId>file-service</artifactId>
    <version>1.0.0</version>
    <name>file-service</name>
    <description>Chunked upload, download, and S3/MinIO storage service for CloudVault</description>

    <properties>
        <java.version>17</java.version>
        <awssdk.version>2.25.16</awssdk.version>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-security</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-redis</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-validation</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>

        <dependency>
            <groupId>software.amazon.awssdk</groupId>
            <artifactId>s3</artifactId>
            <version>${awssdk.version}</version>
        </dependency>

        <dependency>
            <groupId>io.jsonwebtoken</groupId>
            <artifactId>jjwt-api</artifactId>
            <version>0.12.5</version>
        </dependency>
        <dependency>
            <groupId>io.jsonwebtoken</groupId>
            <artifactId>jjwt-impl</artifactId>
            <version>0.12.5</version>
            <scope>runtime</scope>
        </dependency>
        <dependency>
            <groupId>io.jsonwebtoken</groupId>
            <artifactId>jjwt-jackson</artifactId>
            <version>0.12.5</version>
            <scope>runtime</scope>
        </dependency>

        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <optional>true</optional>
        </dependency>

        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
                <configuration>
                    <excludes>
                        <exclude>
                            <groupId>org.projectlombok</groupId>
                            <artifactId>lombok</artifactId>
                        </exclude>
                    </excludes>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
'@

Set-Content "$base\FileServiceApplication.java" @'
package com.cloudvault.file;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class FileServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(FileServiceApplication.class, args);
    }
}
'@

Set-Content "$base\model\UploadSession.java" @'
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
'@

Set-Content "$base\dto\InitUploadRequest.java" @'
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
'@

Set-Content "$base\dto\InitUploadResponse.java" @'
package com.cloudvault.file.dto;

public record InitUploadResponse(String uploadId, Integer totalChunks) {}
'@

Set-Content "$base\dto\UploadStatusResponse.java" @'
package com.cloudvault.file.dto;

import java.util.List;

public record UploadStatusResponse(
        String uploadId,
        int totalChunks,
        List<Integer> receivedChunks,
        List<Integer> missingChunks
) {}
'@

Set-Content "$base\dto\CompleteUploadResponse.java" @'
package com.cloudvault.file.dto;

import java.util.UUID;

public record CompleteUploadResponse(
        UUID fileId,
        String name,
        Long sizeBytes,
        String contentType
) {}
'@

Set-Content "$base\exception\UploadException.java" @'
package com.cloudvault.file.exception;

public class UploadException extends RuntimeException {
    public UploadException(String message) {
        super(message);
    }
}
'@

Set-Content "$base\security\JwtService.java" @'
package com.cloudvault.file.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;

@Component
public class JwtService {

    private final SecretKey signingKey;

    public JwtService(@Value("${jwt.secret}") String secret) {
        this.signingKey = Keys.hmacShaKeyFor(secret.getBytes());
    }

    public Claims parseClaims(String token) {
        return Jwts.parser()
                .verifyWith(signingKey)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }
}
'@

Set-Content "$base\security\JwtAuthFilter.java" @'
package com.cloudvault.file.security;

import io.jsonwebtoken.Claims;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

@Component
@RequiredArgsConstructor
public class JwtAuthFilter extends OncePerRequestFilter {

    private final JwtService jwtService;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {

        String header = request.getHeader("Authorization");

        if (header != null && header.startsWith("Bearer ")) {
            String token = header.substring(7);
            try {
                Claims claims = jwtService.parseClaims(token);
                String userId = claims.getSubject();
                String role = claims.get("role", String.class);

                var authorities = List.of(new SimpleGrantedAuthority("ROLE_" + role));
                var auth = new UsernamePasswordAuthenticationToken(userId, null, authorities);
                SecurityContextHolder.getContext().setAuthentication(auth);
            } catch (Exception ex) {
                SecurityContextHolder.clearContext();
            }
        }

        chain.doFilter(request, response);
    }
}
'@

Set-Content "$base\config\SecurityConfig.java" @'
package com.cloudvault.file.config;

import com.cloudvault.file.security.JwtAuthFilter;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

@Configuration
@EnableWebSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtAuthFilter jwtAuthFilter;

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                .csrf(csrf -> csrf.disable())
                .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers("/actuator/health/**").permitAll()
                        .anyRequest().authenticated()
                )
                .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }
}
'@

Set-Content "$base\config\RestTemplateConfig.java" @'
package com.cloudvault.file.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestTemplate;

@Configuration
public class RestTemplateConfig {

    @Bean
    public RestTemplate restTemplate() {
        return new RestTemplate();
    }
}
'@

Set-Content "$base\config\RedisConfig.java" @'
package com.cloudvault.file.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.json.JsonMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class RedisConfig {

    @Bean
    public ObjectMapper uploadSessionObjectMapper() {
        return JsonMapper.builder().addModule(new JavaTimeModule()).build();
    }
}
'@

Set-Content "$base\config\S3Config.java" @'
package com.cloudvault.file.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;

import java.net.URI;

@Configuration
public class S3Config {

    @Value("${s3.endpoint:}")
    private String endpoint;

    @Value("${s3.region:us-east-1}")
    private String region;

    @Value("${s3.access-key}")
    private String accessKey;

    @Value("${s3.secret-key}")
    private String secretKey;

    @Bean
    public S3Client s3Client() {
        var credentials = StaticCredentialsProvider.create(
                AwsBasicCredentials.create(accessKey, secretKey));

        var builder = S3Client.builder()
                .region(Region.of(region))
                .credentialsProvider(credentials)
                .serviceConfiguration(S3Configuration.builder()
                        .pathStyleAccessEnabled(true)
                        .build());

        if (endpoint != null && !endpoint.isBlank()) {
            builder.endpointOverride(URI.create(endpoint));
        }

        return builder.build();
    }

    @Bean
    public S3Presigner s3Presigner() {
        var credentials = StaticCredentialsProvider.create(
                AwsBasicCredentials.create(accessKey, secretKey));

        var builder = S3Presigner.builder()
                .region(Region.of(region))
                .credentialsProvider(credentials)
                .serviceConfiguration(S3Configuration.builder()
                        .pathStyleAccessEnabled(true)
                        .build());

        if (endpoint != null && !endpoint.isBlank()) {
            builder.endpointOverride(URI.create(endpoint));
        }

        return builder.build();
    }
}
'@

Set-Content "$base\service\MetadataClient.java" @'
package com.cloudvault.file.service;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

import java.util.UUID;

@Component
@RequiredArgsConstructor
public class MetadataClient {

    private final RestTemplate restTemplate;

    @Value("${metadata-service.url}")
    private String metadataServiceUrl;

    public FileRecord registerFile(
            String authorizationHeader,
            String name,
            Long sizeBytes,
            String contentType,
            UUID parentFolderId,
            String s3Key
    ) {
        HttpHeaders headers = new HttpHeaders();
        headers.set("Authorization", authorizationHeader);
        headers.set("Content-Type", "application/json");

        var body = new CreateFileRequestBody(name, sizeBytes, contentType, parentFolderId, s3Key, false);
        HttpEntity<CreateFileRequestBody> entity = new HttpEntity<>(body, headers);

        return restTemplate.exchange(
                metadataServiceUrl + "/metadata/files",
                HttpMethod.POST,
                entity,
                FileRecord.class
        ).getBody();
    }

    private record CreateFileRequestBody(
            String name,
            Long sizeBytes,
            String contentType,
            UUID parentFolderId,
            String s3Key,
            Boolean isFolder
    ) {}

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record FileRecord(
            UUID id,
            String name,
            Long sizeBytes,
            String contentType
    ) {}
}
'@

Set-Content "$base\service\ChunkedUploadService.java" @'
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
'@

Set-Content "$base\service\DownloadService.java" @'
package com.cloudvault.file.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;

import java.time.Duration;

@Service
public class DownloadService {

    private final S3Presigner s3Presigner;
    private final String bucketName;

    public DownloadService(S3Presigner s3Presigner, @Value("${s3.bucket}") String bucketName) {
        this.s3Presigner = s3Presigner;
        this.bucketName = bucketName;
    }

    public String generatePresignedDownloadUrl(String s3Key) {
        GetObjectRequest getObjectRequest = GetObjectRequest.builder()
                .bucket(bucketName)
                .key(s3Key)
                .build();

        GetObjectPresignRequest presignRequest = GetObjectPresignRequest.builder()
                .signatureDuration(Duration.ofMinutes(15))
                .getObjectRequest(getObjectRequest)
                .build();

        return s3Presigner.presignGetObject(presignRequest).url().toString();
    }
}
'@

Set-Content "$base\controller\FileUploadController.java" @'
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
'@

Set-Content "$base\controller\FileDownloadController.java" @'
package com.cloudvault.file.controller;

import com.cloudvault.file.service.DownloadService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.net.URI;

@RestController
public class FileDownloadController {

    private final DownloadService downloadService;

    public FileDownloadController(DownloadService downloadService) {
        this.downloadService = downloadService;
    }

    @GetMapping("/files/download")
    public ResponseEntity<Void> download(@RequestParam String s3Key) {
        String presignedUrl = downloadService.generatePresignedDownloadUrl(s3Key);
        return ResponseEntity.status(HttpStatus.FOUND)
                .location(URI.create(presignedUrl))
                .build();
    }
}
'@

Set-Content "$base\controller\GlobalExceptionHandler.java" @'
package com.cloudvault.file.controller;

import com.cloudvault.file.exception.UploadException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.time.Instant;
import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(UploadException.class)
    public ResponseEntity<Map<String, Object>> handleUploadException(UploadException ex) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(body(400, "Bad Request", ex.getMessage()));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, Object>> handleValidation(MethodArgumentNotValidException ex) {
        String message = ex.getBindingResult().getFieldErrors().stream()
                .findFirst()
                .map(fe -> fe.getField() + ": " + fe.getDefaultMessage())
                .orElse("Validation failed");
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(body(400, "Bad Request", message));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> handleGeneric(Exception ex) {
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(body(500, "Internal Server Error", "Something went wrong: " + ex.getMessage()));
    }

    private Map<String, Object> body(int status, String error, String message) {
        return Map.of(
                "timestamp", Instant.now().toString(),
                "status", status,
                "error", error,
                "message", message
        );
    }
}
'@

Set-Content "file-service\src\main\resources\application.yml" @'
server:
  port: ${SERVER_PORT:8080}

spring:
  application:
    name: file-service
  data:
    redis:
      host: ${REDIS_HOST:localhost}
      port: ${REDIS_PORT:6379}
  servlet:
    multipart:
      max-file-size: 20MB
      max-request-size: 20MB

s3:
  endpoint: ${S3_ENDPOINT:http://localhost:9000}
  region: ${S3_REGION:us-east-1}
  bucket: ${S3_BUCKET:cloudvault-files}
  access-key: ${S3_ACCESS_KEY:minioadmin}
  secret-key: ${S3_SECRET_KEY:minioadmin123}

metadata-service:
  url: ${METADATA_SERVICE_URL:http://localhost:8083}

jwt:
  secret: ${JWT_SECRET:replace_this_with_a_generated_64_byte_base64_secret}

management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus
  endpoint:
    health:
      probes:
        enabled: true
      show-details: always

logging:
  level:
    com.cloudvault: INFO
'@

Write-Host "All file-service files created." -ForegroundColor Green