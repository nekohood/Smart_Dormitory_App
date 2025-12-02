package com.dormitory.SpringBoot.controller;

import com.dormitory.SpringBoot.dto.*;
import com.dormitory.SpringBoot.services.*;
import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 사용자 관련 API 컨트롤러
 * ✅ 수정: 비밀번호 변경 API - currentPassword/oldPassword 모두 지원
 */
@RestController
@RequestMapping("/api/users")
@CrossOrigin(origins = "*")
public class UserController {

    private static final Logger logger = LoggerFactory.getLogger(UserController.class);

    private final UserService userService;

    @Autowired
    public UserController(UserService userService) {
        this.userService = userService;
    }

    /**
     * 현재 로그인한 사용자 정보 조회
     */
    @GetMapping("/me")
    public ResponseEntity<ApiResponse<UserResponse>> getCurrentUser() {
        try {
            Authentication authentication = SecurityContextHolder.getContext().getAuthentication();

            if (authentication == null || !authentication.isAuthenticated() || "anonymousUser".equals(authentication.getPrincipal())) {
                logger.warn("인증되지 않은 사용자의 정보 조회 시도");
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(ApiResponse.unauthorized("인증이 필요합니다."));
            }

            String userId = authentication.getName();
            logger.info("현재 사용자 정보 조회 요청: {}", userId);

            UserResponse userResponse = userService.getUserById(userId);

            logger.info("사용자 정보 조회 성공: {}", userId);
            return ResponseEntity.ok(ApiResponse.success("사용자 정보 조회 성공", userResponse));

        } catch (RuntimeException e) {
            logger.warn("사용자 정보 조회 실패: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.notFound(e.getMessage()));

        } catch (Exception e) {
            logger.error("사용자 정보 조회 중 예기치 않은 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.internalServerError("사용자 정보를 조회할 수 없습니다."));
        }
    }

    /**
     * 사용자 정보 수정
     */
    @PutMapping("/me")
    public ResponseEntity<ApiResponse<UserResponse>> updateCurrentUser(
            @Valid @RequestBody UpdateUserRequest request,
            BindingResult bindingResult) {
        try {
            Authentication authentication = SecurityContextHolder.getContext().getAuthentication();

            if (authentication == null || !authentication.isAuthenticated() || "anonymousUser".equals(authentication.getPrincipal())) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(ApiResponse.unauthorized("인증이 필요합니다."));
            }

            if (bindingResult.hasErrors()) {
                Map<String, String> errors = bindingResult.getFieldErrors().stream()
                        .collect(Collectors.toMap(
                                fieldError -> fieldError.getField(),
                                fieldError -> fieldError.getDefaultMessage()
                        ));
                return ResponseEntity.badRequest()
                        .body(ApiResponse.validationError(errors));
            }

            String userId = authentication.getName();
            logger.info("사용자 정보 수정 요청: {}", userId);

            UserResponse updatedUser = userService.updateUser(userId, request);

            logger.info("사용자 정보 수정 완료: {}", userId);
            return ResponseEntity.ok(ApiResponse.success("사용자 정보가 성공적으로 수정되었습니다.", updatedUser));

        } catch (RuntimeException e) {
            logger.warn("사용자 정보 수정 실패: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error("UPDATE_FAILED", e.getMessage()));

        } catch (Exception e) {
            logger.error("사용자 정보 수정 중 예기치 않은 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.internalServerError("사용자 정보를 수정할 수 없습니다."));
        }
    }

    /**
     * 비밀번호 변경
     * ✅ 수정: @Valid 제거, 수동 검증으로 변경
     * ✅ 수정: currentPassword와 oldPassword 모두 지원
     */
    @PutMapping("/me/password")
    public ResponseEntity<ApiResponse<Void>> changePassword(
            @RequestBody ChangePasswordRequest request) {
        try {
            Authentication authentication = SecurityContextHolder.getContext().getAuthentication();

            if (authentication == null || !authentication.isAuthenticated() || "anonymousUser".equals(authentication.getPrincipal())) {
                logger.warn("비밀번호 변경 시도 - 인증되지 않은 사용자");
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(ApiResponse.unauthorized("인증이 필요합니다."));
            }

            // ✅ 수동 검증: 현재 비밀번호 확인 (oldPassword 또는 currentPassword)
            String currentPassword = request.getEffectiveCurrentPassword();
            if (currentPassword == null || currentPassword.isEmpty()) {
                Map<String, String> errors = new HashMap<>();
                errors.put("currentPassword", "현재 비밀번호는 필수입니다.");
                return ResponseEntity.badRequest()
                        .body(ApiResponse.validationError(errors));
            }

            // ✅ 수동 검증: 새 비밀번호 확인
            if (request.getNewPassword() == null || request.getNewPassword().isEmpty()) {
                Map<String, String> errors = new HashMap<>();
                errors.put("newPassword", "새 비밀번호는 필수입니다.");
                return ResponseEntity.badRequest()
                        .body(ApiResponse.validationError(errors));
            }

            // ✅ 수동 검증: 새 비밀번호 길이 확인 (4자 이상)
            if (request.getNewPassword().length() < 4) {
                Map<String, String> errors = new HashMap<>();
                errors.put("newPassword", "새 비밀번호는 4자 이상이어야 합니다.");
                return ResponseEntity.badRequest()
                        .body(ApiResponse.validationError(errors));
            }

            // ✅ confirmPassword가 있는 경우에만 확인
            if (request.getConfirmPassword() != null && !request.getConfirmPassword().isEmpty()) {
                if (!request.getNewPassword().equals(request.getConfirmPassword())) {
                    Map<String, String> errors = new HashMap<>();
                    errors.put("confirmPassword", "새 비밀번호와 확인 비밀번호가 일치하지 않습니다.");
                    return ResponseEntity.badRequest()
                            .body(ApiResponse.validationError(errors));
                }
            }

            String userId = authentication.getName();
            logger.info("비밀번호 변경 요청: {}", userId);

            userService.changePassword(userId, currentPassword, request.getNewPassword());

            logger.info("비밀번호 변경 완료: {}", userId);
            return ResponseEntity.ok(ApiResponse.success("비밀번호가 성공적으로 변경되었습니다."));

        } catch (RuntimeException e) {
            logger.warn("비밀번호 변경 실패: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error("PASSWORD_CHANGE_FAILED", e.getMessage()));

        } catch (Exception e) {
            logger.error("비밀번호 변경 중 예기치 않은 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.internalServerError("비밀번호를 변경할 수 없습니다."));
        }
    }
}