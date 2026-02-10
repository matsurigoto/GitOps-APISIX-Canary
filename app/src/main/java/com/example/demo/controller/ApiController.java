package com.example.demo.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.net.InetAddress;
import java.time.Instant;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class ApiController {

    @Value("${app.version:v1}")
    private String appVersion;

    @GetMapping("/hello")
    public Map<String, Object> hello() {
        String hostname;
        try {
            hostname = InetAddress.getLocalHost().getHostName();
        } catch (Exception e) {
            hostname = "unknown";
        }
        return Map.of(
            "message", "Hello from " + appVersion,
            "version", appVersion,
            "hostname", hostname,
            "timestamp", Instant.now().toString()
        );
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of(
            "status", "UP",
            "version", appVersion
        );
    }

    @GetMapping("/info")
    public Map<String, String> info() {
        return Map.of(
            "app", "demo-api",
            "version", appVersion,
            "description", "Spring Boot Demo API for GitOps APISIX Canary"
        );
    }
}
