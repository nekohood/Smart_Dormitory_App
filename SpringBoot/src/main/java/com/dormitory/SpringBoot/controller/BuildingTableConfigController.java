package com.dormitory.SpringBoot.controller;

import com.dormitory.SpringBoot.domain.BuildingTableConfig;
import com.dormitory.SpringBoot.dto.ApiResponse;
import com.dormitory.SpringBoot.services.BuildingTableConfigService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 기숙사 테이블 설정 API (관리자용)
 * - 기숙사별 층/호실 범위 설정
 */
@RestController
@RequestMapping("/api/admin/building-config")
@Tag(name = "Building Table Config", description = "기숙사 테이블 설정 관리 API")
@PreAuthorize("hasRole('ADMIN')")
public class BuildingTableConfigController {

    private static final Logger logger = LoggerFactory.getLogger(BuildingTableConfigController.class);

    @Autowired
    private BuildingTableConfigService configService;

    /**
     * 전체 테이블 설정 조회
     */
    @GetMapping
    @Operation(summary = "전체 테이블 설정 조회", description = "모든 기숙사의 테이블 설정을 조회합니다.")
    public ResponseEntity<ApiResponse<?>> getAllConfigs() {
        try {
            logger.info("전체 테이블 설정 조회 요청");
            
            List<BuildingTableConfig> configs = configService.getAllConfigs();
            List<Map<String, Object>> response = configs.stream()
                    .map(this::convertToResponse)
                    .collect(Collectors.toList());

            Map<String, Object> data = new HashMap<>();
            data.put("configs", response);
            data.put("count", response.size());

            return ResponseEntity.ok(ApiResponse.success("테이블 설정 조회 성공", data));
            
        } catch (Exception e) {
            logger.error("테이블 설정 조회 실패", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error("테이블 설정 조회 실패: " + e.getMessage()));
        }
    }

    /**
     * 특정 기숙사의 테이블 설정 조회
     */
    @GetMapping("/{buildingName}")
    @Operation(summary = "기숙사별 테이블 설정 조회", description = "특정 기숙사의 테이블 설정을 조회합니다.")
    public ResponseEntity<ApiResponse<?>> getConfigByBuilding(
            @Parameter(description = "기숙사 동 이름", required = true)
            @PathVariable String buildingName) {
        try {
            logger.info("기숙사별 테이블 설정 조회 - 동: {}", buildingName);
            
            BuildingTableConfig config = configService.getConfigOrDefault(buildingName);
            
            return ResponseEntity.ok(ApiResponse.success("테이블 설정 조회 성공", convertToResponse(config)));
            
        } catch (Exception e) {
            logger.error("테이블 설정 조회 실패 - 동: {}", buildingName, e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error("테이블 설정 조회 실패: " + e.getMessage()));
        }
    }

    /**
     * 테이블 설정 생성
     */
    @PostMapping
    @Operation(summary = "테이블 설정 생성", description = "새로운 기숙사의 테이블 설정을 생성합니다.")
    public ResponseEntity<ApiResponse<?>> createConfig(@RequestBody Map<String, Object> request) {
        try {
            logger.info("테이블 설정 생성 요청: {}", request);
            
            String buildingName = (String) request.get("buildingName");
            Integer startFloor = (Integer) request.get("startFloor");
            Integer endFloor = (Integer) request.get("endFloor");
            Integer startRoom = (Integer) request.get("startRoom");
            Integer endRoom = (Integer) request.get("endRoom");
            String roomNumberFormat = (String) request.get("roomNumberFormat");
            String description = (String) request.get("description");

            if (buildingName == null || buildingName.trim().isEmpty()) {
                return ResponseEntity.badRequest()
                        .body(ApiResponse.error("기숙사 동 이름은 필수입니다."));
            }

            Authentication auth = SecurityContextHolder.getContext().getAuthentication();
            String adminId = auth != null ? auth.getName() : "SYSTEM";

            BuildingTableConfig config = configService.createConfig(
                    buildingName,
                    startFloor != null ? startFloor : 2,
                    endFloor != null ? endFloor : 13,
                    startRoom != null ? startRoom : 1,
                    endRoom != null ? endRoom : 20,
                    roomNumberFormat,
                    description,
                    adminId
            );

            return ResponseEntity.ok(ApiResponse.success("테이블 설정이 생성되었습니다.", convertToResponse(config)));
            
        } catch (RuntimeException e) {
            logger.warn("테이블 설정 생성 실패: {}", e.getMessage());
            return ResponseEntity.badRequest()
                    .body(ApiResponse.error(e.getMessage()));
        } catch (Exception e) {
            logger.error("테이블 설정 생성 중 오류", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error("테이블 설정 생성 실패: " + e.getMessage()));
        }
    }

    /**
     * 테이블 설정 수정
     */
    @PutMapping("/{id}")
    @Operation(summary = "테이블 설정 수정", description = "기숙사의 테이블 설정을 수정합니다.")
    public ResponseEntity<ApiResponse<?>> updateConfig(
            @Parameter(description = "설정 ID", required = true) @PathVariable Long id,
            @RequestBody Map<String, Object> request) {
        try {
            logger.info("테이블 설정 수정 요청 - ID: {}", id);
            
            String buildingName = (String) request.get("buildingName");
            Integer startFloor = request.get("startFloor") != null ? ((Number) request.get("startFloor")).intValue() : null;
            Integer endFloor = request.get("endFloor") != null ? ((Number) request.get("endFloor")).intValue() : null;
            Integer startRoom = request.get("startRoom") != null ? ((Number) request.get("startRoom")).intValue() : null;
            Integer endRoom = request.get("endRoom") != null ? ((Number) request.get("endRoom")).intValue() : null;
            String roomNumberFormat = (String) request.get("roomNumberFormat");
            String description = (String) request.get("description");

            Authentication auth = SecurityContextHolder.getContext().getAuthentication();
            String adminId = auth != null ? auth.getName() : "SYSTEM";

            BuildingTableConfig config = configService.updateConfig(
                    id, buildingName, startFloor, endFloor, startRoom, endRoom,
                    roomNumberFormat, description, adminId
            );

            return ResponseEntity.ok(ApiResponse.success("테이블 설정이 수정되었습니다.", convertToResponse(config)));
            
        } catch (RuntimeException e) {
            logger.warn("테이블 설정 수정 실패: {}", e.getMessage());
            return ResponseEntity.badRequest()
                    .body(ApiResponse.error(e.getMessage()));
        } catch (Exception e) {
            logger.error("테이블 설정 수정 중 오류", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error("테이블 설정 수정 실패: " + e.getMessage()));
        }
    }

    /**
     * 테이블 설정 삭제
     */
    @DeleteMapping("/{id}")
    @Operation(summary = "테이블 설정 삭제", description = "기숙사의 테이블 설정을 삭제합니다.")
    public ResponseEntity<ApiResponse<?>> deleteConfig(
            @Parameter(description = "설정 ID", required = true) @PathVariable Long id) {
        try {
            logger.info("테이블 설정 삭제 요청 - ID: {}", id);
            
            configService.deleteConfig(id);

            return ResponseEntity.ok(ApiResponse.success("테이블 설정이 삭제되었습니다.", null));
            
        } catch (RuntimeException e) {
            logger.warn("테이블 설정 삭제 실패: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.error(e.getMessage()));
        } catch (Exception e) {
            logger.error("테이블 설정 삭제 중 오류", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error("테이블 설정 삭제 실패: " + e.getMessage()));
        }
    }

    /**
     * 테이블 설정 활성화/비활성화 토글
     */
    @PatchMapping("/{id}/toggle")
    @Operation(summary = "테이블 설정 활성화 토글", description = "테이블 설정의 활성화 상태를 전환합니다.")
    public ResponseEntity<ApiResponse<?>> toggleConfig(
            @Parameter(description = "설정 ID", required = true) @PathVariable Long id) {
        try {
            logger.info("테이블 설정 토글 요청 - ID: {}", id);
            
            BuildingTableConfig config = configService.toggleActive(id);
            String message = config.getIsActive() ? "테이블 설정이 활성화되었습니다." : "테이블 설정이 비활성화되었습니다.";

            return ResponseEntity.ok(ApiResponse.success(message, convertToResponse(config)));
            
        } catch (RuntimeException e) {
            logger.warn("테이블 설정 토글 실패: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.error(e.getMessage()));
        } catch (Exception e) {
            logger.error("테이블 설정 토글 중 오류", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error("테이블 설정 토글 실패: " + e.getMessage()));
        }
    }

    /**
     * 엔티티를 응답 Map으로 변환
     */
    private Map<String, Object> convertToResponse(BuildingTableConfig config) {
        Map<String, Object> response = new HashMap<>();
        response.put("id", config.getId());
        response.put("buildingName", config.getBuildingName());
        response.put("startFloor", config.getStartFloor());
        response.put("endFloor", config.getEndFloor());
        response.put("startRoom", config.getStartRoom());
        response.put("endRoom", config.getEndRoom());
        response.put("roomNumberFormat", config.getRoomNumberFormat());
        response.put("description", config.getDescription());
        response.put("isActive", config.getIsActive());
        response.put("floorCount", config.getFloorCount());
        response.put("roomCount", config.getRoomCount());
        response.put("totalRoomCount", config.getTotalRoomCount());
        response.put("createdBy", config.getCreatedBy());
        response.put("createdAt", config.getCreatedAt());
        response.put("updatedAt", config.getUpdatedAt());
        return response;
    }
}
