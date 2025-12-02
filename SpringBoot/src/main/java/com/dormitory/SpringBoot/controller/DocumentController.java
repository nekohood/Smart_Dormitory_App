package com.dormitory.SpringBoot.controller;

import com.dormitory.SpringBoot.domain.Document;
import com.dormitory.SpringBoot.dto.ApiResponse;
import com.dormitory.SpringBoot.services.DocumentService;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 서류 관련 API 컨트롤러
 * ✅ 수정: 관리자 권한 추가, PATCH 메서드 지원
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
            List<Document> documents = documentService.getAllDocuments();

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("documents", documents);
            response.put("count", documents.size());

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
            List<Document> documents = documentService.getUserDocuments(writerId);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("documents", documents);
            response.put("count", documents.size());

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            logger.error("사용자 서류 조회 실패: writerId={}", writerId, e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "서류 조회 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 특정 서류 조회
     */
    @GetMapping("/{id}")
    public ResponseEntity<Map<String, Object>> getDocumentById(@PathVariable Long id) {
        try {
            Document document = documentService.getDocumentById(id);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("document", document);

            return ResponseEntity.ok(response);
        } catch (RuntimeException e) {
            logger.warn("서류 조회 실패: ID {}", id);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", e.getMessage());

            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(errorResponse);
        } catch (Exception e) {
            logger.error("서류 조회 오류: ID {}", id, e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "서류 조회 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 서류 제출 (Form-data)
     */
    @PostMapping
    public ResponseEntity<Map<String, Object>> submitDocument(
            @RequestParam("title") String title,
            @RequestParam("content") String content,
            @RequestParam("category") String category,
            @RequestParam("writerId") String writerId,
            @RequestParam(value = "writerName", required = false) String writerName,
            @RequestParam(value = "file", required = false) MultipartFile file) {

        try {
            logger.info("서류 제출 요청: 제목={}, 카테고리={}, 작성자={}", title, category, writerId);

            Document document = documentService.submitDocument(
                    title, content, category, writerId, writerName, file);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("document", document);
            response.put("message", "서류가 성공적으로 제출되었습니다.");

            logger.info("서류 제출 성공: ID {}", document.getId());
            return ResponseEntity.ok(response);

        } catch (Exception e) {
            logger.error("서류 제출 실패", e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "서류 제출 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 서류 제출 (JSON)
     */
    @PostMapping("/json")
    public ResponseEntity<Map<String, Object>> submitDocumentJson(
            HttpServletRequest request) {

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

            String title = jsonData.get("title");
            String content = jsonData.get("content");
            String category = jsonData.get("category");
            String writerId = jsonData.get("writerId");
            String writerName = jsonData.get("writerName");

            logger.info("JSON 서류 제출 요청: 제목={}, 카테고리={}, 작성자={}", title, category, writerId);

            // 필수 데이터 검증
            if (title == null || content == null || category == null || writerId == null) {
                Map<String, Object> errorResponse = new HashMap<>();
                errorResponse.put("success", false);
                errorResponse.put("message", "필수 데이터가 누락되었습니다.");
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
     * 서류 상태 업데이트 (관리자용) - PUT 방식 (RequestParam)
     * ✅ 관리자 권한 필요
     */
    @PutMapping("/{id}/status")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Map<String, Object>> updateDocumentStatus(
            @PathVariable Long id,
            @RequestParam("status") String status,
            @RequestParam(value = "adminComment", required = false) String adminComment) {

        try {
            logger.info("서류 상태 업데이트 (PUT) - ID: {}, 상태: {}", id, status);
            Document document = documentService.updateDocumentStatus(id, status, adminComment);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("document", document);
            response.put("message", "서류 상태가 성공적으로 변경되었습니다.");

            return ResponseEntity.ok(response);
        } catch (RuntimeException e) {
            logger.warn("서류 상태 업데이트 실패 - ID: {}", id);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", e.getMessage());

            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(errorResponse);
        } catch (Exception e) {
            logger.error("서류 상태 업데이트 오류 - ID: {}", id, e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "상태 변경 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 서류 상태 업데이트 (관리자용) - PATCH 방식 (JSON Body)
     * ✅ 신규 추가: 프론트엔드 PATCH 요청 지원
     * ✅ 관리자 권한 필요
     */
    @PatchMapping("/{id}/status")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Map<String, Object>> patchDocumentStatus(
            @PathVariable Long id,
            @RequestBody Map<String, String> request) {

        try {
            String status = request.get("status");
            String adminComment = request.get("adminComment");

            logger.info("서류 상태 업데이트 (PATCH) - ID: {}, 상태: {}", id, status);

            if (status == null || status.trim().isEmpty()) {
                Map<String, Object> errorResponse = new HashMap<>();
                errorResponse.put("success", false);
                errorResponse.put("message", "상태 값이 필요합니다.");
                return ResponseEntity.badRequest().body(errorResponse);
            }

            Document document = documentService.updateDocumentStatus(id, status, adminComment);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("document", document);
            response.put("message", "서류 상태가 성공적으로 변경되었습니다.");

            return ResponseEntity.ok(response);
        } catch (RuntimeException e) {
            logger.warn("서류 상태 업데이트 실패 - ID: {}, 사유: {}", id, e.getMessage());
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", e.getMessage());

            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(errorResponse);
        } catch (Exception e) {
            logger.error("서류 상태 업데이트 중 오류 발생 - ID: {}", id, e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "상태 변경 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 서류 삭제 (관리자용)
     * ✅ 관리자 권한 필요
     */
    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Map<String, Object>> deleteDocument(@PathVariable Long id) {
        try {
            logger.info("서류 삭제 요청 - ID: {}", id);
            documentService.deleteDocument(id);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "서류가 성공적으로 삭제되었습니다.");

            return ResponseEntity.ok(response);
        } catch (RuntimeException e) {
            logger.warn("서류 삭제 실패 - ID: {}", id);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", e.getMessage());

            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(errorResponse);
        } catch (Exception e) {
            logger.error("서류 삭제 오류 - ID: {}", id, e);
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
            List<Document> documents = documentService.getDocumentsByStatus(status);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("documents", documents);
            response.put("count", documents.size());
            response.put("status", status);

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            logger.error("상태별 서류 조회 실패: status={}", status, e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "서류 조회 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 카테고리별 서류 조회
     */
    @GetMapping("/category/{category}")
    public ResponseEntity<Map<String, Object>> getDocumentsByCategory(@PathVariable String category) {
        try {
            List<Document> documents = documentService.getDocumentsByCategory(category);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("documents", documents);
            response.put("count", documents.size());
            response.put("category", category);

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            logger.error("카테고리별 서류 조회 실패: category={}", category, e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "서류 조회 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 서류 통계 조회 (관리자용)
     */
    @GetMapping("/statistics")
    public ResponseEntity<Map<String, Object>> getDocumentStatistics() {
        try {
            Map<String, Object> statistics = documentService.getDocumentStatistics();

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("data", statistics);

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            logger.error("서류 통계 조회 실패", e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "통계 조회 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }
}