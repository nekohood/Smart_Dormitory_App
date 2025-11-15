package com.dormitory.SpringBoot.repository;

import com.dormitory.SpringBoot.domain.Calendar;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 캘린더 데이터 액세스 인터페이스
 */
@Repository
public interface CalendarRepository extends JpaRepository<Calendar, Long> {

    /**
     * 모든 일정을 시작일 기준으로 조회
     */
    List<Calendar> findAllByOrderByStartDateAsc();

    /**
     * 특정 기간의 일정 조회
     */
    @Query("SELECT c FROM Calendar c WHERE c.startDate >= :start AND c.endDate <= :end ORDER BY c.startDate ASC")
    List<Calendar> findByDateRange(@Param("start") LocalDateTime start, @Param("end") LocalDateTime end);

    /**
     * 특정 날짜가 포함된 일정 조회
     */
    @Query("SELECT c FROM Calendar c WHERE :date BETWEEN c.startDate AND c.endDate ORDER BY c.startDate ASC")
    List<Calendar> findByDate(@Param("date") LocalDateTime date);

    /**
     * 카테고리별 일정 조회
     */
    List<Calendar> findByCategoryOrderByStartDateAsc(String category);

    /**
     * 중요 일정 조회
     */
    List<Calendar> findByIsImportantTrueOrderByStartDateAsc();

    /**
     * 생성자별 일정 조회
     */
    List<Calendar> findByCreatedByOrderByStartDateDesc(String createdBy);

    /**
     * 제목으로 일정 검색
     */
    List<Calendar> findByTitleContainingIgnoreCaseOrderByStartDateAsc(String title);

    /**
     * 특정 월의 일정 조회
     */
    @Query("SELECT c FROM Calendar c WHERE YEAR(c.startDate) = :year AND MONTH(c.startDate) = :month ORDER BY c.startDate ASC")
    List<Calendar> findByMonth(@Param("year") int year, @Param("month") int month);

    /**
     * 다가오는 일정 조회 (현재부터 N일 이내)
     */
    @Query("SELECT c FROM Calendar c WHERE c.startDate >= :now AND c.startDate <= :future ORDER BY c.startDate ASC")
    List<Calendar> findUpcomingEvents(@Param("now") LocalDateTime now, @Param("future") LocalDateTime future);

    /**
     * 오늘의 일정 조회
     */
    @Query("SELECT c FROM Calendar c WHERE DATE(c.startDate) = CURRENT_DATE OR " +
            "(c.isAllDay = true AND CURRENT_DATE BETWEEN DATE(c.startDate) AND DATE(c.endDate)) " +
            "ORDER BY c.startDate ASC")
    List<Calendar> findTodayEvents();

    /**
     * 이번 주 일정 조회
     */
    @Query("SELECT c FROM Calendar c WHERE c.startDate >= :weekStart AND c.startDate < :weekEnd ORDER BY c.startDate ASC")
    List<Calendar> findThisWeekEvents(@Param("weekStart") LocalDateTime weekStart, @Param("weekEnd") LocalDateTime weekEnd);
}
