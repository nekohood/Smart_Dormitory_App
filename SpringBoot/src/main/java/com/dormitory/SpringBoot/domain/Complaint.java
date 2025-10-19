package com.dormitory.SpringBoot.domain;

import jakarta.persistence.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.LocalDateTime;

/**
 * 민원 정보를 저장하는 엔티티 - DB 스키마 동기화 최종 버전
 */
@Entity
@Table(name = "complaints")
@EntityListeners(AuditingEntityListener.class)
public class Complaint {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "title", nullable = false, length = 200)
    private String title;

    @Column(name = "content", nullable = false, columnDefinition = "TEXT")
    private String content;

    @Column(name = "category", nullable = false, length = 50)
    private String category; // 시설 문제, 소음 문제, 청소 문제, 보안 문제 등

    @Column(name = "writer_id", nullable = false, length = 50)
    private String writerId;

    @Column(name = "writer_name", length = 100)
    private String writerName;

    @Column(name = "image_path", length = 500)
    private String imagePath;

    @Column(name = "status", nullable = false, length = 20)
    private String status; // 대기, 처리중, 완료, 반려

    @Column(name = "admin_comment", columnDefinition = "TEXT")
    private String adminComment;

    @CreatedDate
    @Column(name = "submitted_at", nullable = false, updatable = false)
    private LocalDateTime submittedAt;

    @Column(name = "processed_at")
    private LocalDateTime processedAt;

    @LastModifiedDate
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    // ... (이하 Getter, Setter 및 다른 메서드들은 변경 없음) ...

    // 기본 생성자
    public Complaint() {}

    // 생성자
    public Complaint(String title, String content, String category, String writerId) {
        this.title = title;
        this.content = content;
        this.category = category;
        this.writerId = writerId;
        this.status = "대기";
    }

    public Complaint(String title, String content, String category, String writerId, String writerName) {
        this.title = title;
        this.content = content;
        this.category = category;
        this.writerId = writerId;
        this.writerName = writerName;
        this.status = "대기";
    }

    // Getter & Setter
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

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(LocalDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }

    // 비즈니스 메서드
    public void updateStatus(String newStatus, String adminComment) {
        this.status = newStatus;
        this.adminComment = adminComment;
        if ("완료".equals(newStatus) || "반려".equals(newStatus)) {
            this.processedAt = LocalDateTime.now();
        }
    }

    public boolean isCompleted() {
        return "완료".equals(status) || "반려".equals(status);
    }

    public boolean isUrgent() {
        return "대기".equals(status) && submittedAt != null &&
                submittedAt.isBefore(LocalDateTime.now().minusDays(3));
    }

    @Override
    public String toString() {
        return "Complaint{" +
                "id=" + id +
                ", title='" + title + '\'' +
                ", category='" + category + '\'' +
                ", writerId='" + writerId + '\'' +
                ", status='" + status + '\'' +
                ", submittedAt=" + submittedAt +
                '}';
    }
}