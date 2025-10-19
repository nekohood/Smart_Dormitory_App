package com.dormitory.SpringBoot.domain;

import jakarta.persistence.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.LocalDateTime;

/**
 * 공공서류 정보를 저장하는 엔티티 - created_at 필드 추가 버전
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

    @Column(name = "image_path", length = 500)
    private String imagePath;

    @Column(name = "status", nullable = false, length = 20)
    private String status;

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

    // 기본 생성자
    public Document() {
        this.status = "대기"; // 기본 상태
    }

    // 생성자
    public Document(String title, String content, String category, String writerId, String writerName) {
        this.title = title;
        this.content = content;
        this.category = category;
        this.writerId = writerId;
        this.writerName = writerName;
        this.status = "대기"; // 기본 상태
    }

    // PrePersist 콜백 - 저장 전 실행
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

    // PreUpdate 콜백 - 업데이트 전 실행
    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
    }

    // Getter and Setter methods
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

    // 유틸리티 메서드들

    /**
     * 서류가 승인되었는지 확인
     */
    public boolean isApproved() {
        return "승인".equals(this.status);
    }

    /**
     * 서류가 대기 상태인지 확인
     */
    public boolean isPending() {
        return "대기".equals(this.status);
    }

    /**
     * 서류가 반려되었는지 확인
     */
    public boolean isRejected() {
        return "반려".equals(this.status);
    }

    /**
     * 서류가 검토 중인지 확인
     */
    public boolean isUnderReview() {
        return "검토중".equals(this.status);
    }

    /**
     * 서류에 이미지가 첨부되어 있는지 확인
     */
    public boolean hasImage() {
        return this.imagePath != null && !this.imagePath.trim().isEmpty();
    }

    /**
     * 서류가 처리되었는지 확인 (승인 또는 반려)
     */
    public boolean isProcessed() {
        return isApproved() || isRejected();
    }

    /**
     * 서류 제출 후 경과 시간 (시간 단위)
     */
    public long getHoursSinceSubmitted() {
        if (this.submittedAt == null) return 0;
        return java.time.Duration.between(this.submittedAt, LocalDateTime.now()).toHours();
    }

    /**
     * 긴급 서류인지 확인 (7일 이상 대기)
     */
    public boolean isUrgent() {
        return isPending() && getHoursSinceSubmitted() >= 168; // 7일 = 168시간
    }

    /**
     * 서류 상태 업데이트
     */
    public void updateStatus(String newStatus, String adminComment) {
        this.status = newStatus;
        this.adminComment = adminComment;
        this.updatedAt = LocalDateTime.now();

        if (isProcessed()) {
            this.processedAt = LocalDateTime.now();
        }
    }

    @Override
    public String toString() {
        return "Document{" +
                "id=" + id +
                ", title='" + title + '\'' +
                ", category='" + category + '\'' +
                ", writerId='" + writerId + '\'' +
                ", status='" + status + '\'' +
                ", submittedAt=" + submittedAt +
                ", createdAt=" + createdAt +
                '}';
    }
}