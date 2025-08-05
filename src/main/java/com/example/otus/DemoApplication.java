package com.example.otus;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@SpringBootApplication
public class DemoApplication {
    public static void main(String[] args) {
        SpringApplication.run(DemoApplication.class, args);
    }
}

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