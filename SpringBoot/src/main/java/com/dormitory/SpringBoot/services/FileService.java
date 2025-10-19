package com.dormitory.SpringBoot.services;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.UUID;

/**
 * 파일 업로드 및 관리를 담당하는 서비스 - 완성된 버전
 */
@Service
public class FileService {

    private static final Logger logger = LoggerFactory.getLogger(FileService.class);

    // 허용되는 이미지 파일 확장자
    private static final String[] ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".webp"};

    // 최대 파일 크기 (5MB)
    private static final long MAX_FILE_SIZE = 5 * 1024 * 1024;

    @Value("${file.upload.base-path:uploads}")
    private String baseUploadPath;

    /**
     * 이미지 파일 업로드
     *
     * @param file 업로드할 파일
     * @param category 파일 카테고리 (inspection, document 등)
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
     * 이미지 파일 유효성 검사 - 완성된 버전
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

        logger.debug("파일 유효성 검사 통과: {}", originalFilename);
    }

    /**
     * 파일 시그니처(Magic Number) 검증 - 완성된 버전
     */
    private boolean isValidImageSignature(MultipartFile file) {
        try {
            byte[] signature = new byte[12]; // 최대 12바이트까지 읽어서 확인
            int bytesRead = file.getInputStream().read(signature);

            if (bytesRead < 4) {
                logger.debug("파일이 너무 작아 시그니처를 확인할 수 없습니다");
                return false;
            }

            // JPEG 파일 시그니처 확인 (FF D8 FF)
            if (signature[0] == (byte) 0xFF && signature[1] == (byte) 0xD8 && signature[2] == (byte) 0xFF) {
                logger.debug("JPEG 파일 시그니처 확인됨");
                return true;
            }

            // PNG 파일 시그니처 확인 (89 50 4E 47 0D 0A 1A 0A)
            if (bytesRead >= 8 &&
                    signature[0] == (byte) 0x89 && signature[1] == (byte) 0x50 &&
                    signature[2] == (byte) 0x4E && signature[3] == (byte) 0x47 &&
                    signature[4] == (byte) 0x0D && signature[5] == (byte) 0x0A &&
                    signature[6] == (byte) 0x1A && signature[7] == (byte) 0x0A) {
                logger.debug("PNG 파일 시그니처 확인됨");
                return true;
            }

            // GIF 파일 시그니처 확인 (47 49 46 38)
            if (signature[0] == (byte) 0x47 && signature[1] == (byte) 0x49 &&
                    signature[2] == (byte) 0x46 && signature[3] == (byte) 0x38) {
                logger.debug("GIF 파일 시그니처 확인됨");
                return true;
            }

            // WebP 파일 시그니처 확인 (52 49 46 46 ... 57 45 42 50)
            if (bytesRead >= 12 &&
                    signature[0] == (byte) 0x52 && signature[1] == (byte) 0x49 &&
                    signature[2] == (byte) 0x46 && signature[3] == (byte) 0x46 &&
                    signature[8] == (byte) 0x57 && signature[9] == (byte) 0x45 &&
                    signature[10] == (byte) 0x42 && signature[11] == (byte) 0x50) {
                logger.debug("WebP 파일 시그니처 확인됨");
                return true;
            }

            logger.debug("알 수 없는 파일 시그니처: {}", bytesToHex(signature, bytesRead));
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
     */
    private String createUploadDirectory(String category) throws IOException {
        // 날짜별 폴더 구조: uploads/category/yyyy/MM/dd/
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
     * 고유한 파일명 생성
     */
    private String generateFileName(String extension) {
        String timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss"));
        String uuid = UUID.randomUUID().toString().substring(0, 8);
        return timestamp + "_" + uuid + extension;
    }

    /**
     * 파일 크기를 사람이 읽기 쉬운 형식으로 변환
     */
    public String formatFileSize(long bytes) {
        if (bytes < 1024) return bytes + " B";
        int exp = (int) (Math.log(bytes) / Math.log(1024));
        String pre = "KMGTPE".charAt(exp - 1) + "";
        return String.format("%.1f %sB", bytes / Math.pow(1024, exp), pre);
    }

    /**
     * 업로드 디렉토리 정리 (오래된 파일 삭제)
     */
    public void cleanupOldFiles(int daysToKeep) {
        try {
            LocalDateTime cutoffDate = LocalDateTime.now().minusDays(daysToKeep);
            Path uploadPath = Paths.get(baseUploadPath);

            if (Files.exists(uploadPath)) {
                Files.walk(uploadPath)
                        .filter(Files::isRegularFile)
                        .filter(path -> {
                            try {
                                return Files.getLastModifiedTime(path).toMillis() <
                                        cutoffDate.atZone(java.time.ZoneId.systemDefault()).toInstant().toEpochMilli();
                            } catch (IOException e) {
                                return false;
                            }
                        })
                        .forEach(path -> {
                            try {
                                Files.delete(path);
                                logger.info("오래된 파일 삭제: {}", path);
                            } catch (IOException e) {
                                logger.warn("파일 삭제 실패: {}", path, e);
                            }
                        });
            }
        } catch (Exception e) {
            logger.error("파일 정리 중 오류 발생", e);
        }
    }
}