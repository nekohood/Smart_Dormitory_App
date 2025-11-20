package com.dormitory.SpringBoot.controller;

import com.dormitory.SpringBoot.dto.AllowedUserRequest;
import com.dormitory.SpringBoot.dto.ApiResponse;
import com.dormitory.SpringBoot.services.AllowedUserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

/**
 * 허용된 사용자 관리 컨트롤러
 */
@RestController
@RequestMapping("/api/allowed-users")
@Tag(name = "Allowed Users", description = "허용된 사용자 관리 API")
public class AllowedUserController {

    private static final Logger logger = LoggerFactory.getLogger(AllowedUserController.class);

    @Autowired
    private AllowedUserService allowedUserService;

    /**
     * 엑셀 파일로 허용 사용자 일괄 등록 (관리자 전용)
     */
    @PostMapping("/upload-excel")
    @Operation(summary = "엑셀 파일 업로드", description = "엑셀 파일로 허용 사용자 목록을 일괄 등록합니다. (관리자 전용)")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<?>> uploadExcel(
            @Parameter(description = "엑셀 파일 (.xlsx)", required = true)
            @RequestParam("file") MultipartFile file) {
        
        try {
            logger.info("엑셀 파일 업로드 요청 - 파일명: {}", file.getOriginalFilename());

            // 파일 유효성 검사
            if (file.isEmpty()) {
                return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error("파일이 비어있습니다."));
            }

            String filename = file.getOriginalFilename();
            if (filename == null || !filename.endsWith(".xlsx")) {
                return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error("엑셀 파일(.xlsx)만 업로드 가능합니다."));
            }

            AllowedUserRequest.UploadResponse response = 
                allowedUserService.uploadAllowedUsersFromExcel(file);

            String message = String.format("업로드 완료 - 전체: %d, 성공: %d, 실패: %d", 
                response.getTotalCount(), 
                response.getSuccessCount(), 
                response.getFailCount());

            return ResponseEntity.ok(ApiResponse.success(message, response));

        } catch (Exception e) {
            logger.error("엑셀 파일 업로드 실패: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(ApiResponse.internalServerError(e.getMessage()));
        }
    }

    /**
     * 개별 허용 사용자 추가 (관리자 전용)
     */
    @PostMapping("/add")
    @Operation(summary = "허용 사용자 추가", description = "개별 허용 사용자를 추가합니다. (관리자 전용)")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<?>> addAllowedUser(
            @RequestBody AllowedUserRequest.AddUserRequest request) {
        
        try {
            logger.info("허용 사용자 추가 요청 - 학번: {}", request.getUserId());

            AllowedUserRequest.AllowedUserResponse response = 
                allowedUserService.addAllowedUser(request);

            return ResponseEntity.ok(ApiResponse.success("허용 사용자가 추가되었습니다.", response));

        } catch (RuntimeException e) {
            logger.error("허용 사용자 추가 실패: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(ApiResponse.error(e.getMessage()));
        } catch (Exception e) {
            logger.error("허용 사용자 추가 중 예기치 않은 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(ApiResponse.internalServerError(e.getMessage()));
        }
    }

    /**
     * 허용 사용자 목록 조회 (관리자 전용)
     */
    @GetMapping("/list")
    @Operation(summary = "허용 사용자 목록 조회", description = "모든 허용 사용자 목록을 조회합니다. (관리자 전용)")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<?>> getAllAllowedUsers() {
        try {
            logger.info("허용 사용자 목록 조회 요청");

            AllowedUserRequest.AllowedUserListResponse response = 
                allowedUserService.getAllAllowedUsers();

            return ResponseEntity.ok(ApiResponse.success("허용 사용자 목록 조회 성공", response));

        } catch (Exception e) {
            logger.error("허용 사용자 목록 조회 실패: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(ApiResponse.internalServerError(e.getMessage()));
        }
    }

    /**
     * 특정 학번의 허용 사용자 조회 (관리자 전용)
     */
    @GetMapping("/{userId}")
    @Operation(summary = "허용 사용자 조회", description = "특정 학번의 허용 사용자를 조회합니다. (관리자 전용)")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<?>> getAllowedUser(
            @Parameter(description = "사용자 ID (학번)", required = true)
            @PathVariable String userId) {
        
        try {
            logger.info("허용 사용자 조회 요청 - 학번: {}", userId);

            AllowedUserRequest.AllowedUserResponse response = 
                allowedUserService.getAllowedUser(userId);

            return ResponseEntity.ok(ApiResponse.success("허용 사용자 조회 성공", response));

        } catch (RuntimeException e) {
            logger.error("허용 사용자 조회 실패 - 학번: {}, 오류: {}", userId, e.getMessage());
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(ApiResponse.error(e.getMessage()));
        } catch (Exception e) {
            logger.error("허용 사용자 조회 중 예기치 않은 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(ApiResponse.internalServerError(e.getMessage()));
        }
    }

    /**
     * 학번 허용 여부 확인 (공개 API - 회원가입 시 사용)
     */
    @GetMapping("/check/{userId}")
    @Operation(summary = "학번 허용 여부 확인", description = "특정 학번이 회원가입 허용 목록에 있는지 확인합니다.")
    public ResponseEntity<ApiResponse<?>> checkUserAllowed(
            @Parameter(description = "사용자 ID (학번)", required = true)
            @PathVariable String userId) {
        
        try {
            logger.info("학번 허용 여부 확인 - 학번: {}", userId);

            boolean isAllowed = allowedUserService.isUserAllowed(userId);

            return ResponseEntity.ok(ApiResponse.success(
                isAllowed ? "허용된 학번입니다." : "허용되지 않은 학번입니다.", 
                isAllowed));

        } catch (Exception e) {
            logger.error("학번 허용 여부 확인 중 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(ApiResponse.internalServerError(e.getMessage()));
        }
    }

    /**
     * 허용 사용자 삭제 (관리자 전용)
     */
    @DeleteMapping("/{userId}")
    @Operation(summary = "허용 사용자 삭제", description = "특정 학번의 허용 사용자를 삭제합니다. (관리자 전용)")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<?>> deleteAllowedUser(
            @Parameter(description = "사용자 ID (학번)", required = true)
            @PathVariable String userId) {
        
        try {
            logger.info("허용 사용자 삭제 요청 - 학번: {}", userId);

            allowedUserService.deleteAllowedUser(userId);

            return ResponseEntity.ok(ApiResponse.success("허용 사용자가 삭제되었습니다.", null));

        } catch (RuntimeException e) {
            logger.error("허용 사용자 삭제 실패 - 학번: {}, 오류: {}", userId, e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(ApiResponse.error(e.getMessage()));
        } catch (Exception e) {
            logger.error("허용 사용자 삭제 중 예기치 않은 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(ApiResponse.internalServerError(e.getMessage()));
        }
    }
}
