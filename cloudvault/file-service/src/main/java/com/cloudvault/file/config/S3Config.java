package com.cloudvault.file.config;

import java.net.URI;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;

@Configuration
public class S3Config {

    @Value("${s3.endpoint:}")
    private String endpoint;

    // The hostname baked into presigned URLs must be reachable by the
    // BROWSER, not just by other pods inside the cluster. Internally,
    // file-service talks to MinIO via the cluster-only hostname "minio";
    // externally (via kubectl port-forward or an Ingress), that's
    // typically localhost or a real public domain. Defaults to the same
    // value as s3.endpoint for non-Kubernetes (Docker Compose) setups,
    // where there's no distinction.
    @Value("${s3.public-endpoint:${s3.endpoint:}}")
    private String publicEndpoint;

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

        if (publicEndpoint != null && !publicEndpoint.isBlank()) {
            builder.endpointOverride(URI.create(publicEndpoint));
        }

        return builder.build();
    }
}