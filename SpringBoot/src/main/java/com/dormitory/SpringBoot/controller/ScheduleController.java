package com.dormitory.SpringBoot.controller;

import com.dormitory.SpringBoot.domain.Schedule;
import com.dormitory.SpringBoot.dto.ApiResponse; // ApiResponse DTO 임포트
import com.dormitory.SpringBoot.services.ScheduleService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize; // ✅ 권한 설정 임포트
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/schedules")
@Tag(name = "Schedule", description = "학사 일정 관리 API")
@CrossOrigin(origins = "*") // CORS 허용
public class ScheduleController {

    @Autowired
    private ScheduleService scheduleService;

    /**
     * 모든 일정 조회 (사용자, 관리자 공통)
     */
    @GetMapping
    @Operation(summary = "모든 학사 일정 조회", description = "모든 사용자가 학사 일정을 조회합니다.")
    public ResponseEntity<ApiResponse<List<Schedule>>> getAllSchedules() {
        List<Schedule> schedules = scheduleService.getAllSchedules();
        return ResponseEntity.ok(ApiResponse.success("일정 조회 성공", schedules));
    }

    /**
     * 새 일정 생성 (관리자 전용)
     */
    @PostMapping
    @PreAuthorize("hasRole('ADMIN')") // ✅ 관리자만 생성 가능
    @Operation(summary = "새 일정 생성 (관리자)", description = "관리자가 새 학사 일정을 생성합니다.")
    public ResponseEntity<ApiResponse<Schedule>> createSchedule(@RequestBody Schedule schedule) {
        try {
            Schedule newSchedule = scheduleService.createSchedule(schedule);
            return ResponseEntity.status(HttpStatus.CREATED)
                    .body(ApiResponse.success("일정이 성공적으로 생성되었습니다.", newSchedule));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.internalServerError("일정 생성 중 오류 발생: " + e.getMessage()));
        }
    }

    /**
     * 일정 수정 (관리자 전용)
     */
    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')") // ✅ 관리자만 수정 가능
    @Operation(summary = "일정 수정 (관리자)", description = "관리자가 기존 학사 일정을 수정합니다.")
    public ResponseEntity<ApiResponse<Schedule>> updateSchedule(@PathVariable Long id, @RequestBody Schedule scheduleDetails) {
        try {
            Schedule updatedSchedule = scheduleService.updateSchedule(id, scheduleDetails);
            return ResponseEntity.ok(ApiResponse.success("일정이 성공적으로 수정되었습니다.", updatedSchedule));
        } catch (RuntimeException e) {
            // Service에서 ID를 못 찾으면 RuntimeException 발생
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.notFound(e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.internalServerError("일정 수정 중 오류 발생: " + e.getMessage()));
        }
    }

    /**
     * 일정 삭제 (관리자 전용)
     */
    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')") // ✅ 관리자만 삭제 가능
    @Operation(summary = "일정 삭제 (관리자)", description = "관리자가 학사 일정을 삭제합니다.")
    public ResponseEntity<ApiResponse<?>> deleteSchedule(@PathVariable Long id) {
        try {
            scheduleService.deleteSchedule(id);
            return ResponseEntity.ok(ApiResponse.success("일정이 성공적으로 삭제되었습니다."));
        } catch (RuntimeException e) {
            // Service에서 ID를 못 찾으면 RuntimeException 발생
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.notFound(e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.internalServerError("일정 삭제 중 오류 발생: " + e.getMessage()));
        }
    }
}