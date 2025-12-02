package com.dormitory.SpringBoot.controller;

import com.dormitory.SpringBoot.domain.Complaint;
import com.dormitory.SpringBoot.dto.ApiResponse;
import com.dormitory.SpringBoot.services.ComplaintService;
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
 * 민원 관련 API 컨트롤러 - JSON과 Form-data 모두 지원
 * ✅ 수정: 관리자 권한 추가, PATCH 메서드 지원
 */
@RestController
@RequestMapping("/api/complaints")
@CrossOrigin(origins = "*")
public class ComplaintController {

    private static final Logger logger = LoggerFactory.getLogger(ComplaintController.class);

    @Autowired
    private ComplaintService complaintService;

    /**
     * 모든 민원 조회 (관리자용)
     */
    @GetMapping
    public ResponseEntity<ApiResponse<?>> getAllComplaints() {
        try {
            List<Complaint> complaints = complaintService.getAllComplaints();

            Map<String, Object> data = new HashMap<>();
            data.put("complaints", complaints);
            data.put("count", complaints.size());

            return ResponseEntity.ok(ApiResponse.success("민원 목록 조회 성공", data));
        } catch (Exception e) {
            return ResponseEntity.internalServerError()
                    .body(ApiResponse.internalServerError("민원 목록 조회 실패: " + e.getMessage()));
        }
    }

    /**
     * 사용자별 민원 조회
     */
    @GetMapping("/user/{writerId}")
    public ResponseEntity<ApiResponse<?>> getUserComplaints(@PathVariable String writerId) {
        try {
            List<Complaint> complaints = complaintService.getUserComplaints(writerId);

            Map<String, Object> data = new HashMap<>();
            data.put("complaints", complaints);
            data.put("count", complaints.size());

            return ResponseEntity.ok(ApiResponse.success("사용자 민원 조회 성공", data));
        } catch (Exception e) {
            return ResponseEntity.internalServerError()
                    .body(ApiResponse.internalServerError("사용자 민원 조회 실패: " + e.getMessage()));
        }
    }

    /**
     * 특정 민원 조회
     */
    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<?>> getComplaintById(@PathVariable Long id) {
        try {
            Complaint complaint = complaintService.getComplaintById(id);
            return ResponseEntity.ok(ApiResponse.success("민원 조회 성공", complaint));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.notFound(e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.internalServerError()
                    .body(ApiResponse.internalServerError("민원 조회 실패: " + e.getMessage()));
        }
    }

    /**
     * 민원 제출 - JSON과 Form-data 모두 지원
     */
    @PostMapping
    public ResponseEntity<ApiResponse<?>> submitComplaint(
            HttpServletRequest request,
            @RequestParam(value = "title", required = false) String titleParam,
            @RequestParam(value = "content", required = false) String contentParam,
            @RequestParam(value = "category", required = false) String categoryParam,
            @RequestParam(value = "writerId", required = false) String writerIdParam,
            @RequestParam(value = "writerName", required = false) String writerNameParam,
            @RequestParam(value = "file", required = false) MultipartFile file) {

        try {
            logger.info("=== 민원 제출 요청 시작 ===");

            String title, content, category, writerId, writerName;

            // Content-Type 확인하여 처리 방식 결정
            String contentType = request.getContentType();
            logger.debug("Content-Type: {}", contentType);

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

                    logger.debug("받은 JSON: {}", jsonString.toString());

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
                    return ResponseEntity.badRequest()
                            .body(ApiResponse.error("JSON 데이터 파싱 실패: " + e.getMessage()));
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
                return ResponseEntity.badRequest()
                        .body(ApiResponse.error("필수 데이터가 누락되었습니다. (title, content, category, writerId)"));
            }

            // 민원 제출
            Complaint complaint = complaintService.submitComplaint(
                    title, content, category, writerId, writerName, file);

            return ResponseEntity.ok(ApiResponse.success("민원이 성공적으로 제출되었습니다.", complaint));

        } catch (Exception e) {
            logger.error("민원 제출 중 오류 발생", e);
            return ResponseEntity.internalServerError()
                    .body(ApiResponse.internalServerError("민원 제출 실패: " + e.getMessage()));
        }
    }

    /**
     * 민원 상태 업데이트 (관리자용) - PUT 방식 (RequestParam)
     * ✅ 관리자 권한 필요
     */
    @PutMapping("/{id}/status")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<?>> updateComplaintStatus(
            @PathVariable Long id,
            @RequestParam("status") String status,
            @RequestParam(value = "adminComment", required = false) String adminComment) {

        try {
            logger.info("민원 상태 업데이트 (PUT) - ID: {}, 상태: {}", id, status);
            Complaint complaint = complaintService.updateComplaintStatus(id, status, adminComment);
            return ResponseEntity.ok(ApiResponse.success("민원 상태가 성공적으로 변경되었습니다.", complaint));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.notFound(e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.internalServerError()
                    .body(ApiResponse.internalServerError("상태 변경 실패: " + e.getMessage()));
        }
    }

    /**
     * 민원 상태 업데이트 (관리자용) - PATCH 방식 (JSON Body)
     * ✅ 신규 추가: 프론트엔드 PATCH 요청 지원
     * ✅ 관리자 권한 필요
     */
    @PatchMapping("/{id}/status")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<?>> patchComplaintStatus(
            @PathVariable Long id,
            @RequestBody Map<String, String> request) {

        try {
            String status = request.get("status");
            String adminComment = request.get("adminComment");

            logger.info("민원 상태 업데이트 (PATCH) - ID: {}, 상태: {}", id, status);

            if (status == null || status.trim().isEmpty()) {
                return ResponseEntity.badRequest()
                        .body(ApiResponse.error("상태 값이 필요합니다."));
            }

            Complaint complaint = complaintService.updateComplaintStatus(id, status, adminComment);
            return ResponseEntity.ok(ApiResponse.success("민원 상태가 성공적으로 변경되었습니다.", complaint));
        } catch (RuntimeException e) {
            logger.warn("민원 상태 업데이트 실패 - ID: {}, 사유: {}", id, e.getMessage());
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.notFound(e.getMessage()));
        } catch (Exception e) {
            logger.error("민원 상태 업데이트 중 오류 발생 - ID: {}", id, e);
            return ResponseEntity.internalServerError()
                    .body(ApiResponse.internalServerError("상태 변경 실패: " + e.getMessage()));
        }
    }

    /**
     * 민원 삭제 (관리자용)
     * ✅ 관리자 권한 필요
     */
    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<?>> deleteComplaint(@PathVariable Long id) {
        try {
            logger.info("민원 삭제 요청 - ID: {}", id);
            complaintService.deleteComplaint(id);
            return ResponseEntity.ok(ApiResponse.success("민원이 성공적으로 삭제되었습니다.", null));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.notFound(e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.internalServerError()
                    .body(ApiResponse.internalServerError("민원 삭제 실패: " + e.getMessage()));
        }
    }

    /**
     * 상태별 민원 조회
     */
    @GetMapping("/status/{status}")
    public ResponseEntity<ApiResponse<?>> getComplaintsByStatus(@PathVariable String status) {
        try {
            List<Complaint> complaints = complaintService.getComplaintsByStatus(status);

            Map<String, Object> data = new HashMap<>();
            data.put("complaints", complaints);
            data.put("count", complaints.size());
            data.put("status", status);

            return ResponseEntity.ok(ApiResponse.success("상태별 민원 조회 성공", data));
        } catch (Exception e) {
            return ResponseEntity.internalServerError()
                    .body(ApiResponse.internalServerError("상태별 민원 조회 실패: " + e.getMessage()));
        }
    }

    /**
     * 카테고리별 민원 조회
     */
    @GetMapping("/category/{category}")
    public ResponseEntity<ApiResponse<?>> getComplaintsByCategory(@PathVariable String category) {
        try {
            List<Complaint> complaints = complaintService.getComplaintsByCategory(category);

            Map<String, Object> data = new HashMap<>();
            data.put("complaints", complaints);
            data.put("count", complaints.size());
            data.put("category", category);

            return ResponseEntity.ok(ApiResponse.success("카테고리별 민원 조회 성공", data));
        } catch (Exception e) {
            return ResponseEntity.internalServerError()
                    .body(ApiResponse.internalServerError("카테고리별 민원 조회 실패: " + e.getMessage()));
        }
    }

    /**
     * 민원 검색
     */
    @GetMapping("/search")
    public ResponseEntity<ApiResponse<?>> searchComplaints(@RequestParam String keyword) {
        try {
            List<Complaint> complaints = complaintService.searchComplaints(keyword);

            Map<String, Object> data = new HashMap<>();
            data.put("complaints", complaints);
            data.put("count", complaints.size());
            data.put("keyword", keyword);

            return ResponseEntity.ok(ApiResponse.success("민원 검색 성공", data));
        } catch (Exception e) {
            return ResponseEntity.internalServerError()
                    .body(ApiResponse.internalServerError("민원 검색 실패: " + e.getMessage()));
        }
    }

    /**
     * 긴급 민원 조회 (3일 이상 대기)
     */
    @GetMapping("/urgent")
    public ResponseEntity<ApiResponse<?>> getUrgentComplaints() {
        try {
            List<Complaint> complaints = complaintService.getUrgentComplaints();

            Map<String, Object> data = new HashMap<>();
            data.put("complaints", complaints);
            data.put("count", complaints.size());

            return ResponseEntity.ok(ApiResponse.success("긴급 민원 조회 성공", data));
        } catch (Exception e) {
            return ResponseEntity.internalServerError()
                    .body(ApiResponse.internalServerError("긴급 민원 조회 실패: " + e.getMessage()));
        }
    }

    /**
     * 민원 통계 조회 (관리자용)
     */
    @GetMapping("/statistics")
    public ResponseEntity<ApiResponse<?>> getComplaintStatistics() {
        try {
            Map<String, Object> statistics = complaintService.getComplaintStatistics();
            return ResponseEntity.ok(ApiResponse.success("민원 통계 조회 성공", statistics));
        } catch (Exception e) {
            return ResponseEntity.internalServerError()
                    .body(ApiResponse.internalServerError("민원 통계 조회 실패: " + e.getMessage()));
        }
    }
}