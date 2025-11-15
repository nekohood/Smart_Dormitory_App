package com.dormitory.SpringBoot.controller;

import com.dormitory.SpringBoot.dto.CalendarDTO;
import com.dormitory.SpringBoot.services.CalendarService;
import com.dormitory.SpringBoot.utils.JwtTokenProvider;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 캘린더 컨트롤러
 */
@RestController
@RequestMapping("/api/calendar")
@CrossOrigin(origins = "*")
public class CalendarController {

    @Autowired
    private CalendarService calendarService;

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    /**
     * 모든 일정 조회
     */
    @GetMapping
    public ResponseEntity<Map<String, Object>> getAllEvents() {
        try {
            List<CalendarDTO> events = calendarService.getAllEvents();
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "일정 목록 조회 성공");
            response.put("events", events);
            response.put("count", events.size());
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "일정 목록 조회 실패: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }

    /**
     * ID로 일정 조회
     */
    @GetMapping("/{id}")
    public ResponseEntity<Map<String, Object>> getEventById(@PathVariable Long id) {
        try {
            CalendarDTO event = calendarService.getEventById(id);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "일정 조회 성공");
            response.put("event", event);
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "일정 조회 실패: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(errorResponse);
        }
    }

    /**
     * 특정 기간의 일정 조회
     */
    @GetMapping("/range")
    public ResponseEntity<Map<String, Object>> getEventsByDateRange(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime start,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime end) {
        try {
            List<CalendarDTO> events = calendarService.getEventsByDateRange(start, end);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "기간별 일정 조회 성공");
            response.put("events", events);
            response.put("count", events.size());
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "기간별 일정 조회 실패: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }

    /**
     * 특정 월의 일정 조회
     */
    @GetMapping("/month")
    public ResponseEntity<Map<String, Object>> getEventsByMonth(
            @RequestParam int year,
            @RequestParam int month) {
        try {
            List<CalendarDTO> events = calendarService.getEventsByMonth(year, month);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "월별 일정 조회 성공");
            response.put("events", events);
            response.put("count", events.size());
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "월별 일정 조회 실패: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }

    /**
     * 오늘의 일정 조회
     */
    @GetMapping("/today")
    public ResponseEntity<Map<String, Object>> getTodayEvents() {
        try {
            List<CalendarDTO> events = calendarService.getTodayEvents();
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "오늘 일정 조회 성공");
            response.put("events", events);
            response.put("count", events.size());
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "오늘 일정 조회 실패: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }

    /**
     * 이번 주 일정 조회
     */
    @GetMapping("/week")
    public ResponseEntity<Map<String, Object>> getThisWeekEvents() {
        try {
            List<CalendarDTO> events = calendarService.getThisWeekEvents();
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "이번 주 일정 조회 성공");
            response.put("events", events);
            response.put("count", events.size());
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "이번 주 일정 조회 실패: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }

    /**
     * 다가오는 일정 조회
     */
    @GetMapping("/upcoming")
    public ResponseEntity<Map<String, Object>> getUpcomingEvents(
            @RequestParam(defaultValue = "30") int days) {
        try {
            List<CalendarDTO> events = calendarService.getUpcomingEvents(days);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "다가오는 일정 조회 성공");
            response.put("events", events);
            response.put("count", events.size());
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "다가오는 일정 조회 실패: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }

    /**
     * 카테고리별 일정 조회
     */
    @GetMapping("/category/{category}")
    public ResponseEntity<Map<String, Object>> getEventsByCategory(@PathVariable String category) {
        try {
            List<CalendarDTO> events = calendarService.getEventsByCategory(category);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "카테고리별 일정 조회 성공");
            response.put("events", events);
            response.put("count", events.size());
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "카테고리별 일정 조회 실패: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }

    /**
     * 중요 일정 조회
     */
    @GetMapping("/important")
    public ResponseEntity<Map<String, Object>> getImportantEvents() {
        try {
            List<CalendarDTO> events = calendarService.getImportantEvents();
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "중요 일정 조회 성공");
            response.put("events", events);
            response.put("count", events.size());
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "중요 일정 조회 실패: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }

    /**
     * 일정 생성 (관리자 전용)
     */
    @PostMapping
    public ResponseEntity<Map<String, Object>> createEvent(
            @RequestBody CalendarDTO calendarDTO,
            @RequestHeader("Authorization") String token) {
        try {
            // 토큰에서 사용자 ID 추출
            String actualToken = token.replace("Bearer ", "");
            String userId = jwtTokenProvider.getUserIdFromToken(actualToken);
            
            CalendarDTO createdEvent = calendarService.createEvent(calendarDTO, userId);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "일정 생성 성공");
            response.put("event", createdEvent);
            
            return ResponseEntity.status(HttpStatus.CREATED).body(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "일정 생성 실패: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }

    /**
     * 일정 수정 (관리자 전용)
     */
    @PutMapping("/{id}")
    public ResponseEntity<Map<String, Object>> updateEvent(
            @PathVariable Long id,
            @RequestBody CalendarDTO calendarDTO) {
        try {
            CalendarDTO updatedEvent = calendarService.updateEvent(id, calendarDTO);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "일정 수정 성공");
            response.put("event", updatedEvent);
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "일정 수정 실패: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }

    /**
     * 일정 삭제 (관리자 전용)
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, Object>> deleteEvent(@PathVariable Long id) {
        try {
            calendarService.deleteEvent(id);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "일정 삭제 성공");
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "일정 삭제 실패: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }

    /**
     * 일정 검색
     */
    @GetMapping("/search")
    public ResponseEntity<Map<String, Object>> searchEvents(@RequestParam String title) {
        try {
            List<CalendarDTO> events = calendarService.searchEventsByTitle(title);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "일정 검색 성공");
            response.put("events", events);
            response.put("count", events.size());
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "일정 검색 실패: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }
}
