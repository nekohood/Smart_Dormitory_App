package com.dormitory.SpringBoot.dto;

import com.fasterxml.jackson.annotation.JsonFormat;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

/**
 * 점호 출석 테이블 관련 요청/응답 DTO
 */
public class AttendanceRequest {

    /**
     * 출석 테이블 생성 요청
     */
    public static class CreateTableRequest {
        private LocalDate inspectionDate;

        public LocalDate getInspectionDate() {
            return inspectionDate;
        }

        public void setInspectionDate(LocalDate inspectionDate) {
            this.inspectionDate = inspectionDate;
        }
    }

    /**
     * 출석 테이블 항목 수정 요청
     */
    public static class UpdateEntryRequest {
        private Boolean isSubmitted;
        private Integer score;
        private String status;
        private String notes;

        public Boolean getIsSubmitted() {
            return isSubmitted;
        }

        public void setIsSubmitted(Boolean isSubmitted) {
            this.isSubmitted = isSubmitted;
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

        public String getNotes() {
            return notes;
        }

        public void setNotes(String notes) {
            this.notes = notes;
        }
    }

    /**
     * 출석 테이블 항목 응답
     */
    public static class AttendanceEntryResponse {
        private Long id;
        
        @JsonFormat(pattern = "yyyy-MM-dd")
        private LocalDate inspectionDate;
        
        private String roomNumber;
        private String userId;
        private String userName;
        private Boolean isSubmitted;
        
        @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
        private LocalDateTime submissionTime;
        
        private Integer score;
        private String status;
        private String notes;

        // 생성자
        public AttendanceEntryResponse() {}

        public AttendanceEntryResponse(Long id, LocalDate inspectionDate, String roomNumber, 
                                      String userId, String userName, Boolean isSubmitted, 
                                      LocalDateTime submissionTime, Integer score, 
                                      String status, String notes) {
            this.id = id;
            this.inspectionDate = inspectionDate;
            this.roomNumber = roomNumber;
            this.userId = userId;
            this.userName = userName;
            this.isSubmitted = isSubmitted;
            this.submissionTime = submissionTime;
            this.score = score;
            this.status = status;
            this.notes = notes;
        }

        // Getters and Setters
        public Long getId() {
            return id;
        }

        public void setId(Long id) {
            this.id = id;
        }

        public LocalDate getInspectionDate() {
            return inspectionDate;
        }

        public void setInspectionDate(LocalDate inspectionDate) {
            this.inspectionDate = inspectionDate;
        }

        public String getRoomNumber() {
            return roomNumber;
        }

        public void setRoomNumber(String roomNumber) {
            this.roomNumber = roomNumber;
        }

        public String getUserId() {
            return userId;
        }

        public void setUserId(String userId) {
            this.userId = userId;
        }

        public String getUserName() {
            return userName;
        }

        public void setUserName(String userName) {
            this.userName = userName;
        }

        public Boolean getIsSubmitted() {
            return isSubmitted;
        }

        public void setIsSubmitted(Boolean isSubmitted) {
            this.isSubmitted = isSubmitted;
        }

        public LocalDateTime getSubmissionTime() {
            return submissionTime;
        }

        public void setSubmissionTime(LocalDateTime submissionTime) {
            this.submissionTime = submissionTime;
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

        public String getNotes() {
            return notes;
        }

        public void setNotes(String notes) {
            this.notes = notes;
        }
    }

    /**
     * 출석 테이블 전체 응답
     */
    public static class AttendanceTableResponse {
        @JsonFormat(pattern = "yyyy-MM-dd")
        private LocalDate inspectionDate;
        
        private List<AttendanceEntryResponse> entries;
        private AttendanceStatistics statistics;

        public AttendanceTableResponse() {}

        public AttendanceTableResponse(LocalDate inspectionDate, 
                                      List<AttendanceEntryResponse> entries,
                                      AttendanceStatistics statistics) {
            this.inspectionDate = inspectionDate;
            this.entries = entries;
            this.statistics = statistics;
        }

        public LocalDate getInspectionDate() {
            return inspectionDate;
        }

        public void setInspectionDate(LocalDate inspectionDate) {
            this.inspectionDate = inspectionDate;
        }

        public List<AttendanceEntryResponse> getEntries() {
            return entries;
        }

        public void setEntries(List<AttendanceEntryResponse> entries) {
            this.entries = entries;
        }

        public AttendanceStatistics getStatistics() {
            return statistics;
        }

        public void setStatistics(AttendanceStatistics statistics) {
            this.statistics = statistics;
        }
    }

    /**
     * 출석 통계
     */
    public static class AttendanceStatistics {
        private long totalRooms;
        private long submittedRooms;
        private long pendingRooms;
        private double submissionRate;

        public AttendanceStatistics() {}

        public AttendanceStatistics(long totalRooms, long submittedRooms, 
                                   long pendingRooms, double submissionRate) {
            this.totalRooms = totalRooms;
            this.submittedRooms = submittedRooms;
            this.pendingRooms = pendingRooms;
            this.submissionRate = submissionRate;
        }

        public long getTotalRooms() {
            return totalRooms;
        }

        public void setTotalRooms(long totalRooms) {
            this.totalRooms = totalRooms;
        }

        public long getSubmittedRooms() {
            return submittedRooms;
        }

        public void setSubmittedRooms(long submittedRooms) {
            this.submittedRooms = submittedRooms;
        }

        public long getPendingRooms() {
            return pendingRooms;
        }

        public void setPendingRooms(long pendingRooms) {
            this.pendingRooms = pendingRooms;
        }

        public double getSubmissionRate() {
            return submissionRate;
        }

        public void setSubmissionRate(double submissionRate) {
            this.submissionRate = submissionRate;
        }
    }
}
