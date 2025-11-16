package com.dormitory.SpringBoot.controller;

import com.dormitory.SpringBoot.domain.User;
import com.dormitory.SpringBoot.dto.ApiResponse; // ✅ ApiResponse 임포트
import com.dormitory.SpringBoot.dto.LoginRequest;
import com.dormitory.SpringBoot.dto.RegisterRequest;
import com.dormitory.SpringBoot.dto.UserResponse;
import com.dormitory.SpringBoot.repository.UserRepository;
import com.dormitory.SpringBoot.services.UserService;
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
 * 인증 관련 API 컨트롤러 - ApiResponse 적용 버전
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
    public AuthController(UserService userService, JwtUtil jwtUtil, UserRepository userRepository) {
        this.userService = userService;
        this.jwtUtil = jwtUtil;
        this.userRepository = userRepository;
    }

    /**
     * 사용자 회원가입
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
                // ✅ ApiResponse.validationError 사용
                return ResponseEntity.badRequest().body(ApiResponse.validationError(errors));
            }

            UserResponse newUser = userService.register(request);

            // ✅ ApiResponse.success 사용
            Map<String, Object> data = new HashMap<>();
            data.put("user", newUser);
            ApiResponse<?> response = ApiResponse.success("회원가입이 성공적으로 완료되었습니다.", data);

            logger.info("=== 회원가입 요청 완료 ===");
            return ResponseEntity.status(HttpStatus.CREATED).body(response);

        } catch (RuntimeException e) {
            logger.warn("회원가입 실패: {}", e.getMessage());
            // ✅ ApiResponse.error 사용
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(ApiResponse.error(e.getMessage()));

        } catch (Exception e) {
            logger.error("회원가입 중 예기치 않은 오류 발생", e);
            // ✅ ApiResponse.internalServerError 사용
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
                // ✅ ApiResponse.validationError 사용
                return ResponseEntity.badRequest().body(ApiResponse.validationError(errors));
            }

            String token = userService.login(request);
            UserResponse userInfo = userService.getUserById(request.getId());

            // ✅ ApiResponse.success 사용
            Map<String, Object> data = new HashMap<>();
            data.put("token", token);
            data.put("user", userInfo);
            ApiResponse<?> response = ApiResponse.success("로그인이 성공적으로 완료되었습니다.", data);

            logger.info("=== 로그인 요청 완료 ===");
            return ResponseEntity.ok(response);

        } catch (RuntimeException e) {
            logger.warn("로그인 실패: {}", e.getMessage());
            // ✅ ApiResponse.unauthorized 사용
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(ApiResponse.unauthorized(e.getMessage()));

        } catch (Exception e) {
            logger.error("로그인 중 예기치 않은 오류 발생", e);
            // ✅ ApiResponse.internalServerError 사용
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.internalServerError("서버 내부 오류가 발생했습니다."));
        }
    }

    /**
     * 토큰 유효성 검증 - POST와 GET 모두 지원
     */
    @PostMapping("/validate")
    public ResponseEntity<ApiResponse<?>> validateTokenPost(@RequestHeader("Authorization") String authHeader) {
        return validateTokenCommon(authHeader);
    }

    @GetMapping("/validate")
    public ResponseEntity<ApiResponse<?>> validateTokenGet(@RequestHeader("Authorization") String authHeader) {
        return validateTokenCommon(authHeader);
    }

    private ResponseEntity<ApiResponse<?>> validateTokenCommon(String authHeader) {
        try {
            logger.info("토큰 유효성 검증 요청");

            if (authHeader == null || !authHeader.startsWith("Bearer ")) {
                // ✅ ApiResponse.unauthorized 사용
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(ApiResponse.unauthorized("Authorization 헤더가 올바르지 않습니다."));
            }

            String token = authHeader.substring(7);

            // 토큰 유효성 검증
            if (!jwtUtil.isTokenValid(token)) {
                // ✅ ApiResponse.unauthorized 사용
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(ApiResponse.unauthorized("유효하지 않은 토큰입니다."));
            }

            String userId = jwtUtil.getUserIdFromToken(token);
            Boolean isAdmin = jwtUtil.getIsAdminFromToken(token);

            // 사용자 존재 여부 확인
            Optional<User> userOptional = userRepository.findById(userId);
            if (!userOptional.isPresent()) {
                // ✅ ApiResponse.unauthorized 사용
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(ApiResponse.unauthorized("사용자를 찾을 수 없습니다."));
            }

            User user = userOptional.get();

            // 계정 상태 확인
            if (!Boolean.TRUE.equals(user.getIsActive())) {
                // ✅ ApiResponse.unauthorized 사용
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(ApiResponse.unauthorized("비활성화된 계정입니다."));
            }

            if (user.isAccountLocked()) {
                // ✅ ApiResponse.unauthorized 사용
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(ApiResponse.unauthorized("잠긴 계정입니다."));
            }

            // ✅ ApiResponse.success 사용
            Map<String, Object> data = new HashMap<>();
            data.put("valid", true); // 클라이언트 호환성을 위해 유지
            data.put("userId", userId);
            data.put("isAdmin", isAdmin);
            data.put("userName", user.getName());
            ApiResponse<?> response = ApiResponse.success("토큰이 유효합니다.", data);

            logger.info("토큰 검증 성공: 사용자ID {}", userId);
            return ResponseEntity.ok(response);

        } catch (Exception e) {
            logger.warn("토큰 검증 실패: {}", e.getMessage());
            // ✅ ApiResponse.unauthorized 사용
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.unauthorized("유효하지 않은 토큰입니다."));
        }
    }

    /**
     * 현재 로그인한 사용자 정보 조회
     */
    @GetMapping("/me")
    public ResponseEntity<ApiResponse<?>> getCurrentUser() {
        try {
            Authentication authentication = SecurityContextHolder.getContext().getAuthentication();

            if (authentication == null || !authentication.isAuthenticated()) {
                // ✅ ApiResponse.unauthorized 사용
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(ApiResponse.unauthorized("인증이 필요합니다."));
            }

            String userId = authentication.getName();
            logger.info("현재 사용자 정보 조회 요청: {}", userId);

            UserResponse userResponse = userService.getUserById(userId);

            // ✅ ApiResponse.success 사용 (data로 userResponse 객체 바로 전달)
            ApiResponse<?> response = ApiResponse.success("사용자 정보 조회 성공", userResponse);

            return ResponseEntity.ok(response);

        } catch (RuntimeException e) {
            logger.warn("사용자 정보 조회 실패: {}", e.getMessage());
            // ✅ ApiResponse.notFound 사용
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.notFound(e.getMessage()));

        } catch (Exception e) {
            logger.error("사용자 정보 조회 중 예기치 않은 오류 발생", e);
            // ✅ ApiResponse.internalServerError 사용
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.internalServerError("사용자 정보를 조회할 수 없습니다."));
        }
    }

    /**
     * 토큰 새로고침 (옵셔널)
     */
    @PostMapping("/refresh")
    public ResponseEntity<ApiResponse<?>> refreshToken(@RequestHeader("Authorization") String authHeader) {
        try {
            logger.info("토큰 새로고침 요청");

            if (authHeader == null || !authHeader.startsWith("Bearer ")) {
                // ✅ ApiResponse.unauthorized 사용
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(ApiResponse.unauthorized("Authorization 헤더가 올바르지 않습니다."));
            }

            String token = authHeader.substring(7);

            // 토큰 새로고침 시도
            String newToken = jwtUtil.refreshTokenIfNeeded(token);

            // ✅ ApiResponse.success 사용
            Map<String, Object> data = new HashMap<>();
            data.put("token", newToken);
            ApiResponse<?> response = ApiResponse.success("토큰 새로고침 성공", data);

            logger.info("토큰 새로고침 성공");
            return ResponseEntity.ok(response);

        } catch (Exception e) {
            logger.warn("토큰 새로고침 실패: {}", e.getMessage());
            // ✅ ApiResponse.unauthorized 사용
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.unauthorized("토큰 새로고침에 실패했습니다."));
        }
    }

    /**
     * 로그아웃 (옵셔널 - 클라이언트에서 토큰 삭제가 주된 방법)
     */
    @PostMapping("/logout")
    public ResponseEntity<ApiResponse<?>> logout() {
        try {
            logger.info("로그아웃 요청");
            // ✅ ApiResponse.success 사용
            ApiResponse<?> response = ApiResponse.success("로그아웃이 성공적으로 처리되었습니다.");

            logger.info("로그아웃 완료");
            return ResponseEntity.ok(response);

        } catch (Exception e) {
            logger.error("로그아웃 처리 중 오류 발생", e);
            // ✅ ApiResponse.internalServerError 사용
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.internalServerError("로그아웃 처리 중 오류가 발생했습니다."));
        }
    }

    /**
     * 서버 상태 확인 (헬스 체크)
     */
    @GetMapping("/health")
    public ResponseEntity<ApiResponse<?>> healthCheck() {
        // ✅ ApiResponse.success 사용
        Map<String, Object> data = new HashMap<>();
        data.put("status", "UP");
        data.put("service", "Auth Service");
        data.put("timestamp", java.time.LocalDateTime.now());

        return ResponseEntity.ok(ApiResponse.success(data));
    }

    /**
     * 비밀번호 변경 (추가 기능)
     */
    @PutMapping("/change-password")
    public ResponseEntity<ApiResponse<?>> changePassword(@RequestBody Map<String, String> request) {
        try {
            Authentication authentication = SecurityContextHolder.getContext().getAuthentication();

            if (authentication == null || !authentication.isAuthenticated()) {
                // ✅ ApiResponse.unauthorized 사용
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(ApiResponse.unauthorized("인증이 필요합니다."));
            }

            String userId = authentication.getName();
            String currentPassword = request.get("currentPassword");
            String newPassword = request.get("newPassword");

            logger.info("비밀번호 변경 요청: 사용자ID={}", userId);

            if (currentPassword == null || newPassword == null) {
                // ✅ ApiResponse.error (유효성 검증) 사용
                return ResponseEntity.badRequest()
                        .body(ApiResponse.error("VALIDATION_ERROR", "현재 비밀번호와 새 비밀번호가 모두 필요합니다."));
            }

            // UserService에 비밀번호 변경 메서드가 있다고 가정
            userService.changePassword(userId, currentPassword, newPassword);

            // ✅ ApiResponse.success 사용
            ApiResponse<?> response = ApiResponse.success("비밀번호가 성공적으로 변경되었습니다.");

            logger.info("비밀번호 변경 성공: 사용자ID={}", userId);
            return ResponseEntity.ok(response);

        } catch (RuntimeException e) {
            logger.warn("비밀번호 변경 실패: {}", e.getMessage());
            // ✅ ApiResponse.error 사용
            return ResponseEntity.badRequest().body(ApiResponse.error(e.getMessage()));

        } catch (Exception e) {
            logger.error("비밀번호 변경 중 예기치 않은 오류 발생", e);
            // ✅ ApiResponse.internalServerError 사용
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.internalServerError("비밀번호 변경 중 오류가 발생했습니다."));
        }
    }
}