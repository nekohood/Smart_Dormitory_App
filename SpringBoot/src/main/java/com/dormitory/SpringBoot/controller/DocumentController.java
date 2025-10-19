package com.dormitory.SpringBoot.controller;

import com.dormitory.SpringBoot.domain.Document;
import com.dormitory.SpringBoot.services.DocumentService;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 공공서류 관련 API 컨트롤러 - 최종 완전 버전 (JSON과 Form-data 모두 지원)
 */
@RestController
@RequestMapping("/api/documents")
@CrossOrigin(origins = "*")
public class DocumentController {

    private static final Logger logger = LoggerFactory.getLogger(DocumentController.class);

    @Autowired
    private DocumentService documentService;

    /**
     * 모든 서류 조회 (관리자용)
     */
    @GetMapping
    public ResponseEntity<Map<String, Object>> getAllDocuments() {
        try {
            logger.debug("전체 서류 목록 조회 요청");
            List<Document> documents = documentService.getAllDocuments();

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("documents", documents);
            response.put("count", documents.size());

            logger.debug("전체 서류 조회 완료: {} 건", documents.size());
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            logger.error("서류 목록 조회 실패", e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "서류 목록 조회 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 사용자별 서류 조회
     */
    @GetMapping("/user/{writerId}")
    public ResponseEntity<Map<String, Object>> getUserDocuments(@PathVariable String writerId) {
        try {
            logger.debug("사용자별 서류 조회 요청: {}", writerId);
            List<Document> documents = documentService.getUserDocuments(writerId);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("documents", documents);
            response.put("count", documents.size());

            logger.debug("사용자 서류 조회 완료: {} 건", documents.size());
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            logger.error("사용자 서류 조회 실패: {}", writerId, e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "사용자 서류 조회 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 특정 서류 조회
     */
    @GetMapping("/{id}")
    public ResponseEntity<Map<String, Object>> getDocumentById(@PathVariable Long id) {
        try {
            logger.debug("특정 서류 조회 요청: ID {}", id);
            Document document = documentService.getDocumentById(id);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("document", document);

            logger.debug("서류 조회 완료: ID {}", id);
            return ResponseEntity.ok(response);
        } catch (RuntimeException e) {
            logger.warn("서류를 찾을 수 없음: ID {}", id);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", e.getMessage());

            return ResponseEntity.notFound().build();
        } catch (Exception e) {
            logger.error("서류 조회 실패: ID {}", id, e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "서류 조회 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 서류 제출 - JSON과 Form-data 모두 지원하는 범용 메서드
     */
    @PostMapping
    public ResponseEntity<Map<String, Object>> submitDocument(
            HttpServletRequest request,
            @RequestParam(value = "title", required = false) String titleParam,
            @RequestParam(value = "content", required = false) String contentParam,
            @RequestParam(value = "category", required = false) String categoryParam,
            @RequestParam(value = "writerId", required = false) String writerIdParam,
            @RequestParam(value = "writerName", required = false) String writerNameParam,
            @RequestParam(value = "file", required = false) MultipartFile file) {

        try {
            logger.info("=== 서류 제출 요청 시작 (Universal) ===");

            String title, content, category, writerId, writerName;

            // Content-Type 확인하여 처리 방식 결정
            String contentType = request.getContentType();

            if (contentType != null && contentType.contains("application/json")) {
                // JSON 요청 처리
                logger.debug("JSON 형태 요청 감지");

                try {
                    // JSON 데이터 읽기
                    StringBuilder jsonString = new StringBuilder();
                    String line;
                    while ((line = request.getReader().readLine()) != null) {
                        jsonString.append(line);
                    }

                    // JSON 파싱
                    ObjectMapper objectMapper = new ObjectMapper();
                    Map<String, String> jsonData = objectMapper.readValue(
                            jsonString.toString(),
                            new TypeReference<Map<String, String>>() {}
                    );

                    title = jsonData.get("title");
                    content = jsonData.get("content");
                    category = jsonData.get("category");
                    writerId = jsonData.get("writerId");
                    writerName = jsonData.get("writerName");

                } catch (Exception e) {
                    logger.error("JSON 파싱 실패", e);
                    Map<String, Object> errorResponse = new HashMap<>();
                    errorResponse.put("success", false);
                    errorResponse.put("message", "JSON 데이터 파싱 실패: " + e.getMessage());
                    return ResponseEntity.badRequest().body(errorResponse);
                }
            } else {
                // Form-data 요청 처리
                logger.debug("Form-data 형태 요청 감지");
                title = titleParam;
                content = contentParam;
                category = categoryParam;
                writerId = writerIdParam;
                writerName = writerNameParam;
            }

            logger.info("제목: {}, 카테고리: {}, 작성자ID: {}", title, category, writerId);

            // 필수 데이터 검증
            if (title == null || content == null || category == null || writerId == null) {
                Map<String, Object> errorResponse = new HashMap<>();
                errorResponse.put("success", false);
                errorResponse.put("message", "필수 데이터가 누락되었습니다. (title, content, category, writerId)");
                return ResponseEntity.badRequest().body(errorResponse);
            }

            // 인증 정보 확인
            Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
            if (authentication == null || !authentication.isAuthenticated()) {
                logger.warn("인증되지 않은 사용자의 서류 제출 시도");
                Map<String, Object> errorResponse = new HashMap<>();
                errorResponse.put("success", false);
                errorResponse.put("message", "인증이 필요합니다.");
                errorResponse.put("code", "UNAUTHORIZED");
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(errorResponse);
            }

            String currentUserId = authentication.getName();
            boolean isAdmin = authentication.getAuthorities().stream()
                    .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN"));

            logger.debug("현재 사용자: {}, 관리자 여부: {}", currentUserId, isAdmin);

            // 권한 확인 (관리자가 아닌 경우 본인 서류만 제출 가능)
            if (!isAdmin && !currentUserId.equals(writerId)) {
                logger.warn("사용자 ID 불일치. 현재: {}, 요청: {}", currentUserId, writerId);
                Map<String, Object> errorResponse = new HashMap<>();
                errorResponse.put("success", false);
                errorResponse.put("message", "본인의 서류만 제출할 수 있습니다.");
                errorResponse.put("code", "FORBIDDEN");
                return ResponseEntity.status(HttpStatus.FORBIDDEN).body(errorResponse);
            }

            // JWT 토큰 로깅 (디버깅용)
            String authHeader = request.getHeader("Authorization");
            if (authHeader != null) {
                logger.debug("Authorization 헤더 존재: Bearer ***");
            } else {
                logger.warn("Authorization 헤더 없음");
            }

            // 서류 제출 처리
            Document document = documentService.submitDocument(
                    title, content, category, writerId, writerName, file);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("document", document);
            response.put("message", "서류가 성공적으로 제출되었습니다.");

            logger.info("서류 제출 성공: ID {}", document.getId());
            return ResponseEntity.ok(response);

        } catch (Exception e) {
            logger.error("서류 제출 중 오류 발생", e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "서류 제출 실패: " + e.getMessage());
            errorResponse.put("code", "INTERNAL_ERROR");
            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 서류 제출 - JSON 전용 (백업용)
     */
    @PostMapping("/submit-json")
    public ResponseEntity<Map<String, Object>> submitDocumentJson(
            @RequestBody Map<String, String> request,
            HttpServletRequest httpRequest) {

        try {
            logger.info("=== JSON 형태 서류 제출 시작 ===");

            String title = request.get("title");
            String content = request.get("content");
            String category = request.get("category");
            String writerId = request.get("writerId");
            String writerName = request.get("writerName");

            logger.info("제목: {}, 카테고리: {}, 작성자ID: {}", title, category, writerId);

            // 필수 데이터 검증
            if (title == null || content == null || category == null || writerId == null) {
                Map<String, Object> errorResponse = new HashMap<>();
                errorResponse.put("success", false);
                errorResponse.put("message", "필수 데이터가 누락되었습니다. (title, content, category, writerId)");
                return ResponseEntity.badRequest().body(errorResponse);
            }

            // 인증 정보 확인
            Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
            if (authentication == null || !authentication.isAuthenticated()) {
                logger.warn("인증되지 않은 사용자의 서류 제출 시도");
                Map<String, Object> errorResponse = new HashMap<>();
                errorResponse.put("success", false);
                errorResponse.put("message", "인증이 필요합니다.");
                errorResponse.put("code", "UNAUTHORIZED");
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(errorResponse);
            }

            String currentUserId = authentication.getName();
            boolean isAdmin = authentication.getAuthorities().stream()
                    .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN"));

            logger.debug("현재 사용자: {}, 관리자 여부: {}", currentUserId, isAdmin);

            // 권한 확인
            if (!isAdmin && !currentUserId.equals(writerId)) {
                logger.warn("사용자 ID 불일치. 현재: {}, 요청: {}", currentUserId, writerId);
                Map<String, Object> errorResponse = new HashMap<>();
                errorResponse.put("success", false);
                errorResponse.put("message", "본인의 서류만 제출할 수 있습니다.");
                errorResponse.put("code", "FORBIDDEN");
                return ResponseEntity.status(HttpStatus.FORBIDDEN).body(errorResponse);
            }

            // 서류 제출
            Document document = documentService.submitDocument(
                    title, content, category, writerId, writerName, null);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("document", document);
            response.put("message", "서류가 성공적으로 제출되었습니다.");

            logger.info("JSON 서류 제출 성공: ID {}", document.getId());
            return ResponseEntity.ok(response);

        } catch (Exception e) {
            logger.error("JSON 서류 제출 실패", e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "서류 제출 실패: " + e.getMessage());
            errorResponse.put("code", "INTERNAL_ERROR");
            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 서류 상태 업데이트 (관리자용)
     */
    @PutMapping("/{id}/status")
    public ResponseEntity<Map<String, Object>> updateDocumentStatus(
            @PathVariable Long id,
            @RequestParam("status") String status,
            @RequestParam(value = "adminComment", required = false) String adminComment) {

        try {
            logger.info("서류 상태 업데이트 요청: ID {}, 상태: {}", id, status);
            Document document = documentService.updateDocumentStatus(id, status, adminComment);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("document", document);
            response.put("message", "서류 상태가 성공적으로 변경되었습니다.");

            logger.info("서류 상태 업데이트 완료: ID {}", id);
            return ResponseEntity.ok(response);
        } catch (RuntimeException e) {
            logger.warn("서류 상태 업데이트 실패: ID {}", id);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", e.getMessage());

            return ResponseEntity.notFound().build();
        } catch (Exception e) {
            logger.error("서류 상태 업데이트 오류: ID {}", id, e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "상태 변경 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 서류 삭제 (관리자용)
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, Object>> deleteDocument(@PathVariable Long id) {
        try {
            logger.info("서류 삭제 요청: ID {}", id);
            documentService.deleteDocument(id);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "서류가 성공적으로 삭제되었습니다.");

            logger.info("서류 삭제 완료: ID {}", id);
            return ResponseEntity.ok(response);
        } catch (RuntimeException e) {
            logger.warn("서류 삭제 실패: ID {}", id);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", e.getMessage());

            return ResponseEntity.notFound().build();
        } catch (Exception e) {
            logger.error("서류 삭제 오류: ID {}", id, e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "서류 삭제 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 상태별 서류 조회
     */
    @GetMapping("/status/{status}")
    public ResponseEntity<Map<String, Object>> getDocumentsByStatus(@PathVariable String status) {
        try {
            logger.debug("상태별 서류 조회 요청: {}", status);
            List<Document> documents = documentService.getDocumentsByStatus(status);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("documents", documents);
            response.put("count", documents.size());
            response.put("status", status);

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            logger.error("상태별 서류 조회 실패: {}", status, e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "상태별 서류 조회 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 카테고리별 서류 조회
     */
    @GetMapping("/category/{category}")
    public ResponseEntity<Map<String, Object>> getDocumentsByCategory(@PathVariable String category) {
        try {
            logger.debug("카테고리별 서류 조회 요청: {}", category);
            List<Document> documents = documentService.getDocumentsByCategory(category);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("documents", documents);
            response.put("count", documents.size());
            response.put("category", category);

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            logger.error("카테고리별 서류 조회 실패: {}", category, e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "카테고리별 서류 조회 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 서류 검색
     */
    @GetMapping("/search")
    public ResponseEntity<Map<String, Object>> searchDocuments(@RequestParam String keyword) {
        try {
            logger.debug("서류 검색 요청: {}", keyword);
            List<Document> documents = documentService.searchDocuments(keyword);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("documents", documents);
            response.put("count", documents.size());
            response.put("keyword", keyword);

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            logger.error("서류 검색 실패: {}", keyword, e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "서류 검색 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 긴급 서류 조회 (관리자용)
     */
    @GetMapping("/urgent")
    public ResponseEntity<Map<String, Object>> getUrgentDocuments() {
        try {
            logger.debug("긴급 서류 조회 요청");
            List<Document> documents = documentService.getUrgentDocuments();

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("documents", documents);
            response.put("count", documents.size());

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            logger.error("긴급 서류 조회 실패", e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "긴급 서류 조회 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 서류 통계
     */
    @GetMapping("/statistics")
    public ResponseEntity<Map<String, Object>> getDocumentStatistics() {
        try {
            logger.debug("서류 통계 조회 요청");
            Map<String, Object> statistics = documentService.getDocumentStatistics();

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("statistics", statistics);

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            logger.error("통계 조회 실패", e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "통계 조회 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 내 서류 조회 (현재 로그인한 사용자)
     */
    @GetMapping("/my")
    public ResponseEntity<Map<String, Object>> getMyDocuments() {
        try {
            Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
            if (authentication == null || !authentication.isAuthenticated()) {
                Map<String, Object> errorResponse = new HashMap<>();
                errorResponse.put("success", false);
                errorResponse.put("message", "인증이 필요합니다.");
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(errorResponse);
            }

            String currentUserId = authentication.getName();
            logger.debug("내 서류 조회 요청: {}", currentUserId);

            List<Document> documents = documentService.getUserDocuments(currentUserId);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("documents", documents);
            response.put("count", documents.size());

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            logger.error("내 서류 조회 실패", e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "내 서류 조회 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }
}