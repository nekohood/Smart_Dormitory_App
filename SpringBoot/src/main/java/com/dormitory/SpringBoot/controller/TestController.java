package com.dormitory.SpringBoot.controller;

import com.dormitory.SpringBoot.repository.UserRepository;
import com.dormitory.SpringBoot.domain.User;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/test")
@CrossOrigin(origins = "*")
public class TestController {

    private static final Logger logger = LoggerFactory.getLogger(TestController.class);

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    /**
     * 데이터베이스 연결 테스트
     */
    @GetMapping("/db")
    public Map<String, Object> testDatabase() {
        Map<String, Object> result = new HashMap<>();

        try {
            logger.info("=== 데이터베이스 테스트 시작 ===");

            // 전체 사용자 수 조회
            long userCount = userRepository.count();
            logger.info("전체 사용자 수: {}", userCount);
            result.put("totalUsers", userCount);

            // 모든 사용자 목록 조회
            List<User> allUsers = userRepository.findAll();
            logger.info("조회된 사용자 목록 크기: {}", allUsers.size());

            // 사용자 정보를 안전하게 출력 (비밀번호 제외)
            result.put("userCount", allUsers.size());
            result.put("userIds", allUsers.stream().map(User::getId).toList());

            // 데이터베이스 연결 상태
            result.put("status", "SUCCESS");
            result.put("message", "데이터베이스 연결 성공");
            result.put("timestamp", LocalDateTime.now().toString());

            logger.info("=== 데이터베이스 테스트 완료 ===");

        } catch (Exception e) {
            logger.error("데이터베이스 테스트 중 오류 발생", e);
            result.put("status", "ERROR");
            result.put("message", "데이터베이스 연결 실패: " + e.getMessage());
            result.put("error", e.getClass().getSimpleName());
        }

        return result;
    }

    /**
     * 테스트 사용자 직접 생성
     */
    @PostMapping("/create-user")
    public Map<String, Object> createTestUser(
            @RequestParam String id,
            @RequestParam String password,
            @RequestParam(defaultValue = "false") boolean isAdmin) {

        Map<String, Object> result = new HashMap<>();

        try {
            logger.info("=== 테스트 사용자 생성 시작: {} ===", id);

            // 중복 확인
            if (userRepository.existsById(id)) {
                result.put("status", "ERROR");
                result.put("message", "이미 존재하는 사용자 ID입니다: " + id);
                return result;
            }

            User testUser = new User();
            testUser.setId(id);
            testUser.setPassword(passwordEncoder.encode(password));
            testUser.setIsAdmin(isAdmin);
            testUser.setIsActive(true);

            logger.info("사용자 객체 생성 완료: ID={}, isAdmin={}", id, isAdmin);

            User savedUser = userRepository.save(testUser);
            logger.info("사용자 저장 완료: {}", savedUser.getId());

            // 저장 확인
            boolean exists = userRepository.existsById(savedUser.getId());
            logger.info("저장 확인 결과: {}", exists);

            result.put("status", "SUCCESS");
            result.put("message", "테스트 사용자 생성 성공");
            result.put("userId", savedUser.getId());
            result.put("isAdmin", savedUser.getIsAdmin());
            result.put("createdAt", savedUser.getCreatedAt());
            result.put("verified", exists);

            logger.info("=== 테스트 사용자 생성 완료 ===");

        } catch (Exception e) {
            logger.error("테스트 사용자 생성 중 오류 발생", e);
            result.put("status", "ERROR");
            result.put("message", "테스트 사용자 생성 실패: " + e.getMessage());
            result.put("error", e.getClass().getSimpleName());
        }

        return result;
    }

    /**
     * 사용자 삭제 (테스트용)
     */
    @DeleteMapping("/delete-user/{id}")
    public Map<String, Object> deleteTestUser(@PathVariable String id) {
        Map<String, Object> result = new HashMap<>();

        try {
            logger.info("=== 테스트 사용자 삭제: {} ===", id);

            if (!userRepository.existsById(id)) {
                result.put("status", "ERROR");
                result.put("message", "존재하지 않는 사용자 ID입니다: " + id);
                return result;
            }

            userRepository.deleteById(id);

            // 삭제 확인
            boolean exists = userRepository.existsById(id);

            result.put("status", "SUCCESS");
            result.put("message", "테스트 사용자 삭제 성공");
            result.put("deleted", !exists);

            logger.info("=== 테스트 사용자 삭제 완료 ===");

        } catch (Exception e) {
            logger.error("테스트 사용자 삭제 중 오류 발생", e);
            result.put("status", "ERROR");
            result.put("message", "테스트 사용자 삭제 실패: " + e.getMessage());
        }

        return result;
    }

    /**
     * 모든 테스트 데이터 삭제
     */
    @DeleteMapping("/clear-all")
    public Map<String, Object> clearAllUsers() {
        Map<String, Object> result = new HashMap<>();

        try {
            logger.info("=== 모든 사용자 데이터 삭제 ===");

            long beforeCount = userRepository.count();
            userRepository.deleteAll();
            long afterCount = userRepository.count();

            result.put("status", "SUCCESS");
            result.put("message", "모든 사용자 데이터 삭제 완료");
            result.put("deletedCount", beforeCount - afterCount);
            result.put("remainingCount", afterCount);

            logger.info("삭제 완료: {}개 -> {}개", beforeCount, afterCount);

        } catch (Exception e) {
            logger.error("데이터 삭제 중 오류 발생", e);
            result.put("status", "ERROR");
            result.put("message", "데이터 삭제 실패: " + e.getMessage());
        }

        return result;
    }

    /**
     * 테이블 구조 확인
     */
    @GetMapping("/table-info")
    public Map<String, Object> getTableInfo() {
        Map<String, Object> result = new HashMap<>();

        try {
            // 간단한 테이블 존재 여부 확인
            long count = userRepository.count();

            result.put("status", "SUCCESS");
            result.put("message", "테이블 정보 조회 성공");
            result.put("tableExists", true);
            result.put("recordCount", count);
            result.put("timestamp", LocalDateTime.now().toString());

        } catch (Exception e) {
            logger.error("테이블 정보 조회 중 오류", e);
            result.put("status", "ERROR");
            result.put("message", "테이블 정보 조회 실패: " + e.getMessage());
            result.put("tableExists", false);
        }

        return result;
    }
}