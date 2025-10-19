package com.dormitory.SpringBoot.controller;

import com.dormitory.SpringBoot.dto.ApiResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

/**
 * 연결 테스트 및 서버 상태 확인을 위한 컨트롤러
 */
@RestController
@CrossOrigin(origins = "*")
public class HelloController {

    private static final Logger logger = LoggerFactory.getLogger(HelloController.class);

    @Value("${spring.application.name:dormitory-management-system}")
    private String applicationName;

    @Value("${info.app.version:1.0.0}")
    private String applicationVersion;

    /**
     * 기본 연결 테스트 엔드포인트
     */
    @GetMapping("/hello")
    public ResponseEntity<ApiResponse<Map<String, Object>>> hello() {
        logger.info("연결 테스트 요청 수신");

        Map<String, Object> data = new HashMap<>();
        data.put("message", "Hello from Dormitory Management System!");
        data.put("application", applicationName);
        data.put("version", applicationVersion);
        data.put("timestamp", LocalDateTime.now());
        data.put("status", "running");

        return ResponseEntity.ok(ApiResponse.success("서버 연결 성공", data));
    }

    /**
     * 상세 서버 정보 조회
     */
    @GetMapping("/hello/info")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getServerInfo() {
        logger.info("서버 정보 조회 요청");

        Map<String, Object> serverInfo = new HashMap<>();

        // 기본 정보
        serverInfo.put("applicationName", applicationName);
        serverInfo.put("version", applicationVersion);
        serverInfo.put("timestamp", LocalDateTime.now());

        // 시스템 정보
        Runtime runtime = Runtime.getRuntime();
        Map<String, Object> systemInfo = new HashMap<>();
        systemInfo.put("javaVersion", System.getProperty("java.version"));
        systemInfo.put("osName", System.getProperty("os.name"));
        systemInfo.put("osVersion", System.getProperty("os.version"));
        systemInfo.put("totalMemory", runtime.totalMemory() / 1024 / 1024 + " MB");
        systemInfo.put("freeMemory", runtime.freeMemory() / 1024 / 1024 + " MB");
        systemInfo.put("maxMemory", runtime.maxMemory() / 1024 / 1024 + " MB");
        systemInfo.put("processors", runtime.availableProcessors());

        serverInfo.put("system", systemInfo);

        // 환경 정보
        Map<String, Object> environmentInfo = new HashMap<>();
        environmentInfo.put("activeProfile", System.getProperty("spring.profiles.active", "default"));
        environmentInfo.put("serverPort", System.getProperty("server.port", "8080"));
        environmentInfo.put("timezone", System.getProperty("user.timezone"));

        serverInfo.put("environment", environmentInfo);

        return ResponseEntity.ok(ApiResponse.success("서버 정보 조회 성공", serverInfo));
    }

    /**
     * 서버 상태 확인 (헬스체크)
     */
    @GetMapping("/hello/health")
    public ResponseEntity<ApiResponse<Map<String, String>>> healthCheck() {
        logger.debug("헬스체크 요청");

        Map<String, String> health = new HashMap<>();
        health.put("status", "UP");
        health.put("timestamp", LocalDateTime.now().toString());
        health.put("service", "dormitory-management-system");

        return ResponseEntity.ok(ApiResponse.success("서버 정상 작동 중", health));
    }

    /**
     * API 버전 정보
     */
    @GetMapping("/hello/version")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getVersion() {
        logger.debug("버전 정보 요청");

        Map<String, Object> versionInfo = new HashMap<>();
        versionInfo.put("application", applicationName);
        versionInfo.put("version", applicationVersion);
        versionInfo.put("apiVersion", "v1");
        versionInfo.put("buildTime", LocalDateTime.now()); // 실제로는 빌드 시간이 들어가야 함

        Map<String, String> endpoints = new HashMap<>();
        endpoints.put("auth", "/api/auth");
        endpoints.put("users", "/api/users");
        endpoints.put("inspections", "/api/inspections");
        endpoints.put("complaints", "/api/complaints");
        endpoints.put("swagger", "/swagger-ui.html");
        endpoints.put("actuator", "/actuator");

        versionInfo.put("availableEndpoints", endpoints);

        return ResponseEntity.ok(ApiResponse.success("버전 정보 조회 성공", versionInfo));
    }

    /**
     * 에코 테스트 (요청 데이터 그대로 반환)
     */
    @PostMapping("/hello/echo")
    public ResponseEntity<ApiResponse<Map<String, Object>>> echo(@RequestBody(required = false) Map<String, Object> requestData) {
        logger.info("에코 테스트 요청");

        Map<String, Object> response = new HashMap<>();
        response.put("received", requestData != null ? requestData : "empty body");
        response.put("timestamp", LocalDateTime.now());
        response.put("method", "POST");

        return ResponseEntity.ok(ApiResponse.success("에코 테스트 성공", response));
    }

    /**
     * 에러 테스트 (의도적 에러 발생)
     */
    @GetMapping("/hello/error-test")
    public ResponseEntity<ApiResponse<String>> errorTest(@RequestParam(defaultValue = "500") int errorCode) {
        logger.warn("에러 테스트 요청 - 에러 코드: {}", errorCode);

        switch (errorCode) {
            case 400:
                return ResponseEntity.badRequest()
                        .body(ApiResponse.error("TEST_BAD_REQUEST", "테스트용 400 에러입니다."));
            case 401:
                return ResponseEntity.status(401)
                        .body(ApiResponse.unauthorized("테스트용 401 에러입니다."));
            case 403:
                return ResponseEntity.status(403)
                        .body(ApiResponse.forbidden("테스트용 403 에러입니다."));
            case 404:
                return ResponseEntity.status(404)
                        .body(ApiResponse.notFound("테스트용 404 에러입니다."));
            case 500:
            default:
                return ResponseEntity.status(500)
                        .body(ApiResponse.internalServerError("테스트용 500 에러입니다."));
        }
    }

    /**
     * 시간 지연 테스트 (타임아웃 테스트용)
     */
    @GetMapping("/hello/delay")
    public ResponseEntity<ApiResponse<Map<String, Object>>> delayTest(
            @RequestParam(defaultValue = "1000") long delayMs) {
        logger.info("지연 테스트 요청 - {}ms 지연", delayMs);

        // 최대 10초까지만 허용
        if (delayMs > 10000) {
            return ResponseEntity.badRequest()
                    .body(ApiResponse.error("DELAY_TOO_LONG", "최대 10초까지만 지연 가능합니다."));
        }

        try {
            Thread.sleep(delayMs);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return ResponseEntity.status(500)
                    .body(ApiResponse.internalServerError("지연 처리 중 오류가 발생했습니다."));
        }

        Map<String, Object> result = new HashMap<>();
        result.put("delayMs", delayMs);
        result.put("message", delayMs + "ms 지연 후 응답");
        result.put("timestamp", LocalDateTime.now());

        return ResponseEntity.ok(ApiResponse.success("지연 테스트 완료", result));
    }
}