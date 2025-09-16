package com.example.otus.controller;

import com.example.otus.model.User;
import com.example.otus.repository.UserRepository;
import lombok.Data;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import jakarta.validation.Valid;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/api/v1/profile")
public class ProfileController {

    private static final Logger logger = LoggerFactory.getLogger(ProfileController.class);

    private final UserRepository userRepository;

    public ProfileController(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    // Получение своего профиля
    @GetMapping
    public ResponseEntity<?> getMyProfile(@AuthenticationPrincipal UserDetails userDetails) {
        if (userDetails == null) {
            return ResponseEntity.status(401).body(Map.of("error", "Unauthorized"));
        }

        Optional<User> userOpt = userRepository.findByUsername(userDetails.getUsername());

        if (userOpt.isEmpty()) {
            return ResponseEntity.notFound().build();
        }

        User user = userOpt.get();
        user.setPassword(null);

        return ResponseEntity.ok(user);
    }

    // Получение профиля по ID (с проверкой что это свой профиль)
    @GetMapping("/{userId}")
    public ResponseEntity<?> getProfileById(@PathVariable Long userId,
                                            @AuthenticationPrincipal UserDetails userDetails) {
        if (userDetails == null) {
            return ResponseEntity.status(401).body(Map.of("error", "Unauthorized"));
        }

        // Находим текущего пользователя
        Optional<User> currentUserOpt = userRepository.findByUsername(userDetails.getUsername());
        if (currentUserOpt.isEmpty()) {
            return ResponseEntity.notFound().build();
        }

        User currentUser = currentUserOpt.get();

        // Проверяем, что пользователь запрашивает свой профиль
        if (!currentUser.getId().equals(userId)) {
            logger.warn("User {} attempted to access profile of user {}",
                    currentUser.getId(), userId);
            return ResponseEntity.status(403).body(Map.of("error", "Access denied"));
        }

        // Если запрашивает свой профиль - возвращаем
        currentUser.setPassword(null);
        return ResponseEntity.ok(currentUser);
    }

    // Обновление профиля (только своего)
    @PutMapping
    public ResponseEntity<?> updateMyProfile(@AuthenticationPrincipal UserDetails userDetails,
                                             @Valid @RequestBody ProfileUpdateRequest request) {
        if (userDetails == null) {
            return ResponseEntity.status(401).body(Map.of("error", "Unauthorized"));
        }

        Optional<User> userOpt = userRepository.findByUsername(userDetails.getUsername());

        if (userOpt.isEmpty()) {
            return ResponseEntity.notFound().build();
        }

        User user = userOpt.get();

        // Проверяем, что email не занят другим пользователем
        if (request.getEmail() != null && !request.getEmail().equals(user.getEmail())) {
            Optional<User> existingUser = userRepository.findByEmail(request.getEmail());
            if (existingUser.isPresent() && !existingUser.get().getId().equals(user.getId())) {
                return ResponseEntity.badRequest().body(Map.of("error", "Email already taken"));
            }
            user.setEmail(request.getEmail());
        }

        if (request.getFirstName() != null) user.setFirstName(request.getFirstName());
        if (request.getLastName() != null) user.setLastName(request.getLastName());
        if (request.getPhone() != null) user.setPhone(request.getPhone());

        userRepository.save(user);
        user.setPassword(null);

        return ResponseEntity.ok(user);
    }

    @Data
    public static class ProfileUpdateRequest {
        private String email;
        private String firstName;
        private String lastName;
        private String phone;
    }
}