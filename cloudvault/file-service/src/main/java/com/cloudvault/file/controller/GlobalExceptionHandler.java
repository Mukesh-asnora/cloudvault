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
