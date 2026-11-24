$base = "auth-service\src\main\java\com\cloudvault\auth"
$dirs = @("config","entity","repository","dto","security","service","controller","exception")
foreach ($d in $dirs) { New-Item -ItemType Directory -Force -Path "$base\$d" | Out-Null }
New-Item -ItemType Directory -Force -Path "auth-service\src\main\resources" | Out-Null

Set-Content "$base\AuthServiceApplication.java" @'
package com.cloudvault.auth;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class AuthServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(AuthServiceApplication.class, args);
    }
}
'@

Set-Content "$base\entity\Role.java" @'
package com.cloudvault.auth.entity;

public enum Role {
    ADMIN,
    EDITOR,
    VIEWER
}
'@

Set-Content "$base\entity\User.java" @'
package com.cloudvault.auth.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "users", uniqueConstraints = @UniqueConstraint(columnNames = "email"))
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class User {

    @Id
    @GeneratedValue
    private UUID id;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(name = "password_hash", nullable = false)
    private String passwordHash;

    @Column(nullable = false)
    @Enumerated(EnumType.STRING)
    @Builder.Default
    private Role role = Role.VIEWER;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    void onCreate() {
        this.createdAt = Instant.now();
    }
}
'@

Set-Content "$base\repository\UserRepository.java" @'
package com.cloudvault.auth.repository;

import com.cloudvault.auth.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface UserRepository extends JpaRepository<User, UUID> {
    Optional<User> findByEmail(String email);
    boolean existsByEmail(String email);
}
'@

Set-Content "$base\dto\RegisterRequest.java" @'
package com.cloudvault.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record RegisterRequest(
        @NotBlank @Email String email,
        @NotBlank @Size(min = 8, message = "Password must be at least 8 characters") String password
) {}
'@

Set-Content "$base\dto\LoginRequest.java" @'
package com.cloudvault.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public record LoginRequest(
        @NotBlank @Email String email,
        @NotBlank String password
) {}
'@

Set-Content "$base\dto\RefreshRequest.java" @'
package com.cloudvault.auth.dto;

public record RefreshRequest(String refreshToken) {}
'@

Set-Content "$base\dto\AuthResponse.java" @'
package com.cloudvault.auth.dto;

public record AuthResponse(
        String accessToken,
        String refreshToken,
        String tokenType,
        long expiresInSeconds
) {
    public static AuthResponse of(String accessToken, String refreshToken, long expiresInSeconds) {
        return new AuthResponse(accessToken, refreshToken, "Bearer", expiresInSeconds);
    }
}
'@

Set-Content "$base\dto\ErrorResponse.java" @'
package com.cloudvault.auth.dto;

import java.time.Instant;

public record ErrorResponse(
        Instant timestamp,
        int status,
        String error,
        String message
) {
    public static ErrorResponse of(int status, String error, String message) {
        return new ErrorResponse(Instant.now(), status, error, message);
    }
}
'@

Set-Content "$base\security\JwtUtil.java" @'
package com.cloudvault.auth.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.util.Date;
import java.util.UUID;

@Component
public class JwtUtil {

    private final SecretKey signingKey;
    private final long accessTokenExpiryMs;
    private final long refreshTokenExpiryMs;

    public JwtUtil(
            @Value("${jwt.secret}") String secret,
            @Value("${jwt.expiry-minutes}") long expiryMinutes,
            @Value("${jwt.refresh-expiry-days}") long refreshExpiryDays
    ) {
        this.signingKey = Keys.hmacShaKeyFor(secret.getBytes());
        this.accessTokenExpiryMs = expiryMinutes * 60 * 1000;
        this.refreshTokenExpiryMs = refreshExpiryDays * 24 * 60 * 60 * 1000;
    }

    public String generateAccessToken(UUID userId, String email, String role) {
        Date now = new Date();
        return Jwts.builder()
                .subject(userId.toString())
                .claim("email", email)
                .claim("role", role)
                .claim("type", "access")
                .issuedAt(now)
                .expiration(new Date(now.getTime() + accessTokenExpiryMs))
                .signWith(signingKey)
                .compact();
    }

    public String generateRefreshToken(UUID userId) {
        Date now = new Date();
        return Jwts.builder()
                .subject(userId.toString())
                .claim("type", "refresh")
                .issuedAt(now)
                .expiration(new Date(now.getTime() + refreshTokenExpiryMs))
                .signWith(signingKey)
                .compact();
    }

    public long getAccessTokenExpirySeconds() {
        return accessTokenExpiryMs / 1000;
    }

    public Claims parseClaims(String token) {
        return Jwts.parser()
                .verifyWith(signingKey)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }

    public boolean isRefreshToken(Claims claims) {
        return "refresh".equals(claims.get("type", String.class));
    }
}
'@

Set-Content "$base\service\AuthService.java" @'
package com.cloudvault.auth.service;

import com.cloudvault.auth.dto.AuthResponse;
import com.cloudvault.auth.dto.LoginRequest;
import com.cloudvault.auth.dto.RegisterRequest;
import com.cloudvault.auth.entity.Role;
import com.cloudvault.auth.entity.User;
import com.cloudvault.auth.repository.UserRepository;
import com.cloudvault.auth.security.JwtUtil;
import io.jsonwebtoken.Claims;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        if (userRepository.existsByEmail(request.email())) {
            throw new IllegalStateException("An account with this email already exists");
        }

        User user = User.builder()
                .email(request.email())
                .passwordHash(passwordEncoder.encode(request.password()))
                .role(Role.VIEWER)
                .build();

        userRepository.save(user);
        return issueTokens(user);
    }

    @Transactional(readOnly = true)
    public AuthResponse login(LoginRequest request) {
        User user = userRepository.findByEmail(request.email())
                .orElseThrow(() -> new IllegalArgumentException("Invalid email or password"));

        if (!passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            throw new IllegalArgumentException("Invalid email or password");
        }

        return issueTokens(user);
    }

    @Transactional(readOnly = true)
    public AuthResponse refresh(String refreshToken) {
        Claims claims = jwtUtil.parseClaims(refreshToken);
        if (!jwtUtil.isRefreshToken(claims)) {
            throw new IllegalArgumentException("Provided token is not a refresh token");
        }

        UUID userId = UUID.fromString(claims.getSubject());
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User no longer exists"));

        return issueTokens(user);
    }

    private AuthResponse issueTokens(User user) {
        String accessToken = jwtUtil.generateAccessToken(user.getId(), user.getEmail(), user.getRole().name());
        String refreshToken = jwtUtil.generateRefreshToken(user.getId());
        return AuthResponse.of(accessToken, refreshToken, jwtUtil.getAccessTokenExpirySeconds());
    }
}
'@

Set-Content "$base\controller\AuthController.java" @'
package com.cloudvault.auth.controller;

import com.cloudvault.auth.dto.AuthResponse;
import com.cloudvault.auth.dto.LoginRequest;
import com.cloudvault.auth.dto.RefreshRequest;
import com.cloudvault.auth.dto.RegisterRequest;
import com.cloudvault.auth.service.AuthService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @PostMapping("/register")
    public ResponseEntity<AuthResponse> register(@Valid @RequestBody RegisterRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(authService.register(request));
    }

    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(@Valid @RequestBody LoginRequest request) {
        return ResponseEntity.ok(authService.login(request));
    }

    @PostMapping("/refresh")
    public ResponseEntity<AuthResponse> refresh(@Valid @RequestBody RefreshRequest request) {
        return ResponseEntity.ok(authService.refresh(request.refreshToken()));
    }
}
'@

Set-Content "$base\config\SecurityConfig.java" @'
package com.cloudvault.auth.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                .csrf(csrf -> csrf.disable())
                .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers("/auth/**", "/actuator/health/**").permitAll()
                        .anyRequest().authenticated()
                );
        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(12);
    }
}
'@

Set-Content "$base\exception\GlobalExceptionHandler.java" @'
package com.cloudvault.auth.exception;

import com.cloudvault.auth.dto.ErrorResponse;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<ErrorResponse> handleBadCredentials(IllegalArgumentException ex) {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                .body(ErrorResponse.of(401, "Unauthorized", ex.getMessage()));
    }

    @ExceptionHandler(IllegalStateException.class)
    public ResponseEntity<ErrorResponse> handleConflict(IllegalStateException ex) {
        return ResponseEntity.status(HttpStatus.CONFLICT)
                .body(ErrorResponse.of(409, "Conflict", ex.getMessage()));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidation(MethodArgumentNotValidException ex) {
        String message = ex.getBindingResult().getFieldErrors().stream()
                .findFirst()
                .map(fe -> fe.getField() + ": " + fe.getDefaultMessage())
                .orElse("Validation failed");
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(ErrorResponse.of(400, "Bad Request", message));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleGeneric(Exception ex) {
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(ErrorResponse.of(500, "Internal Server Error", "Something went wrong"));
    }
}
'@

Set-Content "auth-service\src\main\resources\application.yml" @'
server:
  port: 8080

spring:
  application:
    name: auth-service
  datasource:
    url: jdbc:postgresql://${DB_HOST:localhost}:${DB_PORT:5432}/${DB_NAME:auth_db}
    username: ${DB_USER:cloudvault}
    password: ${DB_PASSWORD:changeme_local_only}
    hikari:
      maximum-pool-size: 10
      minimum-idle: 2
      connection-timeout: 30000
  jpa:
    hibernate:
      ddl-auto: update
    show-sql: false
    properties:
      hibernate:
        format_sql: true

jwt:
  secret: ${JWT_SECRET:replace_this_with_a_generated_64_byte_base64_secret}
  expiry-minutes: ${JWT_EXPIRY_MINUTES:15}
  refresh-expiry-days: ${JWT_REFRESH_EXPIRY_DAYS:7}

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
    org.springframework.security: WARN
'@

Write-Host "All auth-service files created." -ForegroundColor Green