package com.dormitory.SpringBoot.services;

import com.dormitory.SpringBoot.domain.Schedule;
import com.dormitory.SpringBoot.repository.ScheduleRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ScheduleService {

    private final ScheduleRepository scheduleRepository;

    // 모든 일정 조회 (캘린더용)
    public List<Schedule> getAllSchedules() {
        return scheduleRepository.findAllByOrderByEventDateAsc();
    }

    // 다가오는 일정 조회 (D-Day용)
    public List<Schedule> getUpcomingSchedules() {
        return scheduleRepository.findAllByEventDateGreaterThanEqualOrderByEventDateAsc(LocalDate.now());
    }

    // 일정 생성 (관리자)
    @Transactional
    public Schedule createSchedule(String title, LocalDate eventDate) {
        Schedule schedule = new Schedule();
        schedule.setTitle(title);
        schedule.setEventDate(eventDate);
        return scheduleRepository.save(schedule);
    }

    // 일정 수정 (관리자)
    @Transactional
    public Optional<Schedule> updateSchedule(Long id, String title, LocalDate eventDate) {
        return scheduleRepository.findById(id).map(schedule -> {
            schedule.setTitle(title);
            schedule.setEventDate(eventDate);
            return schedule;
        });
    }

    // 일정 삭제 (관리자)
    @Transactional
    public void deleteSchedule(Long id) {
        scheduleRepository.deleteById(id);
    }
}