package com.dormitory.SpringBoot.domain;

import jakarta.persistence.*;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.Arrays;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * 점호 설정 엔티티
 * ✅ 수정: inspectionDate 필드 추가 (특정 날짜에만 점호 가능하도록)
 */
@Entity
@Table(name = "inspection_settings")
public class InspectionSettings {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "setting_name", nullable = false, unique = true)
    private String settingName;

    @Column(name = "start_time", nullable = false)
    private LocalTime startTime;

    @Column(name = "end_time", nullable = false)
    private LocalTime endTime;

    // ✅ 신규 추가: 점호 날짜 (특정 날짜에만 점호 가능)
    @Column(name = "inspection_date")
    private LocalDate inspectionDate;

    @Column(name = "is_enabled", nullable = false)
    private Boolean isEnabled = true;

    @Column(name = "camera_only", nullable = false)
    private Boolean cameraOnly = true;

    @Column(name = "exif_validation_enabled", nullable = false)
    private Boolean exifValidationEnabled = true;

    @Column(name = "exif_time_tolerance_minutes", nullable = false)
    private Integer exifTimeToleranceMinutes = 10;

    @Column(name = "gps_validation_enabled", nullable = false)
    private Boolean gpsValidationEnabled = false;

    @Column(name = "dormitory_latitude")
    private Double dormitoryLatitude;

    @Column(name = "dormitory_longitude")
    private Double dormitoryLongitude;

    @Column(name = "gps_radius_meters")
    private Integer gpsRadiusMeters = 100;

    @Column(name = "room_photo_validation_enabled", nullable = false)
    private Boolean roomPhotoValidationEnabled = true;

    @Column(name = "applicable_days", length = 50)
    private String applicableDays = "ALL";

    @Column(name = "is_default", nullable = false)
    private Boolean isDefault = false;

    // ✅ 신규 추가: 캘린더 일정 ID (연동된 캘린더 일정)
    @Column(name = "schedule_id")
    private Long scheduleId;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @Column(name = "created_by", length = 50)
    private String createdBy;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
    }

    /**
     * ✅ 수정: 현재 날짜와 시간이 점호 허용 범위 내인지 확인
     */
    public boolean isWithinAllowedTime() {
        if (!Boolean.TRUE.equals(isEnabled)) {
            return false;
        }

        LocalDate today = LocalDate.now();
        LocalTime now = LocalTime.now();

        // ✅ 점호 날짜가 설정되어 있으면 해당 날짜인지 확인
        if (inspectionDate != null) {
            if (!today.equals(inspectionDate)) {
                return false;  // 오늘이 점호 날짜가 아니면 false
            }
        }

        // 시간 확인
        if (startTime.isBefore(endTime)) {
            return !now.isBefore(startTime) && !now.isAfter(endTime);
        } else {
            // 자정을 넘어가는 경우 (예: 23:00 ~ 01:00)
            return !now.isBefore(startTime) || !now.isAfter(endTime);
        }
    }

    /**
     * ✅ 신규: 오늘이 점호 날짜인지 확인
     */
    public boolean isInspectionDateToday() {
        if (inspectionDate == null) {
            return true;  // 날짜 미설정시 매일 점호 가능 (기존 방식)
        }
        return LocalDate.now().equals(inspectionDate);
    }

    /**
     * ✅ 신규: 점호 날짜까지 남은 일수 계산
     */
    public long getDaysUntilInspection() {
        if (inspectionDate == null) {
            return 0;
        }
        LocalDate today = LocalDate.now();
        return java.time.temporal.ChronoUnit.DAYS.between(today, inspectionDate);
    }

    /**
     * 현재 요일에 적용되는 설정인지 확인
     */
    public boolean isApplicableToday() {
        // ✅ 점호 날짜가 설정되어 있으면 요일 무시
        if (inspectionDate != null) {
            return LocalDate.now().equals(inspectionDate);
        }

        if (applicableDays == null || "ALL".equalsIgnoreCase(applicableDays)) {
            return true;
        }

        DayOfWeek today = LocalDateTime.now().getDayOfWeek();
        String todayStr = today.toString().substring(0, 3);

        Set<String> days = Arrays.stream(applicableDays.split(","))
                .map(String::trim)
                .map(String::toUpperCase)
                .collect(Collectors.toSet());

        return days.contains(todayStr);
    }

    // ==================== Getters and Setters ====================

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getSettingName() { return settingName; }
    public void setSettingName(String settingName) { this.settingName = settingName; }

    public LocalTime getStartTime() { return startTime; }
    public void setStartTime(LocalTime startTime) { this.startTime = startTime; }

    public LocalTime getEndTime() { return endTime; }
    public void setEndTime(LocalTime endTime) { this.endTime = endTime; }

    // ✅ 신규
    public LocalDate getInspectionDate() { return inspectionDate; }
    public void setInspectionDate(LocalDate inspectionDate) { this.inspectionDate = inspectionDate; }

    public Boolean getIsEnabled() { return isEnabled; }
    public void setIsEnabled(Boolean isEnabled) { this.isEnabled = isEnabled; }

    public Boolean getCameraOnly() { return cameraOnly; }
    public void setCameraOnly(Boolean cameraOnly) { this.cameraOnly = cameraOnly; }

    public Boolean getExifValidationEnabled() { return exifValidationEnabled; }
    public void setExifValidationEnabled(Boolean exifValidationEnabled) { this.exifValidationEnabled = exifValidationEnabled; }

    public Integer getExifTimeToleranceMinutes() { return exifTimeToleranceMinutes; }
    public void setExifTimeToleranceMinutes(Integer exifTimeToleranceMinutes) { this.exifTimeToleranceMinutes = exifTimeToleranceMinutes; }

    public Boolean getGpsValidationEnabled() { return gpsValidationEnabled; }
    public void setGpsValidationEnabled(Boolean gpsValidationEnabled) { this.gpsValidationEnabled = gpsValidationEnabled; }

    public Double getDormitoryLatitude() { return dormitoryLatitude; }
    public void setDormitoryLatitude(Double dormitoryLatitude) { this.dormitoryLatitude = dormitoryLatitude; }

    public Double getDormitoryLongitude() { return dormitoryLongitude; }
    public void setDormitoryLongitude(Double dormitoryLongitude) { this.dormitoryLongitude = dormitoryLongitude; }

    public Integer getGpsRadiusMeters() { return gpsRadiusMeters; }
    public void setGpsRadiusMeters(Integer gpsRadiusMeters) { this.gpsRadiusMeters = gpsRadiusMeters; }

    public Boolean getRoomPhotoValidationEnabled() { return roomPhotoValidationEnabled; }
    public void setRoomPhotoValidationEnabled(Boolean roomPhotoValidationEnabled) { this.roomPhotoValidationEnabled = roomPhotoValidationEnabled; }

    public String getApplicableDays() { return applicableDays; }
    public void setApplicableDays(String applicableDays) { this.applicableDays = applicableDays; }

    public Boolean getIsDefault() { return isDefault; }
    public void setIsDefault(Boolean isDefault) { this.isDefault = isDefault; }

    // ✅ 신규
    public Long getScheduleId() { return scheduleId; }
    public void setScheduleId(Long scheduleId) { this.scheduleId = scheduleId; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }

    public String getCreatedBy() { return createdBy; }
    public void setCreatedBy(String createdBy) { this.createdBy = createdBy; }
}