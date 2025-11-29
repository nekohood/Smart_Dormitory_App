package com.dormitory.SpringBoot.repository;

import com.dormitory.SpringBoot.domain.BuildingTableConfig;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * 기숙사 테이블 설정 Repository
 */
@Repository
public interface BuildingTableConfigRepository extends JpaRepository<BuildingTableConfig, Long> {

    /**
     * 기숙사 동 이름으로 설정 조회
     */
    Optional<BuildingTableConfig> findByBuildingName(String buildingName);

    /**
     * 기숙사 동 이름으로 활성화된 설정 조회
     */
    Optional<BuildingTableConfig> findByBuildingNameAndIsActiveTrue(String buildingName);

    /**
     * 모든 활성화된 설정 조회
     */
    List<BuildingTableConfig> findByIsActiveTrueOrderByBuildingNameAsc();

    /**
     * 모든 설정 조회 (정렬)
     */
    List<BuildingTableConfig> findAllByOrderByBuildingNameAsc();

    /**
     * 기숙사 동 이름 존재 여부 확인
     */
    boolean existsByBuildingName(String buildingName);

    /**
     * 기숙사 동 이름 존재 여부 확인 (특정 ID 제외, 수정 시 사용)
     */
    @Query("SELECT CASE WHEN COUNT(b) > 0 THEN true ELSE false END FROM BuildingTableConfig b WHERE b.buildingName = :buildingName AND b.id != :id")
    boolean existsByBuildingNameAndIdNot(String buildingName, Long id);
}
