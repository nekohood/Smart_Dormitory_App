package com.dormitory.SpringBoot.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 비밀번호 변경 요청 DTO
 * ✅ 수정: currentPassword와 oldPassword 모두 지원
 * ✅ 수정: confirmPassword를 선택적 필드로 변경 (클라이언트에서 검증)
 */
public class ChangePasswordRequest {

    @JsonProperty("oldPassword")
    private String oldPassword;

    @JsonProperty("currentPassword")
    private String currentPassword;

    @NotBlank(message = "새 비밀번호는 필수입니다")
    @Size(min = 4, max = 100, message = "새 비밀번호는 4-100자 사이여야 합니다")
    @JsonProperty("newPassword")
    private String newPassword;

    @JsonProperty("confirmPassword")
    private String confirmPassword;

    // 기본 생성자
    public ChangePasswordRequest() {}

    // Getter/Setter
    public String getOldPassword() {
        // currentPassword가 설정되어 있으면 그것을 반환, 아니면 oldPassword 반환
        if (currentPassword != null && !currentPassword.isEmpty()) {
            return currentPassword;
        }
        return oldPassword;
    }

    public void setOldPassword(String oldPassword) {
        this.oldPassword = oldPassword;
    }

    public String getCurrentPassword() {
        return currentPassword;
    }

    public void setCurrentPassword(String currentPassword) {
        this.currentPassword = currentPassword;
    }

    public String getNewPassword() {
        return newPassword;
    }

    public void setNewPassword(String newPassword) {
        this.newPassword = newPassword;
    }

    public String getConfirmPassword() {
        return confirmPassword;
    }

    public void setConfirmPassword(String confirmPassword) {
        this.confirmPassword = confirmPassword;
    }

    /**
     * 현재 비밀번호 값 반환 (oldPassword 또는 currentPassword)
     */
    public String getEffectiveCurrentPassword() {
        if (currentPassword != null && !currentPassword.isEmpty()) {
            return currentPassword;
        }
        return oldPassword;
    }

    /**
     * 현재 비밀번호가 입력되었는지 확인
     */
    public boolean hasCurrentPassword() {
        return (currentPassword != null && !currentPassword.isEmpty()) ||
                (oldPassword != null && !oldPassword.isEmpty());
    }

    @Override
    public String toString() {
        return "ChangePasswordRequest{" +
                "oldPassword='[PROTECTED]'" +
                ", currentPassword='[PROTECTED]'" +
                ", newPassword='[PROTECTED]'" +
                ", confirmPassword='[PROTECTED]'" +
                '}';
    }
}