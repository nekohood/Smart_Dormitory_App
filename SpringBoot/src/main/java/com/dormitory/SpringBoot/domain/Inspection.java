package com.dormitory.SpringBoot.domain;

import jakarta.persistence.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.LocalDateTime;

/**
 * 점호 정보를 저장하는 엔티티 - DB 스키마 동기화 최종 버전
 */
@Entity
@Table(name = "inspections")
@EntityListeners(AuditingEntityListener.class)
public class Inspection {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false, length = 50)
    private String userId;

    @Column(name = "room_number", length = 20)
    private String roomNumber;

    @Column(name = "image_path", nullable = false, length = 500)
    private String imagePath;

    @Column(name = "score", nullable = false)
    private Integer score;

    @Column(name = "status", nullable = false, length = 20)
    private String status; // PASS, FAIL

    @Column(name = "gemini_feedback", columnDefinition = "TEXT")
    private String geminiFeedback;

    @Column(name = "admin_comment", columnDefinition = "TEXT")
    private String adminComment;

    @Column(name = "is_re_inspection", nullable = false)
    private Boolean isReInspection = false;

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @LastModifiedDate
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @Column(name = "inspection_date", nullable = false)
    private LocalDateTime inspectionDate;

    // ... (이하 Getter, Setter 및 다른 메서드들은 변경 없음) ...

    // 기본 생성자
    public Inspection() {}

    // 생성자
    public Inspection(String userId, String roomNumber, String imagePath,
                      Integer score, String status, String geminiFeedback) {
        this.userId = userId;
        this.roomNumber = roomNumber;
        this.imagePath = imagePath;
        this.score = score;
        this.status = status;
        this.geminiFeedback = geminiFeedback;
        this.isReInspection = false; // 기본값
        this.inspectionDate = LocalDateTime.now();
    }

    // Getter and Setter methods
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

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

    public Integer getScore() {
        return score;
    }

    public void setScore(Integer score) {
        this.score = score;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public String getGeminiFeedback() {
        return geminiFeedback;
    }

    public void setGeminiFeedback(String geminiFeedback) {
        this.geminiFeedback = geminiFeedback;
    }

    public String getAdminComment() {
        return adminComment;
    }

    public void setAdminComment(String adminComment) {
        this.adminComment = adminComment;
    }

    public Boolean getIsReInspection() {
        return isReInspection;
    }

    public void setIsReInspection(Boolean isReInspection) {
        this.isReInspection = isReInspection;
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

    public LocalDateTime getInspectionDate() {
        return inspectionDate;
    }

    public void setInspectionDate(LocalDateTime inspectionDate) {
        this.inspectionDate = inspectionDate;
    }

    /**
     * 관리자에 의한 수정 메소드
     */
    public void updateByAdmin(Integer score, String status, String geminiFeedback,
                              String adminComment, Boolean isReInspection) {
        if (score != null) {
            this.score = score;
        }
        if (status != null) {
            this.status = status;
        }
        if (geminiFeedback != null) {
            this.geminiFeedback = geminiFeedback;
        }
        if (adminComment != null) {
            this.adminComment = adminComment;
        }
        if (isReInspection != null) {
            this.isReInspection = isReInspection;
        }
    }

    @Override
    public String toString() {
        return "Inspection{" +
                "id=" + id +
                ", userId='" + userId + '\'' +
                ", roomNumber='" + roomNumber + '\'' +
                ", score=" + score +
                ", status='" + status + '\'' +
                ", isReInspection=" + isReInspection +
                ", inspectionDate=" + inspectionDate +
                '}';
    }
}