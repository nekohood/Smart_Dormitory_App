package com.dormitory.SpringBoot.controller;

import com.dormitory.SpringBoot.domain.Notice;
import com.dormitory.SpringBoot.services.NoticeService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 공지사항 관련 API 컨트롤러
 */
@RestController
@RequestMapping("/api/notices")
@CrossOrigin(origins = "*")
public class NoticeController {

    @Autowired
    private NoticeService noticeService;

    /**
     * 모든 공지사항 조회
     */
    @GetMapping
    public ResponseEntity<Map<String, Object>> getAllNotices() {
        try {
            List<Notice> notices = noticeService.getAllNotices();

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("notices", notices);
            response.put("count", notices.size());

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "공지사항 조회 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 특정 공지사항 조회 (조회수 증가)
     */
    @GetMapping("/{id}")
    public ResponseEntity<Map<String, Object>> getNoticeById(@PathVariable Long id) {
        try {
            Notice notice = noticeService.getNoticeById(id);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("notice", notice);

            return ResponseEntity.ok(response);
        } catch (RuntimeException e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", e.getMessage());

            return ResponseEntity.notFound().build();
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "공지사항 조회 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 최신 공지사항 조회
     */
    @GetMapping("/latest")
    public ResponseEntity<Map<String, Object>> getLatestNotice() {
        try {
            Notice notice = noticeService.getLatestNotice();

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("notice", notice);

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("notice", null);
            response.put("message", "등록된 공지사항이 없습니다.");

            return ResponseEntity.ok(response);
        }
    }

    /**
     * 공지사항 작성 (관리자용)
     */
    @PostMapping
    public ResponseEntity<Map<String, Object>> createNotice(
            @RequestParam("title") String title,
            @RequestParam("content") String content,
            @RequestParam("author") String author,
            @RequestParam(value = "isPinned", defaultValue = "false") Boolean isPinned,
            @RequestParam(value = "file", required = false) MultipartFile file) {

        try {
            Notice notice = noticeService.createNotice(title, content, author, isPinned, file);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("notice", notice);
            response.put("message", "공지사항이 성공적으로 작성되었습니다.");

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "공지사항 작성 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 공지사항 수정 (관리자용)
     */
    @PutMapping("/{id}")
    public ResponseEntity<Map<String, Object>> updateNotice(
            @PathVariable Long id,
            @RequestParam("title") String title,
            @RequestParam("content") String content,
            @RequestParam(value = "isPinned", defaultValue = "false") Boolean isPinned,
            @RequestParam(value = "file", required = false) MultipartFile file) {

        try {
            Notice notice = noticeService.updateNotice(id, title, content, isPinned, file);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("notice", notice);
            response.put("message", "공지사항이 성공적으로 수정되었습니다.");

            return ResponseEntity.ok(response);
        } catch (RuntimeException e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", e.getMessage());

            return ResponseEntity.notFound().build();
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "공지사항 수정 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 공지사항 삭제 (관리자용)
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, Object>> deleteNotice(@PathVariable Long id) {
        try {
            noticeService.deleteNotice(id);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "공지사항이 성공적으로 삭제되었습니다.");

            return ResponseEntity.ok(response);
        } catch (RuntimeException e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", e.getMessage());

            return ResponseEntity.notFound().build();
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "공지사항 삭제 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 공지사항 검색
     */
    @GetMapping("/search")
    public ResponseEntity<Map<String, Object>> searchNotices(@RequestParam String keyword) {
        try {
            List<Notice> notices = noticeService.searchNotices(keyword);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("notices", notices);
            response.put("count", notices.size());
            response.put("keyword", keyword);

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "공지사항 검색 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 공지사항 통계
     */
    @GetMapping("/statistics")
    public ResponseEntity<Map<String, Object>> getNoticeStatistics() {
        try {
            Map<String, Object> statistics = noticeService.getNoticeStatistics();

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

    /**
     * 고정 공지사항 토글
     */
    @PatchMapping("/{id}/pin")
    public ResponseEntity<Map<String, Object>> togglePinNotice(@PathVariable Long id) {
        try {
            Notice notice = noticeService.togglePinNotice(id);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("notice", notice);
            response.put("message", notice.getIsPinned() ? "공지사항이 상단에 고정되었습니다." : "공지사항 고정이 해제되었습니다.");

            return ResponseEntity.ok(response);
        } catch (RuntimeException e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", e.getMessage());

            return ResponseEntity.notFound().build();
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "고정 설정 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }
}