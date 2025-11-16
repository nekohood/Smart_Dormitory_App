package com.dormitory.SpringBoot.services;

import com.dormitory.SpringBoot.domain.Inspection;
import com.dormitory.SpringBoot.dto.InspectionRequest;
import com.dormitory.SpringBoot.repository.InspectionRepository;
import com.dormitory.SpringBoot.repository.UserRepository;
import com.dormitory.SpringBoot.domain.User;
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
import java.util.Optional;
import java.util.stream.Collectors;
import java.util.Map;

/**
 * 점호 관련 비즈니스 로직을 처리하는 서비스
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

    @Value("${inspection.pass.score:6}")
    private int passScore;

    @Value("${inspection.fail.score:5}")
    private int failScore;

    /**
     * 점호 제출
     *
     * @param userId 사용자 ID
     * @param roomNumber 방 번호
     * @param imageFile 업로드된 방 사진
     * @return 점호 제출 결과
     */
    public InspectionRequest.Response submitInspection(String userId, String roomNumber, MultipartFile imageFile) {
        try {
            logger.info("점호 제출 시작 - 사용자: {}, 방번호: {}", userId, roomNumber);

            // 오늘 이미 점호했는지 확인 (수정된 부분)
            List<Inspection> todayInspections = inspectionRepository.findTodayInspectionByUserId(userId);
            if (!todayInspections.isEmpty()) {
                throw new RuntimeException("오늘 이미 점호를 완료했습니다.");
            }

            // 파일 업로드
            String imagePath = fileService.uploadImage(imageFile, "inspection");
            logger.info("이미지 업로드 완료: {}", imagePath);

            // Gemini AI를 통한 점호 평가
            int score = geminiService.evaluateInspection(imageFile);
            String geminiFeedback = geminiService.getInspectionFeedback(imageFile);
            String status = score >= passScore ? "PASS" : "FAIL";

            logger.info("AI 평가 완료 - 점수: {}, 상태: {}", score, status);

            // 점호 기록 생성 및 저장
            Inspection inspection = new Inspection();
            inspection.setUserId(userId);
            inspection.setRoomNumber(roomNumber);
            inspection.setImagePath(imagePath);
            inspection.setScore(score);
            inspection.setStatus(status);
            inspection.setGeminiFeedback(geminiFeedback);
            inspection.setInspectionDate(LocalDateTime.now());
            inspection.setCreatedAt(LocalDateTime.now());
            inspection.setIsReInspection(false);

            inspection = inspectionRepository.save(inspection);
            logger.info("점호 기록 저장 완료 - ID: {}", inspection.getId());

            return convertToResponse(inspection);

        } catch (Exception e) {
            logger.error("점호 제출 중 오류 발생", e);
            throw new RuntimeException("점호 제출에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 사용자의 점호 기록 조회
     *
     * @param userId 사용자 ID
     * @return 사용자의 점호 기록 목록
     */
    @Transactional(readOnly = true)
    public List<InspectionRequest.AdminResponse> getUserInspections(String userId) {
        try {
            logger.info("사용자 점호 기록 조회 시작 - 사용자: {}", userId);

            List<Inspection> inspections = inspectionRepository.findByUserIdOrderByCreatedAtDesc(userId);
            List<InspectionRequest.AdminResponse> result = inspections.stream()
                    .map(this::convertToAdminResponse)
                    .collect(Collectors.toList());

            logger.info("사용자 점호 기록 조회 완료 - 총 {}건", result.size());
            return result;

        } catch (Exception e) {
            logger.error("사용자 점호 기록 조회 중 오류 발생", e);
            throw new RuntimeException("점호 기록 조회에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 오늘 점호 조회
     *
     * @param userId 사용자 ID
     * @return 오늘의 점호 기록 (있을 경우)
     */
    @Transactional(readOnly = true)
    public Optional<InspectionRequest.Response> getTodayInspection(String userId) {
        try {
            logger.info("오늘 점호 조회 시작 - 사용자: {}", userId);

            // 수정된 부분: List로 받은 후 첫 번째 항목만 사용
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
     * 전체 점호 기록 조회 (관리자용)
     *
     * @return 모든 점호 기록 목록
     */
    @Transactional(readOnly = true)
    public List<InspectionRequest.AdminResponse> getAllInspections() {
        try {
            logger.info("전체 점호 기록 조회 시작");

            List<Inspection> inspections = inspectionRepository.findAll();
            List<InspectionRequest.AdminResponse> result = inspections.stream()
                    .map(this::convertToAdminResponse)
                    .collect(Collectors.toList());

            logger.info("전체 점호 기록 조회 완료 - 총 {}건", result.size());
            return result;

        } catch (Exception e) {
            logger.error("전체 점호 기록 조회 중 오류 발생", e);
            throw new RuntimeException("점호 기록 조회에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 날짜별 점호 기록 조회 (관리자용)
     *
     * @param dateStr 조회할 날짜 (yyyy-MM-dd 형식)
     * @return 해당 날짜의 점호 기록 목록
     */
    @Transactional(readOnly = true)
    public List<InspectionRequest.AdminResponse> getInspectionsByDate(String dateStr) {
        try {
            logger.info("날짜별 점호 기록 조회 시작 - 날짜: {}", dateStr);

            LocalDateTime date = LocalDateTime.parse(dateStr + " 00:00:00",
                    DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));

            List<Inspection> inspections = inspectionRepository.findByInspectionDate(date);
            List<InspectionRequest.AdminResponse> result = inspections.stream()
                    .map(this::convertToAdminResponse)
                    .collect(Collectors.toList());

            logger.info("날짜별 점호 기록 조회 완료 - 날짜: {}, 총 {}건", dateStr, result.size());
            return result;

        } catch (Exception e) {
            logger.error("날짜별 점호 기록 조회 중 오류 발생 - 날짜: {}", dateStr, e);
            throw new RuntimeException("점호 기록 조회에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 특정 날짜 통계 조회
     *
     * @param dateStr 조회할 날짜 (yyyy-MM-dd 형식)
     * @return 해당 날짜의 점호 통계
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

            InspectionRequest.Statistics result = new InspectionRequest.Statistics(total, passed, failed, reInspections, date);

            logger.info("날짜별 통계 조회 완료 - 날짜: {}, 전체: {}, 통과: {}, 실패: {}",
                    dateStr, total, passed, failed);
            return result;

        } catch (Exception e) {
            logger.error("날짜별 통계 조회 중 오류 발생 - 날짜: {}", dateStr, e);
            throw new RuntimeException("통계 조회에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 전체 통계 조회
     *
     * @return 전체 점호 통계
     */
    @Transactional(readOnly = true)
    public InspectionRequest.Statistics getTotalStatistics() {
        try {
            logger.info("전체 통계 조회 시작");

            long total = inspectionRepository.count();
            long passed = inspectionRepository.findByStatusOrderByCreatedAtDesc("PASS").size();
            long failed = inspectionRepository.findByStatusOrderByCreatedAtDesc("FAIL").size();
            long reInspections = inspectionRepository.findByIsReInspectionTrueOrderByCreatedAtDesc().size();

            InspectionRequest.Statistics result = new InspectionRequest.Statistics(total, passed, failed, reInspections, LocalDateTime.now());

            logger.info("전체 통계 조회 완료 - 전체: {}, 통과: {}, 실패: {}, 재검: {}",
                    total, passed, failed, reInspections);
            return result;

        } catch (Exception e) {
            logger.error("전체 통계 조회 중 오류 발생", e);
            throw new RuntimeException("통계 조회에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 점호 기록 삭제 (관리자용)
     *
     * @param inspectionId 삭제할 점호 기록 ID
     * @return 삭제 성공 여부
     */
    public boolean deleteInspection(Long inspectionId) {
        try {
            logger.info("점호 기록 삭제 시작 - ID: {}", inspectionId);

            Optional<Inspection> inspectionOptional = inspectionRepository.findById(inspectionId);
            if (inspectionOptional.isPresent()) {
                Inspection inspection = inspectionOptional.get();
                String imagePath = inspection.getImagePath();

                // 1. DB에서 점호 기록을 먼저 삭제합니다.
                inspectionRepository.deleteById(inspectionId);
                logger.info("점호 기록 DB 삭제 완료 - ID: {}", inspectionId);

                // 2. 그 후에 관련된 이미지 파일을 삭제합니다.
                // 파일 삭제가 실패하더라도 DB 기록은 이미 삭제되었으므로 문제가 발생하지 않습니다.
                if (imagePath != null && !imagePath.isEmpty()) {
                    boolean fileDeleted = fileService.deleteFile(imagePath);
                    if (fileDeleted) {
                        logger.info("관련 이미지 파일 삭제 성공 - 경로: {}", imagePath);
                    } else {
                        logger.warn("관련 이미지 파일 삭제 실패 - 경로: {}. DB 기록은 정상 삭제되었습니다.", imagePath);
                    }
                }

                return true;
            } else {
                logger.warn("삭제할 점호 기록을 찾을 수 없습니다 - ID: {}", inspectionId);
                return false;
            }

        } catch (Exception e) {
            logger.error("점호 기록 삭제 중 오류 발생 - ID: {}", inspectionId, e);
            throw new RuntimeException("점호 기록 삭제에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 점호 기록 수정 (관리자용) - 수정된 메서드
     *
     * @param inspectionId 수정할 점호 기록 ID
     * @param updateData 수정할 데이터
     * @return 수정된 점호 기록
     */
    public InspectionRequest.AdminResponse updateInspection(Long inspectionId, Map<String, Object> updateData) {
        try {
            logger.info("점호 기록 수정 시작 - ID: {}", inspectionId);

            Optional<Inspection> optionalInspection = inspectionRepository.findById(inspectionId);
            if (!optionalInspection.isPresent()) {
                throw new RuntimeException("점호 기록을 찾을 수 없습니다. ID: " + inspectionId);
            }

            Inspection inspection = optionalInspection.get();
            boolean updated = false;

            // 수정 가능한 필드들 업데이트
            if (updateData.containsKey("score")) {
                Integer newScore = (Integer) updateData.get("score");
                inspection.setScore(newScore);
                // 점수 변경 시 상태도 업데이트
                String newStatus = newScore >= passScore ? "PASS" : "FAIL";
                inspection.setStatus(newStatus);
                logger.info("점수 및 상태 업데이트 - 점수: {}, 상태: {}", newScore, newStatus);
                updated = true;
            }

            if (updateData.containsKey("status")) {
                String newStatus = (String) updateData.get("status");
                inspection.setStatus(newStatus);
                logger.info("상태 업데이트: {}", newStatus);
                updated = true;
            }

            if (updateData.containsKey("geminiFeedback")) {
                String newFeedback = (String) updateData.get("geminiFeedback");
                inspection.setGeminiFeedback(newFeedback);
                logger.info("AI 피드백 업데이트");
                updated = true;
            }

            if (updateData.containsKey("adminComment")) {
                String newComment = (String) updateData.get("adminComment");
                inspection.setAdminComment(newComment);
                logger.info("관리자 코멘트 업데이트");
                updated = true;
            }

            // ✅ 수정된 부분: isReInspection 필드 업데이트
            if (updateData.containsKey("isReInspection")) {
                Boolean newIsReInspection = (Boolean) updateData.get("isReInspection");
                inspection.setIsReInspection(newIsReInspection);
                logger.info("재검 여부 업데이트: {}", newIsReInspection);
                updated = true;
            }

            if (updated) {
                inspection = inspectionRepository.save(inspection);
                logger.info("점호 기록 수정 완료 - ID: {}", inspectionId);
            } else {
                logger.info("수정할 데이터가 없습니다 - ID: {}", inspectionId);
            }

            return convertToAdminResponse(inspection);

        } catch (Exception e) {
            logger.error("점호 기록 수정 중 오류 발생 - ID: {}", inspectionId, e);
            throw new RuntimeException("점호 기록 수정에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 재검 점호 처리
     *
     * @param userId 사용자 ID
     * @param roomNumber 방 번호
     * @param imageFile 재검 사진
     * @return 재검 점호 결과
     */
    public InspectionRequest.Response submitReInspection(String userId, String roomNumber, MultipartFile imageFile) {
        try {
            logger.info("재검 점호 제출 시작 - 사용자: {}, 방번호: {}", userId, roomNumber);

            // 파일 업로드
            String imagePath = fileService.uploadImage(imageFile, "reinspection");

            // Gemini AI를 통한 재검 평가
            int score = geminiService.evaluateInspection(imageFile);
            String geminiFeedback = geminiService.getInspectionFeedback(imageFile);
            String status = score >= passScore ? "PASS" : "FAIL";

            // 재검 점호 기록 생성
            Inspection inspection = new Inspection();
            inspection.setUserId(userId);
            inspection.setRoomNumber(roomNumber);
            inspection.setImagePath(imagePath);
            inspection.setScore(score);
            inspection.setStatus(status);
            inspection.setGeminiFeedback(geminiFeedback);
            inspection.setInspectionDate(LocalDateTime.now());
            inspection.setCreatedAt(LocalDateTime.now());
            inspection.setIsReInspection(true); // 재검 여부 설정

            inspection = inspectionRepository.save(inspection);
            logger.info("재검 점호 기록 저장 완료 - ID: {}", inspection.getId());

            return convertToResponse(inspection);

        } catch (Exception e) {
            logger.error("재검 점호 제출 중 오류 발생", e);
            throw new RuntimeException("재검 점호 제출에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 사용자별 점호 통계 조회
     *
     * @param userId 사용자 ID
     * @return 사용자의 점호 통계
     */
    @Transactional(readOnly = true)
    public InspectionRequest.Statistics getUserStatistics(String userId) {
        try {
            logger.info("사용자별 통계 조회 시작 - 사용자: {}", userId);

            List<Inspection> userInspections = inspectionRepository.findByUserIdOrderByCreatedAtDesc(userId);

            long total = userInspections.size();
            long passed = userInspections.stream()
                    .mapToLong(i -> "PASS".equals(i.getStatus()) ? 1 : 0)
                    .sum();
            long failed = userInspections.stream()
                    .mapToLong(i -> "FAIL".equals(i.getStatus()) ? 1 : 0)
                    .sum();
            long reInspections = userInspections.stream()
                    .mapToLong(i -> Boolean.TRUE.equals(i.getIsReInspection()) ? 1 : 0)
                    .sum();

            InspectionRequest.Statistics result = new InspectionRequest.Statistics(total, passed, failed, reInspections, LocalDateTime.now());

            logger.info("사용자별 통계 조회 완료 - 사용자: {}, 전체: {}, 통과: {}, 실패: {}",
                    userId, total, passed, failed);
            return result;

        } catch (Exception e) {
            logger.error("사용자별 통계 조회 중 오류 발생 - 사용자: {}", userId, e);
            throw new RuntimeException("사용자 통계 조회에 실패했습니다: " + e.getMessage());
        }
    }

    // ===== 내부 변환 메서드들 =====

    /**
     * Inspection을 Response DTO로 변환
     */
    private InspectionRequest.Response convertToResponse(Inspection inspection) {
        return new InspectionRequest.Response(
                inspection.getId(),
                inspection.getUserId(),
                inspection.getRoomNumber(),
                inspection.getImagePath(),
                inspection.getScore(),
                inspection.getStatus(),
                inspection.getGeminiFeedback(),
                inspection.getAdminComment(),
                inspection.getIsReInspection(),
                inspection.getInspectionDate(),
                inspection.getCreatedAt()
        );
    }

    /**
     * Inspection을 AdminResponse DTO로 변환 (사용자 이름 포함)
     */
    private InspectionRequest.AdminResponse convertToAdminResponse(Inspection inspection) {
        String userName = inspection.getUserId(); // 기본값으로 사용자 ID 사용

        try {
            Optional<User> user = userRepository.findById(inspection.getUserId());
            if (user.isPresent()) {
                // ✅ 수정된 부분: User 엔티티에 name 필드가 있다면 사용
                userName = user.get().getName() != null ? user.get().getName() : user.get().getId();
            }
        } catch (Exception e) {
            logger.warn("사용자 정보 조회 실패 - 사용자 ID: {}, 오류: {}", inspection.getUserId(), e.getMessage());
        }

        return new InspectionRequest.AdminResponse(
                inspection.getId(),
                inspection.getUserId(),
                userName,
                inspection.getRoomNumber(),
                inspection.getImagePath(),
                inspection.getScore(),
                inspection.getStatus(),
                inspection.getGeminiFeedback(),
                inspection.getAdminComment(),
                inspection.getIsReInspection(),
                inspection.getInspectionDate(),
                inspection.getCreatedAt()
        );
    }

    // ===== 유틸리티 메서드들 =====

    /**
     * 점호 통과율 계산
     */
    @Transactional(readOnly = true)
    public double calculatePassRate() {
        try {
            long total = inspectionRepository.count();
            if (total == 0) {
                return 0.0;
            }

            long passed = inspectionRepository.findByStatusOrderByCreatedAtDesc("PASS").size();
            return (double) passed / total * 100;

        } catch (Exception e) {
            logger.error("통과율 계산 중 오류 발생", e);
            return 0.0;
        }
    }

    /**
     * 특정 날짜의 점호 통과율 계산
     */
    @Transactional(readOnly = true)
    public double calculatePassRateByDate(String dateStr) {
        try {
            LocalDateTime date = LocalDateTime.parse(dateStr + " 00:00:00",
                    DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));

            long total = inspectionRepository.countTotalInspectionsByDate(date);
            if (total == 0) {
                return 0.0;
            }

            long passed = inspectionRepository.countPassedInspectionsByDate(date);
            return (double) passed / total * 100;

        } catch (Exception e) {
            logger.error("날짜별 통과율 계산 중 오류 발생 - 날짜: {}", dateStr, e);
            return 0.0;
        }
    }
}