package com.dormitory.SpringBoot.controller;

import com.dormitory.SpringBoot.dto.DDayDTO;
import com.dormitory.SpringBoot.services.DDayService;
import com.dormitory.SpringBoot.utils.JwtTokenProvider;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * D-Day 컨트롤러
 */
@RestController
@RequestMapping("/api/dday")
@CrossOrigin(origins = "*")
public class DDayController {

    @Autowired
    private DDayService ddayService;

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    /**
     * 모든 활성화된 D-Day 조회
     */
    @GetMapping
    public ResponseEntity<Map<String, Object>> getAllActiveDDays() {
        try {
            List<DDayDTO> ddays = ddayService.getAllActiveDDays();
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "D-Day 목록 조회 성공");
            response.put("ddays", ddays);
            response.put("count", ddays.size());
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "D-Day 목록 조회 실패: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }

    /**
     * 모든 D-Day 조회 (비활성화 포함 - 관리자용)
     */
    @GetMapping("/all")
    public ResponseEntity<Map<String, Object>> getAllDDays() {
        try {
            List<DDayDTO> ddays = ddayService.getAllDDays();
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "전체 D-Day 목록 조회 성공");
            response.put("ddays", ddays);
            response.put("count", ddays.size());
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "전체 D-Day 목록 조회 실패: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }

    /**
     * ID로 D-Day 조회
     */
    @GetMapping("/{id}")
    public ResponseEntity<Map<String, Object>> getDDayById(@PathVariable Long id) {
        try {
            DDayDTO dday = ddayService.getDDayById(id);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "D-Day 조회 성공");
            response.put("dday", dday);
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "D-Day 조회 실패: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(errorResponse);
        }
    }

    /**
     * 중요 D-Day 조회
     */
    @GetMapping("/important")
    public ResponseEntity<Map<String, Object>> getImportantDDays() {
        try {
            List<DDayDTO> ddays = ddayService.getImportantDDays();
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "중요 D-Day 조회 성공");
            response.put("ddays", ddays);
            response.put("count", ddays.size());
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "중요 D-Day 조회 실패: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }

    /**
     * 다가오는 D-Day 조회
     */
    @GetMapping("/upcoming")
    public ResponseEntity<Map<String, Object>> getUpcomingDDays(
            @RequestParam(defaultValue = "30") int days) {
        try {
            List<DDayDTO> ddays = ddayService.getUpcomingDDays(days);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "다가오는 D-Day 조회 성공");
            response.put("ddays", ddays);
            response.put("count", ddays.size());
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "다가오는 D-Day 조회 실패: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }

    /**
     * 오늘 도래하는 D-Day 조회
     */
    @GetMapping("/today")
    public ResponseEntity<Map<String, Object>> getTodayDDays() {
        try {
            List<DDayDTO> ddays = ddayService.getTodayDDays();
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "오늘 D-Day 조회 성공");
            response.put("ddays", ddays);
            response.put("count", ddays.size());
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "오늘 D-Day 조회 실패: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }

    /**
     * D-Day 생성 (관리자 전용)
     */
    @PostMapping
    public ResponseEntity<Map<String, Object>> createDDay(
            @RequestBody DDayDTO ddayDTO,
            @RequestHeader("Authorization") String token) {
        try {
            // 토큰에서 사용자 ID 추출
            String actualToken = token.replace("Bearer ", "");
            String userId = jwtTokenProvider.getUserIdFromToken(actualToken);
            
            DDayDTO createdDDay = ddayService.createDDay(ddayDTO, userId);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "D-Day 생성 성공");
            response.put("dday", createdDDay);
            
            return ResponseEntity.status(HttpStatus.CREATED).body(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "D-Day 생성 실패: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }

    /**
     * D-Day 수정 (관리자 전용)
     */
    @PutMapping("/{id}")
    public ResponseEntity<Map<String, Object>> updateDDay(
            @PathVariable Long id,
            @RequestBody DDayDTO ddayDTO) {
        try {
            DDayDTO updatedDDay = ddayService.updateDDay(id, ddayDTO);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "D-Day 수정 성공");
            response.put("dday", updatedDDay);
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "D-Day 수정 실패: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }

    /**
     * D-Day 삭제 (관리자 전용)
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, Object>> deleteDDay(@PathVariable Long id) {
        try {
            ddayService.deleteDDay(id);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "D-Day 삭제 성공");
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "D-Day 삭제 실패: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }

    /**
     * D-Day 활성화/비활성화 토글 (관리자 전용)
     */
    @PutMapping("/{id}/toggle")
    public ResponseEntity<Map<String, Object>> toggleDDayActive(@PathVariable Long id) {
        try {
            DDayDTO updatedDDay = ddayService.toggleDDayActive(id);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "D-Day 상태 변경 성공");
            response.put("dday", updatedDDay);
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "D-Day 상태 변경 실패: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }

    /**
     * D-Day 검색
     */
    @GetMapping("/search")
    public ResponseEntity<Map<String, Object>> searchDDays(@RequestParam String title) {
        try {
            List<DDayDTO> ddays = ddayService.searchDDaysByTitle(title);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "D-Day 검색 성공");
            response.put("ddays", ddays);
            response.put("count", ddays.size());
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "D-Day 검색 실패: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }

    /**
     * D-Day 통계 조회 (관리자용)
     */
    @GetMapping("/statistics")
    public ResponseEntity<Map<String, Object>> getDDayStatistics() {
        try {
            long activeCount = ddayService.getActiveDDayCount();
            long importantCount = ddayService.getImportantDDayCount();
            
            Map<String, Object> statistics = new HashMap<>();
            statistics.put("activeCount", activeCount);
            statistics.put("importantCount", importantCount);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "D-Day 통계 조회 성공");
            response.put("statistics", statistics);
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "D-Day 통계 조회 실패: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }
}
