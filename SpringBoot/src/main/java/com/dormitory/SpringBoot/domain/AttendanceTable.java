package com.dormitory.SpringBoot.domain;

import jakarta.persistence.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * 점호 제출 상태 테이블을 관리하는 엔티티
 * 관리자가 특정 날짜의 각 호실별 점호 제출 상태를 테이블로 확인
 */
@Entity
@Table(name = "attendance_table", 
       uniqueConstraints = @UniqueConstraint(columnNames = {"inspection_date", "room_number"}))
@EntityListeners(AuditingEntityListener.class)
public class AttendanceTable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "inspection_date", nullable = false)
    private LocalDate inspectionDate;

    @Column(name = "room_number", nullable = false, length = 20)
    private String roomNumber;

    @Column(name = "user_id", length = 50)
    private String userId;

    @Column(name = "user_name", length = 100)
    private String userName;

    @Column(name = "is_submitted", nullable = false)
    private Boolean isSubmitted = false;

    @Column(name = "submission_time")
    private LocalDateTime submissionTime;

    @Column(name = "score")
    private Integer score;

    @Column(name = "status", length = 20)
    private String status; // PASS, FAIL, PENDING

    @Column(name = "notes", columnDefinition = "TEXT")
    private String notes;

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @LastModifiedDate
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    // 기본 생성자
    public AttendanceTable() {}

    // 생성자
    public AttendanceTable(LocalDate inspectionDate, String roomNumber, String userId, String userName) {
        this.inspectionDate = inspectionDate;
        this.roomNumber = roomNumber;
        this.userId = userId;
        this.userName = userName;
        this.isSubmitted = false;
        this.status = "PENDING";
    }

    // Getters and Setters
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public LocalDate getInspectionDate() {
        return inspectionDate;
    }

    public void setInspectionDate(LocalDate inspectionDate) {
        this.inspectionDate = inspectionDate;
    }

    public String getRoomNumber() {
        return roomNumber;
    }

    public void setRoomNumber(String roomNumber) {
        this.roomNumber = roomNumber;
    }

    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    public String getUserName() {
        return userName;
    }

    public void setUserName(String userName) {
        this.userName = userName;
    }

    public Boolean getIsSubmitted() {
        return isSubmitted;
    }

    public void setIsSubmitted(Boolean isSubmitted) {
        this.isSubmitted = isSubmitted;
    }

    public LocalDateTime getSubmissionTime() {
        return submissionTime;
    }

    public void setSubmissionTime(LocalDateTime submissionTime) {
        this.submissionTime = submissionTime;
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

    public String getNotes() {
        return notes;
    }

    public void setNotes(String notes) {
        this.notes = notes;
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

    /**
     * 점호 제출 완료 처리
     */
    public void markAsSubmitted(Integer score, String status) {
        this.isSubmitted = true;
        this.submissionTime = LocalDateTime.now();
        this.score = score;
        this.status = status;
    }

    /**
     * 관리자 노트 추가
     */
    public void addNotes(String notes) {
        this.notes = notes;
    }
}
