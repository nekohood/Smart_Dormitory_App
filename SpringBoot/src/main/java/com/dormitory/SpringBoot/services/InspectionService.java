package com.dormitory.SpringBoot.services;

import com.dormitory.SpringBoot.domain.BuildingTableConfig;
import com.dormitory.SpringBoot.domain.Inspection;
import com.dormitory.SpringBoot.domain.InspectionSettings;
import com.dormitory.SpringBoot.domain.User;
import com.dormitory.SpringBoot.dto.InspectionRequest;
import com.dormitory.SpringBoot.repository.InspectionRepository;
import com.dormitory.SpringBoot.repository.UserRepository;
import com.dormitory.SpringBoot.utils.EncryptionUtil;
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
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

/**
 * 점호 관련 비즈니스 로직을 처리하는 서비스
 * ✅ 시간 제한, EXIF 검증, 방 사진 검증 기능 통합
 * ✅ 통계 메서드 포함 (getTotalStatistics, getStatisticsByDate)
 * ✅ 기숙사별 점호 현황 테이블 기능 추가
 * ✅ 수동 FAIL/PASS 처리 기능 추가
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

    @Autowired
    private InspectionSettingsService settingsService;

    @Autowired
    private ExifService exifService;

    @Autowired
    private EncryptionUtil encryptionUtil;

    @Autowired
    private BuildingTableConfigService buildingConfigService;

    @Value("${inspection.pass.score:6}")
    private int passScore;

    @Value("${inspection.fail.score:5}")
    private int failScore;

    // ==================== 점호 제출 관련 메서드 ====================

    /**
     * ✅ 점호 제출 - 시간 제한 + EXIF 검증 + 방 사진 검증 통합
     */
    public InspectionRequest.Response submitInspection(String userId, String roomNumber, MultipartFile imageFile) {
        try {
            logger.info("점호 제출 시작 - 사용자: {}, 방번호: {}", userId, roomNumber);

            // 1. 사용자 정보 조회
            User user = userRepository.findById(userId)
                    .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다."));

            // 방 번호 결정 (사용자 프로필 > 요청값)
            String finalRoomNumber = user.getRoomNumber() != null ? user.getRoomNumber() : roomNumber;

            // 2. 점호 시간 확인
            InspectionSettingsService.InspectionTimeCheckResult timeCheck = settingsService.checkInspectionTimeAllowed();
            if (!timeCheck.isAllowed()) {
                logger.warn("점호 시간 외 제출 시도 - 사용자: {}", userId);
                throw new RuntimeException(timeCheck.getMessage());
            }

            // 3. 오늘 이미 점호를 완료했는지 확인
            List<Inspection> todayInspections = inspectionRepository.findTodayInspectionByUserId(userId);
            if (!todayInspections.isEmpty()) {
                Inspection existing = todayInspections.get(0);
                if ("PASS".equals(existing.getStatus())) {
                    throw new RuntimeException("오늘 이미 점호를 완료했습니다.");
                }
            }

            // 4. EXIF 검증 (설정에 따라)
            InspectionSettings currentSettings = timeCheck.getSettings();
            if (currentSettings != null && Boolean.TRUE.equals(currentSettings.getExifValidationEnabled())) {
                // EXIF 검증 파라미터 설정
                int toleranceMinutes = currentSettings.getExifTimeToleranceMinutes() != null
                        ? currentSettings.getExifTimeToleranceMinutes() : 30;
                Double expectedLatitude = Boolean.TRUE.equals(currentSettings.getGpsValidationEnabled())
                        ? currentSettings.getDormitoryLatitude() : null;
                Double expectedLongitude = Boolean.TRUE.equals(currentSettings.getGpsValidationEnabled())
                        ? currentSettings.getDormitoryLongitude() : null;
                int radiusMeters = currentSettings.getGpsRadiusMeters() != null
                        ? currentSettings.getGpsRadiusMeters() : 100;

                ExifService.ExifValidationResult exifResult = exifService.validateExif(
                        imageFile, toleranceMinutes, expectedLatitude, expectedLongitude, radiusMeters);

                if (!exifResult.isValid()) {
                    logger.warn("EXIF 검증 실패 - 사용자: {}, 메시지: {}", userId, exifResult.getMessage());

                    // EXIF 검증 실패 시 0점 처리
                    int score = 0;
                    String geminiFeedback = "❌ " + exifResult.getMessage();
                    String status = "FAIL";

                    return saveInspection(userId, finalRoomNumber, imageFile, score, geminiFeedback, status, false);
                }

                // ✅ 촬영 날짜 검증 실패 시 즉시 0점 처리
                if (!exifResult.isDateValid()) {
                    logger.warn("❌ 촬영 날짜 검증 실패 - 사용자: {}, 과거 촬영 사진 업로드 시도", userId);
                    int score = 0;
                    String geminiFeedback = "❌ 오늘 촬영한 사진이 아닙니다. 과거에 촬영된 사진은 점호로 인정되지 않습니다.";
                    String status = "FAIL";

                    return saveInspection(userId, finalRoomNumber, imageFile, score, geminiFeedback, status, false);
                }

                logger.info("EXIF 검증 통과 - 사용자: {}", userId);
            }

            // 5. AI 평가 - GeminiService의 실제 메서드 사용
            int score = geminiService.evaluateInspection(imageFile);
            String geminiFeedback = geminiService.getInspectionFeedback(imageFile);
            String status = score >= passScore ? "PASS" : "FAIL";

            logger.info("AI 평가 완료 - 사용자: {}, 점수: {}, 상태: {}", userId, score, status);

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
     * 재검 점호 제출
     */
    public InspectionRequest.Response submitReInspection(String userId, String roomNumber, MultipartFile imageFile) {
        try {
            logger.info("재검 점호 제출 시작 - 사용자: {}, 방번호: {}", userId, roomNumber);

            User user = userRepository.findById(userId)
                    .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다."));

            String finalRoomNumber = user.getRoomNumber() != null ? user.getRoomNumber() : roomNumber;

            // 오늘 실패한 점호가 있는지 확인
            List<Inspection> todayInspections = inspectionRepository.findTodayInspectionByUserId(userId);
            if (todayInspections.isEmpty()) {
                throw new RuntimeException("오늘 점호 기록이 없습니다.");
            }

            Inspection lastInspection = todayInspections.get(0);
            if (!"FAIL".equals(lastInspection.getStatus())) {
                throw new RuntimeException("재검 대상이 아닙니다.");
            }

            // AI 평가 - GeminiService의 실제 메서드 사용
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
     * 점호 저장 헬퍼 메서드
     */
    private InspectionRequest.Response saveInspection(String userId, String roomNumber,
                                                      MultipartFile imageFile, int score, String geminiFeedback,
                                                      String status, boolean isReInspection) {
        try {
            // FileService의 실제 메서드 사용
            String imagePath = fileService.uploadImage(imageFile, "inspections");

            Inspection inspection = new Inspection();
            inspection.setUserId(userId);
            inspection.setRoomNumber(roomNumber);
            inspection.setImagePath(imagePath);
            inspection.setScore(score);
            inspection.setStatus(status);
            inspection.setGeminiFeedback(geminiFeedback);
            inspection.setIsReInspection(isReInspection);
            inspection.setInspectionDate(LocalDateTime.now());
            inspection.setCreatedAt(LocalDateTime.now());

            Inspection savedInspection = inspectionRepository.save(inspection);
            logger.info("점호 저장 완료 - ID: {}", savedInspection.getId());

            return convertToResponse(savedInspection);

        } catch (Exception e) {
            logger.error("점호 저장 중 오류 발생", e);
            throw new RuntimeException("점호 저장 중 오류가 발생했습니다: " + e.getMessage());
        }
    }

    // ==================== 조회 메서드 ====================

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
     * 오늘 점호 조회 - ✅ Optional<Response> 반환
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
     * 특정 점호 기록 상세 조회 (관리자용) - ✅ AdminResponse 반환 (Optional 아님)
     */
    @Transactional(readOnly = true)
    public InspectionRequest.AdminResponse getInspectionById(Long inspectionId) {
        try {
            logger.info("점호 상세 조회 시작 - ID: {}", inspectionId);

            Inspection inspection = inspectionRepository.findById(inspectionId)
                    .orElseThrow(() -> new RuntimeException("점호 기록을 찾을 수 없습니다: " + inspectionId));

            InspectionRequest.AdminResponse response = convertToAdminResponse(inspection);

            logger.info("점호 상세 조회 완료 - ID: {}, 사용자: {}", inspectionId, inspection.getUserId());
            return response;

        } catch (RuntimeException e) {
            logger.error("점호 상세 조회 실패 - ID: {}", inspectionId, e);
            throw e;
        } catch (Exception e) {
            logger.error("점호 상세 조회 중 예기치 않은 오류 발생 - ID: {}", inspectionId, e);
            throw new RuntimeException("점호 상세 조회 중 오류가 발생했습니다: " + e.getMessage());
        }
    }

    /**
     * 특정 날짜의 점호 기록 조회
     */
    @Transactional(readOnly = true)
    public List<InspectionRequest.AdminResponse> getInspectionsByDate(String dateStr) {
        try {
            logger.info("날짜별 점호 기록 조회 시작 - 날짜: {}", dateStr);

            LocalDate localDate = LocalDate.parse(dateStr, DateTimeFormatter.ofPattern("yyyy-MM-dd"));
            LocalDateTime startOfDay = localDate.atStartOfDay();

            List<Inspection> inspections = inspectionRepository.findByInspectionDate(startOfDay);

            List<InspectionRequest.AdminResponse> responses = inspections.stream()
                    .map(this::convertToAdminResponse)
                    .collect(Collectors.toList());

            logger.info("날짜별 점호 기록 조회 완료 - 기록 수: {}", responses.size());
            return responses;

        } catch (Exception e) {
            logger.error("날짜별 점호 기록 조회 실패 - 날짜: {}", dateStr, e);
            throw new RuntimeException("날짜별 점호 기록 조회 중 오류가 발생했습니다: " + e.getMessage());
        }
    }

    // ==================== 수정/삭제 관련 메서드 ====================

    /**
     * ✅ 신규 추가: 수동 FAIL 처리
     * 점호 기록을 삭제하지 않고 상태만 FAIL로 변경
     */
    public InspectionRequest.AdminResponse manualFailInspection(Long inspectionId, String adminComment) {
        try {
            logger.info("수동 FAIL 처리 - ID: {}", inspectionId);

            Inspection inspection = inspectionRepository.findById(inspectionId)
                    .orElseThrow(() -> new RuntimeException("점호 기록을 찾을 수 없습니다: " + inspectionId));

            // 상태를 FAIL로 변경
            inspection.setStatus("FAIL");
            inspection.setAdminComment(adminComment != null && !adminComment.isEmpty()
                    ? adminComment
                    : "관리자에 의해 수동으로 FAIL 처리됨");
            inspection.setUpdatedAt(LocalDateTime.now());

            Inspection updated = inspectionRepository.save(inspection);
            logger.info("수동 FAIL 처리 완료 - ID: {}", inspectionId);

            return convertToAdminResponse(updated);

        } catch (RuntimeException e) {
            logger.error("수동 FAIL 처리 실패 - ID: {}", inspectionId, e);
            throw e;
        } catch (Exception e) {
            logger.error("수동 FAIL 처리 중 예기치 않은 오류 - ID: {}", inspectionId, e);
            throw new RuntimeException("수동 FAIL 처리 중 오류가 발생했습니다: " + e.getMessage());
        }
    }

    /**
     * ✅ 신규 추가: 수동 PASS 처리
     * 점호 기록을 삭제하지 않고 상태만 PASS로 변경
     */
    public InspectionRequest.AdminResponse manualPassInspection(Long inspectionId, String adminComment) {
        try {
            logger.info("수동 PASS 처리 - ID: {}", inspectionId);

            Inspection inspection = inspectionRepository.findById(inspectionId)
                    .orElseThrow(() -> new RuntimeException("점호 기록을 찾을 수 없습니다: " + inspectionId));

            // 상태를 PASS로 변경
            inspection.setStatus("PASS");
            inspection.setAdminComment(adminComment != null && !adminComment.isEmpty()
                    ? adminComment
                    : "관리자에 의해 수동으로 PASS 처리됨");
            inspection.setUpdatedAt(LocalDateTime.now());

            Inspection updated = inspectionRepository.save(inspection);
            logger.info("수동 PASS 처리 완료 - ID: {}", inspectionId);

            return convertToAdminResponse(updated);

        } catch (RuntimeException e) {
            logger.error("수동 PASS 처리 실패 - ID: {}", inspectionId, e);
            throw e;
        } catch (Exception e) {
            logger.error("수동 PASS 처리 중 예기치 않은 오류 - ID: {}", inspectionId, e);
            throw new RuntimeException("수동 PASS 처리 중 오류가 발생했습니다: " + e.getMessage());
        }
    }

    /**
     * 점호 반려 처리 (삭제)
     */
    public void rejectInspection(Long inspectionId, String rejectReason) {
        try {
            logger.info("점호 반려 처리 - ID: {}, 사유: {}", inspectionId, rejectReason);

            Inspection inspection = inspectionRepository.findById(inspectionId)
                    .orElseThrow(() -> new RuntimeException("점호 기록을 찾을 수 없습니다: " + inspectionId));

            // 반려 시 점호 기록 삭제
            inspectionRepository.delete(inspection);

            logger.info("점호 반려(삭제) 완료 - ID: {}", inspectionId);

        } catch (RuntimeException e) {
            logger.error("점호 반려 처리 실패 - ID: {}", inspectionId, e);
            throw e;
        } catch (Exception e) {
            logger.error("점호 반려 처리 중 예기치 않은 오류 - ID: {}", inspectionId, e);
            throw new RuntimeException("점호 반려 처리 중 오류가 발생했습니다: " + e.getMessage());
        }
    }

    /**
     * 점호 삭제
     */
    public void deleteInspection(Long inspectionId) {
        try {
            logger.info("점호 삭제 - ID: {}", inspectionId);

            if (!inspectionRepository.existsById(inspectionId)) {
                throw new RuntimeException("점호 기록을 찾을 수 없습니다: " + inspectionId);
            }

            inspectionRepository.deleteById(inspectionId);
            logger.info("점호 삭제 완료 - ID: {}", inspectionId);

        } catch (RuntimeException e) {
            logger.error("점호 삭제 실패 - ID: {}", inspectionId, e);
            throw e;
        } catch (Exception e) {
            logger.error("점호 삭제 중 예기치 않은 오류 - ID: {}", inspectionId, e);
            throw new RuntimeException("점호 삭제 중 오류가 발생했습니다: " + e.getMessage());
        }
    }

    /**
     * 점호 기록 수정 (관리자용)
     */
    public InspectionRequest.AdminResponse updateInspection(Long inspectionId, Map<String, Object> updateData) {
        try {
            logger.info("점호 기록 수정 - ID: {}", inspectionId);

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

            inspection.setUpdatedAt(LocalDateTime.now());

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
            inspection.setUpdatedAt(LocalDateTime.now());
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

    // ==================== 통계 메서드 ====================

    /**
     * 전체 통계 조회
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
     * 날짜별 점호 통계 조회
     */
    @Transactional(readOnly = true)
    public InspectionRequest.Statistics getStatisticsByDate(String dateStr) {
        try {
            logger.info("날짜별 통계 조회 시작 - 날짜: {}", dateStr);

            LocalDate localDate = LocalDate.parse(dateStr, DateTimeFormatter.ofPattern("yyyy-MM-dd"));
            LocalDateTime date = localDate.atStartOfDay();

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

    // ==================== 기숙사별 점호 현황 테이블 메서드 ====================

    /**
     * 기숙사별 점호 현황 테이블 데이터 조회
     */
    @Transactional(readOnly = true)
    public Map<String, Object> getBuildingInspectionStatus(String building, String dateStr) {
        try {
            logger.info("기숙사별 점호 현황 조회 - 동: {}, 날짜: {}", building, dateStr);

            LocalDate targetDate;
            if (dateStr == null || dateStr.isEmpty()) {
                targetDate = LocalDate.now();
            } else {
                targetDate = LocalDate.parse(dateStr, DateTimeFormatter.ofPattern("yyyy-MM-dd"));
            }

            LocalDateTime startOfDay = targetDate.atStartOfDay();
            LocalDateTime endOfDay = targetDate.atTime(23, 59, 59);

            // 해당 동의 사용자 조회
            List<User> buildingUsers = userRepository.findByDormitoryBuildingAndIsActiveTrue(building);

            // 해당 날짜의 점호 기록 조회
            List<Inspection> inspections = inspectionRepository.findByInspectionDateBetween(startOfDay, endOfDay);

            // 사용자별 점호 상태 매핑
            Map<String, Inspection> userInspectionMap = inspections.stream()
                    .filter(i -> building.equals(getUserBuilding(i.getUserId())))
                    .collect(Collectors.toMap(
                            Inspection::getUserId,
                            i -> i,
                            (existing, replacement) -> replacement
                    ));

            // 층별 호실 매트릭스 생성
            Map<Integer, Map<String, Object>> floorMatrix = new LinkedHashMap<>();

            for (User user : buildingUsers) {
                String roomNumber = user.getRoomNumber();
                if (roomNumber == null || roomNumber.isEmpty()) continue;

                int floor;
                try {
                    floor = Integer.parseInt(roomNumber.substring(0, 1));
                } catch (Exception e) {
                    continue;
                }

                floorMatrix.computeIfAbsent(floor, k -> new LinkedHashMap<>());

                Inspection inspection = userInspectionMap.get(user.getId());
                String status = inspection != null ? inspection.getStatus() : "NOT_SUBMITTED";

                Map<String, Object> roomInfo = new HashMap<>();
                roomInfo.put("roomNumber", roomNumber);
                roomInfo.put("userName", user.getName());
                roomInfo.put("status", status);
                roomInfo.put("score", inspection != null ? inspection.getScore() : null);

                floorMatrix.get(floor).put(roomNumber, roomInfo);
            }

            Map<String, Object> result = new HashMap<>();
            result.put("building", building);
            result.put("date", targetDate.toString());
            result.put("floorMatrix", floorMatrix);
            result.put("totalUsers", buildingUsers.size());
            result.put("submittedCount", userInspectionMap.size());
            result.put("passedCount", userInspectionMap.values().stream()
                    .filter(i -> "PASS".equals(i.getStatus())).count());
            result.put("failedCount", userInspectionMap.values().stream()
                    .filter(i -> "FAIL".equals(i.getStatus())).count());

            logger.info("기숙사별 점호 현황 조회 완료 - 동: {}", building);
            return result;

        } catch (Exception e) {
            logger.error("기숙사별 점호 현황 조회 실패 - 동: {}", building, e);
            throw new RuntimeException("기숙사별 점호 현황 조회 중 오류가 발생했습니다: " + e.getMessage());
        }
    }

    /**
     * 기숙사 동 목록 조회
     */
    @Transactional(readOnly = true)
    public List<String> getAllBuildings() {
        try {
            logger.info("기숙사 동 목록 조회 시작");

            // 1. 사용자 데이터에서 기숙사 목록 조회
            List<String> userBuildings = userRepository.findDistinctDormitoryBuildings();

            // 2. 테이블 설정에서 기숙사 목록 조회
            List<BuildingTableConfig> configs = buildingConfigService.getActiveConfigs();
            List<String> configBuildings = configs.stream()
                    .map(BuildingTableConfig::getBuildingName)
                    .filter(name -> name != null && !name.trim().isEmpty())
                    .collect(Collectors.toList());

            // 3. 두 목록 합치기 (중복 제거, 정렬)
            java.util.Set<String> allBuildings = new java.util.TreeSet<>();

            if (userBuildings != null) {
                userBuildings.stream()
                        .filter(b -> b != null && !b.trim().isEmpty())
                        .forEach(allBuildings::add);
            }

            allBuildings.addAll(configBuildings);

            List<String> result = new ArrayList<>(allBuildings);

            logger.info("기숙사 동 목록 조회 완료 - {}개 동", result.size());
            return result;

        } catch (Exception e) {
            logger.error("기숙사 동 목록 조회 실패", e);
            throw new RuntimeException("기숙사 동 목록 조회 중 오류가 발생했습니다: " + e.getMessage());
        }
    }

    // ==================== 유틸리티 메서드 ====================

    /**
     * 사용자 ID로 기숙사 동 조회
     */
    private String getUserBuilding(String userId) {
        return userRepository.findById(userId)
                .map(User::getDormitoryBuilding)
                .orElse(null);
    }

    /**
     * Inspection -> Response 변환
     */
    private InspectionRequest.Response convertToResponse(Inspection inspection) {
        InspectionRequest.Response response = new InspectionRequest.Response();
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
        return response;
    }

    /**
     * Inspection -> AdminResponse 변환
     */
    private InspectionRequest.AdminResponse convertToAdminResponse(Inspection inspection) {
        String userName = userRepository.findById(inspection.getUserId())
                .map(User::getName)
                .orElse("알 수 없음");

        String dormitoryBuilding = userRepository.findById(inspection.getUserId())
                .map(User::getDormitoryBuilding)
                .orElse(null);

        InspectionRequest.AdminResponse response = new InspectionRequest.AdminResponse();
        response.setId(inspection.getId());
        response.setUserId(inspection.getUserId());
        response.setUserName(userName);
        response.setDormitoryBuilding(dormitoryBuilding);
        response.setRoomNumber(inspection.getRoomNumber());
        response.setImagePath(inspection.getImagePath());
        response.setScore(inspection.getScore());
        response.setStatus(inspection.getStatus());
        response.setGeminiFeedback(inspection.getGeminiFeedback());
        response.setAdminComment(inspection.getAdminComment());
        response.setIsReInspection(inspection.getIsReInspection());
        response.setInspectionDate(inspection.getInspectionDate());
        response.setCreatedAt(inspection.getCreatedAt());

        return response;
    }
}