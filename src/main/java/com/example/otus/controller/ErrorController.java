package com.example.otus.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class ErrorController {

    @GetMapping("/error")
    public ResponseEntity<String> error() {
        throw new RuntimeException("Code 500!");
    }
}
