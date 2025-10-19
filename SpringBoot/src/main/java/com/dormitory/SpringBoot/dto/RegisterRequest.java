package com.dormitory.SpringBoot.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 회원가입 요청 DTO - 완성된 버전
 */
public class RegisterRequest {

    @NotBlank(message = "사용자 ID는 필수입니다")
    @Size(min = 3, max = 50, message = "사용자 ID는 3-50자 사이여야 합니다")
    @JsonProperty("id")
    private String id;

    @NotBlank(message = "비밀번호는 필수입니다")
    @Size(min = 8, max = 100, message = "비밀번호는 8-100자 사이여야 합니다")
    @JsonProperty("password")
    private String password;

    @Size(max = 100, message = "이름은 100자를 초과할 수 없습니다")
    @JsonProperty("name")
    private String name;

    @Email(message = "올바른 이메일 형식이어야 합니다")
    @Size(max = 100, message = "이메일은 100자를 초과할 수 없습니다")
    @JsonProperty("email")
    private String email;

    @Size(max = 20, message = "전화번호는 20자를 초과할 수 없습니다")
    @JsonProperty("phoneNumber")
    private String phoneNumber;

    @Size(max = 20, message = "방 번호는 20자를 초과할 수 없습니다")
    @JsonProperty("roomNumber")
    private String roomNumber;

    @JsonProperty("isAdmin")
    private Boolean isAdmin = false;

    // 기본 생성자
    public RegisterRequest() {}

    // 전체 생성자
    public RegisterRequest(String id, String password, String name, String email, Boolean isAdmin) {
        this.id = id;
        this.password = password;
        this.name = name;
        this.email = email;
        this.isAdmin = isAdmin != null ? isAdmin : false;
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

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name != null ? name.trim() : null;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email != null ? email.trim().toLowerCase() : null;
    }

    public String getPhoneNumber() {
        return phoneNumber;
    }

    public void setPhoneNumber(String phoneNumber) {
        this.phoneNumber = phoneNumber != null ? phoneNumber.trim() : null;
    }

    public String getRoomNumber() {
        return roomNumber;
    }

    public void setRoomNumber(String roomNumber) {
        this.roomNumber = roomNumber != null ? roomNumber.trim() : null;
    }

    public Boolean getIsAdmin() {
        return isAdmin;
    }

    public void setIsAdmin(Boolean isAdmin) {
        this.isAdmin = isAdmin != null ? isAdmin : false;
    }

    // 유틸리티 메서드들

    /**
     * 필수 필드가 모두 채워져 있는지 확인
     */
    public boolean hasRequiredFields() {
        return id != null && !id.trim().isEmpty() &&
                password != null && !password.trim().isEmpty();
    }

    /**
     * 이메일이 유효한 형식인지 간단 검증
     */
    public boolean isValidEmail() {
        if (email == null || email.trim().isEmpty()) {
            return true; // 선택사항이므로 빈 값은 유효
        }
        return email.contains("@") && email.contains(".");
    }

    /**
     * 비밀번호 강도 체크 (간단한 검증)
     */
    public boolean isStrongPassword() {
        if (password == null || password.length() < 8) {
            return false;
        }

        boolean hasLetter = password.matches(".*[a-zA-Z].*");
        boolean hasDigit = password.matches(".*\\d.*");

        return hasLetter && hasDigit;
    }

    /**
     * 전화번호 형식 정규화
     */
    public void normalizePhoneNumber() {
        if (phoneNumber != null) {
            // 숫자만 추출
            String numbersOnly = phoneNumber.replaceAll("[^0-9]", "");

            // 한국 휴대폰 번호 형식으로 변환
            if (numbersOnly.length() == 11 && numbersOnly.startsWith("010")) {
                this.phoneNumber = numbersOnly.substring(0, 3) + "-" +
                        numbersOnly.substring(3, 7) + "-" +
                        numbersOnly.substring(7);
            } else if (numbersOnly.length() == 10) {
                this.phoneNumber = numbersOnly.substring(0, 3) + "-" +
                        numbersOnly.substring(3, 6) + "-" +
                        numbersOnly.substring(6);
            }
        }
    }

    @Override
    public String toString() {
        return "RegisterRequest{" +
                "id='" + id + '\'' +
                ", password='[PROTECTED]'" +
                ", name='" + name + '\'' +
                ", email='" + email + '\'' +
                ", phoneNumber='" + phoneNumber + '\'' +
                ", roomNumber='" + roomNumber + '\'' +
                ", isAdmin=" + isAdmin +
                '}';
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        RegisterRequest that = (RegisterRequest) o;
        return id != null ? id.equals(that.id) : that.id == null;
    }

    @Override
    public int hashCode() {
        return id != null ? id.hashCode() : 0;
    }
}