package com.dormitory.SpringBoot.domain;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/**
 * 기준 방 사진 템플릿 엔티티
 * - 관리자가 등록하는 기준(모범) 방 사진
 * - AI 점호 평가 시 비교 기준으로 사용
 */
@Entity
@Table(name = "room_templates")
public class RoomTemplate {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /**
     * 템플릿 이름 (예: "1인실 기준", "2인실 기준", "다인실 기준")
     */
    @Column(name = "template_name", nullable = false, length = 100)
    private String templateName;

    /**
     * 방 타입 (SINGLE: 1인실, DOUBLE: 2인실, MULTI: 다인실)
     */
    @Column(name = "room_type", nullable = false, length = 20)
    @Enumerated(EnumType.STRING)
    private RoomType roomType;

    /**
     * 기준 사진 경로
     */
    @Column(name = "image_path", nullable = false, length = 500)
    private String imagePath;

    /**
     * 기준 사진 Base64 데이터 (Gemini API 호출용 캐시)
     */
    @Column(name = "image_base64", columnDefinition = "LONGTEXT")
    private String imageBase64;

    /**
     * 설명
     */
    @Column(name = "description", length = 500)
    private String description;

    /**
     * 활성화 여부
     */
    @Column(name = "is_active", nullable = false)
    private Boolean isActive = true;

    /**
     * 기본 템플릿 여부 (해당 방 타입의 기본 비교 대상)
     */
    @Column(name = "is_default", nullable = false)
    private Boolean isDefault = false;

    /**
     * 동 이름 (특정 동에만 적용, null이면 전체 적용)
     */
    @Column(name = "building_name", length = 50)
    private String buildingName;

    /**
     * 등록자 ID
     */
    @Column(name = "created_by", length = 50)
    private String createdBy;

    /**
     * 등록일시
     */
    @Column(name = "created_at")
    private LocalDateTime createdAt;

    /**
     * 수정일시
     */
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    // 방 타입 enum
    public enum RoomType {
        SINGLE("1인실"),
        DOUBLE("2인실"),
        MULTI("다인실");

        private final String displayName;

        RoomType(String displayName) {
            this.displayName = displayName;
        }

        public String getDisplayName() {
            return displayName;
        }
    }

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
        this.updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
    }

    // Getters and Setters
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getTemplateName() {
        return templateName;
    }

    public void setTemplateName(String templateName) {
        this.templateName = templateName;
    }

    public RoomType getRoomType() {
        return roomType;
    }

    public void setRoomType(RoomType roomType) {
        this.roomType = roomType;
    }

    public String getImagePath() {
        return imagePath;
    }

    public void setImagePath(String imagePath) {
        this.imagePath = imagePath;
    }

    public String getImageBase64() {
        return imageBase64;
    }

    public void setImageBase64(String imageBase64) {
        this.imageBase64 = imageBase64;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public Boolean getIsActive() {
        return isActive;
    }

    public void setIsActive(Boolean isActive) {
        this.isActive = isActive;
    }

    public Boolean getIsDefault() {
        return isDefault;
    }

    public void setIsDefault(Boolean isDefault) {
        this.isDefault = isDefault;
    }

    public String getBuildingName() {
        return buildingName;
    }

    public void setBuildingName(String buildingName) {
        this.buildingName = buildingName;
    }

    public String getCreatedBy() {
        return createdBy;
    }

    public void setCreatedBy(String createdBy) {
        this.createdBy = createdBy;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(LocalDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }
}