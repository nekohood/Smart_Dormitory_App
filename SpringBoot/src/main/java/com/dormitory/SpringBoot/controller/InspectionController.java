package com.dormitory.SpringBoot.controller;

import com.dormitory.SpringBoot.dto.ApiResponse;
import com.dormitory.SpringBoot.dto.InspectionRequest;
import com.dormitory.SpringBoot.services.InspectionService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * 점호 관련 API 컨트롤러
 */
@RestController
@RequestMapping("/api/inspections")
@Tag(name = "Inspection", description = "점호 관리 API")
public class InspectionController {

    private static final Logger logger = LoggerFactory.getLogger(InspectionController.class);

    @Autowired
    private InspectionService inspectionService;

    @PostMapping("/submit")
    @Operation(summary = "점호 제출", description = "사용자가 방 사진을 업로드하여 점호를 제출합니다.")
    public ResponseEntity<ApiResponse<InspectionRequest.Response>> submitInspection(
            @AuthenticationPrincipal String userId,
            @Parameter(description = "방 번호", required = true) @RequestParam String roomNumber,
            @Parameter(description = "업로드할 방 사진", required = true) @RequestParam("image") MultipartFile imageFile) {
        try {
            InspectionRequest.Response result = inspectionService.submitInspection(userId, roomNumber, imageFile);
            return ResponseEntity.ok(ApiResponse.success("점호가 성공적으로 제출되었습니다.", result));
        } catch (Exception e) {
            logger.error("점호 제출 중 오류 발생 - 사용자: {}", userId, e);
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(ApiResponse.error(e.getMessage()));
        }
    }

    @GetMapping("/my")
    @Operation(summary = "내 점호 기록 조회", description = "로그인한 사용자의 점호 기록을 조회합니다.")
    public ResponseEntity<ApiResponse<List<InspectionRequest.AdminResponse>>> getMyInspections(@AuthenticationPrincipal String userId) {
        try {
            List<InspectionRequest.AdminResponse> inspections = inspectionService.getUserInspections(userId);
            return ResponseEntity.ok(ApiResponse.success("점호 기록 조회 성공", inspections));
        } catch (Exception e) {
            logger.error("사용자 점호 기록 조회 중 오류 발생 - 사용자: {}", userId, e);
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(ApiResponse.error(e.getMessage()));
        }
    }

    @GetMapping("/today")
    @Operation(summary = "오늘 점호 상태 확인", description = "사용자의 오늘 점호 완료 상태를 확인합니다.")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getTodayInspection(@AuthenticationPrincipal String userId) {
        try {
            Optional<InspectionRequest.Response> todayInspection = inspectionService.getTodayInspection(userId);
            Map<String, Object> data = new HashMap<>();
            data.put("completed", todayInspection.isPresent());
            todayInspection.ifPresent(inspection -> data.put("inspection", inspection));

            String message = todayInspection.isPresent() ? "오늘 점호가 완료되었습니다." : "오늘 점호가 아직 완료되지 않았습니다.";
            return ResponseEntity.ok(ApiResponse.success(message, data));
        } catch (Exception e) {
            logger.error("오늘 점호 상태 확인 중 오류 발생 - 사용자: {}", userId, e);
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(ApiResponse.error("점호 상태 확인 중 오류가 발생했습니다."));
        }
    }

    /**
     * 관리자용 - 모든 점호 기록 조회
     */
    @GetMapping("/admin/all")
    @Operation(summary = "모든 점호 기록 조회", description = "관리자가 모든 점호 기록을 조회합니다.")
    public ResponseEntity<?> getAllInspections() {
        try {
            List<InspectionRequest.AdminResponse> inspections = inspectionService.getAllInspections();

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("inspections", inspections);
            response.put("count", inspections.size());

            return ResponseEntity.ok(response);

        } catch (Exception e) {
            logger.error("전체 점호 기록 조회 중 오류 발생", e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("error", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(errorResponse);
        }
    }

    /**
     * 관리자용 - 특정 날짜 점호 기록 조회
     */
    @GetMapping("/admin/date/{date}")
    @Operation(summary = "날짜별 점호 기록 조회", description = "관리자가 특정 날짜의 점호 기록을 조회합니다.")
    public ResponseEntity<?> getInspectionsByDate(
            @Parameter(description = "조회할 날짜 (yyyy-MM-dd)", required = true)
            @PathVariable String date) {
        try {
            List<InspectionRequest.AdminResponse> inspections = inspectionService.getInspectionsByDate(date);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("inspections", inspections);
            response.put("count", inspections.size());

            return ResponseEntity.ok(response);

        } catch (Exception e) {
            logger.error("날짜별 점호 기록 조회 중 오류 발생", e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("error", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(errorResponse);
        }
    }

    /**
     * 점호 통계 조회 - 수정된 메서드
     */
    @GetMapping("/statistics")
    @Operation(summary = "점호 통계 조회", description = "전체 또는 특정 날짜의 점호 통계를 조회합니다.")
    public ResponseEntity<?> getInspectionStatistics(
            @Parameter(description = "조회할 날짜 (yyyy-MM-dd), 없으면 전체 통계")
            @RequestParam(required = false) String date) {
        try {
            InspectionRequest.Statistics statistics;

            if (date != null && !date.isEmpty()) {
                statistics = inspectionService.getStatisticsByDate(date);
            } else {
                statistics = inspectionService.getTotalStatistics();
            }

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("statistics", statistics);

            return ResponseEntity.ok(response);

        } catch (Exception e) {
            logger.error("점호 통계 조회 중 오류 발생", e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("error", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(errorResponse);
        }
    }

    /**
     * 관리자용 - 점호 기록 삭제
     */
    @DeleteMapping("/admin/{inspectionId}")
    @Operation(summary = "점호 기록 삭제", description = "관리자가 특정 점호 기록을 삭제합니다.")
    public ResponseEntity<?> deleteInspection(
            @Parameter(description = "삭제할 점호 기록 ID", required = true)
            @PathVariable Long inspectionId) {
        try {
            boolean success = inspectionService.deleteInspection(inspectionId);

            Map<String, Object> response = new HashMap<>();
            response.put("success", success);

            if (success) {
                response.put("message", "점호 기록이 성공적으로 삭제되었습니다.");
            } else {
                response.put("error", "점호 기록 삭제에 실패했습니다.");
            }

            return ResponseEntity.ok(response);

        } catch (Exception e) {
            logger.error("점호 기록 삭제 중 오류 발생", e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("error", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(errorResponse);
        }
    }

    /**
     * 관리자용 - 점호 기록 수정 - 수정된 메서드
     */
    @PutMapping("/admin/{inspectionId}")
    @Operation(summary = "점호 기록 수정", description = "관리자가 점호 기록을 수정합니다.")
    public ResponseEntity<?> updateInspection(
            @Parameter(description = "수정할 점호 기록 ID", required = true)
            @PathVariable Long inspectionId,
            @RequestBody InspectionRequest.UpdateRequest updateRequest) {
        try {
            // UpdateRequest를 Map으로 변환
            Map<String, Object> updateData = new HashMap<>();
            if (updateRequest.getScore() != null) {
                updateData.put("score", updateRequest.getScore());
            }
            if (updateRequest.getStatus() != null) {
                updateData.put("status", updateRequest.getStatus());
            }
            if (updateRequest.getGeminiFeedback() != null) {
                updateData.put("geminiFeedback", updateRequest.getGeminiFeedback());
            }
            if (updateRequest.getAdminComment() != null) {
                updateData.put("adminComment", updateRequest.getAdminComment());
            }
            if (updateRequest.getIsReInspection() != null) {
                updateData.put("isReInspection", updateRequest.getIsReInspection());
            }

            InspectionRequest.AdminResponse updatedInspection = inspectionService.updateInspection(inspectionId, updateData);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("inspection", updatedInspection);
            response.put("message", "점호 기록이 성공적으로 수정되었습니다.");

            return ResponseEntity.ok(response);

        } catch (Exception e) {
            logger.error("점호 기록 수정 중 오류 발생", e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("error", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(errorResponse);
        }
    }
}