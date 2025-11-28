package com.dormitory.SpringBoot.repository;

import com.dormitory.SpringBoot.domain.RoomTemplate;
import com.dormitory.SpringBoot.domain.RoomTemplate.RoomType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * 방 템플릿 Repository
 */
@Repository
public interface RoomTemplateRepository extends JpaRepository<RoomTemplate, Long> {

    /**
     * 활성화된 템플릿 전체 조회
     */
    List<RoomTemplate> findByIsActiveTrueOrderByRoomTypeAscCreatedAtDesc();

    /**
     * 방 타입별 활성화된 템플릿 조회
     */
    List<RoomTemplate> findByRoomTypeAndIsActiveTrueOrderByIsDefaultDescCreatedAtDesc(RoomType roomType);

    /**
     * 방 타입별 기본 템플릿 조회
     */
    Optional<RoomTemplate> findByRoomTypeAndIsDefaultTrueAndIsActiveTrue(RoomType roomType);

    /**
     * 특정 동의 템플릿 조회
     */
    List<RoomTemplate> findByBuildingNameAndIsActiveTrueOrderByRoomTypeAsc(String buildingName);

    /**
     * 특정 동 + 방 타입의 템플릿 조회
     */
    @Query("SELECT rt FROM RoomTemplate rt WHERE rt.isActive = true " +
            "AND rt.roomType = :roomType " +
            "AND (rt.buildingName = :buildingName OR rt.buildingName IS NULL) " +
            "ORDER BY CASE WHEN rt.buildingName = :buildingName THEN 0 ELSE 1 END, rt.isDefault DESC")
    List<RoomTemplate> findByRoomTypeAndBuilding(@Param("roomType") RoomType roomType,
                                                 @Param("buildingName") String buildingName);

    /**
     * 템플릿 이름 중복 확인
     */
    boolean existsByTemplateName(String templateName);

    /**
     * 전체 템플릿 조회 (관리용)
     */
    List<RoomTemplate> findAllByOrderByRoomTypeAscCreatedAtDesc();

    /**
     * 기본 템플릿 조회 (방 타입별)
     */
    @Query("SELECT rt FROM RoomTemplate rt WHERE rt.isDefault = true AND rt.isActive = true")
    List<RoomTemplate> findAllDefaultTemplates();
}