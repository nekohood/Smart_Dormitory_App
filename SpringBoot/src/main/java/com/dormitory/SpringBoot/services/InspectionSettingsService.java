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
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Optional;

/**
 * 점호 설정 서비스
 * ✅ 수정: 캘린더 연동 기능 추가
 */
@Service
@Transactional
public class InspectionSettingsService {

    private static final Logger logger = LoggerFactory.getLogger(InspectionSettingsService.class);

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
        private final LocalDate nextInspectionDate;  // ✅ 다음 점호 날짜
        private final long daysUntilNext;            // ✅ 다음 점호까지 남은 일수

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
     * ✅ 수정: 현재 시간에 점호가 허용되는지 확인 (날짜 포함)
     */
    public InspectionTimeCheckResult checkInspectionTimeAllowed() {
        try {
            logger.info("점호 허용 시간 확인 시작");

            LocalDate today = LocalDate.now();
            DayOfWeek todayDayOfWeek = today.getDayOfWeek();
            String todayStr = todayDayOfWeek.toString().substring(0, 3);

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
                    .filter(s -> s.getInspectionDate() == null)  // 날짜 미설정인 것만
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
     * ✅ 신규: 다음 예정된 점호 찾기
     */
    @Transactional(readOnly = true)
    public Optional<InspectionSettings> findNextScheduledInspection() {
        LocalDate today = LocalDate.now();

        List<InspectionSettings> futureInspections = settingsRepository.findByIsEnabledTrue().stream()
                .filter(s -> s.getInspectionDate() != null)
                .filter(s -> !s.getInspectionDate().isBefore(today))
                .sorted((a, b) -> a.getInspectionDate().compareTo(b.getInspectionDate()))
                .toList();

        return futureInspections.isEmpty() ? Optional.empty() : Optional.of(futureInspections.get(0));
    }

    /**
     * 현재 적용되는 설정 조회
     */
    @Transactional(readOnly = true)
    public Optional<InspectionSettings> getCurrentSettings() {
        try {
            LocalDate today = LocalDate.now();
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
     * ✅ 수정: 설정 생성 - 캘린더 자동 등록
     */
    public InspectionSettings createSettings(InspectionSettings settings, String adminId) {
        logger.info("점호 설정 생성 - 이름: {}, 날짜: {}", settings.getSettingName(), settings.getInspectionDate());

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

        // ✅ 점호 날짜가 설정되어 있으면 캘린더에 자동 등록
        if (settings.getInspectionDate() != null) {
            Schedule schedule = createScheduleForInspection(saved);
            saved.setScheduleId(schedule.getId());
            saved = settingsRepository.save(saved);
            logger.info("캘린더 일정 자동 생성 - 일정 ID: {}", schedule.getId());
        }

        logger.info("점호 설정 생성 완료 - ID: {}", saved.getId());
        return saved;
    }

    /**
     * ✅ 신규: 점호 설정에 대한 캘린더 일정 생성
     */
    private Schedule createScheduleForInspection(InspectionSettings settings) {
        Schedule schedule = new Schedule();

        // 제목: "🔔 점호: {설정명}"
        schedule.setTitle("🔔 점호: " + settings.getSettingName());

        // 내용: 시간 정보
        String timeRange = formatTimeRange(settings.getStartTime(), settings.getEndTime());
        schedule.setContent("점호 시간: " + timeRange);

        // 시작/종료 시간
        LocalDate date = settings.getInspectionDate();
        schedule.setStartDate(LocalDateTime.of(date, settings.getStartTime()));
        schedule.setEndDate(LocalDateTime.of(date, settings.getEndTime()));

        // 카테고리: INSPECTION (점호)
        schedule.setCategory("INSPECTION");

        return scheduleRepository.save(schedule);
    }

    /**
     * ✅ 수정: 설정 수정 - 캘린더 업데이트
     */
    public InspectionSettings updateSettings(Long id, InspectionSettings updateData) {
        logger.info("점호 설정 수정 - ID: {}", id);

        InspectionSettings settings = settingsRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("설정을 찾을 수 없습니다: " + id));

        // 기존 날짜 저장
        LocalDate oldDate = settings.getInspectionDate();

        // 필드 업데이트
        if (updateData.getSettingName() != null) {
            settings.setSettingName(updateData.getSettingName());
        }
        if (updateData.getStartTime() != null) {
            settings.setStartTime(updateData.getStartTime());
        }
        if (updateData.getEndTime() != null) {
            settings.setEndTime(updateData.getEndTime());
        }
        if (updateData.getInspectionDate() != null) {
            settings.setInspectionDate(updateData.getInspectionDate());
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

        // ✅ 캘린더 일정 업데이트
        LocalDate newDate = settings.getInspectionDate();
        if (newDate != null) {
            if (settings.getScheduleId() != null) {
                // 기존 일정 업데이트
                updateScheduleForInspection(settings);
            } else {
                // 새 일정 생성
                Schedule schedule = createScheduleForInspection(settings);
                settings.setScheduleId(schedule.getId());
            }
        } else if (oldDate != null && newDate == null) {
            // 날짜 제거됨 -> 캘린더 일정도 삭제
            if (settings.getScheduleId() != null) {
                try {
                    scheduleRepository.deleteById(settings.getScheduleId());
                    logger.info("캘린더 일정 삭제 - ID: {}", settings.getScheduleId());
                } catch (Exception e) {
                    logger.warn("캘린더 일정 삭제 실패: {}", e.getMessage());
                }
                settings.setScheduleId(null);
            }
        }

        InspectionSettings updated = settingsRepository.save(settings);
        logger.info("점호 설정 수정 완료 - ID: {}", id);
        return updated;
    }

    /**
     * ✅ 신규: 캘린더 일정 업데이트
     */
    private void updateScheduleForInspection(InspectionSettings settings) {
        if (settings.getScheduleId() == null) return;

        Optional<Schedule> scheduleOpt = scheduleRepository.findById(settings.getScheduleId());
        if (scheduleOpt.isPresent()) {
            Schedule schedule = scheduleOpt.get();
            schedule.setTitle("🔔 점호: " + settings.getSettingName());

            String timeRange = formatTimeRange(settings.getStartTime(), settings.getEndTime());
            schedule.setContent("점호 시간: " + timeRange);

            LocalDate date = settings.getInspectionDate();
            schedule.setStartDate(LocalDateTime.of(date, settings.getStartTime()));
            schedule.setEndDate(LocalDateTime.of(date, settings.getEndTime()));

            scheduleRepository.save(schedule);
            logger.info("캘린더 일정 업데이트 - ID: {}", schedule.getId());
        }
    }

    /**
     * ✅ 수정: 설정 삭제 - 캘린더 일정도 삭제
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
        // inspectionDate는 null로 유지 (매일 점호)

        InspectionSettings saved = settingsRepository.save(defaultSettings);
        logger.info("기본 점호 설정 생성 완료 - ID: {}", saved.getId());
        return saved;
    }

    private String formatTimeRange(LocalTime start, LocalTime end) {
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("HH:mm");
        return start.format(formatter) + " ~ " + end.format(formatter);
    }
}