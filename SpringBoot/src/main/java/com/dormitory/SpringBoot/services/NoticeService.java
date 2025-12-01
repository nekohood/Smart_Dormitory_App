package com.dormitory.SpringBoot.services;

import com.dormitory.SpringBoot.domain.Notice;
import com.dormitory.SpringBoot.repository.NoticeRepository;
import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
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
 * ✅ 수정: Railway Volume 경로 지원 + 조회수 증가 시 updated_at 변경 안함
 */
@Service
@Transactional
public class NoticeService {

    @Autowired
    private NoticeRepository noticeRepository;

    @Value("${file.upload.path:/app/uploads}")
    private String configuredUploadPath;

    // 실제 사용할 업로드 경로 (런타임에 결정)
    private String uploadBasePath;
    private String noticeUploadDirectory;

    /**
     * 서비스 초기화 시 업로드 경로 설정
     */
    @PostConstruct
    public void init() {
        this.uploadBasePath = resolveUploadPath();
        this.noticeUploadDirectory = uploadBasePath + "/notices/";

        // 디렉토리 생성
        ensureDirectoryExists(noticeUploadDirectory);

        System.out.println("[NoticeService] 업로드 기본 경로: " + uploadBasePath);
        System.out.println("[NoticeService] 공지사항 업로드 경로: " + noticeUploadDirectory);
    }

    /**
     * 업로드 경로 결정
     */
    private String resolveUploadPath() {
        // 1. 환경변수 확인
        String envPath = System.getenv("FILE_UPLOAD_PATH");
        if (envPath != null && !envPath.isEmpty()) {
            return envPath;
        }

        // 2. Railway Volume 경로 확인
        File railwayVolume = new File("/app/uploads");
        if (railwayVolume.exists() || isRunningOnRailway()) {
            return "/app/uploads";
        }

        // 3. 로컬 개발 환경
        return System.getProperty("user.dir") + "/uploads";
    }

    /**
     * Railway 환경인지 확인
     */
    private boolean isRunningOnRailway() {
        return System.getenv("RAILWAY_ENVIRONMENT") != null ||
                System.getenv("RAILWAY_PROJECT_ID") != null;
    }

    /**
     * 디렉토리가 없으면 생성
     */
    private void ensureDirectoryExists(String path) {
        try {
            Path dirPath = Paths.get(path);
            if (!Files.exists(dirPath)) {
                Files.createDirectories(dirPath);
                System.out.println("[NoticeService] 디렉토리 생성: " + path);
            }
        } catch (IOException e) {
            System.err.println("[NoticeService] 디렉토리 생성 실패: " + path + " - " + e.getMessage());
        }
    }

    /**
     * 모든 공지사항 조회 (고정 공지사항 우선)
     */
    @Transactional(readOnly = true)
    public List<Notice> getAllNotices() {
        return noticeRepository.findAllOrderByPinnedAndCreatedAt();
    }

    /**
     * ✅ 수정: 특정 공지사항 조회 및 조회수 증가
     * Native Query를 사용하여 updated_at은 변경하지 않음
     */
    @Transactional
    public Notice getNoticeById(Long id) {
        // 1. 먼저 공지사항 존재 여부 확인
        if (!noticeRepository.existsById(id)) {
            throw new RuntimeException("공지사항을 찾을 수 없습니다. ID: " + id);
        }

        // 2. Native Query로 조회수만 증가 (updated_at은 변경되지 않음)
        noticeRepository.incrementViewCountOnly(id);

        // 3. 증가된 조회수를 반영하여 조회
        return noticeRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("공지사항을 찾을 수 없습니다. ID: " + id));
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
     * ✅ 이 경우에만 updated_at이 갱신됨 (관리자가 내용 수정 시)
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
            long totalNotices = noticeRepository.count();
            statistics.put("totalNotices", totalNotices);

            long pinnedNotices = noticeRepository.findByIsPinnedTrueOrderByCreatedAtDesc().size();
            statistics.put("pinnedNotices", pinnedNotices);

            long todayNotices = noticeRepository.countTodayNotices();
            statistics.put("todayNotices", todayNotices);

            LocalDateTime startOfWeek = LocalDateTime.now().minusDays(7);
            long thisWeekNotices = noticeRepository.countThisWeekNotices(startOfWeek);
            statistics.put("thisWeekNotices", thisWeekNotices);

            LocalDateTime startOfMonth = LocalDateTime.now().minusDays(30);
            long thisMonthNotices = noticeRepository.countThisMonthNotices(startOfMonth);
            statistics.put("thisMonthNotices", thisMonthNotices);

            long highViewNotices = noticeRepository.countByViewCountGreaterThanEqual(100);
            statistics.put("highViewNotices", highViewNotices);

        } catch (Exception e) {
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
     * ✅ 수정: 동적 경로 사용
     */
    private String saveUploadedFile(MultipartFile file) throws IOException {
        // 업로드 디렉토리 확인/생성
        ensureDirectoryExists(noticeUploadDirectory);

        // 파일명 생성 (UUID + 원본 확장자)
        String originalFilename = file.getOriginalFilename();
        String extension = "";
        if (originalFilename != null && originalFilename.contains(".")) {
            extension = originalFilename.substring(originalFilename.lastIndexOf("."));
        }
        String newFilename = UUID.randomUUID().toString() + extension;

        // 파일 저장 (절대 경로)
        Path filePath = Paths.get(noticeUploadDirectory, newFilename);
        Files.copy(file.getInputStream(), filePath);

        System.out.println("[NoticeService] 파일 저장 완료: " + filePath);

        // DB에 저장할 상대 경로 반환 (URL 매핑용)
        return "uploads/notices/" + newFilename;
    }

    /**
     * 업로드된 파일 삭제
     * ✅ 수정: 동적 경로 사용
     */
    private void deleteUploadedFile(String relativePath) {
        try {
            if (relativePath != null && !relativePath.isEmpty()) {
                // 상대 경로에서 실제 파일 경로 생성
                String actualPath;
                if (relativePath.startsWith("uploads/")) {
                    // "uploads/notices/xxx.jpg" -> "/app/uploads/notices/xxx.jpg"
                    actualPath = uploadBasePath + "/" + relativePath.substring("uploads/".length());
                } else {
                    actualPath = uploadBasePath + "/" + relativePath;
                }

                Path path = Paths.get(actualPath);
                if (Files.deleteIfExists(path)) {
                    System.out.println("[NoticeService] 파일 삭제 완료: " + actualPath);
                }
            }
        } catch (IOException e) {
            System.err.println("[NoticeService] 파일 삭제 실패: " + relativePath + " - " + e.getMessage());
        }
    }
}