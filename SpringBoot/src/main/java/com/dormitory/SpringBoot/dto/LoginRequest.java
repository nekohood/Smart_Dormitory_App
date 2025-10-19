package com.dormitory.SpringBoot.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 로그인 요청 DTO - 완성된 버전
 */
public class LoginRequest {

    @NotBlank(message = "사용자 ID는 필수입니다")
    @Size(min = 3, max = 50, message = "사용자 ID는 3-50자 사이여야 합니다")
    @JsonProperty("id")
    private String id;

    @NotBlank(message = "비밀번호는 필수입니다")
    @Size(min = 1, max = 100, message = "비밀번호는 100자를 초과할 수 없습니다")
    @JsonProperty("password")
    private String password;

    @JsonProperty("rememberMe")
    private Boolean rememberMe = false;

    @JsonProperty("deviceInfo")
    private String deviceInfo;

    @JsonProperty("ipAddress")
    private String ipAddress;

    // 기본 생성자
    public LoginRequest() {}

    // 필수 필드 생성자
    public LoginRequest(String id, String password) {
        this.id = id;
        this.password = password;
        this.rememberMe = false;
    }

    // 전체 생성자
    public LoginRequest(String id, String password, Boolean rememberMe, String deviceInfo) {
        this.id = id;
        this.password = password;
        this.rememberMe = rememberMe != null ? rememberMe : false;
        this.deviceInfo = deviceInfo;
    }

    // Getter/Setter
    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id != null ? id.trim() : null;
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }

    public Boolean getRememberMe() {
        return rememberMe;
    }

    public void setRememberMe(Boolean rememberMe) {
        this.rememberMe = rememberMe != null ? rememberMe : false;
    }

    public String getDeviceInfo() {
        return deviceInfo;
    }

    public void setDeviceInfo(String deviceInfo) {
        this.deviceInfo = deviceInfo;
    }

    public String getIpAddress() {
        return ipAddress;
    }

    public void setIpAddress(String ipAddress) {
        this.ipAddress = ipAddress;
    }

    // 유틸리티 메서드들

    /**
     * 필수 필드가 모두 채워져 있는지 확인
     */
    public boolean isValid() {
        return id != null && !id.trim().isEmpty() &&
                password != null && !password.trim().isEmpty();
    }

    /**
     * 자동 로그인 여부 확인
     */
    public boolean isRememberMe() {
        return Boolean.TRUE.equals(rememberMe);
    }

    /**
     * 로그인 요청 정보 마스킹 (로그용)
     */
    public String toMaskedString() {
        return "LoginRequest{" +
                "id='" + (id != null ? id.substring(0, Math.min(id.length(), 3)) + "***" : null) + '\'' +
                ", password='[PROTECTED]'" +
                ", rememberMe=" + rememberMe +
                ", deviceInfo='" + deviceInfo + '\'' +
                ", ipAddress='" + (ipAddress != null ? maskIpAddress(ipAddress) : null) + '\'' +
                '}';
    }

    /**
     * IP 주소 마스킹
     */
    private String maskIpAddress(String ip) {
        if (ip == null) return null;

        String[] parts = ip.split("\\.");
        if (parts.length == 4) {
            return parts[0] + "." + parts[1] + ".***." + parts[3];
        }
        return "***";
    }

    /**
     * 로그인 시도 로그를 위한 안전한 정보 반환
     */
    public String getSecureLogInfo() {
        return String.format("User: %s, RememberMe: %s, Device: %s",
                id != null ? id.substring(0, Math.min(id.length(), 3)) + "***" : "null",
                rememberMe,
                deviceInfo != null ? deviceInfo : "Unknown");
    }

    @Override
    public String toString() {
        return "LoginRequest{" +
                "id='" + id + '\'' +
                ", password='[PROTECTED]'" +
                ", rememberMe=" + rememberMe +
                ", deviceInfo='" + deviceInfo + '\'' +
                ", ipAddress='" + ipAddress + '\'' +
                '}';
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        LoginRequest that = (LoginRequest) o;
        return id != null ? id.equals(that.id) : that.id == null;
    }

    @Override
    public int hashCode() {
        return id != null ? id.hashCode() : 0;
    }
}