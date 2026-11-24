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
