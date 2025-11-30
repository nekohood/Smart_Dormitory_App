package com.dormitory.SpringBoot.controller;

import com.dormitory.SpringBoot.domain.User;
import com.dormitory.SpringBoot.dto.ApiResponse;
import com.dormitory.SpringBoot.dto.LoginRequest;
import com.dormitory.SpringBoot.dto.RegisterRequest;
import com.dormitory.SpringBoot.dto.UserResponse;
import com.dormitory.SpringBoot.repository.UserRepository;
import com.dormitory.SpringBoot.services.AdminCodeService;
import com.dormitory.SpringBoot.services.AllowedUserService;
import com.dormitory.SpringBoot.services.UserService;
import com.dormitory.SpringBoot.utils.JwtUtil;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
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
 * 인증 관련 API 컨트롤러
 * ✅ 수정: 관리자 코드 검증 기능 추가
 */
@RestController
@RequestMapping("/api/auth")
@Tag(name = "Auth", description = "인증 관련 API")
@CrossOrigin(origins = "*")
public class AuthController {

    private static final Logger logger = LoggerFactory.getLogger(AuthController.class);

    private final UserService userService;
    private final JwtUtil jwtUtil;
    private final UserRepository userRepository;

    @Autowired
    private AllowedUserService allowedUserService;

    // ✅ 신규: 관리자 코드 서비스
    @Autowired
    private AdminCodeService adminCodeService;

    @Autowired
    public AuthController(UserService userService, JwtUtil jwtUtil, UserRepository userRepository) {
        this.userService = userService;
        this.jwtUtil = jwtUtil;
        this.userRepository = userRepository;
    }

    /**
     * 사용자 회원가입
     * ✅ 수정: 관리자 회원가입 시 관리자 코드 검증 추가
     */
    @PostMapping("/register")
    @Operation(summary = "회원가입", description = "새로운 사용자를 등록합니다. 관리자 등록 시 관리자 코드가 필요합니다.")
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

            // ✅ [수정] 관리자 회원가입 시 관리자 코드 검증
            if (Boolean.TRUE.equals(request.getIsAdmin())) {
                String adminCode = request.getAdminCode();

                if (adminCode == null || adminCode.trim().isEmpty()) {
                    logger.warn("회원가입 차단: 관리자 코드 미입력 - {}", request.getId());
                    return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                            .body(ApiResponse.error("관리자 회원가입에는 관리자 코드가 필요합니다."));
                }

                boolean isValidCode = adminCodeService.validateAdminCode(adminCode.trim());
                if (!isValidCode) {
                    logger.warn("회원가입 차단: 잘못된 관리자 코드 - {}", request.getId());
                    return ResponseEntity.status(HttpStatus.FORBIDDEN)
                            .body(ApiResponse.error("유효하지 않은 관리자 코드입니다."));
                }

                logger.info("관리자 코드 검증 성공 - {}", request.getId());
            }

            // 일반 사용자인 경우 허용 목록 확인
            if (!Boolean.TRUE.equals(request.getIsAdmin())) {
                boolean isAllowed = allowedUserService.isUserAllowed(request.getId());
                if (!isAllowed) {
                    logger.warn("회원가입 차단: 허용되지 않은 학번 - {}", request.getId());
                    return ResponseEntity.status(HttpStatus.FORBIDDEN)
                            .body(ApiResponse.error("회원가입이 허용되지 않은 학번입니다. 관리자에게 문의하세요."));
                }
                logger.info("허용된 학번 확인 완료 - {}", request.getId());
            }

            // 회원가입 처리
            UserResponse newUser = userService.register(request);

            // ✅ [신규] 관리자 회원가입 완료 시 관리자 코드 사용 기록
            if (Boolean.TRUE.equals(request.getIsAdmin()) && request.getAdminCode() != null) {
                adminCodeService.recordCodeUsage(request.getAdminCode().trim());
            }

            // 일반 사용자 회원가입 완료 시 AllowedUser 테이블 업데이트
            if (!Boolean.TRUE.equals(request.getIsAdmin())) {
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
    @Operation(summary = "로그인", description = "사용자 로그인을 처리합니다.")
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
    @Operation(summary = "로그아웃", description = "사용자 로그아웃을 처리합니다.")
    public ResponseEntity<ApiResponse<?>> logout() {
        try {
            Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
            if (authentication != null) {
                String userId = authentication.getName();
                logger.info("로그아웃 시도: 사용자ID={}", userId);
            }

            SecurityContextHolder.clearContext();

            return ResponseEntity.ok(ApiResponse.success("로그아웃이 완료되었습니다."));

        } catch (Exception e) {
            logger.error("로그아웃 중 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.internalServerError("로그아웃 처리 중 오류가 발생했습니다."));
        }
    }

    /**
     * 토큰 유효성 검사
     */
    @GetMapping("/validate")
    @Operation(summary = "토큰 검증", description = "JWT 토큰의 유효성을 검사합니다.")
    public ResponseEntity<ApiResponse<?>> validateToken(@RequestHeader("Authorization") String authHeader) {
        try {
            if (authHeader == null || !authHeader.startsWith("Bearer ")) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(ApiResponse.unauthorized("토큰이 제공되지 않았습니다."));
            }

            String token = authHeader.substring(7);

            if (!jwtUtil.isTokenValid(token)) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(ApiResponse.unauthorized("유효하지 않은 토큰입니다."));
            }

            String userId = jwtUtil.getUserIdFromToken(token);
            Optional<User> userOpt = userRepository.findById(userId);

            if (userOpt.isEmpty()) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(ApiResponse.unauthorized("사용자를 찾을 수 없습니다."));
            }

            Map<String, Object> data = new HashMap<>();
            data.put("valid", true);
            data.put("userId", userId);
            data.put("isAdmin", userOpt.get().getIsAdmin());

            return ResponseEntity.ok(ApiResponse.success("토큰이 유효합니다.", data));

        } catch (Exception e) {
            logger.error("토큰 검증 중 오류 발생", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.internalServerError("토큰 검증 중 오류가 발생했습니다."));
        }
    }
}