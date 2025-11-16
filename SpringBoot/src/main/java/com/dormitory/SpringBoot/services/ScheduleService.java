package com.dormitory.SpringBoot.services;

import com.dormitory.SpringBoot.domain.Schedule;
import com.dormitory.SpringBoot.repository.ScheduleRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Service
@Transactional
public class ScheduleService {

    @Autowired
    private ScheduleRepository scheduleRepository;

    /**
     * 모든 일정 조회
     */
    @Transactional(readOnly = true)
    public List<Schedule> getAllSchedules() {
        // 날짜순으로 정렬
        return scheduleRepository.findAllByOrderByStartDateAsc();
    }

    /**
     * 특정 ID로 일정 조회
     */
    @Transactional(readOnly = true)
    public Optional<Schedule> getScheduleById(Long id) {
        return scheduleRepository.findById(id);
    }

    /**
     * 새 일정 생성 (관리자)
     */
    public Schedule createSchedule(Schedule schedule) {
        // 클라이언트에서 보낸 ID는 무시하고 새로 생성
        schedule.setId(null);
        return scheduleRepository.save(schedule);
    }

    /**
     * 일정 수정 (관리자)
     */
    public Schedule updateSchedule(Long id, Schedule scheduleDetails) {
        // 1. 기존 일정 조회
        Schedule existingSchedule = scheduleRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("해당 ID의 일정을 찾을 수 없습니다: " + id));

        // 2. 받은 정보로 필드 업데이트
        existingSchedule.setTitle(scheduleDetails.getTitle());
        existingSchedule.setContent(scheduleDetails.getContent());
        existingSchedule.setStartDate(scheduleDetails.getStartDate());
        existingSchedule.setEndDate(scheduleDetails.getEndDate());
        existingSchedule.setCategory(scheduleDetails.getCategory());
        // createdAt, updatedAt 등은 @UpdateTimestamp 등으로 자동 관리하는 것이 좋음

        // 3. 변경된 내용 저장
        return scheduleRepository.save(existingSchedule);
    }

    /**
     * 일정 삭제 (관리자)
     */
    public void deleteSchedule(Long id) {
        // 1. 삭제할 일정 조회
        Schedule schedule = scheduleRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("해당 ID의 일정을 찾을 수 없습니다: " + id));

        // 2. 일정 삭제
        scheduleRepository.delete(schedule);
    }
}