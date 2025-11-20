package com.dormitory.SpringBoot.controller;

import com.dormitory.SpringBoot.domain.User;
import com.dormitory.SpringBoot.dto.ApiResponse;
import com.dormitory.SpringBoot.dto.LoginRequest;
import com.dormitory.SpringBoot.dto.RegisterRequest;
import com.dormitory.SpringBoot.dto.UserResponse;
import com.dormitory.SpringBoot.repository.UserRepository;
import com.dormitory.SpringBoot.services.UserService;
import com.dormitory.SpringBoot.services.AllowedUserService; // ✅ 추가
import com.dormitory.SpringBoot.utils.JwtUtil;
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
import java.util.Map;
import java.util.Optional;

/**
 * 인증 관련 API 컨트롤러 - ApiResponse 적용 버전 + 허용 사용자 확인 추가
 */
@RestController
@RequestMapping("/api/auth")
@CrossOrigin(origins = "*")
public class AuthController {

    private static final Logger logger = LoggerFactory.getLogger(AuthController.class);

    private final UserService userService;
    private final JwtUtil jwtUtil;
    private final UserRepository userRepository;

    @Autowired
    private AllowedUserService allowedUserService; // ✅ 추가

    @Autowired
    public AuthController(UserService userService, JwtUtil jwtUtil, UserRepository userRepository) {
        this.userService = userService;
        this.jwtUtil = jwtUtil;
        this.userRepository = userRepository;
    }

    /**
     * 사용자 회원가입 - 허용 사용자 확인 기능 추가
     */
    @PostMapping("/register")
    public ResponseEntity<ApiResponse<?>> register(@Valid @RequestBody RegisterRequest request, BindingResult bindingResult) {
        try {
            logger.info("=== 회원가입 요청 시작 ===");
            logger.info("회원가입 시도: 사용자ID={}, 관리자={}", request.getId(), request.getIsAdmin());

            // 유효성 검증 오류 체크
            if (bindingResult.hasErrors()) {
                logger.warn("회원가입 유효성 검증 실패: {}", bindingResult.getAllErrors());
                Map<String, String> errors = new HashMap<>();
                bindingResult.getFieldErrors().forEach(error ->
                        errors.put(error.getField(), error.getDefaultMessage())
                );
                return ResponseEntity.badRequest().body(ApiResponse.validationError(errors));
            }

            // ✅ [신규] 일반 사용자인 경우 허용 목록 확인
            if (!request.getIsAdmin()) {
                boolean isAllowed = allowedUserService.isUserAllowed(request.getId());
                if (!isAllowed) {
                    logger.warn("회원가입 차단: 허용되지 않은 학번 - {}", request.getId());
                    return ResponseEntity.status(HttpStatus.FORBIDDEN)
                            .body(ApiResponse.error("회원가입이 허용되지 않은 학번입니다. 관리자에게 문의하세요."));
                }
                logger.info("허용된 학번 확인 완료 - {}", request.getId());
            }

            UserResponse newUser = userService.register(request);

            // ✅ [신규] 일반 사용자 회원가입 완료 시 AllowedUser 테이블 업데이트
            if (!request.getIsAdmin()) {
                try {
                    allowedUserService.markAsRegistered(request.getId());
                    logger.info("허용 사용자 등록 완료 처리 - {}", request.getId());
                } catch (Exception e) {
                    logger.warn("허용 사용자 등록 완료 처리 실패 (무시): {}", e.getMessage());
                }
            }

            Map<String, Object> data = new HashMap<>();
            data.put("user", newUser);
            ApiResponse<?> response = ApiResponse.success("회원가입이 성공적으로 완료되었습니다.", data);

            logger.info("=== 회원가입 요청 완료 ===");
            return ResponseEntity.status(HttpStatus.CREATED).body(response);

        } catch (RuntimeException e) {
            logger.warn("회원가입 실패: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(ApiResponse.error(e.getMessage()));

        } catch (Exception e) {
            logger.error("회원가입 중 예기치 않은 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.internalServerError("서버 내부 오류가 발생했습니다."));
        }
    }

    /**
     * 사용자 로그인
     */
    @PostMapping("/login")
    public ResponseEntity<ApiResponse<?>> login(@Valid @RequestBody LoginRequest request, BindingResult bindingResult) {
        try {
            logger.info("=== 로그인 요청 시작 ===");
            logger.info("로그인 시도: 사용자ID={}", request.getId());

            // 유효성 검증 오류 체크
            if (bindingResult.hasErrors()) {
                logger.warn("로그인 유효성 검증 실패: {}", bindingResult.getAllErrors());
                Map<String, String> errors = new HashMap<>();
                bindingResult.getFieldErrors().forEach(error ->
                        errors.put(error.getField(), error.getDefaultMessage())
                );
                return ResponseEntity.badRequest().body(ApiResponse.validationError(errors));
            }

            String token = userService.login(request);
            UserResponse userInfo = userService.getUserById(request.getId());

            Map<String, Object> data = new HashMap<>();
            data.put("token", token);
            data.put("user", userInfo);
            ApiResponse<?> response = ApiResponse.success("로그인이 성공적으로 완료되었습니다.", data);

            logger.info("=== 로그인 요청 완료 ===");
            return ResponseEntity.ok(response);

        } catch (RuntimeException e) {
            logger.warn("로그인 실패: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(ApiResponse.unauthorized(e.getMessage()));

        } catch (Exception e) {
            logger.error("로그인 중 예기치 않은 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.internalServerError("서버 내부 오류가 발생했습니다."));
        }
    }

    /**
     * 사용자 로그아웃
     */
    @PostMapping("/logout")
    public ResponseEntity<ApiResponse<?>> logout() {
        try {
            Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
            if (authentication != null) {
                String userId = authentication.getName();
                logger.info("로그아웃 시도: 사용자ID={}", userId);
            }

            SecurityContextHolder.clearContext();

            return ResponseEntity.ok(ApiResponse.success("로그아웃이 완료되었습니다.", null));

        } catch (Exception e) {
            logger.error("로그아웃 중 예기치 않은 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.internalServerError("로그아웃 처리 중 오류가 발생했습니다."));
        }
    }

    /**
     * 사용자 정보 조회
     */
    @GetMapping("/me")
    public ResponseEntity<ApiResponse<?>> getCurrentUser(Authentication authentication) {
        try {
            if (authentication == null) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(ApiResponse.unauthorized("인증되지 않은 사용자입니다."));
            }

            String userId = authentication.getName();
            logger.info("사용자 정보 조회: 사용자ID={}", userId);

            UserResponse userInfo = userService.getUserById(userId);

            return ResponseEntity.ok(ApiResponse.success("사용자 정보 조회 성공", userInfo));

        } catch (RuntimeException e) {
            logger.error("사용자 정보 조회 실패", e);
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.error("사용자를 찾을 수 없습니다."));

        } catch (Exception e) {
            logger.error("사용자 정보 조회 중 예기치 않은 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.internalServerError("서버 내부 오류가 발생했습니다."));
        }
    }

    /**
     * 사용자 ID 중복 확인
     */
    @GetMapping("/check-id/{id}")
    public ResponseEntity<ApiResponse<?>> checkIdDuplicate(@PathVariable String id) {
        try {
            boolean exists = userRepository.existsById(id);
            Map<String, Object> data = new HashMap<>();
            data.put("exists", exists);
            data.put("available", !exists);

            String message = exists ? "이미 사용 중인 ID입니다." : "사용 가능한 ID입니다.";
            return ResponseEntity.ok(ApiResponse.success(message, data));

        } catch (Exception e) {
            logger.error("ID 중복 확인 중 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.internalServerError("ID 중복 확인 중 오류가 발생했습니다."));
        }
    }

    /**
     * 이메일 해시 중복 확인
     */
    @PostMapping("/check-email")
    public ResponseEntity<ApiResponse<?>> checkEmailDuplicate(@RequestBody Map<String, String> request) {
        try {
            String emailHash = request.get("emailHash");
            if (emailHash == null || emailHash.isEmpty()) {
                return ResponseEntity.badRequest()
                        .body(ApiResponse.error("이메일 해시가 제공되지 않았습니다."));
            }

            Optional<User> existingUser = userRepository.findByEmailHash(emailHash);
            boolean exists = existingUser.isPresent();

            Map<String, Object> data = new HashMap<>();
            data.put("exists", exists);
            data.put("available", !exists);

            String message = exists ? "이미 사용 중인 이메일입니다." : "사용 가능한 이메일입니다.";
            return ResponseEntity.ok(ApiResponse.success(message, data));

        } catch (Exception e) {
            logger.error("이메일 중복 확인 중 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.internalServerError("이메일 중복 확인 중 오류가 발생했습니다."));
        }
    }
}