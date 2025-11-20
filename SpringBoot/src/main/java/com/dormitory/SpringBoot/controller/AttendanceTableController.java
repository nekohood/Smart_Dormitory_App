package com.dormitory.SpringBoot.controller;

import com.dormitory.SpringBoot.dto.ApiResponse;
import com.dormitory.SpringBoot.dto.AttendanceRequest;
import com.dormitory.SpringBoot.services.AttendanceTableService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;

/**
 * 점호 출석 테이블 관리 컨트롤러
 */
@RestController
@RequestMapping("/api/attendance")
@Tag(name = "Attendance Table", description = "점호 출석 테이블 관리 API")
public class AttendanceTableController {

    private static final Logger logger = LoggerFactory.getLogger(AttendanceTableController.class);

    @Autowired
    private AttendanceTableService attendanceTableService;

    /**
     * 출석 테이블 생성 (관리자 전용)
     */
    @PostMapping("/table/create")
    @Operation(summary = "출석 테이블 생성", description = "특정 날짜의 출석 테이블을 생성합니다. (관리자 전용)")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<?>> createAttendanceTable(
            @Parameter(description = "점호 날짜 (yyyy-MM-dd)", required = true)
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        
        try {
            logger.info("출석 테이블 생성 요청 - 날짜: {}", date);
            
            AttendanceRequest.AttendanceTableResponse response = 
                attendanceTableService.createAttendanceTable(date);

            return ResponseEntity.ok(ApiResponse.success("출석 테이블이 생성되었습니다.", response));

        } catch (RuntimeException e) {
            logger.error("출석 테이블 생성 실패 - 날짜: {}, 오류: {}", date, e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(ApiResponse.error(e.getMessage()));
        } catch (Exception e) {
            logger.error("출석 테이블 생성 중 예기치 않은 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(ApiResponse.internalServerError(e.getMessage()));
        }
    }

    /**
     * 출석 테이블 조회 (관리자 전용)
     */
    @GetMapping("/table")
    @Operation(summary = "출석 테이블 조회", description = "특정 날짜의 출석 테이블을 조회합니다. (관리자 전용)")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<?>> getAttendanceTable(
            @Parameter(description = "점호 날짜 (yyyy-MM-dd)", required = true)
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        
        try {
            logger.info("출석 테이블 조회 요청 - 날짜: {}", date);
            
            AttendanceRequest.AttendanceTableResponse response = 
                attendanceTableService.getAttendanceTable(date);

            return ResponseEntity.ok(ApiResponse.success("출석 테이블 조회 성공", response));

        } catch (Exception e) {
            logger.error("출석 테이블 조회 실패 - 날짜: {}, 오류: {}", date, e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(ApiResponse.internalServerError(e.getMessage()));
        }
    }

    /**
     * 오늘 출석 테이블 조회 (관리자 전용)
     */
    @GetMapping("/table/today")
    @Operation(summary = "오늘 출석 테이블 조회", description = "오늘 날짜의 출석 테이블을 조회합니다. (관리자 전용)")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<?>> getTodayAttendanceTable() {
        try {
            LocalDate today = LocalDate.now();
            logger.info("오늘 출석 테이블 조회 요청 - 날짜: {}", today);
            
            AttendanceRequest.AttendanceTableResponse response = 
                attendanceTableService.getAttendanceTable(today);

            return ResponseEntity.ok(ApiResponse.success("오늘 출석 테이블 조회 성공", response));

        } catch (Exception e) {
            logger.error("오늘 출석 테이블 조회 실패: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(ApiResponse.internalServerError(e.getMessage()));
        }
    }

    /**
     * 출석 항목 수정 (관리자 전용)
     */
    @PutMapping("/entry/{entryId}")
    @Operation(summary = "출석 항목 수정", description = "출석 테이블의 특정 항목을 수정합니다. (관리자 전용)")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<?>> updateAttendanceEntry(
            @Parameter(description = "출석 항목 ID", required = true)
            @PathVariable Long entryId,
            @RequestBody AttendanceRequest.UpdateEntryRequest request) {
        
        try {
            logger.info("출석 항목 수정 요청 - ID: {}", entryId);
            
            AttendanceRequest.AttendanceEntryResponse response = 
                attendanceTableService.updateAttendanceEntry(entryId, request);

            return ResponseEntity.ok(ApiResponse.success("출석 항목이 수정되었습니다.", response));

        } catch (RuntimeException e) {
            logger.error("출석 항목 수정 실패 - ID: {}, 오류: {}", entryId, e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(ApiResponse.error(e.getMessage()));
        } catch (Exception e) {
            logger.error("출석 항목 수정 중 예기치 않은 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(ApiResponse.internalServerError(e.getMessage()));
        }
    }

    /**
     * 출석 테이블 삭제 (관리자 전용)
     */
    @DeleteMapping("/table")
    @Operation(summary = "출석 테이블 삭제", description = "특정 날짜의 출석 테이블을 삭제합니다. (관리자 전용)")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<?>> deleteAttendanceTable(
            @Parameter(description = "점호 날짜 (yyyy-MM-dd)", required = true)
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        
        try {
            logger.info("출석 테이블 삭제 요청 - 날짜: {}", date);
            
            attendanceTableService.deleteAttendanceTable(date);

            return ResponseEntity.ok(ApiResponse.success("출석 테이블이 삭제되었습니다.", null));

        } catch (RuntimeException e) {
            logger.error("출석 테이블 삭제 실패 - 날짜: {}, 오류: {}", date, e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(ApiResponse.error(e.getMessage()));
        } catch (Exception e) {
            logger.error("출석 테이블 삭제 중 예기치 않은 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(ApiResponse.internalServerError(e.getMessage()));
        }
    }
}
