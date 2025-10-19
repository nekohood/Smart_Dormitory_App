package com.dormitory.SpringBoot.utils;

import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.Base64;

@Component
public class SecurityUtils {

    /**
     * SHA-256으로 사용자 ID 해시화
     * 외부에서 실제 사용자 ID를 알 수 없도록 함
     */
    public static String hashUserId(String userId) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(userId.getBytes(StandardCharsets.UTF_8));
            return Base64.getEncoder().encodeToString(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("SHA-256 알고리즘을 찾을 수 없습니다", e);
        }
    }

    /**
     * 사용자 ID 검증용 해시 생성
     */
    public static String createUserHash(String userId, String salt) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            String combined = userId + salt;
            byte[] hash = digest.digest(combined.getBytes(StandardCharsets.UTF_8));
            return Base64.getEncoder().encodeToString(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("해시 생성 실패", e);
        }
    }

    /**
     * 랜덤 솔트 생성
     */
    public static String generateSalt() {
        SecureRandom random = new SecureRandom();
        byte[] salt = new byte[16];
        random.nextBytes(salt);
        return Base64.getEncoder().encodeToString(salt);
    }

    /**
     * 개인정보 마스킹 (로그용)
     */
    public static String maskPersonalInfo(String data) {
        if (data == null || data.length() <= 4) {
            return "****";
        }
        return data.substring(0, 2) + "****" + data.substring(data.length() - 2);
    }

    /**
     * 이메일 마스킹
     */
    public static String maskEmail(String email) {
        if (email == null || !email.contains("@")) {
            return "****@****.***";
        }

        String[] parts = email.split("@");
        String username = parts[0];
        String domain = parts[1];

        String maskedUsername = username.length() > 2 ?
                username.substring(0, 2) + "****" : "****";
        String maskedDomain = domain.length() > 4 ?
                domain.substring(0, 2) + "****" + domain.substring(domain.length() - 2) : "****.***";

        return maskedUsername + "@" + maskedDomain;
    }

    /**
     * 전화번호 마스킹
     */
    public static String maskPhoneNumber(String phone) {
        if (phone == null || phone.length() < 8) {
            return "***-****-****";
        }

        // 숫자만 추출
        String numbers = phone.replaceAll("[^0-9]", "");

        if (numbers.length() == 11) {
            return numbers.substring(0, 3) + "-****-" + numbers.substring(7);
        } else if (numbers.length() == 10) {
            return numbers.substring(0, 3) + "-***-" + numbers.substring(6);
        }

        return "***-****-****";
    }
}