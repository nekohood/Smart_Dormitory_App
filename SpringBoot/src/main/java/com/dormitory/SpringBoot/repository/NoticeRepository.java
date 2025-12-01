package com.dormitory.SpringBoot.repository;

import com.dormitory.SpringBoot.domain.Notice;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

/**
 * 공지사항 데이터 액세스 인터페이스
 * ✅ 수정: 조회수 증가용 Native Query 추가
 */
@Repository
public interface NoticeRepository extends JpaRepository<Notice, Long> {

    /**
     * 모든 공지사항을 최신순으로 조회 (고정 공지사항 우선)
     */
    @Query("SELECT n FROM Notice n ORDER BY n.isPinned DESC, n.createdAt DESC")
    List<Notice> findAllOrderByPinnedAndCreatedAt();

    /**
     * 고정된 공지사항들을 조회
     */
    List<Notice> findByIsPinnedTrueOrderByCreatedAtDesc();

    /**
     * 특정 기간 이후의 공지사항 조회
     */
    List<Notice> findByCreatedAtAfterOrderByCreatedAtDesc(LocalDateTime dateTime);

    /**
     * 제목으로 공지사항 검색
     */
    List<Notice> findByTitleContainingIgnoreCaseOrderByCreatedAtDesc(String title);

    /**
     * 내용으로 공지사항 검색
     */
    List<Notice> findByContentContainingIgnoreCaseOrderByCreatedAtDesc(String content);

    /**
     * 제목 또는 내용으로 공지사항 검색
     */
    @Query("SELECT n FROM Notice n WHERE " +
            "LOWER(n.title) LIKE LOWER(CONCAT('%', :keyword, '%')) OR " +
            "LOWER(n.content) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
            "ORDER BY n.isPinned DESC, n.createdAt DESC")
    List<Notice> findByTitleOrContentContainingIgnoreCase(@Param("keyword") String keyword);

    /**
     * 작성자별 공지사항 조회
     */
    List<Notice> findByAuthorOrderByCreatedAtDesc(String author);

    /**
     * 최신 공지사항 1개 조회
     */
    Optional<Notice> findFirstByOrderByCreatedAtDesc();

    /**
     * 조회수 상위 N개 공지사항 조회
     */
    @Query("SELECT n FROM Notice n ORDER BY n.viewCount DESC, n.createdAt DESC")
    List<Notice> findTopByOrderByViewCountDesc();

    /**
     * 특정 조회수 이상의 공지사항 개수
     */
    long countByViewCountGreaterThanEqual(Integer viewCount);

    /**
     * 오늘 작성된 공지사항 개수
     */
    @Query("SELECT COUNT(n) FROM Notice n WHERE DATE(n.createdAt) = CURRENT_DATE")
    long countTodayNotices();

    /**
     * 이번 주 작성된 공지사항 개수
     */
    @Query("SELECT COUNT(n) FROM Notice n WHERE n.createdAt >= :startOfWeek")
    long countThisWeekNotices(@Param("startOfWeek") LocalDateTime startOfWeek);

    /**
     * 이번 달 작성된 공지사항 개수
     */
    @Query("SELECT COUNT(n) FROM Notice n WHERE n.createdAt >= :startOfMonth")
    long countThisMonthNotices(@Param("startOfMonth") LocalDateTime startOfMonth);

    /**
     * ✅ 신규: 조회수만 증가 (updated_at은 변경하지 않음)
     * Native Query를 사용하여 @LastModifiedDate 자동 갱신을 우회
     * clearAutomatically = true로 영속성 컨텍스트 자동 초기화
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query(value = "UPDATE notices SET view_count = view_count + 1 WHERE id = :id", nativeQuery = true)
    void incrementViewCountOnly(@Param("id") Long id);
}