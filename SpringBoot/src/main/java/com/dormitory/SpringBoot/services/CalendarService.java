package com.dormitory.SpringBoot.services;

import com.dormitory.SpringBoot.domain.Calendar;
import com.dormitory.SpringBoot.dto.CalendarDTO;
import com.dormitory.SpringBoot.repository.CalendarRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

/**
 * 캘린더 서비스
 */
@Service
public class CalendarService {

    @Autowired
    private CalendarRepository calendarRepository;

    /**
     * 모든 일정 조회
     */
    public List<CalendarDTO> getAllEvents() {
        return calendarRepository.findAllByOrderByStartDateAsc()
                .stream()
                .map(CalendarDTO::new)
                .collect(Collectors.toList());
    }

    /**
     * ID로 일정 조회
     */
    public CalendarDTO getEventById(Long id) {
        Calendar calendar = calendarRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("일정을 찾을 수 없습니다. ID: " + id));
        return new CalendarDTO(calendar);
    }

    /**
     * 특정 기간의 일정 조회
     */
    public List<CalendarDTO> getEventsByDateRange(LocalDateTime start, LocalDateTime end) {
        return calendarRepository.findByDateRange(start, end)
                .stream()
                .map(CalendarDTO::new)
                .collect(Collectors.toList());
    }

    /**
     * 특정 날짜의 일정 조회
     */
    public List<CalendarDTO> getEventsByDate(LocalDateTime date) {
        return calendarRepository.findByDate(date)
                .stream()
                .map(CalendarDTO::new)
                .collect(Collectors.toList());
    }

    /**
     * 특정 월의 일정 조회
     */
    public List<CalendarDTO> getEventsByMonth(int year, int month) {
        return calendarRepository.findByMonth(year, month)
                .stream()
                .map(CalendarDTO::new)
                .collect(Collectors.toList());
    }

    /**
     * 카테고리별 일정 조회
     */
    public List<CalendarDTO> getEventsByCategory(String category) {
        return calendarRepository.findByCategoryOrderByStartDateAsc(category)
                .stream()
                .map(CalendarDTO::new)
                .collect(Collectors.toList());
    }

    /**
     * 중요 일정 조회
     */
    public List<CalendarDTO> getImportantEvents() {
        return calendarRepository.findByIsImportantTrueOrderByStartDateAsc()
                .stream()
                .map(CalendarDTO::new)
                .collect(Collectors.toList());
    }

    /**
     * 오늘의 일정 조회
     */
    public List<CalendarDTO> getTodayEvents() {
        return calendarRepository.findTodayEvents()
                .stream()
                .map(CalendarDTO::new)
                .collect(Collectors.toList());
    }

    /**
     * 이번 주 일정 조회
     */
    public List<CalendarDTO> getThisWeekEvents() {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime weekStart = now.minusDays(now.getDayOfWeek().getValue() - 1).withHour(0).withMinute(0).withSecond(0);
        LocalDateTime weekEnd = weekStart.plusDays(7);
        
        return calendarRepository.findThisWeekEvents(weekStart, weekEnd)
                .stream()
                .map(CalendarDTO::new)
                .collect(Collectors.toList());
    }

    /**
     * 다가오는 일정 조회 (N일 이내)
     */
    public List<CalendarDTO> getUpcomingEvents(int days) {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime future = now.plusDays(days);
        
        return calendarRepository.findUpcomingEvents(now, future)
                .stream()
                .map(CalendarDTO::new)
                .collect(Collectors.toList());
    }

    /**
     * 제목으로 일정 검색
     */
    public List<CalendarDTO> searchEventsByTitle(String title) {
        return calendarRepository.findByTitleContainingIgnoreCaseOrderByStartDateAsc(title)
                .stream()
                .map(CalendarDTO::new)
                .collect(Collectors.toList());
    }

    /**
     * 일정 생성 (관리자 전용)
     */
    @Transactional
    public CalendarDTO createEvent(CalendarDTO calendarDTO, String createdBy) {
        Calendar calendar = calendarDTO.toEntity();
        calendar.setCreatedBy(createdBy);
        
        // 종료일이 시작일보다 앞설 수 없음
        if (calendar.getEndDate().isBefore(calendar.getStartDate())) {
            throw new RuntimeException("종료일은 시작일보다 앞설 수 없습니다.");
        }
        
        Calendar savedCalendar = calendarRepository.save(calendar);
        return new CalendarDTO(savedCalendar);
    }

    /**
     * 일정 수정 (관리자 전용)
     */
    @Transactional
    public CalendarDTO updateEvent(Long id, CalendarDTO calendarDTO) {
        Calendar existingCalendar = calendarRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("일정을 찾을 수 없습니다. ID: " + id));

        // 수정 가능한 필드 업데이트
        existingCalendar.setTitle(calendarDTO.getTitle());
        existingCalendar.setDescription(calendarDTO.getDescription());
        existingCalendar.setStartDate(calendarDTO.getStartDate());
        existingCalendar.setEndDate(calendarDTO.getEndDate());
        existingCalendar.setCategory(calendarDTO.getCategory());
        existingCalendar.setColor(calendarDTO.getColor());
        existingCalendar.setIsAllDay(calendarDTO.getIsAllDay());
        existingCalendar.setIsImportant(calendarDTO.getIsImportant());
        existingCalendar.setLocation(calendarDTO.getLocation());

        // 종료일이 시작일보다 앞설 수 없음
        if (existingCalendar.getEndDate().isBefore(existingCalendar.getStartDate())) {
            throw new RuntimeException("종료일은 시작일보다 앞설 수 없습니다.");
        }

        Calendar updatedCalendar = calendarRepository.save(existingCalendar);
        return new CalendarDTO(updatedCalendar);
    }

    /**
     * 일정 삭제 (관리자 전용)
     */
    @Transactional
    public void deleteEvent(Long id) {
        if (!calendarRepository.existsById(id)) {
            throw new RuntimeException("일정을 찾을 수 없습니다. ID: " + id);
        }
        calendarRepository.deleteById(id);
    }

    /**
     * 생성자별 일정 조회 (관리자용)
     */
    public List<CalendarDTO> getEventsByCreator(String createdBy) {
        return calendarRepository.findByCreatedByOrderByStartDateDesc(createdBy)
                .stream()
                .map(CalendarDTO::new)
                .collect(Collectors.toList());
    }
}
