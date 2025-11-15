package com.dormitory.SpringBoot.dto;

import com.dormitory.SpringBoot.domain.Calendar;
import java.time.LocalDateTime;

/**
 * 캘린더 데이터 전송 객체
 */
public class CalendarDTO {

    private Long id;
    private String title;
    private String description;
    private LocalDateTime startDate;
    private LocalDateTime endDate;
    private String category;
    private String color;
    private Boolean isAllDay;
    private Boolean isImportant;
    private String location;
    private String createdBy;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    // 기본 생성자
    public CalendarDTO() {
    }

    // Entity로부터 DTO 생성
    public CalendarDTO(Calendar calendar) {
        this.id = calendar.getId();
        this.title = calendar.getTitle();
        this.description = calendar.getDescription();
        this.startDate = calendar.getStartDate();
        this.endDate = calendar.getEndDate();
        this.category = calendar.getCategory();
        this.color = calendar.getColor();
        this.isAllDay = calendar.getIsAllDay();
        this.isImportant = calendar.getIsImportant();
        this.location = calendar.getLocation();
        this.createdBy = calendar.getCreatedBy();
        this.createdAt = calendar.getCreatedAt();
        this.updatedAt = calendar.getUpdatedAt();
    }

    // DTO를 Entity로 변환
    public Calendar toEntity() {
        Calendar calendar = new Calendar();
        calendar.setId(this.id);
        calendar.setTitle(this.title);
        calendar.setDescription(this.description);
        calendar.setStartDate(this.startDate);
        calendar.setEndDate(this.endDate);
        calendar.setCategory(this.category);
        calendar.setColor(this.color);
        calendar.setIsAllDay(this.isAllDay);
        calendar.setIsImportant(this.isImportant);
        calendar.setLocation(this.location);
        calendar.setCreatedBy(this.createdBy);
        return calendar;
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
