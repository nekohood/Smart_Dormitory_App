package com.dormitory.SpringBoot.utils;

import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;

/**
 * JWT 토큰 관련 유틸리티 클래스 - 완성된 버전
 */
@Component
public class JwtUtil {

    private static final Logger logger = LoggerFactory.getLogger(JwtUtil.class);

    @Value("${app.jwt.secret}")
    private String jwtSecret;

    @Value("${app.jwt.expiration:86400000}") // 기본값: 24시간
    private long jwtExpirationMs;

    /**
     * 서명용 키 생성
     */
    private SecretKey getSigningKey() {
        return Keys.hmacShaKeyFor(jwtSecret.getBytes());
    }

    /**
     * JWT 토큰 생성
     *
     * @param userId 사용자 ID
     * @param isAdmin 관리자 여부
     * @return 생성된 JWT 토큰
     */
    public String generateToken(String userId, Boolean isAdmin) {
        try {
            Date now = new Date();
            Date expiryDate = new Date(now.getTime() + jwtExpirationMs);

            Map<String, Object> claims = new HashMap<>();
            claims.put("isAdmin", isAdmin);
            claims.put("iat", now.getTime() / 1000);

            String token = Jwts.builder()
                    .subject(userId)
                    .claims(claims)
                    .issuedAt(now)
                    .expiration(expiryDate)
                    .signWith(getSigningKey())
                    .compact();

            logger.debug("JWT 토큰 생성 완료 - 사용자: {}, 관리자: {}, 만료시간: {}",
                    userId, isAdmin, expiryDate);
            return token;

        } catch (Exception e) {
            logger.error("JWT 토큰 생성 중 오류 발생", e);
            throw new RuntimeException("토큰 생성에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 토큰 유효성 검증
     *
     * @param token 검증할 토큰
     * @return 유효성 여부
     */
    public boolean isTokenValid(String token) {
        try {
            if (token == null || token.trim().isEmpty()) {
                logger.debug("토큰이 null이거나 비어있음");
                return false;
            }

            Jwts.parser()
                    .verifyWith(getSigningKey())
                    .build()
                    .parseSignedClaims(token);

            logger.debug("토큰 유효성 검증 성공");
            return true;

        } catch (ExpiredJwtException e) {
            logger.debug("토큰이 만료되었습니다: {}", e.getMessage());
            return false;
        } catch (UnsupportedJwtException e) {
            logger.debug("지원되지 않는 JWT 토큰: {}", e.getMessage());
            return false;
        } catch (MalformedJwtException e) {
            logger.debug("잘못된 형식의 JWT 토큰: {}", e.getMessage());
            return false;
        } catch (SecurityException e) {
            logger.debug("JWT 토큰 서명이 유효하지 않음: {}", e.getMessage());
            return false;
        } catch (IllegalArgumentException e) {
            logger.debug("JWT 토큰이 비어있음: {}", e.getMessage());
            return false;
        } catch (Exception e) {
            logger.error("토큰 검증 중 예상치 못한 오류", e);
            return false;
        }
    }

    /**
     * 토큰에서 사용자 ID 추출
     *
     * @param token JWT 토큰
     * @return 사용자 ID
     */
    public String getUserIdFromToken(String token) {
        try {
            Claims claims = getClaimsFromToken(token);
            return claims.getSubject();
        } catch (Exception e) {
            logger.error("토큰에서 사용자 ID 추출 실패", e);
            throw new RuntimeException("사용자 ID를 추출할 수 없습니다");
        }
    }

    /**
     * 토큰에서 관리자 여부 추출
     *
     * @param token JWT 토큰
     * @return 관리자 여부
     */
    public Boolean getIsAdminFromToken(String token) {
        try {
            Claims claims = getClaimsFromToken(token);
            return claims.get("isAdmin", Boolean.class);
        } catch (Exception e) {
            logger.error("토큰에서 관리자 여부 추출 실패", e);
            return false;
        }
    }

    /**
     * 토큰에서 만료 시간 추출
     *
     * @param token JWT 토큰
     * @return 만료 시간
     */
    public Date getExpirationDateFromToken(String token) {
        try {
            Claims claims = getClaimsFromToken(token);
            return claims.getExpiration();
        } catch (Exception e) {
            logger.error("토큰에서 만료 시간 추출 실패", e);
            throw new RuntimeException("만료 시간을 추출할 수 없습니다");
        }
    }

    /**
     * 토큰이 만료되었는지 확인
     *
     * @param token JWT 토큰
     * @return 만료 여부
     */
    public boolean isTokenExpired(String token) {
        try {
            Date expiration = getExpirationDateFromToken(token);
            return expiration.before(new Date());
        } catch (Exception e) {
            logger.debug("토큰 만료 확인 실패: {}", e.getMessage());
            return true; // 오류 발생 시 만료된 것으로 처리
        }
    }

    /**
     * 토큰에서 클레임 추출
     *
     * @param token JWT 토큰
     * @return 클레임 정보
     */
    private Claims getClaimsFromToken(String token) {
        try {
            return Jwts.parser()
                    .verifyWith(getSigningKey())
                    .build()
                    .parseSignedClaims(token)
                    .getPayload();
        } catch (ExpiredJwtException e) {
            logger.warn("JWT 토큰이 만료되었습니다: {}", e.getMessage());
            throw new RuntimeException("토큰이 만료되었습니다");
        } catch (UnsupportedJwtException e) {
            logger.warn("지원되지 않는 JWT 토큰입니다: {}", e.getMessage());
            throw new RuntimeException("지원되지 않는 토큰입니다");
        } catch (MalformedJwtException e) {
            logger.warn("잘못된 형식의 JWT 토큰입니다: {}", e.getMessage());
            throw new RuntimeException("잘못된 형식의 토큰입니다");
        } catch (SecurityException e) {
            logger.warn("JWT 토큰 서명이 유효하지 않습니다: {}", e.getMessage());
            throw new RuntimeException("토큰 서명이 유효하지 않습니다");
        } catch (IllegalArgumentException e) {
            logger.warn("JWT 토큰이 비어있습니다: {}", e.getMessage());
            throw new RuntimeException("토큰이 비어있습니다");
        }
    }

    /**
     * 토큰 새로고침 (남은 시간이 일정 시간 이하일 때)
     *
     * @param token 기존 토큰
     * @return 새로운 토큰 또는 기존 토큰
     */
    public String refreshTokenIfNeeded(String token) {
        try {
            if (!isTokenValid(token)) {
                throw new RuntimeException("유효하지 않은 토큰입니다");
            }

            Date expiration = getExpirationDateFromToken(token);
            Date now = new Date();

            // 남은 시간이 1시간 이하면 새 토큰 발급
            long timeLeft = expiration.getTime() - now.getTime();
            if (timeLeft < 3600000) { // 1시간 = 3600000ms
                String userId = getUserIdFromToken(token);
                Boolean isAdmin = getIsAdminFromToken(token);

                logger.info("토큰 새로고침 - 사용자: {}", userId);
                return generateToken(userId, isAdmin);
            }

            return token; // 기존 토큰 반환

        } catch (Exception e) {
            logger.error("토큰 새로고침 실패", e);
            throw new RuntimeException("토큰 새로고침에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 토큰에서 발급 시간 추출
     *
     * @param token JWT 토큰
     * @return 발급 시간
     */
    public Date getIssuedAtFromToken(String token) {
        try {
            Claims claims = getClaimsFromToken(token);
            return claims.getIssuedAt();
        } catch (Exception e) {
            logger.error("토큰에서 발급 시간 추출 실패", e);
            throw new RuntimeException("발급 시간을 추출할 수 없습니다");
        }
    }

    /**
     * 디버깅용 토큰 정보 출력
     *
     * @param token JWT 토큰
     */
    public void printTokenInfo(String token) {
        try {
            if (isTokenValid(token)) {
                String userId = getUserIdFromToken(token);
                Boolean isAdmin = getIsAdminFromToken(token);
                Date issuedAt = getIssuedAtFromToken(token);
                Date expiration = getExpirationDateFromToken(token);

                logger.info("=== JWT 토큰 정보 ===");
                logger.info("사용자 ID: {}", userId);
                logger.info("관리자 여부: {}", isAdmin);
                logger.info("발급 시간: {}", issuedAt);
                logger.info("만료 시간: {}", expiration);
                logger.info("유효 여부: {}", !isTokenExpired(token));
                logger.info("==================");
            } else {
                logger.warn("유효하지 않은 토큰입니다");
            }
        } catch (Exception e) {
            logger.error("토큰 정보 출력 실패", e);
        }
    }
}