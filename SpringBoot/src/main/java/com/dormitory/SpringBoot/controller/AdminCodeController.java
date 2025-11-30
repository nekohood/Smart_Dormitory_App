package com.dormitory.SpringBoot.controller;

import com.dormitory.SpringBoot.domain.AdminCode;
import com.dormitory.SpringBoot.dto.ApiResponse;
import com.dormitory.SpringBoot.services.AdminCodeService;
import io.swagger.v3.oas.annotations.Operation;
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

/**
 * 관리자 코드 관리 API 컨트롤러
 */
@RestController
@RequestMapping("/api/admin-code")
@Tag(name = "Admin Code", description = "관리자 코드 관리 API")
@CrossOrigin(origins = "*")
public class AdminCodeController {

    private static final Logger logger = LoggerFactory.getLogger(AdminCodeController.class);

    @Autowired
    private AdminCodeService adminCodeService;

    /**
     * 관리자 코드 검증 (회원가입 시 사용 - 인증 불필요)
     */
    @PostMapping("/validate")
    @Operation(summary = "관리자 코드 검증", description = "관리자 회원가입 시 코드 유효성을 검증합니다.")
    public ResponseEntity<ApiResponse<?>> validateCode(@RequestBody Map<String, String> request) {
        try {
            String code = request.get("code");
            logger.info("관리자 코드 검증 요청");

            boolean isValid = adminCodeService.validateAdminCode(code);

            Map<String, Object> data = new HashMap<>();
            data.put("valid", isValid);
            data.put("message", isValid ? "유효한 관리자 코드입니다." : "유효하지 않은 관리자 코드입니다.");

            return ResponseEntity.ok(ApiResponse.success("코드 검증 완료", data));

        } catch (Exception e) {
            logger.error("관리자 코드 검증 중 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error("코드 검증 실패: " + e.getMessage()));
        }
    }

    /**
     * 모든 관리자 코드 조회 (관리자 전용)
     */
    @GetMapping
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "관리자 코드 목록 조회", description = "모든 관리자 코드를 조회합니다.")
    public ResponseEntity<ApiResponse<?>> getAllCodes() {
        try {
            logger.info("관리자 코드 목록 조회 요청");

            List<AdminCode> codes = adminCodeService.getAllCodes();

            return ResponseEntity.ok(ApiResponse.success("관리자 코드 목록 조회 성공", codes));

        } catch (Exception e) {
            logger.error("관리자 코드 목록 조회 중 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error("코드 목록 조회 실패: " + e.getMessage()));
        }
    }

    /**
     * 관리자 코드 생성 (관리자 전용)
     */
    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "관리자 코드 생성", description = "새로운 관리자 코드를 생성합니다.")
    public ResponseEntity<ApiResponse<?>> createCode(
            @AuthenticationPrincipal String adminId,
            @RequestBody Map<String, String> request) {
        try {
            String code = request.get("code");
            String description = request.get("description");

            logger.info("관리자 코드 생성 요청 - 코드: {}", code);

            if (code == null || code.trim().isEmpty()) {
                return ResponseEntity.badRequest()
                        .body(ApiResponse.error("코드를 입력해주세요."));
            }

            AdminCode created = adminCodeService.createCode(code.trim(), description, adminId);

            return ResponseEntity.status(HttpStatus.CREATED)
                    .body(ApiResponse.success("관리자 코드가 생성되었습니다.", created));

        } catch (RuntimeException e) {
            logger.warn("관리자 코드 생성 실패: {}", e.getMessage());
            return ResponseEntity.badRequest()
                    .body(ApiResponse.error(e.getMessage()));

        } catch (Exception e) {
            logger.error("관리자 코드 생성 중 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error("코드 생성 실패: " + e.getMessage()));
        }
    }

    /**
     * 관리자 코드 수정 (관리자 전용)
     */
    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "관리자 코드 수정", description = "관리자 코드를 수정합니다.")
    public ResponseEntity<ApiResponse<?>> updateCode(
            @PathVariable Long id,
            @RequestBody Map<String, Object> request) {
        try {
            String newCode = (String) request.get("code");
            String description = (String) request.get("description");
            Boolean isActive = (Boolean) request.get("isActive");

            logger.info("관리자 코드 수정 요청 - ID: {}", id);

            AdminCode updated = adminCodeService.updateCode(id, newCode, description, isActive);

            return ResponseEntity.ok(ApiResponse.success("관리자 코드가 수정되었습니다.", updated));

        } catch (RuntimeException e) {
            logger.warn("관리자 코드 수정 실패: {}", e.getMessage());
            return ResponseEntity.badRequest()
                    .body(ApiResponse.error(e.getMessage()));

        } catch (Exception e) {
            logger.error("관리자 코드 수정 중 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error("코드 수정 실패: " + e.getMessage()));
        }
    }

    /**
     * 관리자 코드 삭제 (관리자 전용)
     */
    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "관리자 코드 삭제", description = "관리자 코드를 삭제합니다.")
    public ResponseEntity<ApiResponse<?>> deleteCode(@PathVariable Long id) {
        try {
            logger.info("관리자 코드 삭제 요청 - ID: {}", id);

            adminCodeService.deleteCode(id);

            return ResponseEntity.ok(ApiResponse.success("관리자 코드가 삭제되었습니다."));

        } catch (RuntimeException e) {
            logger.warn("관리자 코드 삭제 실패: {}", e.getMessage());
            return ResponseEntity.badRequest()
                    .body(ApiResponse.error(e.getMessage()));

        } catch (Exception e) {
            logger.error("관리자 코드 삭제 중 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error("코드 삭제 실패: " + e.getMessage()));
        }
    }

    /**
     * 관리자 코드 활성화/비활성화 토글 (관리자 전용)
     */
    @PatchMapping("/{id}/toggle")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "관리자 코드 토글", description = "관리자 코드의 활성화 상태를 토글합니다.")
    public ResponseEntity<ApiResponse<?>> toggleCode(@PathVariable Long id) {
        try {
            logger.info("관리자 코드 토글 요청 - ID: {}", id);

            AdminCode toggled = adminCodeService.toggleCode(id);

            String message = Boolean.TRUE.equals(toggled.getIsActive()) 
                    ? "관리자 코드가 활성화되었습니다." 
                    : "관리자 코드가 비활성화되었습니다.";

            return ResponseEntity.ok(ApiResponse.success(message, toggled));

        } catch (RuntimeException e) {
            logger.warn("관리자 코드 토글 실패: {}", e.getMessage());
            return ResponseEntity.badRequest()
                    .body(ApiResponse.error(e.getMessage()));

        } catch (Exception e) {
            logger.error("관리자 코드 토글 중 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error("코드 토글 실패: " + e.getMessage()));
        }
    }
}
