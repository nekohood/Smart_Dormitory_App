package com.dormitory.SpringBoot.repository;

import com.dormitory.SpringBoot.domain.Inspection;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

/**
 * 점호 정보에 대한 데이터베이스 접근을 담당하는 Repository - 완성된 버전
 */
@Repository
public interface InspectionRepository extends JpaRepository<Inspection, Long> {

    /**
     * 특정 사용자의 점호 기록을 최신순으로 조회 (버그 수정: 누락된 메서드 추가)
     */
    List<Inspection> findByUserIdOrderByCreatedAtDesc(String userId);

    /**
     * 특정 상태의 점호 기록 수 조회
     */
    long countByStatus(String status);

    /**
     * 특정 사용자의 특정 날짜 점호 기록 조회
     */
    @Query("SELECT i FROM Inspection i WHERE i.userId = :userId " +
            "AND DATE(i.inspectionDate) = DATE(:date) " +
            "ORDER BY i.createdAt DESC")
    List<Inspection> findByUserIdAndInspectionDate(@Param("userId") String userId,
                                                   @Param("date") LocalDateTime date);

    /**
     * 특정 날짜의 모든 점호 기록을 조회 (관리자용)
     */
    @Query("SELECT i FROM Inspection i WHERE DATE(i.inspectionDate) = DATE(:date) " +
            "ORDER BY i.createdAt DESC")
    List<Inspection> findByInspectionDate(@Param("date") LocalDateTime date);

    /**
     * 특정 기간의 점호 기록을 조회
     */
    @Query("SELECT i FROM Inspection i WHERE i.inspectionDate BETWEEN :startDate AND :endDate " +
            "ORDER BY i.inspectionDate DESC")
    List<Inspection> findByInspectionDateBetween(@Param("startDate") LocalDateTime startDate,
                                                 @Param("endDate") LocalDateTime endDate);

    /**
     * 특정 상태의 점호 기록을 조회
     */
    List<Inspection> findByStatusOrderByCreatedAtDesc(String status);

    /**
     * 특정 날짜의 통과한 점호 개수 조회
     */
    @Query("SELECT COUNT(i) FROM Inspection i WHERE DATE(i.inspectionDate) = DATE(:date) " +
            "AND i.status = 'PASS'")
    long countPassedInspectionsByDate(@Param("date") LocalDateTime date);

    /**
     * 특정 날짜의 실패한 점호 개수 조회
     */
    @Query("SELECT COUNT(i) FROM Inspection i WHERE DATE(i.inspectionDate) = DATE(:date) " +
            "AND i.status = 'FAIL'")
    long countFailedInspectionsByDate(@Param("date") LocalDateTime date);

    /**
     * 특정 날짜의 전체 점호 개수 조회
     */
    @Query("SELECT COUNT(i) FROM Inspection i WHERE DATE(i.inspectionDate) = DATE(:date)")
    long countTotalInspectionsByDate(@Param("date") LocalDateTime date);

    /**
     * 특정 날짜의 재검 점호 개수 조회
     */
    @Query("SELECT COUNT(i) FROM Inspection i WHERE DATE(i.inspectionDate) = DATE(:date) " +
            "AND i.isReInspection = true")
    long countReInspectionsByDate(@Param("date") LocalDateTime date);

    /**
     * 특정 사용자의 오늘 점호 기록이 있는지 확인
     */
    @Query("SELECT i FROM Inspection i WHERE i.user.userId = :userId AND FUNCTION('DATE', i.createdAt) = CURRENT_DATE")
    List<Inspection> findTodayInspectionByUserId(@Param("userId") String userId);
    /**
     * 재검 점호 기록 조회
     */
    List<Inspection> findByIsReInspectionTrueOrderByCreatedAtDesc();

    /**
     * 특정 사용자의 점호 통계 - 전체 개수
     */
    long countByUserId(String userId);

    /**
     * 특정 사용자의 상태별 점호 개수
     */
    long countByUserIdAndStatus(String userId, String status);

    /**
     * 특정 사용자의 재검 점호 개수
     */
    long countByUserIdAndIsReInspectionTrue(String userId);

    /**
     * 특정 사용자의 평균 점호 점수
     */
    @Query("SELECT AVG(i.score) FROM Inspection i WHERE i.userId = :userId")
    Double getAverageScoreByUserId(@Param("userId") String userId);

    /**
     * 특정 사용자의 최근 점호 기록 (개수 제한)
     */
    @Query("SELECT i FROM Inspection i WHERE i.userId = :userId " +
            "ORDER BY i.createdAt DESC")
    List<Inspection> findTopByUserIdOrderByCreatedAtDesc(@Param("userId") String userId);

    /**
     * 특정 점수 이상의 점호 기록 조회
     */
    @Query("SELECT i FROM Inspection i WHERE i.score >= :minScore " +
            "ORDER BY i.createdAt DESC")
    List<Inspection> findByScoreGreaterThanEqual(@Param("minScore") int minScore);

    /**
     * 특정 점수 이하의 점호 기록 조회
     */
    @Query("SELECT i FROM Inspection i WHERE i.score <= :maxScore " +
            "ORDER BY i.createdAt DESC")
    List<Inspection> findByScoreLessThanEqual(@Param("maxScore") int maxScore);

    /**
     * 특정 기간의 사용자별 점호 통계
     */
    @Query("SELECT i.userId, COUNT(i), AVG(i.score), " +
            "SUM(CASE WHEN i.status = 'PASS' THEN 1 ELSE 0 END), " +
            "SUM(CASE WHEN i.status = 'FAIL' THEN 1 ELSE 0 END) " +
            "FROM Inspection i WHERE i.inspectionDate BETWEEN :startDate AND :endDate " +
            "GROUP BY i.userId")
    List<Object[]> getUserStatisticsBetween(@Param("startDate") LocalDateTime startDate,
                                            @Param("endDate") LocalDateTime endDate);

    /**
     * 월별 점호 통계
     */
    @Query("SELECT YEAR(i.inspectionDate), MONTH(i.inspectionDate), COUNT(i), " +
            "AVG(i.score), " +
            "SUM(CASE WHEN i.status = 'PASS' THEN 1 ELSE 0 END), " +
            "SUM(CASE WHEN i.status = 'FAIL' THEN 1 ELSE 0 END) " +
            "FROM Inspection i " +
            "GROUP BY YEAR(i.inspectionDate), MONTH(i.inspectionDate) " +
            "ORDER BY YEAR(i.inspectionDate) DESC, MONTH(i.inspectionDate) DESC")
    List<Object[]> getMonthlyStatistics();

    /**
     * 일별 점호 통계
     */
    @Query("SELECT DATE(i.inspectionDate), COUNT(i), AVG(i.score), " +
            "SUM(CASE WHEN i.status = 'PASS' THEN 1 ELSE 0 END), " +
            "SUM(CASE WHEN i.status = 'FAIL' THEN 1 ELSE 0 END) " +
            "FROM Inspection i WHERE i.inspectionDate BETWEEN :startDate AND :endDate " +
            "GROUP BY DATE(i.inspectionDate) " +
            "ORDER BY DATE(i.inspectionDate) DESC")
    List<Object[]> getDailyStatisticsBetween(@Param("startDate") LocalDateTime startDate,
                                             @Param("endDate") LocalDateTime endDate);

    /**
     * 상위 점수 점호 기록 조회
     */
    @Query("SELECT i FROM Inspection i ORDER BY i.score DESC")
    List<Inspection> findTopScoreInspections();

    /**
     * 하위 점수 점호 기록 조회
     */
    @Query("SELECT i FROM Inspection i ORDER BY i.score ASC")
    List<Inspection> findLowScoreInspections();

    /**
     * 특정 사용자의 최고 점수
     */
    @Query("SELECT MAX(i.score) FROM Inspection i WHERE i.userId = :userId")
    Optional<Integer> getMaxScoreByUserId(@Param("userId") String userId);

    /**
     * 특정 사용자의 최저 점수
     */
    @Query("SELECT MIN(i.score) FROM Inspection i WHERE i.userId = :userId")
    Optional<Integer> getMinScoreByUserId(@Param("userId") String userId);

    /**
     * 오늘 점호를 완료하지 않은 사용자 목록 (관리자용)
     */
    @Query("SELECT DISTINCT u.id FROM User u WHERE u.isActive = true " +
            "AND u.id NOT IN (SELECT i.userId FROM Inspection i WHERE DATE(i.inspectionDate) = CURRENT_DATE)")
    List<String> findUsersWithoutTodayInspection();

    /**
     * 연속 통과 기록 조회
     */
    @Query("SELECT i FROM Inspection i WHERE i.userId = :userId AND i.status = 'PASS' " +
            "ORDER BY i.inspectionDate DESC")
    List<Inspection> findConsecutivePassesByUserId(@Param("userId") String userId);

    /**
     * 연속 실패 기록 조회
     */
    @Query("SELECT i FROM Inspection i WHERE i.userId = :userId AND i.status = 'FAIL' " +
            "ORDER BY i.inspectionDate DESC")
    List<Inspection> findConsecutiveFailsByUserId(@Param("userId") String userId);

    /**
     * 특정 기간의 평균 점수
     */
    @Query("SELECT AVG(i.score) FROM Inspection i WHERE i.inspectionDate BETWEEN :startDate AND :endDate")
    Double getAverageScoreBetween(@Param("startDate") LocalDateTime startDate,
                                  @Param("endDate") LocalDateTime endDate);

    /**
     * 관리자 코멘트가 있는 점호 기록 조회
     */
    List<Inspection> findByAdminCommentIsNotNullOrderByCreatedAtDesc();

    /**
     * Gemini 피드백이 있는 점호 기록 조회
     */
    List<Inspection> findByGeminiFeedbackIsNotNullOrderByCreatedAtDesc();

    /**
     * 이미지 경로로 점호 기록 조회
     */
    Optional<Inspection> findByImagePath(String imagePath);

    /**
     * 특정 방 번호의 점호 기록 조회
     */
    List<Inspection> findByRoomNumberOrderByCreatedAtDesc(String roomNumber);

    /**
     * 점호 상태 업데이트
     */
    @Query("UPDATE Inspection i SET i.status = :status, i.adminComment = :comment, i.updatedAt = :updateTime WHERE i.id = :inspectionId")
    void updateInspectionStatus(@Param("inspectionId") Long inspectionId,
                                @Param("status") String status,
                                @Param("comment") String comment,
                                @Param("updateTime") LocalDateTime updateTime);
}