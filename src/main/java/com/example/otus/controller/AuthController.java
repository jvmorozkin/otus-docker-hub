package com.example.otus.controller;

import com.example.otus.model.User;
import com.example.otus.repository.UserRepository;
import com.example.otus.security.JwtUtil;
import lombok.Data;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import jakarta.validation.Valid;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    private static final Logger logger = LoggerFactory.getLogger(AuthController.class);

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;

    public AuthController(UserRepository userRepository,
                          PasswordEncoder passwordEncoder,
                          JwtUtil jwtUtil) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtUtil = jwtUtil;
    }

    @PostMapping("/register")
    public ResponseEntity<?> register(@Valid @RequestBody RegistrationRequest request) {
        logger.info("Registration attempt for user: {}", request.getUsername());

        if (userRepository.findByUsername(request.getUsername()).isPresent()) {
            logger.warn("Registration failed: username {} already exists", request.getUsername());
            return ResponseEntity.badRequest().body(Map.of("error", "Username already exists"));
        }

        if (userRepository.findByEmail(request.getEmail()).isPresent()) {
            logger.warn("Registration failed: email {} already exists", request.getEmail());
            return ResponseEntity.badRequest().body(Map.of("error", "Email already exists"));
        }

        User user = new User();
        user.setUsername(request.getUsername());
        user.setPassword(passwordEncoder.encode(request.getPassword()));
        user.setEmail(request.getEmail());
        user.setFirstName(request.getFirstName());
        user.setLastName(request.getLastName());
        user.setPhone(request.getPhone());

        userRepository.save(user);

        String token = jwtUtil.generateToken(user.getUsername());
        logger.info("Registration successful for user: {}", user.getUsername());

        // Гарантированно возвращаем токен в ответе
        return ResponseEntity.ok(Map.of(
                "token", token,
                "message", "User registered successfully",
                "username", user.getUsername(),
                "userId", user.getId()
        ));
    }

    @PostMapping("/login")
    public ResponseEntity<?> login(@Valid @RequestBody LoginRequest request) {
        logger.info("Login attempt for user: {}", request.getUsername());

        Optional<User> userOpt = userRepository.findByUsername(request.getUsername());

        if (userOpt.isEmpty()) {
            logger.warn("Login failed: user {} not found", request.getUsername());
            return ResponseEntity.badRequest().body(Map.of("error", "Invalid credentials"));
        }

        User user = userOpt.get();
        if (!passwordEncoder.matches(request.getPassword(), user.getPassword())) {
            logger.warn("Login failed: invalid password for user {}", request.getUsername());
            return ResponseEntity.badRequest().body(Map.of("error", "Invalid credentials"));
        }

        String token = jwtUtil.generateToken(request.getUsername());
        logger.info("Login successful for user: {}", request.getUsername());

        // Гарантированно возвращаем токен в ответе
        return ResponseEntity.ok(Map.of(
                "token", token,
                "message", "Login successful",
                "username", user.getUsername(),
                "userId", user.getId()
        ));
    }

    @GetMapping("/check-token")
    public ResponseEntity<?> checkToken(@RequestHeader(value = "Authorization", required = false) String authHeader) {
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            return ResponseEntity.badRequest().body(Map.of("valid", false, "error", "No Bearer token"));
        }

        String token = authHeader.substring(7).trim();
        boolean isValid = jwtUtil.validateToken(token);
        String username = isValid ? jwtUtil.extractUsername(token) : null;

        return ResponseEntity.ok(Map.of(
                "valid", isValid,
                "username", username,
                "tokenLength", token.length()
        ));
    }

    @Data
    public static class RegistrationRequest {
        private String username;
        private String password;
        private String email;
        private String firstName;
        private String lastName;
        private String phone;
    }

    @Data
    public static class LoginRequest {
        private String username;
        private String password;
    }
}