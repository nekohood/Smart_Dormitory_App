package com.dormitory.SpringBoot.repository;

import com.dormitory.SpringBoot.domain.Schedule;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface ScheduleRepository extends JpaRepository<Schedule, Long> {

    // 날짜 오름차순으로 모든 일정 찾기
    List<Schedule> findAllByOrderByEventDateAsc();

    // 오늘 이후의 일정을 날짜순으로 정렬하여 찾기 (D-Day용)
    List<Schedule> findAllByEventDateGreaterThanEqualOrderByEventDateAsc(LocalDate date);
}