package com.dormitory.SpringBoot.services;

import com.dormitory.SpringBoot.domain.Complaint;
import com.dormitory.SpringBoot.domain.User;
import com.dormitory.SpringBoot.repository.ComplaintRepository;
import com.dormitory.SpringBoot.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 민원 관련 비즈니스 로직을 처리하는 서비스 - 완전한 버전 (모든 메서드 포함)
 */
@Service
@Transactional
public class ComplaintService {

    private static final Logger logger = LoggerFactory.getLogger(ComplaintService.class);

    @Autowired
    private ComplaintRepository complaintRepository;

    @Autowired
    private UserRepository userRepository; // ✅ 사용자 정보 조회를 위해 추가

    @Autowired
    private FileService fileService;

    // =============================================================================
    // 기본 CRUD 메서드들
    // =============================================================================

    /**
     * 모든 민원 조회 (관리자용)
     */
    @Transactional(readOnly = true)
    public List<Complaint> getAllComplaints() {
        try {
            logger.info("모든 민원 조회");
            return complaintRepository.findAllByOrderBySubmittedAtDesc();
        } catch (Exception e) {
            logger.error("모든 민원 조회 실패", e);
            throw new RuntimeException("민원 목록 조회에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 사용자별 민원 조회
     */
    @Transactional(readOnly = true)
    public List<Complaint> getUserComplaints(String userId) {
        try {
            logger.info("사용자별 민원 조회 - 사용자ID: {}", userId);
            return complaintRepository.findByWriterIdOrderBySubmittedAtDesc(userId);
        } catch (Exception e) {
            logger.error("사용자별 민원 조회 실패", e);
            throw new RuntimeException("사용자 민원 조회에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 특정 민원 조회
     */
    @Transactional(readOnly = true)
    public Complaint getComplaintById(Long complaintId) {
        try {
            logger.info("민원 상세 조회 - ID: {}", complaintId);
            return complaintRepository.findById(complaintId)
                    .orElseThrow(() -> new RuntimeException("민원을 찾을 수 없습니다: " + complaintId));
        } catch (Exception e) {
            logger.error("민원 상세 조회 실패", e);
            throw new RuntimeException("민원 조회에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 민원 신고 제출 - ✅ 거주 정보 자동 기입 기능 추가
     */
    @Transactional
    public Complaint submitComplaint(String title, String content, String category,
                                     String writerId, String writerName, MultipartFile imageFile) {
        try {
            logger.info("민원 제출 - 작성자: {}, 제목: {}", writerId, title);

            // ✅ 사용자 정보 조회 (거주 동/방 번호 자동 기입)
            User user = userRepository.findById(writerId)
                    .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다: " + writerId));

            // 민원 객체 생성
            Complaint complaint = new Complaint();
            complaint.setTitle(title);
            complaint.setContent(content);
            complaint.setCategory(category);
            complaint.setWriterId(writerId);
            complaint.setWriterName(writerName);
            complaint.setStatus("대기");
            complaint.setSubmittedAt(LocalDateTime.now());
            complaint.setUpdatedAt(LocalDateTime.now());

            // ✅ 사용자의 거주 동/방 번호 자동 기입
            complaint.setDormitoryBuilding(user.getDormitoryBuilding());
            complaint.setRoomNumber(user.getRoomNumber());

            logger.info("민원 제출 - 거주 동: {}, 방 번호: {}",
                    user.getDormitoryBuilding(), user.getRoomNumber());

            // 이미지 파일 업로드 (선택사항)
            if (imageFile != null && !imageFile.isEmpty()) {
                try {
                    String imagePath = fileService.uploadImage(imageFile, "complaint");
                    complaint.setImagePath(imagePath);
                    logger.info("민원 이미지 업로드 완료: {}", imagePath);
                } catch (Exception e) {
                    logger.warn("민원 이미지 업로드 실패: {}", e.getMessage());
                    // 이미지 업로드 실패해도 민원 제출은 계속 진행
                }
            }

            complaint = complaintRepository.save(complaint);
            logger.info("민원 제출 완료 - ID: {}", complaint.getId());

            return complaint;

        } catch (Exception e) {
            logger.error("민원 제출 실패", e);
            throw new RuntimeException("민원 제출에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 민원 상태 업데이트 (관리자용)
     */
    @Transactional
    public Complaint updateComplaintStatus(Long complaintId, String status, String adminComment) {
        try {
            logger.info("민원 상태 업데이트 - ID: {}, 상태: {}", complaintId, status);

            Complaint complaint = complaintRepository.findById(complaintId)
                    .orElseThrow(() -> new RuntimeException("민원을 찾을 수 없습니다. ID: " + complaintId));

            // 상태 업데이트
            complaint.setStatus(status);
            complaint.setAdminComment(adminComment);
            complaint.setUpdatedAt(LocalDateTime.now());

            // 완료 상태인 경우 처리 시간 설정
            if ("완료".equals(status) || "반려".equals(status)) {
                complaint.setProcessedAt(LocalDateTime.now());
            }

            complaint = complaintRepository.save(complaint);
            logger.info("민원 상태 업데이트 완료 - ID: {}", complaintId);

            return complaint;

        } catch (Exception e) {
            logger.error("민원 상태 업데이트 실패", e);
            throw new RuntimeException("민원 상태 업데이트에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 민원 삭제 (관리자용)
     */
    @Transactional
    public void deleteComplaint(Long complaintId) {
        try {
            logger.info("민원 삭제 - ID: {}", complaintId);

            Complaint complaint = complaintRepository.findById(complaintId)
                    .orElseThrow(() -> new RuntimeException("민원을 찾을 수 없습니다. ID: " + complaintId));

            // 첨부 파일 삭제
            if (complaint.getImagePath() != null && !complaint.getImagePath().isEmpty()) {
                try {
                    fileService.deleteFile(complaint.getImagePath());
                    logger.info("민원 첨부 파일 삭제 완료: {}", complaint.getImagePath());
                } catch (Exception e) {
                    logger.warn("민원 첨부 파일 삭제 실패: {}", e.getMessage());
                }
            }

            complaintRepository.delete(complaint);
            logger.info("민원 삭제 완료 - ID: {}", complaintId);

        } catch (Exception e) {
            logger.error("민원 삭제 실패", e);
            throw new RuntimeException("민원 삭제에 실패했습니다: " + e.getMessage());
        }
    }

    // =============================================================================
    // ✅ 컨트롤러에서 호출하는 추가 메서드들 (누락 방지)
    // =============================================================================

    /**
     * 상태별 민원 조회
     */
    @Transactional(readOnly = true)
    public List<Complaint> getComplaintsByStatus(String status) {
        try {
            logger.info("상태별 민원 조회 - 상태: {}", status);
            return complaintRepository.findByStatusOrderBySubmittedAtDesc(status);
        } catch (Exception e) {
            logger.error("상태별 민원 조회 실패", e);
            throw new RuntimeException("상태별 민원 조회에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 카테고리별 민원 조회
     */
    @Transactional(readOnly = true)
    public List<Complaint> getComplaintsByCategory(String category) {
        try {
            logger.info("카테고리별 민원 조회 - 카테고리: {}", category);
            return complaintRepository.findByCategoryOrderBySubmittedAtDesc(category);
        } catch (Exception e) {
            logger.error("카테고리별 민원 조회 실패", e);
            throw new RuntimeException("카테고리별 민원 조회에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 민원 검색
     */
    @Transactional(readOnly = true)
    public List<Complaint> searchComplaints(String keyword) {
        try {
            logger.info("민원 검색 - 키워드: {}", keyword);

            if (keyword == null || keyword.trim().isEmpty()) {
                return getAllComplaints();
            }

            return complaintRepository.searchByKeyword(keyword.trim());
        } catch (Exception e) {
            logger.error("민원 검색 실패", e);
            throw new RuntimeException("민원 검색에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 긴급 민원 조회 (3일 이상 대기)
     */
    @Transactional(readOnly = true)
    public List<Complaint> getUrgentComplaints() {
        try {
            logger.info("긴급 민원 조회 (3일 이상 대기)");

            LocalDateTime urgentDate = LocalDateTime.now().minusDays(3);
            return complaintRepository.findUrgentComplaints(urgentDate);
        } catch (Exception e) {
            logger.error("긴급 민원 조회 실패", e);
            throw new RuntimeException("긴급 민원 조회에 실패했습니다: " + e.getMessage());
        }
    }

    // =============================================================================
    // 통계 메서드들
    // =============================================================================

    /**
     * 민원 통계 조회
     */
    @Transactional(readOnly = true)
    public Map<String, Object> getComplaintStatistics() {
        try {
            logger.info("민원 통계 조회");

            Map<String, Object> statistics = new HashMap<>();

            // 전체 민원 수
            long totalComplaints = complaintRepository.count();
            statistics.put("totalComplaints", totalComplaints);

            // 상태별 통계
            statistics.put("waitingCount", complaintRepository.countByStatus("대기"));
            statistics.put("processingCount", complaintRepository.countByStatus("처리중"));
            statistics.put("completedCount", complaintRepository.countByStatus("완료"));
            statistics.put("rejectedCount", complaintRepository.countByStatus("반려"));

            // 처리 완료/미완료 통계
            long completedTotal = complaintRepository.countCompletedComplaints();
            long pendingTotal = totalComplaints - completedTotal;
            statistics.put("completedTotal", completedTotal);
            statistics.put("pendingTotal", pendingTotal);

            // 긴급 민원 수
            statistics.put("urgentComplaints", getUrgentComplaints().size());

            // 평균 처리 시간
            Double avgProcessingTime = complaintRepository.getAverageProcessingTimeInHours();
            statistics.put("averageProcessingHours", avgProcessingTime != null ? avgProcessingTime : 0.0);

            // 해결률
            double resolutionRate = totalComplaints > 0
                    ? (double) completedTotal / totalComplaints * 100
                    : 0.0;
            statistics.put("resolutionRate", Math.round(resolutionRate * 100.0) / 100.0);

            logger.info("민원 통계 조회 완료 - 전체: {}, 대기: {}, 처리중: {}, 완료: {}, 반려: {}",
                    totalComplaints,
                    statistics.get("waitingCount"),
                    statistics.get("processingCount"),
                    statistics.get("completedCount"),
                    statistics.get("rejectedCount"));

            return statistics;

        } catch (Exception e) {
            logger.error("민원 통계 조회 실패", e);
            throw new RuntimeException("민원 통계 조회에 실패했습니다: " + e.getMessage());
        }
    }
}