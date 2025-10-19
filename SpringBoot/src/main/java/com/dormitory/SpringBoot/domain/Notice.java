package com.dormitory.SpringBoot.domain;

import jakarta.persistence.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.LocalDateTime;

/**
 * 공지사항 정보를 저장하는 엔티티 - DB 스키마 동기화 버전
 */
@Entity
@Table(name = "notices")
@EntityListeners(AuditingEntityListener.class)
public class Notice {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private Long id;

    @Column(name = "title", nullable = false, length = 200)
    private String title;

    @Column(name = "content", nullable = false, columnDefinition = "TEXT")
    private String content;

    @Column(name = "author", nullable = false, length = 100)
    private String author;

    @Column(name = "image_path", length = 500)
    private String imagePath;

    @Column(name = "is_pinned", nullable = false)
    private Boolean isPinned = false;

    @Column(name = "view_count", nullable = false)
    private Integer viewCount = 0;

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @LastModifiedDate
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    // ... (이하 Getter, Setter 및 다른 메서드들은 변경 없음) ...

    // 기본 생성자
    public Notice() {
    }

    // 생성자
    public Notice(String title, String content, String author) {
        this.title = title;
        this.content = content;
        this.author = author;
    }

    public Notice(String title, String content, String author, String imagePath) {
        this.title = title;
        this.content = content;
        this.author = author;
        this.imagePath = imagePath;
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

    public String getAuthor() {
        return author;
    }

    public void setAuthor(String author) {
        this.author = author;
    }

    public String getImagePath() {
        return imagePath;
    }

    public void setImagePath(String imagePath) {
        this.imagePath = imagePath;
    }

    public Boolean getIsPinned() {
        return isPinned;
    }

    public void setIsPinned(Boolean isPinned) {
        this.isPinned = isPinned != null ? isPinned : false;
    }

    public Integer getViewCount() {
        return viewCount;
    }

    public void setViewCount(Integer viewCount) {
        this.viewCount = viewCount != null ? viewCount : 0;
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

    // 비즈니스 메서드

    /**
     * 조회수 증가
     */
    public void incrementViewCount() {
        this.viewCount = (this.viewCount != null ? this.viewCount : 0) + 1;
    }

    /**
     * 고정 여부 토글
     */
    public void togglePin() {
        this.isPinned = !this.isPinned;
    }

    /**
     * 이미지가 있는지 확인
     */
    public boolean hasImage() {
        return this.imagePath != null && !this.imagePath.trim().isEmpty();
    }

    /**
     * 최근에 작성된 공지사항인지 확인 (24시간 이내)
     */
    public boolean isRecent() {
        if (this.createdAt == null) {
            return false;
        }
        return this.createdAt.isAfter(LocalDateTime.now().minusDays(1));
    }

    /**
     * 인기 공지사항인지 확인 (조회수 100회 이상)
     */
    public boolean isPopular() {
        return this.viewCount != null && this.viewCount >= 100;
    }

    @Override
    public String toString() {
        return "Notice{" +
                "id=" + id +
                ", title='" + title + '\'' +
                ", author='" + author + '\'' +
                ", isPinned=" + isPinned +
                ", viewCount=" + viewCount +
                ", hasImage=" + hasImage() +
                ", createdAt=" + createdAt +
                '}';
    }
}