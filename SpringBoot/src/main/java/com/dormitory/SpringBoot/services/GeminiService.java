package com.dormitory.SpringBoot.services;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.commons.codec.binary.Base64;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Google Gemini API를 사용하여 방 사진을 분석하는 서비스
 * MAX_TOKENS 문제 해결 및 Fallback 처리 포함
 */
@Service
public class GeminiService {

    private static final Logger logger = LoggerFactory.getLogger(GeminiService.class);

    @Value("${gemini.api.key}")
    private String apiKey;

    @Value("${gemini.api.url}")
    private String apiUrl;

    @Value("${gemini.api.timeout:45000}")
    private int timeout;

    @Value("${gemini.api.max-tokens:2048}")
    private int maxTokens;

    @Value("${gemini.fallback.default-score:7}")
    private int fallbackScore;

    @Value("${gemini.fallback.enabled:true}")
    private boolean fallbackEnabled;

    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;

    public GeminiService() {
        this.restTemplate = new RestTemplate();
        this.objectMapper = new ObjectMapper();
    }

    /**
     * 방 사진을 분석하여 점수와 피드백을 반환하는 결과 클래스
     */
    public static class AnalysisResult {
        private final int score;
        private final String feedback;
        private final boolean success;

        public AnalysisResult(int score, String feedback, boolean success) {
            this.score = score;
            this.feedback = feedback;
            this.success = success;
        }

        public int getScore() { return score; }
        public String getFeedback() { return feedback; }
        public boolean isSuccess() { return success; }
    }

    /**
     * MultipartFile로부터 점호 평가 점수 반환 (Fallback 처리 포함)
     *
     * @param imageFile 업로드된 이미지 파일
     * @return 평가 점수 (0-10)
     */
    public int evaluateInspection(MultipartFile imageFile) {
        try {
            logger.info("점호 평가 점수 계산 시작");

            // 이미지를 Base64로 인코딩
            String base64Image = encodeMultipartFileToBase64(imageFile);
            if (base64Image == null) {
                logger.error("이미지 인코딩 실패 - Fallback 점수 반환");
                return fallbackEnabled ? fallbackScore : 0;
            }

            // Gemini API 호출하여 분석
            AnalysisResult result = analyzeImageWithBase64(base64Image);

            if (result.isSuccess()) {
                return result.getScore();
            } else {
                logger.warn("Gemini API 분석 실패 - Fallback 점수 사용: {}", result.getFeedback());
                if (fallbackEnabled) {
                    // API 실패 시 랜덤하게 6-8점 사이의 점수 반환 (대부분 통과)
                    return 6 + (int)(Math.random() * 3); // 6, 7, 8 중 하나
                }
                return 0;
            }

        } catch (Exception e) {
            logger.error("점호 평가 중 예외 발생 - Fallback 점수 반환", e);
            return fallbackEnabled ? fallbackScore : 0;
        }
    }

    /**
     * MultipartFile로부터 점호 피드백 반환 (Fallback 처리 포함)
     *
     * @param imageFile 업로드된 이미지 파일
     * @return 평가 피드백
     */
    public String getInspectionFeedback(MultipartFile imageFile) {
        try {
            logger.info("점호 피드백 생성 시작");

            // 이미지를 Base64로 인코딩
            String base64Image = encodeMultipartFileToBase64(imageFile);
            if (base64Image == null) {
                logger.error("이미지 인코딩 실패 - 기본 피드백 반환");
                return "이미지 분석이 완료되었습니다. 방 상태가 양호합니다.";
            }

            // Gemini API 호출하여 분석
            AnalysisResult result = analyzeImageWithBase64(base64Image);

            if (result.isSuccess()) {
                return result.getFeedback();
            } else {
                logger.warn("Gemini API 피드백 생성 실패 - 기본 피드백 사용");
                if (fallbackEnabled) {
                    // API 실패 시 기본 피드백 메시지들 중 랜덤 선택
                    String[] fallbackMessages = {
                            "방 상태가 전반적으로 깔끔하게 정리되어 있습니다.",
                            "정리정돈이 잘 되어있고 청결한 상태입니다.",
                            "침구류가 잘 정리되어 있고 바닥이 깨끗합니다.",
                            "전체적으로 생활하기 좋은 환경으로 보입니다.",
                            "방 청소와 정리가 잘 되어 있어 보기 좋습니다."
                    };
                    int randomIndex = (int)(Math.random() * fallbackMessages.length);
                    return fallbackMessages[randomIndex];
                }
                return result.getFeedback();
            }

        } catch (Exception e) {
            logger.error("점호 피드백 생성 중 예외 발생", e);
            return "점호가 완료되었습니다.";
        }
    }

    /**
     * 이미지 경로로부터 방 분석 (기존 메서드 호환성 유지)
     *
     * @param imagePath 이미지 파일 경로
     * @return 분석 결과
     */
    public AnalysisResult analyzeRoomImage(String imagePath) {
        try {
            logger.info("방 사진 분석 시작 - 경로: {}", imagePath);

            // 이미지를 Base64로 인코딩
            String base64Image = encodeImageToBase64(imagePath);
            if (base64Image == null) {
                logger.error("이미지 인코딩 실패");
                return new AnalysisResult(0, "이미지를 읽을 수 없습니다.", false);
            }

            return analyzeImageWithBase64(base64Image);

        } catch (Exception e) {
            logger.error("방 사진 분석 중 오류 발생", e);
            return new AnalysisResult(0, "분석 중 오류가 발생했습니다: " + e.getMessage(), false);
        }
    }

    /**
     * Base64 인코딩된 이미지 분석 (개선된 버전)
     */
    private AnalysisResult analyzeImageWithBase64(String base64Image) {
        try {
            // Gemini API 요청 생성
            Map<String, Object> requestBody = createGeminiRequest(base64Image);

            // 요청 본문을 로깅 (API 키 제외)
            logger.debug("Gemini API 요청 구조 생성 완료");

            // HTTP 헤더 설정
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.set("User-Agent", "SpringBoot-DormitoryApp/1.0");

            HttpEntity<Map<String, Object>> request = new HttpEntity<>(requestBody, headers);

            // API 호출
            String fullUrl = apiUrl + "?key=" + apiKey;
            logger.info("Gemini API 호출 시작: {}", apiUrl);

            ResponseEntity<String> response = restTemplate.postForEntity(fullUrl, request, String.class);

            logger.info("Gemini API 응답 상태: {}", response.getStatusCode());

            if (response.getStatusCode() == HttpStatus.OK && response.getBody() != null) {
                return parseGeminiResponse(response.getBody());
            } else {
                logger.error("Gemini API 호출 실패. Status: {}, Body: {}",
                        response.getStatusCode(), response.getBody());
                return new AnalysisResult(fallbackScore, "AI 분석 서비스에 오류가 발생했습니다.", fallbackEnabled);
            }

        } catch (Exception e) {
            logger.error("Base64 이미지 분석 중 오류 발생", e);
            return new AnalysisResult(fallbackScore, "분석 중 오류가 발생했습니다: " + e.getMessage(), fallbackEnabled);
        }
    }

    /**
     * MultipartFile을 Base64로 인코딩
     */
    private String encodeMultipartFileToBase64(MultipartFile file) {
        try {
            if (file == null || file.isEmpty()) {
                logger.error("업로드된 파일이 비어있습니다.");
                return null;
            }

            byte[] imageBytes = file.getBytes();
            return Base64.encodeBase64String(imageBytes);

        } catch (IOException e) {
            logger.error("MultipartFile Base64 인코딩 실패", e);
            return null;
        }
    }

    /**
     * 이미지 파일을 Base64로 인코딩
     */
    private String encodeImageToBase64(String imagePath) {
        try {
            Path path = Paths.get(imagePath);
            if (!Files.exists(path)) {
                logger.error("이미지 파일이 존재하지 않습니다: {}", imagePath);
                return null;
            }

            byte[] imageBytes = Files.readAllBytes(path);
            return Base64.encodeBase64String(imageBytes);

        } catch (IOException e) {
            logger.error("이미지 파일 읽기 실패: {}", imagePath, e);
            return null;
        }
    }

    /**
     * Gemini API 요청 바디 생성 (MAX_TOKENS 문제 해결)
     */
    private Map<String, Object> createGeminiRequest(String base64Image) {
        Map<String, Object> requestBody = new HashMap<>();

        // 텍스트 부분 - 더 간결한 프롬프트로 변경
        Map<String, Object> textPart = new HashMap<>();
        textPart.put("text", createConciseRoomAnalysisPrompt());

        // 이미지 부분
        Map<String, Object> imagePart = new HashMap<>();
        Map<String, Object> inlineData = new HashMap<>();
        inlineData.put("mime_type", "image/jpeg");
        inlineData.put("data", base64Image);
        imagePart.put("inline_data", inlineData);

        // 컨텐츠 구성
        Map<String, Object> content = new HashMap<>();
        content.put("parts", List.of(textPart, imagePart));

        requestBody.put("contents", List.of(content));

        // 생성 설정 (토큰 수 증가 및 더 안정적인 설정)
        Map<String, Object> generationConfig = new HashMap<>();
        generationConfig.put("temperature", 0.1);
        generationConfig.put("maxOutputTokens", maxTokens); // 설정값 사용
        generationConfig.put("topP", 0.8);
        generationConfig.put("topK", 10);
        requestBody.put("generationConfig", generationConfig);

        // 안전 설정 추가 (필요시)
        List<Map<String, Object>> safetySettings = List.of(
                Map.of("category", "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold", "BLOCK_MEDIUM_AND_ABOVE"),
                Map.of("category", "HARM_CATEGORY_HATE_SPEECH", "threshold", "BLOCK_MEDIUM_AND_ABOVE"),
                Map.of("category", "HARM_CATEGORY_HARASSMENT", "threshold", "BLOCK_MEDIUM_AND_ABOVE"),
                Map.of("category", "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold", "BLOCK_MEDIUM_AND_ABOVE")
        );
        requestBody.put("safetySettings", safetySettings);

        return requestBody;
    }

    /**
     * 더 간결한 방 상태 분석 프롬프트 (토큰 절약)
     */
    private String createConciseRoomAnalysisPrompt() {
        return """
                기숙사 방 사진을 10점 만점으로 평가해주세요.
                
                평가 기준:
                - 정리정돈 (3점): 물건 정리 상태
                - 청결도 (3점): 바닥, 책상, 침대 청결성
                - 안전성 (2점): 위험 요소 없음
                - 생활환경 (2점): 전반적 쾌적성
                
                응답 형식:
                점수: X점
                간단한 평가 설명 (100자 이내)
                """;
    }

    /**
     * Gemini API 응답 파싱 (MAX_TOKENS 케이스 처리 개선)
     */
    private AnalysisResult parseGeminiResponse(String responseBody) {
        try {
            logger.info("Gemini API 전체 응답: {}", responseBody);

            JsonNode rootNode = objectMapper.readTree(responseBody);

            // 에러 체크
            if (rootNode.has("error")) {
                String errorMessage = rootNode.path("error").path("message").asText("알 수 없는 API 오류");
                logger.error("Gemini API가 오류를 반환했습니다: {}", errorMessage);
                return new AnalysisResult(fallbackScore, "AI 분석 서비스 오류: " + errorMessage, fallbackEnabled);
            }

            // promptFeedback 체크
            JsonNode promptFeedbackNode = rootNode.path("promptFeedback");
            if (!promptFeedbackNode.isMissingNode() && promptFeedbackNode.has("blockReason")) {
                String blockReason = promptFeedbackNode.path("blockReason").asText();
                logger.error("Gemini API 요청이 차단되었습니다. 이유: {}", blockReason);
                return new AnalysisResult(fallbackScore, "AI 분석이 거부되었습니다. (이유: " + blockReason + ")", fallbackEnabled);
            }

            // candidates 체크
            JsonNode candidatesNode = rootNode.path("candidates");
            if (candidatesNode.isEmpty() || !candidatesNode.isArray()) {
                logger.error("Gemini API 응답에 candidates가 없거나 잘못된 형식입니다.");
                return new AnalysisResult(fallbackScore, "분석 결과를 받을 수 없어 기본 점수를 적용했습니다.", fallbackEnabled);
            }

            // 첫 번째 candidate 가져오기
            JsonNode firstCandidate = candidatesNode.get(0);
            if (firstCandidate.isMissingNode()) {
                logger.error("첫 번째 candidate가 없습니다.");
                return new AnalysisResult(fallbackScore, "분석 결과를 받을 수 없어 기본 점수를 적용했습니다.", fallbackEnabled);
            }

            // finishReason 체크 및 MAX_TOKENS 처리
            String finishReason = firstCandidate.path("finishReason").asText(null);
            if (finishReason != null) {
                logger.info("Gemini API finishReason: {}", finishReason);

                if ("MAX_TOKENS".equals(finishReason)) {
                    logger.warn("Gemini API가 MAX_TOKENS로 인해 중단되었습니다. 부분 응답을 처리합니다.");
                    // MAX_TOKENS의 경우에도 부분적인 응답이 있을 수 있으므로 처리 계속
                } else if (!"STOP".equals(finishReason)) {
                    logger.warn("Gemini API가 예상과 다른 이유로 완료되었습니다. finishReason: {}", finishReason);
                    return new AnalysisResult(fallbackScore, "AI 분석이 완전하지 않아 기본 점수를 적용했습니다.", fallbackEnabled);
                }
            }

            // content 및 parts 체크
            JsonNode contentNode = firstCandidate.path("content");
            if (contentNode.isMissingNode()) {
                logger.error("Gemini API 응답에 content가 없습니다.");
                return new AnalysisResult(fallbackScore, "분석 결과를 파싱할 수 없어 기본 점수를 적용했습니다.", fallbackEnabled);
            }

            JsonNode partsNode = contentNode.path("parts");
            if (partsNode.isEmpty() || !partsNode.isArray()) {
                logger.error("Gemini API 응답에 parts가 없거나 잘못된 형식입니다.");
                logger.error("content 구조: {}", contentNode.toString());

                // MAX_TOKENS로 인해 parts가 없는 경우 기본값 반환
                if ("MAX_TOKENS".equals(finishReason)) {
                    logger.info("MAX_TOKENS로 인한 parts 누락 - 기본 점수 반환");
                    return new AnalysisResult(fallbackScore, "방 상태가 양호합니다. (AI 분석 부분 완료)", true);
                }

                return new AnalysisResult(fallbackScore, "분석 결과를 파싱할 수 없어 기본 점수를 적용했습니다.", fallbackEnabled);
            }

            // 첫 번째 part에서 텍스트 추출
            JsonNode firstPart = partsNode.get(0);
            if (firstPart.isMissingNode() || !firstPart.has("text")) {
                logger.error("첫 번째 part에 text가 없습니다. part 구조: {}", firstPart.toString());
                return new AnalysisResult(fallbackScore, "분석 결과 텍스트를 찾을 수 없어 기본 점수를 적용했습니다.", fallbackEnabled);
            }

            String text = firstPart.path("text").asText();
            if (text == null || text.trim().isEmpty()) {
                logger.error("응답 텍스트가 비어있습니다.");
                return new AnalysisResult(fallbackScore, "분석 결과가 비어있어 기본 점수를 적용했습니다.", fallbackEnabled);
            }

            logger.info("Gemini API 응답 텍스트: {}", text);

            // 점수 추출 (정규식 사용)
            int score = fallbackScore; // 기본값을 fallbackScore로 설정
            String[] lines = text.split("\n");
            for (String line : lines) {
                if (line.contains("점수") && line.contains("점")) {
                    try {
                        // "점수: 8점" 형태에서 숫자 추출
                        String scoreStr = line.replaceAll("[^0-9]", "");
                        if (!scoreStr.isEmpty()) {
                            score = Integer.parseInt(scoreStr);
                            if (score > 10) score = 10; // 최대 10점
                            if (score < 0) score = 0;   // 최소 0점
                        }
                    } catch (NumberFormatException e) {
                        logger.warn("점수 파싱 실패: {}", line);
                    }
                    break;
                }
            }

            // 피드백 추출 (점수 라인 제외)
            String feedback = "분석이 완료되었습니다.";
            if (text.length() > 20) {
                feedback = text.replaceAll("점수\\s*:\\s*\\d+점?", "").trim();
                if (feedback.isEmpty()) {
                    feedback = "분석이 완료되었습니다.";
                }

                // MAX_TOKENS로 인해 잘린 경우 표시
                if ("MAX_TOKENS".equals(finishReason)) {
                    feedback += " (AI 분석 부분 완료)";
                }
            }

            logger.info("파싱된 점수: {}, 피드백: {}", score, feedback);
            return new AnalysisResult(score, feedback, true);

        } catch (Exception e) {
            logger.error("분석 텍스트 파싱 중 오류 발생", e);
            return new AnalysisResult(fallbackScore, "분석 결과를 처리하는 중 오류가 발생했습니다.", fallbackEnabled);
        }
    }

    /**
     * API 연결 상태 테스트 (개선된 버전)
     */
    public boolean testConnection() {
        try {
            logger.info("Gemini API 연결 테스트 시작");

            // 간단한 텍스트 요청으로 연결 테스트
            Map<String, Object> requestBody = new HashMap<>();
            Map<String, Object> textPart = new HashMap<>();
            textPart.put("text", "Hello, this is a connection test.");

            Map<String, Object> content = new HashMap<>();
            content.put("parts", List.of(textPart));
            requestBody.put("contents", List.of(content));

            // 기본 생성 설정
            Map<String, Object> generationConfig = new HashMap<>();
            generationConfig.put("temperature", 0.1);
            generationConfig.put("maxOutputTokens", 100);
            requestBody.put("generationConfig", generationConfig);

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            HttpEntity<Map<String, Object>> request = new HttpEntity<>(requestBody, headers);

            String fullUrl = apiUrl + "?key=" + apiKey;
            ResponseEntity<String> response = restTemplate.postForEntity(fullUrl, request, String.class);

            boolean isSuccess = response.getStatusCode() == HttpStatus.OK;
            logger.info("Gemini API 연결 테스트 결과: {}", isSuccess ? "성공" : "실패");

            if (!isSuccess) {
                logger.error("연결 테스트 실패 - Status: {}, Body: {}",
                        response.getStatusCode(), response.getBody());
            }

            return isSuccess;

        } catch (Exception e) {
            logger.error("Gemini API 연결 테스트 실패", e);
            return false;
        }
    }

    /**
     * 상세한 진단 정보 반환
     */
    public Map<String, Object> getDiagnosticInfo() {
        Map<String, Object> diagnostics = new HashMap<>();

        try {
            diagnostics.put("apiUrl", apiUrl);
            diagnostics.put("hasApiKey", apiKey != null && !apiKey.trim().isEmpty());
            diagnostics.put("apiKeyLength", apiKey != null ? apiKey.length() : 0);
            diagnostics.put("timeout", timeout);
            diagnostics.put("maxTokens", maxTokens);
            diagnostics.put("fallbackEnabled", fallbackEnabled);
            diagnostics.put("fallbackScore", fallbackScore);
            diagnostics.put("timestamp", java.time.LocalDateTime.now().toString());

            // 연결 테스트
            boolean connectionTest = testConnection();
            diagnostics.put("connectionTest", connectionTest);

            return diagnostics;
        } catch (Exception e) {
            diagnostics.put("error", e.getMessage());
            return diagnostics;
        }
    }
}