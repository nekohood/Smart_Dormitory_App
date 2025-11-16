package com.dormitory.SpringBoot.controller;

import com.dormitory.SpringBoot.domain.Complaint;
import com.dormitory.SpringBoot.dto.ApiResponse; // ✅ ApiResponse 임포트
import com.dormitory.SpringBoot.services.ComplaintService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 민원 관련 API 컨트롤러 - ApiResponse 적용 버전
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
    public ResponseEntity<ApiResponse<?>> getAllComplaints() {
        try {
            List<Complaint> complaints = complaintService.getAllComplaints();

            // ✅ ApiResponse.success 사용
            Map<String, Object> data = new HashMap<>();
            data.put("complaints", complaints);
            data.put("count", complaints.size());

            return ResponseEntity.ok(ApiResponse.success("민원 목록 조회 성공", data));
        } catch (Exception e) {
            // ✅ ApiResponse.internalServerError 사용
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

            // ✅ ApiResponse.success 사용
            Map<String, Object> data = new HashMap<>();
            data.put("complaints", complaints);
            data.put("count", complaints.size());

            return ResponseEntity.ok(ApiResponse.success("사용자 민원 조회 성공", data));
        } catch (Exception e) {
            // ✅ ApiResponse.internalServerError 사용
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
            // ✅ ApiResponse.success 사용 (data로 complaint 객체 바로 전달)
            return ResponseEntity.ok(ApiResponse.success("민원 조회 성공", complaint));
        } catch (RuntimeException e) {
            // ✅ ApiResponse.notFound 사용
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.notFound(e.getMessage()));
        } catch (Exception e) {
            // ✅ ApiResponse.internalServerError 사용
            return ResponseEntity.internalServerError()
                    .body(ApiResponse.internalServerError("민원 조회 실패: " + e.getMessage()));
        }
    }

    /**
     * 민원 제출
     */
    @PostMapping
    public ResponseEntity<ApiResponse<?>> submitComplaint(
            @RequestParam("title") String title,
            @RequestParam("content") String content,
            @RequestParam("category") String category,
            @RequestParam("writerId") String writerId,
            @RequestParam(value = "writerName", required = false) String writerName,
            @RequestParam(value = "file", required = false) MultipartFile file) {

        try {
            Complaint complaint = complaintService.submitComplaint(
                    title, content, category, writerId, writerName, file);

            // ✅ ApiResponse.success 사용
            return ResponseEntity.ok(ApiResponse.success("민원이 성공적으로 제출되었습니다.", complaint));
        } catch (Exception e) {
            // ✅ ApiResponse.internalServerError 사용
            return ResponseEntity.internalServerError()
                    .body(ApiResponse.internalServerError("민원 제출 실패: " + e.getMessage()));
        }
    }

    /**
     * 민원 상태 업데이트 (관리자용)
     */
    @PutMapping("/{id}/status")
    public ResponseEntity<ApiResponse<?>> updateComplaintStatus(
            @PathVariable Long id,
            @RequestParam("status") String status,
            @RequestParam(value = "adminComment", required = false) String adminComment) {

        try {
            Complaint complaint = complaintService.updateComplaintStatus(id, status, adminComment);
            // ✅ ApiResponse.success 사용
            return ResponseEntity.ok(ApiResponse.success("민원 상태가 성공적으로 변경되었습니다.", complaint));
        } catch (RuntimeException e) {
            // ✅ ApiResponse.notFound 사용
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.notFound(e.getMessage()));
        } catch (Exception e) {
            // ✅ ApiResponse.internalServerError 사용
            return ResponseEntity.internalServerError()
                    .body(ApiResponse.internalServerError("상태 변경 실패: " + e.getMessage()));
        }
    }

    /**
     * 민원 삭제 (관리자용)
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<?>> deleteComplaint(@PathVariable Long id) {
        try {
            complaintService.deleteComplaint(id);
            // ✅ ApiResponse.success 사용 (data 없음)
            return ResponseEntity.ok(ApiResponse.success("민원이 성공적으로 삭제되었습니다."));
        } catch (RuntimeException e) {
            // ✅ ApiResponse.notFound 사용
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.notFound(e.getMessage()));
        } catch (Exception e) {
            // ✅ ApiResponse.internalServerError 사용
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

            // ✅ ApiResponse.success 사용
            Map<String, Object> data = new HashMap<>();
            data.put("complaints", complaints);
            data.put("count", complaints.size());
            data.put("status", status);

            return ResponseEntity.ok(ApiResponse.success("상태별 민원 조회 성공", data));
        } catch (Exception e) {
            // ✅ ApiResponse.internalServerError 사용
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

            // ✅ ApiResponse.success 사용
            Map<String, Object> data = new HashMap<>();
            data.put("complaints", complaints);
            data.put("count", complaints.size());
            data.put("category", category);

            return ResponseEntity.ok(ApiResponse.success("카테고리별 민원 조회 성공", data));
        } catch (Exception e) {
            // ✅ ApiResponse.internalServerError 사용
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

            // ✅ ApiResponse.success 사용
            Map<String, Object> data = new HashMap<>();
            data.put("complaints", complaints);
            data.put("count", complaints.size());
            data.put("keyword", keyword);

            return ResponseEntity.ok(ApiResponse.success("민원 검색 성공", data));
        } catch (Exception e) {
            // ✅ ApiResponse.internalServerError 사용
            return ResponseEntity.internalServerError()
                    .body(ApiResponse.internalServerError("민원 검색 실패: " + e.getMessage()));
        }
    }

    /**
     * 긴급 민원 조회 (관리자용)
     */
    @GetMapping("/urgent")
    public ResponseEntity<ApiResponse<?>> getUrgentComplaints() {
        try {
            List<Complaint> complaints = complaintService.getUrgentComplaints();

            // ✅ ApiResponse.success 사용
            Map<String, Object> data = new HashMap<>();
            data.put("complaints", complaints);
            data.put("count", complaints.size());

            return ResponseEntity.ok(ApiResponse.success("긴급 민원 조회 성공", data));
        } catch (Exception e) {
            // ✅ ApiResponse.internalServerError 사용
            return ResponseEntity.internalServerError()
                    .body(ApiResponse.internalServerError("긴급 민원 조회 실패: " + e.getMessage()));
        }
    }

    /**
     * 민원 통계
     */
    @GetMapping("/statistics")
    public ResponseEntity<ApiResponse<?>> getComplaintStatistics() {
        try {
            Map<String, Object> statistics = complaintService.getComplaintStatistics();
            // ✅ ApiResponse.success 사용 (통계 Map을 data로 바로 전달)
            return ResponseEntity.ok(ApiResponse.success("통계 조회 성공", statistics));
        } catch (Exception e) {
            // ✅ ApiResponse.internalServerError 사용
            return ResponseEntity.internalServerError()
                    .body(ApiResponse.internalServerError("통계 조회 실패: " + e.getMessage()));
        }
    }
}