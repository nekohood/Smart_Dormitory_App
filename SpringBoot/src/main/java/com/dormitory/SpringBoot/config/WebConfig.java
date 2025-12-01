package com.dormitory.SpringBoot.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.io.File;

/**
 * 웹 설정 - 정적 리소스 핸들링
 * ✅ 수정: Railway Volume 경로 지원
 */
@Configuration
public class WebConfig implements WebMvcConfigurer {

    @Value("${file.upload.path:/app/uploads}")
    private String uploadPath;

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        // 업로드 경로 결정 (환경변수 또는 기본값)
        String resolvedPath = resolveUploadPath();

        System.out.println("[WebConfig] 정적 리소스 경로 설정: " + resolvedPath);

        registry
                .addResourceHandler("/uploads/**")
                .addResourceLocations("file:" + resolvedPath + "/");
    }

    /**
     * 업로드 경로 결정
     * 1. 환경변수 FILE_UPLOAD_PATH가 설정되어 있으면 사용
     * 2. /app/uploads 경로가 존재하면 사용 (Railway Volume)
     * 3. 그 외에는 현재 작업 디렉토리의 uploads 폴더 사용 (로컬 개발)
     */
    private String resolveUploadPath() {
        // 1. 환경변수 확인
        String envPath = System.getenv("FILE_UPLOAD_PATH");
        if (envPath != null && !envPath.isEmpty()) {
            ensureDirectoryExists(envPath);
            return envPath;
        }

        // 2. Railway Volume 경로 확인 (/app/uploads)
        File railwayVolume = new File("/app/uploads");
        if (railwayVolume.exists() || isRunningOnRailway()) {
            ensureDirectoryExists("/app/uploads");
            return "/app/uploads";
        }

        // 3. 로컬 개발 환경 (현재 작업 디렉토리)
        String localPath = System.getProperty("user.dir") + "/uploads";
        ensureDirectoryExists(localPath);
        return localPath;
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
        File dir = new File(path);
        if (!dir.exists()) {
            boolean created = dir.mkdirs();
            System.out.println("[WebConfig] 디렉토리 생성: " + path + " - " + (created ? "성공" : "실패 또는 이미 존재"));
        }
    }
}