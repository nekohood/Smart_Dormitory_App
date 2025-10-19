package com.dormitory.SpringBoot.dto;

import com.fasterxml.jackson.annotation.JsonFormat;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

import java.time.LocalDateTime;

/**
 * 점호 관련 DTO 클래스들
 */
public class InspectionRequest {

    /**
     * 점호 등록 요청 DTO
     */
    public static class CreateRequest {
        @NotBlank(message = "방 번호는 필수입니다.")
        private String roomNumber;

        public CreateRequest() {}

        public CreateRequest(String roomNumber) {
            this.roomNumber = roomNumber;
        }

        public String getRoomNumber() {
            return roomNumber;
        }

        public void setRoomNumber(String roomNumber) {
            this.roomNumber = roomNumber;
        }
    }

    /**
     * 관리자용 점호 수정 요청 DTO
     */
    public static class UpdateRequest {
        @Min(value = 0, message = "점수는 0 이상이어야 합니다.")
        @Max(value = 10, message = "점수는 10 이하여야 합니다.")
        private Integer score;

        private String status; // PASS, FAIL

        private String geminiFeedback; // AI 피드백 수정

        private String adminComment; // 관리자 코멘트

        private Boolean isReInspection; // 재검 여부

        // 기본 생성자
        public UpdateRequest() {}

        // 전체 생성자
        public UpdateRequest(Integer score, String status, String geminiFeedback,
                             String adminComment, Boolean isReInspection) {
            this.score = score;
            this.status = status;
            this.geminiFeedback = geminiFeedback;
            this.adminComment = adminComment;
            this.isReInspection = isReInspection;
        }

        // Getter and Setter methods
        public Integer getScore() {
            return score;
        }

        public void setScore(Integer score) {
            this.score = score;
        }

        public String getStatus() {
            return status;
        }

        public void setStatus(String status) {
            this.status = status;
        }

        public String getGeminiFeedback() {
            return geminiFeedback;
        }

        public void setGeminiFeedback(String geminiFeedback) {
            this.geminiFeedback = geminiFeedback;
        }

        public String getAdminComment() {
            return adminComment;
        }

        public void setAdminComment(String adminComment) {
            this.adminComment = adminComment;
        }

        public Boolean getIsReInspection() {
            return isReInspection;
        }

        public void setIsReInspection(Boolean isReInspection) {
            this.isReInspection = isReInspection;
        }
    }

    /**
     * 점호 응답 DTO
     */
    public static class Response {
        private Long id;
        private String userId;
        private String roomNumber;
        private String imagePath;
        private Integer score;
        private String status;
        private String geminiFeedback;
        private String adminComment;
        private Boolean isReInspection;

        @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
        private LocalDateTime inspectionDate;

        @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
        private LocalDateTime createdAt;

        // 기본 생성자
        public Response() {}

        // 전체 생성자
        public Response(Long id, String userId, String roomNumber, String imagePath,
                        Integer score, String status, String geminiFeedback, String adminComment,
                        Boolean isReInspection, LocalDateTime inspectionDate, LocalDateTime createdAt) {
            this.id = id;
            this.userId = userId;
            this.roomNumber = roomNumber;
            this.imagePath = imagePath;
            this.score = score;
            this.status = status;
            this.geminiFeedback = geminiFeedback;
            this.adminComment = adminComment;
            this.isReInspection = isReInspection;
            this.inspectionDate = inspectionDate;
            this.createdAt = createdAt;
        }

        // Getter and Setter methods
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

        public String getRoomNumber() {
            return roomNumber;
        }

        public void setRoomNumber(String roomNumber) {
            this.roomNumber = roomNumber;
        }

        public String getImagePath() {
            return imagePath;
        }

        public void setImagePath(String imagePath) {
            this.imagePath = imagePath;
        }

        public Integer getScore() {
            return score;
        }

        public void setScore(Integer score) {
            this.score = score;
        }

        public String getStatus() {
            return status;
        }

        public void setStatus(String status) {
            this.status = status;
        }

        public String getGeminiFeedback() {
            return geminiFeedback;
        }

        public void setGeminiFeedback(String geminiFeedback) {
            this.geminiFeedback = geminiFeedback;
        }

        public String getAdminComment() {
            return adminComment;
        }

        public void setAdminComment(String adminComment) {
            this.adminComment = adminComment;
        }

        public Boolean getIsReInspection() {
            return isReInspection;
        }

        public void setIsReInspection(Boolean isReInspection) {
            this.isReInspection = isReInspection;
        }

        public LocalDateTime getInspectionDate() {
            return inspectionDate;
        }

        public void setInspectionDate(LocalDateTime inspectionDate) {
            this.inspectionDate = inspectionDate;
        }

        public LocalDateTime getCreatedAt() {
            return createdAt;
        }

        public void setCreatedAt(LocalDateTime createdAt) {
            this.createdAt = createdAt;
        }
    }

    /**
     * 관리자용 점호 목록 응답 DTO
     */
    public static class AdminResponse extends Response {
        private String userName; // 사용자 이름 추가

        public AdminResponse() {
            super();
        }

        public AdminResponse(Long id, String userId, String userName, String roomNumber,
                             String imagePath, Integer score, String status, String geminiFeedback,
                             String adminComment, Boolean isReInspection,
                             LocalDateTime inspectionDate, LocalDateTime createdAt) {
            super(id, userId, roomNumber, imagePath, score, status, geminiFeedback,
                    adminComment, isReInspection, inspectionDate, createdAt);
            this.userName = userName;
        }

        public String getUserName() {
            return userName;
        }

        public void setUserName(String userName) {
            this.userName = userName;
        }
    }

    /**
     * 점호 통계 DTO
     */
    public static class Statistics {
        private long totalInspections;
        private long passedInspections;
        private long failedInspections;
        private long reInspections; // 재검 횟수 추가
        private double passRate;

        @JsonFormat(pattern = "yyyy-MM-dd")
        private LocalDateTime date;

        public Statistics() {}

        public Statistics(long totalInspections, long passedInspections,
                          long failedInspections, long reInspections, LocalDateTime date) {
            this.totalInspections = totalInspections;
            this.passedInspections = passedInspections;
            this.failedInspections = failedInspections;
            this.reInspections = reInspections;
            this.date = date;
            // 통과율 계산
            this.passRate = totalInspections > 0 ?
                    (double) passedInspections / totalInspections * 100.0 : 0.0;
        }

        // Getter and Setter methods
        public long getTotalInspections() {
            return totalInspections;
        }

        public void setTotalInspections(long totalInspections) {
            this.totalInspections = totalInspections;
            // 통과율 재계산
            this.passRate = totalInspections > 0 ?
                    (double) passedInspections / totalInspections * 100.0 : 0.0;
        }

        public long getPassedInspections() {
            return passedInspections;
        }

        public void setPassedInspections(long passedInspections) {
            this.passedInspections = passedInspections;
            // 통과율 재계산
            this.passRate = totalInspections > 0 ?
                    (double) passedInspections / totalInspections * 100.0 : 0.0;
        }

        public long getFailedInspections() {
            return failedInspections;
        }

        public void setFailedInspections(long failedInspections) {
            this.failedInspections = failedInspections;
        }

        public long getReInspections() {
            return reInspections;
        }

        public void setReInspections(long reInspections) {
            this.reInspections = reInspections;
        }

        public double getPassRate() {
            return passRate;
        }

        public void setPassRate(double passRate) {
            this.passRate = passRate;
        }

        public LocalDateTime getDate() {
            return date;
        }

        public void setDate(LocalDateTime date) {
            this.date = date;
        }
    }

    /**
     * 오늘 점호 상태 응답 DTO
     */
    public static class TodayInspectionResponse {
        private boolean completed; // 오늘 점호 완료 여부
        private Response inspection; // 점호 정보 (완료된 경우)
        private String message;

        public TodayInspectionResponse() {}

        public TodayInspectionResponse(boolean completed, Response inspection, String message) {
            this.completed = completed;
            this.inspection = inspection;
            this.message = message;
        }

        public boolean isCompleted() {
            return completed;
        }

        public void setCompleted(boolean completed) {
            this.completed = completed;
        }

        public Response getInspection() {
            return inspection;
        }

        public void setInspection(Response inspection) {
            this.inspection = inspection;
        }

        public String getMessage() {
            return message;
        }

        public void setMessage(String message) {
            this.message = message;
        }
    }
}