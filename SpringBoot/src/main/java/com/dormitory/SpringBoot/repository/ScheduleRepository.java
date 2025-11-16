package com.dormitory.SpringBoot.repository;

import com.dormitory.SpringBoot.domain.Schedule;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List; // ✅ 1. List 임포트 추가

@Repository
public interface ScheduleRepository extends JpaRepository<Schedule, Long> {

    // ✅ 2. 시작 날짜(startDate) 기준으로 오름차순 정렬하는 함수 추가
    /**
     * 모든 일정을 시작 날짜(startDate) 오름차순으로 정렬하여 조회합니다.
     */
    List<Schedule> findAllByOrderByStartDateAsc();
}