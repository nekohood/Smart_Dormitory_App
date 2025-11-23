package com.dormitory.SpringBoot.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.time.LocalDateTime;

/**
 * 사용자 정보 응답 DTO - dormitoryBuilding 포함
 */
public class UserResponse {

    @JsonProperty("id")
    private String id;

    @JsonProperty("name")
    private String name;

    @JsonProperty("email")
    private String email;

    @JsonProperty("phoneNumber")
    private String phoneNumber;

    @JsonProperty("dormitoryBuilding")
    private String dormitoryBuilding;

    @JsonProperty("roomNumber")
    private String roomNumber;

    @JsonProperty("isAdmin")
    private Boolean isAdmin;

    @JsonProperty("profileImagePath")
    private String profileImagePath;

    @JsonProperty("isActive")
    private Boolean isActive;

    @JsonProperty("isLocked")
    private Boolean isLocked;

    @JsonProperty("lastLoginAt")
    private LocalDateTime lastLoginAt;

    @JsonProperty("createdAt")
    private LocalDateTime createdAt;

    @JsonProperty("updatedAt")
    private LocalDateTime updatedAt;

    @JsonProperty("passwordChangedAt")
    private LocalDateTime passwordChangedAt;

    @JsonProperty("loginAttempts")
    private Integer loginAttempts;

    // 기본 생성자
    public UserResponse() {}

    // 전체 생성자
    public UserResponse(String id, String name, String email, String phoneNumber,
                        String dormitoryBuilding, String roomNumber, Boolean isAdmin,
                        String profileImagePath, Boolean isActive, Boolean isLocked,
                        LocalDateTime createdAt, LocalDateTime updatedAt, LocalDateTime lastLoginAt) {
        this.id = id;
        this.name = name;
        this.email = email;
        this.phoneNumber = phoneNumber;
        this.dormitoryBuilding = dormitoryBuilding;
        this.roomNumber = roomNumber;
        this.isAdmin = isAdmin;
        this.profileImagePath = profileImagePath;
        this.isActive = isActive;
        this.isLocked = isLocked;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
        this.lastLoginAt = lastLoginAt;
    }

    // Getter/Setter 메서드들
    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
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

    public String getPhoneNumber() {
        return phoneNumber;
    }

    public void setPhoneNumber(String phoneNumber) {
        this.phoneNumber = phoneNumber;
    }

    public String getDormitoryBuilding() {
        return dormitoryBuilding;
    }

    public void setDormitoryBuilding(String dormitoryBuilding) {
        this.dormitoryBuilding = dormitoryBuilding;
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
        this.isAdmin = isAdmin;
    }

    public String getProfileImagePath() {
        return profileImagePath;
    }

    public void setProfileImagePath(String profileImagePath) {
        this.profileImagePath = profileImagePath;
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

    public LocalDateTime getLastLoginAt() {
        return lastLoginAt;
    }

    public void setLastLoginAt(LocalDateTime lastLoginAt) {
        this.lastLoginAt = lastLoginAt;
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

    public LocalDateTime getPasswordChangedAt() {
        return passwordChangedAt;
    }

    public void setPasswordChangedAt(LocalDateTime passwordChangedAt) {
        this.passwordChangedAt = passwordChangedAt;
    }

    public Integer getLoginAttempts() {
        return loginAttempts;
    }

    public void setLoginAttempts(Integer loginAttempts) {
        this.loginAttempts = loginAttempts;
    }

    @Override
    public String toString() {
        return "UserResponse{" +
                "id='" + id + '\'' +
                ", name='" + name + '\'' +
                ", email='" + email + '\'' +
                ", dormitoryBuilding='" + dormitoryBuilding + '\'' +
                ", roomNumber='" + roomNumber + '\'' +
                ", isAdmin=" + isAdmin +
                ", isActive=" + isActive +
                ", isLocked=" + isLocked +
                ", createdAt=" + createdAt +
                '}';
    }
}