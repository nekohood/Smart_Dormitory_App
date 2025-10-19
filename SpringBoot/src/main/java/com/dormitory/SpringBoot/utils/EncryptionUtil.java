package com.dormitory.SpringBoot.utils;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.Cipher;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.util.Base64;

/**
 * 개인정보 암호화/복호화를 위한 유틸리티 클래스
 */
@Component
public class EncryptionUtil {

    private static final Logger logger = LoggerFactory.getLogger(EncryptionUtil.class);

    private static final String ALGORITHM = "AES";
    private static final String TRANSFORMATION = "AES/ECB/PKCS5Padding";

    @Value("${app.encryption.secret-key}")
    private String secretKey;

    /**
     * 문자열 암호화
     *
     * @param plainText 암호화할 문자열
     * @return 암호화된 문자열 (Base64 인코딩)
     */
    public String encrypt(String plainText) {
        if (plainText == null || plainText.isEmpty()) {
            return plainText;
        }

        try {
            SecretKeySpec keySpec = new SecretKeySpec(getKeyBytes(), ALGORITHM);
            Cipher cipher = Cipher.getInstance(TRANSFORMATION);
            cipher.init(Cipher.ENCRYPT_MODE, keySpec);

            byte[] encryptedBytes = cipher.doFinal(plainText.getBytes(StandardCharsets.UTF_8));
            return Base64.getEncoder().encodeToString(encryptedBytes);

        } catch (Exception e) {
            logger.error("암호화 중 오류 발생", e);
            throw new RuntimeException("암호화에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 문자열 복호화
     *
     * @param encryptedText 암호화된 문자열 (Base64 인코딩)
     * @return 복호화된 문자열
     */
    public String decrypt(String encryptedText) {
        if (encryptedText == null || encryptedText.isEmpty()) {
            return encryptedText;
        }

        try {
            SecretKeySpec keySpec = new SecretKeySpec(getKeyBytes(), ALGORITHM);
            Cipher cipher = Cipher.getInstance(TRANSFORMATION);
            cipher.init(Cipher.DECRYPT_MODE, keySpec);

            byte[] decodedBytes = Base64.getDecoder().decode(encryptedText);
            byte[] decryptedBytes = cipher.doFinal(decodedBytes);
            return new String(decryptedBytes, StandardCharsets.UTF_8);

        } catch (Exception e) {
            logger.error("복호화 중 오류 발생", e);
            // 복호화 실패 시 원본 텍스트 반환 (마이그레이션 대응)
            logger.warn("복호화 실패로 원본 텍스트 반환: {}", encryptedText);
            return encryptedText;
        }
    }

    /**
     * 암호화된 텍스트인지 확인
     *
     * @param text 확인할 텍스트
     * @return 암호화된 텍스트 여부
     */
    public boolean isEncrypted(String text) {
        if (text == null || text.isEmpty()) {
            return false;
        }

        try {
            // Base64 디코딩이 가능한지 확인
            Base64.getDecoder().decode(text);

            // 복호화 시도
            decrypt(text);
            return true;

        } catch (Exception e) {
            return false;
        }
    }

    /**
     * 키 바이트 배열 생성
     * AES-256을 위해 32바이트 키 생성
     */
    private byte[] getKeyBytes() {
        byte[] key = secretKey.getBytes(StandardCharsets.UTF_8);

        // 키가 32바이트가 되도록 조정
        if (key.length > 32) {
            byte[] truncatedKey = new byte[32];
            System.arraycopy(key, 0, truncatedKey, 0, 32);
            return truncatedKey;
        } else if (key.length < 32) {
            byte[] paddedKey = new byte[32];
            System.arraycopy(key, 0, paddedKey, 0, key.length);
            // 나머지 바이트는 0으로 패딩
            return paddedKey;
        }

        return key;
    }

    /**
     * 안전한 문자열 비교 (타이밍 공격 방지)
     *
     * @param a 비교할 문자열 1
     * @param b 비교할 문자열 2
     * @return 같으면 true, 다르면 false
     */
    public boolean safeEquals(String a, String b) {
        if (a == null && b == null) {
            return true;
        }
        if (a == null || b == null) {
            return false;
        }

        byte[] aBytes = a.getBytes(StandardCharsets.UTF_8);
        byte[] bBytes = b.getBytes(StandardCharsets.UTF_8);

        if (aBytes.length != bBytes.length) {
            return false;
        }

        int result = 0;
        for (int i = 0; i < aBytes.length; i++) {
            result |= aBytes[i] ^ bBytes[i];
        }

        return result == 0;
    }

    /**
     * 민감한 문자열 마스킹
     *
     * @param text 마스킹할 문자열
     * @param visibleChars 앞뒤로 보여줄 문자 수
     * @return 마스킹된 문자열
     */
    public String maskSensitiveData(String text, int visibleChars) {
        if (text == null || text.length() <= visibleChars * 2) {
            return "***";
        }

        String prefix = text.substring(0, visibleChars);
        String suffix = text.substring(text.length() - visibleChars);
        int maskLength = text.length() - (visibleChars * 2);
        String mask = "*".repeat(Math.min(maskLength, 6)); // 최대 6개 별표

        return prefix + mask + suffix;
    }

    /**
     * 이메일 마스킹
     *
     * @param email 마스킹할 이메일
     * @return 마스킹된 이메일
     */
    public String maskEmail(String email) {
        if (email == null || !email.contains("@")) {
            return "***@***.***";
        }

        String[] parts = email.split("@");
        String localPart = parts[0];
        String domainPart = parts[1];

        // 로컬 부분 마스킹
        String maskedLocal;
        if (localPart.length() <= 2) {
            maskedLocal = "*".repeat(localPart.length());
        } else {
            maskedLocal = localPart.charAt(0) + "*".repeat(localPart.length() - 2) + localPart.charAt(localPart.length() - 1);
        }

        // 도메인 부분 마스킹
        String maskedDomain;
        if (domainPart.contains(".")) {
            String[] domainParts = domainPart.split("\\.");
            String domainName = domainParts[0];
            String extension = domainParts[domainParts.length - 1];

            if (domainName.length() <= 2) {
                maskedDomain = "*".repeat(domainName.length()) + "." + extension;
            } else {
                maskedDomain = domainName.charAt(0) + "*".repeat(domainName.length() - 2) + domainName.charAt(domainName.length() - 1) + "." + extension;
            }
        } else {
            maskedDomain = maskSensitiveData(domainPart, 1);
        }

        return maskedLocal + "@" + maskedDomain;
    }

    /**
     * 전화번호 마스킹
     *
     * @param phoneNumber 마스킹할 전화번호
     * @return 마스킹된 전화번호
     */
    public String maskPhoneNumber(String phoneNumber) {
        if (phoneNumber == null || phoneNumber.length() < 4) {
            return "***-****-****";
        }

        // 숫자만 추출
        String numbersOnly = phoneNumber.replaceAll("[^0-9]", "");

        if (numbersOnly.length() == 11) {
            // 휴대폰 번호 (010-****-1234)
            return numbersOnly.substring(0, 3) + "-****-" + numbersOnly.substring(7);
        } else if (numbersOnly.length() == 10) {
            // 일반 전화 (02-***-1234)
            return numbersOnly.substring(0, 2) + "-***-" + numbersOnly.substring(6);
        } else {
            // 기타 (앞 2자리, 뒤 2자리만 표시)
            return maskSensitiveData(phoneNumber, 2);
        }
    }
}