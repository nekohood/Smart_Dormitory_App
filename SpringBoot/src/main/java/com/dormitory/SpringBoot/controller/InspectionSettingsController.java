package com.dormitory.SpringBoot.controller;

import com.dormitory.SpringBoot.domain.InspectionSettings;
import com.dormitory.SpringBoot.dto.ApiResponse;
import com.dormitory.SpringBoot.services.InspectionSettingsService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * 점호 설정 관리 API 컨트롤러
 * - 점호 시간 설정
 * - EXIF 검증 설정
 * - GPS 검증 설정
 * - 방 사진 검증 설정
 */
@RestController
@RequestMapping("/api/inspection-settings")
@Tag(name = "Inspection Settings", description = "점호 설정 관리 API")
@CrossOrigin(origins = "*")
public class InspectionSettingsController {

    private static final Logger logger = LoggerFactory.getLogger(InspectionSettingsController.class);

    @Autowired
    private InspectionSettingsService settingsService;

    // ==================== 공개 API (인증 필요, 권한 불필요) ====================

    /**
     * 점호 시간 확인 (모든 사용자)
     */
    @GetMapping("/check-time")
    @Operation(summary = "점호 시간 확인", description = "현재 점호가 가능한 시간인지 확인합니다.")
    public ResponseEntity<ApiResponse<?>> checkInspectionTime() {
        try {
            logger.info("점호 시간 확인 요청");

            InspectionSettingsService.InspectionTimeCheckResult result =
                    settingsService.checkInspectionTimeAllowed();

            Map<String, Object> data = new HashMap<>();
            data.put("allowed", result.isAllowed());
            data.put("message", result.getMessage());

            if (result.getSettings() != null) {
                data.put("startTime", result.getSettings().getStartTime().toString());
                data.put("endTime", result.getSettings().getEndTime().toString());
            }

            // ✅ 다음 점호 날짜 정보 추가
            if (result.getNextInspectionDate() != null) {
                data.put("nextInspectionDate", result.getNextInspectionDate().toString());
                data.put("daysUntilNext", result.getDaysUntilNext());
            }

            return ResponseEntity.ok(ApiResponse.success("점호 시간 확인 성공", data));

        } catch (Exception e) {
            logger.error("점호 시간 확인 중 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error("점호 시간 확인 실패: " + e.getMessage()));
        }
    }

    /**
     * 현재 적용 설정 조회 (모든 사용자)
     */
    @GetMapping("/current")
    @Operation(summary = "현재 적용 설정 조회", description = "현재 적용 중인 점호 설정을 조회합니다.")
    public ResponseEntity<ApiResponse<?>> getCurrentSettings() {
        try {
            logger.info("현재 점호 설정 조회 요청");

            Optional<InspectionSettings> settings = settingsService.getCurrentSettings();

            if (settings.isPresent()) {
                return ResponseEntity.ok(ApiResponse.success("현재 설정 조회 성공", settings.get()));
            } else {
                return ResponseEntity.ok(ApiResponse.success("적용 중인 설정이 없습니다.", null));
            }

        } catch (Exception e) {
            logger.error("현재 설정 조회 중 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error("현재 설정 조회 실패: " + e.getMessage()));
        }
    }

    // ==================== 관리자 전용 API ====================

    /**
     * 전체 설정 조회 (관리자)
     */
    @GetMapping
    @Operation(summary = "전체 설정 조회", description = "모든 점호 설정을 조회합니다.")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<?>> getAllSettings() {
        try {
            logger.info("전체 점호 설정 조회 요청");

            List<InspectionSettings> settings = settingsService.getAllSettings();

            return ResponseEntity.ok(ApiResponse.success("전체 설정 조회 성공", settings));

        } catch (Exception e) {
            logger.error("전체 설정 조회 중 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error("전체 설정 조회 실패: " + e.getMessage()));
        }
    }

    /**
     * 특정 설정 조회 (관리자)
     */
    @GetMapping("/{id}")
    @Operation(summary = "특정 설정 조회", description = "특정 점호 설정을 조회합니다.")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<?>> getSettingsById(
            @Parameter(description = "설정 ID", required = true)
            @PathVariable Long id) {
        try {
            logger.info("점호 설정 조회 요청 - ID: {}", id);

            Optional<InspectionSettings> settings = settingsService.getSettingsById(id);

            if (settings.isPresent()) {
                return ResponseEntity.ok(ApiResponse.success("설정 조회 성공", settings.get()));
            } else {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(ApiResponse.notFound("설정을 찾을 수 없습니다: " + id));
            }

        } catch (Exception e) {
            logger.error("설정 조회 중 오류 발생 - ID: {}", id, e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error("설정 조회 실패: " + e.getMessage()));
        }
    }

    /**
     * 설정 생성 (관리자)
     */
    @PostMapping
    @Operation(summary = "설정 생성", description = "새로운 점호 설정을 생성합니다.")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<?>> createSettings(
            @AuthenticationPrincipal String adminId,
            @RequestBody InspectionSettings settings) {
        try {
            logger.info("점호 설정 생성 요청 - 관리자: {}, 설정명: {}", adminId, settings.getSettingName());

            InspectionSettings created = settingsService.createSettings(settings, adminId);

            return ResponseEntity.status(HttpStatus.CREATED)
                    .body(ApiResponse.success("설정이 성공적으로 생성되었습니다.", created));

        } catch (RuntimeException e) {
            logger.warn("설정 생성 실패: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error(e.getMessage()));
        } catch (Exception e) {
            logger.error("설정 생성 중 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error("설정 생성 실패: " + e.getMessage()));
        }
    }

    /**
     * 설정 수정 (관리자)
     */
    @PutMapping("/{id}")
    @Operation(summary = "설정 수정", description = "기존 점호 설정을 수정합니다.")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<?>> updateSettings(
            @Parameter(description = "설정 ID", required = true)
            @PathVariable Long id,
            @RequestBody InspectionSettings settings) {
        try {
            logger.info("점호 설정 수정 요청 - ID: {}", id);

            InspectionSettings updated = settingsService.updateSettings(id, settings);

            return ResponseEntity.ok(ApiResponse.success("설정이 성공적으로 수정되었습니다.", updated));

        } catch (RuntimeException e) {
            logger.warn("설정 수정 실패 - ID: {}, 사유: {}", id, e.getMessage());
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.notFound(e.getMessage()));
        } catch (Exception e) {
            logger.error("설정 수정 중 오류 발생 - ID: {}", id, e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error("설정 수정 실패: " + e.getMessage()));
        }
    }

    /**
     * 설정 삭제 (관리자)
     */
    @DeleteMapping("/{id}")
    @Operation(summary = "설정 삭제", description = "점호 설정을 삭제합니다.")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<?>> deleteSettings(
            @Parameter(description = "설정 ID", required = true)
            @PathVariable Long id) {
        try {
            logger.info("점호 설정 삭제 요청 - ID: {}", id);

            settingsService.deleteSettings(id);

            return ResponseEntity.ok(ApiResponse.success("설정이 성공적으로 삭제되었습니다."));

        } catch (RuntimeException e) {
            logger.warn("설정 삭제 실패 - ID: {}, 사유: {}", id, e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error(e.getMessage()));
        } catch (Exception e) {
            logger.error("설정 삭제 중 오류 발생 - ID: {}", id, e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error("설정 삭제 실패: " + e.getMessage()));
        }
    }

    /**
     * 설정 활성화/비활성화 토글 (관리자)
     */
    @PatchMapping("/{id}/toggle")
    @Operation(summary = "설정 토글", description = "점호 설정의 활성화/비활성화를 토글합니다.")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<?>> toggleSettings(
            @Parameter(description = "설정 ID", required = true)
            @PathVariable Long id) {
        try {
            logger.info("점호 설정 토글 요청 - ID: {}", id);

            InspectionSettings toggled = settingsService.toggleEnabled(id);

            String message = toggled.getIsEnabled() ? "설정이 활성화되었습니다." : "설정이 비활성화되었습니다.";
            return ResponseEntity.ok(ApiResponse.success(message, toggled));

        } catch (RuntimeException e) {
            logger.warn("설정 토글 실패 - ID: {}, 사유: {}", id, e.getMessage());
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.notFound(e.getMessage()));
        } catch (Exception e) {
            logger.error("설정 토글 중 오류 발생 - ID: {}", id, e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error("설정 토글 실패: " + e.getMessage()));
        }
    }

    /**
     * 기본 설정 초기화 (관리자)
     */
    @PostMapping("/initialize-default")
    @Operation(summary = "기본 설정 초기화", description = "기본 점호 설정을 초기화합니다.")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<?>> initializeDefaultSettings(
            @AuthenticationPrincipal String adminId) {
        try {
            logger.info("기본 설정 초기화 요청 - 관리자: {}", adminId);

            InspectionSettings defaultSettings = settingsService.createDefaultSettingsIfNotExists();

            return ResponseEntity.ok(ApiResponse.success("기본 설정이 초기화되었습니다.", defaultSettings));

        } catch (RuntimeException e) {
            logger.warn("기본 설정 초기화 실패: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error(e.getMessage()));
        } catch (Exception e) {
            logger.error("기본 설정 초기화 중 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error("기본 설정 초기화 실패: " + e.getMessage()));
        }
    }
}