package com.dormitory.SpringBoot.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.Pattern;

/**
 * 알림 설정 DTO
 */
public class NotificationSettings {

    @JsonProperty("inspectionReminder")
    private boolean inspectionReminder = true;

    @JsonProperty("complaintUpdates")
    private boolean complaintUpdates = true;

    @JsonProperty("systemNotifications")
    private boolean systemNotifications = true;

    @JsonProperty("emailNotifications")
    private boolean emailNotifications = false;

    @JsonProperty("pushNotifications")
    private boolean pushNotifications = true;

    @Pattern(regexp = "^([01]?[0-9]|2[0-3]):[0-5][0-9]$", message = "시간 형식이 올바르지 않습니다 (HH:mm)")
    @JsonProperty("reminderTime")
    private String reminderTime = "20:00"; // 점호 알림 시간

    @JsonProperty("weekendNotifications")
    private boolean weekendNotifications = false;

    @JsonProperty("maintenanceNotifications")
    private boolean maintenanceNotifications = true;

    // 기본 생성자
    public NotificationSettings() {}

    // 전체 생성자
    public NotificationSettings(boolean inspectionReminder, boolean complaintUpdates,
                                boolean systemNotifications, boolean emailNotifications) {
        this.inspectionReminder = inspectionReminder;
        this.complaintUpdates = complaintUpdates;
        this.systemNotifications = systemNotifications;
        this.emailNotifications = emailNotifications;
    }

    // Getter/Setter
    public boolean isInspectionReminder() {
        return inspectionReminder;
    }

    public void setInspectionReminder(boolean inspectionReminder) {
        this.inspectionReminder = inspectionReminder;
    }

    public boolean isComplaintUpdates() {
        return complaintUpdates;
    }

    public void setComplaintUpdates(boolean complaintUpdates) {
        this.complaintUpdates = complaintUpdates;
    }

    public boolean isSystemNotifications() {
        return systemNotifications;
    }

    public void setSystemNotifications(boolean systemNotifications) {
        this.systemNotifications = systemNotifications;
    }

    public boolean isEmailNotifications() {
        return emailNotifications;
    }

    public void setEmailNotifications(boolean emailNotifications) {
        this.emailNotifications = emailNotifications;
    }

    public boolean isPushNotifications() {
        return pushNotifications;
    }

    public void setPushNotifications(boolean pushNotifications) {
        this.pushNotifications = pushNotifications;
    }

    public String getReminderTime() {
        return reminderTime;
    }

    public void setReminderTime(String reminderTime) {
        this.reminderTime = reminderTime;
    }

    public boolean isWeekendNotifications() {
        return weekendNotifications;
    }

    public void setWeekendNotifications(boolean weekendNotifications) {
        this.weekendNotifications = weekendNotifications;
    }

    public boolean isMaintenanceNotifications() {
        return maintenanceNotifications;
    }

    public void setMaintenanceNotifications(boolean maintenanceNotifications) {
        this.maintenanceNotifications = maintenanceNotifications;
    }

    // 유틸리티 메서드들

    /**
     * 모든 알림을 비활성화
     */
    public void disableAll() {
        this.inspectionReminder = false;
        this.complaintUpdates = false;
        this.systemNotifications = false;
        this.emailNotifications = false;
        this.pushNotifications = false;
        this.weekendNotifications = false;
        this.maintenanceNotifications = false;
    }

    /**
     * 기본 설정으로 복원
     */
    public void resetToDefault() {
        this.inspectionReminder = true;
        this.complaintUpdates = true;
        this.systemNotifications = true;
        this.emailNotifications = false;
        this.pushNotifications = true;
        this.reminderTime = "20:00";
        this.weekendNotifications = false;
        this.maintenanceNotifications = true;
    }

    /**
     * 알림이 하나라도 활성화되어 있는지 확인
     */
    public boolean hasAnyNotificationEnabled() {
        return inspectionReminder || complaintUpdates || systemNotifications ||
                emailNotifications || pushNotifications || weekendNotifications ||
                maintenanceNotifications;
    }

    @Override
    public String toString() {
        return "NotificationSettings{" +
                "inspectionReminder=" + inspectionReminder +
                ", complaintUpdates=" + complaintUpdates +
                ", systemNotifications=" + systemNotifications +
                ", emailNotifications=" + emailNotifications +
                ", pushNotifications=" + pushNotifications +
                ", reminderTime='" + reminderTime + '\'' +
                ", weekendNotifications=" + weekendNotifications +
                ", maintenanceNotifications=" + maintenanceNotifications +
                '}';
    }
}