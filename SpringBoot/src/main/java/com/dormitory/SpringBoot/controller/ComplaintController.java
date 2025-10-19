package com.dormitory.SpringBoot.controller;

import com.dormitory.SpringBoot.domain.Complaint;
import com.dormitory.SpringBoot.services.ComplaintService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 민원 관련 API 컨트롤러
 */
@RestController
@RequestMapping("/api/complaints")
@CrossOrigin(origins = "*")
public class ComplaintController {

    @Autowired
    private ComplaintService complaintService;

    /**
     * 모든 민원 조회 (관리자용)
     */
    @GetMapping
    public ResponseEntity<Map<String, Object>> getAllComplaints() {
        try {
            List<Complaint> complaints = complaintService.getAllComplaints();

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("complaints", complaints);
            response.put("count", complaints.size());

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "민원 목록 조회 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 사용자별 민원 조회
     */
    @GetMapping("/user/{writerId}")
    public ResponseEntity<Map<String, Object>> getUserComplaints(@PathVariable String writerId) {
        try {
            List<Complaint> complaints = complaintService.getUserComplaints(writerId);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("complaints", complaints);
            response.put("count", complaints.size());

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "사용자 민원 조회 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 특정 민원 조회
     */
    @GetMapping("/{id}")
    public ResponseEntity<Map<String, Object>> getComplaintById(@PathVariable Long id) {
        try {
            Complaint complaint = complaintService.getComplaintById(id);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("complaint", complaint);

            return ResponseEntity.ok(response);
        } catch (RuntimeException e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", e.getMessage());

            return ResponseEntity.notFound().build();
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "민원 조회 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 민원 제출
     */
    @PostMapping
    public ResponseEntity<Map<String, Object>> submitComplaint(
            @RequestParam("title") String title,
            @RequestParam("content") String content,
            @RequestParam("category") String category,
            @RequestParam("writerId") String writerId,
            @RequestParam(value = "writerName", required = false) String writerName,
            @RequestParam(value = "file", required = false) MultipartFile file) {

        try {
            Complaint complaint = complaintService.submitComplaint(
                    title, content, category, writerId, writerName, file);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("complaint", complaint);
            response.put("message", "민원이 성공적으로 제출되었습니다.");

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "민원 제출 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 민원 상태 업데이트 (관리자용)
     */
    @PutMapping("/{id}/status")
    public ResponseEntity<Map<String, Object>> updateComplaintStatus(
            @PathVariable Long id,
            @RequestParam("status") String status,
            @RequestParam(value = "adminComment", required = false) String adminComment) {

        try {
            Complaint complaint = complaintService.updateComplaintStatus(id, status, adminComment);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("complaint", complaint);
            response.put("message", "민원 상태가 성공적으로 변경되었습니다.");

            return ResponseEntity.ok(response);
        } catch (RuntimeException e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", e.getMessage());

            return ResponseEntity.notFound().build();
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "상태 변경 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 민원 삭제 (관리자용)
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, Object>> deleteComplaint(@PathVariable Long id) {
        try {
            complaintService.deleteComplaint(id);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "민원이 성공적으로 삭제되었습니다.");

            return ResponseEntity.ok(response);
        } catch (RuntimeException e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", e.getMessage());

            return ResponseEntity.notFound().build();
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "민원 삭제 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 상태별 민원 조회
     */
    @GetMapping("/status/{status}")
    public ResponseEntity<Map<String, Object>> getComplaintsByStatus(@PathVariable String status) {
        try {
            List<Complaint> complaints = complaintService.getComplaintsByStatus(status);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("complaints", complaints);
            response.put("count", complaints.size());
            response.put("status", status);

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "상태별 민원 조회 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 카테고리별 민원 조회
     */
    @GetMapping("/category/{category}")
    public ResponseEntity<Map<String, Object>> getComplaintsByCategory(@PathVariable String category) {
        try {
            List<Complaint> complaints = complaintService.getComplaintsByCategory(category);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("complaints", complaints);
            response.put("count", complaints.size());
            response.put("category", category);

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "카테고리별 민원 조회 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 민원 검색
     */
    @GetMapping("/search")
    public ResponseEntity<Map<String, Object>> searchComplaints(@RequestParam String keyword) {
        try {
            List<Complaint> complaints = complaintService.searchComplaints(keyword);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("complaints", complaints);
            response.put("count", complaints.size());
            response.put("keyword", keyword);

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "민원 검색 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 긴급 민원 조회 (관리자용)
     */
    @GetMapping("/urgent")
    public ResponseEntity<Map<String, Object>> getUrgentComplaints() {
        try {
            List<Complaint> complaints = complaintService.getUrgentComplaints();

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("complaints", complaints);
            response.put("count", complaints.size());

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "긴급 민원 조회 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 민원 통계
     */
    @GetMapping("/statistics")
    public ResponseEntity<Map<String, Object>> getComplaintStatistics() {
        try {
            Map<String, Object> statistics = complaintService.getComplaintStatistics();

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("statistics", statistics);

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "통계 조회 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }
}