package com.dormitory.SpringBoot.services;

import com.dormitory.SpringBoot.domain.Inspection;
import com.dormitory.SpringBoot.domain.InspectionSettings;
import com.dormitory.SpringBoot.domain.User;
import com.dormitory.SpringBoot.dto.InspectionRequest;
import com.dormitory.SpringBoot.repository.InspectionRepository;
import com.dormitory.SpringBoot.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

/**
 * 점호 관련 비즈니스 로직을 처리하는 서비스
 * ✅ 시간 제한, EXIF 검증, 방 사진 검증 기능 통합
 * ✅ 통계 메서드 포함 (getTotalStatistics, getStatisticsByDate)
 */
@Service
@Transactional
public class InspectionService {

    private static final Logger logger = LoggerFactory.getLogger(InspectionService.class);

    @Autowired
    private InspectionRepository inspectionRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private GeminiService geminiService;

    @Autowired
    private FileService fileService;

    @Autowired
    private AttendanceTableService attendanceTableService;

    // ✅ 새로 추가된 검증 서비스들
    @Autowired
    private InspectionSettingsService settingsService;

    @Autowired
    private ExifService exifService;

    @Value("${inspection.pass.score:6}")
    private int passScore;

    @Value("${inspection.fail.score:5}")
    private int failScore;

    /**
     * ✅ 점호 제출 - 시간 제한 + EXIF 검증 + 방 사진 검증 통합
     */
    public InspectionRequest.Response submitInspection(String userId, String roomNumber, MultipartFile imageFile) {
        try {
            logger.info("점호 제출 시작 - 사용자: {}, 방번호: {}", userId, roomNumber);

            // ✅ 1. 점호 시간 검증
            InspectionSettingsService.InspectionTimeCheckResult timeResult =
                    settingsService.checkInspectionTimeAllowed();

            if (!timeResult.isAllowed()) {
                logger.warn("점호 시간이 아닙니다: {}", timeResult.getMessage());
                throw new RuntimeException(timeResult.getMessage());
            }

            // 사용자 정보 조회
            User user = userRepository.findById(userId)
                    .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다: " + userId));

            String finalRoomNumber = roomNumber;
            String dormitoryBuilding = user.getDormitoryBuilding();

            if (finalRoomNumber == null || finalRoomNumber.trim().isEmpty()) {
                finalRoomNumber = user.getRoomNumber();
                if (finalRoomNumber == null || finalRoomNumber.trim().isEmpty()) {
                    throw new RuntimeException("방 번호 정보가 없습니다. 마이페이지에서 거주 정보를 등록해주세요.");
                }
                logger.info("사용자 정보에서 방 번호 자동 기입: {}", finalRoomNumber);
            }

            // 오늘 이미 점호했는지 확인
            List<Inspection> todayInspections = inspectionRepository.findTodayInspectionByUserId(userId);
            if (!todayInspections.isEmpty()) {
                throw new RuntimeException("오늘 이미 점호를 완료했습니다.");
            }

            // ✅ 2. 현재 설정 가져오기
            Optional<InspectionSettings> settingsOpt = settingsService.getCurrentSettings();
            InspectionSettings settings = settingsOpt.orElse(null);

            int score;
            String geminiFeedback;
            String status;
            boolean exifValid = true;
            StringBuilder feedbackBuilder = new StringBuilder();

            // ✅ 3. EXIF 검증 (설정에서 활성화된 경우)
            if (settings != null && Boolean.TRUE.equals(settings.getExifValidationEnabled())) {
                ExifService.ExifValidationResult exifResult = exifService.validateExif(
                        imageFile,
                        settings.getExifTimeToleranceMinutes(),
                        settings.getGpsValidationEnabled() ? settings.getDormitoryLatitude() : null,
                        settings.getGpsValidationEnabled() ? settings.getDormitoryLongitude() : null,
                        settings.getGpsRadiusMeters() != null ? settings.getGpsRadiusMeters() : 100
                );

                exifValid = exifResult.isValid();
                if (!exifValid) {
                    feedbackBuilder.append("⚠️ EXIF 검증 실패: ").append(exifResult.getMessage()).append("\n");
                    logger.warn("EXIF 검증 실패 - 사용자: {}, 사유: {}", userId, exifResult.getMessage());
                }
            }

            // ✅ 4. AI 평가
            score = geminiService.evaluateInspection(imageFile);
            geminiFeedback = geminiService.getInspectionFeedback(imageFile);

            // ✅ 5. 방 사진 검증 (AI 피드백에서 방이 아닌 경우 감지)
            if (settings != null && Boolean.TRUE.equals(settings.getRoomPhotoValidationEnabled())) {
                if (isNotRoomPhoto(geminiFeedback)) {
                    logger.warn("방 사진이 아닙니다 - 사용자: {}", userId);
                    score = 0;
                    geminiFeedback = "❌ 방 사진이 아닙니다. " + extractNonRoomReason(geminiFeedback);
                    status = "FAIL";
                    return saveInspection(userId, finalRoomNumber, imageFile, score, geminiFeedback, status, false);
                }
            }

            // ✅ 6. EXIF 위조 의심 시 점수 감점
            if (!exifValid) {
                int originalScore = score;
                score = Math.max(0, score - 3);
                feedbackBuilder.append("📉 EXIF 검증 실패로 3점 감점 (").append(originalScore).append("점 → ").append(score).append("점)\n");
            }

            feedbackBuilder.append(geminiFeedback);
            geminiFeedback = feedbackBuilder.toString().trim();

            status = score >= passScore ? "PASS" : "FAIL";
            logger.info("AI 평가 완료 - 점수: {}, 상태: {}, EXIF 검증: {}", score, status, exifValid);

            return saveInspection(userId, finalRoomNumber, imageFile, score, geminiFeedback, status, false);

        } catch (RuntimeException e) {
            logger.error("점호 제출 실패 - 사용자: {}, 오류: {}", userId, e.getMessage());
            throw e;
        } catch (Exception e) {
            logger.error("점호 제출 중 예기치 않은 오류 발생 - 사용자: {}", userId, e);
            throw new RuntimeException("점호 제출 중 오류가 발생했습니다: " + e.getMessage());
        }
    }

    /**
     * 점호 저장 공통 메서드
     */
    private InspectionRequest.Response saveInspection(String userId, String roomNumber,
                                                      MultipartFile imageFile, int score, String geminiFeedback, String status, boolean isReInspection) {
        try {
            String imagePath = fileService.uploadImage(imageFile, "inspection");
            logger.info("이미지 업로드 완료: {}", imagePath);

            Inspection inspection = new Inspection();
            inspection.setUserId(userId);
            inspection.setRoomNumber(roomNumber);
            inspection.setImagePath(imagePath);
            inspection.setScore(score);
            inspection.setStatus(status);
            inspection.setGeminiFeedback(geminiFeedback);
            inspection.setInspectionDate(LocalDateTime.now());
            inspection.setIsReInspection(isReInspection);

            Inspection savedInspection = inspectionRepository.save(inspection);
            logger.info("점호 제출 완료 - ID: {}, 방 번호: {}, 점수: {}, 상태: {}",
                    savedInspection.getId(), roomNumber, score, status);

            try {
                LocalDate today = LocalDate.now();
                attendanceTableService.updateAttendanceOnInspectionSubmit(userId, today, score, status);
                logger.info("출석 테이블 업데이트 완료 - 사용자: {}", userId);
            } catch (Exception e) {
                logger.warn("출석 테이블 업데이트 실패 (무시): {}", e.getMessage());
            }

            return convertToResponse(savedInspection);

        } catch (Exception e) {
            logger.error("점호 저장 중 오류 발생", e);
            throw new RuntimeException("점호 저장 중 오류가 발생했습니다: " + e.getMessage());
        }
    }

    /**
     * 방 사진이 아닌지 확인
     */
    private boolean isNotRoomPhoto(String feedback) {
        if (feedback == null) return false;

        String lower = feedback.toLowerCase();
        String[] nonRoomKeywords = {
                "방_사진_여부: 아니오", "방 사진이 아", "방이 아닙니다",
                "화장실", "샤워", "복도", "계단", "로비", "야외", "외부", "옥외",
                "식당", "세탁", "공용", "셀카만", "실외", "밖",
                "not a room", "bathroom", "toilet", "hallway", "outside"
        };

        for (String keyword : nonRoomKeywords) {
            if (lower.contains(keyword.toLowerCase())) {
                return true;
            }
        }

        return false;
    }

    /**
     * 방이 아닌 이유 추출
     */
    private String extractNonRoomReason(String feedback) {
        if (feedback == null) return "기숙사 방 사진이 아닌 것으로 판단됩니다.";

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

    /**
     * 재검 점호 제출
     */
    public InspectionRequest.Response submitReInspection(String userId, String roomNumber, MultipartFile imageFile) {
        try {
            logger.info("재검 점호 제출 시작 - 사용자: {}, 방번호: {}", userId, roomNumber);

            // 점호 시간 검증
            InspectionSettingsService.InspectionTimeCheckResult timeResult =
                    settingsService.checkInspectionTimeAllowed();

            if (!timeResult.isAllowed()) {
                logger.warn("점호 시간이 아닙니다: {}", timeResult.getMessage());
                throw new RuntimeException(timeResult.getMessage());
            }

            User user = userRepository.findById(userId)
                    .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다: " + userId));

            String finalRoomNumber = roomNumber;
            if (finalRoomNumber == null || finalRoomNumber.trim().isEmpty()) {
                finalRoomNumber = user.getRoomNumber();
                if (finalRoomNumber == null || finalRoomNumber.trim().isEmpty()) {
                    throw new RuntimeException("방 번호 정보가 없습니다.");
                }
            }

            List<Inspection> todayInspections = inspectionRepository.findTodayInspectionByUserId(userId);
            if (todayInspections.isEmpty()) {
                throw new RuntimeException("오늘 점호 기록이 없습니다.");
            }

            Inspection lastInspection = todayInspections.get(0);
            if (!"FAIL".equals(lastInspection.getStatus())) {
                throw new RuntimeException("재검 대상이 아닙니다.");
            }

            int score = geminiService.evaluateInspection(imageFile);
            String geminiFeedback = geminiService.getInspectionFeedback(imageFile);
            String status = score >= passScore ? "PASS" : "FAIL";

            logger.info("재검 AI 평가 완료 - 점수: {}, 상태: {}", score, status);

            return saveInspection(userId, finalRoomNumber, imageFile, score, geminiFeedback, status, true);

        } catch (RuntimeException e) {
            logger.error("재검 점호 제출 실패 - 사용자: {}, 오류: {}", userId, e.getMessage());
            throw e;
        } catch (Exception e) {
            logger.error("재검 점호 제출 중 예기치 않은 오류 발생 - 사용자: {}", userId, e);
            throw new RuntimeException("재검 점호 제출 중 오류가 발생했습니다: " + e.getMessage());
        }
    }

    /**
     * 사용자의 점호 기록 조회
     */
    @Transactional(readOnly = true)
    public List<InspectionRequest.AdminResponse> getUserInspections(String userId) {
        try {
            logger.info("사용자 점호 기록 조회 시작 - 사용자: {}", userId);

            List<Inspection> inspections = inspectionRepository.findByUserIdOrderByCreatedAtDesc(userId);
            List<InspectionRequest.AdminResponse> responses = inspections.stream()
                    .map(this::convertToAdminResponse)
                    .collect(Collectors.toList());

            logger.info("사용자 점호 기록 조회 완료 - 사용자: {}, 기록 수: {}", userId, responses.size());
            return responses;

        } catch (Exception e) {
            logger.error("사용자 점호 기록 조회 실패 - 사용자: {}", userId, e);
            throw new RuntimeException("점호 기록 조회 중 오류가 발생했습니다: " + e.getMessage());
        }
    }

    /**
     * 오늘 점호 조회
     */
    @Transactional(readOnly = true)
    public Optional<InspectionRequest.Response> getTodayInspection(String userId) {
        try {
            logger.info("오늘 점호 조회 시작 - 사용자: {}", userId);

            List<Inspection> todayInspections = inspectionRepository.findTodayInspectionByUserId(userId);
            Optional<Inspection> todayInspection = todayInspections.stream().findFirst();

            Optional<InspectionRequest.Response> result = todayInspection.map(this::convertToResponse);

            logger.info("오늘 점호 조회 완료 - 결과: {}", result.isPresent() ? "있음" : "없음");
            return result;

        } catch (Exception e) {
            logger.error("오늘 점호 조회 중 오류 발생", e);
            throw new RuntimeException("오늘 점호 조회에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 모든 점호 기록 조회 (관리자용)
     */
    @Transactional(readOnly = true)
    public List<InspectionRequest.AdminResponse> getAllInspections() {
        try {
            logger.info("전체 점호 기록 조회 시작");

            List<Inspection> inspections = inspectionRepository.findAll();

            List<InspectionRequest.AdminResponse> responses = inspections.stream()
                    .sorted((i1, i2) -> i2.getCreatedAt().compareTo(i1.getCreatedAt()))
                    .map(this::convertToAdminResponse)
                    .collect(Collectors.toList());

            logger.info("전체 점호 기록 조회 완료 - 기록 수: {}", responses.size());
            return responses;

        } catch (Exception e) {
            logger.error("전체 점호 기록 조회 실패", e);
            throw new RuntimeException("점호 기록 조회 중 오류가 발생했습니다: " + e.getMessage());
        }
    }

    /**
     * 특정 날짜의 점호 기록 조회
     */
    @Transactional(readOnly = true)
    public List<InspectionRequest.AdminResponse> getInspectionsByDate(String dateStr) {
        try {
            logger.info("특정 날짜 점호 기록 조회 - 날짜: {}", dateStr);

            LocalDateTime date = LocalDateTime.parse(dateStr + " 00:00:00",
                    DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));

            List<Inspection> inspections = inspectionRepository.findByInspectionDate(date);
            List<InspectionRequest.AdminResponse> responses = inspections.stream()
                    .map(this::convertToAdminResponse)
                    .collect(Collectors.toList());

            logger.info("특정 날짜 점호 기록 조회 완료 - 날짜: {}, 기록 수: {}", dateStr, responses.size());
            return responses;

        } catch (Exception e) {
            logger.error("특정 날짜 점호 기록 조회 실패 - 날짜: {}", dateStr, e);
            throw new RuntimeException("점호 기록 조회 중 오류가 발생했습니다: " + e.getMessage());
        }
    }

    /**
     * 점호 삭제
     */
    public void deleteInspection(Long inspectionId) {
        try {
            logger.info("점호 삭제 시작 - ID: {}", inspectionId);

            Inspection inspection = inspectionRepository.findById(inspectionId)
                    .orElseThrow(() -> new RuntimeException("점호 기록을 찾을 수 없습니다: " + inspectionId));

            if (inspection.getImagePath() != null) {
                try {
                    fileService.deleteFile(inspection.getImagePath());
                } catch (Exception e) {
                    logger.warn("이미지 파일 삭제 실패: {}", e.getMessage());
                }
            }

            inspectionRepository.delete(inspection);
            logger.info("점호 삭제 완료 - ID: {}", inspectionId);

        } catch (RuntimeException e) {
            logger.error("점호 삭제 실패 - ID: {}", inspectionId, e);
            throw e;
        } catch (Exception e) {
            logger.error("점호 삭제 중 예기치 않은 오류 발생 - ID: {}", inspectionId, e);
            throw new RuntimeException("점호 삭제 중 오류가 발생했습니다: " + e.getMessage());
        }
    }

    /**
     * 점호 기록 수정
     */
    public InspectionRequest.AdminResponse updateInspection(Long inspectionId, Map<String, Object> updateData) {
        try {
            logger.info("점호 기록 수정 시작 - ID: {}", inspectionId);

            Inspection inspection = inspectionRepository.findById(inspectionId)
                    .orElseThrow(() -> new RuntimeException("점호 기록을 찾을 수 없습니다: " + inspectionId));

            if (updateData.containsKey("score")) {
                inspection.setScore((Integer) updateData.get("score"));
            }
            if (updateData.containsKey("status")) {
                inspection.setStatus((String) updateData.get("status"));
            }
            if (updateData.containsKey("geminiFeedback")) {
                inspection.setGeminiFeedback((String) updateData.get("geminiFeedback"));
            }
            if (updateData.containsKey("adminComment")) {
                inspection.setAdminComment((String) updateData.get("adminComment"));
            }
            if (updateData.containsKey("isReInspection")) {
                inspection.setIsReInspection((Boolean) updateData.get("isReInspection"));
            }

            Inspection updatedInspection = inspectionRepository.save(inspection);
            logger.info("점호 기록 수정 완료 - ID: {}", inspectionId);

            return convertToAdminResponse(updatedInspection);

        } catch (RuntimeException e) {
            logger.error("점호 기록 수정 실패 - ID: {}", inspectionId, e);
            throw e;
        } catch (Exception e) {
            logger.error("점호 기록 수정 중 예기치 않은 오류 발생 - ID: {}", inspectionId, e);
            throw new RuntimeException("점호 기록 수정 중 오류가 발생했습니다: " + e.getMessage());
        }
    }

    /**
     * 관리자 코멘트 추가
     */
    public InspectionRequest.Response addAdminComment(Long inspectionId, String adminComment) {
        try {
            logger.info("관리자 코멘트 추가 - ID: {}", inspectionId);

            Inspection inspection = inspectionRepository.findById(inspectionId)
                    .orElseThrow(() -> new RuntimeException("점호 기록을 찾을 수 없습니다: " + inspectionId));

            inspection.setAdminComment(adminComment);
            Inspection updatedInspection = inspectionRepository.save(inspection);

            logger.info("관리자 코멘트 추가 완료 - ID: {}", inspectionId);
            return convertToResponse(updatedInspection);

        } catch (RuntimeException e) {
            logger.error("관리자 코멘트 추가 실패 - ID: {}", inspectionId, e);
            throw e;
        } catch (Exception e) {
            logger.error("관리자 코멘트 추가 중 예기치 않은 오류 발생 - ID: {}", inspectionId, e);
            throw new RuntimeException("관리자 코멘트 추가 중 오류가 발생했습니다: " + e.getMessage());
        }
    }

    // ==================== ✅ 통계 메서드 ====================

    /**
     * ✅ 전체 통계 조회
     */
    @Transactional(readOnly = true)
    public InspectionRequest.Statistics getTotalStatistics() {
        try {
            logger.info("전체 통계 조회 시작");

            long total = inspectionRepository.count();
            long passed = inspectionRepository.countByStatus("PASS");
            long failed = inspectionRepository.countByStatus("FAIL");
            long reInspections = inspectionRepository.findByIsReInspectionTrueOrderByCreatedAtDesc().size();

            InspectionRequest.Statistics result = new InspectionRequest.Statistics(
                    total, passed, failed, reInspections, LocalDateTime.now());

            logger.info("전체 통계 조회 완료 - 전체: {}, 통과: {}, 실패: {}, 재검: {}",
                    total, passed, failed, reInspections);
            return result;

        } catch (Exception e) {
            logger.error("전체 통계 조회 중 오류 발생", e);
            throw new RuntimeException("통계 조회에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * ✅ 날짜별 점호 통계 조회
     */
    @Transactional(readOnly = true)
    public InspectionRequest.Statistics getStatisticsByDate(String dateStr) {
        try {
            logger.info("날짜별 통계 조회 시작 - 날짜: {}", dateStr);

            // String -> LocalDateTime 변환
            LocalDateTime date = LocalDateTime.parse(dateStr + " 00:00:00",
                    DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));

            long total = inspectionRepository.countTotalInspectionsByDate(date);
            long passed = inspectionRepository.countPassedInspectionsByDate(date);
            long failed = inspectionRepository.countFailedInspectionsByDate(date);
            long reInspections = inspectionRepository.countReInspectionsByDate(date);

            InspectionRequest.Statistics result = new InspectionRequest.Statistics(
                    total, passed, failed, reInspections, date);

            logger.info("날짜별 통계 조회 완료 - 날짜: {}, 전체: {}, 통과: {}, 실패: {}",
                    dateStr, total, passed, failed);
            return result;

        } catch (Exception e) {
            logger.error("날짜별 통계 조회 중 오류 발생", e);
            throw new RuntimeException("날짜별 통계 조회에 실패했습니다: " + e.getMessage());
        }
    }

    // ========== 변환 메서드들 ==========

    private InspectionRequest.Response convertToResponse(Inspection inspection) {
        InspectionRequest.Response response = new InspectionRequest.Response();
        response.setId(inspection.getId());
        response.setUserId(inspection.getUserId());
        response.setRoomNumber(inspection.getRoomNumber());
        response.setImagePath(inspection.getImagePath());
        response.setScore(inspection.getScore());
        response.setStatus(inspection.getStatus());
        response.setGeminiFeedback(inspection.getGeminiFeedback());
        response.setInspectionDate(inspection.getInspectionDate());
        response.setCreatedAt(inspection.getCreatedAt());
        return response;
    }

    private InspectionRequest.AdminResponse convertToAdminResponse(Inspection inspection) {
        InspectionRequest.AdminResponse response = new InspectionRequest.AdminResponse();
        response.setId(inspection.getId());
        response.setUserId(inspection.getUserId());
        response.setRoomNumber(inspection.getRoomNumber());
        response.setImagePath(inspection.getImagePath());
        response.setScore(inspection.getScore());
        response.setStatus(inspection.getStatus());
        response.setGeminiFeedback(inspection.getGeminiFeedback());
        response.setAdminComment(inspection.getAdminComment());
        response.setIsReInspection(inspection.getIsReInspection());
        response.setInspectionDate(inspection.getInspectionDate());
        response.setCreatedAt(inspection.getCreatedAt());
        response.setUpdatedAt(inspection.getUpdatedAt());
        return response;
    }
}