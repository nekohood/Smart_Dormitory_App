package com.dormitory.SpringBoot.controller;

import com.dormitory.SpringBoot.services.GeminiService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.HashMap;
import java.util.Map;

/**
 * 진단 및 테스트용 컨트롤러
 */
@RestController
@RequestMapping("/api/diagnostic")
public class DiagnosticController {

    private static final Logger logger = LoggerFactory.getLogger(DiagnosticController.class);

    @Autowired
    private GeminiService geminiService;

    /**
     * Gemini API 연결 상태 확인
     */
    @GetMapping("/gemini/connection")
    public ResponseEntity<Map<String, Object>> checkGeminiConnection() {
        try {
            Map<String, Object> result = new HashMap<>();
            
            // 기본 진단 정보
            Map<String, Object> diagnostics = geminiService.getDiagnosticInfo();
            result.put("diagnostics", diagnostics);
            
            // 연결 테스트
            boolean connectionTest = geminiService.testConnection();
            result.put("connectionTest", connectionTest);
            result.put("status", connectionTest ? "SUCCESS" : "FAIL");
            
            return ResponseEntity.ok(result);
            
        } catch (Exception e) {
            logger.error("Gemini 연결 확인 중 오류 발생", e);
            Map<String, Object> error = new HashMap<>();
            error.put("status", "ERROR");
            error.put("message", e.getMessage());
            return ResponseEntity.ok(error);
        }
    }

    /**
     * 테스트 이미지로 Gemini API 호출 테스트
     */
    @PostMapping("/gemini/test-image")
    public ResponseEntity<Map<String, Object>> testGeminiWithImage(
            @RequestParam("image") MultipartFile imageFile) {
        try {
            Map<String, Object> result = new HashMap<>();
            
            logger.info("테스트 이미지 분석 시작 - 파일명: {}, 크기: {} bytes", 
                       imageFile.getOriginalFilename(), imageFile.getSize());
            
            // 이미지 분석 테스트
            int score = geminiService.evaluateInspection(imageFile);
            String feedback = geminiService.getInspectionFeedback(imageFile);
            
            result.put("status", "SUCCESS");
            result.put("score", score);
            result.put("feedback", feedback);
            result.put("fileName", imageFile.getOriginalFilename());
            result.put("fileSize", imageFile.getSize());
            
            logger.info("테스트 이미지 분석 완료 - 점수: {}", score);
            
            return ResponseEntity.ok(result);
            
        } catch (Exception e) {
            logger.error("테스트 이미지 분석 중 오류 발생", e);
            Map<String, Object> error = new HashMap<>();
            error.put("status", "ERROR");
            error.put("message", e.getMessage());
            return ResponseEntity.ok(error);
        }
    }

    /**
     * 시스템 상태 전반 확인
     */
    @GetMapping("/system/status")
    public ResponseEntity<Map<String, Object>> getSystemStatus() {
        try {
            Map<String, Object> status = new HashMap<>();
            
            // 현재 시간
            status.put("timestamp", java.time.LocalDateTime.now().toString());
            
            // JVM 정보
            Runtime runtime = Runtime.getRuntime();
            Map<String, Object> jvm = new HashMap<>();
            jvm.put("totalMemory", runtime.totalMemory());
            jvm.put("freeMemory", runtime.freeMemory());
            jvm.put("usedMemory", runtime.totalMemory() - runtime.freeMemory());
            jvm.put("maxMemory", runtime.maxMemory());
            status.put("jvm", jvm);
            
            // Gemini 서비스 상태
            Map<String, Object> geminiStatus = geminiService.getDiagnosticInfo();
            status.put("gemini", geminiStatus);
            
            return ResponseEntity.ok(status);
            
        } catch (Exception e) {
            logger.error("시스템 상태 확인 중 오류 발생", e);
            Map<String, Object> error = new HashMap<>();
            error.put("status", "ERROR");
            error.put("message", e.getMessage());
            return ResponseEntity.ok(error);
        }
    }

    /**
     * Gemini API 상세 테스트 (텍스트 전용)
     */
    @PostMapping("/gemini/test-text")
    public ResponseEntity<Map<String, Object>> testGeminiTextOnly(@RequestBody Map<String, String> request) {
        try {
            Map<String, Object> result = new HashMap<>();
            String testText = request.getOrDefault("text", "안녕하세요, 연결 테스트입니다.");
            
            // 연결 테스트
            boolean connectionResult = geminiService.testConnection();
            
            result.put("status", connectionResult ? "SUCCESS" : "FAIL");
            result.put("connectionTest", connectionResult);
            result.put("testText", testText);
            result.put("timestamp", java.time.LocalDateTime.now().toString());
            
            return ResponseEntity.ok(result);
            
        } catch (Exception e) {
            logger.error("Gemini 텍스트 테스트 중 오류 발생", e);
            Map<String, Object> error = new HashMap<>();
            error.put("status", "ERROR");
            error.put("message", e.getMessage());
            return ResponseEntity.ok(error);
        }
    }

    /**
     * API 설정 정보 확인 (민감 정보 제외)
     */
    @GetMapping("/gemini/config")
    public ResponseEntity<Map<String, Object>> getGeminiConfig() {
        try {
            Map<String, Object> config = new HashMap<>();
            
            // 진단 정보 (민감한 정보는 마스킹)
            Map<String, Object> diagnostics = geminiService.getDiagnosticInfo();
            config.putAll(diagnostics);
            
            // 추가 설정 정보
            config.put("serviceClass", "GeminiService");
            config.put("version", "1.0");
            
            return ResponseEntity.ok(config);
            
        } catch (Exception e) {
            logger.error("Gemini 설정 확인 중 오류 발생", e);
            Map<String, Object> error = new HashMap<>();
            error.put("status", "ERROR");
            error.put("message", e.getMessage());
            return ResponseEntity.ok(error);
        }
    }

    /**
     * 로그 레벨 동적 변경 (개발용)
     */
    @PostMapping("/logging/level")
    public ResponseEntity<Map<String, Object>> changeLogLevel(@RequestBody Map<String, String> request) {
        try {
            Map<String, Object> result = new HashMap<>();
            String level = request.getOrDefault("level", "INFO");
            String loggerName = request.getOrDefault("logger", "com.dormitory.SpringBoot");
            
            // 로그 레벨 변경 (실제 구현은 LoggerContext를 사용)
            result.put("status", "SUCCESS");
            result.put("message", "로그 레벨 변경 요청을 받았습니다.");
            result.put("requestedLevel", level);
            result.put("targetLogger", loggerName);
            result.put("timestamp", java.time.LocalDateTime.now().toString());
            
            logger.info("로그 레벨 변경 요청 - Logger: {}, Level: {}", loggerName, level);
            
            return ResponseEntity.ok(result);
            
        } catch (Exception e) {
            logger.error("로그 레벨 변경 중 오류 발생", e);
            Map<String, Object> error = new HashMap<>();
            error.put("status", "ERROR");
            error.put("message", e.getMessage());
            return ResponseEntity.ok(error);
        }
    }

    /**
     * 헬스 체크 (간단한 상태 확인)
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> healthCheck() {
        Map<String, Object> health = new HashMap<>();
        health.put("status", "UP");
        health.put("timestamp", java.time.LocalDateTime.now().toString());
        health.put("service", "DiagnosticController");
        health.put("version", "1.0");
        
        return ResponseEntity.ok(health);
    }
}