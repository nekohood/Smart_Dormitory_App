package com.dormitory.SpringBoot.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.time.LocalDateTime;

/**
 * 사용자 통계 응답 DTO
 */
public class UserStatistics {

    @JsonProperty("totalInspections")
    private int totalInspections;

    @JsonProperty("passedInspections")
    private int passedInspections;

    @JsonProperty("failedInspections")
    private int failedInspections;

    @JsonProperty("totalComplaints")
    private int totalComplaints;

    @JsonProperty("resolvedComplaints")
    private int resolvedComplaints;

    @JsonProperty("averageInspectionScore")
    private double averageInspectionScore;

    @JsonProperty("lastInspectionDate")
    private LocalDateTime lastInspectionDate;

    @JsonProperty("consecutivePasses")
    private int consecutivePasses;

    @JsonProperty("consecutiveFails")
    private int consecutiveFails;

    @JsonProperty("maxScore")
    private Integer maxScore;

    @JsonProperty("minScore")
    private Integer minScore;

    @JsonProperty("passRate")
    private double passRate;

    // 기본 생성자
    public UserStatistics() {}

    // Getter/Setter
    public int getTotalInspections() {
        return totalInspections;
    }

    public void setTotalInspections(int totalInspections) {
        this.totalInspections = totalInspections;
    }

    public int getPassedInspections() {
        return passedInspections;
    }

    public void setPassedInspections(int passedInspections) {
        this.passedInspections = passedInspections;
    }

    public int getFailedInspections() {
        return failedInspections;
    }

    public void setFailedInspections(int failedInspections) {
        this.failedInspections = failedInspections;
    }

    public int getTotalComplaints() {
        return totalComplaints;
    }

    public void setTotalComplaints(int totalComplaints) {
        this.totalComplaints = totalComplaints;
    }

    public int getResolvedComplaints() {
        return resolvedComplaints;
    }

    public void setResolvedComplaints(int resolvedComplaints) {
        this.resolvedComplaints = resolvedComplaints;
    }

    public double getAverageInspectionScore() {
        return averageInspectionScore;
    }

    public void setAverageInspectionScore(double averageInspectionScore) {
        this.averageInspectionScore = averageInspectionScore;
    }

    public LocalDateTime getLastInspectionDate() {
        return lastInspectionDate;
    }

    public void setLastInspectionDate(LocalDateTime lastInspectionDate) {
        this.lastInspectionDate = lastInspectionDate;
    }

    public int getConsecutivePasses() {
        return consecutivePasses;
    }

    public void setConsecutivePasses(int consecutivePasses) {
        this.consecutivePasses = consecutivePasses;
    }

    public int getConsecutiveFails() {
        return consecutiveFails;
    }

    public void setConsecutiveFails(int consecutiveFails) {
        this.consecutiveFails = consecutiveFails;
    }

    public Integer getMaxScore() {
        return maxScore;
    }

    public void setMaxScore(Integer maxScore) {
        this.maxScore = maxScore;
    }

    public Integer getMinScore() {
        return minScore;
    }

    public void setMinScore(Integer minScore) {
        this.minScore = minScore;
    }

    public double getPassRate() {
        return passRate;
    }

    public void setPassRate(double passRate) {
        this.passRate = passRate;
    }

    // 유틸리티 메서드
    public void calculatePassRate() {
        if (totalInspections > 0) {
            this.passRate = (double) passedInspections / totalInspections * 100;
        } else {
            this.passRate = 0.0;
        }
    }

    @Override
    public String toString() {
        return "UserStatistics{" +
                "totalInspections=" + totalInspections +
                ", passedInspections=" + passedInspections +
                ", failedInspections=" + failedInspections +
                ", totalComplaints=" + totalComplaints +
                ", resolvedComplaints=" + resolvedComplaints +
                ", averageInspectionScore=" + averageInspectionScore +
                ", passRate=" + passRate +
                '}';
    }
}