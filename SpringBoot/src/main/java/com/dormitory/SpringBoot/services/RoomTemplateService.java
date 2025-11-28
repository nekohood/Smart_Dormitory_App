package com.dormitory.SpringBoot.services;

import com.dormitory.SpringBoot.domain.RoomTemplate;
import com.dormitory.SpringBoot.domain.RoomTemplate.RoomType;
import com.dormitory.SpringBoot.repository.RoomTemplateRepository;
import org.apache.commons.codec.binary.Base64;
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
import java.util.List;
import java.util.Optional;

/**
 * 방 템플릿 관리 서비스
 * - 관리자가 기준 방 사진을 등록/관리
 * - AI 점호 평가 시 비교 기준 제공
 */
@Service
@Transactional
public class RoomTemplateService {

    private static final Logger logger = LoggerFactory.getLogger(RoomTemplateService.class);

    @Autowired
    private RoomTemplateRepository templateRepository;

    @Autowired
    private FileService fileService;

    /**
     * 템플릿 등록
     */
    public RoomTemplate createTemplate(String templateName, RoomType roomType,
                                        MultipartFile imageFile, String description,
                                        String buildingName, boolean isDefault, String adminId) {
        try {
            logger.info("방 템플릿 등록 시작 - 이름: {}, 타입: {}", templateName, roomType);

            // 이미지 업로드
            String imagePath = fileService.uploadImage(imageFile, "room-templates");

            // Base64 인코딩 (AI 비교용)
            String base64Image = encodeToBase64(imageFile);

            // 기본 템플릿으로 설정 시 기존 기본 템플릿 해제
            if (isDefault) {
                templateRepository.findByRoomTypeAndIsDefaultTrueAndIsActiveTrue(roomType)
                        .ifPresent(existing -> {
                            existing.setIsDefault(false);
                            templateRepository.save(existing);
                            logger.info("기존 기본 템플릿 해제 - ID: {}", existing.getId());
                        });
            }

            RoomTemplate template = new RoomTemplate();
            template.setTemplateName(templateName);
            template.setRoomType(roomType);
            template.setImagePath(imagePath);
            template.setImageBase64(base64Image);
            template.setDescription(description);
            template.setBuildingName(buildingName);
            template.setIsDefault(isDefault);
            template.setIsActive(true);
            template.setCreatedBy(adminId);

            RoomTemplate saved = templateRepository.save(template);
            logger.info("방 템플릿 등록 완료 - ID: {}", saved.getId());
            return saved;

        } catch (Exception e) {
            logger.error("방 템플릿 등록 실패", e);
            throw new RuntimeException("템플릿 등록에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 템플릿 수정
     */
    public RoomTemplate updateTemplate(Long id, String templateName, RoomType roomType,
                                        MultipartFile imageFile, String description,
                                        String buildingName, boolean isDefault) {
        try {
            logger.info("방 템플릿 수정 - ID: {}", id);

            RoomTemplate template = templateRepository.findById(id)
                    .orElseThrow(() -> new RuntimeException("템플릿을 찾을 수 없습니다: " + id));

            if (templateName != null) {
                template.setTemplateName(templateName);
            }
            if (roomType != null) {
                template.setRoomType(roomType);
            }
            if (description != null) {
                template.setDescription(description);
            }
            if (buildingName != null) {
                template.setBuildingName(buildingName.isEmpty() ? null : buildingName);
            }

            // 새 이미지가 있으면 업데이트
            if (imageFile != null && !imageFile.isEmpty()) {
                String imagePath = fileService.uploadImage(imageFile, "room-templates");
                String base64Image = encodeToBase64(imageFile);
                template.setImagePath(imagePath);
                template.setImageBase64(base64Image);
            }

            // 기본 템플릿 설정 변경
            if (isDefault && !Boolean.TRUE.equals(template.getIsDefault())) {
                templateRepository.findByRoomTypeAndIsDefaultTrueAndIsActiveTrue(template.getRoomType())
                        .ifPresent(existing -> {
                            if (!existing.getId().equals(id)) {
                                existing.setIsDefault(false);
                                templateRepository.save(existing);
                            }
                        });
            }
            template.setIsDefault(isDefault);

            RoomTemplate updated = templateRepository.save(template);
            logger.info("방 템플릿 수정 완료 - ID: {}", id);
            return updated;

        } catch (Exception e) {
            logger.error("방 템플릿 수정 실패", e);
            throw new RuntimeException("템플릿 수정에 실패했습니다: " + e.getMessage());
        }
    }

    /**
     * 템플릿 삭제 (비활성화)
     */
    public void deleteTemplate(Long id) {
        logger.info("방 템플릿 삭제 - ID: {}", id);

        RoomTemplate template = templateRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("템플릿을 찾을 수 없습니다: " + id));

        template.setIsActive(false);
        template.setIsDefault(false);
        templateRepository.save(template);

        logger.info("방 템플릿 삭제 완료 (비활성화) - ID: {}", id);
    }

    /**
     * 템플릿 완전 삭제
     */
    public void hardDeleteTemplate(Long id) {
        logger.info("방 템플릿 완전 삭제 - ID: {}", id);
        templateRepository.deleteById(id);
        logger.info("방 템플릿 완전 삭제 완료 - ID: {}", id);
    }

    /**
     * 전체 활성 템플릿 조회
     */
    @Transactional(readOnly = true)
    public List<RoomTemplate> getAllActiveTemplates() {
        return templateRepository.findByIsActiveTrueOrderByRoomTypeAscCreatedAtDesc();
    }

    /**
     * 전체 템플릿 조회 (관리용)
     */
    @Transactional(readOnly = true)
    public List<RoomTemplate> getAllTemplates() {
        return templateRepository.findAllByOrderByRoomTypeAscCreatedAtDesc();
    }

    /**
     * 방 타입별 템플릿 조회
     */
    @Transactional(readOnly = true)
    public List<RoomTemplate> getTemplatesByRoomType(RoomType roomType) {
        return templateRepository.findByRoomTypeAndIsActiveTrueOrderByIsDefaultDescCreatedAtDesc(roomType);
    }

    /**
     * 특정 템플릿 조회
     */
    @Transactional(readOnly = true)
    public Optional<RoomTemplate> getTemplateById(Long id) {
        return templateRepository.findById(id);
    }

    /**
     * 방 타입의 기본 템플릿 조회
     */
    @Transactional(readOnly = true)
    public Optional<RoomTemplate> getDefaultTemplate(RoomType roomType) {
        return templateRepository.findByRoomTypeAndIsDefaultTrueAndIsActiveTrue(roomType);
    }

    /**
     * 특정 동 + 방 타입에 맞는 템플릿 조회 (AI 비교용)
     */
    @Transactional(readOnly = true)
    public Optional<RoomTemplate> getTemplateForComparison(RoomType roomType, String buildingName) {
        List<RoomTemplate> templates = templateRepository.findByRoomTypeAndBuilding(roomType, buildingName);
        return templates.isEmpty() ? Optional.empty() : Optional.of(templates.get(0));
    }

    /**
     * 모든 기본 템플릿 조회
     */
    @Transactional(readOnly = true)
    public List<RoomTemplate> getAllDefaultTemplates() {
        return templateRepository.findAllDefaultTemplates();
    }

    /**
     * 템플릿 활성화/비활성화 토글
     */
    public RoomTemplate toggleActive(Long id) {
        RoomTemplate template = templateRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("템플릿을 찾을 수 없습니다: " + id));

        template.setIsActive(!Boolean.TRUE.equals(template.getIsActive()));

        // 비활성화 시 기본 템플릿 해제
        if (!template.getIsActive()) {
            template.setIsDefault(false);
        }

        RoomTemplate updated = templateRepository.save(template);
        logger.info("템플릿 활성화 토글 - ID: {}, 활성화: {}", id, updated.getIsActive());
        return updated;
    }

    /**
     * MultipartFile을 Base64로 인코딩
     */
    private String encodeToBase64(MultipartFile file) {
        try {
            if (file == null || file.isEmpty()) {
                return null;
            }
            byte[] bytes = file.getBytes();
            return Base64.encodeBase64String(bytes);
        } catch (IOException e) {
            logger.error("Base64 인코딩 실패", e);
            return null;
        }
    }

    /**
     * 파일 경로에서 Base64 로드 (캐시 갱신용)
     */
    public String loadBase64FromPath(String imagePath) {
        try {
            Path path = Paths.get("uploads", imagePath);
            if (!Files.exists(path)) {
                logger.warn("이미지 파일이 존재하지 않음: {}", imagePath);
                return null;
            }
            byte[] bytes = Files.readAllBytes(path);
            return Base64.encodeBase64String(bytes);
        } catch (IOException e) {
            logger.error("이미지 로드 실패: {}", imagePath, e);
            return null;
        }
    }

    /**
     * 템플릿 Base64 캐시 갱신
     */
    public void refreshTemplateBase64(Long id) {
        RoomTemplate template = templateRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("템플릿을 찾을 수 없습니다: " + id));

        String base64 = loadBase64FromPath(template.getImagePath());
        if (base64 != null) {
            template.setImageBase64(base64);
            templateRepository.save(template);
            logger.info("템플릿 Base64 캐시 갱신 완료 - ID: {}", id);
        }
    }
}
