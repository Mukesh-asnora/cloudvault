$base = "api-gateway\src\main\java\com\cloudvault\gateway"
$dirs = @("config","filter","security")
foreach ($d in $dirs) { New-Item -ItemType Directory -Force -Path "$base\$d" | Out-Null }
New-Item -ItemType Directory -Force -Path "api-gateway\src\main\resources" | Out-Null

Set-Content "api-gateway\pom.xml" @'
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
    <artifactId>api-gateway</artifactId>
    <version>1.0.0</version>
    <name>api-gateway</name>
    <description>Single entry point routing, JWT validation, and rate limiting for CloudVault</description>

    <properties>
        <java.version>17</java.version>
        <spring-cloud.version>2023.0.1</spring-cloud.version>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-starter-gateway</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-redis-reactive</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
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
        <dependency>
            <groupId>io.projectreactor</groupId>
            <artifactId>reactor-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <dependencyManagement>
        <dependencies>
            <dependency>
                <groupId>org.springframework.cloud</groupId>
                <artifactId>spring-cloud-dependencies</artifactId>
                <version>${spring-cloud.version}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
        </dependencies>
    </dependencyManagement>

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

Set-Content "$base\ApiGatewayApplication.java" @'
package com.cloudvault.gateway;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class ApiGatewayApplication {
    public static void main(String[] args) {
        SpringApplication.run(ApiGatewayApplication.class, args);
    }
}
'@

Set-Content "$base\security\JwtService.java" @'
package com.cloudvault.gateway.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;

/**
 * Validates JWTs at the gateway - the first checkpoint before a request
 * ever reaches a backend service. Each downstream service (auth, metadata,
 * file) ALSO independently re-validates the same token - this is
 * deliberate defense in depth, not redundant duplication.
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

Set-Content "$base\filter\JwtAuthenticationFilter.java" @'
package com.cloudvault.gateway.filter;

import com.cloudvault.gateway.security.JwtService;
import lombok.RequiredArgsConstructor;
import org.springframework.core.Ordered;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.http.HttpStatus;
import org.springframework.http.server.reactive.ServerHttpRequest;
import org.springframework.http.server.reactive.ServerHttpResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

/**
 * Runs on every request through the gateway. Public routes (login/register,
 * health checks) pass straight through; everything else must carry a valid
 * JWT in the Authorization header, or the gateway rejects it before it ever
 * reaches a backend service.
 */
@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter implements GlobalFilter, Ordered {

    private final JwtService jwtService;

    private static final String[] PUBLIC_PATHS = {
            "/auth/register",
            "/auth/login",
            "/auth/refresh",
            "/actuator/health"
    };

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        ServerHttpRequest request = exchange.getRequest();
        String path = request.getURI().getPath();

        if (isPublicPath(path)) {
            return chain.filter(exchange);
        }

        String header = request.getHeaders().getFirst("Authorization");
        if (header == null || !header.startsWith("Bearer ")) {
            return reject(exchange, "Missing or malformed Authorization header");
        }

        String token = header.substring(7);
        try {
            jwtService.parseClaims(token);
            return chain.filter(exchange);
        } catch (Exception ex) {
            return reject(exchange, "Invalid or expired token");
        }
    }

    private boolean isPublicPath(String path) {
        for (String publicPath : PUBLIC_PATHS) {
            if (path.startsWith(publicPath)) {
                return true;
            }
        }
        return false;
    }

    private Mono<Void> reject(ServerWebExchange exchange, String message) {
        ServerHttpResponse response = exchange.getResponse();
        response.setStatusCode(HttpStatus.UNAUTHORIZED);
        response.getHeaders().add("Content-Type", "application/json");
        String body = String.format("{\"status\":401,\"error\":\"Unauthorized\",\"message\":\"%s\"}", message);
        var buffer = response.bufferFactory().wrap(body.getBytes());
        return response.writeWith(Mono.just(buffer));
    }

    @Override
    public int getOrder() {
        return -1; // run before routing filters
    }
}
'@

Set-Content "$base\config\RateLimiterConfig.java" @'
package com.cloudvault.gateway.config;

import org.springframework.cloud.gateway.filter.ratelimit.KeyResolver;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import reactor.core.publisher.Mono;

@Configuration
public class RateLimiterConfig {

    // Rate limits are keyed by client IP - one heavy client can't starve
    // everyone else's requests.
    @Bean
    public KeyResolver ipKeyResolver() {
        return exchange -> {
            var remoteAddress = exchange.getRequest().getRemoteAddress();
            String ip = (remoteAddress != null) ? remoteAddress.getAddress().getHostAddress() : "unknown";
            return Mono.just(ip);
        };
    }
}
'@

Set-Content "api-gateway\src\main\resources\application.yml" @'
server:
  port: ${SERVER_PORT:8080}

spring:
  application:
    name: api-gateway
  data:
    redis:
      host: ${REDIS_HOST:localhost}
      port: ${REDIS_PORT:6379}

  cloud:
    gateway:
      globalcors:
        cors-configurations:
          '[/**]':
            allowedOrigins: "http://localhost:3000"
            allowedMethods:
              - GET
              - POST
              - PUT
              - PATCH
              - DELETE
              - OPTIONS
            allowedHeaders: "*"
            allowCredentials: true

      routes:
        - id: auth-service
          uri: ${AUTH_SERVICE_URL:http://localhost:8081}
          predicates:
            - Path=/auth/**
          filters:
            - name: RequestRateLimiter
              args:
                redis-rate-limiter.replenishRate: 10
                redis-rate-limiter.burstCapacity: 20
                key-resolver: "#{@ipKeyResolver}"

        - id: metadata-service
          uri: ${METADATA_SERVICE_URL:http://localhost:8083}
          predicates:
            - Path=/metadata/**
          filters:
            - name: RequestRateLimiter
              args:
                redis-rate-limiter.replenishRate: 50
                redis-rate-limiter.burstCapacity: 100
                key-resolver: "#{@ipKeyResolver}"

        - id: file-service
          uri: ${FILE_SERVICE_URL:http://localhost:8082}
          predicates:
            - Path=/files/**
          filters:
            - name: RequestRateLimiter
              args:
                redis-rate-limiter.replenishRate: 50
                redis-rate-limiter.burstCapacity: 100
                key-resolver: "#{@ipKeyResolver}"

jwt:
  secret: ${JWT_SECRET:replace_this_with_a_generated_64_byte_base64_secret}

management:
  endpoints:
    web:
      exposure:
        include: health,info,gateway

logging:
  level:
    com.cloudvault: INFO
    org.springframework.cloud.gateway: INFO
'@

Write-Host "All api-gateway files created." -ForegroundColor Green