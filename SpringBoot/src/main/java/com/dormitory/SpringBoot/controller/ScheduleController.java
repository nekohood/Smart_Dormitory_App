package com.dormitory.SpringBoot.controller;

import com.dormitory.SpringBoot.domain.Schedule;
import com.dormitory.SpringBoot.dto.ApiResponse;
import com.dormitory.SpringBoot.services.ScheduleService;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/schedule")
@RequiredArgsConstructor
public class ScheduleController {

    private final ScheduleService scheduleService;

    // 모든 일정 조회 (GET /api/schedule)
    @GetMapping
    public ResponseEntity<ApiResponse<List<Schedule>>> getAllSchedules() {
        List<Schedule> schedules = scheduleService.getAllSchedules();
        return ResponseEntity.ok(new ApiResponse<>(true, "모든 일정 조회 성공", schedules));
    }

    // 다가오는 일정 조회 (GET /api/schedule/upcoming)
    @GetMapping("/upcoming")
    public ResponseEntity<ApiResponse<List<Schedule>>> getUpcomingSchedules() {
        List<Schedule> schedules = scheduleService.getUpcomingSchedules();
        return ResponseEntity.ok(new ApiResponse<>(true, "다가오는 일정 조회 성공", schedules));
    }

    // 일정 생성 (POST /api/schedule) - 관리자
    @PostMapping
    public ResponseEntity<ApiResponse<Schedule>> createSchedule(@RequestBody ScheduleRequest request) {
        Schedule newSchedule = scheduleService.createSchedule(request.getTitle(), request.getEventDate());
        return ResponseEntity.ok(new ApiResponse<>(true, "일정 생성 성공", newSchedule));
    }

    // 일정 수정 (PUT /api/schedule/{id}) - 관리자
    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<Schedule>> updateSchedule(@PathVariable Long id, @RequestBody ScheduleRequest request) {
        return scheduleService.updateSchedule(id, request.getTitle(), request.getEventDate())
                .map(schedule -> ResponseEntity.ok(new ApiResponse<>(true, "일정 수정 성공", schedule)))
                .orElse(ResponseEntity.badRequest().body(new ApiResponse<>(false, "일정을 찾을 수 없습니다.", null)));
    }

    // 일정 삭제 (DELETE /api/schedule/{id}) - 관리자
    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteSchedule(@PathVariable Long id) {
        try {
            scheduleService.deleteSchedule(id);
            return ResponseEntity.ok(new ApiResponse<>(true, "일정 삭제 성공", null));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(new ApiResponse<>(false, "일정 삭제 실패", null));
        }
    }

    // 요청 DTO
    @Data
    static class ScheduleRequest {
        private String title;
        @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
        private LocalDate eventDate;
    }
}