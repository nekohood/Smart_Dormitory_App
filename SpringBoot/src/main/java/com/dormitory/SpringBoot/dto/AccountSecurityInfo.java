package com.dormitory.SpringBoot.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.time.LocalDateTime;

public class AccountSecurityInfo {

    @JsonProperty("passwordLastChanged")
    private LocalDateTime passwordLastChanged;

    @JsonProperty("passwordExpired")
    private boolean passwordExpired;

    @JsonProperty("accountLocked")
    private boolean accountLocked;

    @JsonProperty("loginAttempts")
    private int loginAttempts;

    @JsonProperty("lockedUntil")
    private LocalDateTime lockedUntil;

    @JsonProperty("twoFactorEnabled")
    private boolean twoFactorEnabled = false;

    @JsonProperty("lastLoginLocation")
    private String lastLoginLocation;

    @JsonProperty("securityScore")
    private int securityScore; // 0-100

    // 기본 생성자
    public AccountSecurityInfo() {}

    // Getter/Setter
    public LocalDateTime getPasswordLastChanged() { return passwordLastChanged; }
    public void setPasswordLastChanged(LocalDateTime passwordLastChanged) { this.passwordLastChanged = passwordLastChanged; }

    public boolean isPasswordExpired() { return passwordExpired; }
    public void setPasswordExpired(boolean passwordExpired) { this.passwordExpired = passwordExpired; }

    public boolean isAccountLocked() { return accountLocked; }
    public void setAccountLocked(boolean accountLocked) { this.accountLocked = accountLocked; }

    public int getLoginAttempts() { return loginAttempts; }
    public void setLoginAttempts(int loginAttempts) { this.loginAttempts = loginAttempts; }

    public LocalDateTime getLockedUntil() { return lockedUntil; }
    public void setLockedUntil(LocalDateTime lockedUntil) { this.lockedUntil = lockedUntil; }

    public boolean isTwoFactorEnabled() { return twoFactorEnabled; }
    public void setTwoFactorEnabled(boolean twoFactorEnabled) { this.twoFactorEnabled = twoFactorEnabled; }

    public String getLastLoginLocation() { return lastLoginLocation; }
    public void setLastLoginLocation(String lastLoginLocation) { this.lastLoginLocation = lastLoginLocation; }

    public int getSecurityScore() { return securityScore; }
    public void setSecurityScore(int securityScore) { this.securityScore = securityScore; }
}