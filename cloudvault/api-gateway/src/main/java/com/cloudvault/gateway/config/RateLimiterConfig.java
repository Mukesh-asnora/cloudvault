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
