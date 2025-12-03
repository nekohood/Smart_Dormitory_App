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
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * 점호 관련 API 컨트롤러 - 상세 조회 및 반려 기능 추가
 */
@RestController
@RequestMapping("/api/inspections")
@Tag(name = "Inspection", description = "점호 관리 API")
@CrossOrigin(origins = "*")
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
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<?>> getAllInspections() {
        try {
            List<InspectionRequest.AdminResponse> inspections = inspectionService.getAllInspections();

            Map<String, Object> data = new HashMap<>();
            data.put("inspections", inspections);
            data.put("count", inspections.size());

            return ResponseEntity.ok(ApiResponse.success("전체 점호 기록 조회 성공", data));

        } catch (Exception e) {
            logger.error("전체 점호 기록 조회 중 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.internalServerError(e.getMessage()));
        }
    }

    /**
     * ✅ 신규 추가: 관리자용 - 점호 상세 조회
     */
    @GetMapping("/admin/{inspectionId}")
    @Operation(summary = "점호 상세 조회", description = "관리자가 특정 점호 기록의 상세 정보를 조회합니다.")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<?>> getInspectionDetail(
            @Parameter(description = "점호 기록 ID", required = true)
            @PathVariable Long inspectionId) {
        try {
            logger.info("점호 상세 조회 요청 - ID: {}", inspectionId);

            InspectionRequest.AdminResponse inspection = inspectionService.getInspectionById(inspectionId);

            return ResponseEntity.ok(ApiResponse.success("점호 상세 조회 성공", inspection));

        } catch (RuntimeException e) {
            logger.warn("점호 상세 조회 실패 - ID: {}, 사유: {}", inspectionId, e.getMessage());
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.notFound(e.getMessage()));
        } catch (Exception e) {
            logger.error("점호 상세 조회 중 오류 발생 - ID: {}", inspectionId, e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.internalServerError(e.getMessage()));
        }
    }

    /**
     * 관리자용 - 특정 날짜 점호 기록 조회
     */
    @GetMapping("/admin/date/{date}")
    @Operation(summary = "날짜별 점호 기록 조회", description = "관리자가 특정 날짜의 점호 기록을 조회합니다.")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<?>> getInspectionsByDate(
            @Parameter(description = "조회할 날짜 (yyyy-MM-dd)", required = true)
            @PathVariable String date) {
        try {
            List<InspectionRequest.AdminResponse> inspections = inspectionService.getInspectionsByDate(date);

            Map<String, Object> data = new HashMap<>();
            data.put("inspections", inspections);
            data.put("count", inspections.size());

            return ResponseEntity.ok(ApiResponse.success("날짜별 점호 기록 조회 성공", data));

        } catch (Exception e) {
            logger.error("날짜별 점호 기록 조회 중 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.internalServerError(e.getMessage()));
        }
    }

    /**
     * 점호 통계 조회
     */
    @GetMapping("/statistics")
    @Operation(summary = "점호 통계 조회", description = "전체 또는 특정 날짜의 점호 통계를 조회합니다.")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<?>> getInspectionStatistics(
            @Parameter(description = "조회할 날짜 (yyyy-MM-dd), 없으면 전체 통계")
            @RequestParam(required = false) String date) {
        try {
            InspectionRequest.Statistics statistics;

            if (date != null && !date.isEmpty()) {
                statistics = inspectionService.getStatisticsByDate(date);
            } else {
                statistics = inspectionService.getTotalStatistics();
            }

            return ResponseEntity.ok(ApiResponse.success("통계 조회 성공", statistics));

        } catch (Exception e) {
            logger.error("점호 통계 조회 중 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.internalServerError(e.getMessage()));
        }
    }

    /**
     * ✅ 수정: 관리자용 - 점호 기록 삭제 (void 반환 대응)
     */
    @DeleteMapping("/admin/{inspectionId}")
    @Operation(summary = "점호 기록 삭제", description = "관리자가 특정 점호 기록을 삭제합니다.")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<?>> deleteInspection(
            @Parameter(description = "삭제할 점호 기록 ID", required = true)
            @PathVariable Long inspectionId) {
        try {
            // ✅ void 반환이므로 예외가 발생하지 않으면 성공
            inspectionService.deleteInspection(inspectionId);

            return ResponseEntity.ok(ApiResponse.success("점호 기록이 성공적으로 삭제되었습니다."));

        } catch (RuntimeException e) {
            // Service에서 던진 RuntimeException (데이터 없음 등)
            logger.warn("점호 기록 삭제 실패: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.notFound(e.getMessage()));

        } catch (Exception e) {
            logger.error("점호 기록 삭제 중 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.internalServerError(e.getMessage()));
        }
    }

    /**
     * ✅ 신규 추가: 관리자용 - 점호 반려 (반려 사유와 함께 삭제)
     */
    @PostMapping("/admin/{inspectionId}/reject")
    @Operation(summary = "점호 반려", description = "관리자가 점호를 반려 처리하고 삭제합니다. 반려 사유가 사용자에게 전달됩니다.")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<?>> rejectInspection(
            @Parameter(description = "반려할 점호 기록 ID", required = true)
            @PathVariable Long inspectionId,
            @RequestBody @Valid InspectionRequest.RejectRequest rejectRequest) {
        try {
            logger.info("점호 반려 요청 - ID: {}, 사유: {}", inspectionId, rejectRequest.getRejectReason());

            inspectionService.rejectInspection(inspectionId, rejectRequest.getRejectReason());

            Map<String, Object> data = new HashMap<>();
            data.put("inspectionId", inspectionId);
            data.put("rejectReason", rejectRequest.getRejectReason());
            data.put("rejected", true);

            return ResponseEntity.ok(ApiResponse.success("점호가 성공적으로 반려되었습니다.", data));

        } catch (RuntimeException e) {
            logger.warn("점호 반려 실패 - ID: {}, 사유: {}", inspectionId, e.getMessage());
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.notFound(e.getMessage()));

        } catch (Exception e) {
            logger.error("점호 반려 중 오류 발생 - ID: {}", inspectionId, e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.internalServerError(e.getMessage()));
        }
    }

    /**
     * 관리자용 - 점호 기록 수정
     */
    @PutMapping("/admin/{inspectionId}")
    @Operation(summary = "점호 기록 수정", description = "관리자가 점호 기록을 수정합니다.")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<?>> updateInspection(
            @Parameter(description = "수정할 점호 기록 ID", required = true)
            @PathVariable Long inspectionId,
            @RequestBody @Valid InspectionRequest.UpdateRequest updateRequest) {
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

            return ResponseEntity.ok(ApiResponse.success("점호 기록이 성공적으로 수정되었습니다.", updatedInspection));

        } catch (RuntimeException e) {
            logger.warn("점호 기록 수정 실패: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.notFound(e.getMessage()));
        } catch (Exception e) {
            logger.error("점호 기록 수정 중 예기치 않은 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.internalServerError(e.getMessage()));
        }
    }

    /**
     * 재검 점호 제출
     */
    @PostMapping("/resubmit")
    @Operation(summary = "재검 점호 제출", description = "실패한 점호에 대해 재검 점호를 제출합니다.")
    public ResponseEntity<ApiResponse<InspectionRequest.Response>> resubmitInspection(
            @AuthenticationPrincipal String userId,
            @Parameter(description = "방 번호", required = true) @RequestParam String roomNumber,
            @Parameter(description = "업로드할 방 사진", required = true) @RequestParam("image") MultipartFile imageFile) {
        try {
            InspectionRequest.Response result = inspectionService.submitReInspection(userId, roomNumber, imageFile);
            return ResponseEntity.ok(ApiResponse.success("재검 점호가 성공적으로 제출되었습니다.", result));
        } catch (Exception e) {
            logger.error("재검 점호 제출 중 오류 발생 - 사용자: {}", userId, e);
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(ApiResponse.error(e.getMessage()));
        }
    }

    /**
     * ✅ 기숙사별 점호 현황 테이블 데이터 조회
     * 층/호실 매트릭스 형태로 점호 상태 반환
     */
    @GetMapping("/admin/building-status/{building}")
    @Operation(summary = "기숙사별 점호 현황 조회", description = "특정 기숙사의 층/호실별 점호 현황을 테이블 형태로 조회합니다.")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<?>> getBuildingInspectionStatus(
            @Parameter(description = "기숙사 동 이름", required = true)
            @PathVariable String building,
            @Parameter(description = "조회할 날짜 (yyyy-MM-dd), 없으면 오늘")
            @RequestParam(required = false) String date) {
        try {
            logger.info("기숙사별 점호 현황 조회 - 동: {}, 날짜: {}", building, date);

            Map<String, Object> statusData = inspectionService.getBuildingInspectionStatus(building, date);

            return ResponseEntity.ok(ApiResponse.success("기숙사별 점호 현황 조회 성공", statusData));

        } catch (Exception e) {
            logger.error("기숙사별 점호 현황 조회 중 오류 발생 - 동: {}", building, e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.internalServerError(e.getMessage()));
        }
    }

    /**
     * ✅ 전체 기숙사 목록 조회
     * 등록된 사용자들의 기숙사 동 목록을 반환
     */
    @GetMapping("/admin/buildings")
    @Operation(summary = "기숙사 동 목록 조회", description = "등록된 모든 기숙사 동 목록을 조회합니다.")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<?>> getBuildingList() {
        try {
            logger.info("기숙사 동 목록 조회");

            List<String> buildings = inspectionService.getAllBuildings();

            Map<String, Object> data = new HashMap<>();
            data.put("buildings", buildings);
            data.put("count", buildings.size());

            return ResponseEntity.ok(ApiResponse.success("기숙사 동 목록 조회 성공", data));

        } catch (Exception e) {
            logger.error("기숙사 동 목록 조회 중 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.internalServerError(e.getMessage()));
        }
    }

    /**
     * ✅ 특정 호실의 점호 상세 정보 조회
     */
    @GetMapping("/admin/room-status/{building}/{floor}/{room}")
    @Operation(summary = "호실별 점호 상세 조회", description = "특정 호실의 점호 상세 정보를 조회합니다.")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<?>> getRoomInspectionDetail(
            @Parameter(description = "기숙사 동", required = true) @PathVariable String building,
            @Parameter(description = "층수", required = true) @PathVariable int floor,
            @Parameter(description = "호실 번호", required = true) @PathVariable int room,
            @Parameter(description = "조회할 날짜 (yyyy-MM-dd), 없으면 오늘") @RequestParam(required = false) String date) {
        try {
            // 방 번호 형식: 층수 + 호실 (예: 2층 1호실 = 201)
            String roomNumber = String.valueOf(floor * 100 + room);
            logger.info("호실별 점호 상세 조회 - 동: {}, 방번호: {}, 날짜: {}", building, roomNumber, date);

            Map<String, Object> roomDetail = inspectionService.getRoomInspectionDetail(building, roomNumber, date);

            return ResponseEntity.ok(ApiResponse.success("호실별 점호 상세 조회 성공", roomDetail));

        } catch (Exception e) {
            logger.error("호실별 점호 상세 조회 중 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.internalServerError(e.getMessage()));
        }
    }
}