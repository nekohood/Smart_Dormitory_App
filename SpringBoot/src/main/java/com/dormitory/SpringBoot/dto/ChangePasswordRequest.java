package com.dormitory.SpringBoot.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 비밀번호 변경 요청 DTO
 */
public class ChangePasswordRequest {

    @NotBlank(message = "기존 비밀번호는 필수입니다")
    @JsonProperty("oldPassword")
    private String oldPassword;

    @NotBlank(message = "새 비밀번호는 필수입니다")
    @Size(min = 8, max = 100, message = "새 비밀번호는 8-100자 사이여야 합니다")
    @JsonProperty("newPassword")
    private String newPassword;

    @NotBlank(message = "비밀번호 확인은 필수입니다")
    @JsonProperty("confirmPassword")
    private String confirmPassword;

    // 기본 생성자
    public ChangePasswordRequest() {}

    // Getter/Setter
    public String getOldPassword() {
        return oldPassword;
    }

    public void setOldPassword(String oldPassword) {
        this.oldPassword = oldPassword;
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

    @Override
    public String toString() {
        return "ChangePasswordRequest{" +
                "oldPassword='[PROTECTED]'" +
                ", newPassword='[PROTECTED]'" +
                ", confirmPassword='[PROTECTED]'" +
                '}';
    }
}