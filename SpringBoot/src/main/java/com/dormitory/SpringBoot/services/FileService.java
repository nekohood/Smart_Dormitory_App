package com.dormitory.SpringBoot.services;

import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.UUID;

/**
 * 파일 업로드 및 관리를 담당하는 서비스
 * ✅ 수정: Railway Volume 경로 지원 (/app/uploads)
 */
@Service
public class FileService {

    private static final Logger logger = LoggerFactory.getLogger(FileService.class);

    // 허용되는 이미지 파일 확장자
    private static final String[] ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".webp"};

    // 최대 파일 크기 (5MB)
    private static final long MAX_FILE_SIZE = 5 * 1024 * 1024;

    @Value("${file.upload.base-path:uploads}")
    private String configuredUploadPath;

    // ✅ 실제 사용할 업로드 경로 (런타임에 결정)
    private String baseUploadPath;

    /**
     * ✅ 서비스 초기화 시 업로드 경로 설정
     */
    @PostConstruct
    public void init() {
        this.baseUploadPath = resolveUploadPath();
        ensureDirectoryExists(baseUploadPath);
        logger.info("[FileService] 업로드 기본 경로 설정: {}", baseUploadPath);
    }

    /**
     * ✅ 업로드 경로 결정 (Railway Volume 지원)
     */
    private String resolveUploadPath() {
        // 1. 환경변수 FILE_UPLOAD_PATH 확인
        String envPath = System.getenv("FILE_UPLOAD_PATH");
        if (envPath != null && !envPath.isEmpty()) {
            logger.info("[FileService] 환경변수 FILE_UPLOAD_PATH 사용: {}", envPath);
            return envPath;
        }

        // 2. Railway Volume 경로 확인 (/app/uploads)
        File railwayVolume = new File("/app/uploads");
        if (railwayVolume.exists() || isRunningOnRailway()) {
            logger.info("[FileService] Railway Volume 경로 사용: /app/uploads");
            return "/app/uploads";
        }

        // 3. 로컬 개발 환경 (현재 작업 디렉토리)
        String localPath = System.getProperty("user.dir") + "/uploads";
        logger.info("[FileService] 로컬 개발 경로 사용: {}", localPath);
        return localPath;
    }

    /**
     * ✅ Railway 환경인지 확인
     */
    private boolean isRunningOnRailway() {
        return System.getenv("RAILWAY_ENVIRONMENT") != null ||
                System.getenv("RAILWAY_PROJECT_ID") != null;
    }

    /**
     * ✅ 디렉토리가 없으면 생성
     */
    private void ensureDirectoryExists(String path) {
        File dir = new File(path);
        if (!dir.exists()) {
            boolean created = dir.mkdirs();
            logger.info("[FileService] 디렉토리 생성: {} - {}", path, (created ? "성공" : "실패 또는 이미 존재"));
        }
    }

    /**
     * 이미지 파일 업로드
     *
     * @param file 업로드할 파일
     * @param category 파일 카테고리 (inspection, document, room-templates 등)
     * @return 업로드된 파일의 상대 경로
     */
    public String uploadImage(MultipartFile file, String category) {
        try {
            logger.info("파일 업로드 시작 - 카테고리: {}, 파일명: {}, 크기: {}",
                    category, file.getOriginalFilename(), formatFileSize(file.getSize()));

            // 파일 유효성 검사
            validateImageFile(file);

            // 업로드 디렉토리 생성
            String uploadDir = createUploadDirectory(category);

            // 파일명 생성 (중복 방지를 위해 UUID 사용)
            String originalFilename = file.getOriginalFilename();
            String extension = getFileExtension(originalFilename);
            String fileName = generateFileName(extension);

            // 파일 저장
            Path targetPath = Paths.get(uploadDir, fileName);
            Files.copy(file.getInputStream(), targetPath, StandardCopyOption.REPLACE_EXISTING);

            // 상대 경로 반환 (날짜 폴더 포함)
            LocalDateTime now = LocalDateTime.now();
            String datePath = now.format(DateTimeFormatter.ofPattern("yyyy/MM/dd"));
            String relativePath = category + "/" + datePath + "/" + fileName;

            logger.info("파일 업로드 완료: {}", relativePath);
            logger.info("실제 저장 경로: {}", targetPath);
            return relativePath;

        } catch (Exception e) {
            logger.error("파일 업로드 중 오류 발생", e);
            throw new RuntimeException("파일 업로드에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 파일 삭제
     *
     * @param filePath 삭제할 파일 경로 (상대 경로)
     * @return 삭제 성공 여부
     */
    public boolean deleteFile(String filePath) {
        try {
            if (filePath == null || filePath.isEmpty()) {
                logger.warn("삭제할 파일 경로가 비어있습니다");
                return false;
            }

            Path fullPath = Paths.get(baseUploadPath, filePath);

            if (Files.exists(fullPath)) {
                Files.delete(fullPath);
                logger.info("파일 삭제 완료: {}", filePath);
                return true;
            } else {
                logger.warn("삭제할 파일이 존재하지 않습니다: {}", filePath);
                return false;
            }

        } catch (Exception e) {
            logger.error("파일 삭제 중 오류 발생: {}", filePath, e);
            return false;
        }
    }

    /**
     * 파일 존재 여부 확인
     *
     * @param filePath 확인할 파일 경로 (상대 경로)
     * @return 파일 존재 여부
     */
    public boolean fileExists(String filePath) {
        try {
            if (filePath == null || filePath.isEmpty()) {
                return false;
            }

            Path fullPath = Paths.get(baseUploadPath, filePath);
            return Files.exists(fullPath);

        } catch (Exception e) {
            logger.error("파일 존재 여부 확인 중 오류 발생: {}", filePath, e);
            return false;
        }
    }

    /**
     * 파일 전체 경로 반환
     *
     * @param filePath 상대 경로
     * @return 전체 경로
     */
    public String getFullPath(String filePath) {
        if (filePath == null || filePath.isEmpty()) {
            return null;
        }
        return Paths.get(baseUploadPath, filePath).toString();
    }

    /**
     * ✅ 현재 업로드 기본 경로 반환 (디버깅용)
     */
    public String getBaseUploadPath() {
        return baseUploadPath;
    }

    /**
     * 이미지 파일 유효성 검사
     */
    private void validateImageFile(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new IllegalArgumentException("업로드할 파일이 없습니다.");
        }

        // 파일 크기 검사
        if (file.getSize() > MAX_FILE_SIZE) {
            throw new IllegalArgumentException(
                    String.format("파일 크기가 너무 큽니다. 최대 %s까지 업로드 가능합니다.",
                            formatFileSize(MAX_FILE_SIZE))
            );
        }

        // 파일명 검사
        String originalFilename = file.getOriginalFilename();
        if (originalFilename == null || originalFilename.trim().isEmpty()) {
            throw new IllegalArgumentException("파일명이 올바르지 않습니다.");
        }

        // 파일 확장자 검사
        String extension = getFileExtension(originalFilename).toLowerCase();
        boolean isValidExtension = false;
        for (String allowedExt : ALLOWED_EXTENSIONS) {
            if (allowedExt.equals(extension)) {
                isValidExtension = true;
                break;
            }
        }

        if (!isValidExtension) {
            throw new IllegalArgumentException(
                    String.format("지원하지 않는 파일 형식입니다. 허용되는 형식: %s",
                            String.join(", ", ALLOWED_EXTENSIONS))
            );
        }

        // 파일 시그니처 검증 (Magic Number 검사)
        if (!isValidImageSignature(file)) {
            throw new IllegalArgumentException("파일 내용이 이미지 형식과 일치하지 않습니다.");
        }
    }

    /**
     * 파일 시그니처 검사 (Magic Number)
     */
    private boolean isValidImageSignature(MultipartFile file) {
        try {
            byte[] bytes = new byte[8];
            file.getInputStream().read(bytes, 0, 8);

            String hex = bytesToHex(bytes, 8);

            // JPEG: FF D8 FF
            if (hex.startsWith("FF D8 FF")) {
                return true;
            }

            // PNG: 89 50 4E 47 0D 0A 1A 0A
            if (hex.startsWith("89 50 4E 47")) {
                return true;
            }

            // GIF: 47 49 46 38
            if (hex.startsWith("47 49 46 38")) {
                return true;
            }

            // WEBP: 52 49 46 46 ... 57 45 42 50
            if (hex.startsWith("52 49 46 46")) {
                return true;
            }

            logger.warn("알 수 없는 파일 시그니처: {}", hex);
            return false;

        } catch (IOException e) {
            logger.error("파일 시그니처 확인 중 오류 발생", e);
            return false;
        }
    }

    /**
     * 바이트 배열을 16진수 문자열로 변환
     */
    private String bytesToHex(byte[] bytes, int length) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < length; i++) {
            sb.append(String.format("%02X ", bytes[i]));
        }
        return sb.toString().trim();
    }

    /**
     * 업로드 디렉토리 생성
     * ✅ 수정: baseUploadPath 사용
     */
    private String createUploadDirectory(String category) throws IOException {
        // 날짜별 폴더 구조: /app/uploads/category/yyyy/MM/dd/
        LocalDateTime now = LocalDateTime.now();
        String datePath = now.format(DateTimeFormatter.ofPattern("yyyy/MM/dd"));

        Path uploadPath = Paths.get(baseUploadPath, category, datePath);

        if (!Files.exists(uploadPath)) {
            Files.createDirectories(uploadPath);
            logger.info("업로드 디렉토리 생성: {}", uploadPath.toString());
        }

        return uploadPath.toString();
    }

    /**
     * 파일 확장자 추출
     */
    private String getFileExtension(String filename) {
        if (filename == null || !filename.contains(".")) {
            return "";
        }
        return filename.substring(filename.lastIndexOf(".")).toLowerCase();
    }

    /**
     * 고유 파일명 생성
     */
    private String generateFileName(String extension) {
        LocalDateTime now = LocalDateTime.now();
        String timestamp = now.format(DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss"));
        String uuid = UUID.randomUUID().toString().substring(0, 8);
        return timestamp + "_" + uuid + extension;
    }

    /**
     * 파일 크기 포맷팅
     */
    private String formatFileSize(long size) {
        if (size < 1024) {
            return size + " B";
        } else if (size < 1024 * 1024) {
            return String.format("%.1f KB", size / 1024.0);
        } else {
            return String.format("%.1f MB", size / (1024.0 * 1024.0));
        }
    }
}