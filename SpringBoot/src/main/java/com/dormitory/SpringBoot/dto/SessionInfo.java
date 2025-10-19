package com.dormitory.SpringBoot.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.time.LocalDateTime;
import java.time.Duration;

/**
 * 세션 정보 DTO
 */
public class SessionInfo {

    @JsonProperty("sessionId")
    private String sessionId;

    @JsonProperty("userId")
    private String userId;

    @JsonProperty("loginTime")
    private LocalDateTime loginTime;

    @JsonProperty("lastActivity")
    private LocalDateTime lastActivity;

    @JsonProperty("ipAddress")
    private String ipAddress;

    @JsonProperty("userAgent")
    private String userAgent;

    @JsonProperty("deviceType")
    private String deviceType;

    @JsonProperty("location")
    private String location;

    @JsonProperty("isActive")
    private boolean isActive = true;

    @JsonProperty("expiresAt")
    private LocalDateTime expiresAt;

    @JsonProperty("sessionDuration")
    private String sessionDuration;

    @JsonProperty("browser")
    private String browser;

    @JsonProperty("operatingSystem")
    private String operatingSystem;

    // 기본 생성자
    public SessionInfo() {}

    // 전체 생성자
    public SessionInfo(String sessionId, String userId, LocalDateTime loginTime) {
        this.sessionId = sessionId;
        this.userId = userId;
        this.loginTime = loginTime;
        this.lastActivity = LocalDateTime.now();
        this.isActive = true;
        // 24시간 후 만료
        this.expiresAt = loginTime.plusHours(24);
    }

    // Getter/Setter
    public String getSessionId() {
        return sessionId;
    }

    public void setSessionId(String sessionId) {
        this.sessionId = sessionId;
    }

    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    public LocalDateTime getLoginTime() {
        return loginTime;
    }

    public void setLoginTime(LocalDateTime loginTime) {
        this.loginTime = loginTime;
    }

    public LocalDateTime getLastActivity() {
        return lastActivity;
    }

    public void setLastActivity(LocalDateTime lastActivity) {
        this.lastActivity = lastActivity;
    }

    public String getIpAddress() {
        return ipAddress;
    }

    public void setIpAddress(String ipAddress) {
        this.ipAddress = ipAddress;
    }

    public String getUserAgent() {
        return userAgent;
    }

    public void setUserAgent(String userAgent) {
        this.userAgent = userAgent;
        // User-Agent에서 브라우저와 OS 정보 추출
        parseUserAgent();
    }

    public String getDeviceType() {
        return deviceType;
    }

    public void setDeviceType(String deviceType) {
        this.deviceType = deviceType;
    }

    public String getLocation() {
        return location;
    }

    public void setLocation(String location) {
        this.location = location;
    }

    public boolean isActive() {
        return isActive;
    }

    public void setActive(boolean active) {
        isActive = active;
    }

    public LocalDateTime getExpiresAt() {
        return expiresAt;
    }

    public void setExpiresAt(LocalDateTime expiresAt) {
        this.expiresAt = expiresAt;
    }

    public String getSessionDuration() {
        if (loginTime != null) {
            Duration duration = Duration.between(loginTime,
                    lastActivity != null ? lastActivity : LocalDateTime.now());
            return formatDuration(duration);
        }
        return sessionDuration;
    }

    public void setSessionDuration(String sessionDuration) {
        this.sessionDuration = sessionDuration;
    }

    public String getBrowser() {
        return browser;
    }

    public void setBrowser(String browser) {
        this.browser = browser;
    }

    public String getOperatingSystem() {
        return operatingSystem;
    }

    public void setOperatingSystem(String operatingSystem) {
        this.operatingSystem = operatingSystem;
    }

    // 유틸리티 메서드들

    /**
     * 세션이 만료되었는지 확인
     */
    public boolean isExpired() {
        return expiresAt != null && LocalDateTime.now().isAfter(expiresAt);
    }

    /**
     * 세션이 비활성 상태인지 확인 (30분 이상 활동 없음)
     */
    public boolean isInactive() {
        if (lastActivity == null) return false;
        return Duration.between(lastActivity, LocalDateTime.now()).toMinutes() > 30;
    }

    /**
     * 세션 연장
     */
    public void extendSession(int hours) {
        this.expiresAt = LocalDateTime.now().plusHours(hours);
        this.lastActivity = LocalDateTime.now();
    }

    /**
     * 세션 종료
     */
    public void terminateSession() {
        this.isActive = false;
        this.expiresAt = LocalDateTime.now();
    }

    /**
     * User-Agent 파싱
     */
    private void parseUserAgent() {
        if (userAgent == null) return;

        String ua = userAgent.toLowerCase();

        // 브라우저 감지
        if (ua.contains("chrome")) {
            browser = "Chrome";
        } else if (ua.contains("firefox")) {
            browser = "Firefox";
        } else if (ua.contains("safari")) {
            browser = "Safari";
        } else if (ua.contains("edge")) {
            browser = "Edge";
        } else {
            browser = "Unknown";
        }

        // 운영체제 감지
        if (ua.contains("windows")) {
            operatingSystem = "Windows";
        } else if (ua.contains("mac")) {
            operatingSystem = "macOS";
        } else if (ua.contains("linux")) {
            operatingSystem = "Linux";
        } else if (ua.contains("android")) {
            operatingSystem = "Android";
            deviceType = "Mobile";
        } else if (ua.contains("iphone") || ua.contains("ipad")) {
            operatingSystem = "iOS";
            deviceType = "Mobile";
        } else {
            operatingSystem = "Unknown";
        }

        // 디바이스 타입 감지
        if (deviceType == null) {
            if (ua.contains("mobile") || ua.contains("tablet")) {
                deviceType = "Mobile";
            } else {
                deviceType = "Desktop";
            }
        }
    }

    /**
     * Duration을 사람이 읽기 쉬운 형식으로 변환
     */
    private String formatDuration(Duration duration) {
        long hours = duration.toHours();
        long minutes = duration.toMinutesPart();

        if (hours > 0) {
            return String.format("%d시간 %d분", hours, minutes);
        } else {
            return String.format("%d분", minutes);
        }
    }

    @Override
    public String toString() {
        return "SessionInfo{" +
                "sessionId='" + sessionId + '\'' +
                ", userId='" + userId + '\'' +
                ", loginTime=" + loginTime +
                ", lastActivity=" + lastActivity +
                ", ipAddress='" + ipAddress + '\'' +
                ", deviceType='" + deviceType + '\'' +
                ", browser='" + browser + '\'' +
                ", operatingSystem='" + operatingSystem + '\'' +
                ", isActive=" + isActive +
                ", isExpired=" + isExpired() +
                '}';
    }
}