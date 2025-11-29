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

    // ✅ 테이블 설정 서비스 추가
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
                throw new RuntimeException("오늘 이미 점호를 완료했습니다.");
            }

            // 4. EXIF 검증 (설정에 따라)
            InspectionSettings currentSettings = timeCheck.getSettings();
            if (currentSettings != null && currentSettings.getExifValidationEnabled()) {
                // EXIF 검증 파라미터 설정
                int toleranceMinutes = currentSettings.getExifTimeToleranceMinutes() != null
                        ? currentSettings.getExifTimeToleranceMinutes() : 30;
                Double expectedLatitude = currentSettings.getGpsValidationEnabled()
                        ? currentSettings.getDormitoryLatitude() : null;
                Double expectedLongitude = currentSettings.getGpsValidationEnabled()
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

            // 5. AI 평가
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
     * 특정 점호 기록 상세 조회 (관리자용)
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

    // ==================== 수정/삭제 메서드 ====================

    /**
     * 점호 반려 (관리자)
     */
    public void rejectInspection(Long inspectionId, String reason) {
        try {
            logger.info("점호 반려 시작 - ID: {}, 사유: {}", inspectionId, reason);

            Inspection inspection = inspectionRepository.findById(inspectionId)
                    .orElseThrow(() -> new RuntimeException("점호 기록을 찾을 수 없습니다: " + inspectionId));

            String userId = inspection.getUserId();

            // 이미지 파일 삭제
            if (inspection.getImagePath() != null) {
                try {
                    fileService.deleteFile(inspection.getImagePath());
                    logger.info("점호 이미지 삭제 완료: {}", inspection.getImagePath());
                } catch (Exception e) {
                    logger.warn("점호 이미지 삭제 실패: {}", e.getMessage());
                }
            }

            // 점호 기록 삭제
            inspectionRepository.delete(inspection);
            logger.info("점호 반려 완료 - ID: {}, 사용자: {}", inspectionId, userId);

        } catch (RuntimeException e) {
            logger.error("점호 반려 실패 - ID: {}", inspectionId, e);
            throw e;
        } catch (Exception e) {
            logger.error("점호 반려 중 예기치 않은 오류 발생 - ID: {}", inspectionId, e);
            throw new RuntimeException("점호 반려 중 오류가 발생했습니다: " + e.getMessage());
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

            // 이미지 파일 삭제
            if (inspection.getImagePath() != null) {
                try {
                    fileService.deleteFile(inspection.getImagePath());
                    logger.info("점호 이미지 삭제 완료: {}", inspection.getImagePath());
                } catch (Exception e) {
                    logger.warn("이미지 파일 삭제 실패: {}", e.getMessage());
                }
            }

            // 점호 기록 삭제
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

    // ==================== 기숙사별 점호 현황 테이블 메서드 ====================

    /**
     * ✅ 기숙사별 점호 현황 테이블 데이터 조회 (테이블 설정 적용)
     * 층/호실 매트릭스 형태로 점호 상태 반환
     */
    @Transactional(readOnly = true)
    public Map<String, Object> getBuildingInspectionStatus(String building, String dateStr) {
        try {
            logger.info("기숙사별 점호 현황 조회 시작 - 동: {}, 날짜: {}", building, dateStr);

            // 날짜 파싱 (없으면 오늘)
            LocalDate targetDate;
            if (dateStr == null || dateStr.isEmpty()) {
                targetDate = LocalDate.now();
            } else {
                targetDate = LocalDate.parse(dateStr);
            }

            LocalDateTime startOfDay = targetDate.atStartOfDay();
            LocalDateTime endOfDay = targetDate.atTime(23, 59, 59);

            // ✅ 테이블 설정 조회 (없으면 예시용 기본값)
            BuildingTableConfig tableConfig = buildingConfigService.getConfigOrDefault(building);

            // 기본값 여부 확인
            boolean isDefaultConfig = (tableConfig.getId() == null);

            int startFloor = tableConfig.getStartFloor();
            int endFloor = tableConfig.getEndFloor();
            int startRoom = tableConfig.getStartRoom();
            int endRoom = tableConfig.getEndRoom();
            String roomNumberFormat = tableConfig.getRoomNumberFormat();

            logger.info("테이블 설정 - 층: {}~{}, 호실: {}~{}, 형식: {}",
                    startFloor, endFloor, startRoom, endRoom, roomNumberFormat);

            // 해당 기숙사의 모든 사용자 조회
            List<User> buildingUsers = userRepository.findByDormitoryBuildingAndIsActiveTrue(building);

            // 해당 날짜의 점호 기록 조회
            List<Inspection> inspections = inspectionRepository.findByInspectionDateBetween(startOfDay, endOfDay);

            // 해당 기숙사 사용자들의 점호 기록만 필터링
            Map<String, Inspection> userInspectionMap = inspections.stream()
                    .filter(i -> buildingUsers.stream().anyMatch(u -> u.getId().equals(i.getUserId())))
                    .collect(Collectors.toMap(
                            Inspection::getUserId,
                            i -> i,
                            (existing, replacement) -> replacement
                    ));

            // ✅ 동적 층/호실 목록 생성
            List<Integer> floors = new ArrayList<>();
            for (int f = startFloor; f <= endFloor; f++) {
                floors.add(f);
            }

            List<Integer> rooms = new ArrayList<>();
            for (int r = startRoom; r <= endRoom; r++) {
                rooms.add(r);
            }

            // 호실별 상태 매트릭스 생성
            Map<String, Map<String, Object>> matrix = new LinkedHashMap<>();

            for (int floor : floors) {
                Map<String, Object> floorData = new LinkedHashMap<>();

                for (int room : rooms) {
                    // ✅ 방 번호 형식에 따라 생성
                    String roomNumber;
                    if ("FLOOR_ZERO_ROOM".equals(roomNumberFormat)) {
                        roomNumber = String.valueOf(floor * 1000 + room);
                    } else {
                        roomNumber = String.valueOf(floor * 100 + room);
                    }

                    // 해당 호실의 사용자 찾기
                    List<User> roomUsers = buildingUsers.stream()
                            .filter(u -> roomNumber.equals(u.getRoomNumber()))
                            .collect(Collectors.toList());

                    Map<String, Object> roomStatus = new HashMap<>();
                    roomStatus.put("roomNumber", roomNumber);
                    roomStatus.put("floor", floor);
                    roomStatus.put("room", room);

                    if (roomUsers.isEmpty()) {
                        roomStatus.put("status", "EMPTY");
                        roomStatus.put("statusText", "빈 방");
                        roomStatus.put("userCount", 0);
                    } else {
                        List<Map<String, Object>> userStatuses = new ArrayList<>();
                        String overallStatus = "NOT_SUBMITTED";

                        boolean hasPass = false;
                        boolean hasFail = false;
                        boolean hasRejected = false;
                        boolean hasPending = false;
                        int submittedCount = 0;

                        for (User user : roomUsers) {
                            Map<String, Object> userStatus = new HashMap<>();
                            userStatus.put("userId", user.getId());
                            userStatus.put("userName", decryptUserName(user.getName()));

                            Inspection inspection = userInspectionMap.get(user.getId());

                            if (inspection != null) {
                                submittedCount++;
                                userStatus.put("inspectionId", inspection.getId());
                                userStatus.put("status", inspection.getStatus());
                                userStatus.put("score", inspection.getScore());
                                userStatus.put("inspectionTime", inspection.getInspectionDate());

                                String status = inspection.getStatus();
                                if ("PASS".equals(status)) hasPass = true;
                                else if ("FAIL".equals(status)) hasFail = true;
                                else if ("REJECTED".equals(status)) hasRejected = true;
                                else if ("PENDING".equals(status)) hasPending = true;
                            } else {
                                userStatus.put("status", "NOT_SUBMITTED");
                            }

                            userStatuses.add(userStatus);
                        }

                        // 호실 전체 상태 결정
                        if (hasRejected) overallStatus = "REJECTED";
                        else if (hasFail) overallStatus = "FAIL";
                        else if (hasPending) overallStatus = "PENDING";
                        else if (submittedCount < roomUsers.size()) overallStatus = "NOT_SUBMITTED";
                        else if (hasPass && submittedCount == roomUsers.size()) overallStatus = "PASS";

                        roomStatus.put("status", overallStatus);
                        roomStatus.put("statusText", getStatusText(overallStatus));
                        roomStatus.put("userCount", roomUsers.size());
                        roomStatus.put("submittedCount", submittedCount);
                        roomStatus.put("users", userStatuses);
                    }

                    floorData.put(String.valueOf(room), roomStatus);
                }

                matrix.put(String.valueOf(floor), floorData);
            }

            // 통계 정보
            Map<String, Object> statistics = new HashMap<>();
            int totalRooms = 0;
            int passCount = 0;
            int failCount = 0;
            int rejectedCount = 0;
            int pendingCount = 0;
            int notSubmittedCount = 0;
            int emptyCount = 0;

            for (Map.Entry<String, Map<String, Object>> floorEntry : matrix.entrySet()) {
                for (Map.Entry<String, Object> roomEntry : floorEntry.getValue().entrySet()) {
                    @SuppressWarnings("unchecked")
                    Map<String, Object> roomData = (Map<String, Object>) roomEntry.getValue();
                    String status = (String) roomData.get("status");

                    totalRooms++;
                    switch (status) {
                        case "PASS": passCount++; break;
                        case "FAIL": failCount++; break;
                        case "REJECTED": rejectedCount++; break;
                        case "PENDING": pendingCount++; break;
                        case "NOT_SUBMITTED": notSubmittedCount++; break;
                        case "EMPTY": emptyCount++; break;
                    }
                }
            }

            statistics.put("totalRooms", totalRooms);
            statistics.put("occupiedRooms", totalRooms - emptyCount);
            statistics.put("passCount", passCount);
            statistics.put("failCount", failCount);
            statistics.put("rejectedCount", rejectedCount);
            statistics.put("pendingCount", pendingCount);
            statistics.put("notSubmittedCount", notSubmittedCount);
            statistics.put("emptyCount", emptyCount);

            // 결과 구성
            Map<String, Object> result = new HashMap<>();
            result.put("building", building);
            result.put("date", targetDate.toString());
            result.put("matrix", matrix);
            result.put("statistics", statistics);
            result.put("floors", floors);
            result.put("rooms", rooms);

            // ✅ 테이블 설정 정보 추가
            Map<String, Object> configInfo = new HashMap<>();
            configInfo.put("startFloor", startFloor);
            configInfo.put("endFloor", endFloor);
            configInfo.put("startRoom", startRoom);
            configInfo.put("endRoom", endRoom);
            configInfo.put("roomNumberFormat", roomNumberFormat);
            configInfo.put("configId", tableConfig.getId());
            configInfo.put("isDefault", isDefaultConfig);  // ✅ 기본값 여부
            if (isDefaultConfig) {
                configInfo.put("message", "⚠️ 예시 테이블입니다. 설정 버튼을 눌러 실제 층/호실 범위를 설정해주세요.");
            }
            result.put("tableConfig", configInfo);

            logger.info("기숙사별 점호 현황 조회 완료 - 동: {}, 통과: {}, 실패: {}, 미제출: {}",
                    building, passCount, failCount, notSubmittedCount);

            return result;

        } catch (Exception e) {
            logger.error("기숙사별 점호 현황 조회 실패 - 동: {}", building, e);
            throw new RuntimeException("기숙사별 점호 현황 조회 중 오류가 발생했습니다: " + e.getMessage());
        }
    }

    /**
     * 전체 기숙사 동 목록 조회
     * ✅ 사용자 데이터 + 테이블 설정 모두에서 기숙사 목록을 가져옴
     */
    @Transactional(readOnly = true)
    public List<String> getAllBuildings() {
        try {
            logger.info("전체 기숙사 동 목록 조회");

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

            logger.info("기숙사 동 목록 조회 완료 - {}개 동 (사용자: {}, 설정: {})",
                    result.size(),
                    userBuildings != null ? userBuildings.size() : 0,
                    configBuildings.size());

            return result;
        } catch (Exception e) {
            logger.error("기숙사 동 목록 조회 실패", e);
            throw new RuntimeException("기숙사 동 목록 조회 중 오류가 발생했습니다: " + e.getMessage());
        }
    }

    /**
     * 특정 호실의 점호 상세 정보 조회
     */
    @Transactional(readOnly = true)
    public Map<String, Object> getRoomInspectionDetail(String building, String roomNumber, String dateStr) {
        try {
            logger.info("호실 점호 상세 조회 - 동: {}, 호실: {}, 날짜: {}", building, roomNumber, dateStr);

            LocalDate targetDate;
            if (dateStr == null || dateStr.isEmpty()) {
                targetDate = LocalDate.now();
            } else {
                targetDate = LocalDate.parse(dateStr);
            }

            LocalDateTime startOfDay = targetDate.atStartOfDay();
            LocalDateTime endOfDay = targetDate.atTime(23, 59, 59);

            // 해당 호실의 사용자들 조회
            List<User> roomUsers = userRepository.findByDormitoryBuildingAndRoomNumberAndIsActiveTrue(building, roomNumber);

            Map<String, Object> result = new HashMap<>();
            result.put("building", building);
            result.put("roomNumber", roomNumber);
            result.put("date", targetDate.toString());
            result.put("userCount", roomUsers.size());

            if (roomUsers.isEmpty()) {
                result.put("overallStatus", "EMPTY");
                result.put("statusText", "빈 방");
                result.put("users", List.of());
                return result;
            }

            List<Map<String, Object>> userDetails = new ArrayList<>();

            for (User user : roomUsers) {
                Map<String, Object> userDetail = new HashMap<>();
                userDetail.put("userId", user.getId());
                userDetail.put("userName", decryptUserName(user.getName()));

                // 해당 날짜의 점호 기록 조회
                List<Inspection> inspections = inspectionRepository.findByUserIdAndInspectionDateBetween(
                        user.getId(), startOfDay, endOfDay);

                if (inspections.isEmpty()) {
                    userDetail.put("inspectionStatus", "NOT_SUBMITTED");
                    userDetail.put("statusText", "미제출");
                    userDetail.put("inspection", null);
                } else {
                    Inspection inspection = inspections.get(0);
                    userDetail.put("inspectionStatus", inspection.getStatus());
                    userDetail.put("statusText", getStatusText(inspection.getStatus()));

                    Map<String, Object> inspectionData = new HashMap<>();
                    inspectionData.put("id", inspection.getId());
                    inspectionData.put("score", inspection.getScore());
                    inspectionData.put("status", inspection.getStatus());
                    inspectionData.put("geminiFeedback", inspection.getGeminiFeedback());
                    inspectionData.put("adminComment", inspection.getAdminComment());
                    inspectionData.put("imagePath", inspection.getImagePath());
                    inspectionData.put("inspectionDate", inspection.getInspectionDate());

                    userDetail.put("inspection", inspectionData);
                }

                userDetails.add(userDetail);
            }

            // 전체 상태 결정
            String overallStatus = determineOverallStatus(userDetails);
            result.put("overallStatus", overallStatus);
            result.put("statusText", getStatusText(overallStatus));
            result.put("users", userDetails);

            return result;

        } catch (Exception e) {
            logger.error("호실 점호 상세 조회 실패", e);
            throw new RuntimeException("호실 점호 상세 조회 중 오류가 발생했습니다: " + e.getMessage());
        }
    }

    // ==================== 헬퍼 메서드 ====================

    /**
     * 상태 코드를 텍스트로 변환
     */
    private String getStatusText(String status) {
        switch (status) {
            case "PASS": return "통과";
            case "FAIL": return "실패";
            case "REJECTED": return "반려";
            case "PENDING": return "검토중";
            case "NOT_SUBMITTED": return "미제출";
            case "EMPTY": return "빈 방";
            default: return status;
        }
    }

    /**
     * 암호화된 사용자 이름 복호화
     */
    private String decryptUserName(String encryptedName) {
        if (encryptedName == null) return "Unknown";
        try {
            return encryptionUtil.decrypt(encryptedName);
        } catch (Exception e) {
            logger.warn("사용자 이름 복호화 실패: {}", e.getMessage());
            return encryptedName;
        }
    }

    /**
     * 호실 전체 상태 결정
     */
    private String determineOverallStatus(List<Map<String, Object>> userDetails) {
        boolean hasPass = false;
        boolean hasFail = false;
        boolean hasRejected = false;
        boolean hasPending = false;
        boolean hasNotSubmitted = false;

        for (Map<String, Object> user : userDetails) {
            String status = (String) user.get("inspectionStatus");
            switch (status) {
                case "PASS": hasPass = true; break;
                case "FAIL": hasFail = true; break;
                case "REJECTED": hasRejected = true; break;
                case "PENDING": hasPending = true; break;
                case "NOT_SUBMITTED": hasNotSubmitted = true; break;
            }
        }

        if (hasRejected) return "REJECTED";
        if (hasFail) return "FAIL";
        if (hasPending) return "PENDING";
        if (hasNotSubmitted) return "NOT_SUBMITTED";
        if (hasPass) return "PASS";
        return "EMPTY";
    }

    // ==================== 변환 메서드 ====================

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
        response.setUpdatedAt(inspection.getUpdatedAt());
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

        // 사용자 이름 조회 및 복호화
        try {
            Optional<User> user = userRepository.findById(inspection.getUserId());
            if (user.isPresent()) {
                User u = user.get();
                if (u.getName() != null) {
                    response.setUserName(decryptUserName(u.getName()));
                } else {
                    response.setUserName(u.getId());
                }
                response.setDormitoryBuilding(u.getDormitoryBuilding());
            } else {
                response.setUserName(inspection.getUserId());
            }
        } catch (Exception e) {
            logger.warn("사용자 정보 조회 실패 - 사용자ID: {}", inspection.getUserId());
            response.setUserName(inspection.getUserId());
        }

        return response;
    }
}