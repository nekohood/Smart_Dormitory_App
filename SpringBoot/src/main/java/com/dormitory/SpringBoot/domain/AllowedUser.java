package com.dormitory.SpringBoot.domain;

import jakarta.persistence.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.LocalDateTime;

/**
 * 허용된 사용자 목록을 관리하는 엔티티
 * 관리자가 엑셀 파일 등으로 등록한 사용자만 회원가입 가능
 */
@Entity
@Table(name = "allowed_users")
@EntityListeners(AuditingEntityListener.class)
public class AllowedUser {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false, unique = true, length = 50)
    private String userId;

    @Column(name = "name", nullable = false, length = 100)
    private String name;

    @Column(name = "dormitory_building", length = 50)
    private String dormitoryBuilding;

    @Column(name = "room_number", length = 20)
    private String roomNumber;

    @Column(name = "phone_number", length = 20)
    private String phoneNumber;

    @Column(name = "email", length = 255)
    private String email;

    @Column(name = "is_registered", nullable = false)
    private Boolean isRegistered = false;

    @Column(name = "registered_at")
    private LocalDateTime registeredAt;

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @LastModifiedDate
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    // 기본 생성자
    public AllowedUser() {}

    // 전체 생성자
    public AllowedUser(String userId, String name, String dormitoryBuilding, String roomNumber, String phoneNumber, String email) {
        this.userId = userId;
        this.name = name;
        this.dormitoryBuilding = dormitoryBuilding;
        this.roomNumber = roomNumber;
        this.phoneNumber = phoneNumber;
        this.email = email;
        this.isRegistered = false;
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

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(LocalDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }

    /**
     * 회원가입 완료 처리
     */
    public void markAsRegistered() {
        this.isRegistered = true;
        this.registeredAt = LocalDateTime.now();
    }

    @Override
    public String toString() {
        return "AllowedUser{" +
                "id=" + id +
                ", userId='" + userId + '\'' +
                ", name='" + name + '\'' +
                ", dormitoryBuilding='" + dormitoryBuilding + '\'' +
                ", roomNumber='" + roomNumber + '\'' +
                ", isRegistered=" + isRegistered +
                '}';
    }
}