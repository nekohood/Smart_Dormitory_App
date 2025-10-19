package com.dormitory.SpringBoot.filter;

import com.dormitory.SpringBoot.domain.User;
import com.dormitory.SpringBoot.repository.UserRepository;
import com.dormitory.SpringBoot.utils.JwtUtil;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpMethod;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Collections;
import java.util.Optional;

/**
 * JWT 인증 필터 - 디버깅 강화 버전
 */
@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private static final Logger logger = LoggerFactory.getLogger(JwtAuthenticationFilter.class);

    @Autowired
    private JwtUtil jwtUtil;

    @Autowired
    private UserRepository userRepository;

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {

        // OPTIONS 요청은 바로 통과
        if (HttpMethod.OPTIONS.matches(request.getMethod())) {
            logger.debug("OPTIONS 요청 - 필터 바이패스");
            filterChain.doFilter(request, response);
            return;
        }

        String requestPath = request.getRequestURI();
        String requestMethod = request.getMethod();
        logger.debug("=== JWT 필터 시작 === Path: {} Method: {}", requestPath, requestMethod);

        try {
            String authHeader = request.getHeader("Authorization");
            logger.debug("Authorization 헤더: {}", authHeader != null ? "Bearer ***" : "null");

            if (authHeader != null && authHeader.startsWith("Bearer ")) {
                String token = authHeader.substring(7);
                logger.debug("JWT 토큰 추출 성공, 길이: {}", token.length());

                // 토큰 유효성 검증
                if (jwtUtil.isTokenValid(token)) {
                    logger.debug("토큰 유효성 검증 성공");

                    String userId = jwtUtil.getUserIdFromToken(token);
                    Boolean isAdmin = jwtUtil.getIsAdminFromToken(token);

                    logger.debug("사용자 ID: {}, 관리자 여부: {}", userId, isAdmin);

                    // 사용자 정보 조회 및 Authentication 설정
                    Optional<User> userOptional = userRepository.findById(userId);
                    if (userOptional.isPresent()) {
                        User user = userOptional.get();

                        // 계정 활성화 상태 확인
                        if (!Boolean.TRUE.equals(user.getIsActive())) {
                            logger.warn("비활성화된 계정으로 접근 시도 - 사용자ID: {}", userId);
                            filterChain.doFilter(request, response);
                            return;
                        }

                        // 계정 잠금 상태 확인
                        if (user.isAccountLocked()) {
                            logger.warn("잠긴 계정으로 접근 시도 - 사용자ID: {}", userId);
                            filterChain.doFilter(request, response);
                            return;
                        }

                        // 계정 잠금이 만료된 경우 자동 해제
                        user.unlockAccountIfNeeded();

                        SimpleGrantedAuthority authority = isAdmin ?
                                new SimpleGrantedAuthority("ROLE_ADMIN") :
                                new SimpleGrantedAuthority("ROLE_USER");

                        UsernamePasswordAuthenticationToken authentication =
                                new UsernamePasswordAuthenticationToken(
                                        userId, null, Collections.singletonList(authority));

                        authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                        SecurityContextHolder.getContext().setAuthentication(authentication);

                        logger.debug("인증 설정 완료: {} (권한: {})", userId, authority.getAuthority());
                    } else {
                        logger.warn("사용자를 찾을 수 없음: {}", userId);
                    }
                } else {
                    logger.warn("토큰 유효성 검증 실패");
                }
            } else {
                logger.debug("Authorization 헤더가 없거나 Bearer 형식이 아님");
            }

        } catch (Exception e) {
            logger.error("JWT 처리 중 오류 발생", e);
            SecurityContextHolder.clearContext();
        }

        filterChain.doFilter(request, response);
        logger.debug("=== JWT 필터 완료 ===");
    }

    /**
     * 필터를 적용하지 않을 요청 경로 확인
     */
    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) throws ServletException {
        String path = request.getRequestURI();

        // 인증이 필요없는 경로들
        boolean shouldSkip = path.startsWith("/hello") ||
                path.startsWith("/api/auth") ||
                path.startsWith("/actuator/health") ||
                path.startsWith("/swagger-ui") ||
                path.startsWith("/v3/api-docs") ||
                path.startsWith("/uploads") ||
                path.equals("/favicon.ico");

        if (shouldSkip) {
            logger.debug("필터 스킵: {}", path);
        }

        return shouldSkip;
    }
}