package com.dormitory.SpringBoot.services;

import com.dormitory.SpringBoot.domain.InspectionSettings;
import com.dormitory.SpringBoot.repository.InspectionSettingsRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.DayOfWeek;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Optional;

/**
 * 점호 설정 서비스
 */
@Service
@Transactional
public class InspectionSettingsService {

    private static final Logger logger = LoggerFactory.getLogger(InspectionSettingsService.class);

    @Autowired
    private InspectionSettingsRepository settingsRepository;

    /**
     * 점호 시간 확인 결과
     */
    public static class InspectionTimeCheckResult {
        private final boolean allowed;
        private final String message;
        private final InspectionSettings settings;

        public InspectionTimeCheckResult(boolean allowed, String message, InspectionSettings settings) {
            this.allowed = allowed;
            this.message = message;
            this.settings = settings;
        }

        public boolean isAllowed() { return allowed; }
        public String getMessage() { return message; }
        public InspectionSettings getSettings() { return settings; }
    }

    /**
     * 현재 시간에 점호가 허용되는지 확인
     */
    public InspectionTimeCheckResult checkInspectionTimeAllowed() {
        try {
            logger.info("점호 허용 시간 확인 시작");

            DayOfWeek today = LocalDateTime.now().getDayOfWeek();
            String todayStr = today.toString().substring(0, 3);

            List<InspectionSettings> todaySettings = settingsRepository.findByApplicableDay(todayStr);

            if (todaySettings.isEmpty()) {
                Optional<InspectionSettings> defaultSettings = settingsRepository.findActiveDefaultSettings();
                if (defaultSettings.isPresent()) {
                    todaySettings = List.of(defaultSettings.get());
                }
            }

            if (todaySettings.isEmpty()) {
                logger.info("점호 설정이 없습니다. 기본적으로 허용합니다.");
                return new InspectionTimeCheckResult(true, "점호 설정이 없어 기본 허용됩니다.", null);
            }

            for (InspectionSettings settings : todaySettings) {
                if (settings.isWithinAllowedTime()) {
                    logger.info("점호 허용됨 - 설정: {}", settings.getSettingName());
                    return new InspectionTimeCheckResult(true, "점호 가능 시간입니다.", settings);
                }
            }

            InspectionSettings firstSettings = todaySettings.get(0);
            String timeRange = formatTimeRange(firstSettings.getStartTime(), firstSettings.getEndTime());
            String message = String.format("점호 시간이 아닙니다. 점호 가능 시간: %s", timeRange);

            logger.info("점호 시간 아님: {}", message);
            return new InspectionTimeCheckResult(false, message, firstSettings);

        } catch (Exception e) {
            logger.error("점호 시간 확인 중 오류 발생", e);
            return new InspectionTimeCheckResult(true, "시간 확인 오류 - 기본 허용", null);
        }
    }

    /**
     * 현재 적용되는 설정 조회
     */
    @Transactional(readOnly = true)
    public Optional<InspectionSettings> getCurrentSettings() {
        try {
            DayOfWeek today = LocalDateTime.now().getDayOfWeek();
            String todayStr = today.toString().substring(0, 3);

            List<InspectionSettings> todaySettings = settingsRepository.findByApplicableDay(todayStr);

            if (!todaySettings.isEmpty()) {
                return Optional.of(todaySettings.get(0));
            }

            return settingsRepository.findActiveDefaultSettings();
        } catch (Exception e) {
            logger.error("현재 설정 조회 중 오류 발생", e);
            return Optional.empty();
        }
    }

    /**
     * 모든 설정 조회
     */
    @Transactional(readOnly = true)
    public List<InspectionSettings> getAllSettings() {
        return settingsRepository.findAllByOrderByCreatedAtDesc();
    }

    /**
     * 특정 설정 조회
     */
    @Transactional(readOnly = true)
    public Optional<InspectionSettings> getSettingsById(Long id) {
        return settingsRepository.findById(id);
    }

    /**
     * 설정 생성
     */
    public InspectionSettings createSettings(InspectionSettings settings, String adminId) {
        logger.info("점호 설정 생성 - 이름: {}", settings.getSettingName());

        if (settingsRepository.existsBySettingName(settings.getSettingName())) {
            throw new RuntimeException("이미 존재하는 설정 이름입니다: " + settings.getSettingName());
        }

        if (Boolean.TRUE.equals(settings.getIsDefault())) {
            settingsRepository.findByIsDefaultTrue().ifPresent(existing -> {
                existing.setIsDefault(false);
                settingsRepository.save(existing);
            });
        }

        settings.setCreatedBy(adminId);
        InspectionSettings saved = settingsRepository.save(settings);
        logger.info("점호 설정 생성 완료 - ID: {}", saved.getId());
        return saved;
    }

    /**
     * 설정 수정
     */
    public InspectionSettings updateSettings(Long id, InspectionSettings updateData) {
        logger.info("점호 설정 수정 - ID: {}", id);

        InspectionSettings settings = settingsRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("설정을 찾을 수 없습니다: " + id));

        if (updateData.getSettingName() != null) {
            settings.setSettingName(updateData.getSettingName());
        }
        if (updateData.getStartTime() != null) {
            settings.setStartTime(updateData.getStartTime());
        }
        if (updateData.getEndTime() != null) {
            settings.setEndTime(updateData.getEndTime());
        }
        if (updateData.getIsEnabled() != null) {
            settings.setIsEnabled(updateData.getIsEnabled());
        }
        if (updateData.getCameraOnly() != null) {
            settings.setCameraOnly(updateData.getCameraOnly());
        }
        if (updateData.getExifValidationEnabled() != null) {
            settings.setExifValidationEnabled(updateData.getExifValidationEnabled());
        }
        if (updateData.getExifTimeToleranceMinutes() != null) {
            settings.setExifTimeToleranceMinutes(updateData.getExifTimeToleranceMinutes());
        }
        if (updateData.getGpsValidationEnabled() != null) {
            settings.setGpsValidationEnabled(updateData.getGpsValidationEnabled());
        }
        if (updateData.getDormitoryLatitude() != null) {
            settings.setDormitoryLatitude(updateData.getDormitoryLatitude());
        }
        if (updateData.getDormitoryLongitude() != null) {
            settings.setDormitoryLongitude(updateData.getDormitoryLongitude());
        }
        if (updateData.getGpsRadiusMeters() != null) {
            settings.setGpsRadiusMeters(updateData.getGpsRadiusMeters());
        }
        if (updateData.getRoomPhotoValidationEnabled() != null) {
            settings.setRoomPhotoValidationEnabled(updateData.getRoomPhotoValidationEnabled());
        }
        if (updateData.getApplicableDays() != null) {
            settings.setApplicableDays(updateData.getApplicableDays());
        }

        if (Boolean.TRUE.equals(updateData.getIsDefault()) && !Boolean.TRUE.equals(settings.getIsDefault())) {
            settingsRepository.findByIsDefaultTrue().ifPresent(existing -> {
                if (!existing.getId().equals(id)) {
                    existing.setIsDefault(false);
                    settingsRepository.save(existing);
                }
            });
            settings.setIsDefault(true);
        }

        InspectionSettings updated = settingsRepository.save(settings);
        logger.info("점호 설정 수정 완료 - ID: {}", id);
        return updated;
    }

    /**
     * 설정 삭제
     */
    public void deleteSettings(Long id) {
        logger.info("점호 설정 삭제 - ID: {}", id);

        InspectionSettings settings = settingsRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("설정을 찾을 수 없습니다: " + id));

        if (Boolean.TRUE.equals(settings.getIsDefault())) {
            throw new RuntimeException("기본 설정은 삭제할 수 없습니다.");
        }

        settingsRepository.delete(settings);
        logger.info("점호 설정 삭제 완료 - ID: {}", id);
    }

    /**
     * 설정 활성화/비활성화 토글
     */
    public InspectionSettings toggleEnabled(Long id) {
        logger.info("점호 설정 토글 - ID: {}", id);

        InspectionSettings settings = settingsRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("설정을 찾을 수 없습니다: " + id));

        settings.setIsEnabled(!Boolean.TRUE.equals(settings.getIsEnabled()));
        InspectionSettings updated = settingsRepository.save(settings);

        logger.info("점호 설정 토글 완료 - ID: {}, 활성화: {}", id, updated.getIsEnabled());
        return updated;
    }

    /**
     * 기본 설정 생성 (없는 경우)
     */
    public InspectionSettings createDefaultSettingsIfNotExists() {
        Optional<InspectionSettings> existing = settingsRepository.findByIsDefaultTrue();
        if (existing.isPresent()) {
            return existing.get();
        }

        InspectionSettings defaultSettings = new InspectionSettings();
        defaultSettings.setSettingName("기본 설정");
        defaultSettings.setStartTime(LocalTime.of(21, 0));
        defaultSettings.setEndTime(LocalTime.of(23, 59));
        defaultSettings.setIsEnabled(true);
        defaultSettings.setCameraOnly(true);
        defaultSettings.setExifValidationEnabled(true);
        defaultSettings.setExifTimeToleranceMinutes(10);
        defaultSettings.setGpsValidationEnabled(false);
        defaultSettings.setRoomPhotoValidationEnabled(true);
        defaultSettings.setApplicableDays("ALL");
        defaultSettings.setIsDefault(true);
        defaultSettings.setCreatedBy("SYSTEM");

        InspectionSettings saved = settingsRepository.save(defaultSettings);
        logger.info("기본 점호 설정 생성 완료 - ID: {}", saved.getId());
        return saved;
    }

    private String formatTimeRange(LocalTime start, LocalTime end) {
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("HH:mm");
        return start.format(formatter) + " ~ " + end.format(formatter);
    }
}