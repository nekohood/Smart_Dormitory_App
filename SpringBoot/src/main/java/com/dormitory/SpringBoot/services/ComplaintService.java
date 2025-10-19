package com.dormitory.SpringBoot.services;

import com.dormitory.SpringBoot.domain.Complaint;
import com.dormitory.SpringBoot.repository.ComplaintRepository;
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
 * 민원 관련 비즈니스 로직을 처리하는 서비스 - 완성된 버전
 */
@Service
@Transactional
public class ComplaintService {

    private static final Logger logger = LoggerFactory.getLogger(ComplaintService.class);

    @Autowired
    private ComplaintRepository complaintRepository;

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
     * 민원 신고 제출 - 수정된 시그니처
     */
    public Complaint submitComplaint(String title, String content, String category,
                                     String writerId, String writerName, MultipartFile imageFile) {
        try {
            logger.info("민원 제출 - 작성자: {}, 제목: {}", writerId, title);

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
    public void deleteComplaint(Long complaintId) {
        try {
            logger.info("민원 삭제 - ID: {}", complaintId);

            Complaint complaint = complaintRepository.findById(complaintId)
                    .orElseThrow(() -> new RuntimeException("민원을 찾을 수 없습니다. ID: " + complaintId));

            // 첨부 파일 삭제
            if (complaint.getImagePath() != null) {
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

            return complaintRepository.findByTitleOrContentContainingIgnoreCase(keyword.trim());
        } catch (Exception e) {
            logger.error("민원 검색 실패", e);
            throw new RuntimeException("민원 검색에 실패했습니다: " + e.getMessage());
        }
    }

    // =============================================================================
    // 통계 및 분석 메서드들 (기존 메서드들)
    // =============================================================================

    /**
     * 대기 중인 민원 개수 조회
     */
    @Transactional(readOnly = true)
    public long countPendingComplaints() {
        try {
            logger.debug("대기 중인 민원 개수 조회");
            return complaintRepository.countPendingComplaints();
        } catch (Exception e) {
            logger.error("대기 중인 민원 개수 조회 실패", e);
            return 0;
        }
    }

    /**
     * 카테고리별 통계 조회
     */
    @Transactional(readOnly = true)
    public Map<String, Long> getCategoryStatistics() {
        try {
            logger.debug("카테고리별 통계 조회");

            List<Object[]> results = complaintRepository.getCategoryStatistics();
            Map<String, Long> statistics = new HashMap<>();

            for (Object[] result : results) {
                String category = (String) result[0];
                Long count = (Long) result[1];
                statistics.put(category, count);
            }

            return statistics;
        } catch (Exception e) {
            logger.error("카테고리별 통계 조회 실패", e);
            return new HashMap<>();
        }
    }

    /**
     * 전체 민원 통계 조회
     */
    @Transactional(readOnly = true)
    public Map<String, Object> getComplaintStatistics() {
        try {
            logger.debug("전체 민원 통계 조회");

            Map<String, Object> statistics = new HashMap<>();

            // 기본 통계
            statistics.put("total", complaintRepository.count());
            statistics.put("pending", complaintRepository.countPendingComplaints());
            statistics.put("processing", complaintRepository.countProcessingComplaints());
            statistics.put("completed", complaintRepository.countCompletedComplaints());
            statistics.put("rejected", complaintRepository.countRejectedComplaints());

            // 오늘 접수된 민원
            statistics.put("todaySubmissions", complaintRepository.countTodayComplaints());

            // 카테고리별 통계
            statistics.put("categoryStats", getCategoryStatistics());

            // 상태별 통계
            Map<String, Long> statusStats = new HashMap<>();
            List<Object[]> statusResults = complaintRepository.getStatusStatistics();
            for (Object[] result : statusResults) {
                String status = (String) result[0];
                Long count = (Long) result[1];
                statusStats.put(status, count);
            }
            statistics.put("statusStats", statusStats);

            return statistics;
        } catch (Exception e) {
            logger.error("전체 민원 통계 조회 실패", e);
            return new HashMap<>();
        }
    }

    /**
     * 처리 우선순위가 높은 민원 조회
     */
    @Transactional(readOnly = true)
    public List<Complaint> getHighPriorityComplaints() {
        try {
            logger.debug("우선순위 높은 민원 조회");

            LocalDateTime priorityDate = LocalDateTime.now().minusDays(3);
            return complaintRepository.findHighPriorityComplaints(priorityDate);
        } catch (Exception e) {
            logger.error("우선순위 높은 민원 조회 실패", e);
            throw new RuntimeException("우선순위 민원 조회에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 민원 해결율 통계 조회
     */
    @Transactional(readOnly = true)
    public Map<String, Object> getResolutionRateStatistics(LocalDateTime startDate, LocalDateTime endDate) {
        try {
            logger.debug("민원 해결율 통계 조회: {} ~ {}", startDate, endDate);

            List<Object[]> results = complaintRepository.getResolutionRateStatistics(startDate, endDate);
            Map<String, Object> statistics = new HashMap<>();

            if (!results.isEmpty()) {
                Object[] result = results.get(0);
                Long total = (Long) result[0];
                Long completed = (Long) result[1];
                Double resolutionRate = (Double) result[2];

                statistics.put("totalComplaints", total);
                statistics.put("completedComplaints", completed);
                statistics.put("resolutionRate", resolutionRate);
                statistics.put("pendingComplaints", total - completed);
            } else {
                statistics.put("totalComplaints", 0L);
                statistics.put("completedComplaints", 0L);
                statistics.put("resolutionRate", 0.0);
                statistics.put("pendingComplaints", 0L);
            }

            return statistics;
        } catch (Exception e) {
            logger.error("민원 해결율 통계 조회 실패", e);
            return new HashMap<>();
        }
    }

    /**
     * 월별 민원 접수 통계 조회
     */
    @Transactional(readOnly = true)
    public List<Map<String, Object>> getMonthlySubmissionStatistics() {
        try {
            logger.debug("월별 민원 접수 통계 조회");

            List<Object[]> results = complaintRepository.getMonthlySubmissionStatistics();
            return results.stream()
                    .map(result -> {
                        Map<String, Object> monthlyData = new HashMap<>();
                        monthlyData.put("year", result[0]);
                        monthlyData.put("month", result[1]);
                        monthlyData.put("count", result[2]);
                        return monthlyData;
                    })
                    .toList();
        } catch (Exception e) {
            logger.error("월별 민원 접수 통계 조회 실패", e);
            throw new RuntimeException("월별 통계 조회에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 사용자별 최근 민원 조회
     */
    @Transactional(readOnly = true)
    public List<Complaint> getRecentComplaintsByUser(String userId, int limit) {
        try {
            logger.debug("사용자별 최근 민원 조회: {}, 개수: {}", userId, limit);
            return complaintRepository.findRecentComplaintsByUser(userId, limit);
        } catch (Exception e) {
            logger.error("사용자별 최근 민원 조회 실패", e);
            throw new RuntimeException("사용자 민원 조회에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 긴급 처리가 필요한 민원 조회
     */
    @Transactional(readOnly = true)
    public List<Complaint> getUrgentComplaints() {
        try {
            logger.debug("긴급 처리 필요 민원 조회");

            LocalDateTime urgentDate = LocalDateTime.now().minusDays(3);
            return complaintRepository.findUrgentComplaints(urgentDate);
        } catch (Exception e) {
            logger.error("긴급 민원 조회 실패", e);
            throw new RuntimeException("긴급 민원 조회에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 평균 처리 시간 조회
     */
    @Transactional(readOnly = true)
    public double getAverageProcessingTime() {
        try {
            logger.debug("평균 처리 시간 조회");

            Double avgTime = complaintRepository.getAverageProcessingTimeInHours();
            return avgTime != null ? avgTime : 0.0;
        } catch (Exception e) {
            logger.error("평균 처리 시간 조회 실패", e);
            return 0.0;
        }
    }

    /**
     * 관리자용 대시보드 데이터 조회
     */
    @Transactional(readOnly = true)
    public Map<String, Object> getAdminDashboardData() {
        try {
            logger.debug("관리자 대시보드 데이터 조회");

            Map<String, Object> dashboardData = new HashMap<>();

            // 기본 통계
            dashboardData.put("statistics", getComplaintStatistics());

            // 긴급 처리 필요 민원
            dashboardData.put("urgentComplaints", getUrgentComplaints());

            // 평균 처리 시간
            dashboardData.put("averageProcessingTime", getAverageProcessingTime());

            // 이번 달 해결율
            LocalDateTime startOfMonth = LocalDateTime.now().withDayOfMonth(1).withHour(0).withMinute(0).withSecond(0);
            LocalDateTime now = LocalDateTime.now();
            dashboardData.put("monthlyResolutionRate", getResolutionRateStatistics(startOfMonth, now));

            return dashboardData;
        } catch (Exception e) {
            logger.error("관리자 대시보드 데이터 조회 실패", e);
            return new HashMap<>();
        }
    }

    // =============================================================================
    // 유틸리티 메서드들
    // =============================================================================

    /**
     * 민원 카테고리 목록
     */
    public List<String> getComplaintCategories() {
        return List.of(
                "시설 문제",
                "소음 문제",
                "청소 문제",
                "보안 문제",
                "기타 불편사항",
                "개선 건의",
                "분실물 신고",
                "기타"
        );
    }

    /**
     * 상태 목록 (관리자용)
     */
    public List<String> getStatusList() {
        return List.of(
                "대기",
                "처리중",
                "완료",
                "반려"
        );
    }
}