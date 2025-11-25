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

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

/**
 * 점호 관련 비즈니스 로직을 처리하는 서비스 - 거주 정보 자동 기입 추가
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

    @Value("${inspection.pass.score:6}")
    private int passScore;

    @Value("${inspection.fail.score:5}")
    private int failScore;

    /**
     * 점호 제출 - 거주 정보 자동 기입
     *
     * @param userId 사용자 ID
     * @param roomNumber 방 번호 (옵션, null이면 사용자 정보에서 가져옴)
     * @param imageFile 업로드된 방 사진
     * @return 점호 제출 결과
     */
    public InspectionRequest.Response submitInspection(String userId, String roomNumber, MultipartFile imageFile) {
        try {
            logger.info("점호 제출 시작 - 사용자: {}, 방번호: {}", userId, roomNumber);

            // ✅ 사용자 정보 조회하여 거주 정보 가져오기
            User user = userRepository.findById(userId)
                    .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다: " + userId));

            // ✅ roomNumber가 null이면 사용자 정보에서 가져오기
            String finalRoomNumber = roomNumber;
            String dormitoryBuilding = user.getDormitoryBuilding();

            if (finalRoomNumber == null || finalRoomNumber.trim().isEmpty()) {
                finalRoomNumber = user.getRoomNumber();
                if (finalRoomNumber == null || finalRoomNumber.trim().isEmpty()) {
                    throw new RuntimeException("방 번호 정보가 없습니다. 마이페이지에서 거주 정보를 등록해주세요.");
                }
                logger.info("사용자 정보에서 방 번호 자동 기입: {}", finalRoomNumber);
            }

            if (dormitoryBuilding == null || dormitoryBuilding.trim().isEmpty()) {
                logger.warn("거주 동 정보가 없습니다 - 사용자: {}", userId);
            }

            // 오늘 이미 점호했는지 확인
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

            // Inspection 엔티티 생성
            Inspection inspection = new Inspection();
            inspection.setUserId(userId);
            inspection.setRoomNumber(finalRoomNumber);
            inspection.setImagePath(imagePath);
            inspection.setScore(score);
            inspection.setStatus(status);
            inspection.setGeminiFeedback(geminiFeedback);
            inspection.setInspectionDate(LocalDateTime.now());
            inspection.setIsReInspection(false);

            Inspection savedInspection = inspectionRepository.save(inspection);
            logger.info("점호 제출 완료 - ID: {}, 거주 동: {}, 방 번호: {}, 점수: {}, 상태: {}",
                    savedInspection.getId(), dormitoryBuilding, finalRoomNumber, score, status);

            // 출석 테이블 업데이트
            try {
                LocalDate today = LocalDate.now();
                attendanceTableService.updateAttendanceOnInspectionSubmit(
                        userId,
                        today,
                        score,
                        status
                );
                logger.info("출석 테이블 업데이트 완료 - 사용자: {}", userId);
            } catch (Exception e) {
                logger.warn("출석 테이블 업데이트 실패 (무시): {}", e.getMessage());
            }

            return convertToResponse(savedInspection);

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

            // ✅ 사용자 정보 조회
            User user = userRepository.findById(userId)
                    .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다: " + userId));

            // ✅ roomNumber가 null이면 사용자 정보에서 가져오기
            String finalRoomNumber = roomNumber;
            if (finalRoomNumber == null || finalRoomNumber.trim().isEmpty()) {
                finalRoomNumber = user.getRoomNumber();
                if (finalRoomNumber == null || finalRoomNumber.trim().isEmpty()) {
                    throw new RuntimeException("방 번호 정보가 없습니다.");
                }
            }

            // 오늘 재검 대상인지 확인
            List<Inspection> todayInspections = inspectionRepository.findTodayInspectionByUserId(userId);
            if (todayInspections.isEmpty()) {
                throw new RuntimeException("오늘 점호 기록이 없습니다.");
            }

            Inspection lastInspection = todayInspections.get(0);
            if (!"FAIL".equals(lastInspection.getStatus())) {
                throw new RuntimeException("재검 대상이 아닙니다.");
            }

            // 파일 업로드
            String imagePath = fileService.uploadImage(imageFile, "inspection");
            logger.info("재검 이미지 업로드 완료: {}", imagePath);

            // Gemini AI를 통한 점호 평가
            int score = geminiService.evaluateInspection(imageFile);
            String geminiFeedback = geminiService.getInspectionFeedback(imageFile);
            String status = score >= passScore ? "PASS" : "FAIL";

            logger.info("재검 AI 평가 완료 - 점수: {}, 상태: {}", score, status);

            // 재검 Inspection 엔티티 생성
            Inspection reInspection = new Inspection();
            reInspection.setUserId(userId);
            reInspection.setRoomNumber(finalRoomNumber);
            reInspection.setImagePath(imagePath);
            reInspection.setScore(score);
            reInspection.setStatus(status);
            reInspection.setGeminiFeedback(geminiFeedback);
            reInspection.setInspectionDate(LocalDateTime.now());
            reInspection.setIsReInspection(true);

            Inspection savedReInspection = inspectionRepository.save(reInspection);
            logger.info("재검 점호 제출 완료 - ID: {}, 점수: {}, 상태: {}",
                    savedReInspection.getId(), score, status);

            // 출석 테이블 업데이트
            try {
                LocalDate today = LocalDate.now();
                attendanceTableService.updateAttendanceOnInspectionSubmit(
                        userId,
                        today,
                        score,
                        status
                );
                logger.info("재검 출석 테이블 업데이트 완료 - 사용자: {}", userId);
            } catch (Exception e) {
                logger.warn("재검 출석 테이블 업데이트 실패 (무시): {}", e.getMessage());
            }

            return convertToResponse(savedReInspection);

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
     * 오늘 점호 상태 확인
     */
    @Transactional(readOnly = true)
    public Map<String, Object> getTodayInspectionStatus(String userId) {
        try {
            List<Inspection> todayInspections = inspectionRepository.findTodayInspectionByUserId(userId);

            if (todayInspections.isEmpty()) {
                return Map.of(
                        "submitted", false,
                        "message", "오늘 점호를 아직 제출하지 않았습니다."
                );
            }

            Inspection latestInspection = todayInspections.get(0);
            boolean needsReInspection = "FAIL".equals(latestInspection.getStatus())
                    && !latestInspection.getIsReInspection();

            return Map.of(
                    "submitted", true,
                    "inspection", convertToResponse(latestInspection),
                    "needsReInspection", needsReInspection,
                    "message", needsReInspection ? "재검이 필요합니다." : "점호 완료"
            );

        } catch (Exception e) {
            logger.error("오늘 점호 상태 확인 실패 - 사용자: {}", userId, e);
            throw new RuntimeException("점호 상태 확인 중 오류가 발생했습니다: " + e.getMessage());
        }
    }

    /**
     * 모든 점호 기록 조회 (관리자용)
     */
    @Transactional(readOnly = true)
    public List<InspectionRequest.AdminResponse> getAllInspections() {
        try {
            logger.info("전체 점호 기록 조회 시작");

            List<Inspection> inspections = inspectionRepository.findAllOrderByCreatedAtDesc();
            List<InspectionRequest.AdminResponse> responses = inspections.stream()
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
     * 특정 날짜의 점호 기록 조회 (관리자용)
     */
    @Transactional(readOnly = true)
    public List<InspectionRequest.AdminResponse> getInspectionsByDate(LocalDate date) {
        try {
            logger.info("특정 날짜 점호 기록 조회 - 날짜: {}", date);

            List<Inspection> inspections = inspectionRepository.findByInspectionDate(date);
            List<InspectionRequest.AdminResponse> responses = inspections.stream()
                    .map(this::convertToAdminResponse)
                    .collect(Collectors.toList());

            logger.info("특정 날짜 점호 기록 조회 완료 - 날짜: {}, 기록 수: {}", date, responses.size());
            return responses;

        } catch (Exception e) {
            logger.error("특정 날짜 점호 기록 조회 실패 - 날짜: {}", date, e);
            throw new RuntimeException("점호 기록 조회 중 오류가 발생했습니다: " + e.getMessage());
        }
    }

    /**
     * 점호 삭제 (관리자용)
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

    /**
     * Inspection → Response 변환
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
     * Inspection → AdminResponse 변환
     */
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

        // 사용자 정보 추가
        Optional<User> userOptional = userRepository.findById(inspection.getUserId());
        userOptional.ifPresent(user -> {
            response.setUserName(user.getName());
            response.setDormitoryBuilding(user.getDormitoryBuilding());
        });

        return response;
    }
}