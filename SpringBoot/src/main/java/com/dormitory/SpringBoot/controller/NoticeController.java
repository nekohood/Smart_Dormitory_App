package com.dormitory.SpringBoot.controller;

import com.dormitory.SpringBoot.domain.Notice;
import com.dormitory.SpringBoot.services.NoticeService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 공지사항 관련 API 컨트롤러
 * ✅ 수정: 관리자 권한 명시적 설정 + PUT 요청 multipart 지원
 */
@RestController
@RequestMapping("/api/notices")
@CrossOrigin(origins = "*")
public class NoticeController {

    private static final Logger logger = LoggerFactory.getLogger(NoticeController.class);

    @Autowired
    private NoticeService noticeService;

    /**
     * 모든 공지사항 조회 (모든 사용자)
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
            logger.error("공지사항 목록 조회 실패", e);
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
            logger.error("공지사항 조회 실패 - ID: {}", id, e);
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
     * ✅ 관리자 권한 필요
     */
    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Map<String, Object>> createNotice(
            @RequestParam("title") String title,
            @RequestParam("content") String content,
            @RequestParam("author") String author,
            @RequestParam(value = "isPinned", defaultValue = "false") Boolean isPinned,
            @RequestParam(value = "file", required = false) MultipartFile file) {

        try {
            logger.info("공지사항 작성 요청 - 제목: {}, 작성자: {}", title, author);

            Notice notice = noticeService.createNotice(title, content, author, isPinned, file);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("notice", notice);
            response.put("message", "공지사항이 성공적으로 작성되었습니다.");

            logger.info("공지사항 작성 완료 - ID: {}", notice.getId());
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            logger.error("공지사항 작성 실패", e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "공지사항 작성 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 공지사항 수정 (관리자용) - PUT 요청
     * ✅ 관리자 권한 필요
     */
    @PutMapping(value = "/{id}", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Map<String, Object>> updateNotice(
            @PathVariable Long id,
            @RequestParam("title") String title,
            @RequestParam("content") String content,
            @RequestParam(value = "isPinned", defaultValue = "false") Boolean isPinned,
            @RequestParam(value = "file", required = false) MultipartFile file) {

        try {
            logger.info("공지사항 수정 요청 - ID: {}, 제목: {}", id, title);

            Notice notice = noticeService.updateNotice(id, title, content, isPinned, file);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("notice", notice);
            response.put("message", "공지사항이 성공적으로 수정되었습니다.");

            logger.info("공지사항 수정 완료 - ID: {}", id);
            return ResponseEntity.ok(response);
        } catch (RuntimeException e) {
            logger.warn("공지사항 수정 실패 - ID: {}, 사유: {}", id, e.getMessage());
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", e.getMessage());

            return ResponseEntity.notFound().build();
        } catch (Exception e) {
            logger.error("공지사항 수정 실패 - ID: {}", id, e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "공지사항 수정 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 공지사항 수정 (관리자용) - POST 요청 (파일 업로드 호환용)
     * ✅ PUT이 multipart를 지원하지 않는 클라이언트를 위한 대체 엔드포인트
     */
    @PostMapping(value = "/{id}", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Map<String, Object>> updateNoticeViaPost(
            @PathVariable Long id,
            @RequestParam("title") String title,
            @RequestParam("content") String content,
            @RequestParam(value = "isPinned", defaultValue = "false") Boolean isPinned,
            @RequestParam(value = "file", required = false) MultipartFile file) {

        // PUT과 동일한 로직 수행
        return updateNotice(id, title, content, isPinned, file);
    }

    /**
     * 공지사항 삭제 (관리자용)
     * ✅ 관리자 권한 필요
     */
    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Map<String, Object>> deleteNotice(@PathVariable Long id) {
        try {
            logger.info("공지사항 삭제 요청 - ID: {}", id);

            noticeService.deleteNotice(id);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "공지사항이 성공적으로 삭제되었습니다.");

            logger.info("공지사항 삭제 완료 - ID: {}", id);
            return ResponseEntity.ok(response);
        } catch (RuntimeException e) {
            logger.warn("공지사항 삭제 실패 - ID: {}, 사유: {}", id, e.getMessage());
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", e.getMessage());

            return ResponseEntity.notFound().build();
        } catch (Exception e) {
            logger.error("공지사항 삭제 실패 - ID: {}", id, e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "공지사항 삭제 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 공지사항 고정/해제 토글 (관리자용)
     * ✅ 관리자 권한 필요
     */
    @PutMapping("/{id}/pin")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Map<String, Object>> togglePinNotice(@PathVariable Long id) {
        try {
            logger.info("공지사항 고정 토글 요청 - ID: {}", id);

            Notice notice = noticeService.togglePinNotice(id);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("notice", notice);
            response.put("message", notice.getIsPinned() ? "공지사항이 고정되었습니다." : "공지사항 고정이 해제되었습니다.");

            return ResponseEntity.ok(response);
        } catch (RuntimeException e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", e.getMessage());

            return ResponseEntity.notFound().build();
        } catch (Exception e) {
            logger.error("공지사항 고정 토글 실패 - ID: {}", id, e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "공지사항 고정 상태 변경 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 공지사항 검색
     */
    @GetMapping("/search")
    public ResponseEntity<Map<String, Object>> searchNotices(@RequestParam("keyword") String keyword) {
        try {
            List<Notice> notices = noticeService.searchNotices(keyword);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("notices", notices);
            response.put("count", notices.size());
            response.put("keyword", keyword);

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            logger.error("공지사항 검색 실패 - 키워드: {}", keyword, e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "공지사항 검색 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * 공지사항 통계 (관리자용)
     * ✅ 관리자 권한 필요
     */
    @GetMapping("/statistics")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Map<String, Object>> getNoticeStatistics() {
        try {
            Map<String, Object> statistics = noticeService.getNoticeStatistics();

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("statistics", statistics);

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            logger.error("공지사항 통계 조회 실패", e);
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "통계 조회 실패: " + e.getMessage());

            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }
}