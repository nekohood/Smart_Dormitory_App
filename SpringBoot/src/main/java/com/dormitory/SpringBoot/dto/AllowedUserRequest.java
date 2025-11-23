package com.dormitory.SpringBoot.dto;

import com.fasterxml.jackson.annotation.JsonFormat;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 허용된 사용자 관리 관련 요청/응답 DTO
 */
public class AllowedUserRequest {

    /**
     * 사용자 추가 요청
     */
    public static class AddUserRequest {
        private String userId;
        private String name;
        private String dormitoryBuilding;
        private String roomNumber;
        private String phoneNumber;
        private String email;

        public AddUserRequest() {}

        public AddUserRequest(String userId, String name, String dormitoryBuilding,
                              String roomNumber, String phoneNumber, String email) {
            this.userId = userId;
            this.name = name;
            this.dormitoryBuilding = dormitoryBuilding;
            this.roomNumber = roomNumber;
            this.phoneNumber = phoneNumber;
            this.email = email;
        }

        public String getUserId() {
            return userId;
        }

        public void setUserId(String userId) {
            this.userId = userId;
        }

        public String getName() {
            return name;
        }

        public void setName(String name) {
            this.name = name;
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

        public String getPhoneNumber() {
            return phoneNumber;
        }

        public void setPhoneNumber(String phoneNumber) {
            this.phoneNumber = phoneNumber;
        }

        public String getEmail() {
            return email;
        }

        public void setEmail(String email) {
            this.email = email;
        }
    }

    /**
     * 엑셀 파일 업로드 응답
     */
    public static class UploadResponse {
        private int totalCount;
        private int successCount;
        private int failCount;
        private List<String> errors;

        public UploadResponse() {}

        public UploadResponse(int totalCount, int successCount, int failCount, List<String> errors) {
            this.totalCount = totalCount;
            this.successCount = successCount;
            this.failCount = failCount;
            this.errors = errors;
        }

        public int getTotalCount() {
            return totalCount;
        }

        public void setTotalCount(int totalCount) {
            this.totalCount = totalCount;
        }

        public int getSuccessCount() {
            return successCount;
        }

        public void setSuccessCount(int successCount) {
            this.successCount = successCount;
        }

        public int getFailCount() {
            return failCount;
        }

        public void setFailCount(int failCount) {
            this.failCount = failCount;
        }

        public List<String> getErrors() {
            return errors;
        }

        public void setErrors(List<String> errors) {
            this.errors = errors;
        }
    }

    /**
     * 허용 사용자 응답
     */
    public static class AllowedUserResponse {
        private Long id;
        private String userId;
        private String name;
        private String dormitoryBuilding;
        private String roomNumber;
        private String phoneNumber;
        private String email;
        private Boolean isRegistered;

        @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
        private LocalDateTime registeredAt;

        @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
        private LocalDateTime createdAt;

        public AllowedUserResponse() {}

        public AllowedUserResponse(Long id, String userId, String name, String dormitoryBuilding,
                                   String roomNumber, String phoneNumber, String email,
                                   Boolean isRegistered, LocalDateTime registeredAt, LocalDateTime createdAt) {
            this.id = id;
            this.userId = userId;
            this.name = name;
            this.dormitoryBuilding = dormitoryBuilding;
            this.roomNumber = roomNumber;
            this.phoneNumber = phoneNumber;
            this.email = email;
            this.isRegistered = isRegistered;
            this.registeredAt = registeredAt;
            this.createdAt = createdAt;
        }

        // Getters and Setters
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

        public String getName() {
            return name;
        }

        public void setName(String name) {
            this.name = name;
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

        public String getPhoneNumber() {
            return phoneNumber;
        }

        public void setPhoneNumber(String phoneNumber) {
            this.phoneNumber = phoneNumber;
        }

        public String getEmail() {
            return email;
        }

        public void setEmail(String email) {
            this.email = email;
        }

        public Boolean getIsRegistered() {
            return isRegistered;
        }

        public void setIsRegistered(Boolean isRegistered) {
            this.isRegistered = isRegistered;
        }

        public LocalDateTime getRegisteredAt() {
            return registeredAt;
        }

        public void setRegisteredAt(LocalDateTime registeredAt) {
            this.registeredAt = registeredAt;
        }

        public LocalDateTime getCreatedAt() {
            return createdAt;
        }

        public void setCreatedAt(LocalDateTime createdAt) {
            this.createdAt = createdAt;
        }
    }

    /**
     * 허용 사용자 목록 응답
     */
    public static class AllowedUserListResponse {
        private List<AllowedUserResponse> users;
        private long totalCount;
        private long registeredCount;
        private long unregisteredCount;

        public AllowedUserListResponse() {}

        public AllowedUserListResponse(List<AllowedUserResponse> users, long totalCount,
                                       long registeredCount, long unregisteredCount) {
            this.users = users;
            this.totalCount = totalCount;
            this.registeredCount = registeredCount;
            this.unregisteredCount = unregisteredCount;
        }

        public List<AllowedUserResponse> getUsers() {
            return users;
        }

        public void setUsers(List<AllowedUserResponse> users) {
            this.users = users;
        }

        public long getTotalCount() {
            return totalCount;
        }

        public void setTotalCount(long totalCount) {
            this.totalCount = totalCount;
        }

        public long getRegisteredCount() {
            return registeredCount;
        }

        public void setRegisteredCount(long registeredCount) {
            this.registeredCount = registeredCount;
        }

        public long getUnregisteredCount() {
            return unregisteredCount;
        }

        public void setUnregisteredCount(long unregisteredCount) {
            this.unregisteredCount = unregisteredCount;
        }
    }
}