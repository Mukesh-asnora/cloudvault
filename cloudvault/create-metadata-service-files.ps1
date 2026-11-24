
$base = "metadata-service\src\main\java\com\cloudvault\metadata"
$dirs = @("config","entity","repository","dto","security","service","controller","exception")
foreach ($d in $dirs) { New-Item -ItemType Directory -Force -Path "$base\$d" | Out-Null }
New-Item -ItemType Directory -Force -Path "metadata-service\src\main\resources" | Out-Null

Set-Content "$base\MetadataServiceApplication.java" @'
package com.cloudvault.metadata;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cache.annotation.EnableCaching;

@SpringBootApplication
@EnableCaching
public class MetadataServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(MetadataServiceApplication.class, args);
    }
}
'@

Set-Content "$base\entity\PermissionLevel.java" @'
package com.cloudvault.metadata.entity;

public enum PermissionLevel {
    OWNER,
    EDITOR,
    VIEWER
}
'@

Set-Content "$base\entity\FileMetadata.java" @'
package com.cloudvault.metadata.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "file_metadata")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FileMetadata {

    @Id
    @GeneratedValue
    private UUID id;

    @Column(nullable = false)
    private String name;

    @Column(name = "size_bytes")
    private Long sizeBytes;

    @Column(name = "content_type")
    private String contentType;

    @Column(name = "owner_id", nullable = false)
    private UUID ownerId;

    @Column(name = "parent_folder_id")
    private UUID parentFolderId;

    @Column(name = "is_folder", nullable = false)
    @Builder.Default
    private boolean isFolder = false;

    // Pointer to the actual bytes in S3/MinIO - set by file-service after upload completes.
    // Null for folders, which have no backing object.
    @Column(name = "s3_key")
    private String s3Key;

    @Column(nullable = false)
    @Builder.Default
    private Integer version = 1;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    void onCreate() {
        Instant now = Instant.now();
        this.createdAt = now;
        this.updatedAt = now;
    }

    @PreUpdate
    void onUpdate() {
        this.updatedAt = Instant.now();
    }
}
'@

Set-Content "$base\entity\Permission.java" @'
package com.cloudvault.metadata.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "permissions")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Permission {

    @Id
    @GeneratedValue
    private UUID id;

    @Column(name = "file_id", nullable = false)
    private UUID fileId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(nullable = false)
    @Enumerated(EnumType.STRING)
    private PermissionLevel level;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    void onCreate() {
        this.createdAt = Instant.now();
    }
}
'@

Set-Content "$base\repository\FileMetadataRepository.java" @'
package com.cloudvault.metadata.repository;

import com.cloudvault.metadata.entity.FileMetadata;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface FileMetadataRepository extends JpaRepository<FileMetadata, UUID> {
    List<FileMetadata> findByOwnerIdAndParentFolderId(UUID ownerId, UUID parentFolderId);
    List<FileMetadata> findByOwnerIdAndParentFolderIdIsNull(UUID ownerId);
}
'@

Set-Content "$base\repository\PermissionRepository.java" @'
package com.cloudvault.metadata.repository;

import com.cloudvault.metadata.entity.Permission;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface PermissionRepository extends JpaRepository<Permission, UUID> {
    Optional<Permission> findByFileIdAndUserId(UUID fileId, UUID userId);
    boolean existsByFileIdAndUserId(UUID fileId, UUID userId);
}
'@

Set-Content "$base\dto\FileMetadataRequest.java" @'
package com.cloudvault.metadata.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.util.UUID;

public record FileMetadataRequest(
        @NotBlank String name,
        Long sizeBytes,
        String contentType,
        UUID parentFolderId,
        String s3Key,
        @NotNull Boolean isFolder
) {}
'@

Set-Content "$base\dto\FileMetadataResponse.java" @'
package com.cloudvault.metadata.dto;

import com.cloudvault.metadata.entity.FileMetadata;

import java.time.Instant;
import java.util.UUID;

public record FileMetadataResponse(
        UUID id,
        String name,
        Long sizeBytes,
        String contentType,
        boolean isFolder,
        UUID parentFolderId,
        Instant createdAt
) {
    public static FileMetadataResponse from(FileMetadata entity) {
        return new FileMetadataResponse(
                entity.getId(),
                entity.getName(),
                entity.getSizeBytes(),
                entity.getContentType(),
                entity.isFolder(),
                entity.getParentFolderId(),
                entity.getCreatedAt()
        );
    }
}
'@

Set-Content "$base\dto\RenameRequest.java" @'
package com.cloudvault.metadata.dto;

import jakarta.validation.constraints.NotBlank;

public record RenameRequest(@NotBlank String newName) {}
'@

Set-Content "$base\dto\ShareRequest.java" @'
package com.cloudvault.metadata.dto;

import com.cloudvault.metadata.entity.PermissionLevel;
import jakarta.validation.constraints.NotNull;

import java.util.UUID;

public record ShareRequest(
        @NotNull UUID targetUserId,
        @NotNull PermissionLevel level
) {}
'@

Set-Content "$base\exception\ResourceNotFoundException.java" @'
package com.cloudvault.metadata.exception;

public class ResourceNotFoundException extends RuntimeException {
    public ResourceNotFoundException(String message) {
        super(message);
    }
}
'@

Set-Content "$base\exception\AccessDeniedException.java" @'
package com.cloudvault.metadata.exception;

public class AccessDeniedException extends RuntimeException {
    public AccessDeniedException(String message) {
        super(message);
    }
}
'@

Set-Content "$base\security\JwtService.java" @'
package com.cloudvault.metadata.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;

/**
 * Independently re-validates JWTs issued by auth-service, using the same
 * shared secret. This service never assumes "the gateway already checked
 * the token" - it checks again itself. Defense in depth.
 */
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
package com.cloudvault.metadata.security;

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
                // Invalid/expired token - leave SecurityContext empty, request will be rejected downstream
                SecurityContextHolder.clearContext();
            }
        }

        chain.doFilter(request, response);
    }
}
'@

Set-Content "$base\config\SecurityConfig.java" @'
package com.cloudvault.metadata.config;

import com.cloudvault.metadata.security.JwtAuthFilter;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.List;

@Configuration
@EnableWebSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtAuthFilter jwtAuthFilter;

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                .cors(cors -> cors.configurationSource(corsConfigurationSource()))
                .csrf(csrf -> csrf.disable())
                .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers("/actuator/health/**").permitAll()
                        .anyRequest().authenticated()
                )
                .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOrigins(List.of("http://localhost:3000"));
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));
        config.setAllowCredentials(true);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }
}
'@

Set-Content "$base\config\CacheConfig.java" @'
package com.cloudvault.metadata.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.json.JsonMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.cache.RedisCacheConfiguration;
import org.springframework.data.redis.cache.RedisCacheManagerBuilderCustomizer;
import org.springframework.data.redis.serializer.GenericJackson2JsonRedisSerializer;
import org.springframework.data.redis.serializer.RedisSerializationContext;

import java.time.Duration;

@Configuration
public class CacheConfig {

    // 60s TTL - short-lived on purpose. Metadata changes (renames, deletes,
    // new uploads) should become visible quickly rather than being cached
    // for a long time.
    @Bean
    public RedisCacheManagerBuilderCustomizer redisCacheManagerBuilderCustomizer() {
        ObjectMapper mapper = JsonMapper.builder().addModule(new JavaTimeModule()).build();
        GenericJackson2JsonRedisSerializer serializer = new GenericJackson2JsonRedisSerializer(mapper);

        return builder -> builder.cacheDefaults(
                RedisCacheConfiguration.defaultCacheConfig()
                        .entryTtl(Duration.ofSeconds(60))
                        .serializeValuesWith(RedisSerializationContext.SerializationPair.fromSerializer(serializer))
        );
    }
}
'@

Set-Content "$base\service\FileMetadataService.java" @'
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
        List<FileMetadata> files = (parentFolderId == null)
                ? fileMetadataRepository.findByOwnerIdAndParentFolderIdIsNull(ownerId)
                : fileMetadataRepository.findByOwnerIdAndParentFolderId(ownerId, parentFolderId);

        return files.stream().map(FileMetadataResponse::from).collect(Collectors.toList());
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
        return FileMetadataResponse.from(file);
    }

    @CacheEvict(value = "fileListings", allEntries = true)
    @Transactional
    public FileMetadataResponse rename(UUID fileId, UUID callerId, String newName) {
        FileMetadata file = getFileOrThrow(fileId);
        assertCanEdit(file, callerId);
        file.setName(newName);
        fileMetadataRepository.save(file);
        return FileMetadataResponse.from(file);
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
'@

Set-Content "$base\controller\FileMetadataController.java" @'
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
        UUID callerId = currentUserId();
        return ResponseEntity.ok(fileMetadataService.listFiles(callerId, parentFolderId));
    }

    @PostMapping
    public ResponseEntity<FileMetadataResponse> createFile(@Valid @RequestBody FileMetadataRequest request) {
        UUID callerId = currentUserId();
        return ResponseEntity.status(HttpStatus.CREATED).body(fileMetadataService.createFile(callerId, request));
    }

    @PatchMapping("/{id}")
    public ResponseEntity<FileMetadataResponse> rename(
            @PathVariable UUID id, @Valid @RequestBody RenameRequest request) {
        UUID callerId = currentUserId();
        return ResponseEntity.ok(fileMetadataService.rename(id, callerId, request.newName()));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable UUID id) {
        UUID callerId = currentUserId();
        fileMetadataService.delete(id, callerId);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{id}/share")
    public ResponseEntity<Void> share(@PathVariable UUID id, @Valid @RequestBody ShareRequest request) {
        UUID callerId = currentUserId();
        fileMetadataService.share(id, callerId, request);
        return ResponseEntity.ok().build();
    }

    private UUID currentUserId() {
        String principal = (String) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        return UUID.fromString(principal);
    }
}
'@

Set-Content "$base\controller\GlobalExceptionHandler.java" @'
package com.cloudvault.metadata.controller;

import com.cloudvault.metadata.exception.AccessDeniedException;
import com.cloudvault.metadata.exception.ResourceNotFoundException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.time.Instant;
import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(ResourceNotFoundException.class)
    public ResponseEntity<Map<String, Object>> handleNotFound(ResourceNotFoundException ex) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(body(404, "Not Found", ex.getMessage()));
    }

    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<Map<String, Object>> handleAccessDenied(AccessDeniedException ex) {
        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(body(403, "Forbidden", ex.getMessage()));
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
                .body(body(500, "Internal Server Error", "Something went wrong"));
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

Set-Content "metadata-service\src\main\resources\application.yml" @'
server:
  port: 8080

spring:
  application:
    name: metadata-service
  datasource:
    url: jdbc:postgresql://${DB_HOST:localhost}:${DB_PORT:5432}/${DB_NAME:metadata_db}
    username: ${DB_USER:cloudvault}
    password: ${DB_PASSWORD:changeme_local_only}
    hikari:
      maximum-pool-size: 10
      minimum-idle: 2
  jpa:
    hibernate:
      ddl-auto: update
    show-sql: false
  data:
    redis:
      host: ${REDIS_HOST:localhost}
      port: ${REDIS_PORT:6379}
  cache:
    type: redis

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

Write-Host "All metadata-service files created." -ForegroundColor Green
