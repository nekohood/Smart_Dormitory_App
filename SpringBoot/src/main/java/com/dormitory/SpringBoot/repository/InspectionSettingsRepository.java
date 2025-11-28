package com.dormitory.SpringBoot.repository;

import com.dormitory.SpringBoot.domain.InspectionSettings;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * 점호 설정 Repository
 */
@Repository
public interface InspectionSettingsRepository extends JpaRepository<InspectionSettings, Long> {

    /**
     * 활성화된 설정 조회
     */
    List<InspectionSettings> findByIsEnabledTrue();

    /**
     * 기본 설정 조회
     */
    Optional<InspectionSettings> findByIsDefaultTrue();

    /**
     * 활성화된 기본 설정 조회
     */
    @Query("SELECT s FROM InspectionSettings s WHERE s.isEnabled = true AND s.isDefault = true")
    Optional<InspectionSettings> findActiveDefaultSettings();

    /**
     * 특정 요일에 적용되는 설정 조회
     */
    @Query("SELECT s FROM InspectionSettings s WHERE s.isEnabled = true AND (s.applicableDays = 'ALL' OR s.applicableDays LIKE %:dayOfWeek%)")
    List<InspectionSettings> findByApplicableDay(@Param("dayOfWeek") String dayOfWeek);

    /**
     * 설정 이름으로 조회
     */
    Optional<InspectionSettings> findBySettingName(String settingName);

    /**
     * 설정 이름 존재 여부 확인
     */
    boolean existsBySettingName(String settingName);

    /**
     * 모든 설정 조회 (생성일 역순)
     */
    List<InspectionSettings> findAllByOrderByCreatedAtDesc();
}