package com.dormitory.SpringBoot.services;

import com.dormitory.SpringBoot.domain.InspectionSettings;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

/**
 * 점호 검증 통합 서비스
 * - 시간 제한 검증
 * - EXIF 데이터 검증
 * - AI 방 사진 검증
 */
@Service
public class InspectionValidationService {

    private static final Logger logger = LoggerFactory.getLogger(InspectionValidationService.class);

    @Autowired
    private InspectionSettingsService settingsService;

    @Autowired
    private ExifService exifService;

    @Autowired
    private GeminiService geminiService;

    /**
     * 종합 검증 결과
     */
    public static class ValidationResult {
        private final boolean valid;
        private final int score;
        private final String feedback;
        private final boolean timeAllowed;
        private final boolean exifValid;
        private final boolean isRoomPhoto;
        private final Map<String, Object> details;

        public ValidationResult(boolean valid, int score, String feedback,
                                boolean timeAllowed, boolean exifValid, boolean isRoomPhoto,
                                Map<String, Object> details) {
            this.valid = valid;
            this.score = score;
            this.feedback = feedback;
            this.timeAllowed = timeAllowed;
            this.exifValid = exifValid;
            this.isRoomPhoto = isRoomPhoto;
            this.details = details;
        }

        public boolean isValid() { return valid; }
        public int getScore() { return score; }
        public String getFeedback() { return feedback; }
        public boolean isTimeAllowed() { return timeAllowed; }
        public boolean isExifValid() { return exifValid; }
        public boolean isRoomPhoto() { return isRoomPhoto; }
        public Map<String, Object> getDetails() { return details; }
    }

    /**
     * 점호 사진 종합 검증
     */
    public ValidationResult validateInspection(MultipartFile imageFile) {
        try {
            logger.info("점호 종합 검증 시작");

            Map<String, Object> details = new HashMap<>();
            boolean allValid = true;
            int finalScore = 0;
            StringBuilder feedbackBuilder = new StringBuilder();

            // 1. 점호 시간 검증
            InspectionSettingsService.InspectionTimeCheckResult timeResult =
                    settingsService.checkInspectionTimeAllowed();

            boolean timeAllowed = timeResult.isAllowed();
            details.put("timeAllowed", timeAllowed);
            details.put("timeMessage", timeResult.getMessage());

            if (!timeAllowed) {
                logger.warn("점호 시간이 아닙니다: {}", timeResult.getMessage());
                return new ValidationResult(false, 0, timeResult.getMessage(),
                        false, false, false, details);
            }

            Optional<InspectionSettings> settingsOpt = settingsService.getCurrentSettings();
            InspectionSettings settings = settingsOpt.orElse(null);

            // 2. EXIF 검증
            boolean exifValid = true;
            if (settings != null && Boolean.TRUE.equals(settings.getExifValidationEnabled())) {
                ExifService.ExifValidationResult exifResult = exifService.validateExif(
                        imageFile,
                        settings.getExifTimeToleranceMinutes(),
                        settings.getGpsValidationEnabled() ? settings.getDormitoryLatitude() : null,
                        settings.getGpsValidationEnabled() ? settings.getDormitoryLongitude() : null,
                        settings.getGpsRadiusMeters() != null ? settings.getGpsRadiusMeters() : 100
                );

                exifValid = exifResult.isValid();
                details.put("exifValid", exifValid);
                details.put("exifDetails", exifResult.getExifData());

                if (!exifValid) {
                    allValid = false;
                    feedbackBuilder.append("⚠️ 사진 위조 의심: ").append(exifResult.getMessage()).append("\n");
                    logger.warn("EXIF 검증 실패: {}", exifResult.getMessage());
                }
            }

            // 3. AI 방 사진 검증
            boolean isRoomPhoto = true;
            if (settings != null && Boolean.TRUE.equals(settings.getRoomPhotoValidationEnabled())) {
                RoomPhotoValidationResult roomResult = validateRoomPhoto(imageFile);
                isRoomPhoto = roomResult.isRoomPhoto;
                details.put("isRoomPhoto", isRoomPhoto);
                details.put("roomPhotoConfidence", roomResult.confidence);
                details.put("roomPhotoReason", roomResult.reason);

                if (!isRoomPhoto) {
                    logger.warn("방 사진이 아닙니다: {}", roomResult.reason);
                    return new ValidationResult(false, 0,
                            "❌ 방 사진이 아닙니다: " + roomResult.reason,
                            timeAllowed, exifValid, false, details);
                }
            }

            // 4. AI 점호 평가
            finalScore = geminiService.evaluateInspection(imageFile);
            String geminiFeedback = geminiService.getInspectionFeedback(imageFile);

            details.put("aiScore", finalScore);
            details.put("aiFeedback", geminiFeedback);

            if (!exifValid) {
                finalScore = Math.max(0, finalScore - 3);
                feedbackBuilder.append("📉 EXIF 검증 실패로 3점 감점됨\n");
            }

            feedbackBuilder.append(geminiFeedback);

            logger.info("점호 종합 검증 완료 - 점수: {}, 유효: {}", finalScore, allValid);

            return new ValidationResult(allValid, finalScore, feedbackBuilder.toString().trim(),
                    timeAllowed, exifValid, isRoomPhoto, details);

        } catch (Exception e) {
            logger.error("점호 종합 검증 중 오류 발생", e);
            return new ValidationResult(true, 7, "검증 중 오류가 발생하여 기본 점수가 적용되었습니다.",
                    true, true, true, new HashMap<>());
        }
    }

    private RoomPhotoValidationResult validateRoomPhoto(MultipartFile imageFile) {
        try {
            String feedback = geminiService.getInspectionFeedback(imageFile);
            boolean isRoom = !containsNonRoomIndicators(feedback);
            String reason = isRoom ? "기숙사 방 사진으로 확인됨" : extractNonRoomReason(feedback);
            double confidence = isRoom ? 0.9 : 0.85;

            return new RoomPhotoValidationResult(isRoom, confidence, reason);

        } catch (Exception e) {
            logger.error("방 사진 검증 중 오류 발생", e);
            return new RoomPhotoValidationResult(true, 0.5, "검증 불가 - 기본 허용");
        }
    }

    private boolean containsNonRoomIndicators(String feedback) {
        if (feedback == null) return false;

        String lower = feedback.toLowerCase();
        String[] nonRoomKeywords = {
                "화장실", "샤워", "복도", "계단", "로비", "야외", "외부", "옥외",
                "식당", "세탁", "공용", "셀카만", "방이 아", "실외", "밖",
                "bathroom", "toilet", "hallway", "corridor", "outside", "outdoor"
        };

        for (String keyword : nonRoomKeywords) {
            if (lower.contains(keyword)) {
                return true;
            }
        }

        return false;
    }

    private String extractNonRoomReason(String feedback) {
        if (feedback == null) return "방 사진이 아닌 것으로 판단됨";

        String lower = feedback.toLowerCase();

        if (lower.contains("화장실") || lower.contains("샤워") || lower.contains("bathroom")) {
            return "화장실/샤워실 사진은 점호로 인정되지 않습니다.";
        }
        if (lower.contains("복도") || lower.contains("계단") || lower.contains("hallway")) {
            return "복도/계단 사진은 점호로 인정되지 않습니다.";
        }
        if (lower.contains("야외") || lower.contains("외부") || lower.contains("옥외") || lower.contains("outside")) {
            return "야외/실외 사진은 점호로 인정되지 않습니다.";
        }
        if (lower.contains("셀카")) {
            return "방이 보이지 않는 셀카는 점호로 인정되지 않습니다.";
        }

        return "기숙사 방 내부 사진이 아닌 것으로 판단됩니다.";
    }

    private static class RoomPhotoValidationResult {
        final boolean isRoomPhoto;
        final double confidence;
        final String reason;

        RoomPhotoValidationResult(boolean isRoomPhoto, double confidence, String reason) {
            this.isRoomPhoto = isRoomPhoto;
            this.confidence = confidence;
            this.reason = reason;
        }
    }
}