package com.dormitory.SpringBoot.services;

import com.dormitory.SpringBoot.domain.Document;
import com.dormitory.SpringBoot.repository.DocumentRepository;
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
 * 공공서류 비즈니스 로직 서비스
 */
@Service
@Transactional
public class DocumentService {

    @Autowired
    private DocumentRepository documentRepository;

    private final String uploadDirectory = "uploads/documents/";

    /**
     * 모든 서류 조회 (관리자용)
     */
    @Transactional(readOnly = true)
    public List<Document> getAllDocuments() {
        return documentRepository.findAllByOrderBySubmittedAtDesc();
    }

    /**
     * 사용자별 서류 조회
     */
    @Transactional(readOnly = true)
    public List<Document> getUserDocuments(String writerId) {
        return documentRepository.findByWriterIdOrderBySubmittedAtDesc(writerId);
    }

    /**
     * 특정 서류 조회
     */
    @Transactional(readOnly = true)
    public Document getDocumentById(Long id) {
        return documentRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("서류를 찾을 수 없습니다. ID: " + id));
    }

    /**
     * 서류 제출
     */
    @Transactional
    public Document submitDocument(String title, String content, String category,
                                   String writerId, String writerName, MultipartFile file) {
        try {
            Document document = new Document(title, content, category, writerId, writerName);

            // 파일 업로드 처리
            if (file != null && !file.isEmpty()) {
                String imagePath = saveUploadedFile(file);
                document.setImagePath(imagePath);
            }

            return documentRepository.save(document);
        } catch (IOException e) {
            throw new RuntimeException("파일 업로드 실패: " + e.getMessage());
        } catch (Exception e) {
            throw new RuntimeException("서류 제출 실패: " + e.getMessage());
        }
    }

    /**
     * 서류 상태 업데이트 (관리자용)
     */
    @Transactional
    public Document updateDocumentStatus(Long id, String status, String adminComment) {
        try {
            Document document = documentRepository.findById(id)
                    .orElseThrow(() -> new RuntimeException("서류를 찾을 수 없습니다. ID: " + id));

            document.updateStatus(status, adminComment);
            return documentRepository.save(document);
        } catch (Exception e) {
            throw new RuntimeException("서류 상태 업데이트 실패: " + e.getMessage());
        }
    }

    /**
     * 서류 삭제 (관리자용)
     */
    @Transactional
    public void deleteDocument(Long id) {
        try {
            Document document = documentRepository.findById(id)
                    .orElseThrow(() -> new RuntimeException("서류를 찾을 수 없습니다. ID: " + id));

            // 첨부 파일 삭제
            if (document.getImagePath() != null) {
                deleteUploadedFile(document.getImagePath());
            }

            documentRepository.delete(document);
        } catch (Exception e) {
            throw new RuntimeException("서류 삭제 실패: " + e.getMessage());
        }
    }

    /**
     * 상태별 서류 조회
     */
    @Transactional(readOnly = true)
    public List<Document> getDocumentsByStatus(String status) {
        return documentRepository.findByStatusOrderBySubmittedAtDesc(status);
    }

    /**
     * 카테고리별 서류 조회
     */
    @Transactional(readOnly = true)
    public List<Document> getDocumentsByCategory(String category) {
        return documentRepository.findByCategoryOrderBySubmittedAtDesc(category);
    }

    /**
     * 서류 검색
     */
    @Transactional(readOnly = true)
    public List<Document> searchDocuments(String keyword) {
        if (keyword == null || keyword.trim().isEmpty()) {
            return getAllDocuments();
        }
        return documentRepository.findByTitleOrContentContainingIgnoreCase(keyword.trim());
    }

    /**
     * 긴급 서류 조회 (7일 이상 대기)
     */
    @Transactional(readOnly = true)
    public List<Document> getUrgentDocuments() {
        LocalDateTime urgentDate = LocalDateTime.now().minusDays(7);
        return documentRepository.findUrgentDocuments(urgentDate);
    }

    /**
     * 서류 통계
     */
    @Transactional(readOnly = true)
    public Map<String, Object> getDocumentStatistics() {
        Map<String, Object> statistics = new HashMap<>();

        // 전체 서류 수
        long totalDocuments = documentRepository.count();
        statistics.put("totalDocuments", totalDocuments);

        // 상태별 통계
        statistics.put("waitingCount", documentRepository.countByStatus("대기"));
        statistics.put("reviewingCount", documentRepository.countByStatus("검토중"));
        statistics.put("approvedCount", documentRepository.countByStatus("승인"));
        statistics.put("rejectedCount", documentRepository.countByStatus("반려"));

        // 처리 완료/미완료 통계
        statistics.put("completedTotal", documentRepository.countCompletedDocuments());
        statistics.put("pendingTotal", documentRepository.countPendingDocuments());

        // 기간별 통계
        statistics.put("todayDocuments", documentRepository.countTodayDocuments());

        LocalDateTime startOfWeek = LocalDateTime.now().minusDays(7);
        statistics.put("thisWeekDocuments", documentRepository.countThisWeekDocuments(startOfWeek));

        LocalDateTime startOfMonth = LocalDateTime.now().minusDays(30);
        statistics.put("thisMonthDocuments", documentRepository.countThisMonthDocuments(startOfMonth));

        // 긴급 서류 수
        statistics.put("urgentDocuments", getUrgentDocuments().size());

        // 평균 처리 시간
        Double avgProcessingTime = documentRepository.getAverageProcessingTimeInHours();
        statistics.put("averageProcessingHours", avgProcessingTime != null ? avgProcessingTime : 0.0);

        // 카테고리별 통계
        List<Object[]> categoryStats = documentRepository.getCategoryStatistics();
        Map<String, Long> categoryMap = new HashMap<>();
        for (Object[] stat : categoryStats) {
            categoryMap.put((String) stat[0], (Long) stat[1]);
        }
        statistics.put("categoryStatistics", categoryMap);

        return statistics;
    }

    /**
     * 사용자별 특정 상태 서류 조회
     */
    @Transactional(readOnly = true)
    public List<Document> getUserDocumentsByStatus(String writerId, String status) {
        return documentRepository.findByWriterIdAndStatusOrderBySubmittedAtDesc(writerId, status);
    }

    /**
     * 최근 서류 조회
     */
    @Transactional(readOnly = true)
    public List<Document> getRecentDocuments(int days) {
        LocalDateTime since = LocalDateTime.now().minusDays(days);
        return documentRepository.findBySubmittedAtAfterOrderBySubmittedAtDesc(since);
    }

    /**
     * 월별 통계 조회
     */
    @Transactional(readOnly = true)
    public List<Object[]> getMonthlyStatistics(int months) {
        LocalDateTime since = LocalDateTime.now().minusMonths(months);
        return documentRepository.getMonthlyStatistics(since);
    }

    /**
     * 월별 승인률 조회 (단순 버전)
     */
    @Transactional(readOnly = true)
    public Map<String, Double> getMonthlyApprovalRateSimple(int months) {
        Map<String, Double> monthlyRates = new HashMap<>();

        try {
            for (int i = 0; i < months; i++) {
                LocalDateTime startOfMonth = LocalDateTime.now().minusMonths(i + 1);

                // 해당 월의 모든 처리된 서류 조회
                List<Document> allDocs = documentRepository.findBySubmittedAtAfterOrderBySubmittedAtDesc(startOfMonth);
                List<Document> monthlyDocs = allDocs.stream()
                        .filter(d -> d.getSubmittedAt().getMonthValue() == startOfMonth.getMonthValue() + 1)
                        .filter(d -> "승인".equals(d.getStatus()) || "반려".equals(d.getStatus()))
                        .toList();

                if (!monthlyDocs.isEmpty()) {
                    long approved = monthlyDocs.stream()
                            .mapToLong(d -> "승인".equals(d.getStatus()) ? 1 : 0)
                            .sum();
                    double rate = (approved * 100.0) / monthlyDocs.size();
                    String monthKey = startOfMonth.getYear() + "-" + String.format("%02d", startOfMonth.getMonthValue() + 1);
                    monthlyRates.put(monthKey, rate);
                }
            }
        } catch (Exception e) {
            System.err.println("월별 승인률 계산 실패: " + e.getMessage());
        }

        return monthlyRates;
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