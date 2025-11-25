package com.dormitory.SpringBoot.services;

import com.dormitory.SpringBoot.domain.Document;
import com.dormitory.SpringBoot.domain.User;
import com.dormitory.SpringBoot.repository.DocumentRepository;
import com.dormitory.SpringBoot.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
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
 * 공공서류 비즈니스 로직 서비스 - 완전한 버전 (모든 메서드 포함)
 */
@Service
@Transactional
public class DocumentService {

    private static final Logger logger = LoggerFactory.getLogger(DocumentService.class);

    @Autowired
    private DocumentRepository documentRepository;

    @Autowired
    private UserRepository userRepository; // ✅ 사용자 정보 조회를 위해 추가

    private final String uploadDirectory = "uploads/documents/";

    // =============================================================================
    // 기본 CRUD 메서드들
    // =============================================================================

    /**
     * 모든 서류 조회 (관리자용)
     */
    @Transactional(readOnly = true)
    public List<Document> getAllDocuments() {
        try {
            logger.info("모든 서류 조회");
            return documentRepository.findAllByOrderBySubmittedAtDesc();
        } catch (Exception e) {
            logger.error("모든 서류 조회 실패", e);
            throw new RuntimeException("서류 목록 조회에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 사용자별 서류 조회
     */
    @Transactional(readOnly = true)
    public List<Document> getUserDocuments(String writerId) {
        try {
            logger.info("사용자별 서류 조회 - 사용자ID: {}", writerId);
            return documentRepository.findByWriterIdOrderBySubmittedAtDesc(writerId);
        } catch (Exception e) {
            logger.error("사용자별 서류 조회 실패", e);
            throw new RuntimeException("사용자 서류 조회에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 특정 서류 조회
     */
    @Transactional(readOnly = true)
    public Document getDocumentById(Long id) {
        try {
            logger.info("서류 상세 조회 - ID: {}", id);
            return documentRepository.findById(id)
                    .orElseThrow(() -> new RuntimeException("서류를 찾을 수 없습니다. ID: " + id));
        } catch (Exception e) {
            logger.error("서류 상세 조회 실패", e);
            throw new RuntimeException("서류 조회에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 서류 제출 - ✅ 거주 정보 자동 기입 기능 추가
     */
    @Transactional
    public Document submitDocument(String title, String content, String category,
                                   String writerId, String writerName, MultipartFile file) {
        try {
            logger.info("서류 제출 - 작성자: {}, 제목: {}", writerId, title);

            // ✅ 사용자 정보 조회 (거주 동/방 번호 자동 기입)
            User user = userRepository.findById(writerId)
                    .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다: " + writerId));

            Document document = new Document(title, content, category, writerId, writerName);

            // ✅ 사용자의 거주 동/방 번호 자동 기입
            document.setDormitoryBuilding(user.getDormitoryBuilding());
            document.setRoomNumber(user.getRoomNumber());

            logger.info("서류 제출 - 거주 동: {}, 방 번호: {}",
                    user.getDormitoryBuilding(), user.getRoomNumber());

            // 파일 업로드 처리
            if (file != null && !file.isEmpty()) {
                try {
                    String imagePath = saveUploadedFile(file);
                    document.setImagePath(imagePath);
                    logger.info("서류 파일 업로드 완료: {}", imagePath);
                } catch (Exception e) {
                    logger.warn("서류 파일 업로드 실패: {}", e.getMessage());
                    // 파일 업로드 실패해도 서류 제출은 계속 진행
                }
            }

            document = documentRepository.save(document);
            logger.info("서류 제출 완료 - ID: {}", document.getId());

            return document;

        } catch (Exception e) {
            logger.error("서류 제출 실패", e);
            throw new RuntimeException("서류 제출에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 서류 상태 업데이트 (관리자용)
     */
    @Transactional
    public Document updateDocumentStatus(Long id, String status, String adminComment) {
        try {
            logger.info("서류 상태 업데이트 - ID: {}, 상태: {}", id, status);

            Document document = documentRepository.findById(id)
                    .orElseThrow(() -> new RuntimeException("서류를 찾을 수 없습니다. ID: " + id));

            document.updateStatus(status, adminComment);
            document = documentRepository.save(document);

            logger.info("서류 상태 업데이트 완료 - ID: {}", id);
            return document;

        } catch (Exception e) {
            logger.error("서류 상태 업데이트 실패", e);
            throw new RuntimeException("서류 상태 업데이트에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 서류 삭제 (관리자용)
     */
    @Transactional
    public void deleteDocument(Long id) {
        try {
            logger.info("서류 삭제 - ID: {}", id);

            Document document = documentRepository.findById(id)
                    .orElseThrow(() -> new RuntimeException("서류를 찾을 수 없습니다. ID: " + id));

            // 첨부 파일도 함께 삭제
            if (document.getImagePath() != null && !document.getImagePath().isEmpty()) {
                try {
                    deleteUploadedFile(document.getImagePath());
                    logger.info("서류 첨부 파일 삭제 완료: {}", document.getImagePath());
                } catch (Exception e) {
                    logger.warn("서류 첨부 파일 삭제 실패: {}", e.getMessage());
                }
            }

            documentRepository.delete(document);
            logger.info("서류 삭제 완료 - ID: {}", id);

        } catch (Exception e) {
            logger.error("서류 삭제 실패", e);
            throw new RuntimeException("서류 삭제에 실패했습니다: " + e.getMessage());
        }
    }

    // =============================================================================
    // ✅ 컨트롤러에서 호출하는 추가 메서드들 (누락 방지)
    // =============================================================================

    /**
     * 상태별 서류 조회
     */
    @Transactional(readOnly = true)
    public List<Document> getDocumentsByStatus(String status) {
        try {
            logger.info("상태별 서류 조회 - 상태: {}", status);
            return documentRepository.findByStatusOrderBySubmittedAtDesc(status);
        } catch (Exception e) {
            logger.error("상태별 서류 조회 실패", e);
            throw new RuntimeException("상태별 서류 조회에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 카테고리별 서류 조회
     */
    @Transactional(readOnly = true)
    public List<Document> getDocumentsByCategory(String category) {
        try {
            logger.info("카테고리별 서류 조회 - 카테고리: {}", category);
            return documentRepository.findByCategoryOrderBySubmittedAtDesc(category);
        } catch (Exception e) {
            logger.error("카테고리별 서류 조회 실패", e);
            throw new RuntimeException("카테고리별 서류 조회에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 서류 검색
     */
    @Transactional(readOnly = true)
    public List<Document> searchDocuments(String keyword) {
        try {
            logger.info("서류 검색 - 키워드: {}", keyword);

            if (keyword == null || keyword.trim().isEmpty()) {
                return getAllDocuments();
            }

            return documentRepository.findByTitleOrContentContainingIgnoreCase(keyword.trim());
        } catch (Exception e) {
            logger.error("서류 검색 실패", e);
            throw new RuntimeException("서류 검색에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 긴급 서류 조회 (7일 이상 대기)
     */
    @Transactional(readOnly = true)
    public List<Document> getUrgentDocuments() {
        try {
            logger.info("긴급 서류 조회 (7일 이상 대기)");

            LocalDateTime urgentDate = LocalDateTime.now().minusDays(7);
            return documentRepository.findUrgentDocuments(urgentDate);
        } catch (Exception e) {
            logger.error("긴급 서류 조회 실패", e);
            throw new RuntimeException("긴급 서류 조회에 실패했습니다: " + e.getMessage());
        }
    }

    // =============================================================================
    // 통계 메서드들
    // =============================================================================

    /**
     * 서류 통계 조회
     */
    @Transactional(readOnly = true)
    public Map<String, Object> getDocumentStatistics() {
        try {
            logger.info("서류 통계 조회");

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

            logger.info("서류 통계 조회 완료 - 전체: {}, 대기: {}, 검토중: {}, 승인: {}, 반려: {}",
                    totalDocuments,
                    statistics.get("waitingCount"),
                    statistics.get("reviewingCount"),
                    statistics.get("approvedCount"),
                    statistics.get("rejectedCount"));

            return statistics;

        } catch (Exception e) {
            logger.error("서류 통계 조회 실패", e);
            throw new RuntimeException("서류 통계 조회에 실패했습니다: " + e.getMessage());
        }
    }

    // =============================================================================
    // 파일 관리 메서드들
    // =============================================================================

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
            logger.warn("파일 삭제 실패: {} - {}", filePath, e.getMessage());
        }
    }
}