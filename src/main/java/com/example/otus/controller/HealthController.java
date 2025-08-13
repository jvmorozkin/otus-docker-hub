package com.example.otus.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
class HealthController {
    @GetMapping("/health")
    public HealthStatus health() {
        return new HealthStatus("OK");
    }

    static class HealthStatus {
        public String status;

        public HealthStatus(String status) {
            this.status = status;
        }
    }
}
