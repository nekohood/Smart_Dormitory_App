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
            // 수정된 부분: ApiResponse.error() 사용
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
     */
    @PutMapping("/me/password")
    public ResponseEntity<ApiResponse<Void>> changePassword(
            @Valid @RequestBody ChangePasswordRequest request,
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

            // 새 비밀번호와 확인 비밀번호가 일치하는지 확인
            if (!request.getNewPassword().equals(request.getConfirmPassword())) {
                Map<String, String> errors = new HashMap<>();
                errors.put("confirmPassword", "새 비밀번호와 확인 비밀번호가 일치하지 않습니다.");
                return ResponseEntity.badRequest()
                        .body(ApiResponse.validationError(errors));
            }

            String userId = authentication.getName();
            logger.info("비밀번호 변경 요청: {}", userId);

            userService.changePassword(userId, request.getOldPassword(), request.getNewPassword());

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