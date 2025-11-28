package com.dormitory.SpringBoot.services;

import com.dormitory.SpringBoot.domain.Inspection;
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

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

/**
 * 점호 관련 비즈니스 로직 처리 서비스
 * ✅ 상세 조회 및 반려 기능 추가
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
    private FileService fileService;

    @Autowired
    private GeminiService geminiService;

    @Value("${inspection.pass.score:7}")
    private int passScore;

    /**
     * 점호 제출
     */
    public InspectionRequest.Response submitInspection(String userId, String roomNumber, MultipartFile imageFile) {
        try {
            logger.info("점호 제출 시작 - 사용자: {}, 방 번호: {}", userId, roomNumber);

            // 오늘 이미 점호를 완료했는지 확인
            List<Inspection> todayInspections = inspectionRepository.findTodayInspectionByUserId(userId);
            if (!todayInspections.isEmpty()) {
                throw new RuntimeException("오늘 이미 점호를 완료했습니다.");
            }

            // 사용자 정보 조회
            User user = userRepository.findById(userId)
                    .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다."));

            // 방 번호 검증 및 설정
            String finalRoomNumber = roomNumber;
            if (user.getRoomNumber() != null && !user.getRoomNumber().isEmpty()) {
                finalRoomNumber = user.getRoomNumber();
            }

            // AI 평가
            int score = geminiService.evaluateInspection(imageFile);
            String geminiFeedback = geminiService.getInspectionFeedback(imageFile);
            String status = score >= passScore ? "PASS" : "FAIL";

            logger.info("AI 평가 완료 - 점수: {}, 상태: {}", score, status);

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
            logger.info("재검 점호 제출 시작 - 사용자: {}, 방 번호: {}", userId, roomNumber);

            User user = userRepository.findById(userId)
                    .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다."));

            String finalRoomNumber = roomNumber;
            if (user.getRoomNumber() != null && !user.getRoomNumber().isEmpty()) {
                finalRoomNumber = user.getRoomNumber();
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
     * ✅ 신규 추가: 특정 점호 기록 상세 조회 (관리자용)
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
     * ✅ 신규 추가: 점호 반려 (반려 사유와 함께 삭제)
     */
    public void rejectInspection(Long inspectionId, String rejectReason) {
        try {
            logger.info("점호 반려 시작 - ID: {}, 사유: {}", inspectionId, rejectReason);

            Inspection inspection = inspectionRepository.findById(inspectionId)
                    .orElseThrow(() -> new RuntimeException("점호 기록을 찾을 수 없습니다: " + inspectionId));

            String userId = inspection.getUserId();

            // TODO: 추후 알림 서비스 연동 시 사용자에게 반려 알림 전송
            // notificationService.sendRejectionNotification(userId, rejectReason);
            logger.info("점호 반려 알림 예정 - 사용자: {}, 사유: {}", userId, rejectReason);

            // 이미지 파일 삭제
            if (inspection.getImagePath() != null) {
                try {
                    fileService.deleteFile(inspection.getImagePath());
                    logger.info("점호 이미지 삭제 완료 - 경로: {}", inspection.getImagePath());
                } catch (Exception e) {
                    logger.warn("이미지 파일 삭제 실패: {}", e.getMessage());
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
                    total, passed, failed, reInspections, LocalDateTime.now()
            );

            logger.info("전체 통계 조회 완료 - 전체: {}, 통과: {}, 실패: {}, 재검: {}",
                    total, passed, failed, reInspections);
            return result;

        } catch (Exception e) {
            logger.error("전체 통계 조회 중 오류 발생", e);
            throw new RuntimeException("전체 통계 조회에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 날짜별 통계 조회
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
                    total, passed, failed, reInspections, date
            );

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

        // 사용자 이름 조회
        try {
            Optional<User> user = userRepository.findById(inspection.getUserId());
            if (user.isPresent()) {
                response.setUserName(user.get().getName());
                response.setDormitoryBuilding(user.get().getDormitoryBuilding());
            } else {
                response.setUserName("알 수 없음");
            }
        } catch (Exception e) {
            logger.warn("사용자 정보 조회 실패 - 사용자ID: {}", inspection.getUserId());
            response.setUserName("알 수 없음");
        }

        return response;
    }
}