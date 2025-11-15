package com.dormitory.SpringBoot.domain;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/**
 * 캘린더 이벤트 엔티티
 */
@Entity
@Table(name = "calendar")
public class Calendar {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 100)
    private String title; // 일정 제목

    @Column(length = 500)
    private String description; // 일정 설명

    @Column(nullable = false)
    private LocalDateTime startDate; // 시작 날짜

    @Column(nullable = false)
    private LocalDateTime endDate; // 종료 날짜

    @Column(length = 50)
    private String category; // 카테고리 (학사일정, 기숙사일정, 행사 등)

    @Column(length = 20)
    private String color; // 일정 표시 색상

    @Column(nullable = false)
    private Boolean isAllDay = false; // 종일 일정 여부

    @Column(nullable = false)
    private Boolean isImportant = false; // 중요 일정 여부

    @Column(length = 255)
    private String location; // 장소

    @Column(length = 100)
    private String createdBy; // 생성자 (관리자 ID)

    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt; // 생성 일시

    @Column(nullable = false)
    private LocalDateTime updatedAt; // 수정 일시

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }

    // 기본 생성자
    public Calendar() {
    }

    // Getters and Setters
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

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public LocalDateTime getStartDate() {
        return startDate;
    }

    public void setStartDate(LocalDateTime startDate) {
        this.startDate = startDate;
    }

    public LocalDateTime getEndDate() {
        return endDate;
    }

    public void setEndDate(LocalDateTime endDate) {
        this.endDate = endDate;
    }

    public String getCategory() {
        return category;
    }

    public void setCategory(String category) {
        this.category = category;
    }

    public String getColor() {
        return color;
    }

    public void setColor(String color) {
        this.color = color;
    }

    public Boolean getIsAllDay() {
        return isAllDay;
    }

    public void setIsAllDay(Boolean isAllDay) {
        this.isAllDay = isAllDay;
    }

    public Boolean getIsImportant() {
        return isImportant;
    }

    public void setIsImportant(Boolean isImportant) {
        this.isImportant = isImportant;
    }

    public String getLocation() {
        return location;
    }

    public void setLocation(String location) {
        this.location = location;
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
