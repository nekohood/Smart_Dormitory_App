package com.dormitory.SpringBoot.dto;

import com.dormitory.SpringBoot.domain.DDay;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * D-Day 데이터 전송 객체
 */
public class DDayDTO {

    private Long id;
    private String title;
    private String description;
    private LocalDate targetDate;
    private String color;
    private Boolean isActive;
    private Boolean isImportant;
    private String createdBy;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    private Long daysRemaining; // 남은 일수 (계산 필드)
    private Boolean isPast; // 지난 날짜인지 (계산 필드)
    private Boolean isToday; // 오늘인지 (계산 필드)

    // 기본 생성자
    public DDayDTO() {
    }

    // Entity로부터 DTO 생성
    public DDayDTO(DDay dday) {
        this.id = dday.getId();
        this.title = dday.getTitle();
        this.description = dday.getDescription();
        this.targetDate = dday.getTargetDate();
        this.color = dday.getColor();
        this.isActive = dday.getIsActive();
        this.isImportant = dday.getIsImportant();
        this.createdBy = dday.getCreatedBy();
        this.createdAt = dday.getCreatedAt();
        this.updatedAt = dday.getUpdatedAt();
        this.daysRemaining = dday.getDaysRemaining();
        this.isPast = dday.isPast();
        this.isToday = dday.isToday();
    }

    // DTO를 Entity로 변환
    public DDay toEntity() {
        DDay dday = new DDay();
        dday.setId(this.id);
        dday.setTitle(this.title);
        dday.setDescription(this.description);
        dday.setTargetDate(this.targetDate);
        dday.setColor(this.color);
        dday.setIsActive(this.isActive);
        dday.setIsImportant(this.isImportant);
        dday.setCreatedBy(this.createdBy);
        return dday;
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

    public LocalDate getTargetDate() {
        return targetDate;
    }

    public void setTargetDate(LocalDate targetDate) {
        this.targetDate = targetDate;
    }

    public String getColor() {
        return color;
    }

    public void setColor(String color) {
        this.color = color;
    }

    public Boolean getIsActive() {
        return isActive;
    }

    public void setIsActive(Boolean isActive) {
        this.isActive = isActive;
    }

    public Boolean getIsImportant() {
        return isImportant;
    }

    public void setIsImportant(Boolean isImportant) {
        this.isImportant = isImportant;
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

    public Long getDaysRemaining() {
        return daysRemaining;
    }

    public void setDaysRemaining(Long daysRemaining) {
        this.daysRemaining = daysRemaining;
    }

    public Boolean getIsPast() {
        return isPast;
    }

    public void setIsPast(Boolean isPast) {
        this.isPast = isPast;
    }

    public Boolean getIsToday() {
        return isToday;
    }

    public void setIsToday(Boolean isToday) {
        this.isToday = isToday;
    }
}
