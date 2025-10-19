package com.dormitory.SpringBoot.services;

import com.dormitory.SpringBoot.domain.Notice;
import com.dormitory.SpringBoot.repository.NoticeRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * 공지사항 비즈니스 로직 서비스
 */
@Service
@Transactional
public class NoticeService {

    @Autowired
    private NoticeRepository noticeRepository;

    private final String uploadDirectory = "uploads/notices/";

    /**
     * 모든 공지사항 조회 (고정 공지사항 우선)
     */
    @Transactional(readOnly = true)
    public List<Notice> getAllNotices() {
        return noticeRepository.findAllOrderByPinnedAndCreatedAt();
    }

    /**
     * 특정 공지사항 조회 및 조회수 증가
     */
    @Transactional
    public Notice getNoticeById(Long id) {
        Notice notice = noticeRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("공지사항을 찾을 수 없습니다. ID: " + id));

        // 조회수 증가
        notice.incrementViewCount();
        return noticeRepository.save(notice);
    }

    /**
     * 최신 공지사항 조회
     */
    @Transactional(readOnly = true)
    public Notice getLatestNotice() {
        return noticeRepository.findFirstByOrderByCreatedAtDesc()
                .orElseThrow(() -> new RuntimeException("등록된 공지사항이 없습니다."));
    }

    /**
     * 공지사항 작성
     */
    @Transactional
    public Notice createNotice(String title, String content, String author, Boolean isPinned, MultipartFile file) {
        try {
            Notice notice = new Notice(title, content, author);
            notice.setIsPinned(isPinned != null ? isPinned : false);

            // 파일 업로드 처리
            if (file != null && !file.isEmpty()) {
                String imagePath = saveUploadedFile(file);
                notice.setImagePath(imagePath);
            }

            return noticeRepository.save(notice);
        } catch (IOException e) {
            throw new RuntimeException("파일 업로드 실패: " + e.getMessage());
        } catch (Exception e) {
            throw new RuntimeException("공지사항 작성 실패: " + e.getMessage());
        }
    }

    /**
     * 공지사항 수정 - 완전한 버전
     */
    @Transactional
    public Notice updateNotice(Long id, String title, String content, Boolean isPinned, MultipartFile file) {
        try {
            Notice notice = noticeRepository.findById(id)
                    .orElseThrow(() -> new RuntimeException("공지사항을 찾을 수 없습니다. ID: " + id));

            notice.setTitle(title);
            notice.setContent(content);
            notice.setIsPinned(isPinned != null ? isPinned : false);

            // 새 파일이 업로드된 경우
            if (file != null && !file.isEmpty()) {
                // 기존 파일 삭제
                if (notice.getImagePath() != null) {
                    deleteUploadedFile(notice.getImagePath());
                }
                // 새 파일 저장
                String imagePath = saveUploadedFile(file);
                notice.setImagePath(imagePath);
            }

            return noticeRepository.save(notice);
        } catch (IOException e) {
            throw new RuntimeException("파일 업로드 실패: " + e.getMessage());
        } catch (Exception e) {
            throw new RuntimeException("공지사항 수정 실패: " + e.getMessage());
        }
    }

    /**
     * 공지사항 삭제
     */
    @Transactional
    public void deleteNotice(Long id) {
        try {
            Notice notice = noticeRepository.findById(id)
                    .orElseThrow(() -> new RuntimeException("공지사항을 찾을 수 없습니다. ID: " + id));

            // 첨부 파일 삭제
            if (notice.getImagePath() != null) {
                deleteUploadedFile(notice.getImagePath());
            }

            noticeRepository.delete(notice);
        } catch (Exception e) {
            throw new RuntimeException("공지사항 삭제 실패: " + e.getMessage());
        }
    }

    /**
     * 공지사항 검색
     */
    @Transactional(readOnly = true)
    public List<Notice> searchNotices(String keyword) {
        if (keyword == null || keyword.trim().isEmpty()) {
            return getAllNotices();
        }
        return noticeRepository.findByTitleOrContentContainingIgnoreCase(keyword.trim());
    }

    /**
     * 고정 공지사항 토글
     */
    @Transactional
    public Notice togglePinNotice(Long id) {
        Notice notice = noticeRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("공지사항을 찾을 수 없습니다. ID: " + id));

        notice.setIsPinned(!notice.getIsPinned());
        return noticeRepository.save(notice);
    }

    /**
     * 공지사항 통계
     */
    @Transactional(readOnly = true)
    public Map<String, Object> getNoticeStatistics() {
        Map<String, Object> statistics = new HashMap<>();

        try {
            // 전체 공지사항 수
            long totalNotices = noticeRepository.count();
            statistics.put("totalNotices", totalNotices);

            // 고정 공지사항 수
            long pinnedNotices = noticeRepository.findByIsPinnedTrueOrderByCreatedAtDesc().size();
            statistics.put("pinnedNotices", pinnedNotices);

            // 오늘 작성된 공지사항 수
            long todayNotices = noticeRepository.countTodayNotices();
            statistics.put("todayNotices", todayNotices);

            // 이번 주 작성된 공지사항 수
            LocalDateTime startOfWeek = LocalDateTime.now().minusDays(7);
            long thisWeekNotices = noticeRepository.countThisWeekNotices(startOfWeek);
            statistics.put("thisWeekNotices", thisWeekNotices);

            // 이번 달 작성된 공지사항 수
            LocalDateTime startOfMonth = LocalDateTime.now().minusDays(30);
            long thisMonthNotices = noticeRepository.countThisMonthNotices(startOfMonth);
            statistics.put("thisMonthNotices", thisMonthNotices);

            // 높은 조회수 공지사항 수 (100회 이상)
            long highViewNotices = noticeRepository.countByViewCountGreaterThanEqual(100);
            statistics.put("highViewNotices", highViewNotices);

        } catch (Exception e) {
            // 통계 조회 실패 시 기본값 설정
            statistics.put("totalNotices", 0L);
            statistics.put("pinnedNotices", 0L);
            statistics.put("todayNotices", 0L);
            statistics.put("thisWeekNotices", 0L);
            statistics.put("thisMonthNotices", 0L);
            statistics.put("highViewNotices", 0L);
            statistics.put("error", "통계 조회 중 오류 발생: " + e.getMessage());
        }

        return statistics;
    }

    /**
     * 작성자별 공지사항 조회
     */
    @Transactional(readOnly = true)
    public List<Notice> getNoticesByAuthor(String author) {
        return noticeRepository.findByAuthorOrderByCreatedAtDesc(author);
    }

    /**
     * 파일 업로드 처리
     */
    private String saveUploadedFile(MultipartFile file) throws IOException {
        // 업로드 디렉토리 생성
        Path uploadPath = Paths.get(uploadDirectory);
        if (!Files.exists(uploadPath)) {
            Files.createDirectories(uploadPath);
        }

        // 파일명 생성 (UUID + 원본 확장자)
        String originalFilename = file.getOriginalFilename();
        String extension = "";
        if (originalFilename != null && originalFilename.contains(".")) {
            extension = originalFilename.substring(originalFilename.lastIndexOf("."));
        }
        String fileName = UUID.randomUUID().toString() + extension;

        // 파일 저장
        Path filePath = uploadPath.resolve(fileName);
        Files.copy(file.getInputStream(), filePath);

        return uploadDirectory + fileName;
    }

    /**
     * 파일 삭제 처리
     */
    private void deleteUploadedFile(String filePath) {
        try {
            Path path = Paths.get(filePath);
            if (Files.exists(path)) {
                Files.delete(path);
            }
        } catch (IOException e) {
            // 파일 삭제 실패는 로그만 남기고 진행
            System.err.println("파일 삭제 실패: " + filePath + " - " + e.getMessage());
        }
    }
}