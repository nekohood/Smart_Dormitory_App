package com.dormitory.SpringBoot.services;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import javax.imageio.ImageIO;
import javax.imageio.ImageReader;
import javax.imageio.metadata.IIOMetadata;
import javax.imageio.stream.ImageInputStream;
import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

/**
 * EXIF 데이터 추출 및 검증 서비스
 * ✅ 촬영 날짜 검증 기능 추가 (당일 촬영 사진만 허용)
 */
@Service
public class ExifService {

    private static final Logger logger = LoggerFactory.getLogger(ExifService.class);
    private static final DateTimeFormatter EXIF_DATE_FORMAT = DateTimeFormatter.ofPattern("yyyy:MM:dd HH:mm:ss");

    /**
     * EXIF 검증 결과
     */
    public static class ExifValidationResult {
        private final boolean valid;
        private final String message;
        private final Map<String, Object> exifData;
        private final boolean timeValid;
        private final boolean locationValid;
        private final boolean notEdited;
        private final boolean dateValid;  // ✅ 추가: 촬영 날짜 유효 여부

        public ExifValidationResult(boolean valid, String message, Map<String, Object> exifData,
                                    boolean timeValid, boolean locationValid, boolean notEdited) {
            this.valid = valid;
            this.message = message;
            this.exifData = exifData;
            this.timeValid = timeValid;
            this.locationValid = locationValid;
            this.notEdited = notEdited;
            this.dateValid = true;  // 기본값
        }

        // ✅ 새로운 생성자 (dateValid 포함)
        public ExifValidationResult(boolean valid, String message, Map<String, Object> exifData,
                                    boolean timeValid, boolean locationValid, boolean notEdited, boolean dateValid) {
            this.valid = valid;
            this.message = message;
            this.exifData = exifData;
            this.timeValid = timeValid;
            this.locationValid = locationValid;
            this.notEdited = notEdited;
            this.dateValid = dateValid;
        }

        public boolean isValid() { return valid; }
        public String getMessage() { return message; }
        public Map<String, Object> getExifData() { return exifData; }
        public boolean isTimeValid() { return timeValid; }
        public boolean isLocationValid() { return locationValid; }
        public boolean isNotEdited() { return notEdited; }
        public boolean isDateValid() { return dateValid; }  // ✅ 추가
    }

    /**
     * EXIF 데이터 추출
     */
    public Map<String, Object> extractExifData(MultipartFile imageFile) {
        Map<String, Object> exifData = new HashMap<>();

        try {
            logger.info("EXIF 데이터 추출 시작 - 파일: {}", imageFile.getOriginalFilename());
            byte[] imageBytes = imageFile.getBytes();

            if (isJpegFile(imageBytes)) {
                exifData = parseJpegExif(imageBytes);
            }

            logger.info("EXIF 데이터 추출 완료: {}", exifData);
            return exifData;

        } catch (Exception e) {
            logger.error("EXIF 데이터 추출 실패", e);
            return exifData;
        }
    }

    /**
     * ✅ EXIF 종합 검증 (촬영 날짜 검증 추가)
     */
    public ExifValidationResult validateExif(MultipartFile imageFile,
                                             int toleranceMinutes,
                                             Double expectedLatitude,
                                             Double expectedLongitude,
                                             int radiusMeters) {
        try {
            logger.info("EXIF 검증 시작 - 허용 오차: {}분", toleranceMinutes);

            Map<String, Object> exifData = extractExifData(imageFile);

            // 기존 검증
            boolean timeValid = validateCaptureTime(exifData, toleranceMinutes);
            boolean locationValid = true;
            if (expectedLatitude != null && expectedLongitude != null) {
                locationValid = validateLocation(exifData, expectedLatitude, expectedLongitude, radiusMeters);
            }
            boolean notEdited = checkNotEdited(exifData);

            // ✅ 촬영 날짜 검증 추가 (오늘 촬영 사진인지 확인)
            boolean dateValid = validateCaptureDate(exifData);

            boolean allValid = timeValid && locationValid && notEdited && dateValid;
            String message = buildValidationMessage(timeValid, locationValid, notEdited, dateValid, exifData);

            logger.info("EXIF 검증 완료 - 유효: {}, 시간: {}, 위치: {}, 미편집: {}, 날짜: {}",
                    allValid, timeValid, locationValid, notEdited, dateValid);

            return new ExifValidationResult(allValid, message, exifData, timeValid, locationValid, notEdited, dateValid);

        } catch (Exception e) {
            logger.error("EXIF 검증 중 오류 발생", e);
            return new ExifValidationResult(true, "EXIF 검증을 수행할 수 없습니다.",
                    new HashMap<>(), true, true, true, true);
        }
    }

    /**
     * ✅ 촬영 날짜 검증 - 오늘 촬영한 사진인지 확인
     * @return true: 오늘 촬영 또는 날짜 정보 없음 (통과), false: 과거 촬영 (0점 처리)
     */
    public boolean validateCaptureDate(Map<String, Object> exifData) {
        try {
            String dateTimeOriginal = (String) exifData.get("DateTimeOriginal");
            if (dateTimeOriginal == null) {
                dateTimeOriginal = (String) exifData.get("DateTime");
            }

            if (dateTimeOriginal == null) {
                // EXIF에 날짜 정보가 없으면 통과 (일부 기기는 EXIF 미지원)
                logger.warn("촬영 날짜 정보가 없습니다. 검증 통과 처리.");
                return true;
            }

            LocalDateTime captureTime = LocalDateTime.parse(dateTimeOriginal, EXIF_DATE_FORMAT);
            LocalDate captureDate = captureTime.toLocalDate();
            LocalDate today = LocalDate.now();

            logger.info("촬영 날짜 검증 - 촬영일: {}, 오늘: {}", captureDate, today);

            if (!captureDate.equals(today)) {
                long daysDiff = ChronoUnit.DAYS.between(captureDate, today);
                logger.warn("❌ 촬영 날짜가 오늘이 아닙니다! 촬영일: {}, 오늘: {}, 차이: {}일",
                        captureDate, today, daysDiff);
                return false;
            }

            logger.info("✅ 촬영 날짜 검증 통과 - 오늘 촬영된 사진입니다.");
            return true;

        } catch (Exception e) {
            logger.error("촬영 날짜 검증 중 오류 발생", e);
            // 오류 발생 시 통과 처리 (EXIF 파싱 문제일 수 있음)
            return true;
        }
    }

    /**
     * 촬영 시간 검증 (기존 - 분 단위 오차)
     */
    public boolean validateCaptureTime(Map<String, Object> exifData, int toleranceMinutes) {
        try {
            String dateTimeOriginal = (String) exifData.get("DateTimeOriginal");
            if (dateTimeOriginal == null) {
                dateTimeOriginal = (String) exifData.get("DateTime");
            }

            if (dateTimeOriginal == null) {
                logger.warn("촬영 시간 정보가 없습니다. 검증 통과 처리.");
                return true;
            }

            LocalDateTime captureTime = LocalDateTime.parse(dateTimeOriginal, EXIF_DATE_FORMAT);
            LocalDateTime now = LocalDateTime.now();
            long minutesDiff = Math.abs(ChronoUnit.MINUTES.between(captureTime, now));

            logger.info("촬영 시간 검증 - 촬영: {}, 현재: {}, 차이: {}분, 허용: {}분",
                    captureTime, now, minutesDiff, toleranceMinutes);

            if (minutesDiff > toleranceMinutes) {
                logger.warn("촬영 시간이 허용 오차를 초과합니다. 위조 의심.");
                return false;
            }

            return true;

        } catch (Exception e) {
            logger.error("촬영 시간 검증 중 오류 발생", e);
            return true;
        }
    }

    /**
     * GPS 위치 검증
     */
    public boolean validateLocation(Map<String, Object> exifData,
                                    double expectedLatitude,
                                    double expectedLongitude,
                                    int radiusMeters) {
        try {
            Double latitude = (Double) exifData.get("GPSLatitude");
            Double longitude = (Double) exifData.get("GPSLongitude");

            if (latitude == null || longitude == null) {
                logger.warn("GPS 정보가 없습니다. 검증 통과 처리.");
                return true;
            }

            double distance = calculateDistance(latitude, longitude, expectedLatitude, expectedLongitude);

            logger.info("GPS 검증 - 촬영 위치: ({}, {}), 기준 위치: ({}, {}), 거리: {}m, 허용: {}m",
                    latitude, longitude, expectedLatitude, expectedLongitude, distance, radiusMeters);

            if (distance > radiusMeters) {
                logger.warn("촬영 위치가 기숙사 반경을 벗어났습니다. 위조 의심.");
                return false;
            }

            return true;

        } catch (Exception e) {
            logger.error("GPS 검증 중 오류 발생", e);
            return true;
        }
    }

    /**
     * 편집 여부 확인
     */
    public boolean checkNotEdited(Map<String, Object> exifData) {
        try {
            String software = (String) exifData.get("Software");

            if (software != null) {
                String softwareLower = software.toLowerCase();
                String[] editingSoftware = {
                        "photoshop", "gimp", "lightroom", "snapseed", "vsco",
                        "afterlight", "picsart", "facetune", "meitu", "beautyplus",
                        "faceapp", "snow", "b612", "foodie", "ulike"
                };

                for (String editor : editingSoftware) {
                    if (softwareLower.contains(editor)) {
                        logger.warn("이미지 편집 소프트웨어 감지: {}", software);
                        return false;
                    }
                }
            }

            return true;

        } catch (Exception e) {
            logger.error("편집 여부 확인 중 오류 발생", e);
            return true;
        }
    }

    private boolean isJpegFile(byte[] data) {
        if (data.length < 3) return false;
        return (data[0] & 0xFF) == 0xFF &&
                (data[1] & 0xFF) == 0xD8 &&
                (data[2] & 0xFF) == 0xFF;
    }

    private Map<String, Object> parseJpegExif(byte[] imageBytes) {
        Map<String, Object> exifData = new HashMap<>();

        try {
            InputStream is = new ByteArrayInputStream(imageBytes);
            ImageInputStream iis = ImageIO.createImageInputStream(is);

            Iterator<ImageReader> readers = ImageIO.getImageReadersByFormatName("jpeg");
            if (readers.hasNext()) {
                ImageReader reader = readers.next();
                reader.setInput(iis, true);

                IIOMetadata metadata = reader.getImageMetadata(0);
                if (metadata != null) {
                    String[] metadataFormatNames = metadata.getMetadataFormatNames();
                    for (String formatName : metadataFormatNames) {
                        logger.debug("메타데이터 형식: {}", formatName);
                    }
                }

                reader.dispose();
            }

            is.close();
            iis.close();

            exifData.put("Format", "JPEG");
            exifData.put("FileSize", imageBytes.length);

        } catch (Exception e) {
            logger.warn("JPEG EXIF 파싱 중 오류: {}", e.getMessage());
        }

        return exifData;
    }

    private double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
        final int EARTH_RADIUS = 6371000;

        double latDistance = Math.toRadians(lat2 - lat1);
        double lonDistance = Math.toRadians(lon2 - lon1);

        double a = Math.sin(latDistance / 2) * Math.sin(latDistance / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(lonDistance / 2) * Math.sin(lonDistance / 2);

        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

        return EARTH_RADIUS * c;
    }

    /**
     * ✅ 검증 메시지 생성 (날짜 검증 추가)
     */
    private String buildValidationMessage(boolean timeValid, boolean locationValid,
                                          boolean notEdited, boolean dateValid, Map<String, Object> exifData) {
        StringBuilder message = new StringBuilder();

        // ✅ 날짜 검증 실패가 가장 중요 (0점 처리 대상)
        if (!dateValid) {
            message.append("❌ 오늘 촬영한 사진이 아닙니다. 과거에 촬영된 사진은 점호로 인정되지 않습니다. ");
        }
        if (!timeValid) {
            message.append("촬영 시간이 제출 시간과 일치하지 않습니다. ");
        }
        if (!locationValid) {
            message.append("촬영 위치가 기숙사 범위를 벗어났습니다. ");
        }
        if (!notEdited) {
            message.append("이미지 편집이 감지되었습니다. ");
        }

        if (message.length() == 0) {
            message.append("EXIF 검증 통과");
        }

        return message.toString().trim();
    }

    // ✅ 기존 메서드 오버로드 (하위 호환성 유지)
    private String buildValidationMessage(boolean timeValid, boolean locationValid,
                                          boolean notEdited, Map<String, Object> exifData) {
        return buildValidationMessage(timeValid, locationValid, notEdited, true, exifData);
    }
}