package com.dormitory.SpringBoot.services;

import com.dormitory.SpringBoot.domain.InspectionSettings;
import com.dormitory.SpringBoot.domain.Schedule;
import com.dormitory.SpringBoot.repository.InspectionSettingsRepository;
import com.dormitory.SpringBoot.repository.ScheduleRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Optional;

/**
 * 점호 설정 서비스
 * ✅ 수정: 한국 시간대(KST) 적용
 */
@Service
@Transactional
public class InspectionSettingsService {

    private static final Logger logger = LoggerFactory.getLogger(InspectionSettingsService.class);

    // ✅ 한국 시간대 상수
    private static final ZoneId KOREA_ZONE = ZoneId.of("Asia/Seoul");

    @Autowired
    private InspectionSettingsRepository settingsRepository;

    @Autowired
    private ScheduleRepository scheduleRepository;

    /**
     * 점호 시간 확인 결과
     */
    public static class InspectionTimeCheckResult {
        private final boolean allowed;
        private final String message;
        private final InspectionSettings settings;
        private final LocalDate nextInspectionDate;
        private final long daysUntilNext;

        public InspectionTimeCheckResult(boolean allowed, String message, InspectionSettings settings) {
            this.allowed = allowed;
            this.message = message;
            this.settings = settings;
            this.nextInspectionDate = null;
            this.daysUntilNext = 0;
        }

        public InspectionTimeCheckResult(boolean allowed, String message, InspectionSettings settings,
                                         LocalDate nextInspectionDate, long daysUntilNext) {
            this.allowed = allowed;
            this.message = message;
            this.settings = settings;
            this.nextInspectionDate = nextInspectionDate;
            this.daysUntilNext = daysUntilNext;
        }

        public boolean isAllowed() { return allowed; }
        public String getMessage() { return message; }
        public InspectionSettings getSettings() { return settings; }
        public LocalDate getNextInspectionDate() { return nextInspectionDate; }
        public long getDaysUntilNext() { return daysUntilNext; }
    }

    /**
     * ✅ 수정: 현재 시간에 점호가 허용되는지 확인 (한국 시간 기준)
     */
    public InspectionTimeCheckResult checkInspectionTimeAllowed() {
        try {
            // ✅ 한국 시간대 기준으로 현재 날짜/시간 가져오기
            ZonedDateTime koreaTime = ZonedDateTime.now(KOREA_ZONE);
            LocalDate today = koreaTime.toLocalDate();
            LocalTime nowTime = koreaTime.toLocalTime();
            DayOfWeek todayDayOfWeek = today.getDayOfWeek();
            String todayStr = todayDayOfWeek.toString().substring(0, 3);

            logger.info("점호 허용 시간 확인 시작 - 한국 시간: {}, 날짜: {}, 요일: {}",
                    nowTime, today, todayStr);

            // 1. 오늘 날짜에 해당하는 설정 찾기 (점호 날짜가 설정된 것 우선)
            List<InspectionSettings> allSettings = settingsRepository.findByIsEnabledTrue();

            // 오늘 점호 날짜인 설정 찾기
            Optional<InspectionSettings> todayDateSettings = allSettings.stream()
                    .filter(s -> s.getInspectionDate() != null && s.getInspectionDate().equals(today))
                    .findFirst();

            if (todayDateSettings.isPresent()) {
                InspectionSettings settings = todayDateSettings.get();
                if (settings.isWithinAllowedTime()) {
                    logger.info("점호 허용됨 - 설정: {} (날짜 기반)", settings.getSettingName());
                    return new InspectionTimeCheckResult(true, "점호 가능 시간입니다.", settings);
                } else {
                    String timeRange = formatTimeRange(settings.getStartTime(), settings.getEndTime());
                    String message = String.format("점호 시간이 아닙니다. 오늘 점호 시간: %s", timeRange);
                    return new InspectionTimeCheckResult(false, message, settings);
                }
            }

            // 2. 요일 기반 설정 확인 (점호 날짜가 설정되지 않은 설정들)
            List<InspectionSettings> dayBasedSettings = settingsRepository.findByApplicableDay(todayStr);
            dayBasedSettings = dayBasedSettings.stream()
                    .filter(s -> s.getInspectionDate() == null)
                    .toList();

            if (dayBasedSettings.isEmpty()) {
                // 기본 설정 확인
                Optional<InspectionSettings> defaultSettings = settingsRepository.findActiveDefaultSettings();
                if (defaultSettings.isPresent() && defaultSettings.get().getInspectionDate() == null) {
                    dayBasedSettings = List.of(defaultSettings.get());
                }
            }

            for (InspectionSettings settings : dayBasedSettings) {
                if (settings.isWithinAllowedTime()) {
                    logger.info("점호 허용됨 - 설정: {} (요일 기반)", settings.getSettingName());
                    return new InspectionTimeCheckResult(true, "점호 가능 시간입니다.", settings);
                }
            }

            // 3. 점호 불가 - 다음 점호 날짜 찾기
            Optional<InspectionSettings> nextScheduled = findNextScheduledInspection();
            if (nextScheduled.isPresent()) {
                InspectionSettings next = nextScheduled.get();
                LocalDate nextDate = next.getInspectionDate();
                long daysUntil = next.getDaysUntilInspection();
                String timeRange = formatTimeRange(next.getStartTime(), next.getEndTime());

                String message;
                if (daysUntil == 0) {
                    message = String.format("오늘 점호 시간: %s", timeRange);
                } else if (daysUntil == 1) {
                    message = String.format("다음 점호: 내일 %s", timeRange);
                } else {
                    message = String.format("다음 점호: %s (%d일 후) %s",
                            nextDate.format(DateTimeFormatter.ofPattern("M월 d일")),
                            daysUntil, timeRange);
                }

                logger.info("점호 시간 아님 - 다음 점호: {}", nextDate);
                return new InspectionTimeCheckResult(false, message, next, nextDate, daysUntil);
            }

            // 4. 설정된 점호가 없음
            if (!dayBasedSettings.isEmpty()) {
                InspectionSettings firstSettings = dayBasedSettings.get(0);
                String timeRange = formatTimeRange(firstSettings.getStartTime(), firstSettings.getEndTime());
                String message = String.format("점호 시간이 아닙니다. 점호 가능 시간: %s", timeRange);
                return new InspectionTimeCheckResult(false, message, firstSettings);
            }

            logger.info("점호 설정이 없습니다.");
            return new InspectionTimeCheckResult(false, "점호 일정이 없습니다.", null);

        } catch (Exception e) {
            logger.error("점호 시간 확인 중 오류 발생", e);
            return new InspectionTimeCheckResult(true, "시간 확인 오류 - 기본 허용", null);
        }
    }

    /**
     * ✅ 다음 예정된 점호 찾기 (한국 시간 기준)
     */
    @Transactional(readOnly = true)
    public Optional<InspectionSettings> findNextScheduledInspection() {
        LocalDate today = ZonedDateTime.now(KOREA_ZONE).toLocalDate();

        List<InspectionSettings> futureInspections = settingsRepository.findByIsEnabledTrue().stream()
                .filter(s -> s.getInspectionDate() != null)
                .filter(s -> !s.getInspectionDate().isBefore(today))
                .sorted((a, b) -> a.getInspectionDate().compareTo(b.getInspectionDate()))
                .toList();

        return futureInspections.isEmpty() ? Optional.empty() : Optional.of(futureInspections.get(0));
    }

    /**
     * 현재 적용되는 설정 조회 (한국 시간 기준)
     */
    @Transactional(readOnly = true)
    public Optional<InspectionSettings> getCurrentSettings() {
        try {
            LocalDate today = ZonedDateTime.now(KOREA_ZONE).toLocalDate();
            DayOfWeek todayDayOfWeek = today.getDayOfWeek();
            String todayStr = todayDayOfWeek.toString().substring(0, 3);

            // 오늘 날짜의 설정 우선
            List<InspectionSettings> allSettings = settingsRepository.findByIsEnabledTrue();
            Optional<InspectionSettings> todayDateSettings = allSettings.stream()
                    .filter(s -> s.getInspectionDate() != null && s.getInspectionDate().equals(today))
                    .findFirst();

            if (todayDateSettings.isPresent()) {
                return todayDateSettings;
            }

            // 요일 기반 설정
            List<InspectionSettings> todaySettings = settingsRepository.findByApplicableDay(todayStr);
            todaySettings = todaySettings.stream()
                    .filter(s -> s.getInspectionDate() == null)
                    .toList();

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
     * 설정 생성 (캘린더 연동 포함)
     */
    public InspectionSettings createSettings(InspectionSettings settings, String createdBy) {
        logger.info("점호 설정 생성 - 이름: {}, 생성자: {}", settings.getSettingName(), createdBy);

        // 중복 이름 체크
        if (settingsRepository.existsBySettingName(settings.getSettingName())) {
            throw new RuntimeException("이미 존재하는 설정 이름입니다: " + settings.getSettingName());
        }

        settings.setCreatedBy(createdBy);

        // ✅ 점호 날짜가 설정되어 있으면 캘린더 일정 자동 생성
        if (settings.getInspectionDate() != null) {
            Schedule schedule = createScheduleForInspection(settings);
            settings.setScheduleId(schedule.getId());
            logger.info("캘린더 일정 자동 생성 - 일정 ID: {}", schedule.getId());
        }

        InspectionSettings saved = settingsRepository.save(settings);
        logger.info("점호 설정 생성 완료 - ID: {}", saved.getId());
        return saved;
    }

    /**
     * ✅ 점호 설정에 대한 캘린더 일정 생성
     */
    private Schedule createScheduleForInspection(InspectionSettings settings) {
        Schedule schedule = new Schedule();
        schedule.setTitle("점호: " + settings.getSettingName());
        schedule.setContent(String.format("점호 시간: %s ~ %s",
                settings.getStartTime().format(DateTimeFormatter.ofPattern("HH:mm")),
                settings.getEndTime().format(DateTimeFormatter.ofPattern("HH:mm"))));
        schedule.setStartDate(settings.getInspectionDate().atTime(settings.getStartTime()));
        schedule.setEndDate(settings.getInspectionDate().atTime(settings.getEndTime()));
        schedule.setCategory("INSPECTION");

        return scheduleRepository.save(schedule);
    }

    /**
     * 설정 수정
     */
    public InspectionSettings updateSettings(Long id, InspectionSettings updatedSettings) {
        logger.info("점호 설정 수정 - ID: {}", id);

        InspectionSettings existing = settingsRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("설정을 찾을 수 없습니다: " + id));

        // 이름 중복 체크 (자신 제외)
        if (!existing.getSettingName().equals(updatedSettings.getSettingName()) &&
                settingsRepository.existsBySettingName(updatedSettings.getSettingName())) {
            throw new RuntimeException("이미 존재하는 설정 이름입니다: " + updatedSettings.getSettingName());
        }

        // 업데이트
        existing.setSettingName(updatedSettings.getSettingName());
        existing.setStartTime(updatedSettings.getStartTime());
        existing.setEndTime(updatedSettings.getEndTime());
        existing.setInspectionDate(updatedSettings.getInspectionDate());
        existing.setIsEnabled(updatedSettings.getIsEnabled());
        existing.setCameraOnly(updatedSettings.getCameraOnly());
        existing.setExifValidationEnabled(updatedSettings.getExifValidationEnabled());
        existing.setExifTimeToleranceMinutes(updatedSettings.getExifTimeToleranceMinutes());
        existing.setGpsValidationEnabled(updatedSettings.getGpsValidationEnabled());
        existing.setDormitoryLatitude(updatedSettings.getDormitoryLatitude());
        existing.setDormitoryLongitude(updatedSettings.getDormitoryLongitude());
        existing.setGpsRadiusMeters(updatedSettings.getGpsRadiusMeters());
        existing.setRoomPhotoValidationEnabled(updatedSettings.getRoomPhotoValidationEnabled());
        existing.setApplicableDays(updatedSettings.getApplicableDays());

        // ✅ 캘린더 일정 업데이트
        if (updatedSettings.getInspectionDate() != null) {
            if (existing.getScheduleId() != null) {
                // 기존 일정 업데이트
                updateScheduleForInspection(existing.getScheduleId(), existing);
            } else {
                // 새 일정 생성
                Schedule schedule = createScheduleForInspection(existing);
                existing.setScheduleId(schedule.getId());
            }
        } else if (existing.getScheduleId() != null) {
            // 날짜가 제거되면 일정도 삭제
            try {
                scheduleRepository.deleteById(existing.getScheduleId());
                existing.setScheduleId(null);
            } catch (Exception e) {
                logger.warn("캘린더 일정 삭제 실패: {}", e.getMessage());
            }
        }

        InspectionSettings saved = settingsRepository.save(existing);
        logger.info("점호 설정 수정 완료 - ID: {}", id);
        return saved;
    }

    /**
     * ✅ 캘린더 일정 업데이트
     */
    private void updateScheduleForInspection(Long scheduleId, InspectionSettings settings) {
        scheduleRepository.findById(scheduleId).ifPresent(schedule -> {
            schedule.setTitle("점호: " + settings.getSettingName());
            schedule.setContent(String.format("점호 시간: %s ~ %s",
                    settings.getStartTime().format(DateTimeFormatter.ofPattern("HH:mm")),
                    settings.getEndTime().format(DateTimeFormatter.ofPattern("HH:mm"))));
            schedule.setStartDate(settings.getInspectionDate().atTime(settings.getStartTime()));
            schedule.setEndDate(settings.getInspectionDate().atTime(settings.getEndTime()));
            scheduleRepository.save(schedule);
        });
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

        // ✅ 연결된 캘린더 일정 삭제
        if (settings.getScheduleId() != null) {
            try {
                scheduleRepository.deleteById(settings.getScheduleId());
                logger.info("연결된 캘린더 일정 삭제 - ID: {}", settings.getScheduleId());
            } catch (Exception e) {
                logger.warn("캘린더 일정 삭제 실패: {}", e.getMessage());
            }
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