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
