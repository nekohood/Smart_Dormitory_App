package com.dormitory.SpringBoot.domain;

import jakarta.persistence.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.LocalDateTime;

/**
 * 공공서류 정보를 저장하는 엔티티 - 거주 동/방 번호 자동 기입 기능 포함
 */
@Entity
@Table(name = "documents")
@EntityListeners(AuditingEntityListener.class)
public class Document {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "title", nullable = false, length = 200)
    private String title;

    @Column(name = "content", nullable = false, columnDefinition = "TEXT")
    private String content;

    @Column(name = "category", nullable = false, length = 50)
    private String category;

    @Column(name = "writer_id", nullable = false, length = 50)
    private String writerId;

    @Column(name = "writer_name", length = 100)
    private String writerName;

    // ✅ 거주 정보 자동 기입 필드 추가
    @Column(name = "dormitory_building", length = 50)
    private String dormitoryBuilding; // 기숙사 거주 동 (자동 기입)

    @Column(name = "room_number", length = 20)
    private String roomNumber; // 방 번호 (자동 기입)

    @Column(name = "image_path", length = 500)
    private String imagePath;

    @Column(name = "status", nullable = false, length = 20)
    private String status; // 대기, 검토중, 승인, 반려

    @Column(name = "admin_comment", columnDefinition = "TEXT")
    private String adminComment;

    @CreatedDate
    @Column(name = "submitted_at", nullable = false, updatable = false)
    private LocalDateTime submittedAt;

    @Column(name = "processed_at")
    private LocalDateTime processedAt;

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @LastModifiedDate
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    // =============================================================================
    // 생성자
    // =============================================================================

    public Document() {
        this.status = "대기"; // 기본 상태
    }

    public Document(String title, String content, String category, String writerId, String writerName) {
        this.title = title;
        this.content = content;
        this.category = category;
        this.writerId = writerId;
        this.writerName = writerName;
        this.status = "대기"; // 기본 상태
    }

    // =============================================================================
    // Lifecycle 콜백
    // =============================================================================

    @PrePersist
    protected void onCreate() {
        if (this.createdAt == null) {
            this.createdAt = LocalDateTime.now();
        }
        if (this.submittedAt == null) {
            this.submittedAt = LocalDateTime.now();
        }
        if (this.updatedAt == null) {
            this.updatedAt = LocalDateTime.now();
        }
        if (this.status == null) {
            this.status = "대기";
        }
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
    }

    // =============================================================================
    // Getter & Setter
    // =============================================================================

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public String getContent() {
        return content;
    }

    public void setContent(String content) {
        this.content = content;
    }

    public String getCategory() {
        return category;
    }

    public void setCategory(String category) {
        this.category = category;
    }

    public String getWriterId() {
        return writerId;
    }

    public void setWriterId(String writerId) {
        this.writerId = writerId;
    }

    public String getWriterName() {
        return writerName;
    }

    public void setWriterName(String writerName) {
        this.writerName = writerName;
    }

    // ✅ 거주 동 Getter & Setter
    public String getDormitoryBuilding() {
        return dormitoryBuilding;
    }

    public void setDormitoryBuilding(String dormitoryBuilding) {
        this.dormitoryBuilding = dormitoryBuilding;
    }

    // ✅ 방 번호 Getter & Setter
    public String getRoomNumber() {
        return roomNumber;
    }

    public void setRoomNumber(String roomNumber) {
        this.roomNumber = roomNumber;
    }

    public String getImagePath() {
        return imagePath;
    }

    public void setImagePath(String imagePath) {
        this.imagePath = imagePath;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public String getAdminComment() {
        return adminComment;
    }

    public void setAdminComment(String adminComment) {
        this.adminComment = adminComment;
    }

    public LocalDateTime getSubmittedAt() {
        return submittedAt;
    }

    public void setSubmittedAt(LocalDateTime submittedAt) {
        this.submittedAt = submittedAt;
    }

    public LocalDateTime getProcessedAt() {
        return processedAt;
    }

    public void setProcessedAt(LocalDateTime processedAt) {
        this.processedAt = processedAt;
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

    // =============================================================================
    // 비즈니스 메서드
    // =============================================================================

    /**
     * 서류 상태 업데이트
     */
    public void updateStatus(String status, String adminComment) {
        this.status = status;
        this.adminComment = adminComment;

        // 승인 또는 반려 상태인 경우 처리 시간 설정
        if ("승인".equals(status) || "반려".equals(status)) {
            this.processedAt = LocalDateTime.now();
        }

        this.updatedAt = LocalDateTime.now();
    }

    // =============================================================================
    // toString
    // =============================================================================

    @Override
    public String toString() {
        return "Document{" +
                "id=" + id +
                ", title='" + title + '\'' +
                ", category='" + category + '\'' +
                ", writerId='" + writerId + '\'' +
                ", writerName='" + writerName + '\'' +
                ", dormitoryBuilding='" + dormitoryBuilding + '\'' +
                ", roomNumber='" + roomNumber + '\'' +
                ", status='" + status + '\'' +
                ", submittedAt=" + submittedAt +
                '}';
    }
}