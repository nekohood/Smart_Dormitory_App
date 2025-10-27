package com.dormitory.SpringBoot.repository;

import com.dormitory.SpringBoot.domain.Complaint;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 민원 데이터 액세스 인터페이스 - 완성된 버전
 */
@Repository
public interface ComplaintRepository extends JpaRepository<Complaint, Long> {

    // ... (기존 메서드들은 그대로 유지) ...

    /**
     * 모든 민원을 최신순으로 조회
     */
    List<Complaint> findAllByOrderBySubmittedAtDesc();

    /**
     * 사용자별 민원 조회
     */
    List<Complaint> findByWriterIdOrderBySubmittedAtDesc(String writerId);

    /**
     * 상태별 민원 조회
     */
    List<Complaint> findByStatusOrderBySubmittedAtDesc(String status);

    /**
     * 카테고리별 민원 조회
     */
    List<Complaint> findByCategoryOrderBySubmittedAtDesc(String category);

    /**
     * 사용자별 특정 상태 민원 조회
     */
    List<Complaint> findByWriterIdAndStatusOrderBySubmittedAtDesc(String writerId, String status);

    /**
     * 제목으로 민원 검색
     */
    List<Complaint> findByTitleContainingIgnoreCaseOrderBySubmittedAtDesc(String title);

    /**
     * 내용으로 민원 검색
     */
    List<Complaint> findByContentContainingIgnoreCaseOrderBySubmittedAtDesc(String content);

    /**
     * 제목 또는 내용으로 민원 검색
     */
    @Query("SELECT c FROM Complaint c WHERE " +
            "LOWER(c.title) LIKE LOWER(CONCAT('%', :keyword, '%')) OR " +
            "LOWER(c.content) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
            "ORDER BY c.submittedAt DESC")
    List<Complaint> findByTitleOrContentContainingIgnoreCase(@Param("keyword") String keyword);

    /**
     * 특정 기간 이후의 민원 조회
     */
    List<Complaint> findBySubmittedAtAfterOrderBySubmittedAtDesc(LocalDateTime dateTime);

    /**
     * 긴급 민원 조회 (3일 이상 대기 상태)
     */
    @Query("SELECT c FROM Complaint c WHERE c.status = '대기' AND c.submittedAt < :urgentDate ORDER BY c.submittedAt ASC")
    List<Complaint> findUrgentComplaints(@Param("urgentDate") LocalDateTime urgentDate);

    /**
     * 상태별 민원 개수
     */
    long countByStatus(String status);

    /**
     * 카테고리별 민원 개수
     */
    long countByCategory(String category);

    /**
     * 사용자별 민원 개수
     */
    long countByWriterId(String writerId);

    /**
     * 사용자별 특정 상태 민원 개수 - 누락된 메서드 추가
     */
    long countByWriterIdAndStatus(String writerId, String status);

    /**
     * 오늘 제출된 민원 개수
     */
    @Query("SELECT COUNT(c) FROM Complaint c WHERE FUNCTION('DATE', c.createdAt) = CURRENT_DATE")
    long countTodayComplaints();

    /**
     * 이번 주 제출된 민원 개수
     */
    @Query("SELECT COUNT(c) FROM Complaint c WHERE c.submittedAt >= :startOfWeek")
    long countThisWeekComplaints(@Param("startOfWeek") LocalDateTime startOfWeek);

    /**
     * 이번 달 제출된 민원 개수
     */
    @Query("SELECT COUNT(c) FROM Complaint c WHERE c.submittedAt >= :startOfMonth")
    long countThisMonthComplaints(@Param("startOfMonth") LocalDateTime startOfMonth);

    /**
     * 특정 기간 동안의 민원 개수
     */
    @Query("SELECT COUNT(c) FROM Complaint c WHERE c.submittedAt BETWEEN :startDate AND :endDate")
    long countComplaintsBetween(@Param("startDate") LocalDateTime startDate,
                                @Param("endDate") LocalDateTime endDate);

    /**
     * 사용자별 특정 기간 민원 개수
     */
    @Query("SELECT COUNT(c) FROM Complaint c WHERE c.writerId = :writerId " +
            "AND c.submittedAt BETWEEN :startDate AND :endDate")
    long countByWriterIdBetween(@Param("writerId") String writerId,
                                @Param("startDate") LocalDateTime startDate,
                                @Param("endDate") LocalDateTime endDate);

    /**
     * 사용자별 카테고리별 민원 개수
     */
    long countByWriterIdAndCategory(String writerId, String category);

    /**
     * 처리 완료된 민원 중 평균 처리 시간 계산
     */
    @Query("SELECT AVG(TIMESTAMPDIFF(HOUR, c.submittedAt, c.processedAt)) FROM Complaint c " +
            "WHERE c.status = '완료' AND c.processedAt IS NOT NULL")
    Double getAverageProcessingTimeInHours();

    /**
     * 특정 관리자가 처리한 민원 조회
     */
    @Query("SELECT c FROM Complaint c WHERE c.adminComment IS NOT NULL " +
            "ORDER BY c.processedAt DESC")
    List<Complaint> findProcessedComplaints();

    /**
     * 이미지가 첨부된 민원 조회
     */
    List<Complaint> findByImagePathIsNotNullOrderBySubmittedAtDesc();

    /**
     * 이미지가 첨부되지 않은 민원 조회
     */
    List<Complaint> findByImagePathIsNullOrderBySubmittedAtDesc();

    /**
     * 특정 월의 민원 통계
     */
    @Query("SELECT c.category, COUNT(c), " +
            "SUM(CASE WHEN c.status = '완료' THEN 1 ELSE 0 END) as completed, " +
            "SUM(CASE WHEN c.status = '대기' THEN 1 ELSE 0 END) as waiting " +
            "FROM Complaint c WHERE YEAR(c.submittedAt) = :year AND MONTH(c.submittedAt) = :month " +
            "GROUP BY c.category ORDER BY COUNT(c) DESC")
    List<Object[]> getMonthlyStatisticsByCategory(@Param("year") int year, @Param("month") int month);

    /**
     * 사용자별 민원 통계
     */
    @Query("SELECT c.writerId, COUNT(c), " +
            "SUM(CASE WHEN c.status = '완료' THEN 1 ELSE 0 END) as completed, " +
            "SUM(CASE WHEN c.status = '대기' THEN 1 ELSE 0 END) as waiting " +
            "FROM Complaint c GROUP BY c.writerId ORDER BY COUNT(c) DESC")
    List<Object[]> getUserComplaintStatistics();

    /**
     * 최근 활동이 있는 민원 조회
     */
    @Query("SELECT c FROM Complaint c WHERE c.updatedAt >= :since ORDER BY c.updatedAt DESC")
    List<Complaint> findRecentActivity(@Param("since") LocalDateTime since);

    /**
     * 답변이 필요한 민원 조회 (대기 상태이고 3일 이상 지난 것)
     */
    @Query("SELECT c FROM Complaint c WHERE c.status = '대기' " +
            "AND c.submittedAt <= :deadline ORDER BY c.submittedAt ASC")
    List<Complaint> findComplaintsNeedingResponse(@Param("deadline") LocalDateTime deadline);

    /**
     * 키워드별 민원 검색 (제목, 내용, 카테고리)
     */
    @Query("SELECT c FROM Complaint c WHERE " +
            "LOWER(c.title) LIKE LOWER(CONCAT('%', :keyword, '%')) OR " +
            "LOWER(c.content) LIKE LOWER(CONCAT('%', :keyword, '%')) OR " +
            "LOWER(c.category) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
            "ORDER BY c.submittedAt DESC")
    List<Complaint> searchByKeyword(@Param("keyword") String keyword);

    /**
     * 특정 상태의 민원을 최신순으로 제한된 개수만큼 조회
     */
    @Query("SELECT c FROM Complaint c WHERE c.status = :status " +
            "ORDER BY c.submittedAt DESC LIMIT :limit")
    List<Complaint> findTopByStatusOrderBySubmittedAtDesc(@Param("status") String status,
                                                          @Param("limit") int limit);

    /**
     * 민원 처리 상태 업데이트
     */
    @Query("UPDATE Complaint c SET c.status = :status, c.adminComment = :comment, " +
            "c.processedAt = :processedAt, c.updatedAt = :updatedAt WHERE c.id = :id")
    void updateComplaintStatus(@Param("id") Long id,
                               @Param("status") String status,
                               @Param("comment") String comment,
                               @Param("processedAt") LocalDateTime processedAt,
                               @Param("updatedAt") LocalDateTime updatedAt);

    /**
     * 대기 중인 민원 개수 조회 - 누락된 메서드 추가
     */
    @Query("SELECT COUNT(c) FROM Complaint c WHERE c.status = '대기'")
    long countPendingComplaints();

    /**
     * 카테고리별 통계 조회 - 누락된 메서드 추가
     */
    @Query("SELECT c.category, COUNT(c) FROM Complaint c GROUP BY c.category ORDER BY COUNT(c) DESC")
    List<Object[]> getCategoryStatistics();

    /**
     * 처리중인 민원 개수 조회
     */
    @Query("SELECT COUNT(c) FROM Complaint c WHERE c.status = '처리중'")
    long countProcessingComplaints();

    /**
     * 완료된 민원 개수 조회
     */
    @Query("SELECT COUNT(c) FROM Complaint c WHERE c.status = '완료'")
    long countCompletedComplaints();

    /**
     * 반려된 민원 개수 조회
     */
    @Query("SELECT COUNT(c) FROM Complaint c WHERE c.status = '반려'")
    long countRejectedComplaints();

    /**
     * 전체 민원 상태별 통계
     */
    @Query("SELECT c.status, COUNT(c) FROM Complaint c GROUP BY c.status ORDER BY COUNT(c) DESC")
    List<Object[]> getStatusStatistics();

    /**
     * 월별 민원 접수 통계
     */
    @Query("SELECT YEAR(c.submittedAt), MONTH(c.submittedAt), COUNT(c) " +
            "FROM Complaint c " +
            "GROUP BY YEAR(c.submittedAt), MONTH(c.submittedAt) " +
            "ORDER BY YEAR(c.submittedAt) DESC, MONTH(c.submittedAt) DESC")
    List<Object[]> getMonthlySubmissionStatistics();

    /**
     * 사용자별 최근 민원 조회 (버그 수정: 누락된 메서드 추가)
     */
    @Query("SELECT c FROM Complaint c WHERE c.writerId = :writerId " +
            "ORDER BY c.submittedAt DESC LIMIT :limit")
    List<Complaint> findRecentComplaintsByUser(@Param("writerId") String writerId, @Param("limit") int limit);

    /**
     * 우선순위가 높은 민원 조회 (3일 이상 대기)
     */
    @Query("SELECT c FROM Complaint c WHERE c.status = '대기' " +
            "AND c.submittedAt <= :priorityDate ORDER BY c.submittedAt ASC")
    List<Complaint> findHighPriorityComplaints(@Param("priorityDate") LocalDateTime priorityDate);

    /**
     * 특정 기간의 민원 해결율 계산
     */
    @Query("SELECT " +
            "COUNT(c) as total, " +
            "SUM(CASE WHEN c.status = '완료' THEN 1 ELSE 0 END) as completed, " +
            "ROUND(SUM(CASE WHEN c.status = '완료' THEN 1 ELSE 0 END) * 100.0 / COUNT(c), 2) as resolution_rate " +
            "FROM Complaint c WHERE c.submittedAt BETWEEN :startDate AND :endDate")
    List<Object[]> getResolutionRateStatistics(@Param("startDate") LocalDateTime startDate,
                                               @Param("endDate") LocalDateTime endDate);
}