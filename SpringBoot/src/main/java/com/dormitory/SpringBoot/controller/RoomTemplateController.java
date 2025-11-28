package com.dormitory.SpringBoot.controller;

import com.dormitory.SpringBoot.domain.RoomTemplate;
import com.dormitory.SpringBoot.domain.RoomTemplate.RoomType;
import com.dormitory.SpringBoot.dto.ApiResponse;
import com.dormitory.SpringBoot.services.RoomTemplateService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 방 템플릿 관리 API (관리자용)
 * - 기준 방 사진 등록/수정/삭제
 * - AI 점호 평가 시 비교 기준으로 사용
 */
@RestController
@RequestMapping("/api/admin/room-templates")
@PreAuthorize("hasRole('ADMIN')")
public class RoomTemplateController {

    private static final Logger logger = LoggerFactory.getLogger(RoomTemplateController.class);

    @Autowired
    private RoomTemplateService templateService;

    /**
     * 전체 템플릿 목록 조회
     */
    @GetMapping
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getAllTemplates() {
        try {
            List<RoomTemplate> templates = templateService.getAllTemplates();
            List<Map<String, Object>> response = new ArrayList<>();
            for (RoomTemplate template : templates) {
                response.add(convertToResponse(template));
            }

            return ResponseEntity.ok(ApiResponse.success("템플릿 목록 조회 성공", response));
        } catch (Exception e) {
            logger.error("템플릿 목록 조회 실패", e);
            return ResponseEntity.internalServerError()
                    .body(ApiResponse.error("템플릿 목록 조회 실패: " + e.getMessage()));
        }
    }

    /**
     * 활성화된 템플릿 목록 조회
     */
    @GetMapping("/active")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getActiveTemplates() {
        try {
            List<RoomTemplate> templates = templateService.getAllActiveTemplates();
            List<Map<String, Object>> response = new ArrayList<>();
            for (RoomTemplate template : templates) {
                response.add(convertToResponse(template));
            }

            return ResponseEntity.ok(ApiResponse.success("활성 템플릿 목록 조회 성공", response));
        } catch (Exception e) {
            logger.error("활성 템플릿 목록 조회 실패", e);
            return ResponseEntity.internalServerError()
                    .body(ApiResponse.error("활성 템플릿 목록 조회 실패: " + e.getMessage()));
        }
    }

    /**
     * 방 타입별 템플릿 조회
     */
    @GetMapping("/type/{roomType}")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getTemplatesByType(@PathVariable String roomType) {
        try {
            RoomType type = RoomType.valueOf(roomType.toUpperCase());
            List<RoomTemplate> templates = templateService.getTemplatesByRoomType(type);
            List<Map<String, Object>> response = new ArrayList<>();
            for (RoomTemplate template : templates) {
                response.add(convertToResponse(template));
            }

            return ResponseEntity.ok(ApiResponse.success("템플릿 조회 성공", response));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest()
                    .body(ApiResponse.error("잘못된 방 타입입니다: " + roomType));
        } catch (Exception e) {
            logger.error("타입별 템플릿 조회 실패", e);
            return ResponseEntity.internalServerError()
                    .body(ApiResponse.error("템플릿 조회 실패: " + e.getMessage()));
        }
    }

    /**
     * 특정 템플릿 조회
     */
    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getTemplateById(@PathVariable Long id) {
        try {
            return templateService.getTemplateById(id)
                    .map(template -> ResponseEntity.ok(ApiResponse.success("템플릿 조회 성공", convertToResponse(template))))
                    .orElseGet(() -> ResponseEntity.badRequest().body(ApiResponse.error("템플릿을 찾을 수 없습니다.")));
        } catch (Exception e) {
            logger.error("템플릿 조회 실패 - ID: {}", id, e);
            return ResponseEntity.internalServerError()
                    .body(ApiResponse.error("템플릿 조회 실패: " + e.getMessage()));
        }
    }

    /**
     * 템플릿 등록
     */
    @PostMapping
    public ResponseEntity<ApiResponse<Map<String, Object>>> createTemplate(
            @RequestParam("templateName") String templateName,
            @RequestParam("roomType") String roomType,
            @RequestParam("image") MultipartFile imageFile,
            @RequestParam(value = "description", required = false) String description,
            @RequestParam(value = "buildingName", required = false) String buildingName,
            @RequestParam(value = "isDefault", defaultValue = "false") boolean isDefault) {
        try {
            logger.info("템플릿 등록 요청 - 이름: {}, 타입: {}", templateName, roomType);

            // 관리자 ID 추출
            Authentication auth = SecurityContextHolder.getContext().getAuthentication();
            String adminId = auth != null ? auth.getName() : "SYSTEM";

            RoomType type = RoomType.valueOf(roomType.toUpperCase());
            RoomTemplate template = templateService.createTemplate(
                    templateName, type, imageFile, description, buildingName, isDefault, adminId);

            return ResponseEntity.ok(ApiResponse.success("템플릿이 등록되었습니다.", convertToResponse(template)));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest()
                    .body(ApiResponse.error("잘못된 방 타입입니다: " + roomType));
        } catch (Exception e) {
            logger.error("템플릿 등록 실패", e);
            return ResponseEntity.internalServerError()
                    .body(ApiResponse.error("템플릿 등록 실패: " + e.getMessage()));
        }
    }

    /**
     * 템플릿 수정
     */
    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<Map<String, Object>>> updateTemplate(
            @PathVariable Long id,
            @RequestParam(value = "templateName", required = false) String templateName,
            @RequestParam(value = "roomType", required = false) String roomType,
            @RequestParam(value = "image", required = false) MultipartFile imageFile,
            @RequestParam(value = "description", required = false) String description,
            @RequestParam(value = "buildingName", required = false) String buildingName,
            @RequestParam(value = "isDefault", defaultValue = "false") boolean isDefault) {
        try {
            logger.info("템플릿 수정 요청 - ID: {}", id);

            RoomType type = roomType != null ? RoomType.valueOf(roomType.toUpperCase()) : null;
            RoomTemplate template = templateService.updateTemplate(
                    id, templateName, type, imageFile, description, buildingName, isDefault);

            return ResponseEntity.ok(ApiResponse.success("템플릿이 수정되었습니다.", convertToResponse(template)));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest()
                    .body(ApiResponse.error("잘못된 방 타입입니다: " + roomType));
        } catch (Exception e) {
            logger.error("템플릿 수정 실패 - ID: {}", id, e);
            return ResponseEntity.internalServerError()
                    .body(ApiResponse.error("템플릿 수정 실패: " + e.getMessage()));
        }
    }

    /**
     * 템플릿 삭제 (비활성화)
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Object>> deleteTemplate(@PathVariable Long id) {
        try {
            logger.info("템플릿 삭제 요청 - ID: {}", id);
            templateService.deleteTemplate(id);
            return ResponseEntity.ok(ApiResponse.success("템플릿이 삭제되었습니다.", null));
        } catch (Exception e) {
            logger.error("템플릿 삭제 실패 - ID: {}", id, e);
            return ResponseEntity.internalServerError()
                    .body(ApiResponse.error("템플릿 삭제 실패: " + e.getMessage()));
        }
    }

    /**
     * 템플릿 활성화 토글
     */
    @PatchMapping("/{id}/toggle")
    public ResponseEntity<ApiResponse<Map<String, Object>>> toggleTemplate(@PathVariable Long id) {
        try {
            logger.info("템플릿 활성화 토글 요청 - ID: {}", id);
            RoomTemplate template = templateService.toggleActive(id);
            return ResponseEntity.ok(ApiResponse.success(
                    template.getIsActive() ? "템플릿이 활성화되었습니다." : "템플릿이 비활성화되었습니다.",
                    convertToResponse(template)));
        } catch (Exception e) {
            logger.error("템플릿 토글 실패 - ID: {}", id, e);
            return ResponseEntity.internalServerError()
                    .body(ApiResponse.error("템플릿 토글 실패: " + e.getMessage()));
        }
    }

    /**
     * 방 타입 목록 조회
     */
    @GetMapping("/room-types")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getRoomTypes() {
        try {
            List<Map<String, Object>> types = new ArrayList<>();

            Map<String, Object> single = new HashMap<>();
            single.put("value", "SINGLE");
            single.put("label", "1인실");
            types.add(single);

            Map<String, Object> doubleRoom = new HashMap<>();
            doubleRoom.put("value", "DOUBLE");
            doubleRoom.put("label", "2인실");
            types.add(doubleRoom);

            Map<String, Object> multi = new HashMap<>();
            multi.put("value", "MULTI");
            multi.put("label", "다인실");
            types.add(multi);

            return ResponseEntity.ok(ApiResponse.success("방 타입 목록", types));
        } catch (Exception e) {
            return ResponseEntity.internalServerError()
                    .body(ApiResponse.error("방 타입 조회 실패: " + e.getMessage()));
        }
    }

    /**
     * 템플릿 엔티티를 응답 형태로 변환
     */
    private Map<String, Object> convertToResponse(RoomTemplate template) {
        Map<String, Object> response = new HashMap<>();
        response.put("id", template.getId());
        response.put("templateName", template.getTemplateName());
        response.put("roomType", template.getRoomType().name());
        response.put("roomTypeDisplay", template.getRoomType().getDisplayName());
        response.put("imagePath", template.getImagePath());
        response.put("description", template.getDescription());
        response.put("buildingName", template.getBuildingName());
        response.put("isActive", template.getIsActive());
        response.put("isDefault", template.getIsDefault());
        response.put("createdBy", template.getCreatedBy());
        response.put("createdAt", template.getCreatedAt() != null ? template.getCreatedAt().toString() : null);
        response.put("updatedAt", template.getUpdatedAt() != null ? template.getUpdatedAt().toString() : null);
        // Base64는 용량이 크므로 목록에서는 제외
        return response;
    }
}