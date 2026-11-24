package com.cloudvault.metadata.dto;

import com.cloudvault.metadata.entity.PermissionLevel;
import jakarta.validation.constraints.NotNull;

import java.util.UUID;

public record ShareRequest(
        @NotNull UUID targetUserId,
        @NotNull PermissionLevel level
) {}
