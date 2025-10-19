package com.dormitory.SpringBoot.controller;

import com.dormitory.SpringBoot.domain.User;
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
 * 인증 관련 API 컨트롤러 - 완전 버전
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
    public ResponseEntity<?> register(@Valid @RequestBody RegisterRequest request, BindingResult bindingResult) {
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
                return ResponseEntity.badRequest().body(errors);
            }

            UserResponse newUser = userService.register(request);

            Map<String, Object> response = new HashMap<>();
            response.put("message", "회원가입이 성공적으로 완료되었습니다.");
            response.put("user", newUser);
            response.put("success", true);

            logger.info("=== 회원가입 요청 완료 ===");
            return ResponseEntity.status(HttpStatus.CREATED).body(response);

        } catch (RuntimeException e) {
            logger.warn("회원가입 실패: {}", e.getMessage());
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("error", e.getMessage());
            errorResponse.put("success", false);
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(errorResponse);

        } catch (Exception e) {
            logger.error("회원가입 중 예기치 않은 오류 발생", e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("error", "서버 내부 오류가 발생했습니다.");
            errorResponse.put("success", false);
            errorResponse.put("details", e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }

    /**
     * 사용자 로그인
     */
    @PostMapping("/login")
    public ResponseEntity<?> login(@Valid @RequestBody LoginRequest request, BindingResult bindingResult) {
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
                return ResponseEntity.badRequest().body(errors);
            }

            String token = userService.login(request);
            UserResponse userInfo = userService.getUserById(request.getId());

            Map<String, Object> response = new HashMap<>();
            response.put("message", "로그인이 성공적으로 완료되었습니다.");
            response.put("token", token);
            response.put("user", userInfo);
            response.put("success", true);

            logger.info("=== 로그인 요청 완료 ===");
            return ResponseEntity.ok(response);

        } catch (RuntimeException e) {
            logger.warn("로그인 실패: {}", e.getMessage());
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("error", e.getMessage());
            errorResponse.put("success", false);
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(errorResponse);

        } catch (Exception e) {
            logger.error("로그인 중 예기치 않은 오류 발생", e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("error", "서버 내부 오류가 발생했습니다.");
            errorResponse.put("success", false);
            errorResponse.put("details", e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }

    /**
     * 토큰 유효성 검증 - POST와 GET 모두 지원
     */
    @PostMapping("/validate")
    public ResponseEntity<?> validateTokenPost(@RequestHeader("Authorization") String authHeader) {
        return validateTokenCommon(authHeader);
    }

    @GetMapping("/validate")
    public ResponseEntity<?> validateTokenGet(@RequestHeader("Authorization") String authHeader) {
        return validateTokenCommon(authHeader);
    }

    private ResponseEntity<?> validateTokenCommon(String authHeader) {
        try {
            logger.info("토큰 유효성 검증 요청");

            if (authHeader == null || !authHeader.startsWith("Bearer ")) {
                Map<String, Object> errorResponse = new HashMap<>();
                errorResponse.put("error", "Authorization 헤더가 올바르지 않습니다.");
                errorResponse.put("valid", false);
                errorResponse.put("success", false);
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(errorResponse);
            }

            String token = authHeader.substring(7);

            // 토큰 유효성 검증
            if (!jwtUtil.isTokenValid(token)) {
                Map<String, Object> errorResponse = new HashMap<>();
                errorResponse.put("error", "유효하지 않은 토큰입니다.");
                errorResponse.put("valid", false);
                errorResponse.put("success", false);
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(errorResponse);
            }

            String userId = jwtUtil.getUserIdFromToken(token);
            Boolean isAdmin = jwtUtil.getIsAdminFromToken(token);

            // 사용자 존재 여부 확인
            Optional<User> userOptional = userRepository.findById(userId);
            if (!userOptional.isPresent()) {
                Map<String, Object> errorResponse = new HashMap<>();
                errorResponse.put("error", "사용자를 찾을 수 없습니다.");
                errorResponse.put("valid", false);
                errorResponse.put("success", false);
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(errorResponse);
            }

            User user = userOptional.get();

            // 계정 상태 확인
            if (!Boolean.TRUE.equals(user.getIsActive())) {
                Map<String, Object> errorResponse = new HashMap<>();
                errorResponse.put("error", "비활성화된 계정입니다.");
                errorResponse.put("valid", false);
                errorResponse.put("success", false);
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(errorResponse);
            }

            if (user.isAccountLocked()) {
                Map<String, Object> errorResponse = new HashMap<>();
                errorResponse.put("error", "잠긴 계정입니다.");
                errorResponse.put("valid", false);
                errorResponse.put("success", false);
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(errorResponse);
            }

            Map<String, Object> response = new HashMap<>();
            response.put("valid", true);
            response.put("message", "토큰이 유효합니다.");
            response.put("userId", userId);
            response.put("isAdmin", isAdmin);
            response.put("userName", user.getName());
            response.put("success", true);

            logger.info("토큰 검증 성공: 사용자ID {}", userId);
            return ResponseEntity.ok(response);

        } catch (Exception e) {
            logger.warn("토큰 검증 실패: {}", e.getMessage());
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("error", "유효하지 않은 토큰입니다.");
            errorResponse.put("valid", false);
            errorResponse.put("success", false);
            errorResponse.put("details", e.getMessage());
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(errorResponse);
        }
    }

    /**
     * 현재 로그인한 사용자 정보 조회
     */
    @GetMapping("/me")
    public ResponseEntity<?> getCurrentUser() {
        try {
            Authentication authentication = SecurityContextHolder.getContext().getAuthentication();

            if (authentication == null || !authentication.isAuthenticated()) {
                Map<String, Object> errorResponse = new HashMap<>();
                errorResponse.put("error", "인증이 필요합니다.");
                errorResponse.put("success", false);
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(errorResponse);
            }

            String userId = authentication.getName();
            logger.info("현재 사용자 정보 조회 요청: {}", userId);

            UserResponse userResponse = userService.getUserById(userId);

            Map<String, Object> response = new HashMap<>();
            response.put("message", "사용자 정보 조회 성공");
            response.put("user", userResponse);
            response.put("success", true);

            return ResponseEntity.ok(response);

        } catch (RuntimeException e) {
            logger.warn("사용자 정보 조회 실패: {}", e.getMessage());
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("error", e.getMessage());
            errorResponse.put("success", false);
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(errorResponse);

        } catch (Exception e) {
            logger.error("사용자 정보 조회 중 예기치 않은 오류 발생", e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("error", "사용자 정보를 조회할 수 없습니다.");
            errorResponse.put("success", false);
            errorResponse.put("details", e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }

    /**
     * 토큰 새로고침 (옵셔널)
     */
    @PostMapping("/refresh")
    public ResponseEntity<?> refreshToken(@RequestHeader("Authorization") String authHeader) {
        try {
            logger.info("토큰 새로고침 요청");

            if (authHeader == null || !authHeader.startsWith("Bearer ")) {
                Map<String, Object> errorResponse = new HashMap<>();
                errorResponse.put("error", "Authorization 헤더가 올바르지 않습니다.");
                errorResponse.put("success", false);
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(errorResponse);
            }

            String token = authHeader.substring(7);

            // 토큰 새로고침 시도
            String newToken = jwtUtil.refreshTokenIfNeeded(token);

            Map<String, Object> response = new HashMap<>();
            response.put("message", "토큰 새로고침 성공");
            response.put("token", newToken);
            response.put("success", true);

            logger.info("토큰 새로고침 성공");
            return ResponseEntity.ok(response);

        } catch (Exception e) {
            logger.warn("토큰 새로고침 실패: {}", e.getMessage());
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("error", "토큰 새로고침에 실패했습니다.");
            errorResponse.put("success", false);
            errorResponse.put("details", e.getMessage());
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(errorResponse);
        }
    }

    /**
     * 로그아웃 (옵셔널 - 클라이언트에서 토큰 삭제가 주된 방법)
     */
    @PostMapping("/logout")
    public ResponseEntity<?> logout() {
        try {
            logger.info("로그아웃 요청");

            // 서버 측에서는 JWT가 stateless하므로 특별한 처리가 필요 없음
            // 클라이언트에서 토큰을 삭제하는 것이 주된 로그아웃 방법

            Map<String, Object> response = new HashMap<>();
            response.put("message", "로그아웃이 성공적으로 처리되었습니다.");
            response.put("success", true);

            logger.info("로그아웃 완료");
            return ResponseEntity.ok(response);

        } catch (Exception e) {
            logger.error("로그아웃 처리 중 오류 발생", e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("error", "로그아웃 처리 중 오류가 발생했습니다.");
            errorResponse.put("success", false);
            errorResponse.put("details", e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }

    /**
     * 서버 상태 확인 (헬스 체크)
     */
    @GetMapping("/health")
    public ResponseEntity<?> healthCheck() {
        Map<String, Object> response = new HashMap<>();
        response.put("status", "UP");
        response.put("service", "Auth Service");
        response.put("timestamp", java.time.LocalDateTime.now());
        response.put("success", true);

        return ResponseEntity.ok(response);
    }

    /**
     * 비밀번호 변경 (추가 기능)
     */
    @PutMapping("/change-password")
    public ResponseEntity<?> changePassword(@RequestBody Map<String, String> request) {
        try {
            Authentication authentication = SecurityContextHolder.getContext().getAuthentication();

            if (authentication == null || !authentication.isAuthenticated()) {
                Map<String, Object> errorResponse = new HashMap<>();
                errorResponse.put("error", "인증이 필요합니다.");
                errorResponse.put("success", false);
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(errorResponse);
            }

            String userId = authentication.getName();
            String currentPassword = request.get("currentPassword");
            String newPassword = request.get("newPassword");

            logger.info("비밀번호 변경 요청: 사용자ID={}", userId);

            if (currentPassword == null || newPassword == null) {
                Map<String, Object> errorResponse = new HashMap<>();
                errorResponse.put("error", "현재 비밀번호와 새 비밀번호가 모두 필요합니다.");
                errorResponse.put("success", false);
                return ResponseEntity.badRequest().body(errorResponse);
            }

            // UserService에 비밀번호 변경 메서드가 있다고 가정
            userService.changePassword(userId, currentPassword, newPassword);

            Map<String, Object> response = new HashMap<>();
            response.put("message", "비밀번호가 성공적으로 변경되었습니다.");
            response.put("success", true);

            logger.info("비밀번호 변경 성공: 사용자ID={}", userId);
            return ResponseEntity.ok(response);

        } catch (RuntimeException e) {
            logger.warn("비밀번호 변경 실패: {}", e.getMessage());
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("error", e.getMessage());
            errorResponse.put("success", false);
            return ResponseEntity.badRequest().body(errorResponse);

        } catch (Exception e) {
            logger.error("비밀번호 변경 중 예기치 않은 오류 발생", e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("error", "비밀번호 변경 중 오류가 발생했습니다.");
            errorResponse.put("success", false);
            errorResponse.put("details", e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }
}