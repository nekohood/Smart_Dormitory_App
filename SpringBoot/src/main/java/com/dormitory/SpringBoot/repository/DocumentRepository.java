package com.dormitory.SpringBoot.repository;

import com.dormitory.SpringBoot.domain.Document;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 공공서류 데이터 액세스 인터페이스
 */
@Repository
public interface DocumentRepository extends JpaRepository<Document, Long> {

    /**
     * 모든 서류를 최신순으로 조회
     */
    List<Document> findAllByOrderBySubmittedAtDesc();

    /**
     * 사용자별 서류 조회
     */
    List<Document> findByWriterIdOrderBySubmittedAtDesc(String writerId);

    /**
     * 상태별 서류 조회
     */
    List<Document> findByStatusOrderBySubmittedAtDesc(String status);

    /**
     * 카테고리별 서류 조회
     */
    List<Document> findByCategoryOrderBySubmittedAtDesc(String category);

    /**
     * 사용자별 특정 상태 서류 조회
     */
    List<Document> findByWriterIdAndStatusOrderBySubmittedAtDesc(String writerId, String status);

    /**
     * 제목으로 서류 검색
     */
    List<Document> findByTitleContainingIgnoreCaseOrderBySubmittedAtDesc(String title);

    /**
     * 내용으로 서류 검색
     */
    List<Document> findByContentContainingIgnoreCaseOrderBySubmittedAtDesc(String content);

    /**
     * 제목 또는 내용으로 서류 검색
     */
    @Query("SELECT d FROM Document d WHERE " +
            "LOWER(d.title) LIKE LOWER(CONCAT('%', :keyword, '%')) OR " +
            "LOWER(d.content) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
            "ORDER BY d.submittedAt DESC")
    List<Document> findByTitleOrContentContainingIgnoreCase(@Param("keyword") String keyword);

    /**
     * 특정 기간 이후의 서류 조회
     */
    List<Document> findBySubmittedAtAfterOrderBySubmittedAtDesc(LocalDateTime dateTime);

    /**
     * 긴급 서류 조회 (7일 이상 대기 상태)
     */
    @Query("SELECT d FROM Document d WHERE d.status = '대기' AND d.submittedAt < :urgentDate ORDER BY d.submittedAt ASC")
    List<Document> findUrgentDocuments(@Param("urgentDate") LocalDateTime urgentDate);

    /**
     * 상태별 서류 개수
     */
    long countByStatus(String status);

    /**
     * 카테고리별 서류 개수
     */
    long countByCategory(String category);

    /**
     * 사용자별 서류 개수
     */
    long countByWriterId(String writerId);

    /**
     * 오늘 제출된 서류 개수
     */
    @Query("SELECT COUNT(d) FROM Document d WHERE DATE(d.submittedAt) = CURRENT_DATE")
    long countTodayDocuments();

    /**
     * 이번 주 제출된 서류 개수
     */
    @Query("SELECT COUNT(d) FROM Document d WHERE d.submittedAt >= :startOfWeek")
    long countThisWeekDocuments(@Param("startOfWeek") LocalDateTime startOfWeek);

    /**
     * 이번 달 제출된 서류 개수
     */
    @Query("SELECT COUNT(d) FROM Document d WHERE d.submittedAt >= :startOfMonth")
    long countThisMonthDocuments(@Param("startOfMonth") LocalDateTime startOfMonth);

    /**
     * 처리 완료된 서류 개수
     */
    @Query("SELECT COUNT(d) FROM Document d WHERE d.status IN ('승인', '반려')")
    long countCompletedDocuments();

    /**
     * 처리 중인 서류 개수
     */
    @Query("SELECT COUNT(d) FROM Document d WHERE d.status IN ('대기', '검토중')")
    long countPendingDocuments();

    /**
     * 처리 완료된 서류 개수 (승인 + 반려)
     */
    @Query("SELECT COUNT(d) FROM Document d WHERE d.status IN ('승인', '반려')")
    long countProcessedDocuments();

    /**
     * 평균 처리 시간 (시간 단위)
     */
    @Query("SELECT AVG(TIMESTAMPDIFF(HOUR, d.submittedAt, d.processedAt)) FROM Document d WHERE d.processedAt IS NOT NULL")
    Double getAverageProcessingTimeInHours();

    /**
     * 최근 N일간의 서류 개수
     */
    @Query("SELECT COUNT(d) FROM Document d WHERE d.submittedAt >= :since")
    long countDocumentsSince(@Param("since") LocalDateTime since);

    /**
     * 카테고리별 통계
     */
    @Query("SELECT d.category, COUNT(d) FROM Document d GROUP BY d.category ORDER BY COUNT(d) DESC")
    List<Object[]> getCategoryStatistics();

    /**
     * 월별 서류 통계
     */
    @Query("SELECT YEAR(d.submittedAt), MONTH(d.submittedAt), COUNT(d) " +
            "FROM Document d " +
            "WHERE d.submittedAt >= :since " +
            "GROUP BY YEAR(d.submittedAt), MONTH(d.submittedAt) " +
            "ORDER BY YEAR(d.submittedAt) DESC, MONTH(d.submittedAt) DESC")
    List<Object[]> getMonthlyStatistics(@Param("since") LocalDateTime since);

    /**
     * 상태별 통계
     */
    @Query("SELECT d.status, COUNT(d) FROM Document d GROUP BY d.status")
    List<Object[]> getStatusStatistics();
}