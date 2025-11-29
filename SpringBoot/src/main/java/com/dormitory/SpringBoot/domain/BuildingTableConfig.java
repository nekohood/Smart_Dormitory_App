package com.dormitory.SpringBoot.domain;

import jakarta.persistence.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.LocalDateTime;

/**
 * 기숙사별 점호 테이블 설정 엔티티
 * - 각 기숙사 동별로 층수 범위, 호실 범위를 설정
 * - 관리자가 테이블 행렬 크기를 커스터마이징 가능
 */
@Entity
@Table(name = "building_table_config", 
       uniqueConstraints = @UniqueConstraint(columnNames = {"building_name"}))
@EntityListeners(AuditingEntityListener.class)
public class BuildingTableConfig {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /**
     * 기숙사 동 이름 (예: "제1기숙사", "제2기숙사")
     */
    @Column(name = "building_name", nullable = false, unique = true, length = 50)
    private String buildingName;

    /**
     * 시작 층수 (예: 2)
     */
    @Column(name = "start_floor", nullable = false)
    private Integer startFloor = 2;

    /**
     * 종료 층수 (예: 13)
     */
    @Column(name = "end_floor", nullable = false)
    private Integer endFloor = 13;

    /**
     * 시작 호실 (예: 1)
     */
    @Column(name = "start_room", nullable = false)
    private Integer startRoom = 1;

    /**
     * 종료 호실 (예: 20)
     */
    @Column(name = "end_room", nullable = false)
    private Integer endRoom = 20;

    /**
     * 방 번호 형식 (예: "FLOOR_ROOM" = 201, "FLOOR_ZERO_ROOM" = 2001)
     * FLOOR_ROOM: 층수*100 + 호실 (201, 202, ... 1320)
     * FLOOR_ZERO_ROOM: 층수*1000 + 호실 (2001, 2002, ... 13020)
     */
    @Column(name = "room_number_format", length = 20)
    private String roomNumberFormat = "FLOOR_ROOM";

    /**
     * 활성화 여부
     */
    @Column(name = "is_active", nullable = false)
    private Boolean isActive = true;

    /**
     * 설명/메모
     */
    @Column(name = "description", length = 500)
    private String description;

    /**
     * 생성자 ID
     */
    @Column(name = "created_by", length = 50)
    private String createdBy;

    /**
     * 수정자 ID
     */
    @Column(name = "updated_by", length = 50)
    private String updatedBy;

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @LastModifiedDate
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    // 기본 생성자
    public BuildingTableConfig() {}

    // 생성자
    public BuildingTableConfig(String buildingName, Integer startFloor, Integer endFloor, 
                               Integer startRoom, Integer endRoom) {
        this.buildingName = buildingName;
        this.startFloor = startFloor;
        this.endFloor = endFloor;
        this.startRoom = startRoom;
        this.endRoom = endRoom;
    }

    // 방 번호 생성 헬퍼 메서드
    public String generateRoomNumber(int floor, int room) {
        if ("FLOOR_ZERO_ROOM".equals(roomNumberFormat)) {
            return String.valueOf(floor * 1000 + room);
        }
        // 기본: FLOOR_ROOM
        return String.valueOf(floor * 100 + room);
    }

    // 방 번호에서 층/호실 추출 헬퍼 메서드
    public int[] parseRoomNumber(String roomNumber) {
        try {
            int num = Integer.parseInt(roomNumber);
            if ("FLOOR_ZERO_ROOM".equals(roomNumberFormat)) {
                return new int[]{num / 1000, num % 1000};
            }
            return new int[]{num / 100, num % 100};
        } catch (NumberFormatException e) {
            return new int[]{0, 0};
        }
    }

    // 층수 개수
    public int getFloorCount() {
        return endFloor - startFloor + 1;
    }

    // 호실 개수
    public int getRoomCount() {
        return endRoom - startRoom + 1;
    }

    // 총 방 개수
    public int getTotalRoomCount() {
        return getFloorCount() * getRoomCount();
    }

    // Getters and Setters
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getBuildingName() {
        return buildingName;
    }

    public void setBuildingName(String buildingName) {
        this.buildingName = buildingName;
    }

    public Integer getStartFloor() {
        return startFloor;
    }

    public void setStartFloor(Integer startFloor) {
        this.startFloor = startFloor;
    }

    public Integer getEndFloor() {
        return endFloor;
    }

    public void setEndFloor(Integer endFloor) {
        this.endFloor = endFloor;
    }

    public Integer getStartRoom() {
        return startRoom;
    }

    public void setStartRoom(Integer startRoom) {
        this.startRoom = startRoom;
    }

    public Integer getEndRoom() {
        return endRoom;
    }

    public void setEndRoom(Integer endRoom) {
        this.endRoom = endRoom;
    }

    public String getRoomNumberFormat() {
        return roomNumberFormat;
    }

    public void setRoomNumberFormat(String roomNumberFormat) {
        this.roomNumberFormat = roomNumberFormat;
    }

    public Boolean getIsActive() {
        return isActive;
    }

    public void setIsActive(Boolean isActive) {
        this.isActive = isActive;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public String getCreatedBy() {
        return createdBy;
    }

    public void setCreatedBy(String createdBy) {
        this.createdBy = createdBy;
    }

    public String getUpdatedBy() {
        return updatedBy;
    }

    public void setUpdatedBy(String updatedBy) {
        this.updatedBy = updatedBy;
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

    @Override
    public String toString() {
        return "BuildingTableConfig{" +
                "id=" + id +
                ", buildingName='" + buildingName + '\'' +
                ", startFloor=" + startFloor +
                ", endFloor=" + endFloor +
                ", startRoom=" + startRoom +
                ", endRoom=" + endRoom +
                ", isActive=" + isActive +
                '}';
    }
}
