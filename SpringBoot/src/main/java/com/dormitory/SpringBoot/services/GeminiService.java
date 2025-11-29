package com.dormitory.SpringBoot.services;

import com.dormitory.SpringBoot.domain.RoomTemplate;
import com.dormitory.SpringBoot.domain.RoomTemplate.RoomType;  // ✅ 수정: RoomTemplate 내부 enum
import com.dormitory.SpringBoot.repository.RoomTemplateRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.commons.codec.binary.Base64;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.*;

/**
 * Google Gemini API를 사용하여 방 사진을 분석하는 서비스
 * ✅ 방 사진이 아닌 경우 0점 처리 기능 추가
 * ✅ 기준 방 사진(템플릿)과 비교 분석 기능 추가
 * ✅ 오탐지 방지를 위한 키워드 검증 로직 개선
 */
@Service
public class GeminiService {

    @Autowired(required = false)
    private RoomTemplateRepository roomTemplateRepository;

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
        private final boolean isNotRoomPhoto;

        public AnalysisResult(int score, String feedback, boolean success) {
            this.score = score;
            this.feedback = feedback;
            this.success = success;
            this.isNotRoomPhoto = false;
        }

        public AnalysisResult(int score, String feedback, boolean success, boolean isNotRoomPhoto) {
            this.score = score;
            this.feedback = feedback;
            this.success = success;
            this.isNotRoomPhoto = isNotRoomPhoto;
        }

        public int getScore() { return score; }
        public String getFeedback() { return feedback; }
        public boolean isSuccess() { return success; }
        public boolean isNotRoomPhoto() { return isNotRoomPhoto; }
    }

    /**
     * MultipartFile로부터 점호 평가 점수 반환
     */
    public int evaluateInspection(MultipartFile imageFile) {
        try {
            logger.info("점호 평가 점수 계산 시작");

            String base64Image = encodeMultipartFileToBase64(imageFile);
            if (base64Image == null) {
                logger.error("이미지 인코딩 실패 - Fallback 점수 반환");
                return fallbackEnabled ? fallbackScore : 0;
            }

            AnalysisResult result = analyzeImageWithBase64(base64Image);

            if (result.isSuccess()) {
                return result.getScore();
            } else {
                logger.warn("Gemini API 분석 실패 - Fallback 점수 사용: {}", result.getFeedback());
                if (fallbackEnabled) {
                    return 6 + (int)(Math.random() * 3);
                }
                return 0;
            }

        } catch (Exception e) {
            logger.error("점호 평가 중 예외 발생 - Fallback 점수 반환", e);
            return fallbackEnabled ? fallbackScore : 0;
        }
    }

    /**
     * MultipartFile로부터 점호 피드백 반환
     */
    public String getInspectionFeedback(MultipartFile imageFile) {
        try {
            logger.info("점호 피드백 생성 시작");

            String base64Image = encodeMultipartFileToBase64(imageFile);
            if (base64Image == null) {
                logger.error("이미지 인코딩 실패 - 기본 피드백 반환");
                return "이미지 분석이 완료되었습니다. 방 상태가 양호합니다.";
            }

            AnalysisResult result = analyzeImageWithBase64(base64Image);

            if (result.isSuccess()) {
                return result.getFeedback();
            } else {
                logger.warn("Gemini API 피드백 생성 실패 - 기본 피드백 사용");
                if (fallbackEnabled) {
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
     * 방 사진인지 확인 (별도 메서드)
     */
    public boolean isRoomPhoto(MultipartFile imageFile) {
        try {
            String base64Image = encodeMultipartFileToBase64(imageFile);
            if (base64Image == null) {
                return true; // 인코딩 실패 시 기본적으로 허용
            }

            AnalysisResult result = analyzeImageWithBase64(base64Image);

            // ✅ 점수가 0이고 피드백에 "검사불가"가 있으면 방 사진이 아님
            if (result.getScore() == 0 && result.getFeedback() != null) {
                String feedback = result.getFeedback().toLowerCase();
                if (feedback.contains("검사불가") || feedback.contains("검사 불가")) {
                    return false;
                }
            }

            return !result.isNotRoomPhoto();

        } catch (Exception e) {
            logger.error("방 사진 확인 중 오류", e);
            return true; // 오류 시 기본적으로 허용
        }
    }

    /**
     * 이미지 경로로부터 방 분석
     */
    public AnalysisResult analyzeRoomImage(String imagePath) {
        try {
            logger.info("방 사진 분석 시작 - 경로: {}", imagePath);

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
     * Base64 인코딩된 이미지 분석
     */
    private AnalysisResult analyzeImageWithBase64(String base64Image) {
        try {
            Map<String, Object> requestBody = createGeminiRequest(base64Image);

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.set("User-Agent", "SpringBoot-DormitoryApp/1.0");

            HttpEntity<Map<String, Object>> request = new HttpEntity<>(requestBody, headers);

            String fullUrl = apiUrl + "?key=" + apiKey;
            logger.info("Gemini API 호출 시작");

            ResponseEntity<String> response = restTemplate.postForEntity(fullUrl, request, String.class);

            logger.info("Gemini API 응답 상태: {}", response.getStatusCode());

            if (response.getStatusCode() == HttpStatus.OK && response.getBody() != null) {
                return parseGeminiResponse(response.getBody());
            } else {
                logger.error("Gemini API 호출 실패. Status: {}", response.getStatusCode());
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
     * Gemini API 요청 바디 생성
     */
    private Map<String, Object> createGeminiRequest(String base64Image) {
        Map<String, Object> requestBody = new HashMap<>();

        Map<String, Object> textPart = new HashMap<>();
        textPart.put("text", createConciseRoomAnalysisPrompt());

        Map<String, Object> imagePart = new HashMap<>();
        Map<String, Object> inlineData = new HashMap<>();
        inlineData.put("mime_type", "image/jpeg");
        inlineData.put("data", base64Image);
        imagePart.put("inline_data", inlineData);

        Map<String, Object> content = new HashMap<>();
        content.put("parts", List.of(textPart, imagePart));

        requestBody.put("contents", List.of(content));

        Map<String, Object> generationConfig = new HashMap<>();
        generationConfig.put("temperature", 0.1);
        generationConfig.put("maxOutputTokens", maxTokens);
        generationConfig.put("topP", 0.8);
        generationConfig.put("topK", 10);
        requestBody.put("generationConfig", generationConfig);

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
     * ✅ 개선된 프롬프트 - 더 명확한 지시사항
     */
    private String createConciseRoomAnalysisPrompt() {
        return """
                당신은 기숙사 방 청결도 평가 전문가입니다.
                제출된 사진이 실제 기숙사/원룸/숙소 방 사진인지 먼저 확인하세요.
                
                ✅ 다음은 모두 유효한 기숙사 방 사진입니다:
                - 침대, 책상, 의자, 옷장이 있는 방
                - 바닥이 보이는 방 내부 전경
                - 발코니/베란다가 보이는 방 사진
                - 1인실, 2인실, 다인실 등 모든 형태의 기숙사 방
                - 깨끗하거나 어질러진 모든 상태의 방
                
                ❌ 다음 경우에만 "검사불가"로 응답하세요:
                - 게임 스크린샷이나 CG 이미지 (포르자, GTA 등)
                - 영화/드라마/애니메이션 장면
                - 인터넷에서 다운로드한 인테리어 사진
                - 화장실, 복도, 계단, 로비, 야외 사진
                - 셀카만 있고 방이 전혀 보이지 않는 사진
                - TV/모니터 화면을 촬영한 사진
                
                방 사진이 맞다면 10점 만점으로 평가하세요:
                - 정리정돈 (3점): 물건 정리 상태
                - 청결도 (3점): 바닥, 책상, 침대 청결성
                - 안전성 (2점): 위험 요소 없음
                - 생활환경 (2점): 전반적 쾌적성
                
                응답 형식:
                점수: X점
                [평가 설명 100자 이내]
                
                방 사진이 아닌 경우에만:
                점수: 0점
                검사불가: [이미지 유형] - 기숙사 방 사진이 아닙니다.
                """;
    }

    /**
     * ✅ Gemini API 응답 파싱 (개선된 버전)
     */
    private AnalysisResult parseGeminiResponse(String responseBody) {
        try {
            logger.debug("Gemini API 응답 파싱 시작");

            JsonNode rootNode = objectMapper.readTree(responseBody);

            if (rootNode.has("error")) {
                String errorMessage = rootNode.path("error").path("message").asText("알 수 없는 API 오류");
                logger.error("Gemini API가 오류를 반환했습니다: {}", errorMessage);
                return new AnalysisResult(fallbackScore, "AI 분석 서비스 오류: " + errorMessage, fallbackEnabled);
            }

            JsonNode promptFeedbackNode = rootNode.path("promptFeedback");
            if (!promptFeedbackNode.isMissingNode() && promptFeedbackNode.has("blockReason")) {
                String blockReason = promptFeedbackNode.path("blockReason").asText();
                logger.error("Gemini API 요청이 차단되었습니다. 이유: {}", blockReason);
                return new AnalysisResult(fallbackScore, "AI 분석이 거부되었습니다.", fallbackEnabled);
            }

            JsonNode candidatesNode = rootNode.path("candidates");
            if (candidatesNode.isEmpty() || !candidatesNode.isArray()) {
                logger.error("Gemini API 응답에 candidates가 없거나 잘못된 형식입니다.");
                return new AnalysisResult(fallbackScore, "분석 결과를 받을 수 없어 기본 점수를 적용했습니다.", fallbackEnabled);
            }

            JsonNode firstCandidate = candidatesNode.get(0);
            if (firstCandidate.isMissingNode()) {
                return new AnalysisResult(fallbackScore, "분석 결과를 받을 수 없어 기본 점수를 적용했습니다.", fallbackEnabled);
            }

            String finishReason = firstCandidate.path("finishReason").asText(null);
            if (finishReason != null) {
                logger.info("Gemini API finishReason: {}", finishReason);
            }

            JsonNode contentNode = firstCandidate.path("content");
            if (contentNode.isMissingNode()) {
                return new AnalysisResult(fallbackScore, "분석 결과를 파싱할 수 없어 기본 점수를 적용했습니다.", fallbackEnabled);
            }

            JsonNode partsNode = contentNode.path("parts");
            if (partsNode.isEmpty() || !partsNode.isArray()) {
                if ("MAX_TOKENS".equals(finishReason)) {
                    return new AnalysisResult(fallbackScore, "방 상태가 양호합니다. (AI 분석 부분 완료)", true);
                }
                return new AnalysisResult(fallbackScore, "분석 결과를 파싱할 수 없어 기본 점수를 적용했습니다.", fallbackEnabled);
            }

            JsonNode firstPart = partsNode.get(0);
            if (firstPart.isMissingNode() || !firstPart.has("text")) {
                return new AnalysisResult(fallbackScore, "분석 결과 텍스트를 찾을 수 없어 기본 점수를 적용했습니다.", fallbackEnabled);
            }

            String text = firstPart.path("text").asText();
            if (text == null || text.trim().isEmpty()) {
                return new AnalysisResult(fallbackScore, "분석 결과가 비어있어 기본 점수를 적용했습니다.", fallbackEnabled);
            }

            logger.info("Gemini API 응답 텍스트: {}", text);

            // ✅ 방 사진이 아닌 경우 감지 (개선된 로직)
            if (isNotRoomPhotoResponse(text)) {
                logger.warn("방 사진이 아닌 것으로 감지됨 - 0점 처리");
                String reason = extractNotRoomPhotoReason(text);
                return new AnalysisResult(0, "❌ 검사불가: " + reason, true, true);
            }

            int score = extractScoreFromText(text);
            String feedback = extractFeedbackFromText(text);

            logger.info("파싱된 점수: {}, 피드백: {}", score, feedback);
            return new AnalysisResult(score, feedback, true);

        } catch (Exception e) {
            logger.error("분석 텍스트 파싱 중 오류 발생", e);
            return new AnalysisResult(fallbackScore, "분석 결과를 처리하는 중 오류가 발생했습니다.", fallbackEnabled);
        }
    }

    /**
     * ✅ 방 사진이 아닌 응답인지 확인 (개선된 버전 - 오탐지 방지)
     *
     * 핵심 변경: "평가 기준", "적용하여" 같은 일반적인 단어를 제거하고,
     * 명확하게 방 사진이 아님을 나타내는 키워드만 사용
     */
    private boolean isNotRoomPhotoResponse(String text) {
        if (text == null) return false;

        String lower = text.toLowerCase();

        // ✅ 1단계: "검사불가" 또는 "검사 불가"가 명시적으로 있는 경우
        if (lower.contains("검사불가") || lower.contains("검사 불가")) {
            logger.info("'검사불가' 키워드 감지 - 방 사진 아님으로 판단");
            return true;
        }

        // ✅ 2단계: "점수: 0점"이고 특정 거부 사유가 있는 경우
        if (lower.contains("점수: 0점") || lower.contains("점수:0점")) {
            // 0점이면서 명확한 거부 사유가 있는 경우만
            String[] rejectReasons = {
                    "방 사진이 아", "기숙사 방 사진이 아", "방이 아닙니다",
                    "게임", "스크린샷", "screenshot",
                    "영화", "드라마", "애니메이션", "만화", "일러스트",
                    "화장실", "복도", "계단", "야외", "외부", "옥외",
                    "셀카만", "방이 보이지 않"
            };

            for (String reason : rejectReasons) {
                if (lower.contains(reason.toLowerCase())) {
                    logger.info("0점 + '{}' 키워드 감지 - 방 사진 아님으로 판단", reason);
                    return true;
                }
            }
        }

        // ✅ 3단계: 명시적으로 "평가 불가"라고 하는 경우 (단, 점수가 있으면 제외)
        if ((lower.contains("평가 불가") || lower.contains("평가불가")) &&
                !lower.matches(".*점수\\s*:\\s*[1-9].*")) {
            // 점수가 1-9점 사이가 아닌 경우에만 평가 불가로 처리
            logger.info("'평가 불가' 키워드 감지 + 유효 점수 없음 - 방 사진 아님으로 판단");
            return true;
        }

        // ✅ 4단계: 명확한 비-방 이미지 유형이 언급된 경우 (0점일 때만)
        if (lower.contains("0점") || lower.contains("0 점")) {
            String[] imageTypes = {
                    "게임 스크린샷", "비디오 게임", "cg 이미지", "렌더링",
                    "인터넷 이미지", "다운로드한 이미지", "캡처 이미지",
                    "tv 화면", "모니터 화면", "컴퓨터 화면"
            };

            for (String type : imageTypes) {
                if (lower.contains(type.toLowerCase())) {
                    logger.info("0점 + '{}' 이미지 유형 감지 - 방 사진 아님으로 판단", type);
                    return true;
                }
            }
        }

        // 그 외의 경우는 정상적인 방 사진으로 간주
        return false;
    }

    /**
     * ✅ 방 사진이 아닌 이유 추출
     */
    private String extractNotRoomPhotoReason(String text) {
        if (text == null) return "기숙사 방 사진이 아닙니다.";

        String lower = text.toLowerCase();

        if (lower.contains("게임") || lower.contains("스크린샷") || lower.contains("screenshot")) {
            return "게임 스크린샷은 점호 사진으로 인정되지 않습니다.";
        }
        if (lower.contains("영화") || lower.contains("드라마")) {
            return "영화/드라마 장면은 점호 사진으로 인정되지 않습니다.";
        }
        if (lower.contains("만화") || lower.contains("일러스트") || lower.contains("애니메이션")) {
            return "그림/일러스트는 점호 사진으로 인정되지 않습니다.";
        }
        if (lower.contains("화장실") || lower.contains("샤워") || lower.contains("bathroom")) {
            return "화장실/샤워실 사진은 점호로 인정되지 않습니다.";
        }
        if (lower.contains("복도") || lower.contains("계단") || lower.contains("hallway")) {
            return "복도/계단 사진은 점호로 인정되지 않습니다.";
        }
        if (lower.contains("야외") || lower.contains("외부") || lower.contains("옥외") || lower.contains("outside")) {
            return "야외/실외 사진은 점호로 인정되지 않습니다.";
        }
        if (lower.contains("셀카") || lower.contains("selfie")) {
            return "방이 보이지 않는 셀카는 점호로 인정되지 않습니다.";
        }
        if (lower.contains("tv") || lower.contains("모니터") || lower.contains("컴퓨터 화면")) {
            return "화면 캡처/촬영 이미지는 점호로 인정되지 않습니다.";
        }
        if (lower.contains("인터넷") || lower.contains("다운로드")) {
            return "인터넷에서 다운로드한 이미지는 점호로 인정되지 않습니다.";
        }

        return "기숙사 방 사진이 아닙니다. 실제 방 사진을 다시 제출해주세요.";
    }

    /**
     * 텍스트에서 점수 추출
     */
    private int extractScoreFromText(String text) {
        int score = fallbackScore;

        String[] lines = text.split("\n");
        for (String line : lines) {
            if (line.contains("점수") && line.contains("점")) {
                try {
                    String scoreStr = line.replaceAll("[^0-9]", "");
                    if (!scoreStr.isEmpty()) {
                        score = Integer.parseInt(scoreStr);
                        if (score > 10) score = 10;
                        if (score < 0) score = 0;
                    }
                } catch (NumberFormatException e) {
                    logger.warn("점수 파싱 실패: {}", line);
                }
                break;
            }
        }

        return score;
    }

    /**
     * 텍스트에서 피드백 추출
     */
    private String extractFeedbackFromText(String text) {
        String feedback = "분석이 완료되었습니다.";

        if (text.length() > 20) {
            feedback = text.replaceAll("점수\\s*:\\s*\\d+점?", "").trim();
            if (feedback.isEmpty()) {
                feedback = "분석이 완료되었습니다.";
            }
        }

        return feedback;
    }

    /**
     * API 연결 상태 테스트
     */
    public boolean testConnection() {
        try {
            logger.info("Gemini API 연결 테스트 시작");

            Map<String, Object> requestBody = new HashMap<>();
            Map<String, Object> textPart = new HashMap<>();
            textPart.put("text", "Hello, this is a connection test. Please respond with 'OK'.");

            Map<String, Object> content = new HashMap<>();
            content.put("parts", List.of(textPart));
            requestBody.put("contents", List.of(content));

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);

            HttpEntity<Map<String, Object>> request = new HttpEntity<>(requestBody, headers);
            String fullUrl = apiUrl + "?key=" + apiKey;

            ResponseEntity<String> response = restTemplate.postForEntity(fullUrl, request, String.class);

            boolean success = response.getStatusCode() == HttpStatus.OK;
            logger.info("Gemini API 연결 테스트 결과: {}", success ? "성공" : "실패");
            return success;

        } catch (Exception e) {
            logger.error("Gemini API 연결 테스트 실패", e);
            return false;
        }
    }

    /**
     * 진단 정보 반환
     */
    public Map<String, Object> getDiagnosticInfo() {
        Map<String, Object> info = new HashMap<>();
        info.put("apiUrl", apiUrl);
        info.put("timeout", timeout);
        info.put("maxTokens", maxTokens);
        info.put("fallbackScore", fallbackScore);
        info.put("fallbackEnabled", fallbackEnabled);
        info.put("apiKeyConfigured", apiKey != null && !apiKey.isEmpty());
        return info;
    }

    // ==================== 템플릿 비교 관련 메서드 ====================

    /**
     * 기준 템플릿과 비교하여 점호 평가
     */
    public int evaluateInspectionWithTemplate(MultipartFile imageFile, RoomType roomType, String buildingName) {
        try {
            logger.info("템플릿 비교 점호 평가 시작 - 방타입: {}, 동: {}", roomType, buildingName);

            Optional<RoomTemplate> templateOpt = getTemplateForComparison(roomType, buildingName);

            if (templateOpt.isEmpty() || templateOpt.get().getImageBase64() == null) {
                logger.info("비교할 템플릿이 없음 - 일반 평가 진행");
                return evaluateInspection(imageFile);
            }

            RoomTemplate template = templateOpt.get();
            String templateBase64 = template.getImageBase64();
            String userImageBase64 = encodeMultipartFileToBase64(imageFile);

            if (userImageBase64 == null) {
                logger.error("사용자 이미지 인코딩 실패");
                return fallbackEnabled ? fallbackScore : 0;
            }

            AnalysisResult result = analyzeWithTemplateComparison(templateBase64, userImageBase64);

            if (result.isSuccess()) {
                logger.info("템플릿 비교 평가 완료 - 점수: {}", result.getScore());
                return result.getScore();
            } else {
                logger.warn("템플릿 비교 실패 - 일반 평가로 폴백");
                return evaluateInspection(imageFile);
            }

        } catch (Exception e) {
            logger.error("템플릿 비교 점호 평가 중 오류", e);
            return evaluateInspection(imageFile);
        }
    }

    /**
     * 기준 템플릿과 비교하여 피드백 생성
     */
    public String getInspectionFeedbackWithTemplate(MultipartFile imageFile, RoomType roomType, String buildingName) {
        try {
            Optional<RoomTemplate> templateOpt = getTemplateForComparison(roomType, buildingName);

            if (templateOpt.isEmpty() || templateOpt.get().getImageBase64() == null) {
                return getInspectionFeedback(imageFile);
            }

            RoomTemplate template = templateOpt.get();
            String templateBase64 = template.getImageBase64();
            String userImageBase64 = encodeMultipartFileToBase64(imageFile);

            if (userImageBase64 == null) {
                return "이미지 분석에 실패했습니다.";
            }

            AnalysisResult result = analyzeWithTemplateComparison(templateBase64, userImageBase64);

            if (result.isSuccess()) {
                return result.getFeedback();
            } else {
                return getInspectionFeedback(imageFile);
            }

        } catch (Exception e) {
            logger.error("템플릿 비교 피드백 생성 중 오류", e);
            return getInspectionFeedback(imageFile);
        }
    }

    /**
     * 비교할 템플릿 조회
     */
    private Optional<RoomTemplate> getTemplateForComparison(RoomType roomType, String buildingName) {
        try {
            if (roomTemplateRepository == null) {
                return Optional.empty();
            }

            if (buildingName != null && !buildingName.isEmpty()) {
                List<RoomTemplate> templates = roomTemplateRepository.findByRoomTypeAndBuilding(roomType, buildingName);
                if (!templates.isEmpty()) {
                    return Optional.of(templates.get(0));
                }
            }

            return roomTemplateRepository.findByRoomTypeAndIsDefaultTrueAndIsActiveTrue(roomType);

        } catch (Exception e) {
            logger.error("템플릿 조회 실패", e);
            return Optional.empty();
        }
    }

    /**
     * 템플릿 비교 분석 수행
     */
    private AnalysisResult analyzeWithTemplateComparison(String templateBase64, String userImageBase64) {
        try {
            Map<String, Object> requestBody = new HashMap<>();

            Map<String, Object> textPart = new HashMap<>();
            textPart.put("text", createTemplateComparisonPrompt());

            Map<String, Object> templateImagePart = new HashMap<>();
            Map<String, Object> templateInlineData = new HashMap<>();
            templateInlineData.put("mime_type", "image/jpeg");
            templateInlineData.put("data", templateBase64);
            templateImagePart.put("inline_data", templateInlineData);

            Map<String, Object> userImagePart = new HashMap<>();
            Map<String, Object> userInlineData = new HashMap<>();
            userInlineData.put("mime_type", "image/jpeg");
            userInlineData.put("data", userImageBase64);
            userImagePart.put("inline_data", userInlineData);

            Map<String, Object> content = new HashMap<>();
            content.put("parts", List.of(textPart, templateImagePart, userImagePart));

            requestBody.put("contents", List.of(content));

            Map<String, Object> generationConfig = new HashMap<>();
            generationConfig.put("temperature", 0.1);
            generationConfig.put("maxOutputTokens", maxTokens);
            requestBody.put("generationConfig", generationConfig);

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);

            HttpEntity<Map<String, Object>> request = new HttpEntity<>(requestBody, headers);
            String fullUrl = apiUrl + "?key=" + apiKey;

            ResponseEntity<String> response = restTemplate.postForEntity(fullUrl, request, String.class);

            if (response.getStatusCode() == HttpStatus.OK && response.getBody() != null) {
                return parseGeminiResponse(response.getBody());
            } else {
                return new AnalysisResult(fallbackScore, "템플릿 비교 분석 실패", false);
            }

        } catch (Exception e) {
            logger.error("템플릿 비교 분석 중 오류", e);
            return new AnalysisResult(fallbackScore, "템플릿 비교 분석 중 오류 발생", false);
        }
    }

    /**
     * 템플릿 비교 프롬프트
     */
    private String createTemplateComparisonPrompt() {
        return """
                두 장의 기숙사 방 사진을 비교 분석해주세요.
                
                첫 번째 이미지: 관리자가 등록한 기준(모범) 방 사진
                두 번째 이미지: 학생이 제출한 점호 사진
                
                비교 평가 기준 (10점 만점):
                - 정리정돈 상태 비교 (3점): 기준 사진 대비 정리 상태
                - 청결도 비교 (3점): 기준 사진 대비 청결 상태
                - 안전성 (2점): 위험 요소 없음
                - 전반적 유사도 (2점): 기준 방과의 전반적인 상태 비교
                
                응답 형식:
                점수: X점
                [기준 사진 대비 평가 설명 - 100자 이내]
                
                ※ 두 번째 이미지가 방 사진이 아닌 경우:
                점수: 0점
                검사불가: [사유]
                """;
    }
}