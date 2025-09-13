package com.example.otus.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtUtil jwtUtil;
    private final UserDetailsService userDetailsService;

    private static final Logger logger = LoggerFactory.getLogger(JwtAuthenticationFilter.class);

    public JwtAuthenticationFilter(JwtUtil jwtUtil, UserDetailsService userDetailsService) {
        this.jwtUtil = jwtUtil;
        this.userDetailsService = userDetailsService;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {

        String authHeader = request.getHeader("Authorization");
        String requestUrl = request.getRequestURL().toString();

        // Пропускаем аутентификационные и health эндпоинты
        if (requestUrl.contains("/api/v1/auth/") ||
            requestUrl.contains("/health") ||
            requestUrl.contains("/actuator") ||
            requestUrl.contains("/error") ||
            requestUrl.contains("/debug")) {
            filterChain.doFilter(request, response);
            return;
        }

        logger.debug("=== JWT FILTER ===");
        logger.debug("Request URL: {}", requestUrl);
        logger.debug("Authorization Header: {}", authHeader);

        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7).trim();

            logger.debug("Extracted token: {}", token);
            logger.debug("Token length: {}", token.length());

            if (!token.isEmpty() && jwtUtil.validateToken(token)) {
                String username = jwtUtil.extractUsername(token);

                if (username != null) {
                    logger.debug("Token validated for user: {}", username);

                    try {
                        UserDetails userDetails = userDetailsService.loadUserByUsername(username);
                        UsernamePasswordAuthenticationToken authentication =
                                new UsernamePasswordAuthenticationToken(userDetails, null, userDetails.getAuthorities());

                        SecurityContextHolder.getContext().setAuthentication(authentication);
                        logger.debug("Authentication set for user: {}", username);
                    } catch (Exception e) {
                        logger.warn("Failed to load user details: {}", e.getMessage());
                    }
                } else {
                    logger.warn("Failed to extract username from valid token");
                }
            } else {
                logger.warn("Token validation failed or empty token");
            }
        } else {
            logger.debug("No Bearer token found for URL: {}", requestUrl);
        }

        filterChain.doFilter(request, response);
    }
}