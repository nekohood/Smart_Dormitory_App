package com.dormitory.SpringBoot.repository;

import com.dormitory.SpringBoot.domain.DDay;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

/**
 * D-Day 데이터 액세스 인터페이스
 */
@Repository
public interface DDayRepository extends JpaRepository<DDay, Long> {

    /**
     * 활성화된 모든 D-Day를 목표일 기준으로 조회
     */
    List<DDay> findByIsActiveTrueOrderByTargetDateAsc();

    /**
     * 모든 D-Day를 목표일 기준으로 조회
     */
    List<DDay> findAllByOrderByTargetDateAsc();

    /**
     * 중요 D-Day 조회
     */
    List<DDay> findByIsImportantTrueAndIsActiveTrueOrderByTargetDateAsc();

    /**
     * 생성자별 D-Day 조회
     */
    List<DDay> findByCreatedByOrderByTargetDateDesc(String createdBy);

    /**
     * 특정 날짜 이후의 D-Day 조회 (활성화된 것만)
     */
    List<DDay> findByIsActiveTrueAndTargetDateAfterOrderByTargetDateAsc(LocalDate date);

    /**
     * 특정 날짜 이전의 D-Day 조회 (활성화된 것만)
     */
    List<DDay> findByIsActiveTrueAndTargetDateBeforeOrderByTargetDateAsc(LocalDate date);

    /**
     * 제목으로 D-Day 검색
     */
    List<DDay> findByTitleContainingIgnoreCaseOrderByTargetDateAsc(String title);

    /**
     * 다가오는 D-Day 조회 (현재부터 N일 이내, 활성화된 것만)
     */
    @Query("SELECT d FROM DDay d WHERE d.isActive = true AND d.targetDate >= CURRENT_DATE AND d.targetDate <= :futureDate ORDER BY d.targetDate ASC")
    List<DDay> findUpcomingDDays(@Param("futureDate") LocalDate futureDate);

    /**
     * 오늘 도래하는 D-Day 조회
     */
    @Query("SELECT d FROM DDay d WHERE d.isActive = true AND d.targetDate = CURRENT_DATE")
    List<DDay> findTodayDDays();

    /**
     * 활성화된 D-Day 개수
     */
    long countByIsActiveTrue();

    /**
     * 중요 D-Day 개수
     */
    long countByIsImportantTrueAndIsActiveTrue();
}
