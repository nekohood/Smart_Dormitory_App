package com.dormitory.SpringBoot.domain;

import jakarta.persistence.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.LocalDateTime;

/**
 * 사용자 정보를 저장하는 엔티티 - DB 스키마 완전 동기화 버전
 */
@Entity
@Table(name = "users")
@EntityListeners(AuditingEntityListener.class)
public class User {

    @Id
    @Column(name = "user_id", nullable = false, length = 50)
    private String id;

    @Column(name = "password_hash", nullable = false, length = 255)
    private String password;

    @Column(name = "name_encrypted", length = 255)
    private String name;

    @Column(name = "email_encrypted", length = 255)
    private String email;

    @Column(name = "email_hash", length = 255, unique = true)
    private String emailHash;

    @Column(name = "phone_encrypted", length = 255)
    private String phoneNumber;

    @Column(name = "room_number", length = 20) // DB에 room_number_encrypted가 있지만, 코드는 room_number를 사용중이므로 우선 유지
    private String roomNumber;

    @Column(name = "is_admin", nullable = false)
    private Boolean isAdmin = false;

    @Column(name = "profile_image_path", length = 500)
    private String profileImagePath;

    // 알림 설정
    @Column(name = "inspection_reminder")
    private Boolean inspectionReminder = true;

    @Column(name = "complaint_updates")
    private Boolean complaintUpdates = true;

    @Column(name = "system_notifications")
    private Boolean systemNotifications = true;

    @Column(name = "email_notifications")
    private Boolean emailNotifications = false;

    // 계정 상태
    @Column(name = "is_active")
    private Boolean isActive = true;

    @Column(name = "is_locked")
    private Boolean isLocked = false;

    @Column(name = "login_attempts")
    private Integer loginAttempts = 0;

    @Column(name = "locked_until")
    private LocalDateTime lockedUntil;

    @Column(name = "last_login_at")
    private LocalDateTime lastLoginAt;

    @Column(name = "password_changed_at")
    private LocalDateTime passwordChangedAt;

    // JPA 감사 필드
    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @LastModifiedDate
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    // ... (이하 Getter, Setter 및 다른 메서드들은 변경 없음) ...

    // 기본 생성자
    public User() {}

    // 기본 생성자 (필수 필드만)
    public User(String id, String password, Boolean isAdmin) {
        this.id = id;
        this.password = password;
        this.isAdmin = isAdmin != null ? isAdmin : false;
    }

    // 전체 생성자
    public User(String id, String password, String name, String email,
                String phoneNumber, String roomNumber, Boolean isAdmin) {
        this.id = id;
        this.password = password;
        this.name = name;
        this.email = email;
        this.phoneNumber = phoneNumber;
        this.roomNumber = roomNumber;
        this.isAdmin = isAdmin != null ? isAdmin : false;
    }

    // Getter & Setter
    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
        this.passwordChangedAt = LocalDateTime.now();
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getEmailHash() {
        return emailHash;
    }

    public void setEmailHash(String emailHash) {
        this.emailHash = emailHash;
    }

    public String getPhoneNumber() {
        return phoneNumber;
    }

    public void setPhoneNumber(String phoneNumber) {
        this.phoneNumber = phoneNumber;
    }

    public String getRoomNumber() {
        return roomNumber;
    }

    public void setRoomNumber(String roomNumber) {
        this.roomNumber = roomNumber;
    }

    public Boolean getIsAdmin() {
        return isAdmin;
    }

    public void setIsAdmin(Boolean isAdmin) {
        this.isAdmin = isAdmin != null ? isAdmin : false;
    }

    public String getProfileImagePath() {
        return profileImagePath;
    }

    public void setProfileImagePath(String profileImagePath) {
        this.profileImagePath = profileImagePath;
    }

    public Boolean getInspectionReminder() {
        return inspectionReminder;
    }

    public void setInspectionReminder(Boolean inspectionReminder) {
        this.inspectionReminder = inspectionReminder;
    }

    public Boolean getComplaintUpdates() {
        return complaintUpdates;
    }

    public void setComplaintUpdates(Boolean complaintUpdates) {
        this.complaintUpdates = complaintUpdates;
    }

    public Boolean getSystemNotifications() {
        return systemNotifications;
    }

    public void setSystemNotifications(Boolean systemNotifications) {
        this.systemNotifications = systemNotifications;
    }

    public Boolean getEmailNotifications() {
        return emailNotifications;
    }

    public void setEmailNotifications(Boolean emailNotifications) {
        this.emailNotifications = emailNotifications;
    }

    public Boolean getIsActive() {
        return isActive;
    }

    public void setIsActive(Boolean isActive) {
        this.isActive = isActive;
    }

    public Boolean getIsLocked() {
        return isLocked;
    }

    public void setIsLocked(Boolean isLocked) {
        this.isLocked = isLocked;
    }

    public Integer getLoginAttempts() {
        return loginAttempts;
    }

    public void setLoginAttempts(Integer loginAttempts) {
        this.loginAttempts = loginAttempts;
    }

    public LocalDateTime getLockedUntil() {
        return lockedUntil;
    }

    public void setLockedUntil(LocalDateTime lockedUntil) {
        this.lockedUntil = lockedUntil;
    }

    public LocalDateTime getLastLoginAt() {
        return lastLoginAt;
    }

    public void setLastLoginAt(LocalDateTime lastLoginAt) {
        this.lastLoginAt = lastLoginAt;
    }

    public LocalDateTime getPasswordChangedAt() {
        return passwordChangedAt;
    }

    public void setPasswordChangedAt(LocalDateTime passwordChangedAt) {
        this.passwordChangedAt = passwordChangedAt;
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
     * 로그인 시도 실패 시 호출
     */
    public void incrementLoginAttempts() {
        this.loginAttempts = (this.loginAttempts != null ? this.loginAttempts : 0) + 1;

        // 5회 실패 시 계정 잠금 (30분)
        if (this.loginAttempts >= 5) {
            this.isLocked = true;
            this.lockedUntil = LocalDateTime.now().plusMinutes(30);
        }
    }

    /**
     * 로그인 성공 시 호출 - 에러 해결을 위해 추가
     */
    public void onLoginSuccess() {
        this.lastLoginAt = LocalDateTime.now();
        this.loginAttempts = 0;
        this.isLocked = false;
        this.lockedUntil = null;
    }

    /**
     * 로그인 시도 횟수 초기화 (기존 메서드)
     */
    public void resetLoginAttempts() {
        this.loginAttempts = 0;
        this.isLocked = false;
        this.lockedUntil = null;
        this.lastLoginAt = LocalDateTime.now();
    }

    /**
     * 계정이 잠겨있는지 확인 - 에러 해결을 위해 추가
     */
    public boolean isAccountLocked() {
        if (!Boolean.TRUE.equals(this.isLocked)) {
            return false;
        }

        if (this.lockedUntil == null) {
            return true;
        }

        return LocalDateTime.now().isBefore(this.lockedUntil);
    }

    /**
     * 계정 잠금
     */
    public void lockAccount(int lockoutDurationMinutes) {
        this.isLocked = true;
        this.lockedUntil = LocalDateTime.now().plusMinutes(lockoutDurationMinutes);
    }

    /**
     * 계정 잠금 해제 (시간이 지난 경우)
     */
    public void unlockAccountIfNeeded() {
        if (this.isLocked && this.lockedUntil != null &&
                LocalDateTime.now().isAfter(this.lockedUntil)) {
            this.isLocked = false;
            this.lockedUntil = null;
            this.loginAttempts = 0;
        }
    }

    /**
     * 계정이 현재 잠겨있는지 확인 (기존 메서드)
     */
    public boolean isCurrentlyLocked() {
        return isAccountLocked();
    }

    /**
     * 비밀번호 만료 확인 (90일)
     */
    public boolean isPasswordExpired() {
        if (passwordChangedAt == null) {
            // 비밀번호 변경 기록이 없으면 계정 생성일 기준
            return createdAt != null &&
                    createdAt.isBefore(LocalDateTime.now().minusDays(90));
        }
        return passwordChangedAt.isBefore(LocalDateTime.now().minusDays(90));
    }

    @Override
    public String toString() {
        return "User{" +
                "id='" + id + '\'' +
                ", name='" + name + '\'' +
                ", email='" + email + '\'' +
                ", roomNumber='" + roomNumber + '\'' +
                ", isAdmin=" + isAdmin +
                ", isActive=" + isActive +
                ", isLocked=" + isLocked +
                ", createdAt=" + createdAt +
                '}';
    }
}